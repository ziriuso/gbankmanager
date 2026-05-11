local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local historyView = ns.modules.historyView or {}

function historyView.Filter(entries, filters)
    local out = {}
    filters = filters or {}

    for _, entry in ipairs(entries or {}) do
        local include = true

        if filters.changeType and entry.type ~= filters.changeType then
            include = false
        end

        if filters.actor and entry.actor ~= filters.actor then
            include = false
        end

        if filters.itemName and entry.name ~= filters.itemName then
            include = false
        end

        if include then
            table.insert(out, entry)
        end
    end

    return out
end

ns.modules.historyView = historyView

return historyView
