local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local historyView = ns.modules.historyView or {}

local action_labels = {
    ITEM_ADDED = "Added",
    ITEM_REMOVED = "Removed",
    QUANTITY_INCREASED = "Deposited",
    QUANTITY_DECREASED = "Withdrew",
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

        if filters.itemName and entry.name ~= filters.itemName then
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
        local suffix = ""
        if entry.delta ~= nil then
            suffix = string.format(" (+%s)", tostring(entry.delta))
        end

        table.insert(rows, string.format("%s %s%s", tostring(entry.type), tostring(entry.name), suffix))
    end

    if #rows == 0 then
        table.insert(rows, "No history entries yet.")
    end

    return rows
end

function historyView.BuildTableRows(entries, filters)
    local rows = {}

    for _, entry in ipairs(historyView.Filter(entries, filters)) do
        local quantity = tonumber(entry.delta or 0)
        if entry.type == "ITEM_REMOVED" or entry.type == "QUANTITY_DECREASED" then
            quantity = -quantity
        end

        table.insert(rows, {
            itemName = tostring(entry.name or "Unknown"),
            action = action_labels[entry.type] or tostring(entry.type or "Unknown"),
            quantity = tostring(quantity),
            actor = tostring(entry.actor or "Unknown"),
            date = format_timestamp(entry.scannedAt),
        })
    end

    return rows
end

ns.modules.historyView = historyView

return historyView
