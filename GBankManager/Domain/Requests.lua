local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local permissions = ns.modules.permissions

if permissions == nil and type(_G.dofile) == "function" then
    permissions = _G.dofile("GBankManager/Domain/Permissions.lua")
end

permissions = permissions or {}

local requests = ns.modules.requests or {}

local function now()
    return type(_G.time) == "function" and _G.time() or 0
end

local function actor_context(input, db)
    local context = input and input.actorContext
    if type(context) == "table" then
        return context
    end

    if type(permissions.GetLivePlayerContext) == "function" then
        return permissions.GetLivePlayerContext(db)
    end

    return {
        name = input and input.requester or "Unknown",
        characterKey = input and input.requesterCharacterKey or tostring(input and input.requester or "Unknown"),
        guildRankName = input and input.role or "",
        guildRankIndex = nil,
        isGuildMaster = input and input.role == "GUILDMASTER" or false,
        inGuild = true,
    }
end

local function actor_name(actor)
    if type(actor) == "table" then
        return actor.name or actor.characterKey or "Unknown"
    end

    return actor or "Unknown"
end

local function actor_character_key(actor)
    if type(actor) == "table" then
        return actor.characterKey
    end

    return nil
end

local function actor_owns_request(request, actor)
    request = request or {}
    if type(actor) ~= "table" then
        return false
    end

    local actorKey = tostring(actor_character_key(actor) or "")
    local requesterKey = tostring(request.requesterCharacterKey or "")
    if actorKey ~= "" and requesterKey ~= "" then
        return actorKey == requesterKey
    end

    local name = tostring(actor.name or "")
    local requester = tostring(request.requester or "")
    return name ~= "" and requester ~= "" and name == requester
end

local function actor_is_guildmaster(actor)
    return type(actor) == "table" and actor.isGuildMaster == true
end

local function build_request_id(input, context)
    local createdAt = input.createdAt or now()
    return table.concat({
        tostring(createdAt or 0),
        tostring((context or {}).characterKey or input.requester or "Unknown"),
        tostring(input.itemID or 0),
        tostring(input.quantity or 0),
    }, "|")
end

local function ensure_tables(db)
    db.requests = db.requests or {}
    db.auditLog = db.auditLog or {}
    return db
end

local function find_request(db, requestId)
    for index, request in ipairs((db or {}).requests or {}) do
        if request.requestId == requestId then
            return request, index
        end
    end
end

local function append_audit(db, entry)
    ensure_tables(db)
    table.insert(db.auditLog, entry)
    return entry
end

local function copy_request(request)
    local copy = {}
    for key, value in pairs(request or {}) do
        copy[key] = value
    end
    return copy
end

local function actor_context_for_action(actor, db)
    if type(actor) == "table" then
        return actor
    end

    return actor_context({
        requester = actor,
    }, db)
end

local function can_act(actor, capability, db)
    if not db or db.auth == nil then
        return true
    end

    local context = actor_context_for_action(actor, db)
    if type(permissions.Can) == "function" then
        return permissions.Can(context, capability, db.auth)
    end

    return true
end

local function normalize_approval(value)
    return tostring(value or "PENDING")
end

local function normalize_fulfillment(value)
    return tostring(value or "OPEN")
end

function requests.CanApplyAction(request, action)
    request = request or {}
    action = tostring(action or "")

    local approval = normalize_approval(request.approval)
    local fulfillment = normalize_fulfillment(request.fulfillment)

    if action == "APPROVE" or action == "REJECT" then
        return approval == "PENDING"
    end

    if action == "FULFILL" then
        return approval == "APPROVED" and fulfillment == "OPEN"
    end

    if action == "REOPEN" then
        return fulfillment == "FULFILLED"
    end

    if action == "EDIT" then
        return fulfillment ~= "FULFILLED"
    end

    if action == "CANCEL" then
        return approval == "PENDING" and fulfillment ~= "FULFILLED"
    end

    if action == "DELETE" then
        return true
    end

    return false
end

function requests.CanActorApplyAction(request, action, actor)
    if not requests.CanApplyAction(request, action) then
        return false
    end

    if action == "APPROVE" and actor_owns_request(request, actor) and not actor_is_guildmaster(actor) then
        return false
    end

    if action == "CANCEL" then
        return actor_owns_request(request, actor)
    end

    return true
end

function requests.Create(input)
    input = input or {}
    local context = actor_context(input, input.db)
    local requesterName = context.name or input.requester
    local createdAt = input.createdAt or now()

    return {
        requestId = input.requestId or build_request_id(input, context),
        requester = requesterName,
        requesterCharacterKey = context.characterKey or input.requesterCharacterKey,
        requesterRankName = context.guildRankName or input.role or "",
        requesterRankIndex = context.guildRankIndex,
        role = input.role or context.guildRankName,
        itemID = input.itemID,
        itemName = input.itemName,
        itemLink = input.itemLink,
        itemString = input.itemString,
        craftedQuality = input.craftedQuality,
        craftedQualityIcon = input.craftedQualityIcon,
        craftedQualityMax = input.craftedQualityMax,
        craftedQualityFamilySize = input.craftedQualityFamilySize,
        craftedQualityDisplayAtlas = input.craftedQualityDisplayAtlas,
        craftedQualityPreferredAtlas = input.craftedQualityPreferredAtlas,
        quantity = input.quantity,
        tabName = input.tabName,
        preferredBankTab = input.preferredBankTab or input.tabName,
        note = input.note or "",
        approval = "PENDING",
        fulfillment = "OPEN",
        createdAt = createdAt,
        createdBy = context.characterKey or requesterName,
        updatedAt = createdAt,
        updatedBy = context.characterKey or requesterName,
        updatedByRankIndex = context.guildRankIndex,
    }
