local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsView = ns.modules.minimumsView or {}

local QUALITY_RANK_BY_ATLAS = {
    ["Professions-ChatIcon-Quality-Tier1"] = 1,
    ["Professions-ChatIcon-Quality-Tier2"] = 2,
    ["Professions-ChatIcon-Quality-Tier3"] = 3,
    ["Professions-ChatIcon-Quality-Tier4"] = 4,
    ["Professions-ChatIcon-Quality-Tier5"] = 5,
}

local DEFAULT_COLUMNS = {
    { key = "itemID", label = "Item ID", width = 72, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "tier", label = "Tier", width = 60, justifyH = "CENTER", filterMode = "none", sortable = true },
    { key = "itemName", label = "Item", width = 196, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "bankTab", label = "Bank Tab", width = 116, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "current", label = "Current", width = 64, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "restock", label = "Restock", width = 70, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "quantity", label = "Minimum", width = 70, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "restockFrom", label = "Restock\nSource", width = 100, justifyH = "LEFT", filterMode = "text", sortable = true },
}

local function copy_columns(columns)
    local out = {}

    for index, column in ipairs(columns or {}) do
        out[index] = {
            key = column.key,
            label = column.label,
            width = column.width,
            justifyH = column.justifyH,
            filterMode = column.filterMode,
            sortable = column.sortable,
        }
    end

    return out
end

local function rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local function normalize_rule(rule, previous)
    rule = rule or {}
    previous = previous or {}

    local enabled = false
    if rule.enabled ~= nil then
        enabled = rule.enabled and true or false
    elseif previous.enabled ~= nil then
        enabled = previous.enabled and true or false
    end

    local scope = rule.scope or previous.scope or "TAB"
    local tabName = rule.tabName ~= nil and rule.tabName or previous.tabName

    if tabName and tabName ~= "" then
        scope = "TAB"
    end

    return {
        itemID = rule.itemID,
        itemName = rule.itemName,
        quantity = rule.quantity or 0,
        scope = scope,
        tabName = tabName,
        enabled = enabled,
        craftedQuality = rule.craftedQuality or previous.craftedQuality,
        craftedQualityIcon = rule.craftedQualityIcon or previous.craftedQualityIcon,
        draftKey = rule.draftKey or previous.draftKey,
        originalItemID = rule.originalItemID or previous.originalItemID,
        originalScope = rule.originalScope or previous.originalScope,
        originalTabName = rule.originalTabName ~= nil and rule.originalTabName or previous.originalTabName,
    }
end

local function crafted_quality_markup(atlasName)
    if atlasName == nil or atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function crafted_quality_rank(item)
    item = item or {}

    local atlasName = tostring(item.craftedQualityIcon or "")
    if QUALITY_RANK_BY_ATLAS[atlasName] ~= nil then
        return QUALITY_RANK_BY_ATLAS[atlasName]
    end

    local tierText = string.match(atlasName, "[Tt]ier%s*[_%-]?(%d+)")
    local parsedTier = tonumber(tierText or "")
    if parsedTier and parsedTier >= 1 and parsedTier <= 5 then
        return parsedTier
    end

    local quality = tonumber(item.craftedQuality or 0) or 0
    if quality < 1 or quality > 5 then
        return 0
    end

    return quality
end

local function normalized_sort_value(key, value, direction)
    if key == "tier" then
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

local function sorted_tabs(item)
    local tabs = {}

    for tabName, count in pairs((item or {}).tabs or {}) do
        table.insert(tabs, {
            name = tostring(tabName),
            count = tonumber(count or 0) or 0,
        })
    end

    table.sort(tabs, function(left, right)
        if left.count ~= right.count then
            return left.count > right.count
        end
        return left.name < right.name
    end)

    return tabs
end

local function primary_tab(item)
    local tabs = sorted_tabs(item)
    local first = tabs[1]
    return first and first.name or "-"
end

local function current_count_for_rule(item, rule)
    if not item then
        return 0
    end

    local tabName = (rule or {}).tabName
    if tabName and tabName ~= "" then
        return tonumber(((item.tabs or {})[tabName]) or 0) or 0
    end

    return tonumber(item.totalCount or 0) or 0
end

local function restock_from(item, configuredTab, shouldRestock)
    if not shouldRestock then
        return "-"
    end

    for _, tab in ipairs(sorted_tabs(item)) do
        if tab.name ~= configuredTab and tab.count > 0 then
            return tab.name
        end
    end

    return "Auction"
end

local function matches_search(row, search)
    if search == "" then
        return true
    end

    local fields = {
        row.itemID,
        row.itemName,
        row.bankTab,
        row.restockFrom,
        row.restock,
    }

    for _, value in ipairs(fields) do
        if string.find(string.lower(tostring(value or "")), search, 1, true) ~= nil then
            return true
        end
    end

    return false
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

