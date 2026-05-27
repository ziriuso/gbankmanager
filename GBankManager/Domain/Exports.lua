local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end

local function current_item_catalog()
    local itemCatalog = ns.modules.itemCatalog or {}
    if itemCatalog.GetBundledItemByID == nil and type(_G.dofile) == "function" then
        itemCatalog = _G.dofile("GBankManager/Domain/ItemCatalog.lua")
    end

    return itemCatalog
end

local function preferred_quality_icon(item)
    item = type(item) == "table" and item or {}
    return tostring(item.craftedQualityIcon or item.craftedQualityPreferredAtlas or item.craftedQualityDisplayAtlas or "")
end

local function render_field(row, field)
    return tostring(row[field] or "")
end

local function normalize_export_inline_atlas(atlasName, fallbackQuality, maxQuality)
    atlasName = tostring(atlasName or "")
    local quality = tonumber(fallbackQuality or 0) or 0
    local familySize = tonumber(maxQuality or 0) or 0

    if quality == 1 and familySize == 2 and atlasName == "Professions-ChatIcon-Quality-Tier1" then
        return "Professions-ChatIcon-Quality-12-Tier1"
    end

    if quality == 2 and familySize <= 0 and atlasName == "Professions-ChatIcon-Quality-Tier2" then
        return "Interface-Crafting-ReagentQuality-2-Med"
    end

    return atlasName
end