end

local function approval_metadata(noteOrDecidedAt, decidedAtOrBankTab, bankTab)
    if type(noteOrDecidedAt) == "number" and decidedAtOrBankTab == nil and bankTab == nil then
        return nil, noteOrDecidedAt, nil
    end

    if type(noteOrDecidedAt) == "number" and type(decidedAtOrBankTab) == "string" and bankTab == nil then
        return nil, noteOrDecidedAt, decidedAtOrBankTab
    end

    return noteOrDecidedAt, decidedAtOrBankTab, bankTab
end

function requests.Approve(request, approver, noteOrDecidedAt, decidedAtOrBankTab, bankTab)
    local note, decidedAt, selectedBankTab = approval_metadata(noteOrDecidedAt, decidedAtOrBankTab, bankTab)
    request.approval = "APPROVED"
    request.approvedBy = actor_name(approver)
    request.decidedBy = actor_name(approver)
    request.decisionNote = note or request.decisionNote or ""
    request.approvedBankTab = selectedBankTab or request.approvedBankTab
    request.tabName = selectedBankTab or request.tabName
    request.decidedAt = decidedAt or now()
    request.updatedAt = request.decidedAt
    request.updatedBy = actor_character_key(approver) or actor_name(approver)
    request.updatedByRankIndex = type(approver) == "table" and approver.guildRankIndex or request.updatedByRankIndex
    return request
end

function requests.Reject(request, actor, note, decidedAt)
    request.approval = "REJECTED"
    request.decidedBy = actor_name(actor)
    request.decisionNote = note or ""
    request.decidedAt = decidedAt or now()
    request.updatedAt = request.decidedAt
    request.updatedBy = actor_character_key(actor) or actor_name(actor)
    request.updatedByRankIndex = type(actor) == "table" and actor.guildRankIndex or request.updatedByRankIndex
    return request
end

function requests.MarkFulfilled(request, actor, updatedAt)
    request.fulfillment = "FULFILLED"
    request.fulfilledBy = actor_name(actor)
    request.fulfillmentUpdatedAt = updatedAt or now()
    request.updatedAt = request.fulfillmentUpdatedAt
    request.updatedBy = actor_character_key(actor) or actor_name(actor)
    request.updatedByRankIndex = type(actor) == "table" and actor.guildRankIndex or request.updatedByRankIndex
    return request
end

function requests.Reopen(request, updatedAt)
    request.fulfillment = "OPEN"
    request.fulfillmentUpdatedAt = updatedAt or now()
    request.updatedAt = request.fulfillmentUpdatedAt
    return request
end

function requests.Cancel(request, actor, note, canceledAt)
    request.approval = "CANCELED"
    request.canceledBy = actor_name(actor)
    request.decidedBy = actor_name(actor)
    request.decisionNote = note or ""
    request.canceledAt = canceledAt or now()
    request.updatedAt = request.canceledAt
    request.updatedBy = actor_character_key(actor) or actor_name(actor)
    request.updatedByRankIndex = type(actor) == "table" and actor.guildRankIndex or request.updatedByRankIndex
    return request
end

function requests.BuildAuditEntry(eventType, request, details)
    request = request or {}
    details = details or {}
    local auditActor = details.actor
    if auditActor == nil or auditActor == "" then
        auditActor = request.decidedBy or request.approvedBy or request.fulfilledBy or request.canceledBy or request.requester or "Unknown"
    end

    return {
        category = "REQUEST",
        type = eventType,
        actor = actor_name(auditActor),
        requestId = request.requestId,
        itemID = request.itemID,
        itemName = request.itemName,
        requester = request.requester,
        quantity = request.quantity,
        oldValue = details.oldValue,
        newValue = details.newValue,
        note = details.note or request.note or "",
        timestamp = details.timestamp or now(),
    }
end

function requests.CreateAndStore(db, input)
    db = ensure_tables(db or {})
    input = input or {}
    input.db = db
    input.auth = db.auth
    local request = requests.Create(input)
    table.insert(db.requests, request)
    append_audit(db, requests.BuildAuditEntry("REQUEST_CREATED", request, {
        actor = request.requester,
        timestamp = request.createdAt,
        newValue = request.approval,
        note = request.note,
    }))
    return request
end

