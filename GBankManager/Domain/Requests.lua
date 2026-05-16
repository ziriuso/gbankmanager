local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local permissions = ns.modules.permissions

if permissions == nil and type(_G.dofile) == "function" then
    permissions = _G.dofile("GBankManager/Domain/Permissions.lua")
end

permissions = permissions or {}

local requests = ns.modules.requests or {}

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

local function build_request_id(input, context)
    local createdAt = input.createdAt or _G.time()
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

local function actor_context_for_action(actor, db)
    if type(actor) == "table" then
        return actor
    end

    return actor_context({
        requester = actor,
    }, db)
end

local function can_act(actor, capability, db)
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
        return approval == "APPROVED" and (fulfillment == "OPEN" or fulfillment == "SUGGESTED_FULFILLED")
    end

    if action == "REOPEN" then
        return fulfillment == "FULFILLED" or fulfillment == "SUGGESTED_FULFILLED"
    end

    if action == "EDIT" then
        return fulfillment ~= "FULFILLED"
    end

    return false
end

function requests.Create(input)
    input = input or {}
    local context = actor_context(input, input.db)
    local autoApproved = false
    if type(permissions.Can) == "function" then
        autoApproved = permissions.Can(context, "request_approve", input.auth or (input.db and input.db.auth))
    elseif type(permissions.AutoApprovesOwnRequests) == "function" then
        autoApproved = permissions.AutoApprovesOwnRequests(input.role)
    end

    local requesterName = context.name or input.requester

    return {
        requestId = input.requestId or build_request_id(input, context),
        requester = requesterName,
        requesterCharacterKey = context.characterKey or input.requesterCharacterKey,
        requesterRankName = context.guildRankName or input.role or "",
        requesterRankIndex = context.guildRankIndex,
        role = input.role or context.guildRankName,
        itemID = input.itemID,
        itemName = input.itemName,
        quantity = input.quantity,
        note = input.note or "",
        approval = autoApproved and "APPROVED" or "PENDING",
        fulfillment = "OPEN",
        createdAt = input.createdAt or _G.time(),
        createdBy = context.characterKey or requesterName,
        updatedAt = input.createdAt or _G.time(),
    }
end

function requests.Approve(request, approver, decidedAt)
    request.approval = "APPROVED"
    request.approvedBy = actor_name(approver)
    request.decidedBy = actor_name(approver)
    request.decidedAt = decidedAt or _G.time()
    request.updatedAt = request.decidedAt
    return request
end

function requests.Reject(request, actor, note, decidedAt)
    request.approval = "REJECTED"
    request.decidedBy = actor_name(actor)
    request.decisionNote = note or ""
    request.decidedAt = decidedAt or _G.time()
    request.updatedAt = request.decidedAt
    return request
end

function requests.MarkSuggestedFulfilled(request, updatedAt)
    request.fulfillment = "SUGGESTED_FULFILLED"
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
    request.updatedAt = request.fulfillmentUpdatedAt
    return request
end

function requests.MarkFulfilled(request, actor, updatedAt)
    request.fulfillment = "FULFILLED"
    request.fulfilledBy = actor_name(actor)
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
    request.updatedAt = request.fulfillmentUpdatedAt
    return request
end

function requests.Reopen(request, updatedAt)
    request.fulfillment = "OPEN"
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
    request.updatedAt = request.fulfillmentUpdatedAt
    return request
end

function requests.BuildAuditEntry(eventType, request, details)
    request = request or {}
    details = details or {}

    return {
        category = "REQUEST",
        type = eventType,
        actor = details.actor or request.decidedBy or request.approvedBy or request.fulfilledBy or request.requester or "Unknown",
        requestId = request.requestId,
        itemID = request.itemID,
        itemName = request.itemName,
        requester = request.requester,
        quantity = request.quantity,
        oldValue = details.oldValue,
        newValue = details.newValue,
        note = details.note or request.note or "",
        timestamp = details.timestamp or _G.time(),
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

function requests.ApproveStored(db, requestId, actor, decidedAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_approve", db) or not requests.CanApplyAction(request, "APPROVE") then
        return nil
    end

    local oldValue = request.approval
    requests.Approve(request, actor, decidedAt)
    append_audit(db, requests.BuildAuditEntry("REQUEST_APPROVED", request, {
        actor = actor,
        timestamp = request.decidedAt,
        oldValue = oldValue,
        newValue = request.approval,
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

function requests.ReopenStored(db, requestId, actor, updatedAt)
    db = ensure_tables(db or {})
    local request = find_request(db, requestId)
    if not request or not can_act(actor, "request_reopen", db) or not requests.CanApplyAction(request, "REOPEN") then
        return nil
    end

    local oldValue = request.fulfillment
    requests.Reopen(request, updatedAt)
    append_audit(db, requests.BuildAuditEntry("REQUEST_REOPENED", request, {
        actor = actor,
        timestamp = request.fulfillmentUpdatedAt,
        oldValue = oldValue,
        newValue = request.fulfillment,
    }))
    return request
end

ns.modules.requests = requests

return requests
