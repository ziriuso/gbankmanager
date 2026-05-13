local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local inventoryView = ns.modules.inventoryView or {}

local QUALITY_RANK_BY_ATLAS = {
    ["Professions-ChatIcon-Quality-Tier1"] = 1,
    ["Professions-ChatIcon-Quality-Tier2"] = 2,
    ["Professions-ChatIcon-Quality-Tier3"] = 3,
    ["Professions-ChatIcon-Quality-Tier4"] = 4,
    ["Professions-ChatIcon-Quality-Tier5"] = 5,
}

local DEFAULT_COLUMNS = {
    { key = "quality", label = "Tier", width = 64, minWidth = 64, maxWidth = 76, justifyH = "CENTER", filterMode = "none", sortable = true },
    { key = "name", label = "Name", width = 238, minWidth = 190, maxWidth = 360, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "tab", label = "Tab", width = 152, minWidth = 120, maxWidth = 280, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "restock", label = "Restock", width = 90, minWidth = 78, maxWidth = 116, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "quantity", label = "Qty", width = 84, minWidth = 72, maxWidth = 112, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "minimum", label = "Min", width = 92, minWidth = 80, maxWidth = 118, justifyH = "LEFT", filterMode = "none", sortable = true },
}

local function crafted_quality_icon_text(icon)
    if type(icon) == "table" then
        for _, key in ipairs({ "atlas", "iconInventory", "iconMixed", "iconChat", "iconSmall", "icon", "texture", "markup" }) do
            local nested = crafted_quality_icon_text(icon[key])
            if nested ~= "" then
                return nested
            end
        end

        return ""
    end

    if icon == nil then
        return ""
    end

    return tostring(icon)
end

local function crafted_quality_markup(icon)
    local atlasName = crafted_quality_icon_text(icon)
    if atlasName == "" then
        return ""
    end

    if string.sub(atlasName, 1, 3) == "|A:" or string.sub(atlasName, 1, 2) == "|T" then
        return atlasName
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function parsed_quality_tier(icon)
    local atlasName = crafted_quality_icon_text(icon)
    if QUALITY_RANK_BY_ATLAS[atlasName] ~= nil then
        return QUALITY_RANK_BY_ATLAS[atlasName]
    end

    local tierText = string.match(atlasName, "[Tt]ier%s*[_%-]?(%d+)")
    if tierText == nil then
        tierText = string.match(atlasName, "[Qq]uality%s*[_%-]?(%d+)")
    end
    if tierText == nil then
        tierText = string.match(atlasName, "[Rr]ank%s*[_%-]?(%d+)")
    end

    local parsedTier = tonumber(tierText or "")
    if parsedTier and parsedTier >= 1 and parsedTier <= 5 then
        return parsedTier
    end

    return nil
end

local function crafted_quality_rank(item)
    item = item or {}

    local parsedTier = parsed_quality_tier(item.craftedQualityIcon)
    if parsedTier ~= nil then
        return parsedTier
    end

    local quality = tonumber(item.craftedQuality or 0) or 0
    if quality < 1 or quality > 5 then
        return 0
    end

    return quality
end

local function normalized_sort_value(key, value, direction)
    if key == "quality" then
        local rank = tonumber(value or 0) or 0
        if rank <= 0 then
            return direction == "desc" and -1 or 999
        end
        return rank
    end

    if type(value) == "string" then
        return string.lower(tostring(value or ""))
    end

    return value or 0
end

local function copy_columns(columns)
    local out = {}

    for index, column in ipairs(columns or {}) do
        out[index] = {
            key = column.key,
            label = column.label,
            width = column.width,
            minWidth = column.minWidth,
            maxWidth = column.maxWidth,
            justifyH = column.justifyH,
            filterMode = column.filterMode,
            sortable = column.sortable,
        }
    end

    return out
end

local function total_width(columns)
    local width = 0

    for _, column in ipairs(columns or {}) do
        width = width + (column.width or 0)
    end

    return width
end

local function clip_text(text, width)
    text = tostring(text or "")
    width = math.max(0, tonumber(width) or 0)

    if string.sub(text, 1, 3) == "|A:" then
        return text
    end

    local maxChars = math.floor(math.max(0, width - 16) / 7)
    if maxChars <= 0 then
        return ""
    end

    if string.len(text) <= maxChars then
        return text
    end

    if maxChars <= 3 then
        return string.rep(".", maxChars)
    end

    return string.sub(text, 1, maxChars - 3) .. "..."
end

function inventoryView.GetDefaultColumns()
    return copy_columns(DEFAULT_COLUMNS)
end