function requests.ApproveStored(db, requestId, actor, noteOrDecidedAt, decidedAtOrBankTab, bankTab)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_approve", db) or not requests.CanActorApplyAction(request, "APPROVE", actor) then
        return nil
    end

    local note, decidedAt, selectedBankTab = approval_metadata(noteOrDecidedAt, decidedAtOrBankTab, bankTab)
    local oldValue = request.approval
    requests.Approve(request, actor, note, decidedAt, selectedBankTab)
    append_audit(db, requests.BuildAuditEntry("REQUEST_APPROVED", request, {
        actor = actor,
        timestamp = request.decidedAt,
        oldValue = oldValue,
        newValue = request.approval,
        note = note,
    }))
    return request
end

function requests.CancelStored(db, requestId, actor, note, canceledAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not requests.CanActorApplyAction(request, "CANCEL", actor) then
        return nil
    end

    local oldValue = request.approval
    requests.Cancel(request, actor, note, canceledAt)
    append_audit(db, requests.BuildAuditEntry("REQUEST_CANCELED", request, {
        actor = actor,
        timestamp = request.canceledAt,
        oldValue = oldValue,
        newValue = request.approval,
        note = note,
    }))
    return request
end

function requests.RejectStored(db, requestId, actor, note, decidedAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_reject", db) or not requests.CanApplyAction(request, "REJECT") then
        return nil
    end

    local oldValue = request.approval
    requests.Reject(request, actor, note, decidedAt)
    append_audit(db, requests.BuildAuditEntry("REQUEST_REJECTED", request, {
        actor = actor,
        timestamp = request.decidedAt,
        oldValue = oldValue,
        newValue = request.approval,
        note = note,
    }))
    return request
end

function requests.MarkFulfilledStored(db, requestId, actor, updatedAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_fulfill", db) or not requests.CanApplyAction(request, "FULFILL") then
        return nil
    end

    local oldValue = request.fulfillment
    requests.MarkFulfilled(request, actor, updatedAt)
    append_audit(db, requests.BuildAuditEntry("REQUEST_FULFILLED", request, {
        actor = actor,
        timestamp = request.fulfillmentUpdatedAt,
        oldValue = oldValue,
        newValue = request.fulfillment,
    }))
    return request
end

local function snapshot_item_total(snapshot, itemID)
    local items = (snapshot or {}).items or {}
    local item = items[itemID] or items[tonumber(itemID)]
    return tonumber((item or {}).totalCount or 0) or 0
end

function requests.AutoFulfillApprovedFromSnapshot(db, snapshot, actor, updatedAt)
    db = ensure_tables(db or {})
    local fulfilled = {}

    for _, request in ipairs(db.requests or {}) do
        local quantity = tonumber(request.quantity or 0) or 0
        if request.approval == "APPROVED"
            and request.fulfillment == "OPEN"
            and quantity > 0
            and snapshot_item_total(snapshot, request.itemID) >= quantity then
            local oldValue = request.fulfillment
            requests.MarkFulfilled(request, actor or "Bank Scan", updatedAt)
            append_audit(db, requests.BuildAuditEntry("REQUEST_FULFILLED", request, {
                actor = actor or "Bank Scan",
                timestamp = request.fulfillmentUpdatedAt,
                oldValue = oldValue,
                newValue = request.fulfillment,
            }))
            table.insert(fulfilled, request)
        end
    end

    return fulfilled
end

function requests.ReopenStored(db, requestId, actor, updatedAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_reopen", db) or not requests.CanApplyAction(request, "REOPEN") then
        return nil
    end

    local oldValue = request.fulfillment
    requests.Reopen(request, updatedAt)
    request.updatedBy = actor_character_key(actor) or actor_name(actor)
    request.updatedByRankIndex = type(actor) == "table" and actor.guildRankIndex or request.updatedByRankIndex
    append_audit(db, requests.BuildAuditEntry("REQUEST_REOPENED", request, {
        actor = actor,
        timestamp = request.fulfillmentUpdatedAt,
        oldValue = oldValue,
        newValue = request.fulfillment,
    }))
    return request
end

function requests.DeleteStored(db, requestId, actor, note, deletedAt)
    db = ensure_tables(db or {})
    local request, requestIndex = find_request(db, requestId)
    if not request or not requestIndex or not can_act(actor, "request_delete", db) or not requests.CanActorApplyAction(request, "DELETE", actor) then
        return nil
    end

    local deletedRequest = copy_request(request)
    deletedRequest.deletedBy = actor_name(actor)
    deletedRequest.decisionNote = note or deletedRequest.decisionNote or ""
    deletedRequest.deletedAt = deletedAt or now()
    deletedRequest.updatedAt = deletedRequest.deletedAt
    deletedRequest.updatedBy = actor_character_key(actor) or actor_name(actor)
    deletedRequest.updatedByRankIndex = type(actor) == "table" and actor.guildRankIndex or deletedRequest.updatedByRankIndex
    table.remove(db.requests, requestIndex)
    append_audit(db, requests.BuildAuditEntry("REQUEST_DELETED", deletedRequest, {
        actor = actor,
        timestamp = deletedRequest.deletedAt,
        oldValue = request.approval,
        newValue = "DELETED",
        note = deletedRequest.decisionNote,
    }))
    return deletedRequest
end

ns.modules.requests = requests

return requests
