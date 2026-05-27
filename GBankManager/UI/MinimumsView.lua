local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsView = ns.modules.minimumsView or {}
local craftedQuality = ns.modules.craftedQuality or {}
local itemCatalog = ns.modules.itemCatalog or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end
if itemCatalog.ApplyCanonicalCraftedQuality == nil and type(_G.dofile) == "function" then
    itemCatalog = _G.dofile("GBankManager/Domain/ItemCatalog.lua")
end

local function canonical_item(item)
    if type(itemCatalog.ApplyCanonicalCraftedQuality) == "function" then
        return itemCatalog.ApplyCanonicalCraftedQuality(item)
    end

    return item
end

local function preferred_quality_icon(item)
    item = type(item) == "table" and item or {}
    return tostring(item.craftedQualityIcon or item.craftedQualityPreferredAtlas or item.craftedQualityDisplayAtlas or "")
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
        updatedAt = rule.updatedAt or previous.updatedAt,
        updatedBy = rule.updatedBy or previous.updatedBy,
        updatedByRankIndex = rule.updatedByRankIndex ~= nil and rule.updatedByRankIndex or previous.updatedByRankIndex,
        craftedQuality = rule.craftedQuality or previous.craftedQuality,
        craftedQualityIcon = rule.craftedQualityIcon or previous.craftedQualityIcon,
        craftedQualityMax = rule.craftedQualityMax or previous.craftedQualityMax,
        draftKey = rule.draftKey or previous.draftKey,
        originalItemID = rule.originalItemID or previous.originalItemID,
        originalScope = rule.originalScope or previous.originalScope,
        originalTabName = rule.originalTabName ~= nil and rule.originalTabName or previous.originalTabName,
        isNewlyAdded = rule.isNewlyAdded == true or previous.isNewlyAdded == true,
    }
end

