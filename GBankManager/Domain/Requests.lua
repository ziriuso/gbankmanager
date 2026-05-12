local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local permissions = ns.modules.permissions

if permissions == nil and type(_G.dofile) == "function" then
    permissions = _G.dofile("GBankManager/Domain/Permissions.lua")
end

permissions = permissions or {}

local requests = ns.modules.requests or {}

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

function requests.Create(input)
    input = input or {}

    local autoApproved = false
    if type(permissions.AutoApprovesOwnRequests) == "function" then
        autoApproved = permissions.AutoApprovesOwnRequests(input.role)
    end

    return {
        requestId = input.requestId or tostring(_G.time()),
        requester = input.requester,
        role = input.role,
        itemID = input.itemID,
        itemName = input.itemName,
        quantity = input.quantity,
        note = input.note or "",
        approval = autoApproved and "APPROVED" or "PENDING",
        fulfillment = "OPEN",
        createdAt = input.createdAt or _G.time(),
    }
end

function requests.Approve(request, approver, decidedAt)
    request.approval = "APPROVED"
    request.approvedBy = approver
    request.decidedBy = approver
    request.decidedAt = decidedAt or _G.time()
    return request
end

function requests.Reject(request, actor, note, decidedAt)
    request.approval = "REJECTED"
    request.decidedBy = actor
    request.decisionNote = note or ""
    request.decidedAt = decidedAt or _G.time()
    return request
end

function requests.MarkSuggestedFulfilled(request, updatedAt)
    request.fulfillment = "SUGGESTED_FULFILLED"
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
    return request
end

function requests.MarkFulfilled(request, actor, updatedAt)
    request.fulfillment = "FULFILLED"
    request.fulfilledBy = actor
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
    return request
end

function requests.Reopen(request, updatedAt)
    request.fulfillment = "OPEN"
    request.fulfillmentUpdatedAt = updatedAt or _G.time()
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
    local request = requests.Create(input or {})
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
    if not request then
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
    if not request then
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
    if not request then
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
    if not request then
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
