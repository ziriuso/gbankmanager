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
local manualActions = ns.modules.syncManualActions or {}

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

local function guild_key_is_known(guildKey)
    local store = ns.data.store or ns.modules.store
    if store and type(store.IsPlaceholderGuildName) == "function" then
        return not store.IsPlaceholderGuildName(guildKey)
    end

    local normalized = tostring(guildKey or ""):match("^%s*(.-)%s*$")
    return normalized ~= "" and normalized ~= "Unknown" and normalized ~= "Unknown Guild"
end

local function current_policy(db)
    local store = ns.data.store or ns.modules.store
    return store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or (db or {}).auth or {}
end

local function active_guild_key(db)
    local root = (ns.state or {}).dbRoot
    local rootGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if guild_key_is_known(rootGuildKey) then
        return rootGuildKey
    end

    local dbGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    if guild_key_is_known(dbGuildKey) then
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

local function normalize_character_key(value, realmName, nameHint)
    if type(permissions.NormalizeCharacterKey) == "function" then
        return permissions.NormalizeCharacterKey(value, realmName, nameHint)
    end

    return tostring(value or "")
end

local function character_name_from_key(characterKey, realmName, nameHint)
    if type(permissions.GetCharacterNameFromKey) == "function" then
        return tostring(permissions.GetCharacterNameFromKey(characterKey, realmName, nameHint) or "")
    end

    local normalized = tostring(characterKey or "")
    return normalized:match("^([^%-]+)") or normalized
end

local normalize_request_for_sync

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

    local actorCharacterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
    local requesterCharacterKey = normalize_character_key(request.requesterCharacterKey, actorContext.realmName, request.requester)
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

    local actorCharacterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
    local normalizedSenderKey = normalize_character_key(sender)
    if actorCharacterKey ~= "" and actorCharacterKey ~= normalizedSenderKey then
        local actorKeyCharacter = character_name_from_key(actorCharacterKey, actorContext.realmName, actorContext.name)
        if actorKeyCharacter ~= sender and actorKeyCharacter ~= senderName then
            return false
        end
    end

    return true
end

local function normalize_actor_context(actorContext)
    actorContext = type(actorContext) == "table" and actorContext or {}
    actorContext.characterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
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
    local contextCharacterKey = normalize_character_key(context.characterKey, context.realmName, contextName)
    local normalizedSenderKey = normalize_character_key(sender)
    if sender == contextName or normalizedSenderKey == contextCharacterKey then
        return true
    end

    local senderName = sender:match("^([^%-]+)") or sender
    if senderName ~= "" and (senderName == contextName or senderName == character_name_from_key(contextCharacterKey, context.realmName, contextName)) then
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
    local localCharacterKey = normalize_character_key(liveContext.characterKey, liveContext.realmName, liveContext.name)
    local localName = tostring(liveContext.name or "")
    local actorCharacterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
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
        local existingValue = existing[key]
        local incomingValue = incoming[key]
        if key == "requesterCharacterKey" then
            existingValue = normalize_character_key(existingValue, nil, existing.requester)
            incomingValue = normalize_character_key(incomingValue, nil, incoming.requester)
        end
        if incoming[key] ~= nil and existingValue ~= incomingValue then
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

local function remember_sync_decision(message, sender, payload, accepted, category, reason)
    message = type(message) == "table" and message or {}
    payload = type(payload) == "table" and payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}

    ns.state.lastSyncDecision = {
        accepted = accepted == true,
        category = tostring(category or ""),
        reason = tostring(reason or ""),
        sender = tostring(sender or ""),
        distribution = tostring(message.distribution or ""),
        messageType = tostring(message.type or ""),
        guildKey = tostring(payload.guildKey or ""),
        actorName = tostring(actorContext.name or ""),
        actorCharacterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name),
        peerCharacterKey = normalize_character_key(actorContext.characterKey or (message.type == "SYNC_HELLO" and message.payload) or sender or "", actorContext.realmName, actorContext.name),
        updatedAt = tonumber(message.updatedAt or 0) or 0,
    }

    return ns.state.lastSyncDecision
