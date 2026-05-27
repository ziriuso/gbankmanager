local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local inventoryView = ns.modules.inventoryView or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end

local function crafted_quality_icon_text(icon)
    if type(craftedQuality.GetIconText) == "function" then
        return craftedQuality.GetIconText(icon)
    end

    if icon == nil then
        return ""
    end

    return tostring(icon)
end

local function crafted_quality_markup(itemID, icon, fallbackQuality, maxQuality)
    if type(craftedQuality.GetDisplayAtlasForItem) == "function" then
        local atlasName = craftedQuality.GetDisplayAtlasForItem(itemID, icon, fallbackQuality, "reagent", maxQuality)
        if tostring(atlasName or "") ~= "" then
            return string.format("|A:%s:22:22|a", tostring(atlasName))
        end
    end

    if type(craftedQuality.DisplayMarkupForItem) == "function" then
        return craftedQuality.DisplayMarkupForItem(itemID, icon, 22, "reagent", fallbackQuality, maxQuality)
    end

    if type(craftedQuality.ToMarkup) == "function" then
        return craftedQuality.ToMarkup(icon, 22, "reagent", fallbackQuality, maxQuality)
    end

    local atlasName = crafted_quality_icon_text(icon)
    if atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function crafted_quality_atlas(itemID, icon, fallbackQuality, maxQuality)
    if type(craftedQuality.GetDisplayAtlasForItem) == "function" then
        return tostring(craftedQuality.GetDisplayAtlasForItem(itemID, icon, fallbackQuality, "reagent", maxQuality) or "")
    end

    local atlasName = crafted_quality_icon_text(icon)
    return atlasName
end

local function parsed_quality_tier(icon)
    if type(craftedQuality.ParseTier) == "function" then
        local parsedTier = craftedQuality.ParseTier(icon, 0)
        if parsedTier > 0 then
            return parsedTier
        end
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
    if key == "quality" or key == "tier" then
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

local function csv_escape(value)
    local text = tostring(value or "")
    if string.find(text, "[\",\n]") then
        text = "\"" .. string.gsub(text, "\"", "\"\"") .. "\""
    end
    return text
end

function inventoryView.GetDefaultColumns()
    local tableLayouts = ns.modules.tableLayouts
    if tableLayouts and type(tableLayouts.GetInventoryMinimumColumns) == "function" then
        return tableLayouts.GetInventoryMinimumColumns()
    end

    return {}
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
    local store = ns.data.store or ns.modules.store
    local saved = store.GetInventoryColumnWidths(db)

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
        if tostring(left.name) ~= tostring(right.name) then
            return tostring(left.name) < tostring(right.name)
        end

        return tostring(left.tabName or "") < tostring(right.tabName or "")
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

local function minimum_for_item(db, item, tabName)
    local minimum = 0
    local matched = false

    for _, rule in ipairs((db or {}).minimums or {}) do
        local ruleTab = rule.tabName
        local isTabMatch = ruleTab == nil or ruleTab == "" or tabName == nil or ruleTab == tabName
        if rule.itemID == item.itemID and rule.enabled ~= false and isTabMatch then
            minimum = math.max(minimum, tonumber(rule.quantity or 0))
            matched = true
        end
    end

    return minimum, matched
end

