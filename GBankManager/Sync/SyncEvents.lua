local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local syncEvents = ns.modules.syncEvents or {}
local transport = ns.modules.syncTransport or {}
local codec = ns.modules.syncCodec or {}
local permissions = ns.modules.permissions or ns.modules.auth or {}
local coordinator = ns.modules.syncCoordinator or {}
local authPolicySource = ns.modules.authPolicySource or {}
local authPolicyCodec = ns.modules.authPolicyCodec or {}

local REGISTERED_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "CHAT_MSG_ADDON",
    "GUILD_MOTD",
    "GUILD_ROSTER_UPDATE",
    "PLAYER_GUILD_UPDATE",
    "GUILD_RANKS_UPDATE",
}

function syncEvents.GetRegisteredEvents()
    return REGISTERED_EVENTS
end

local function current_db()
    local store = ns.data.store or ns.modules.store
    return store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
end

local function current_policy(db)
    local store = ns.data.store or ns.modules.store
    return store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or (db or {}).auth or {}
end

local function upsert_request(db, request)
    db.requests = db.requests or {}
    for index, existing in ipairs(db.requests) do
        if existing.requestId == request.requestId then
            db.requests[index] = request
            return request, index, false
        end
    end

    table.insert(db.requests, request)
    return request, #db.requests, true
end

local function actor_can(context, capability, policy)
    return type(permissions.Can) == "function" and permissions.Can(context or {}, capability, policy) or true
end

local function handle_auth_policy_snapshot(db, payload)
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local remotePolicy = type(payload.policy) == "table" and payload.policy or nil
    local localPolicy = current_policy(db)

    if not remotePolicy or permissions.IsBlacklisted(actorContext, localPolicy) then
        return false
    end

    if not actorContext.isGuildMaster and not actor_can(actorContext, "auth_manage", localPolicy) then
        return false
    end

    local nextPolicy = type(coordinator.ResolveAuthConflict) == "function" and coordinator.ResolveAuthConflict(localPolicy, remotePolicy) or remotePolicy
    if type(permissions.NormalizePolicy) == "function" then
        nextPolicy = permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end
    if type(authPolicyCodec.EncodePolicy) == "function" then
        nextPolicy.guildPolicyString = authPolicyCodec.EncodePolicy(nextPolicy)
    end
    nextPolicy.guildPolicySource = "sync"

    db.auth = nextPolicy
    return true
end

local function handle_request_created(db, payload)
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local request = type(payload.request) == "table" and payload.request or nil
    local localPolicy = current_policy(db)

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        return false
    end

    if not actor_can(actorContext, "request_submit", localPolicy) then
        return false
    end

    upsert_request(db, request)
    return true
end

local function handle_request_updated(db, payload)
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local request = type(payload.request) == "table" and payload.request or nil
    local action = tostring(payload.action or "")
    local localPolicy = current_policy(db)
    local capabilityByAction = {
        APPROVE = "request_approve",
        REJECT = "request_reject",
        FULFILL = "request_fulfill",
        REOPEN = "request_reopen",
        EDIT = "request_edit",
    }

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        return false
    end

    local capability = capabilityByAction[action]
    if capability and not actor_can(actorContext, capability, localPolicy) then
        return false
    end

    upsert_request(db, request)
    return true
end

function syncEvents.HandleEvent(event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= ns.addonName then
            return false
        end

        local store = ns.data.store or ns.modules.store
        local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
        if type(permissions.RefreshPolicyFromGuild) == "function" then
            permissions.RefreshPolicyFromGuild(db)
        end
        if type(authPolicySource.PullPolicyFromGuildInfo) == "function" then
            authPolicySource.PullPolicyFromGuildInfo(db)
        end
        return true
    end

    if event == "PLAYER_LOGIN" then
        if _G.C_ChatInfo and type(_G.C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
            _G.C_ChatInfo.RegisterAddonMessagePrefix("GBankManager")
        end

        if type(transport.Send) == "function" then
            local store = ns.data.store or ns.modules.store
            local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
            local context = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
            transport.Send("GUILD", "GUILD", {
                type = "SYNC_HELLO",
                updatedAt = _G.time(),
                payload = context.characterKey or (_G.UnitName("player") or "Unknown"),
            })
        end

        return true
    end

    if event == "GUILD_MOTD" or event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" or event == "GUILD_RANKS_UPDATE" then
        local db = current_db()
        if type(permissions.RefreshPolicyFromGuild) == "function" then
            permissions.RefreshPolicyFromGuild(db)
        end
        return true
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, payload, distribution, sender = ...
        if prefix ~= "GBankManager" then
            return false
        end

        ns.state.lastSyncMessage = codec.DecodeTable(payload)
        ns.state.lastSyncMessage.distribution = distribution
        ns.state.lastSyncMessage.sender = sender
        local db = current_db()
        if ns.state.lastSyncMessage.type == "AUTH_POLICY_SNAPSHOT" then
            return handle_auth_policy_snapshot(db, ns.state.lastSyncMessage.payload)
        end

        if ns.state.lastSyncMessage.type == "REQUEST_CREATED" then
            return handle_request_created(db, ns.state.lastSyncMessage.payload)
        end

        if ns.state.lastSyncMessage.type == "REQUEST_UPDATED" then
            return handle_request_updated(db, ns.state.lastSyncMessage.payload)
        end

        return true
    end

    return false
end

ns.modules.syncEvents = syncEvents

return syncEvents
