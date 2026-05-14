local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local requests = ns.modules.requests

local requestDialog = ns.modules.requestDialog or {}

function requestDialog.ResolveMatches(index, query)
    local out = {}
    local normalizedQuery = string.lower(tostring(query or ""))

    for _, item in ipairs(index or {}) do
        local itemName = string.lower(item.name or "")
        local itemID = tostring(item.itemID or "")
        local matchesName = string.find(itemName, normalizedQuery, 1, true) ~= nil
        local matchesID = itemID == normalizedQuery

        if normalizedQuery == "" or matchesName or matchesID then
            table.insert(out, item)
        end
    end

    table.sort(out, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return out
end

function requestDialog.Submit(input)
    return requests.Create(input or {})
end

ns.modules.requestDialog = requestDialog

return requestDialog