end

local function touch_sync_peer(db, message, sender)
    if type(peerState.TouchPeer) ~= "function" then
        return nil
    end

    message = type(message) == "table" and message or {}
    local payload = type(message.payload) == "table" and message.payload or {}
    local actorContext = type(payload.actorContext) == "table" and payload.actorContext or {}
    local characterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
    if characterKey == "" and message.type == "SYNC_HELLO" and type(message.payload) == "string" then
        characterKey = normalize_character_key(message.payload)
    end
    if characterKey == "" then
        characterKey = normalize_character_key(sender)
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
    local characterKey = normalize_character_key(actorContext.characterKey, actorContext.realmName, actorContext.name)
    if characterKey == "" and message.type == "SYNC_HELLO" and type(message.payload) == "string" then
        characterKey = normalize_character_key(message.payload)
    end
    if characterKey == "" then
        characterKey = normalize_character_key(sender)
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

local function refresh_sync_peer_view()
    local mainFrame = ns.modules.mainFrame or {}
    if type(mainFrame.RefreshSyncControls) ~= "function" then
        return
    end

    if type(mainFrame.optionsSyncTableScrollChild) ~= "table" then
        return
    end

    if tostring(mainFrame.activeView or "") ~= "OPTIONS" or tostring(mainFrame.optionsActiveTab or "") ~= "SYNC" then
        return
    end

    mainFrame:RefreshSyncControls()
end

local function refresh_visible_sync_views()
    local mainFrame = ns.modules.mainFrame or {}
    if type(mainFrame.RefreshView) ~= "function" then
        return
    end

    local activeView = tostring(mainFrame.activeView or "")
    if activeView == "HISTORY" or activeView == "REQUESTS" or activeView == "MINIMUMS" then
        mainFrame:RefreshView()
    end
end

local function send_visible_history_snapshot(db, actorContext, updatedAt)
    local historyView = ns.modules.historyView or {}
    if type(transport.Send) ~= "function" or type(historyView.BuildSyncSnapshot) ~= "function" then
        return false
    end

    transport.Send("GUILD", "GUILD", {
        type = "HISTORY_SNAPSHOT",
        updatedAt = tonumber(updatedAt or (_G.time and _G.time() or 0)) or 0,
        payload = {
            guildKey = active_guild_key(db),
            actorContext = type(actorContext) == "table" and actorContext or {},
            entries = historyView.BuildSyncSnapshot((db or {}).auditLog or {}),
        },
    })
    return true
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

local function minimum_rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local function append_minimum_sync_audit(db, eventType, rule, actorContext, timestamp, oldValue, newValue)
    rule = type(rule) == "table" and rule or {}
    return append_audit_entry(db, {
        category = "MINIMUM",
        type = tostring(eventType or ""),
        actor = tostring((actorContext or {}).name or (actorContext or {}).characterKey or "Unknown"),
        itemID = tonumber(rule.itemID),
        itemName = tostring(rule.itemName or "Unknown"),
        oldValue = oldValue,
        newValue = newValue,
        timestamp = tonumber(timestamp or _G.time()) or 0,
    })
end