local function crafted_quality_markup(itemID, atlasName, fallbackQuality, maxQuality)
    if type(craftedQuality.DisplayMarkupForItem) == "function" then
        return craftedQuality.DisplayMarkupForItem(itemID, atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if type(craftedQuality.DisplayMarkup) == "function" then
        return craftedQuality.DisplayMarkup(atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if type(craftedQuality.ToMarkupForItem) == "function" then
        return craftedQuality.ToMarkupForItem(itemID, atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if type(craftedQuality.ToMarkup) == "function" then
        return craftedQuality.ToMarkup(atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if atlasName == nil or atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function crafted_quality_atlas(itemID, atlasName, fallbackQuality, maxQuality)
    if type(craftedQuality.GetDisplayAtlasForItem) == "function" then
        return craftedQuality.GetDisplayAtlasForItem(itemID, atlasName, fallbackQuality, nil, maxQuality)
    end

    if type(craftedQuality.GetDisplayAtlas) == "function" then
        return craftedQuality.GetDisplayAtlas(atlasName, fallbackQuality, nil, maxQuality)
    end

    return tostring(atlasName or "")
end

local function crafted_quality_rank(item)
    item = item or {}

    if type(craftedQuality.ParseTier) == "function" then
        local parsedTier = craftedQuality.ParseTier(item.craftedQualityIcon, item.craftedQuality)
        if parsedTier > 0 then
            return parsedTier
        end
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

local function snapshot_bank_rows(snapshot)
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

    for itemID, item in pairs(snapshotItems) do
        local hadTabs = false
        for tabName, count in pairs(item.tabs or {}) do
            hadTabs = true
            table.insert(rows, {
                rowKey = table.concat({ tostring(itemID or ""), "TAB", tostring(tabName or "") }, "|"),
                itemID = itemID,
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
                rowKey = tostring(itemID or ""),
                itemID = itemID,
                name = item.name,
                quality = item.quality,
                craftedQuality = item.craftedQuality,
                craftedQualityIcon = item.craftedQualityIcon,
                craftedQualityMax = item.craftedQualityMax,
                tabName = primary_tab(item),
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

local function tab_row_key(itemID, tabName)
    return table.concat({ tostring(itemID or ""), "TAB", tostring(tabName or "") }, "|")
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
    local tableLayouts = ns.modules.tableLayouts
    if tableLayouts and type(tableLayouts.GetInventoryMinimumColumns) == "function" then
        return tableLayouts.GetInventoryMinimumColumns()
    end

    return {}
end

function minimumsView.Upsert(list, rule)
    list = list or {}
    rule = rule or {}

    local updated = false
    for index, existing in ipairs(list) do
        local sameDraft = existing.draftKey ~= nil and rule.draftKey ~= nil and existing.draftKey == rule.draftKey
        local sameRule = existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName
        local sameOriginal = rule.originalItemID ~= nil
            and existing.itemID == rule.originalItemID
            and existing.scope == (rule.originalScope or rule.scope)
            and existing.tabName == rule.originalTabName

        if sameDraft or sameRule or sameOriginal then
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
    normalizedRule.updatedAt = metadata.timestamp or normalizedRule.updatedAt or _G.time()
    normalizedRule.updatedBy = metadata.actor or normalizedRule.updatedBy or "Unknown"
    normalizedRule.updatedByRankIndex = metadata.actorRankIndex ~= nil and metadata.actorRankIndex or normalizedRule.updatedByRankIndex
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

function minimumsView.SaveForApprovedRequest(db, request, bankTab, metadata)
    db = db or {}
    request = request or {}
    metadata = metadata or {}

    local itemID = tonumber(request.itemID)
    local itemName = tostring(request.itemName or "")
    local quantity = tonumber(request.quantity)
    bankTab = tostring(bankTab or "")
    if not itemID or itemName == "" or not quantity or quantity <= 0 or bankTab == "" then
        return nil
    end

    local rule = {
        itemID = itemID,
        itemName = itemName,
        quantity = quantity,
        scope = "TAB",
        tabName = bankTab,
        enabled = true,
        craftedQuality = request.craftedQuality,
        craftedQualityIcon = request.craftedQualityIcon,
        craftedQualityMax = request.craftedQualityMax,
    }

    minimumsView.UpsertWithAudit(db, rule, metadata)
    request.minimumRuleKey = table.concat({ tostring(itemID), "TAB", bankTab }, "|")
    request.tabName = bankTab
    request.approvedBankTab = bankTab
    return rule
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

function minimumsView.RemoveWithAudit(db, rule, metadata)
    db = db or {}
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    metadata = metadata or {}

    local removed = nil
    local remaining = {}

    for _, existing in ipairs(db.minimums) do
        if removed == nil and rule_key(existing) == rule_key(rule) then
            removed = existing
        else
            table.insert(remaining, existing)
        end
    end

    db.minimums = remaining

    if removed then
        table.insert(db.auditLog, {
            category = "MINIMUM",
            type = "MINIMUM_REMOVED",
            actor = metadata.actor or "Unknown",
            itemID = removed.itemID,
            itemName = removed.itemName,
            oldValue = tostring(removed.quantity or 0),
            newValue = "REMOVED",
            timestamp = metadata.timestamp or _G.time(),
        })
    end

    return db.minimums
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
        local unresolvedGlobalTab = tostring(row.scope or "TAB") == "GLOBAL" and tostring(row.tabName or "") == ""
        local configuredTab = unresolvedGlobalTab and "GLOBAL" or tostring(row.tabName or (item and primary_tab(item)) or "-")
        local currentCount = current_count_for_rule(item, row)
        local minimumCount = tonumber(row.quantity or 0) or 0
        local shouldRestock = row.enabled ~= false and currentCount < minimumCount
        local source = item and "Configured" or "Manual"
        local qualitySource = canonical_item(item or row)

        table.insert(out, {
            rowKey = row.draftKey or rule_key(row),
            itemID = tostring(row.itemID or ""),
            itemName = tostring(row.itemName or "Unknown"),
            tier = "",
            tierAtlas = crafted_quality_atlas(row.itemID, preferred_quality_icon(qualitySource), qualitySource.craftedQuality, qualitySource.craftedQualityFamilySize or qualitySource.craftedQualityMax),
            tierIconAtlas = crafted_quality_atlas(row.itemID, preferred_quality_icon(qualitySource), qualitySource.craftedQuality, qualitySource.craftedQualityFamilySize or qualitySource.craftedQualityMax),
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
            configuredSort = unresolvedGlobalTab and -1 or 0,
            configured = true,
            craftedQuality = qualitySource.craftedQuality,
            craftedQualityDisplayAtlas = qualitySource.craftedQualityDisplayAtlas,
            craftedQualityPreferredAtlas = qualitySource.craftedQualityPreferredAtlas,
            craftedQualityFamilySize = qualitySource.craftedQualityFamilySize,
            craftedQualityIcon = qualitySource.craftedQualityIcon,
            craftedQualityMax = qualitySource.craftedQualityMax,
            isNewlyAdded = row.isNewlyAdded == true,
            needsBankTab = unresolvedGlobalTab,
            sourceRequestId = row.sourceRequestId,
            sourceRequestBackfill = row.sourceRequestBackfill == true,
        })
        seen[tab_row_key(row.itemID, configuredTab)] = true
    end

    for _, itemRow in ipairs(snapshot_bank_rows(snapshot)) do
        local configuredTab = itemRow.tabName or "-"
        local itemID = itemRow.itemID
        if showAll and not seen[tab_row_key(itemID, configuredTab)] then
            local item = canonical_item(itemRow.aggregate)
            local currentCount = tonumber(itemRow.quantity or 0) or 0
            table.insert(out, {
                rowKey = tab_row_key(itemID, configuredTab),
                itemID = tostring(itemID or ""),
                itemName = tostring(itemRow.name or "Unknown"),
                tier = "",
                tierAtlas = crafted_quality_atlas(itemID, preferred_quality_icon(item), item.craftedQuality, item.craftedQualityFamilySize or item.craftedQualityMax),
                tierIconAtlas = crafted_quality_atlas(itemID, preferred_quality_icon(item), item.craftedQuality, item.craftedQualityFamilySize or item.craftedQualityMax),
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
                craftedQualityDisplayAtlas = item.craftedQualityDisplayAtlas,
                craftedQualityPreferredAtlas = item.craftedQualityPreferredAtlas,
                craftedQualityFamilySize = item.craftedQualityFamilySize,
                craftedQualityIcon = item.craftedQualityIcon,
                craftedQualityMax = item.craftedQualityMax,
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
        if tostring(left.itemName or "") ~= tostring(right.itemName or "") then
            return tostring(left.itemName or "") < tostring(right.itemName or "")
        end

        return tostring(left.bankTab or "") < tostring(right.bankTab or "")
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
    local itemCatalog = ns.modules.itemCatalog
    if itemCatalog and type(itemCatalog.ResolveQuery) == "function" then
        return itemCatalog.ResolveQuery(snapshot, query)
    end

    return {
        status = "missing",
        matches = {},
    }
end

function minimumsView.GetMinimumSettings(db)
    local store = ns.data.store or ns.modules.store
    return store.GetMinimumSettings(db)
end

ns.modules.minimumsView = minimumsView

return minimumsView
