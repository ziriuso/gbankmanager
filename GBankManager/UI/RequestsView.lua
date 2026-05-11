local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local requestsView = ns.modules.requestsView or {}

function requestsView.FilterOwnRequests(rows, playerName)
    local out = {}

    for _, row in ipairs(rows or {}) do
        if row.requester == playerName then
            table.insert(out, row)
        end
    end

    return out
end

ns.modules.requestsView = requestsView

return requestsView
