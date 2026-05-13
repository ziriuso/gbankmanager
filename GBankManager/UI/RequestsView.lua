local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local requestsView = ns.modules.requestsView or {}

local function format_timestamp(timestamp)
    if not timestamp or timestamp == 0 then
        return "-"
    end

    local formatter = _G.date or os.date
    if type(formatter) == "function" then
        return formatter("%Y-%m-%d %H:%M", timestamp)
    end

    return tostring(timestamp)
end

function requestsView.FilterOwnRequests(rows, playerName)
    local out = {}

    for _, row in ipairs(rows or {}) do
        if row.requester == playerName then
            table.insert(out, row)
        end
    end

    return out
end

function requestsView.BuildOfficerQueue(rows)
    local out = {}

    for _, row in ipairs(rows or {}) do
        local actionable = (row.approval == "PENDING") or (row.approval == "APPROVED" and row.fulfillment == "OPEN")
        if actionable then
            table.insert(out, row)
        end
    end

    table.sort(out, function(left, right)
        if left.approval ~= right.approval then
            return left.approval == "PENDING"
        end

        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return out
end

function requestsView.BuildTableRows(rows)
    local queue = requestsView.BuildOfficerQueue(rows or {})
    local out = {}

    for _, row in ipairs(queue) do
        table.insert(out, {
            requestId = row.requestId,
            requester = tostring(row.requester or "Unknown"),
            itemName = tostring(row.itemName or "Unknown"),
            quantity = tostring(row.quantity or 0),
            approval = tostring(row.approval or "UNKNOWN"),
            fulfillment = tostring(row.fulfillment or "UNKNOWN"),
            note = tostring(row.note or ""),
            createdAt = format_timestamp(row.createdAt),
        })
    end

    return out
end

function requestsView.BuildOwnRows(rows, characterKey, requesterName)
    local out = {}

    for _, row in ipairs(rows or {}) do
        if row.requesterCharacterKey == characterKey or row.requester == requesterName then
            table.insert(out, row)
        end
    end

    table.sort(out, function(left, right)
        return tonumber(left.createdAt or 0) > tonumber(right.createdAt or 0)
    end)

    return out
end

function requestsView.BuildVisibleRows(rows, viewerContext, accessProfile)
    if accessProfile == "request_only" then
        return requestsView.BuildOwnRows(rows or {}, viewerContext and viewerContext.characterKey, viewerContext and viewerContext.name)
    end

    return requestsView.BuildOfficerQueue(rows or {})
end

function requestsView.BuildTableRows(rows, viewerContext, accessProfile)
    local queue = requestsView.BuildVisibleRows(rows or {}, viewerContext or {}, accessProfile)
    local out = {}

    for _, row in ipairs(queue) do
        table.insert(out, {
            requestId = row.requestId,
            requester = tostring(row.requester or "Unknown"),
            itemName = tostring(row.itemName or "Unknown"),
            quantity = tostring(row.quantity or 0),
            approval = tostring(row.approval or "UNKNOWN"),
            fulfillment = tostring(row.fulfillment or "UNKNOWN"),
            note = tostring(row.note or ""),
            createdAt = format_timestamp(row.createdAt),
        })
    end

    return out
end

ns.modules.requestsView = requestsView

return requestsView