function inventoryView.ResizeColumnLayout(columns, index, delta, totalWidthHint)
    local out = copy_columns(columns)
    local current = out[index]

    if not current then
        return out
    end

    if delta > 0 then
        local availableGrow = (current.maxWidth or 9999) - (current.width or 0)
        local requested = math.min(delta, availableGrow)
        local remaining = requested

        for nextIndex = index + 1, #out do
            local neighbor = out[nextIndex]
            local available = math.max(0, (neighbor.width or 0) - (neighbor.minWidth or 0))
            local taken = math.min(remaining, available)
            neighbor.width = (neighbor.width or 0) - taken
            remaining = remaining - taken
            if remaining <= 0 then
                break
            end
        end

        current.width = (current.width or 0) + (requested - remaining)
    elseif delta < 0 and out[index + 1] then
        local requested = math.min(math.abs(delta), (current.width or 0) - (current.minWidth or 0))
        local neighbor = out[index + 1]
        local availableGrow = (neighbor.maxWidth or 9999) - (neighbor.width or 0)
        local applied = math.min(requested, availableGrow)

        current.width = (current.width or 0) - applied
        neighbor.width = (neighbor.width or 0) + applied
    end

    if totalWidthHint and total_width(out) > totalWidthHint then
        current.width = math.max(current.minWidth or 0, current.width - (total_width(out) - totalWidthHint))
    end

    return out
end

function inventoryView.GetColumnLayout(db, totalWidthHint)
    local columns = inventoryView.GetDefaultColumns()
    local saved = (((db or {}).ui or {}).inventoryColumnWidths) or {}

    for index, delta in pairs(saved) do
        if columns[index] then
            columns[index].width = math.max(columns[index].minWidth, math.min(columns[index].maxWidth, columns[index].width + delta))
        end
    end

    if totalWidthHint and total_width(columns) > totalWidthHint then
        local overflow = total_width(columns) - totalWidthHint
        for index = #columns, 1, -1 do
            local column = columns[index]
            local available = math.max(0, (column.width or 0) - (column.minWidth or 0))
            local reduce = math.min(overflow, available)
            column.width = column.width - reduce
            overflow = overflow - reduce
            if overflow <= 0 then
                break
            end
        end
    end

    return columns
end

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

function inventoryView.ApplyColumnFilters(rows, filters)
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
        if rule.itemID == item.itemID and rule.enabled ~= false then
            minimum = math.max(minimum, tonumber(rule.quantity or 0))
            matched = true
        end
    end

    return minimum, matched
end

function inventoryView.BuildTableRows(snapshot, db, query)
    local rows = {}
    local items = {}
    local filters = {}

    if type(query) == "table" then
        filters = query
    elseif type(query) == "string" and query ~= "" then
        filters.name = query
    end

    for _, item in pairs((snapshot or {}).items or {}) do
        table.insert(items, item)
    end

    for _, item in ipairs(inventoryView.FilterItems(items, filters.name or "")) do
        local tabs = {}
        for tabName in pairs(item.tabs or {}) do
            table.insert(tabs, tostring(tabName))
        end
        table.sort(tabs)

        local minimum, hasMinimum = minimum_for_item(db, item)
        table.insert(rows, {
            quality = crafted_quality_markup(item.craftedQualityIcon),
            qualityValue = crafted_quality_rank(item),
            name = tostring(item.name or "Unknown"),
            quantity = tostring(item.totalCount or 0),
            quantityValue = tonumber(item.totalCount or 0),
            tab = #tabs > 0 and table.concat(tabs, ", ") or "-",
            restock = hasMinimum and ((item.totalCount or 0) < minimum and "Yes" or "No") or "No",
            restockValue = hasMinimum and ((item.totalCount or 0) < minimum and 1 or 0) or 0,
            minimum = hasMinimum and tostring(minimum) or "-",
            minimumValue = hasMinimum and minimum or 0,
        })
    end

    return inventoryView.ApplyColumnFilters(rows, filters)
end

local function compare_with_direction(left, right, direction)
    if left == right then
        return nil
    end

    if direction == "desc" then
        return left > right
    end

    return left < right
end

function inventoryView.SortRows(rows, sortState)
    rows = rows or {}
    sortState = sortState or {}

    local key = sortState.key
    if key == nil or key == "" then
        return rows
    end

    local direction = sortState.direction or "asc"
    local valueKey = ({
        quality = "qualityValue",
        quantity = "quantityValue",
        tab = "tab",
        restock = "restockValue",
        minimum = "minimumValue",
    })[key] or key

    table.sort(rows, function(left, right)
        local leftValue = left[valueKey]
        local rightValue = right[valueKey]

        leftValue = normalized_sort_value(key, leftValue, direction)
        rightValue = normalized_sort_value(key, rightValue, direction)

        local ordered = compare_with_direction(leftValue, rightValue, direction)
        if ordered ~= nil then
            return ordered
        end

        return tostring(left.name or "") < tostring(right.name or "")
    end)

    return rows
end

function inventoryView.BuildDisplayRows(rows, columns)
    local out = {}

    for _, row in ipairs(rows or {}) do
        local displayRow = {}
        for _, column in ipairs(columns or {}) do
            displayRow[column.key] = clip_text(row[column.key], column.width)
        end
        table.insert(out, displayRow)
    end

    return out
end

ns.modules.inventoryView = inventoryView

return inventoryView
