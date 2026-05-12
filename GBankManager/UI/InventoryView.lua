local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local inventoryView = ns.modules.inventoryView or {}

function inventoryView.FilterItems(items, query)
    local out = {}
    query = string.lower(query or "")

    for _, item in ipairs(items or {}) do
        local name = string.lower(item.name or "")
        if query == "" or string.find(name, query, 1, true) then
            table.insert(out, item)
        end
    end

    table.sort(out, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return out
end

function inventoryView.BuildLines(snapshot, query)
    local rows = {}
    local items = {}

    for _, item in pairs((snapshot or {}).items or {}) do
        table.insert(items, item)
    end

    for _, item in ipairs(inventoryView.FilterItems(items, query)) do
        table.insert(rows, string.format("%s x%d", tostring(item.name), tonumber(item.totalCount or 0)))
    end

    if #rows == 0 then
        table.insert(rows, "No inventory data yet.")
    end

    return rows
end

local function minimum_for_item(db, item)
    local minimum = 0
    local matched = false

    for _, rule in ipairs((db or {}).minimums or {}) do
        if rule.itemID == item.itemID then
            minimum = math.max(minimum, tonumber(rule.quantity or 0))
            matched = true
        end
    end

    return minimum, matched
end

function inventoryView.BuildTableRows(snapshot, db, query)
    local rows = {}
    local items = {}

    for _, item in pairs((snapshot or {}).items or {}) do
        table.insert(items, item)
    end

    for _, item in ipairs(inventoryView.FilterItems(items, query)) do
        local tabs = {}
        for tabName in pairs(item.tabs or {}) do
            table.insert(tabs, tostring(tabName))
        end
        table.sort(tabs)

        local minimum, hasMinimum = minimum_for_item(db, item)
        table.insert(rows, {
            name = tostring(item.name or "Unknown"),
            quantity = tostring(item.totalCount or 0),
            tab = #tabs > 0 and table.concat(tabs, ", ") or "-",
            restock = hasMinimum and ((item.totalCount or 0) < minimum and "Yes" or "No") or "No",
            minimum = hasMinimum and tostring(minimum) or "-",
        })
    end

    return rows
end

ns.modules.inventoryView = inventoryView

return inventoryView
