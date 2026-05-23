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
local requestsModule = ns.modules.requests or {}

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

local function report_sync_status(message)
    if type(transport.ReportStatus) == "function" then
        transport.ReportStatus(message)
    end
end

local function sender_display_name(sender)
    local fullSender = tostring(sender or "")
    if fullSender == "" then
        return "Unknown"
    end

    return fullSender:match("^([^%-]+)") or fullSender
end

local function request_sync_label(request)
    request = type(request) == "table" and request or {}
    return tostring(request.requestId or request.itemName or "unknown-request")
end

local request_action_labels = {
    APPROVE = "approval",
    REJECT = "rejection",
    FULFILL = "fulfillment",
    REOPEN = "reopen",
    EDIT = "update",
    DELETE = "deletion",
}

local function report_request_sync_applied(action, request, sender)
    local label = request_sync_label(request)
    local actor = sender_display_name(sender)
    if tostring(action or "") == "CREATE" then
        report_sync_status(string.format("Synced request %s from %s.", label, actor))
        return
    end

    local actionLabel = request_action_labels[tostring(action or "")] or string.lower(tostring(action or "update"))
    report_sync_status(string.format("Synced request %s for %s from %s.", actionLabel, label, actor))
end

local function report_request_sync_ignored(action, sender)
    local actor = sender_display_name(sender)
    if tostring(action or "") == "CREATE" then
        report_sync_status(string.format("Ignored synced request create from %s.", actor))
        return
    end

    local actionLabel = request_action_labels[tostring(action or "")] or string.lower(tostring(action or "update"))
    report_sync_status(string.format("Ignored synced request %s from %s.", actionLabel, actor))
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

local function delete_request(db, requestId)
    db.requests = db.requests or {}
    for index, existing in ipairs(db.requests) do
        if existing.requestId == requestId then
            table.remove(db.requests, index)
            return true
        end
    end

    return false
end

local function find_request(db, requestId)
    for index, existing in ipairs((db or {}).requests or {}) do
        if existing.requestId == requestId then
            return existing, index
        end
    end
end

local function requester_matches_actor(actorContext, request)
    actorContext = type(actorContext) == "table" and actorContext or {}
    request = type(request) == "table" and request or {}

    local actorCharacterKey = tostring(actorContext.characterKey or "")
    local requesterCharacterKey = tostring(request.requesterCharacterKey or "")
    if actorCharacterKey == "" or requesterCharacterKey == "" or actorCharacterKey ~= requesterCharacterKey then
        return false
    end

    local actorName = tostring(actorContext.name or "")
    local requesterName = tostring(request.requester or "")
    if actorName ~= "" and requesterName ~= "" and actorName ~= requesterName then
        return false
    end

    return true
end

local function actor_matches_sender(actorContext, sender)
    actorContext = type(actorContext) == "table" and actorContext or {}
    sender = tostring(sender or "")
    if sender == "" then
        return false
    end

    local senderName = sender:match("^([^%-]+)") or sender
    local actorName = tostring(actorContext.name or "")
    if actorName ~= "" and actorName ~= sender and actorName ~= senderName then
        return false
    end

    local actorCharacterKey = tostring(actorContext.characterKey or "")
    if actorCharacterKey ~= "" and actorCharacterKey ~= sender then
        local actorKeyCharacter = actorCharacterKey:match("^[^%-]+%-(.+)$") or actorCharacterKey
        if actorKeyCharacter ~= sender and actorKeyCharacter ~= senderName then
            return false
        end
    end

    return true
end

local function request_is_newer(remoteRequest, localRequest)
    remoteRequest = type(remoteRequest) == "table" and remoteRequest or {}
    localRequest = type(localRequest) == "table" and localRequest or {}
    return tonumber(remoteRequest.updatedAt or 0) >= tonumber(localRequest.updatedAt or 0)
end

local function immutable_request_fields_match(existing, incoming)
    existing = type(existing) == "table" and existing or {}
    incoming = type(incoming) == "table" and incoming or {}

    local immutableKeys = {
        "requestId",
        "requester",
        "requesterCharacterKey",
        "requesterRankName",
        "requesterRankIndex",
        "role",
        "itemID",
        "createdAt",
        "createdBy",
    }

    for _, key in ipairs(immutableKeys) do
        if incoming[key] ~= nil and existing[key] ~= incoming[key] then
            return false
        end
    end

    return true
