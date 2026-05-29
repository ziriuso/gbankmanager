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
local bankLedger = ns.modules.bankLedger or {}
local peerState = ns.modules.syncPeerState or {}

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

local function active_guild_key(db)
    local root = (ns.state or {}).dbRoot
    local rootGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if rootGuildKey ~= "" and rootGuildKey ~= "Unknown" then
        return rootGuildKey
    end

    local dbGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    if dbGuildKey ~= "" and dbGuildKey ~= "Unknown" then
        return dbGuildKey
    end

    local context = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
    return tostring(context.guildName or "Unknown")
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

local function normalize_actor_context(actorContext)
    actorContext = type(actorContext) == "table" and actorContext or {}
    if actorContext.inGuild == nil then
        actorContext.inGuild = true
    end
    return actorContext
end

local function sender_matches_context(context, sender)
    context = type(context) == "table" and context or {}
    sender = tostring(sender or "")
    if sender == "" then
        return false
    end

    local contextName = tostring(context.name or "")
    local contextCharacterKey = tostring(context.characterKey or "")
    if sender == contextName or sender == contextCharacterKey then
        return true
    end

    local senderName = sender:match("^([^%-]+)") or sender
    if senderName ~= "" and senderName == contextName then
        return true
    end

    return false
end

local function message_is_from_local_player(db, message, sender)
    local liveContext = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
    if sender_matches_context(liveContext, sender) then
        return true
    end

    message = type(message) == "table" and message or {}
    local payload = type(message.payload) == "table" and message.payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local localCharacterKey = tostring(liveContext.characterKey or "")
    local localName = tostring(liveContext.name or "")
    local actorCharacterKey = tostring(actorContext.characterKey or "")
    local actorName = tostring(actorContext.name or "")

    if actorCharacterKey ~= "" and actorCharacterKey == localCharacterKey then
        return true
    end

    if actorName ~= "" and actorName == localName then
        return true
    end

    if message.type == "SYNC_HELLO" and type(message.payload) == "string" then
        local helloPayload = tostring(message.payload or "")
        if helloPayload ~= "" and (helloPayload == localCharacterKey or helloPayload == localName) then
            return true
        end
    end

    return false
end

local function request_targets_active_guild(db, guildKey)
    guildKey = tostring(guildKey or "")
    if guildKey == "" then
        return false
    end

    return guildKey == active_guild_key(db)
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
    if type(permissions.Can) == "function" then
        return permissions.Can(context or {}, capability, policy)
    end

    return true
end

local function actor_can_manage_minimums(context, policy)
    return actor_can(context, "minimum_add", policy)
        or actor_can(context, "minimum_edit", policy)
        or actor_can(context, "minimum_delete", policy)
end

