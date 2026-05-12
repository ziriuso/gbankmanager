local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsView = ns.modules.minimumsView or {}

local function rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local function normalize_rule(rule, previous)
    rule = rule or {}
    previous = previous or {}

    local enabled = false
    if rule.enabled ~= nil then
        enabled = rule.enabled and true or false
    elseif previous.enabled ~= nil then
        enabled = previous.enabled and true or false
    end

    return {
        itemID = rule.itemID,
        itemName = rule.itemName,
        quantity = rule.quantity or 0,
        scope = rule.scope or previous.scope or "GLOBAL",
        tabName = rule.tabName ~= nil and rule.tabName or previous.tabName,
        enabled = enabled,
    }
end

function minimumsView.Upsert(list, rule)
    list = list or {}
    rule = rule or {}

    local updated = false
    for index, existing in ipairs(list) do
        if existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName then
            list[index] = normalize_rule(rule, existing)
            updated = true
            break
        end
    end

    if not updated then
        table.insert(list, normalize_rule(rule))
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

    local normalizedRule = normalize_rule(rule, previous)
    db.minimums = minimumsView.Upsert(db.minimums, normalizedRule)

    table.insert(db.auditLog, {
        category = "MINIMUM",
        type = previous and "MINIMUM_UPDATED" or "MINIMUM_CREATED",
        actor = metadata.actor or "Unknown",
        itemID = normalizedRule.itemID,
        itemName = normalizedRule.itemName,
        oldValue = previous and tostring(previous.quantity or 0) or nil,
        newValue = tostring(normalizedRule.quantity or 0),
        timestamp = metadata.timestamp or _G.time(),
    })

    return db.minimums
end

function minimumsView.SetEnabledWithAudit(db, rule, enabled, metadata)
    db = db or {}
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local existing = nil
    for _, candidate in ipairs(db.minimums) do
        if rule_key(candidate) == rule_key(rule) then
            existing = candidate
            break
        end
    end

    local previousEnabled = existing and existing.enabled ~= false or false
    local normalizedRule = normalize_rule(rule, existing)
    normalizedRule.enabled = enabled and true or false

    db.minimums = minimumsView.Upsert(db.minimums, normalizedRule)

    if previousEnabled ~= normalizedRule.enabled then
        table.insert(db.auditLog, {
            category = "MINIMUM",
            type = normalizedRule.enabled and "MINIMUM_ENABLED" or "MINIMUM_DISABLED",
            actor = metadata.actor or "Unknown",
            itemID = normalizedRule.itemID,
            itemName = normalizedRule.itemName,
            oldValue = previousEnabled and "ENABLED" or "DISABLED",
            newValue = normalizedRule.enabled and "ENABLED" or "DISABLED",
            timestamp = metadata.timestamp or _G.time(),
        })
    end

    return normalizedRule
end

function minimumsView.BuildTableRows(rows, snapshot, options)
    local out = {}
    local snapshotItems = ((snapshot or {}).items) or {}
    local seen = {}
    options = options or {}
    local showAll = options.showAll ~= false
    local search = string.lower(tostring(options.search or ""))
    local manualOnly = options.manualOnly == true

    for _, row in ipairs(rows or {}) do
        local item = snapshotItems[row.itemID]
        table.insert(out, {
            itemID = tostring(row.itemID or ""),
            itemName = tostring(row.itemName or "Unknown"),
            quantity = tostring(row.quantity or 0),
            scope = tostring(row.scope or "GLOBAL"),
            tabName = tostring(row.tabName or "-"),
            tabKey = tostring(row.tabName or ""),
            current = tostring(item and item.totalCount or 0),
            restock = row.enabled ~= false and "Yes" or "No",
            source = item and "Both" or "Manual",
            enabledSort = row.enabled ~= false and 0 or 1,
            configuredSort = 0,
        })
        seen[row.itemID] = true
    end

    for itemID, item in pairs(snapshotItems) do
        if showAll and not seen[itemID] then
            table.insert(out, {
                itemID = tostring(itemID or ""),
                itemName = tostring(item.name or "Unknown"),
                quantity = "-",
                scope = "GLOBAL",
                tabName = "-",
                tabKey = "",
                current = tostring(item.totalCount or 0),
                restock = "No",
                source = "Bank",
                enabledSort = 1,
                configuredSort = 1,
            })
        end
    end

    if not showAll then
        local filtered = {}
        for _, row in ipairs(out) do
            if row.restock == "Yes" then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    if manualOnly then
        local filtered = {}
        for _, row in ipairs(out) do
            if row.source == "Manual" then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    if search ~= "" then
        local filtered = {}
        for _, row in ipairs(out) do
            if string.find(string.lower(tostring(row.itemName or "")), search, 1, true) ~= nil then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    table.sort(out, function(left, right)
        if left.enabledSort ~= right.enabledSort then
            return left.enabledSort < right.enabledSort
        end
        if left.configuredSort ~= right.configuredSort then
            return left.configuredSort < right.configuredSort
        end
        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return out
end

ns.modules.minimumsView = minimumsView

return minimumsView
