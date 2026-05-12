local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local targetsView = ns.modules.targetsView or {}

local function target_key(target)
    return table.concat({
        tostring((target or {}).itemID or ""),
        tostring((target or {}).scope or "GLOBAL"),
        tostring((target or {}).tabName or ""),
    }, "|")
end

local function normalize_target(target, previous)
    target = target or {}
    previous = previous or {}

    return {
        itemID = target.itemID,
        itemName = target.itemName,
        quantity = target.quantity or 0,
        scope = target.scope or previous.scope or "GLOBAL",
        tabName = target.tabName ~= nil and target.tabName or previous.tabName,
        status = target.status or previous.status or "OPEN",
    }
end

function targetsView.Upsert(list, target)
    list = list or {}
    target = target or {}

    local updated = false
    for index, existing in ipairs(list) do
        if target_key(existing) == target_key(target) then
            list[index] = normalize_target(target, existing)
            updated = true
            break
        end
    end

    if not updated then
        table.insert(list, normalize_target(target))
    end

    return list
end

function targetsView.UpsertWithAudit(db, target, metadata)
    db = db or {}
    db.oneTimeTargets = db.oneTimeTargets or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local previous = nil
    for _, existing in ipairs(db.oneTimeTargets) do
        if target_key(existing) == target_key(target) then
            previous = existing
            break
        end
    end

    local normalizedTarget = normalize_target(target, previous)
    db.oneTimeTargets = targetsView.Upsert(db.oneTimeTargets, normalizedTarget)

    table.insert(db.auditLog, {
        category = "TARGET",
        type = previous and "TARGET_UPDATED" or "TARGET_CREATED",
        actor = metadata.actor or "Unknown",
        itemID = normalizedTarget.itemID,
        itemName = normalizedTarget.itemName,
        oldValue = previous and tostring(previous.quantity or 0) or nil,
        newValue = tostring(normalizedTarget.quantity or 0),
        timestamp = metadata.timestamp or _G.time(),
    })

    return db.oneTimeTargets
end

function targetsView.SetStatusWithAudit(db, target, status, metadata)
    db = db or {}
    db.oneTimeTargets = db.oneTimeTargets or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local previous = nil
    for _, existing in ipairs(db.oneTimeTargets) do
        if target_key(existing) == target_key(target) then
            previous = existing
            break
        end
    end

    local normalizedTarget = normalize_target(target, previous)
    normalizedTarget.status = status or normalizedTarget.status or "OPEN"
    db.oneTimeTargets = targetsView.Upsert(db.oneTimeTargets, normalizedTarget)

    local previousStatus = previous and previous.status or "OPEN"
    if previousStatus ~= normalizedTarget.status then
        table.insert(db.auditLog, {
            category = "TARGET",
            type = normalizedTarget.status == "CLOSED" and "TARGET_CLOSED" or "TARGET_REOPENED",
            actor = metadata.actor or "Unknown",
            itemID = normalizedTarget.itemID,
            itemName = normalizedTarget.itemName,
            oldValue = previousStatus,
            newValue = normalizedTarget.status,
            timestamp = metadata.timestamp or _G.time(),
        })
    end

    return normalizedTarget
end

function targetsView.MarkSuggestedFulfilled(target, currentCount)
    target = target or {}

    if (currentCount or 0) >= (target.quantity or 0) then
        target.status = "SUGGESTED_FULFILLED"
    end

    return target
end

function targetsView.BuildTableRows(targets, snapshot)
    local rows = {}
    local snapshotItems = ((snapshot or {}).items) or {}

    for _, target in ipairs(targets or {}) do
        local item = snapshotItems[target.itemID]
        local current = item and item.totalCount or 0
        local displayTarget = {
            itemID = target.itemID,
            itemName = target.itemName,
            quantity = target.quantity,
            status = target.status,
        }
        local displayStatus = target.status or "OPEN"
        if displayStatus == "OPEN" then
            displayStatus = targetsView.MarkSuggestedFulfilled(displayTarget, current).status
        end

        table.insert(rows, {
            itemID = tostring(target.itemID or ""),
            itemName = tostring(target.itemName or "Unknown"),
            current = tostring(current),
            status = displayStatus == "SUGGESTED_FULFILLED" and "Suggested" or (displayStatus == "CLOSED" and "Closed" or "Open"),
            quantity = tostring(target.quantity or 0),
            scope = tostring(target.scope or "GLOBAL"),
            tabKey = tostring(target.tabName or ""),
            statusSort = displayStatus == "OPEN" and 0 or (displayStatus == "SUGGESTED_FULFILLED" and 0 or 1),
        })
    end

    table.sort(rows, function(left, right)
        if left.statusSort ~= right.statusSort then
            return left.statusSort < right.statusSort
        end
        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return rows
end

ns.modules.targetsView = targetsView

return targetsView