local function snapshot_item_rows(snapshot)
    local rows = {}
    local snapshotItems = (snapshot or {}).items or {}
    local persistedRows = (snapshot or {}).itemRows or {}

    if #persistedRows > 0 then
        for _, itemRow in ipairs(persistedRows) do
            local item = snapshotItems[itemRow.itemID] or {}
            table.insert(rows, {
                rowKey = itemRow.rowKey,
                itemID = itemRow.itemID,
                name = itemRow.name or item.name,
                quality = itemRow.quality or item.quality,
                craftedQuality = itemRow.craftedQuality or item.craftedQuality,
                craftedQualityIcon = itemRow.craftedQualityIcon or item.craftedQualityIcon,
                craftedQualityMax = itemRow.craftedQualityMax or item.craftedQualityMax,
                tabName = itemRow.tabName,
                quantity = tonumber(itemRow.quantity or 0) or 0,
                aggregate = item,
            })
        end

        return rows
    end

    for _, item in pairs(snapshotItems) do
        local hadTabs = false
        for tabName, count in pairs(item.tabs or {}) do
            hadTabs = true
            table.insert(rows, {
                rowKey = table.concat({ tostring(item.itemID or ""), "TAB", tostring(tabName or "") }, "|"),
                itemID = item.itemID,
                name = item.name,
                quality = item.quality,
                craftedQuality = item.craftedQuality,
                craftedQualityIcon = item.craftedQualityIcon,
                craftedQualityMax = item.craftedQualityMax,
                tabName = tostring(tabName),
                quantity = tonumber(count or 0) or 0,
                aggregate = item,
            })
        end

        if not hadTabs then
            table.insert(rows, {
                rowKey = tostring(item.itemID or ""),
                itemID = item.itemID,
                name = item.name,
                quality = item.quality,
                craftedQuality = item.craftedQuality,
                craftedQualityIcon = item.craftedQualityIcon,
                craftedQualityMax = item.craftedQualityMax,
                tabName = nil,
                quantity = tonumber(item.totalCount or 0) or 0,
                aggregate = item,
            })
        end
    end

    table.sort(rows, function(left, right)
        if tostring(left.name or "") ~= tostring(right.name or "") then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return tostring(left.tabName or "") < tostring(right.tabName or "")
    end)

    return rows
end

function inventoryView.BuildTableRows(snapshot, db, query)
    local rows = {}
    local filters = {}

    if type(query) == "table" then
        filters = query
    elseif type(query) == "string" and query ~= "" then
        filters.itemName = query
    end

    for _, item in ipairs(inventoryView.FilterItems(snapshot_item_rows(snapshot), filters.itemName or filters.name or "")) do
        local minimum, hasMinimum = minimum_for_item(db, item, item.tabName)
        local current = tonumber(item.quantity or 0) or 0
        local tier = crafted_quality_markup(item.itemID, item.craftedQualityIcon, item.craftedQuality, item.craftedQualityMax)
        local tierAtlas = crafted_quality_atlas(item.itemID, item.craftedQualityIcon, item.craftedQuality, item.craftedQualityMax)
        local tierValue = crafted_quality_rank(item)
        local itemName = tostring(item.name or "Unknown")
        local bankTab = item.tabName or "-"
        local minimumText = hasMinimum and tostring(minimum) or "-"
        local restock = hasMinimum and (current < minimum and "Yes" or "No") or "No"
        table.insert(rows, {
            rowKey = item.rowKey,
            itemID = tostring(item.itemID or ""),
            tier = tierAtlas ~= "" and "" or tier,
            tierIconAtlas = tierAtlas,
            tierValue = tierValue,
            itemName = itemName,
            bankTab = bankTab,
            bankTabValue = string.lower(bankTab),
            current = tostring(current),
            currentValue = current,
            restock = restock,
            restockValue = restock == "Yes" and 1 or 0,
            quantity = minimumText,
            quantityValue = hasMinimum and minimum or 0,
            quality = tier,
            qualityValue = tierValue,
            name = itemName,
            tab = bankTab,
            minimum = minimumText,
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
        tier = "tierValue",
        current = "currentValue",
        quantity = "quantityValue",
        tab = "tab",
        bankTab = "bankTabValue",
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

        return tostring(left.itemName or left.name or "") < tostring(right.itemName or right.name or "")
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

function inventoryView.BuildCsvText(rows)
    local lines = {
        "Item ID,Tier,Item,Bank Tab,Current,Restock,Minimum",
    }

    for _, row in ipairs(rows or {}) do
        lines[#lines + 1] = table.concat({
            csv_escape(row.itemID or ""),
            csv_escape(row.tierValue or 0),
            csv_escape(row.itemName or row.name or ""),
            csv_escape(row.bankTab or row.tab or "-"),
            csv_escape(row.current or 0),
            csv_escape(row.restock or "No"),
            csv_escape(row.minimum or row.quantity or "-"),
        }, ",")
    end

    return table.concat(lines, "\n")
end

ns.modules.inventoryView = inventoryView

return inventoryView
