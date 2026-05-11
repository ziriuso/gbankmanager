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

ns.modules.inventoryView = inventoryView

return inventoryView
