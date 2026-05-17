local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local requestsView = ns.modules.requestsView or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end

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

local function crafted_quality_markup(atlasName)
    if type(craftedQuality.ToMarkup) == "function" then
        return craftedQuality.ToMarkup(atlasName, 22)
    end

    if atlasName == nil or atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function title_status(value)
    value = tostring(value or "UNKNOWN")
    return string.sub(value, 1, 1) .. string.lower(string.sub(value, 2):gsub("_", " "))
end

function requestsView.FormatStatus(row)
    row = row or {}
    local approval = tostring(row.approval or "UNKNOWN")
    local fulfillment = tostring(row.fulfillment or "UNKNOWN")

    if approval == "APPROVED" and fulfillment == "FULFILLED" then
        return "Fulfilled"
    end

    if approval == "APPROVED" then
        return "Approved"
    end

    if approval == "PENDING" then
        return "Pending"
    end

    if approval == "CANCELED" then
        return "Canceled"
    end

    if approval == "REJECTED" then
        return "Rejected"
    end

    return title_status(approval)
end

function requestsView.FormatLocalTimestamp(timestamp)
    if not timestamp or timestamp == 0 then
        return "-"
    end

    local formatter = _G.date or os.date
    local localTime = type(formatter) == "function" and formatter("%Y-%m-%d %H:%M", timestamp) or tostring(timestamp)
    local zone = type(formatter) == "function" and formatter("%Z", timestamp) or "Local"
    if zone == nil or zone == "" then
        zone = "Local"
    end
    if string.find(zone, " ", 1, true) then
        local abbreviation = ""
        for word in string.gmatch(zone, "%S+") do
            abbreviation = abbreviation .. string.sub(word, 1, 1)
        end
        zone = string.upper(abbreviation)
    end

    return string.format("%s %s", localTime, zone)
end

local function apply_column_filters(rows, filters)
    local out = {}
    filters = filters or {}

    for _, row in ipairs(rows or {}) do
        local include = true

        for key, value in pairs(filters) do
            local needle = string.lower(tostring(value or ""))
            local haystack = string.lower(tostring(row[key] or ""))

            if needle ~= "" and string.find(haystack, needle, 1, true) == nil then
                include = false
                break
            end
        end

        if include then
            table.insert(out, row)
        end
    end

    return out
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

function requestsView.BuildOfficerQueue(rows, statusFilter)
    local out = {}
    statusFilter = tostring(statusFilter or "ALL")

    for _, row in ipairs(rows or {}) do
        local include = true
        if statusFilter == "PENDING_APPROVAL" then
            include = row.approval == "PENDING"
        elseif statusFilter == "PENDING_FULFILLMENT" then
            include = row.approval == "APPROVED" and row.fulfillment == "OPEN"
        end

        if include then
            table.insert(out, row)
        end
    end

    table.sort(out, function(left, right)
        local function rank(row)
            if row.approval == "PENDING" then
                return 1
            end
            if row.approval == "APPROVED" and row.fulfillment == "OPEN" then
                return 2
            end
            if row.approval == "APPROVED" and row.fulfillment == "FULFILLED" then
                return 3
            end
            return 4
        end

        if rank(left) ~= rank(right) then
            return rank(left) < rank(right)
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
            itemID = tostring(row.itemID or ""),
            tier = crafted_quality_markup(row.craftedQualityIcon),
            tierValue = tonumber(row.craftedQuality or 0) or 0,
            itemName = tostring(row.itemName or "Unknown"),
            quantity = tostring(row.quantity or 0),
            approval = tostring(row.approval or "UNKNOWN"),
            fulfillment = tostring(row.fulfillment or "UNKNOWN"),
            status = requestsView.FormatStatus(row),
            note = tostring(row.note or ""),
            createdAt = format_timestamp(row.createdAt),
            requestedAtLocal = requestsView.FormatLocalTimestamp(row.createdAt),
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

function requestsView.BuildVisibleRows(rows, viewerContext, accessProfile, statusFilter)
    if accessProfile == "request_only" then
        return requestsView.BuildOwnRows(rows or {}, viewerContext and viewerContext.characterKey, viewerContext and viewerContext.name)
    end

    return requestsView.BuildOfficerQueue(rows or {}, statusFilter)
end

function requestsView.BuildTableRows(rows, viewerContext, accessProfile, filters, statusFilter)
    local queue = requestsView.BuildVisibleRows(rows or {}, viewerContext or {}, accessProfile, statusFilter)
    local out = {}

    for _, row in ipairs(queue) do
        table.insert(out, {
            requestId = row.requestId,
            requester = tostring(row.requester or "Unknown"),
            itemID = tostring(row.itemID or ""),
            tier = crafted_quality_markup(row.craftedQualityIcon),
            tierValue = tonumber(row.craftedQuality or 0) or 0,
            itemName = tostring(row.itemName or "Unknown"),
            quantity = tostring(row.quantity or 0),
            approval = tostring(row.approval or "UNKNOWN"),
            fulfillment = tostring(row.fulfillment or "UNKNOWN"),
            status = requestsView.FormatStatus(row),
            note = tostring(row.note or ""),
            createdAt = format_timestamp(row.createdAt),
            requestedAtLocal = requestsView.FormatLocalTimestamp(row.createdAt),
            fulfilledAt = format_timestamp(row.fulfillmentUpdatedAt),
            fulfilledAtLocal = requestsView.FormatLocalTimestamp(row.fulfillmentUpdatedAt),
        })
    end

    return apply_column_filters(out, filters)
end

ns.modules.requestsView = requestsView

return requestsView