function minimumsView.GetDefaultColumns()
    return copy_columns(DEFAULT_COLUMNS)
end

function minimumsView.Upsert(list, rule)
    list = list or {}
    rule = rule or {}

    local updated = false
    for index, existing in ipairs(list) do
        local sameDraft = existing.draftKey ~= nil and rule.draftKey ~= nil and existing.draftKey == rule.draftKey
        local sameRule = existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName

        if sameDraft or sameRule then
            list[index] = normalize_rule(rule, existing)
            updated = true
            break
        end
    end

    if not updated then
        table.insert(list, normalize_rule(rule))
    end

    return list
end

function minimumsView.UpsertWithAudit(db, rule, metadata)
    db = db or {}
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local previous = nil
    local previousIndex = nil
    for index, existing in ipairs(db.minimums) do
        local originalItemID = rule.originalItemID or rule.itemID
        local originalScope = rule.originalScope or rule.scope
        local originalTabName = rule.originalTabName
        local sameCurrent = existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName
        local sameOriginal = existing.itemID == originalItemID and existing.scope == originalScope and existing.tabName == originalTabName

        if sameCurrent or sameOriginal then
            previous = existing
            previousIndex = index
            break
        end
    end

    local normalizedRule = normalize_rule(rule, previous)
    if previousIndex ~= nil then
        db.minimums[previousIndex] = normalizedRule
    else
        db.minimums = minimumsView.Upsert(db.minimums, normalizedRule)
    end

    table.insert(db.auditLog, {
        category = "MINIMUM",
        type = previous and "MINIMUM_UPDATED" or "MINIMUM_CREATED",
        actor = metadata.actor or "Unknown",
        itemID = normalizedRule.itemID,
        itemName = normalizedRule.itemName,
        oldValue = previous and tostring(previous.quantity or 0) or nil,
        newValue = tostring(normalizedRule.quantity or 0),
        timestamp = metadata.timestamp or _G.time(),
    })

    return db.minimums
end

function minimumsView.SetEnabledWithAudit(db, rule, enabled, metadata)
    db = db or {}
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local existing = nil
    for _, candidate in ipairs(db.minimums) do
        if rule_key(candidate) == rule_key(rule) then
            existing = candidate
            break
        end
    end

    local previousEnabled = existing and existing.enabled ~= false or false
    local normalizedRule = normalize_rule(rule, existing)
    normalizedRule.enabled = enabled and true or false

    db.minimums = minimumsView.Upsert(db.minimums, normalizedRule)

    if previousEnabled ~= normalizedRule.enabled then
        table.insert(db.auditLog, {
            category = "MINIMUM",
            type = normalizedRule.enabled and "MINIMUM_ENABLED" or "MINIMUM_DISABLED",
            actor = metadata.actor or "Unknown",
            itemID = normalizedRule.itemID,
            itemName = normalizedRule.itemName,
            oldValue = previousEnabled and "ENABLED" or "DISABLED",
            newValue = normalizedRule.enabled and "ENABLED" or "DISABLED",
            timestamp = metadata.timestamp or _G.time(),
        })
    end

    return normalizedRule
end

