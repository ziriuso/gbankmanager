local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsView = ns.modules.minimumsView or {}

function minimumsView.Upsert(list, rule)
    list = list or {}
    rule = rule or {}

    local updated = false
    for index, existing in ipairs(list) do
        if existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName then
            list[index] = rule
            updated = true
            break
        end
    end

    if not updated then
        table.insert(list, rule)
    end

    return list
end

function minimumsView.UpsertWithAudit(db, rule, metadata)
    db = db or {}
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local previous = nil
    for _, existing in ipairs(db.minimums) do
        if existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName then
            previous = existing
            break
        end
    end

    db.minimums = minimumsView.Upsert(db.minimums, rule)

    table.insert(db.auditLog, {
        category = "MINIMUM",
        type = previous and "MINIMUM_UPDATED" or "MINIMUM_CREATED",
        actor = metadata.actor or "Unknown",
        itemID = rule.itemID,
        itemName = rule.itemName,
        oldValue = previous and tostring(previous.quantity or 0) or nil,
        newValue = tostring(rule.quantity or 0),
        timestamp = metadata.timestamp or _G.time(),
    })

    return db.minimums
end

ns.modules.minimumsView = minimumsView

return minimumsView