local function crafted_quality_markup(atlasName, fallbackQuality, maxQuality)
    atlasName = normalize_export_inline_atlas(atlasName, fallbackQuality, maxQuality)

    if type(craftedQuality.DisplayMarkup) == "function" then
        return craftedQuality.DisplayMarkup(atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if type(craftedQuality.ToMarkup) == "function" then
        return craftedQuality.ToMarkup(atlasName, 22, "reagent", fallbackQuality, maxQuality)
    end

    if atlasName == nil or atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function crafted_quality_markup_for_item(itemID, atlasName, fallbackQuality, maxQuality)
    if type(craftedQuality.DisplayMarkupForItem) == "function" then
        local markup = craftedQuality.DisplayMarkupForItem(itemID, atlasName, 22, "reagent", fallbackQuality, maxQuality)
        if markup ~= "" then
            local normalizedAtlas = normalize_export_inline_atlas(
                tostring(markup):match("^|A:([^:]+):") or "",
                fallbackQuality,
                maxQuality
            )
            if normalizedAtlas ~= "" and normalizedAtlas ~= tostring(markup):match("^|A:([^:]+):") then
                return string.format("|A:%s:22:22|a", normalizedAtlas)
            end
            return markup
        end
    end

    return crafted_quality_markup(atlasName, fallbackQuality, maxQuality)
end

local function crafted_quality_atlas_for_item(itemID, atlasName, fallbackQuality, maxQuality)
    if type(craftedQuality.GetDisplayAtlasForItem) == "function" then
        local resolvedAtlas = craftedQuality.GetDisplayAtlasForItem(itemID, atlasName, fallbackQuality, nil, maxQuality)
        return normalize_export_inline_atlas(resolvedAtlas, fallbackQuality, maxQuality)
    end

    if type(craftedQuality.GetDisplayAtlas) == "function" then
        local resolvedAtlas = craftedQuality.GetDisplayAtlas(atlasName, fallbackQuality, nil, maxQuality)
        return normalize_export_inline_atlas(resolvedAtlas, fallbackQuality, maxQuality)
    end

    return normalize_export_inline_atlas(atlasName, fallbackQuality, maxQuality)
end

local function crafted_quality_icon_for_value(quality, maxQuality)
    quality = math.max(0, math.floor(tonumber(quality or 0) or 0))
    if quality < 1 or quality > 5 then
        return ""
    end

    local atlasName = string.format("Professions-ChatIcon-Quality-Tier%d", quality)
    if quality == 2 and (tonumber(maxQuality or 0) or 0) <= 0 then
        maxQuality = 2
    end
    if type(craftedQuality.NormalizeDisplayAtlas) == "function" then
        return craftedQuality.NormalizeDisplayAtlas(atlasName, quality, "reagent", maxQuality)
    end

    return atlasName
end

local function excess_qty_cell_details(excessQty)
    excessQty = math.max(0, math.floor(tonumber(excessQty or 0) or 0))
    if excessQty <= 0 then
        return tostring(excessQty), nil
    end

    return tostring(excessQty), {
        atlas = "common-icon-forwardarrow",
        align = "RIGHT",
        rightInset = 10,
        size = 14,
        tint = { 1.0, 0.82, 0.0, 1.0 },
        textRightPadding = 22,
    }
end

function exports.BuildDelimited(rows, template)
    local lines = {}
    template = template or {}

    if template.includeHeader then
        table.insert(lines, table.concat(template.fields or {}, template.delimiter or ","))
    end

    for _, row in ipairs(rows or {}) do
        local values = {}
        for _, field in ipairs(template.fields or {}) do
            local valueField = (template.labels or {})[field] or field
            table.insert(values, render_field(row, valueField))
        end
        table.insert(lines, table.concat(values, template.delimiter or ","))
    end

    return table.concat(lines, "\n")
end

function exports.BuildAuctionator(rows, shoppingListName)
    local lines = {}
    local seen = {}

    shoppingListName = tostring(shoppingListName or "GBankManager")
    rows = type(rows) == "table" and rows or {}
    lines[1] = shoppingListName

    for _, row in ipairs(rows) do
        local itemName = tostring(row.itemName or "")
        local totalToBuy = tonumber(row.totalToBuy or 0) or 0

        if itemName ~= "" and totalToBuy > 0 and not seen[itemName] then
            seen[itemName] = true
            table.insert(lines, itemName)
        end
    end

    return table.concat(lines, "^")
end

local function current_total(snapshot, itemID)
    local item = snapshot and snapshot.items and snapshot.items[itemID]
    if item == nil then
        return 0
    end

    return item.totalCount or 0
end

local function current_tab_total(snapshotItem, bankTab)
    snapshotItem = type(snapshotItem) == "table" and snapshotItem or {}
    bankTab = tostring(bankTab or "")
    if bankTab == "" or bankTab == "GLOBAL" then
        return tonumber(snapshotItem.totalCount or 0) or 0
    end

    return tonumber(((snapshotItem.tabs or {})[bankTab]) or 0) or 0
end

local function minimum_rule_quantity(db, itemID, bankTab)
    local total = 0
    bankTab = tostring(bankTab or "")
    for _, minimum in ipairs((db or {}).minimums or {}) do
        if minimum.enabled ~= false and tonumber(minimum.itemID) == tonumber(itemID) then
            local scope = tostring(minimum.scope or "GLOBAL")
            local minimumTab = tostring(minimum.tabName or "")
            if bankTab == "GLOBAL" or bankTab == "" then
                if scope ~= "TAB" then
                    total = total + (tonumber(minimum.quantity or 0) or 0)
                end
            elseif scope == "TAB" and minimumTab == bankTab then
                total = total + (tonumber(minimum.quantity or 0) or 0)
            end
        end
    end

    return total
end

local function summarize_scopes(details)
    local scopes = {}
    local seen = {}

    for _, detail in ipairs(details or {}) do
        local label = detail.scope or "GLOBAL"
        if detail.scope == "TAB" and detail.tabName and detail.tabName ~= "" then
            label = detail.tabName
        end

        if not seen[label] then
            seen[label] = true
            table.insert(scopes, label)
        end
    end

    table.sort(scopes)
    return #scopes > 0 and table.concat(scopes, "|") or "GLOBAL"
end

local function primary_bank_tab(details)
    for _, detail in ipairs(details or {}) do
        if detail.scope == "TAB" and detail.tabName and detail.tabName ~= "" then
            return detail.tabName
        end
    end

    return summarize_scopes(details)
end

local function stocked_elsewhere(snapshotItem, bankTab)
    local out = {}
    bankTab = tostring(bankTab or "")

    if bankTab == "" or bankTab == "GLOBAL" then
        return out
    end

    for tabName, quantity in pairs((snapshotItem or {}).tabs or {}) do
        quantity = tonumber(quantity or 0) or 0
        if tostring(tabName) ~= bankTab and quantity > 0 then
            table.insert(out, {
                tabName = tostring(tabName),
                quantity = quantity,
            })
        end
    end

    table.sort(out, function(left, right)
        local leftQuantity = tonumber(left.quantity or 0) or 0
        local rightQuantity = tonumber(right.quantity or 0) or 0
        if leftQuantity ~= rightQuantity then
            return leftQuantity > rightQuantity
        end

        return tostring(left.tabName or "") < tostring(right.tabName or "")
    end)
    return out
end

local function quality_for_item(db, snapshot, itemID)
    db = db or {}
    snapshot = snapshot or { items = {} }

    local snapshotItem = snapshot.items and snapshot.items[itemID]
    if snapshotItem then
        local snapshotQuality = tonumber(snapshotItem.craftedQuality or 0) or 0
        if snapshotQuality > 0 then
            return snapshotQuality
        end
    end

    local itemCatalog = current_item_catalog()
    local bundledItem = type(itemCatalog.GetBundledItemByID) == "function" and itemCatalog.GetBundledItemByID(itemID) or nil
    local bundledQuality = tonumber((bundledItem or {}).craftedQuality or 0) or 0
    if bundledQuality > 0 then
        return bundledQuality
    end

    for _, source in ipairs({
        db.minimums,
        db.oneTimeTargets,
        db.requests,
    }) do
        for _, entry in ipairs(source or {}) do
            if entry.itemID == itemID then
                local quality = tonumber(entry.quality or entry.craftedQuality or 0) or 0
                if quality > 0 then
                    return quality
                end
            end
        end
    end

    return 0
end

local function quality_icon_for_item(db, snapshot, itemID)
    db = db or {}
    snapshot = snapshot or { items = {} }

    local snapshotItem = snapshot.items and snapshot.items[itemID]
    local atlasName = preferred_quality_icon(snapshotItem)
    if atlasName ~= "" then
        return atlasName
    end

    local itemCatalog = current_item_catalog()
    local bundledItem = type(itemCatalog.GetBundledItemByID) == "function" and itemCatalog.GetBundledItemByID(itemID) or nil
    atlasName = preferred_quality_icon(bundledItem)
    if atlasName ~= "" then
        return atlasName
    end

    for _, source in ipairs({
        db.minimums,
        db.oneTimeTargets,
        db.requests,
    }) do
        for _, entry in ipairs(source or {}) do
            if entry.itemID == itemID then
                atlasName = preferred_quality_icon(entry)
                if atlasName ~= "" then
                    return atlasName
                end
            end
        end
    end

    return ""
end

local function quality_max_for_item(db, snapshot, itemID)
    db = db or {}
    snapshot = snapshot or { items = {} }

    local snapshotItem = snapshot.items and snapshot.items[itemID]
    local maxQuality = tonumber((snapshotItem or {}).craftedQualityMax or 0) or 0
    if maxQuality > 0 then
        return maxQuality
    end

    local itemCatalog = current_item_catalog()
    local bundledItem = type(itemCatalog.GetBundledItemByID) == "function" and itemCatalog.GetBundledItemByID(itemID) or nil
    maxQuality = tonumber((bundledItem or {}).craftedQualityMax or 0) or 0
    if maxQuality > 0 then
        return maxQuality
    end

    for _, source in ipairs({
        db.minimums,
        db.oneTimeTargets,
        db.requests,
    }) do
        for _, entry in ipairs(source or {}) do
            if entry.itemID == itemID then
                maxQuality = tonumber(entry.craftedQualityMax or 0) or 0
                if maxQuality > 0 then
                    return maxQuality
                end
            end
        end
    end

    return 0
end

function exports.MaterializePlanRows(plan, snapshot, db)
    local rows = {}
    snapshot = snapshot or { items = {} }
    db = db or {}

    for _, row in pairs(plan or {}) do
        if (row.totalToBuy or 0) > 0 then
            local currentItem = snapshot.items and snapshot.items[row.itemID]
            local itemCatalog = current_item_catalog()
            if type(itemCatalog.ApplyCanonicalCraftedQuality) == "function" then
                itemCatalog.ApplyCanonicalCraftedQuality(row)
                itemCatalog.ApplyCanonicalCraftedQuality(currentItem)
            end
            local reasons = {}

            for reason, quantity in pairs(row.sources or {}) do
                if quantity > 0 then
                    table.insert(reasons, string.format("%s:%d", reason, quantity))
                end
            end

            table.sort(reasons)
            local bankTab = primary_bank_tab(row.details or {})
            local elsewhereTabs = stocked_elsewhere(currentItem, bankTab)
            local topElsewhereTab = elsewhereTabs[1]
            local excessQty = 0
            for _, elsewhere in ipairs(elsewhereTabs) do
                excessQty = excessQty + (tonumber(elsewhere.quantity or 0) or 0)
            end
            local qtyToBuy = math.max(0, (tonumber(row.totalToBuy or 0) or 0) - excessQty)
            local excessQtyLabel, excessQtyIcon = excess_qty_cell_details(excessQty)
            local quality = tonumber(row.quality or row.craftedQuality or (currentItem and currentItem.craftedQuality) or 0) or 0
            local craftedQualityMax = tonumber(row.craftedQualityFamilySize or row.craftedQualityMax or row.qualityTierMax or (currentItem and (currentItem.craftedQualityFamilySize or currentItem.craftedQualityMax)) or 0) or 0
            local craftedQualityDisplayAtlas = tostring(row.craftedQualityDisplayAtlas or (currentItem and currentItem.craftedQualityDisplayAtlas) or "") or ""
            local craftedQualityPreferredAtlas = tostring(row.craftedQualityPreferredAtlas or (currentItem and currentItem.craftedQualityPreferredAtlas) or craftedQualityDisplayAtlas) or ""
            local craftedQualityIcon = preferred_quality_icon(row)
            if craftedQualityIcon == "" then
                craftedQualityIcon = preferred_quality_icon(currentItem)
            end
            if craftedQualityIcon == "" then
                craftedQualityIcon = crafted_quality_icon_for_value(quality, craftedQualityMax)
            end
            table.insert(rows, {
                itemID = row.itemID,
                itemName = row.itemName,
                currentQuantity = current_total(snapshot, row.itemID),
                restockQuantity = (row.sources and row.sources.RESTOCK) or 0,
                targetQuantity = (row.sources and row.sources.ONE_TIME_TARGET) or 0,
                requestQuantity = (row.sources and row.sources.REQUEST) or 0,
                totalToBuy = row.totalToBuy,
                minQty = minimum_rule_quantity(db, row.itemID, bankTab),
                qtyInStock = current_tab_total(currentItem, bankTab),
                qtyToBuy = qtyToBuy,
                excessQty = excessQty,
                excessQtyValue = excessQty,
                excessQtyLabel = excessQtyLabel,
                excessQtyIconAtlas = excessQtyIcon and excessQtyIcon.atlas or "",
                cellIcons = excessQtyIcon and {
                    excessQtyLabel = excessQtyIcon,
                } or nil,
                quality = quality,
                craftedQualityMax = craftedQualityMax,
                craftedQualityDisplayAtlas = craftedQualityDisplayAtlas,
                craftedQualityPreferredAtlas = craftedQualityPreferredAtlas,
                craftedQualityIcon = craftedQualityIcon,
                itemTier = "",
                itemTierAtlas = crafted_quality_atlas_for_item(row.itemID, craftedQualityIcon, quality, craftedQualityMax),
                itemTierIconAtlas = crafted_quality_atlas_for_item(row.itemID, craftedQualityIcon, quality, craftedQualityMax),
                itemTierValue = quality,
                bankTab = bankTab,
                scopeSummary = summarize_scopes(row.details or {}),
                reason = table.concat(reasons, "|"),
                stockedElsewhere = topElsewhereTab and tostring(topElsewhereTab.tabName or "") or "None",
                stockedElsewhereTabs = elsewhereTabs,
            })
        end
    end

    table.sort(rows, function(left, right)
        return tostring(left.itemName) < tostring(right.itemName)
    end)

    return rows
end

function exports.FilterRowsUnavailableElsewhere(rows)
    local out = {}

    for _, row in ipairs(rows or {}) do
        if #((row or {}).stockedElsewhereTabs or {}) == 0 then
            table.insert(out, row)
        end
    end

    return out
end

function exports.BuildTsmItemIdList(rows)
    local values = {}
    local seen = {}

    for _, row in ipairs(rows or {}) do
        local itemID = tonumber(row.itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            table.insert(values, tostring(itemID))
        end
    end

    table.sort(values, function(left, right)
        return tonumber(left) < tonumber(right)
    end)
    return table.concat(values, ",")
end

function exports.BuildRowsFromDatabase(db)
    db = db or {}

    local planning = ns.modules.planning
    if planning == nil and type(_G.dofile) == "function" then
        planning = _G.dofile("GBankManager/Domain/Planning.lua")
    end

    local demandPlan = {}
    local snapshot = { items = {} }

    if planning and type(planning.BuildDemandPlanFromDatabase) == "function" then
        demandPlan, snapshot = planning.BuildDemandPlanFromDatabase(db)
    end

    local rows = exports.MaterializePlanRows(demandPlan, snapshot, db)

    for _, row in ipairs(rows) do
        row.quality = quality_for_item(db, snapshot, row.itemID)
        row.craftedQualityMax = quality_max_for_item(db, snapshot, row.itemID)
        row.craftedQualityIcon = quality_icon_for_item(db, snapshot, row.itemID)
        if tostring(row.craftedQualityIcon or "") == "" then
            row.craftedQualityIcon = crafted_quality_icon_for_value(row.quality, row.craftedQualityMax)
        end
        row.itemTier = ""
        row.itemTierAtlas = crafted_quality_atlas_for_item(row.itemID, row.craftedQualityIcon, row.quality, row.craftedQualityMax)
        row.itemTierIconAtlas = row.itemTierAtlas
        row.itemTierValue = tonumber(row.quality or 0) or 0
    end

    return rows, snapshot
end

ns.modules.exports = exports

return exports