local function append_minimums_snapshot_audit(db, previousMinimums, nextMinimums, actorContext, timestamp)
    previousMinimums = clone_array_records(previousMinimums)
    nextMinimums = clone_array_records(nextMinimums)

    local previousByKey = {}
    local nextByKey = {}

    for _, rule in ipairs(previousMinimums or {}) do
        previousByKey[minimum_rule_key(rule)] = rule
    end

    for _, rule in ipairs(nextMinimums or {}) do
        nextByKey[minimum_rule_key(rule)] = rule
    end

    for ruleKey, nextRule in pairs(nextByKey) do
        local previousRule = previousByKey[ruleKey]
        if not previousRule then
            append_minimum_sync_audit(db, "MINIMUM_CREATED", nextRule, actorContext, timestamp, nil, tostring(nextRule.quantity or 0))
        else
            local previousQuantity = tonumber(previousRule.quantity or 0) or 0
            local nextQuantity = tonumber(nextRule.quantity or 0) or 0
            if previousQuantity ~= nextQuantity then
                append_minimum_sync_audit(db, "MINIMUM_UPDATED", nextRule, actorContext, timestamp, tostring(previousQuantity), tostring(nextQuantity))
            end

            local previousEnabled = previousRule.enabled ~= false
            local nextEnabled = nextRule.enabled ~= false
            if previousEnabled ~= nextEnabled then
                append_minimum_sync_audit(
                    db,
                    nextEnabled and "MINIMUM_ENABLED" or "MINIMUM_DISABLED",
                    nextRule,
                    actorContext,
                    timestamp,
                    previousEnabled and "ENABLED" or "DISABLED",
                    nextEnabled and "ENABLED" or "DISABLED"
                )
            end
        end
    end

    for ruleKey, previousRule in pairs(previousByKey) do
        if not nextByKey[ruleKey] then
            append_minimum_sync_audit(db, "MINIMUM_REMOVED", previousRule, actorContext, timestamp, tostring(previousRule.quantity or 0), "REMOVED")
        end
    end
end

local function request_snapshot_action(previousRequest, nextRequest)
    previousRequest = type(previousRequest) == "table" and previousRequest or nil
    nextRequest = type(nextRequest) == "table" and nextRequest or {}
    if not previousRequest then
        return "CREATE"
    end

    local previousApproval = tostring(previousRequest.approval or "")
    local nextApproval = tostring(nextRequest.approval or "")
    if previousApproval ~= nextApproval then
        if nextApproval == "APPROVED" then
            return "APPROVE"
        end
        if nextApproval == "REJECTED" then
            return "REJECT"
        end
        if nextApproval == "CANCELED" then
            return "CANCEL"
        end
    end

    local previousFulfillment = tostring(previousRequest.fulfillment or "")
    local nextFulfillment = tostring(nextRequest.fulfillment or "")
    if previousFulfillment ~= nextFulfillment then
        if nextFulfillment == "FULFILLED" then
            return "FULFILL"
        end
        if nextFulfillment == "OPEN" then
            return "REOPEN"
        end
    end

    for _, key in ipairs({
        "itemID",
        "itemName",
        "quantity",
        "note",
        "approvedBankTab",
        "tabName",
        "approval",
        "fulfillment",
        "updatedAt",
    }) do
        if previousRequest[key] ~= nextRequest[key] then
            return "EDIT"
        end
    end

    return nil
end

normalize_request_for_sync = function(request)
    request = type(request) == "table" and request or {}
    request.requesterCharacterKey = normalize_character_key(request.requesterCharacterKey, nil, request.requester)
    if type(request.updatedBy) == "string" and string.find(request.updatedBy, "-", 1, true) then
        request.updatedBy = normalize_character_key(request.updatedBy)
    end
    return request
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
    local request = type(payload.request) == "table" and normalize_request_for_sync(payload.request) or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_create", "wrong_guild")
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_create", request and "blacklisted" or "missing_request")
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not actor_can(actorContext, "request_submit", localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_create", "capability_denied")
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_create", "actor_sender_mismatch")
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    if not requester_matches_actor(actorContext, request) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_create", "requester_actor_mismatch")
        report_request_sync_ignored("CREATE", sender)
        return false
    end

    local existing = find_request(db, request.requestId)
    if existing and not request_is_newer(request, existing) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "request_create", "stale_duplicate")
        return true
    end

    local previousRequest = existing and find_request(db, request.requestId) or nil
    upsert_request(db, request)
    append_request_sync_audit(db, "CREATE", previousRequest, request, actorContext, request.note)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "request_create", "applied")
    report_request_sync_applied("CREATE", request, sender)
    return true
