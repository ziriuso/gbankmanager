local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local itemCatalog = ns.modules.itemCatalog or {}
local ITEM_DATA_ADDON_NAME = "GBankManager_ItemData"

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

local function hydrate_namespace_from_globals()
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

local function append_unique_item(items, seenByItemID, item)
    if type(item) ~= "table" then
        return
    end

    local itemID = tonumber(item.itemID)
    local itemName = tostring(item.name or item.itemName or "")
    if not itemID or itemName == "" or seenByItemID[itemID] then
        return
    end

    seenByItemID[itemID] = true
    table.insert(items, {
        itemID = itemID,
        name = itemName,
        quality = item.quality,
        qualityName = item.qualityName,
        craftedQuality = item.craftedQuality,
        craftedQualityIcon = item.craftedQualityIcon,
        totalCount = item.totalCount,
        tabs = item.tabs,
    })
end

function itemCatalog.GetBundledItems()
    if not itemCatalog.EnsureBundledDataLoaded() then
        return {}
    end

    local diagnostics = get_bundled_search_diagnostics()
    return type((diagnostics.catalog or {}).items) == "table" and diagnostics.catalog.items or {}
end

function itemCatalog.GetBundledSearchPayload()
    if not itemCatalog.EnsureBundledDataLoaded() then
        return nil
    end

    return get_bundled_search_diagnostics().payload
end

function itemCatalog.BuildSearchCatalog(db, snapshot, options)
    db = db or {}
    snapshot = snapshot or {}
    options = options or {}

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

    return items
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

    return items
end

function itemCatalog.CreateSearchSession(snapshot)
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

    local itemID = tonumber((item or {}).itemID)
    local itemName = tostring((item or {}).name or (item or {}).itemName or "")
    if not itemID or itemName == "" then
        return nil
    end

    for _, existing in ipairs(savedCatalog) do
        if tonumber(existing.itemID) == itemID then
            existing.name = itemName
            existing.quality = (item or {}).quality or existing.quality
            existing.qualityName = (item or {}).qualityName or existing.qualityName
            existing.craftedQuality = (item or {}).craftedQuality or existing.craftedQuality
            existing.craftedQualityIcon = (item or {}).craftedQualityIcon or existing.craftedQualityIcon
            return existing
        end
    end

    local entry = {
        itemID = itemID,
        name = itemName,
        quality = (item or {}).quality,
        qualityName = (item or {}).qualityName,
        craftedQuality = (item or {}).craftedQuality,
        craftedQualityIcon = (item or {}).craftedQualityIcon,
    }
    table.insert(savedCatalog, entry)
    return entry
end

local function item_id_from_link(link)
    return tonumber(string.match(tostring(link or ""), "item:(%d+)"))
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

    return {
        itemID = itemID,
        name = itemName,
        quality = tonumber(itemQuality),
    }
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
