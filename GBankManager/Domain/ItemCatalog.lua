local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local itemCatalog = ns.modules.itemCatalog or {}
local ITEM_DATA_ADDON_NAME = "GBankManager_ItemData"
local ensure_payload_quality_families
local hydrate_namespace_from_globals

local function strip_legacy_tier_prefix(value)
    local text = tostring(value or "")
    text = text:gsub("^|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("^%s*%[[Tt]%d+%]%s*", "")
    return text
end

local function item_id_from_link(link)
    return tonumber(string.match(tostring(link or ""), "item:(%d+)"))
end

local function get_bundled_search_diagnostics()
    local payload = ns.data.staticItemSearch
        or ns.modules.staticItemSearch
        or _G.GBankManagerItemSearchPayload
        or nil
    local catalog = ns.data.staticItemCatalog
        or ns.modules.staticItemCatalog
        or _G.GBankManagerItemCatalogData
        or nil
    local metadata = type(payload) == "table" and payload.metadata or nil
    local loadedItemCount = type(catalog) == "table" and type(catalog.items) == "table" and #catalog.items or 0
    local expectedItemCount = tonumber(type(metadata) == "table" and metadata.itemCount or 0) or 0
    local tokenCount = tonumber(type(metadata) == "table" and metadata.tokenCount or 0) or 0
    local ready = type(payload) == "table"
        and type(payload.itemsByID) == "table"
        and type(payload.tokenToItemIDs) == "table"
        and type(metadata) == "table"
        and metadata.ready == true
        and expectedItemCount > 0
        and tokenCount > 0
        and loadedItemCount == expectedItemCount

    return {
        payload = payload,
        catalog = catalog,
        metadata = metadata,
        loadedItemCount = loadedItemCount,
        expectedItemCount = expectedItemCount,
        tokenCount = tokenCount,
        ready = ready,
    }
end

local function get_available_bundled_payload()
    hydrate_namespace_from_globals()
    local diagnostics = get_bundled_search_diagnostics()
    local payload = diagnostics.payload
    if type((payload or {}).itemsByID) == "table" and next(payload.itemsByID) ~= nil then
        return ensure_payload_quality_families(payload)
    end

    return nil
end

hydrate_namespace_from_globals = function()
    if type(_G.GBankManagerItemSearchPayload) == "table" then
        ns.data.staticItemSearch = ns.data.staticItemSearch or _G.GBankManagerItemSearchPayload
        ns.modules.staticItemSearch = ns.modules.staticItemSearch or _G.GBankManagerItemSearchPayload
    end

    if type(_G.GBankManagerItemCatalogData) == "table" then
        ns.data.staticItemCatalog = ns.data.staticItemCatalog or _G.GBankManagerItemCatalogData
        ns.modules.staticItemCatalog = ns.modules.staticItemCatalog or _G.GBankManagerItemCatalogData
    end
end

function itemCatalog.GetBundledSearchDiagnostics()
    hydrate_namespace_from_globals()
    return get_bundled_search_diagnostics()
end

function itemCatalog.IsBundledDataLoaded()
    hydrate_namespace_from_globals()
    return get_bundled_search_diagnostics().ready == true
end

function itemCatalog.EnsureBundledDataLoaded()
    if itemCatalog.IsBundledDataLoaded() then
        return true
    end

    local loader = _G.C_AddOns and _G.C_AddOns.LoadAddOn or _G.LoadAddOn
    if type(loader) ~= "function" then
        return false
    end

    local isLoaded = _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded
    local loaded, _ = loader(ITEM_DATA_ADDON_NAME)
    if loaded or (type(isLoaded) == "function" and isLoaded(ITEM_DATA_ADDON_NAME)) then
        hydrate_namespace_from_globals()
        return itemCatalog.IsBundledDataLoaded()
    end

    return false
end

function itemCatalog.HydrateItem(item)
    item = type(item) == "table" and item or {}

    local itemLink = tostring(item.itemLink or "")
    local itemString = tostring(item.itemString or "")
    local itemID = tonumber(item.itemID) or item_id_from_link(itemLink) or item_id_from_link(itemString)
    local itemName = strip_legacy_tier_prefix(item.name or item.itemName or "")
    if not itemID or itemName == "" then
        return nil
    end

    return {
        itemID = itemID,
        name = itemName,
        itemName = itemName,
        itemLink = itemLink ~= "" and itemLink or nil,
        itemString = itemString ~= "" and itemString or nil,
        quality = tonumber(item.quality) or item.quality,
        qualityName = item.qualityName,
        craftedQuality = tonumber(item.craftedQuality) or item.craftedQuality,
        craftedQualityIcon = item.craftedQualityIcon,
        craftedQualityMax = tonumber(item.craftedQualityMax) or item.craftedQualityMax,
        craftedQualityDisplayAtlas = item.craftedQualityDisplayAtlas,
        craftedQualityPreferredAtlas = item.craftedQualityPreferredAtlas,
        craftedQualityFamilySize = tonumber(item.craftedQualityFamilySize) or item.craftedQualityFamilySize,
        totalCount = tonumber(item.totalCount) or item.totalCount,
        tabs = item.tabs,
    }
end

local function append_unique_item(items, seenByItemID, item)
    local entry = itemCatalog.HydrateItem(item)
    if type(entry) ~= "table" then
        return
    end
    local itemID = entry.itemID

    local existing = seenByItemID[itemID]
    if existing and type(existing) == "table" then
        existing.name = entry.name ~= "" and entry.name or existing.name
        existing.itemName = existing.itemName or entry.itemName
        existing.itemLink = existing.itemLink or entry.itemLink
        existing.itemString = existing.itemString or entry.itemString
        existing.quality = existing.quality or entry.quality
        existing.qualityName = existing.qualityName or entry.qualityName
        existing.craftedQuality = existing.craftedQuality or entry.craftedQuality
        existing.craftedQualityIcon = existing.craftedQualityIcon or entry.craftedQualityIcon
        existing.craftedQualityMax = existing.craftedQualityMax or entry.craftedQualityMax
        existing.craftedQualityDisplayAtlas = existing.craftedQualityDisplayAtlas or entry.craftedQualityDisplayAtlas
        existing.craftedQualityPreferredAtlas = existing.craftedQualityPreferredAtlas or entry.craftedQualityPreferredAtlas
        existing.craftedQualityFamilySize = existing.craftedQualityFamilySize or entry.craftedQualityFamilySize
        existing.totalCount = existing.totalCount or entry.totalCount
        existing.tabs = existing.tabs or entry.tabs
        return
    end

    seenByItemID[itemID] = entry
    table.insert(items, entry)
end

local function normalize_family_name(value)
    return string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function crafted_quality_display_atlas(item)
    item = type(item) == "table" and item or {}
    local quality = tonumber(item.craftedQuality or 0) or 0
    local maxQuality = tonumber(item.craftedQualityMax or 0) or 0
    if quality < 1 then
        return nil
    end

    if maxQuality == 2 then
        if quality == 1 then
            return "Professions-Icon-Quality-12-Tier1-Inv"
        end
        if quality == 2 then
            return "Professions-Icon-Quality-12-Tier2-Inv"
        end
    end

    if maxQuality >= 3 then
        return string.format("Professions-ChatIcon-Quality-Tier%d", quality)
    end

    return tostring(item.craftedQualityIcon or "") ~= "" and item.craftedQualityIcon or string.format("Professions-ChatIcon-Quality-Tier%d", quality)
end

local function apply_crafted_quality_families(items)
    local tiersByName = {}

    for _, item in ipairs(items or {}) do
        local familyName = normalize_family_name(item.name or item.itemName or "")
        local tier = tonumber(item.craftedQuality or 0) or 0
        if familyName ~= "" and tier >= 1 and tier <= 5 then
            tiersByName[familyName] = tiersByName[familyName] or {}
            tiersByName[familyName][tier] = true
        end
    end

    for _, item in ipairs(items or {}) do
        local familyName = normalize_family_name(item.name or item.itemName or "")
        local familyTiers = tiersByName[familyName] or {}
        local distinctCount = 0
        local maxTier = 0
        for tier = 1, 5 do
            if familyTiers[tier] then
                distinctCount = distinctCount + 1
                maxTier = tier
            end
        end

        if maxTier >= 3 then
            item.craftedQualityMax = 5
        elseif distinctCount == 2 and familyTiers[1] and familyTiers[2] then
            item.craftedQualityMax = 2
        elseif item.craftedQualityMax == nil then
            item.craftedQualityMax = maxTier > 0 and maxTier or nil
        end

        local canonicalDisplayAtlas = crafted_quality_display_atlas(item)
        if tostring(canonicalDisplayAtlas or "") ~= "" then
            item.craftedQualityDisplayAtlas = canonicalDisplayAtlas
            item.craftedQualityPreferredAtlas = canonicalDisplayAtlas
        elseif tostring(item.craftedQualityPreferredAtlas or "") == "" then
            item.craftedQualityPreferredAtlas = tostring(item.craftedQualityDisplayAtlas or item.craftedQualityIcon or "")
        end
        if tonumber(item.craftedQualityFamilySize or 0) == 0 and tonumber(item.craftedQualityMax or 0) > 0 then
            item.craftedQualityFamilySize = tonumber(item.craftedQualityMax or 0) or 0
        end
    end

    return items
end

ensure_payload_quality_families = function(payload)
    payload = type(payload) == "table" and payload or nil
    if not payload or payload.craftedQualityFamiliesReady == true then
        return payload
    end

    local indexedItems = {}
    for _, item in pairs(payload.itemsByID or {}) do
        if type(item) == "table" then
            indexedItems[#indexedItems + 1] = item
        end
    end

    apply_crafted_quality_families(indexedItems)
    payload.craftedQualityFamiliesReady = true
    return payload
end

function itemCatalog.GetBundledItems()
    if not itemCatalog.EnsureBundledDataLoaded() then
        return {}
    end

    local diagnostics = get_bundled_search_diagnostics()
    local items = type((diagnostics.catalog or {}).items) == "table" and diagnostics.catalog.items or {}
    return apply_crafted_quality_families(items)
end

function itemCatalog.GetBundledSearchPayload()
    if not itemCatalog.EnsureBundledDataLoaded() then
        return get_available_bundled_payload()
    end

    return get_available_bundled_payload()
end

function itemCatalog.GetBundledItemByID(itemID)
    local numericID = tonumber(itemID)
    if not numericID then
        return nil
    end

    local payload = itemCatalog.GetBundledSearchPayload() or get_available_bundled_payload()
    return type((payload or {}).itemsByID) == "table" and payload.itemsByID[numericID] or nil
end

function itemCatalog.ApplyCanonicalCraftedQuality(item)
    item = type(item) == "table" and item or nil
    if not item then
        return item
    end

    local numericID = tonumber(item.itemID)
    if not numericID then
        return item
    end

    local bundledItem = itemCatalog.GetBundledItemByID(numericID)
    local bundledQualityEntry = ns.data.staticCraftedQualityByItemID
        or ns.modules.staticCraftedQualityByItemID
        or _G.GBankManagerItemQualityByID
        or {}
    bundledQualityEntry = bundledQualityEntry[numericID]

    if type(bundledItem) ~= "table" and type(bundledQualityEntry) ~= "table" then
        return item
    end

    item.craftedQuality = (bundledQualityEntry and bundledQualityEntry.craftedQuality) or (bundledItem and bundledItem.craftedQuality) or item.craftedQuality
    item.craftedQualityIcon = (bundledQualityEntry and bundledQualityEntry.craftedQualityIcon) or (bundledItem and bundledItem.craftedQualityIcon) or item.craftedQualityIcon
    item.craftedQualityMax = (bundledQualityEntry and bundledQualityEntry.craftedQualityMax) or (bundledItem and bundledItem.craftedQualityMax) or item.craftedQualityMax
    item.craftedQualityDisplayAtlas = (bundledQualityEntry and bundledQualityEntry.craftedQualityDisplayAtlas) or (bundledItem and bundledItem.craftedQualityDisplayAtlas) or item.craftedQualityDisplayAtlas
    item.craftedQualityPreferredAtlas = (bundledQualityEntry and bundledQualityEntry.craftedQualityPreferredAtlas) or (bundledItem and bundledItem.craftedQualityPreferredAtlas) or item.craftedQualityPreferredAtlas or item.craftedQualityDisplayAtlas
    item.craftedQualityFamilySize = (bundledQualityEntry and bundledQualityEntry.craftedQualityFamilySize) or (bundledItem and bundledItem.craftedQualityFamilySize) or item.craftedQualityFamilySize or item.craftedQualityMax
    local canonicalDisplayAtlas = crafted_quality_display_atlas(item)
    if tostring(canonicalDisplayAtlas or "") ~= "" then
        item.craftedQualityDisplayAtlas = canonicalDisplayAtlas
        item.craftedQualityPreferredAtlas = canonicalDisplayAtlas
    end
    item.name = strip_legacy_tier_prefix((bundledItem and bundledItem.name) or item.name or item.itemName or "")
    item.itemName = item.name
    return item
end

function itemCatalog.StripLegacyTierPrefix(value)
    return strip_legacy_tier_prefix(value)
end

local function overlay_bundled_crafted_quality(items)
    hydrate_namespace_from_globals()
    itemCatalog.EnsureBundledDataLoaded()
    local payload = get_available_bundled_payload()
    local itemsByID = type((payload or {}).itemsByID) == "table" and payload.itemsByID or nil
    if not itemsByID then
        return items
    end

    for _, item in ipairs(items or {}) do
        itemCatalog.ApplyCanonicalCraftedQuality(item)
    end

    return items
end

function itemCatalog.BuildSearchCatalog(db, snapshot, options)
    db = db or {}
    snapshot = snapshot or {}
    options = options or {}

    itemCatalog.EnsureBundledDataLoaded()

    local items = {}
    local seenByItemID = {}
    local store = ns.data.store or ns.modules.store
    local savedCatalog = store and type(store.GetMinimumItemCatalog) == "function" and store.GetMinimumItemCatalog(db) or {}

    if options.includeBundled ~= false then
        for _, item in ipairs(itemCatalog.GetBundledItems()) do
            append_unique_item(items, seenByItemID, item)
        end
    end

    for _, item in ipairs(savedCatalog or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    for _, item in ipairs(db.minimums or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    for _, item in ipairs(db.requests or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    for _, item in ipairs(db.oneTimeTargets or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    for _, item in pairs(snapshot.items or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    table.sort(items, function(left, right)
        if tostring(left.name or "") ~= tostring(right.name or "") then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return (tonumber(left.itemID or 0) or 0) < (tonumber(right.itemID or 0) or 0)
    end)

    overlay_bundled_crafted_quality(items)
    return apply_crafted_quality_families(items)
end

local function collect_search_items(snapshot)
    local items = {}
    local seenByItemID = {}

    for _, item in pairs((snapshot or {}).items or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    for _, item in ipairs((snapshot or {}).searchCatalog or {}) do
        append_unique_item(items, seenByItemID, item)
    end

    table.sort(items, function(left, right)
        if tostring(left.name or "") ~= tostring(right.name or "") then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return (tonumber(left.itemID or 0) or 0) < (tonumber(right.itemID or 0) or 0)
    end)

    return apply_crafted_quality_families(items)
end

function itemCatalog.CreateSearchSession(snapshot)
    itemCatalog.EnsureBundledDataLoaded()
    local payload = itemCatalog.GetBundledSearchPayload()
    return {
        payload = payload,
        payloadDiagnostics = get_bundled_search_diagnostics(),
        recentQueries = {},
        fallbackItems = collect_search_items(snapshot),
    }
end

function itemCatalog.IsSearchSessionIndexedReady(session)
    return type(session) == "table" and itemCatalog.IsBundledSearchReady(session.payload)
end

function itemCatalog.StoreResolvedItem(db, item)
    db = db or {}
    local store = ns.data.store or ns.modules.store
    local savedCatalog = store and type(store.GetMinimumItemCatalog) == "function" and store.GetMinimumItemCatalog(db) or nil
    if type(savedCatalog) ~= "table" then
        return nil
    end

    local entry = itemCatalog.HydrateItem(item)
    if type(entry) ~= "table" then
        return nil
    end
    local itemID = entry.itemID
    local itemName = entry.name

    for _, existing in ipairs(savedCatalog) do
        if tonumber(existing.itemID) == itemID then
            existing.name = itemName
            existing.itemName = existing.itemName or entry.itemName
            existing.itemLink = entry.itemLink or existing.itemLink
            existing.itemString = entry.itemString or existing.itemString
            existing.quality = entry.quality or existing.quality
            existing.qualityName = entry.qualityName or existing.qualityName
            existing.craftedQuality = entry.craftedQuality or existing.craftedQuality
            existing.craftedQualityIcon = entry.craftedQualityIcon or existing.craftedQualityIcon
            existing.craftedQualityMax = entry.craftedQualityMax or existing.craftedQualityMax
            existing.craftedQualityDisplayAtlas = entry.craftedQualityDisplayAtlas or existing.craftedQualityDisplayAtlas
            existing.craftedQualityPreferredAtlas = entry.craftedQualityPreferredAtlas or existing.craftedQualityPreferredAtlas
            existing.craftedQualityFamilySize = entry.craftedQualityFamilySize or existing.craftedQualityFamilySize
            return existing
        end
    end

    table.insert(savedCatalog, entry)
    return entry
end

local function resolve_item_from_client_cache(query)
    local getter = _G.GetItemInfo
    if type(getter) ~= "function" then
        return nil
    end

    local itemName, itemLink, itemQuality = getter(query)
    if itemName == nil or itemName == "" then
        local requestor = _G.C_Item and _G.C_Item.RequestLoadItemDataByID
        local numericId = tonumber(query)
        if numericId and type(requestor) == "function" then
            requestor(numericId)
        end
        return nil
    end

    local itemID = tonumber(query) or item_id_from_link(itemLink)
    if not itemID then
        return nil
    end

    return itemCatalog.HydrateItem({
        itemID = itemID,
        name = itemName,
        itemLink = itemLink,
        quality = tonumber(itemQuality),
    })
end

local function normalize_text(value)
    local normalized = string.lower(tostring(value or ""))
    normalized = normalized:gsub("[^%w]+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")
    normalized = normalized:gsub("%s+", " ")
    return normalized
end

local function normalize_token(token)
    local normalized = tostring(token or "")
    if #normalized > 3 and normalized:sub(-1) == "s" and normalized:sub(-2) ~= "ss" then
        normalized = normalized:sub(1, -2)
    end
    return normalized
end

local function tokenize_text(value)
    local normalized = normalize_text(value)
    local tokens = {}
    for token in string.gmatch(normalized, "%S+") do
        table.insert(tokens, normalize_token(token))
    end
    return normalized, tokens
end

local INDEX_QUERY_STOP_WORDS = {
    a = true,
    an = true,
    the = true,
}

local function filter_index_query_tokens(tokens)
    local filtered = {}
    for _, token in ipairs(tokens or {}) do
        if not INDEX_QUERY_STOP_WORDS[token] then
            table.insert(filtered, token)
        end
    end
    return filtered
end

local score_name_match
local add_ranked_match

function itemCatalog.IsBundledSearchReady(payload)
    local metadata = type(payload) == "table" and payload.metadata or nil
    return type(payload) == "table"
        and type(payload.itemsByID) == "table"
        and type(payload.tokenToItemIDs) == "table"
        and type(metadata) == "table"
        and metadata.ready == true
        and (tonumber(metadata.itemCount) or 0) > 0
        and (tonumber(metadata.tokenCount) or 0) > 0
end

local function copy_item_ids(source)
    local copied = {}
    for index, itemID in ipairs(source or {}) do
        copied[index] = tonumber(itemID)
    end
    return copied
end

local function merge_unique_item_ids(target, additions, seen)
    target = target or {}
    seen = seen or {}

    for _, itemID in ipairs(additions or {}) do
        local numericID = tonumber(itemID)
        if numericID and not seen[numericID] then
            seen[numericID] = true
            table.insert(target, numericID)
        end
    end

    return target
end

local function sorted_unique_item_ids(itemIDs)
    local unique = {}
    local seen = {}
    for _, itemID in ipairs(itemIDs or {}) do
        local numericID = tonumber(itemID)
        if numericID and not seen[numericID] then
            seen[numericID] = true
            table.insert(unique, numericID)
        end
    end
    table.sort(unique)
    return unique
end

local function token_matches_query(indexToken, queryToken)
    return string.find(tostring(indexToken or ""), tostring(queryToken or ""), 1, true) == 1
end

local function resolve_query_token_item_ids(tokenToItemIDs, queryToken)
    local matches = {}
    local seen = {}
    local exact = tokenToItemIDs[queryToken]
    if type(exact) == "table" and #exact > 0 then
        merge_unique_item_ids(matches, exact, seen)
    end

    for indexToken, itemIDs in pairs(tokenToItemIDs or {}) do
        if indexToken ~= queryToken and token_matches_query(indexToken, queryToken) then
            merge_unique_item_ids(matches, itemIDs, seen)
        end
    end

    table.sort(matches)
    return matches
end

local function intersect_item_id_lists(left, right)
    if #left == 0 or #right == 0 then
        return {}
    end

    local seen = {}
    for _, itemID in ipairs(right) do
        seen[tonumber(itemID)] = true
    end

    local intersection = {}
    for _, itemID in ipairs(left) do
        local numericID = tonumber(itemID)
        if numericID and seen[numericID] then
            table.insert(intersection, numericID)
        end
    end

    return intersection
end

local function intersect_token_lists(tokenToItemIDs, queryTokens)
    local candidateIDs = nil
    for _, queryToken in ipairs(queryTokens or {}) do
        local matchingIDs = resolve_query_token_item_ids(tokenToItemIDs or {}, queryToken)
        if #matchingIDs == 0 then
            return {}
        end

        if candidateIDs == nil then
            candidateIDs = copy_item_ids(matchingIDs)
        else
            candidateIDs = intersect_item_id_lists(candidateIDs, matchingIDs)
        end

        if #candidateIDs == 0 then
            return {}
        end
    end

    return candidateIDs or {}
end

local function rank_indexed_matches(payload, candidateIDs, normalizedQuery, queryTokens)
    local indexedItems = {}
    for _, itemID in ipairs(candidateIDs or {}) do
        local item = type(payload.itemsByID) == "table" and payload.itemsByID[itemID] or nil
        if item then
            table.insert(indexedItems, item)
        end
    end

    return indexedItems
end

local function has_all_tokens(queryTokens, nameTokens)
    if #queryTokens == 0 then
        return false
    end

    for _, queryToken in ipairs(queryTokens) do
        local matched = false
        for _, nameToken in ipairs(nameTokens) do
            if string.find(nameToken, queryToken, 1, true) == 1 then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    return true
end

local function has_tokens_in_order(queryTokens, nameTokens)
    if #queryTokens == 0 then
        return false
    end

    local queryIndex = 1
    for _, token in ipairs(nameTokens) do
        if string.find(token, queryTokens[queryIndex], 1, true) == 1 then
            queryIndex = queryIndex + 1
            if queryIndex > #queryTokens then
                return true
            end
        end
    end

    return false
end

score_name_match = function(queryText, queryTokens, itemName)
    local normalizedName, nameTokens = tokenize_text(itemName)
    if queryText == "" or #queryTokens == 0 or not has_all_tokens(queryTokens, nameTokens) then
        return nil
    end

    if normalizedName == queryText then
        return 400
    end

    if string.find(normalizedName, queryText, 1, true) == 1 then
        return 300
    end

    if has_tokens_in_order(queryTokens, nameTokens) then
        return 200
    end

    return 100
end

add_ranked_match = function(scoredMatches, item, score)
    if not item or not score then
        return scoredMatches
    end

    scoredMatches = scoredMatches or {}
    for _, existing in ipairs(scoredMatches) do
        if tonumber(existing.item.itemID) == tonumber(item.itemID) then
            if score > existing.score then
                existing.item = item
                existing.score = score
            end
            return scoredMatches
        end
    end

    table.insert(scoredMatches, {
        item = item,
        score = score,
    })
    return scoredMatches
end

local function sort_scored_matches(scoredMatches)
    table.sort(scoredMatches, function(left, right)
        if left.score ~= right.score then
            return left.score > right.score
        end
        if tostring(left.item.name or "") == tostring(right.item.name or "") then
            local leftTier = tonumber(left.item.craftedQuality or 0) or 0
            local rightTier = tonumber(right.item.craftedQuality or 0) or 0
            if leftTier ~= rightTier then
                return leftTier > rightTier
            end
        end
        if tostring(left.item.name or "") ~= tostring(right.item.name or "") then
            return tostring(left.item.name or "") < tostring(right.item.name or "")
        end
        return (tonumber(left.item.itemID or 0) or 0) < (tonumber(right.item.itemID or 0) or 0)
    end)
end

local function extract_scored_items(scoredMatches)
    local matches = {}
    for _, entry in ipairs(scoredMatches or {}) do
        table.insert(matches, entry.item)
    end
    return matches
end

local function rank_matches(items, normalizedQuery, queryTokens)
    local scoredMatches = {}
    for _, item in ipairs(items or {}) do
        local score = score_name_match(normalizedQuery, queryTokens, item.name or item.itemName or "")
        if score then
            scoredMatches = add_ranked_match(scoredMatches, item, score)
        end
    end

    sort_scored_matches(scoredMatches)
    return extract_scored_items(scoredMatches)
end

local function resolve_query_against_items(items, query)
    local raw = tostring(query or "")
    local numericId = tonumber(raw)
    local normalizedQuery, queryTokens = tokenize_text(raw)

    if numericId then
        for _, item in ipairs(items or {}) do
            if tonumber(item.itemID) == numericId then
                return {
                    status = "resolved",
                    item = item,
                    matches = { item },
                }
            end
        end

        local cachedItem = resolve_item_from_client_cache(numericId)
        if cachedItem then
            return {
                status = "resolved",
                item = cachedItem,
                matches = { cachedItem },
            }
        end

        return {
            status = "missing",
            matches = {},
        }
    end

    local combinedItems = {}
    local seenByItemID = {}
    for _, item in ipairs(items or {}) do
        append_unique_item(combinedItems, seenByItemID, item)
    end

    local cachedItem = resolve_item_from_client_cache(raw)
    if cachedItem then
        append_unique_item(combinedItems, seenByItemID, cachedItem)
    end

    local matches = rank_matches(combinedItems, normalizedQuery, queryTokens)
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

    if cachedItem then
        return {
            status = "resolved",
            item = cachedItem,
            matches = { cachedItem },
        }
    end

    return {
        status = "missing",
        matches = {},
    }
end

local function session_cache_key(query)
    local raw = tostring(query or "")
    local numericId = tonumber(raw)
    if numericId then
        return "id:" .. tostring(numericId)
    end

    return "name:" .. normalize_text(raw)
end

function itemCatalog.ResolveQuery(snapshot, query)
    return resolve_query_against_items(collect_search_items(snapshot), query)
end

function itemCatalog.ResolveIndexedQuery(payload, query)
    payload = ensure_payload_quality_families(payload)
    if not itemCatalog.IsBundledSearchReady(payload) then
        return {
            status = "missing",
            matches = {},
        }
    end

    local raw = tostring(query or "")
    local numericId = tonumber(raw)
    local normalizedQuery, queryTokens = tokenize_text(raw)
    queryTokens = filter_index_query_tokens(queryTokens)

    if numericId then
        local resolved = payload.itemsByID[numericId]
        if resolved then
            return {
                status = "resolved",
                item = resolved,
                matches = { resolved },
            }
        end

        return {
            status = "missing",
            matches = {},
        }
    end

    if normalizedQuery == "" or #queryTokens == 0 then
        return {
            status = "missing",
            matches = {},
        }
    end

    local candidateIDs = intersect_token_lists(payload.tokenToItemIDs, queryTokens)
    local matches = rank_indexed_matches(payload, candidateIDs, normalizedQuery, queryTokens)
    matches = rank_matches(matches, normalizedQuery, queryTokens)

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

function itemCatalog.ResolveSearchSessionQuery(session, query)
    if type(session) ~= "table" then
        return itemCatalog.ResolveQuery({ items = {}, searchCatalog = {} }, query)
    end

    session.recentQueries = session.recentQueries or {}
    local cacheKey = session_cache_key(query)
    if session.recentQueries[cacheKey] ~= nil then
        return session.recentQueries[cacheKey]
    end

    local indexedResolution = itemCatalog.ResolveIndexedQuery(session.payload, query)
    local fallbackResolution = resolve_query_against_items(session.fallbackItems or {}, query)
    local finalResolution = nil
    local numericId = tonumber(tostring(query or ""))
    local indexedReady = itemCatalog.IsSearchSessionIndexedReady(session)

    if numericId then
        if indexedResolution.status == "resolved" then
            finalResolution = indexedResolution
        else
            finalResolution = fallbackResolution
        end
    else
        if not indexedReady then
            finalResolution = {
                status = "unavailable",
                matches = {},
                message = "Bundled item database unavailable.",
            }
            session.recentQueries[cacheKey] = finalResolution
            return finalResolution
        end

        local normalizedQuery, queryTokens = tokenize_text(query)
        local combinedMatches = {}
        local seenByItemID = {}

        for _, item in ipairs(indexedResolution.matches or {}) do
            append_unique_item(combinedMatches, seenByItemID, item)
        end
        for _, item in ipairs(fallbackResolution.matches or {}) do
            append_unique_item(combinedMatches, seenByItemID, item)
        end

        local rankedMatches = rank_matches(combinedMatches, normalizedQuery, queryTokens)
        if #rankedMatches == 1 then
            finalResolution = {
                status = "resolved",
                item = rankedMatches[1],
                matches = rankedMatches,
            }
        elseif #rankedMatches > 1 then
            finalResolution = {
                status = "multiple",
                matches = rankedMatches,
            }
        elseif fallbackResolution.status == "resolved" then
            finalResolution = fallbackResolution
        else
            finalResolution = {
                status = "missing",
                matches = {},
            }
        end
    end

    session.recentQueries[cacheKey] = finalResolution
    return finalResolution
end

ns.modules.itemCatalog = itemCatalog

return itemCatalog