end

local function handle_request_updated(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local request = type(payload.request) == "table" and normalize_request_for_sync(payload.request) or nil
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
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "wrong_guild")
        report_request_sync_ignored(action, sender)
        return false
    end

    if not request or permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", request and "blacklisted" or "missing_request")
        report_request_sync_ignored(action, sender)
        return false
    end

    local capability = capabilityByAction[action]
    if capability and not actor_can(actorContext, capability, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "capability_denied")
        report_request_sync_ignored(action, sender)
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "actor_sender_mismatch")
        report_request_sync_ignored(action, sender)
        return false
    end

    local existing = find_request(db, request.requestId)
    if not existing then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "missing_local_request")
        report_request_sync_ignored(action, sender)
        return false
    end

    if not immutable_request_fields_match(existing, request) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "immutable_field_mismatch")
        report_request_sync_ignored(action, sender)
        return false
    end

    if type(requestsModule.CanActorApplyAction) == "function" and not requestsModule.CanActorApplyAction(existing, action, actorContext) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "invalid_transition")
        report_request_sync_ignored(action, sender)
        return false
    end

    if type(requestsModule.CanActorApplyAction) ~= "function" and type(requestsModule.CanApplyAction) == "function" and not requestsModule.CanApplyAction(existing, action) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "request_update", "invalid_transition")
        report_request_sync_ignored(action, sender)
        return false
    end

    local resolved = type(coordinator.ResolveRequestConflict) == "function" and coordinator.ResolveRequestConflict(existing, request) or nil
    if resolved and resolved ~= request then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "request_update", "conflict_kept_local")
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
            remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "request_update", "applied")
            report_request_sync_applied(action, request, sender)
        end
        return deleted
    end

    upsert_request(db, request)
    append_request_sync_audit(db, action, previousRequest, request, actorContext, payload.note)
    sync_request_minimum_side_effect(db, action, request, actorContext)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "request_update", "applied")
    report_request_sync_applied(action, request, sender)
    return true
end

local function handle_minimums_snapshot(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local minimums = type(payload.minimums) == "table" and payload.minimums or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "minimums_snapshot", "wrong_guild")
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if minimums == nil or permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "minimums_snapshot", minimums and "blacklisted" or "missing_minimums")
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "minimums_snapshot", "actor_sender_mismatch")
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_can_manage_minimums(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "minimums_snapshot", "capability_denied")
        report_sync_status(string.format("Ignored synced minimums from %s.", sender_display_name(sender)))
        return false
    end

    local previousMinimums = clone_array_records(db.minimums or {})
    db.minimums = clone_array_records(minimums)
    append_minimums_snapshot_audit(db, previousMinimums, db.minimums, actorContext, payload.updatedAt or ns.state.lastSyncMessage.updatedAt)
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "minimums_snapshot", "applied")
    report_sync_status(string.format("Synced minimums from %s.", sender_display_name(sender)))
    return true
end