local function clone_array_records(records)
    local out = {}
    for _, record in ipairs(records or {}) do
        local copy = {}
        for key, value in pairs(record or {}) do
            copy[key] = value
        end
        out[#out + 1] = copy
    end
    return out
end

local function payload_version(payload)
    payload = type(payload) == "table" and payload or {}
    if type(payload.version) == "string" and payload.version ~= "" then
        return payload.version
    end

    if type(payload.payload) == "table" and type(payload.payload.version) == "string" and payload.payload.version ~= "" then
        return payload.payload.version
    end

    return ""
end

local function touch_sync_peer(db, message, sender)
    if type(peerState.TouchPeer) ~= "function" then
        return nil
    end

    message = type(message) == "table" and message or {}
    local payload = type(message.payload) == "table" and message.payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local characterKey = tostring(actorContext.characterKey or "")
    if characterKey == "" and message.type == "SYNC_HELLO" and type(message.payload) == "string" then
        characterKey = tostring(message.payload or "")
    end
    if characterKey == "" then
        local senderName = tostring(sender or "")
        characterKey = senderName
    end

    local guildKey = tostring(payload.guildKey or active_guild_key(db))
    return peerState.TouchPeer(db, {
        guildKey = guildKey,
        characterKey = characterKey,
        messageType = tostring(message.type or ""),
        seenAt = tonumber(message.updatedAt or (_G.time and _G.time() or 0)) or 0,
        version = payload_version(message),
    })
end

local function mark_sync_peer_synchronized(db, message, sender)
    if type(peerState.MarkSynchronized) ~= "function" then
        return nil
    end

    message = type(message) == "table" and message or {}
    local payload = type(message.payload) == "table" and message.payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local characterKey = tostring(actorContext.characterKey or "")
    if characterKey == "" then
        characterKey = tostring(sender or "")
    end

    local guildKey = tostring(payload.guildKey or active_guild_key(db))
    return peerState.MarkSynchronized(db, {
        guildKey = guildKey,
        characterKey = characterKey,
        messageType = tostring(message.type or ""),
        seenAt = tonumber(message.updatedAt or (_G.time and _G.time() or 0)) or 0,
        synchronizedAt = tonumber(message.updatedAt or (_G.time and _G.time() or 0)) or 0,
        version = payload_version(message),
    })
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
    local actorContext = normalize_actor_context(payload.actorContext)
    local request = type(payload.request) == "table" and payload.request or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        report_request_sync_ignored("CREATE", sender)
        return false
    end

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
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    report_request_sync_applied("CREATE", request, sender)
    return true
end

local function handle_request_updated(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
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

    if not request_targets_active_guild(db, payload.guildKey) then
        report_request_sync_ignored(action, sender)
        return false
    end

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
            mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
            report_request_sync_applied(action, request, sender)
        end
        return deleted
    end

    upsert_request(db, request)
    append_request_sync_audit(db, action, previousRequest, request, actorContext, payload.note)
    sync_request_minimum_side_effect(db, action, request, actorContext)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    report_request_sync_applied(action, request, sender)
    return true
end

local function handle_minimums_snapshot(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local minimums = type(payload.minimums) == "table" and payload.minimums or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if minimums == nil or permissions.IsBlacklisted(actorContext, localPolicy) then
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_can_manage_minimums(actorContext, localPolicy) then
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    db.minimums = clone_array_records(minimums)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    report_sync_status(string.format("Synced minimums from %s.", sender_display_name(sender)))
    return true
end

local function handle_requests_snapshot(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local requests = type(payload.requests) == "table" and payload.requests or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if requests == nil or permissions.IsBlacklisted(actorContext, localPolicy) then
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_can(actorContext, "request_submit", localPolicy)
        and not actor_can(actorContext, "request_approve", localPolicy)
        and not actor_can(actorContext, "full_ui", localPolicy)
    then
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    local mergedCount = 0
    for _, request in ipairs(requests) do
        if type(request) == "table" and tostring(request.requestId or "") ~= "" then
            local existing = find_request(db, request.requestId)
            if not existing then
                upsert_request(db, request)
                mergedCount = mergedCount + 1
            elseif immutable_request_fields_match(existing, request) then
                local resolved = type(coordinator.ResolveRequestConflict) == "function" and coordinator.ResolveRequestConflict(existing, request) or request
                if resolved == request then
                    upsert_request(db, request)
                    mergedCount = mergedCount + 1
                end
            end
        end
    end

    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    report_sync_status(string.format("Synced %d request snapshot row(s) from %s.", mergedCount, sender_display_name(sender)))
    return true
end

local function handle_ledger_delta(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if permissions.IsBlacklisted(actorContext, localPolicy) then
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if type(bankLedger.MergeRemoteDelta) ~= "function" then
        return false
    end

    bankLedger.MergeRemoteDelta(db, payload)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    report_sync_status(string.format("Synced ledger delta from %s.", sender_display_name(sender)))
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
        local mainFrame = ns.modules.mainFrame or {}
        if type(mainFrame.RefreshSidebarIdentity) == "function" then
            mainFrame:RefreshSidebarIdentity()
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
        local mainFrame = ns.modules.mainFrame or {}
        if type(mainFrame.RefreshSidebarIdentity) == "function" then
            mainFrame:RefreshSidebarIdentity()
        end
        if event == "GUILD_ROSTER_UPDATE" then
            if type(mainFrame.OnGuildRosterRefresh) == "function" then
                mainFrame:OnGuildRosterRefresh()
            end
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
        if tostring(distribution or "") ~= "GUILD" then
            return false
        end

        local payloadPrefix = tostring(payload or ""):sub(1, 1)
        local isChunkPayload = payloadPrefix == string.char(1)
            or payloadPrefix == string.char(2)
            or payloadPrefix == string.char(3)
        local rawDecodedMessage = not isChunkPayload and codec.DecodeTable(payload) or nil
        local decodedMessage = rawDecodedMessage
        local receiveState = rawDecodedMessage and "complete" or nil
        if type(transport.Receive) == "function" then
            local queuedDecodedMessage, queuedReceiveState = transport.Receive(payload, distribution, sender)
            if rawDecodedMessage and queuedDecodedMessage then
                local rawEncoded = codec.EncodeTable(rawDecodedMessage)
                local queuedEncoded = codec.EncodeTable(queuedDecodedMessage)
                decodedMessage = rawEncoded == queuedEncoded and queuedDecodedMessage or rawDecodedMessage
                receiveState = "complete"
            elseif rawDecodedMessage then
                decodedMessage = rawDecodedMessage
                receiveState = "complete"
            else
                decodedMessage = queuedDecodedMessage
                receiveState = queuedReceiveState
            end
        end

        if not decodedMessage then
            return receiveState == "partial" or receiveState == "invalid"
        end

        ns.state.lastSyncMessage = decodedMessage
        ns.state.lastSyncMessage.distribution = distribution
        ns.state.lastSyncMessage.sender = sender
        local db = current_db()
        if message_is_from_local_player(db, ns.state.lastSyncMessage, sender) then
            return false
        end
        touch_sync_peer(db, ns.state.lastSyncMessage, sender)
        if ns.state.lastSyncMessage.type == "AUTH_POLICY_SNAPSHOT" then
            report_sync_status("Ignored retired auth policy snapshot message.")
            return false
        end

        if ns.state.lastSyncMessage.type == "REQUEST_CREATED" then
            return handle_request_created(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "REQUEST_UPDATED" then
            return handle_request_updated(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "MINIMUMS_SNAPSHOT" then
            return handle_minimums_snapshot(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "REQUESTS_SNAPSHOT" then
            return handle_requests_snapshot(db, ns.state.lastSyncMessage.payload, sender)
        end

        if ns.state.lastSyncMessage.type == "LEDGER_DELTA" then
            return handle_ledger_delta(db, ns.state.lastSyncMessage.payload, sender)
        end

        return true
    end

    return false
end

ns.modules.syncEvents = syncEvents

return syncEvents
