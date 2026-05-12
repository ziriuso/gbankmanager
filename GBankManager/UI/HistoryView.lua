local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local historyView = ns.modules.historyView or {}

local action_labels = {
    REQUEST_CREATED = "Created",
    REQUEST_APPROVED = "Approved",
    REQUEST_REJECTED = "Rejected",
    REQUEST_FULFILLED = "Fulfilled",
    REQUEST_REOPENED = "Reopened",
    MINIMUM_CREATED = "Created",
    MINIMUM_UPDATED = "Updated",
    MINIMUM_REMOVED = "Removed",
}

local category_labels = {
    REQUEST = "Request",
    MINIMUM = "Minimum",
}

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

        if filters.itemName and (entry.itemName or entry.name) ~= filters.itemName then
            include = false
        end

        if include then
            table.insert(out, entry)
        end
    end

    return out
end

function historyView.BuildLines(entries, filters)
    local rows = {}

    for _, entry in ipairs(historyView.Filter(entries, filters)) do
        table.insert(rows, string.format("%s %s", tostring(entry.type), tostring(entry.itemName or entry.name or "Unknown")))
    end

    if #rows == 0 then
        table.insert(rows, "No history entries yet.")
    end

    return rows
end

function historyView.BuildTableRows(entries, filters)
    local rows = {}

    for _, entry in ipairs(historyView.Filter(entries, filters)) do
        table.insert(rows, {
            category = category_labels[entry.category] or tostring(entry.category or "Unknown"),
            itemName = tostring(entry.itemName or entry.name or "Unknown"),
            action = action_labels[entry.type] or tostring(entry.type or "Unknown"),
            actor = tostring(entry.actor or "Unknown"),
            oldValue = entry.oldValue ~= nil and tostring(entry.oldValue) or "-",
            newValue = entry.newValue ~= nil and tostring(entry.newValue) or "-",
            date = format_timestamp(entry.timestamp or entry.scannedAt),
        })
    end

    return rows
end

ns.modules.historyView = historyView

return historyView