local function handle_requests_snapshot(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local requests = type(payload.requests) == "table" and payload.requests or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "requests_snapshot", "wrong_guild")
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if requests == nil or permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "requests_snapshot", requests and "blacklisted" or "missing_requests")
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "requests_snapshot", "actor_sender_mismatch")
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_can(actorContext, "request_submit", localPolicy)
        and not actor_can(actorContext, "request_approve", localPolicy)
        and not actor_can(actorContext, "full_ui", localPolicy)
    then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "requests_snapshot", "capability_denied")
        report_sync_status(string.format("Ignored synced requests snapshot from %s.", sender_display_name(sender)))
        return false
    end

    local mergedCount = 0
    for _, request in ipairs(requests) do
        if type(request) == "table" and tostring(request.requestId or "") ~= "" then
            request = normalize_request_for_sync(request)
            local existing = find_request(db, request.requestId)
            if not existing then
                upsert_request(db, request)
                append_request_sync_audit(db, "CREATE", nil, request, actorContext, request.note)
                mergedCount = mergedCount + 1
            elseif immutable_request_fields_match(existing, request) then
                local resolved = type(coordinator.ResolveRequestConflict) == "function" and coordinator.ResolveRequestConflict(existing, request) or request
                if resolved == request then
                    local previousRequest = {}
                    for key, value in pairs(existing or {}) do
                        previousRequest[key] = value
                    end
                    upsert_request(db, request)
                    local action = request_snapshot_action(previousRequest, request)
                    if action then
                        append_request_sync_audit(db, action, previousRequest, request, actorContext, request.note)
                    end
                    mergedCount = mergedCount + 1
                end
            end
        end
    end

    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "requests_snapshot", "applied")
    report_sync_status(string.format("Synced %d request snapshot row(s) from %s.", mergedCount, sender_display_name(sender)))
    return true
end

local function actor_can_sync_history(context, policy)
    return actor_can(context, "request_submit", policy)
        or actor_can(context, "request_approve", policy)
        or actor_can_manage_minimums(context, policy)
        or actor_can(context, "auth_manage", policy)
        or actor_can(context, "full_ui", policy)
end