function minimumsView.BuildTableRows(rows, snapshot, options)
    local out = {}
    local snapshotItems = ((snapshot or {}).items) or {}
    local seen = {}
    options = options or {}
    local showAll = options.showAll ~= false
    local search = string.lower(tostring(options.search or ""))
    local manualOnly = options.manualOnly == true
    local columnFilters = options.columnFilters or {}

    for _, row in ipairs(rows or {}) do
        local item = snapshotItems[row.itemID]
        local configuredTab = tostring(row.tabName or (item and primary_tab(item)) or "-")
        local currentCount = current_count_for_rule(item, row)
        local minimumCount = tonumber(row.quantity or 0) or 0
        local shouldRestock = row.enabled ~= false and currentCount < minimumCount
        local source = item and "Configured" or "Manual"
        local qualitySource = item or row

        table.insert(out, {
            rowKey = row.draftKey or rule_key(row),
            itemID = tostring(row.itemID or ""),
            itemName = tostring(row.itemName or "Unknown"),
            tier = crafted_quality_markup(qualitySource.craftedQualityIcon),
            tierValue = crafted_quality_rank(qualitySource),
            quantity = tostring(minimumCount),
            quantityValue = minimumCount,
            scope = tostring(row.scope or "TAB"),
            originalScope = row.scope or "TAB",
            originalItemID = row.itemID,
            originalTabName = row.tabName,
            tabName = configuredTab,
            tabKey = row.tabName or "",
            bankTab = configuredTab,
            bankTabValue = string.lower(configuredTab),
            current = tostring(currentCount),
            currentValue = currentCount,
            restock = row.enabled ~= false and "Yes" or "No",
            restockValue = row.enabled ~= false and 1 or 0,
            restockFrom = restock_from(item, configuredTab, shouldRestock),
            restockFromValue = string.lower(restock_from(item, configuredTab, shouldRestock)),
            source = source,
            enabledSort = row.enabled ~= false and 0 or 1,
            configuredSort = 0,
            configured = true,
            craftedQuality = qualitySource.craftedQuality,
            craftedQualityIcon = qualitySource.craftedQualityIcon,
        })
        seen[row.itemID] = true
    end

    for itemID, item in pairs(snapshotItems) do
        if showAll and not seen[itemID] then
            local configuredTab = primary_tab(item)
            local currentCount = tonumber(((item.tabs or {})[configuredTab]) or item.totalCount or 0) or 0
            table.insert(out, {
                rowKey = table.concat({ tostring(itemID or ""), "TAB", tostring(configuredTab or "") }, "|"),
                itemID = tostring(itemID or ""),
                itemName = tostring(item.name or "Unknown"),
                tier = crafted_quality_markup(item.craftedQualityIcon),
                tierValue = crafted_quality_rank(item),
                quantity = "-",
                quantityValue = 0,
                scope = "TAB",
                originalScope = "TAB",
                originalItemID = itemID,
                originalTabName = configuredTab,
                tabName = configuredTab,
                tabKey = configuredTab,
                bankTab = configuredTab,
                bankTabValue = string.lower(configuredTab),
                current = tostring(currentCount),
                currentValue = currentCount,
                restock = "No",
                restockValue = 0,
                restockFrom = "-",
                restockFromValue = "",
                source = "Bank",
                enabledSort = 1,
                configuredSort = 1,
                configured = false,
                craftedQuality = item.craftedQuality,
                craftedQualityIcon = item.craftedQualityIcon,
            })
        end
    end

    if not showAll then
        local filtered = {}
        for _, row in ipairs(out) do
            if row.restock == "Yes" then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    if manualOnly then
        local filtered = {}
        for _, row in ipairs(out) do
            if row.source == "Manual" then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    if search ~= "" then
        local filtered = {}
        for _, row in ipairs(out) do
            if matches_search(row, search) then
                table.insert(filtered, row)
            end
        end
        out = filtered
    end

    out = apply_column_filters(out, columnFilters)

    table.sort(out, function(left, right)
        if left.enabledSort ~= right.enabledSort then
            return left.enabledSort < right.enabledSort
        end
        if left.configuredSort ~= right.configuredSort then
            return left.configuredSort < right.configuredSort
        end
        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return out
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

function minimumsView.SortRows(rows, sortState)
    rows = rows or {}
    sortState = sortState or {}

    local key = sortState.key
    if key == nil or key == "" then
        return rows
    end

    local direction = sortState.direction or "asc"
    local valueKey = ({
        tier = "tierValue",
        current = "currentValue",
        quantity = "quantityValue",
        bankTab = "bankTabValue",
        restock = "restockValue",
        restockFrom = "restockFromValue",
    })[key] or key

    table.sort(rows, function(left, right)
        local leftValue = normalized_sort_value(key, left[valueKey], direction)
        local rightValue = normalized_sort_value(key, right[valueKey], direction)
        local ordered = compare_with_direction(leftValue, rightValue, direction)

        if ordered ~= nil then
            return ordered
        end

        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return rows
end

function minimumsView.ResolveItemQuery(snapshot, query)
    local items = {}
    local itemMap = ((snapshot or {}).items) or {}
    local raw = tostring(query or "")
    local numericId = tonumber(raw)
    local lowered = string.lower(raw)

    for _, item in pairs(itemMap) do
        table.insert(items, item)
    end

    table.sort(items, function(left, right)
        if tostring(left.name or "") ~= tostring(right.name or "") then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return crafted_quality_rank(left) < crafted_quality_rank(right)
    end)

    if numericId then
        for _, item in ipairs(items) do
            if tonumber(item.itemID) == numericId then
                return {
                    status = "resolved",
                    item = item,
                    matches = { item },
                }
            end
        end

        return {
            status = "missing",
            matches = {},
        }
    end

    local matches = {}
    for _, item in ipairs(items) do
        if lowered ~= "" and string.find(string.lower(item.name or ""), lowered, 1, true) ~= nil then
            table.insert(matches, item)
        end
    end

    if #matches == 1 then
        return {
            status = "resolved",
            item = matches[1],
            matches = matches,
        }
    end

    if #matches > 1 then
        return {
            status = "multiple",
            matches = matches,
        }
    end

    return {
        status = "missing",
        matches = {},
    }
end

function minimumsView.GetMinimumSettings(db)
    db = db or {}
    db.ui = db.ui or {}
    db.ui.minimumSettings = db.ui.minimumSettings or {}
    db.ui.minimumSettings.defaultQuantity = tonumber(db.ui.minimumSettings.defaultQuantity or 100) or 100
    return db.ui.minimumSettings
end

ns.modules.minimumsView = minimumsView

return minimumsView