end

local function actor_can(context, capability, policy)
    return type(permissions.Can) == "function" and permissions.Can(context or {}, capability, policy) or true
end

local function append_audit_entry(db, entry)
    db.auditLog = db.auditLog or {}
    local lastEntry = db.auditLog[#db.auditLog]
    if lastEntry
        and lastEntry.type == entry.type
        and lastEntry.requestId == entry.requestId
        and lastEntry.timestamp == entry.timestamp
        and tostring(lastEntry.actor or "") == tostring(entry.actor or "") then
        return false
    end

    table.insert(db.auditLog, entry)
    return true
end

local function append_request_sync_audit(db, action, previousRequest, nextRequest, actorContext, note)
    if type(requestsModule.BuildAuditEntry) ~= "function" then
        return false
    end

    local eventTypeByAction = {
        APPROVE = "REQUEST_APPROVED",
        REJECT = "REQUEST_REJECTED",
        FULFILL = "REQUEST_FULFILLED",
        REOPEN = "REQUEST_REOPENED",
        CANCEL = "REQUEST_CANCELED",
        DELETE = "REQUEST_DELETED",
        EDIT = "REQUEST_UPDATED",
        CREATE = "REQUEST_CREATED",
    }

    local actionKey = tostring(action or "")
    local eventType = eventTypeByAction[actionKey]
    if not eventType then
        return false
    end

    local details = {
        actor = actorContext,
        timestamp = tonumber((nextRequest or {}).updatedAt or _G.time()) or 0,
        note = note,
    }

    if actionKey == "APPROVE" or actionKey == "REJECT" or actionKey == "CANCEL" then
        details.oldValue = previousRequest and previousRequest.approval or nil
        details.newValue = nextRequest and nextRequest.approval or nil
    elseif actionKey == "FULFILL" or actionKey == "REOPEN" then
        details.oldValue = previousRequest and previousRequest.fulfillment or nil
        details.newValue = nextRequest and nextRequest.fulfillment or nil
    elseif actionKey == "DELETE" then
        details.oldValue = previousRequest and previousRequest.approval or nil
        details.newValue = "DELETED"
    elseif actionKey == "CREATE" then
        details.newValue = nextRequest and nextRequest.approval or nil
    end

    return append_audit_entry(db, requestsModule.BuildAuditEntry(eventType, nextRequest, details))
end

local function sync_request_minimum_side_effect(db, action, request, actorContext)
    if tostring(action or "") ~= "APPROVE" then
        return nil
    end

    local minimumsView = ns.modules.minimumsView
    if type(minimumsView) ~= "table" or type(minimumsView.SaveForApprovedRequest) ~= "function" then
        return nil
    end

    local bankTab = tostring((request or {}).approvedBankTab or (request or {}).tabName or "")
    if bankTab == "" then
        return nil
    end

    return minimumsView.SaveForApprovedRequest(db, request, bankTab, {
        actor = tostring((actorContext or {}).name or (actorContext or {}).characterKey or "Unknown"),
        actorRankIndex = type(actorContext) == "table" and actorContext.guildRankIndex or nil,
        timestamp = tonumber((request or {}).decidedAt or (request or {}).updatedAt or _G.time()) or 0,
    })
end

local function handle_auth_policy_snapshot(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local remotePolicy = type(payload.policy) == "table" and payload.policy or nil
    local localPolicy = current_policy(db)

    if not remotePolicy or permissions.IsBlacklisted(actorContext, localPolicy) then
        report_sync_status(string.format("Ignored synced auth policy from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_sync_status(string.format("Ignored synced auth policy from %s.", sender_display_name(sender)))
        return false
    end

    if not actorContext.isGuildMaster and not actor_can(actorContext, "auth_manage", localPolicy) then
        report_sync_status(string.format("Ignored synced auth policy from %s.", sender_display_name(sender)))
        return false
    end

    local nextPolicy = type(coordinator.ResolveAuthConflict) == "function" and coordinator.ResolveAuthConflict(localPolicy, remotePolicy) or remotePolicy
    if authPolicySource and type(authPolicySource.ApplyPolicy) == "function" then
        local applied = authPolicySource.ApplyPolicy(db, nextPolicy, {
            force = true,
            source = "sync",
        })
        if applied == true then
            report_sync_status(string.format("Synced auth policy from %s.", sender_display_name(sender)))
        end
        return applied == true
    end

    if type(permissions.NormalizePolicy) == "function" then
        nextPolicy = permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end
    if type(authPolicyCodec.EncodePolicy) == "function" then
        nextPolicy.guildPolicyString = authPolicyCodec.EncodePolicy(nextPolicy)
    end
    nextPolicy.guildPolicySource = "sync"
    db.auth = nextPolicy
    report_sync_status(string.format("Synced auth policy from %s.", sender_display_name(sender)))
    return true
end

local function handle_request_created(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local request = type(payload.request) == "table" and payload.request or nil
    local localPolicy = current_policy(db)

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not actor_can(actorContext, "request_submit", localPolicy) then
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not requester_matches_actor(actorContext, request) then
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    local existing = find_request(db, request.requestId)
    if existing and not request_is_newer(request, existing) then
        return true
    end

    local previousRequest = existing and find_request(db, request.requestId) or nil
    upsert_request(db, request)
    append_request_sync_audit(db, "CREATE", previousRequest, request, actorContext, request.note)
    report_request_sync_applied("CREATE", request, sender)
    return true
end

local function handle_request_updated(db, payload, sender)
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
        DELETE = "request_delete",
    }

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        report_request_sync_ignored(action, sender)
        return false
    end

    local capability = capabilityByAction[action]
    if capability and not actor_can(actorContext, capability, localPolicy) then
        report_request_sync_ignored(action, sender)
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_request_sync_ignored(action, sender)
        return false
    end

    local existing = find_request(db, request.requestId)
    if not existing then
        report_request_sync_ignored(action, sender)
        return false
    end

    if not immutable_request_fields_match(existing, request) then
        report_request_sync_ignored(action, sender)
        return false
    end

    if type(requestsModule.CanActorApplyAction) == "function" and not requestsModule.CanActorApplyAction(existing, action, actorContext) then
        report_request_sync_ignored(action, sender)
        return false
    end

    if type(requestsModule.CanActorApplyAction) ~= "function" and type(requestsModule.CanApplyAction) == "function" and not requestsModule.CanApplyAction(existing, action) then
        report_request_sync_ignored(action, sender)
        return false
    end

    local resolved = type(coordinator.ResolveRequestConflict) == "function" and coordinator.ResolveRequestConflict(existing, request) or nil
    if resolved and resolved ~= request then
        return true
    end

    local previousRequest = {}
    for key, value in pairs(existing or {}) do
        previousRequest[key] = value
    end

    if action == "DELETE" then
        local deleted = delete_request(db, request.requestId)
        if deleted then
            append_request_sync_audit(db, action, previousRequest, request, actorContext, payload.note)
            report_request_sync_applied(action, request, sender)
        end
        return deleted
    end

    upsert_request(db, request)
    append_request_sync_audit(db, action, previousRequest, request, actorContext, payload.note)
    sync_request_minimum_side_effect(db, action, request, actorContext)
    report_request_sync_applied(action, request, sender)
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
            report_sync_status(string.format("Sync hello sent for %s.", context.characterKey or (_G.UnitName("player") or "Unknown")))
        end

        return true
    end

    if event == "GUILD_MOTD" or event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" or event == "GUILD_RANKS_UPDATE" then
        local db = current_db()
        if type(permissions.RefreshPolicyFromGuild) == "function" then
            permissions.RefreshPolicyFromGuild(db)
        end
        if type(authPolicySource.PullPolicyFromGuildInfo) == "function" then
            authPolicySource.PullPolicyFromGuildInfo(db)
        end
        if event == "GUILD_ROSTER_UPDATE" then
            local mainFrame = ns.modules.mainFrame or {}
            if type(mainFrame.ResumePendingAuthPolicySave) == "function" then
                mainFrame:ResumePendingAuthPolicySave()
            end
            if type(mainFrame.ResumePendingBlacklistPopupWorkflow) == "function" then
                mainFrame:ResumePendingBlacklistPopupWorkflow()
            end
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
            return handle_auth_policy_snapshot(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "REQUEST_CREATED" then
            return handle_request_created(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "REQUEST_UPDATED" then
            return handle_request_updated(db, ns.state.lastSyncMessage.payload, sender)
        end

        return true
    end

    return false
end

ns.modules.syncEvents = syncEvents

return syncEvents