local function handle_history_snapshot(db, payload, sender)
    local historyView = ns.modules.historyView or {}
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local entries = type(payload.entries) == "table" and payload.entries or nil
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "history_snapshot", "wrong_guild")
        report_sync_status(string.format("Ignored synced history snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if entries == nil or permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "history_snapshot", entries and "blacklisted" or "missing_history")
        report_sync_status(string.format("Ignored synced history snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "history_snapshot", "actor_sender_mismatch")
        report_sync_status(string.format("Ignored synced history snapshot from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_can_sync_history(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "history_snapshot", "capability_denied")
        report_sync_status(string.format("Ignored synced history snapshot from %s.", sender_display_name(sender)))
        return false
    end

    local mergedCount = type(historyView.MergeSyncSnapshot) == "function" and historyView.MergeSyncSnapshot(db.auditLog or {}, entries) or 0
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "history_snapshot", mergedCount > 0 and "applied" or "no_change")
    report_sync_status(string.format("Synced %d history row(s) from %s.", mergedCount, sender_display_name(sender)))
    return true
end

local function handle_ledger_delta(db, payload, sender)
    payload = type(payload) == "table" and payload or {}
    local actorContext = normalize_actor_context(payload.actorContext)
    local localPolicy = current_policy(db)

    if not request_targets_active_guild(db, payload.guildKey) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "ledger_delta", "wrong_guild")
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if permissions.IsBlacklisted(actorContext, localPolicy) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "ledger_delta", "blacklisted")
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if not actor_matches_sender(actorContext, sender) then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "ledger_delta", "actor_sender_mismatch")
        report_sync_status(string.format("Ignored synced ledger delta from %s.", sender_display_name(sender)))
        return false
    end

    if type(bankLedger.MergeRemoteDelta) ~= "function" then
        remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "ledger_delta", "merge_unavailable")
        return false
    end

    local mergedCount = tonumber(bankLedger.MergeRemoteDelta(db, payload) or 0) or 0
    mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
    remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "ledger_delta", mergedCount > 0 and "applied" or "no_change")
    if mergedCount > 0 then
        report_sync_status(string.format("Synced ledger delta from %s.", sender_display_name(sender)))
    end
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
        local preferredGuildKey = type((ns.state.lastSyncMessage or {}).payload) == "table" and ns.state.lastSyncMessage.payload.guildKey or nil
        local store = ns.data.store or ns.modules.store
        local db = store and type(store.GetDatabase) == "function"
            and store.GetDatabase(preferredGuildKey)
            or current_db()
        if message_is_from_local_player(db, ns.state.lastSyncMessage, sender) then
            remember_sync_decision(ns.state.lastSyncMessage, sender, ns.state.lastSyncMessage.payload, false, "sync_receive", "self_origin")
            return false
        end
        touch_sync_peer(db, ns.state.lastSyncMessage, sender)
        if ns.state.lastSyncMessage.type == "SYNC_HELLO" then
            local liveContext = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
            local manualSyncActions = ns.modules.syncManualActions or manualActions or {}
            local accessProfile = type(permissions.GetEffectiveAccessProfile) == "function"
                and permissions.GetEffectiveAccessProfile(liveContext, current_policy(db))
                or "full_shell"
            local defaultAction = type(manualSyncActions.ResolveDefaultAction) == "function"
                and manualSyncActions.ResolveDefaultAction(accessProfile)
                or (accessProfile == "request_only" and "requests" or "all")
            local syncTriggered = false
            if accessProfile ~= "blocked" and type(manualSyncActions.Run) == "function" then
                local result = manualSyncActions.Run(db, {
                    action = defaultAction,
                    accessProfile = accessProfile,
                    now = tonumber(ns.state.lastSyncMessage.updatedAt or (_G.time and _G.time() or 0)) or 0,
                    skipCooldown = true,
                })
                syncTriggered = type(result) == "table" and result.ok == true
            end
            if not syncTriggered and accessProfile ~= "blocked" then
                send_visible_history_snapshot(db, liveContext, ns.state.lastSyncMessage.updatedAt)
                syncTriggered = true
            end
            if syncTriggered then
                mark_sync_peer_synchronized(db, ns.state.lastSyncMessage, sender)
            end
            refresh_sync_peer_view()
            return true
        end
        if ns.state.lastSyncMessage.type == "AUTH_POLICY_SNAPSHOT" then
            remember_sync_decision(ns.state.lastSyncMessage, sender, ns.state.lastSyncMessage.payload, false, "auth_policy_snapshot", "retired_message_type")
            report_sync_status("Ignored retired auth policy snapshot message.")
            refresh_sync_peer_view()
            return false
        end

        if ns.state.lastSyncMessage.type == "REQUEST_CREATED" then
            local accepted = handle_request_created(db, ns.state.lastSyncMessage.payload, sender)
            refresh_visible_sync_views()
            refresh_sync_peer_view()
            return accepted
        end

        if ns.state.lastSyncMessage.type == "REQUEST_UPDATED" then
            local accepted = handle_request_updated(db, ns.state.lastSyncMessage.payload, sender)
            refresh_visible_sync_views()
            refresh_sync_peer_view()
            return accepted
        end

        if ns.state.lastSyncMessage.type == "MINIMUMS_SNAPSHOT" then
            local accepted = handle_minimums_snapshot(db, ns.state.lastSyncMessage.payload, sender)
            refresh_visible_sync_views()
            refresh_sync_peer_view()
            return accepted
        end

        if ns.state.lastSyncMessage.type == "REQUESTS_SNAPSHOT" then
            local accepted = handle_requests_snapshot(db, ns.state.lastSyncMessage.payload, sender)
            refresh_visible_sync_views()
            refresh_sync_peer_view()
            return accepted
        end

        if ns.state.lastSyncMessage.type == "HISTORY_SNAPSHOT" then
            local accepted = handle_history_snapshot(db, ns.state.lastSyncMessage.payload, sender)
            refresh_visible_sync_views()
            refresh_sync_peer_view()
            return accepted
        end

        if ns.state.lastSyncMessage.type == "LEDGER_DELTA" then
            local accepted = handle_ledger_delta(db, ns.state.lastSyncMessage.payload, sender)
            refresh_sync_peer_view()
            return accepted
        end

        refresh_sync_peer_view()
        return true
    end

    return false
end

ns.modules.syncEvents = syncEvents

return syncEvents
