local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local historyView = ns.modules.historyView or {}

local action_labels = {
    AUTH_POLICY_UPDATED = "Updated",
    REQUEST_CREATED = "Created",
    REQUEST_UPDATED = "Updated",
    REQUEST_APPROVED = "Approved",
    REQUEST_REJECTED = "Rejected",
    REQUEST_FULFILLED = "Fulfilled",
    REQUEST_REOPENED = "Reopened",
    MINIMUM_CREATED = "Created",
    MINIMUM_UPDATED = "Updated",
    MINIMUM_ENABLED = "Enabled",
    MINIMUM_DISABLED = "Disabled",
    MINIMUM_REMOVED = "Removed",
    TARGET_CREATED = "Created",
    TARGET_UPDATED = "Updated",
    TARGET_CLOSED = "Closed",
    TARGET_REOPENED = "Reopened",
}

local category_labels = {
    OPTIONS = "Options",
    REQUEST = "Request",
    MINIMUM = "Minimum",
    TARGET = "Target",
}

local procurement_categories = {
    REQUEST = true,
    MINIMUM = true,
}

local function normalize_timestamp(timestamp)
    local numeric = tonumber(timestamp)
    if numeric ~= nil then
        return numeric
    end

    return 0
end

local function abbreviate_timezone_name(displayText)
    local prefix, timezoneName = string.match(tostring(displayText or ""), "^(.-)([A-Za-z][A-Za-z%s]+)$")
    if not timezoneName or string.find(timezoneName, " ", 1, true) == nil then
        return tostring(displayText or "")
    end

    local known = {
        ["Eastern Daylight Time"] = "EDT",
        ["Eastern Standard Time"] = "EST",
        ["Central Daylight Time"] = "CDT",
        ["Central Standard Time"] = "CST",
        ["Mountain Daylight Time"] = "MDT",
        ["Mountain Standard Time"] = "MST",
        ["Pacific Daylight Time"] = "PDT",
        ["Pacific Standard Time"] = "PST",
        ["Greenwich Mean Time"] = "GMT",
        ["Coordinated Universal Time"] = "UTC",
    }

    local abbreviation = known[timezoneName]
    if not abbreviation then
        abbreviation = timezoneName:gsub("(%a)[%a']*", "%1"):gsub("%s+", ""):upper()
    end

    return string.format("%s%s", prefix or "", abbreviation)
end

local function format_timestamp(timestamp)
    timestamp = normalize_timestamp(timestamp)
    if timestamp == 0 then
        return "-"
    end

    local formatter = _G.date or os.date
    if type(formatter) == "function" then
        return abbreviate_timezone_name(formatter("%Y-%m-%d %H:%M %Z", timestamp))
    end

    return tostring(timestamp)
end

local function contains_text(haystack, needle)
    haystack = string.lower(tostring(haystack or ""))
    needle = string.lower(tostring(needle or ""))

    if needle == "" then
        return true
    end

    return string.find(haystack, needle, 1, true) ~= nil
end

function historyView.Filter(entries, filters)
    local out = {}
    filters = filters or {}

    for _, entry in ipairs(entries or {}) do
        local include = true

        if filters.changeType and filters.changeType ~= "" and entry.type ~= filters.changeType then
            include = false
        end

        if filters.action and not contains_text(action_labels[entry.type] or entry.type, filters.action) then
            include = false
        end

        if filters.category and not contains_text(category_labels[entry.category] or entry.category, filters.category) then
            include = false
        end

        if filters.actor and filters.actor ~= "" and not contains_text(entry.actor, filters.actor) then
            include = false
        end

        if filters.itemName and filters.itemName ~= "" and not contains_text(entry.itemName or entry.name, filters.itemName) then
            include = false
        end

        if include then
            table.insert(out, entry)
        end
    end

    return out
end

function historyView.FilterProcurementEntries(entries)
    local filtered = {}

    for _, entry in ipairs(entries or {}) do
        if procurement_categories[entry.category] or (entry.category == "OPTIONS" and entry.type == "AUTH_POLICY_UPDATED") then
            table.insert(filtered, entry)
        end
    end

    return filtered
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
    local filteredEntries = historyView.Filter(entries, filters)

    table.sort(filteredEntries, function(left, right)
        local leftTimestamp = normalize_timestamp(left.timestamp or left.scannedAt)
        local rightTimestamp = normalize_timestamp(right.timestamp or right.scannedAt)
        if leftTimestamp == rightTimestamp then
            return tostring(left.itemName or left.name or "") < tostring(right.itemName or right.name or "")
        end
        return leftTimestamp > rightTimestamp
    end)

    for _, entry in ipairs(filteredEntries) do
        table.insert(rows, {
            category = category_labels[entry.category] or tostring(entry.category or "Unknown"),
            itemName = tostring(entry.itemName or entry.name or "Unknown"),
            action = action_labels[entry.type] or tostring(entry.type or "Unknown"),
            actor = tostring(entry.actor or "Unknown"),
            date = format_timestamp(entry.timestamp or entry.scannedAt),
            details = {
                type = tostring(entry.type or "Unknown"),
                category = category_labels[entry.category] or tostring(entry.category or "Unknown"),
                itemName = tostring(entry.itemName or entry.name or "Unknown"),
                action = action_labels[entry.type] or tostring(entry.type or "Unknown"),
                actor = tostring(entry.actor or "Unknown"),
                oldValue = entry.oldValue ~= nil and tostring(entry.oldValue) or "-",
                newValue = entry.newValue ~= nil and tostring(entry.newValue) or "-",
                timestamp = format_timestamp(entry.timestamp or entry.scannedAt),
            },
            historyEntry = entry,
        })
    end

    return rows
end

ns.modules.historyView = historyView

return historyView
