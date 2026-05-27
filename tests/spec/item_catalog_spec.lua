package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")

_G.GBankManagerNamespace = nil

local itemDataChunk, itemDataLoadError = loadfile("GBankManager_ItemData/Data.lua")
assert.truthy(itemDataChunk ~= nil, "generated item data should remain loadable by the Lua 5.1 runtime after full rebuilds")

assert.load_addon_from_toc("GBankManager_ItemData/GBankManager_ItemData.toc")
local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local itemCatalog = ns.modules.itemCatalog

assert.equal("GBankManager", addonName, "item catalog spec should load the addon toc")
assert.truthy(type(itemCatalog) == "table", "item catalog module should load from toc")
assert.truthy(type(itemCatalog.GetBundledItems) == "function", "item catalog should expose bundled items")
assert.truthy(type(itemCatalog.BuildSearchCatalog) == "function", "item catalog should build a shared search catalog")
assert.truthy(type(itemCatalog.StoreResolvedItem) == "function", "item catalog should store resolved items for future searches")
assert.truthy(type(itemCatalog.ResolveQuery) == "function", "item catalog should resolve exact and partial item queries")
assert.truthy(type(itemCatalog.IsBundledSearchReady) == "function", "item catalog should expose bundled indexed-search readiness validation")
assert.truthy(type(itemCatalog.ResolveIndexedQuery) == "function", "item catalog should expose bundled indexed query resolution")
assert.truthy(type(itemCatalog.ResolveSearchSessionQuery) == "function", "item catalog should expose session-based indexed query resolution")
assert.truthy(type(itemCatalog.EnsureBundledDataLoaded) == "function", "item catalog should expose the bundled item-data loader")
assert.truthy(itemCatalog.IsBundledDataLoaded() == true, "main addon should preserve preloaded bundled item data when the companion addon loads first")
local bundledItems = itemCatalog.GetBundledItems()
assert.truthy(#bundledItems >= 1, "bundled item catalog should seed at least one shared item")
assert.truthy(itemCatalog.IsBundledDataLoaded() == true, "bundled item data should load on demand")
assert.truthy(type(ns.modules.staticItemCatalog) == "table", "static item catalog should populate the shared namespace after load")
assert.equal(#bundledItems, tonumber((ns.modules.staticItemCatalog.metadata or {}).itemCount), "generated item data metadata should match the lazy-loaded bundled row count")
assert.truthy(type((bundledItems[1] or {}).itemID) == "number", "preloaded bundled item data should survive into the main addon namespace intact")
assert.truthy(type(_G.GBankManagerItemSearchPayload) == "table", "bundled item data companion should publish a global search payload bridge for retail runtime consumers")
assert.truthy(type(_G.GBankManagerItemCatalogData) == "table", "bundled item data companion should publish a global catalog bridge for retail runtime consumers")

local originalNamespaceSearch = ns.data.staticItemSearch
local originalNamespaceCatalog = ns.data.staticItemCatalog
local originalModuleSearch = ns.modules.staticItemSearch
local originalModuleCatalog = ns.modules.staticItemCatalog
ns.data.staticItemSearch = nil
ns.data.staticItemCatalog = nil
ns.modules.staticItemSearch = nil
ns.modules.staticItemCatalog = nil
assert.truthy(itemCatalog.IsBundledDataLoaded() == true, "item catalog should recover bundled data from the explicit global bridge when addon namespaces are not shared")
ns.data.staticItemSearch = originalNamespaceSearch
ns.data.staticItemCatalog = originalNamespaceCatalog
ns.modules.staticItemSearch = originalModuleSearch
ns.modules.staticItemCatalog = originalModuleCatalog

local originalStaticItemCatalog = ns.data.staticItemCatalog
local originalStaticItemSearch = ns.data.staticItemSearch
local originalAddOnsApi = _G.C_AddOns
local originalGlobalSearchPayload = _G.GBankManagerItemSearchPayload
local originalGlobalCatalogData = _G.GBankManagerItemCatalogData
ns.data.staticItemCatalog = { items = {} }
ns.data.staticItemSearch = {
    metadata = {
        ready = false,
        itemCount = 0,
        tokenCount = 0,
    },
    itemsByID = {},
    tokenToItemIDs = {},
}
_G.C_AddOns = {
    IsAddOnLoaded = function()
        return false
    end,
    LoadAddOn = function(addonName)
        assert.equal("GBankManager_ItemData", addonName, "item catalog should request the sibling bundled item-data addon by name")
        ns.data.staticItemCatalog.items = {
            { itemID = 1, name = "Synthetic Load Check" },
        }
        ns.data.staticItemSearch = {
            metadata = {
                ready = true,
                itemCount = 1,
                tokenCount = 1,
            },
            itemsByID = {
                [1] = { itemID = 1, name = "Synthetic Load Check" },
            },
            tokenToItemIDs = {
                synthetic = { 1 },
            },
        }
        _G.GBankManagerItemCatalogData = ns.data.staticItemCatalog
        _G.GBankManagerItemSearchPayload = ns.data.staticItemSearch
        return 1
    end,
}
assert.truthy(itemCatalog.EnsureBundledDataLoaded(), "item catalog should treat WoW truthy addon-load results as successful when bundled data becomes available")
ns.data.staticItemCatalog = originalStaticItemCatalog
ns.data.staticItemSearch = originalStaticItemSearch
_G.C_AddOns = originalAddOnsApi
_G.GBankManagerItemSearchPayload = originalGlobalSearchPayload
_G.GBankManagerItemCatalogData = originalGlobalCatalogData

local db = {
    minimums = {
        { itemID = 990002, itemName = "Unit Test Feast" },
    },
    requests = {
        { itemID = 990003, itemName = "Unit Test Hammer" },
    },
    oneTimeTargets = {},
    ui = {
        minimumItemCatalog = {
            { itemID = 990001, name = "Unit Test Saved Rune" },
        },
    },
}

local snapshot = {
    items = {
        [990004] = {
            itemID = 990004,
            name = "Unit Test Oil",
        },
    },
}

local searchCatalog = itemCatalog.BuildSearchCatalog(db, snapshot)
local namesByItemID = {}
for _, item in ipairs(searchCatalog) do
    namesByItemID[tonumber(item.itemID)] = item.name
end

assert.equal("Unit Test Oil", namesByItemID[990004], "shared item search catalog should include snapshot items")
assert.equal("Unit Test Hammer", namesByItemID[990003], "shared item search catalog should include request items for future reuse")
assert.equal("Unit Test Feast", namesByItemID[990002], "shared item search catalog should include minimum items")
assert.equal("Unit Test Saved Rune", namesByItemID[990001], "shared item search catalog should include saved catalog items")

local supplementalCatalog = itemCatalog.BuildSearchCatalog(db, snapshot, {
    includeBundled = false,
})
local supplementalNamesByItemID = {}
for _, item in ipairs(supplementalCatalog) do
    supplementalNamesByItemID[tonumber(item.itemID)] = item.name
end
assert.equal("Unit Test Oil", supplementalNamesByItemID[990004], "supplemental search catalog should still include snapshot items")
assert.equal("Unit Test Hammer", supplementalNamesByItemID[990003], "supplemental search catalog should still include request items")
assert.equal("Unit Test Feast", supplementalNamesByItemID[990002], "supplemental search catalog should still include minimum items")
assert.equal("Unit Test Saved Rune", supplementalNamesByItemID[990001], "supplemental search catalog should still include learned catalog items")
assert.truthy(supplementalNamesByItemID[7007] == nil, "supplemental search catalog should not duplicate bundled item-data rows when indexed bundled search is already available")

local stored = itemCatalog.StoreResolvedItem(db, {
    itemID = 19019,
    name = "Thunderfury, Blessed Blade of the Windseeker",
    quality = 5,
    qualityName = "Legendary",
    craftedQuality = 4,
    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier4",
})
assert.equal("Thunderfury, Blessed Blade of the Windseeker", stored.name, "item catalog should persist newly resolved search items")
assert.equal(4, stored.craftedQuality, "item catalog should persist crafted quality tiers for resolved items")
assert.equal("Professions-ChatIcon-Quality-Tier4", stored.craftedQualityIcon, "item catalog should persist crafted quality icons for resolved items")

local resolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = searchCatalog,
}, "Test Hamm")
assert.equal("resolved", resolution.status, "item catalog should resolve a single partial-name match when the query is unique")
assert.equal("Unit Test Hammer", resolution.item.name, "item catalog should return the resolved request item")

local minimumResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = searchCatalog,
}, "Test Fea")
assert.equal("resolved", minimumResolution.status, "item catalog should resolve partial-name matches sourced from shared minimums search entries when the query is unique")
assert.equal("Unit Test Feast", minimumResolution.item.name, "item catalog should return shared minimum items through the search catalog")

local requestResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = searchCatalog,
}, "Saved Ru")
assert.equal("resolved", requestResolution.status, "item catalog should resolve partial-name matches sourced from saved catalog entries when the query is unique")
assert.equal("Unit Test Saved Rune", requestResolution.item.name, "item catalog should return shared saved catalog items through the search catalog")

local function match_names(result)
    local names = {}
    for _, item in ipairs((result or {}).matches or {}) do
        table.insert(names, item.name)
    end
    table.sort(names)
    return table.concat(names, " | ")
end

local function ordered_match_names(result)
    local names = {}
    for _, item in ipairs((result or {}).matches or {}) do
        table.insert(names, item.name)
    end
    return table.concat(names, " | ")
end

local resolverSearchCatalog = {
    { itemID = 111001, name = "Flask of Supreme Power" },
    { itemID = 111002, name = "Flask of Distilled Wisdom" },
    { itemID = 111003, name = "Flask of Chromatic Resistance" },
    { itemID = 111004, name = "Flask of the Magisters" },
    { itemID = 111007, name = "Flask of the Magisters" },
    { itemID = 111005, name = "Flask of the Titans" },
    { itemID = 111006, name = "Crystal Vial" },
}

local broadTokenResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = resolverSearchCatalog,
}, "flask of")
assert.equal("multiple", broadTokenResolution.status, "item catalog should keep broad multi-word queries as multi-match results")
assert.equal(6, #broadTokenResolution.matches, "item catalog should include every matching Flask of variant for broad token queries")
assert.equal(
    "Flask of Chromatic Resistance | Flask of Distilled Wisdom | Flask of Supreme Power | Flask of the Magisters | Flask of the Magisters | Flask of the Titans",
    match_names(broadTokenResolution),
    "item catalog should return the full Flask of result set for broad token queries"
)

local pluralFriendlyResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = resolverSearchCatalog,
}, "flask magister")
assert.equal("multiple", pluralFriendlyResolution.status, "item catalog should keep singular-plural-friendly token matches grouped when more than one row matches")
assert.equal(2, #pluralFriendlyResolution.matches, "item catalog should return every Flask of the Magisters row for singularized token queries")
assert.equal("Flask of the Magisters | Flask of the Magisters", match_names(pluralFriendlyResolution), "item catalog should match singularized token queries against plural item names")

local bundledShatteredSunResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = bundledItems,
}, "flask of the shat")
assert.equal("multiple", bundledShatteredSunResolution.status, "item catalog should resolve bundled flask variants from partial token queries that narrow into the Shattered Sun family")
assert.truthy(#(bundledShatteredSunResolution.matches or {}) >= 2, "item catalog should surface both bundled Shattered Sun quality variants from the full bundled catalog")

local rankingSearchCatalog = {
    { itemID = 211001, name = "Savage Globe" },
    { itemID = 211002, name = "Savage Guard Globe" },
    { itemID = 211003, name = "Globe Savage Ward" },
}

local rankedMultiMatchResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = rankingSearchCatalog,
}, "savage glo")
assert.equal("multiple", rankedMultiMatchResolution.status, "item catalog should keep ranked token searches as multi-match results when more than one item matches")
assert.equal(3, #rankedMultiMatchResolution.matches, "item catalog should keep every ranked token match in the result set")
assert.equal(
    "Savage Globe | Savage Guard Globe | Globe Savage Ward",
    ordered_match_names(rankedMultiMatchResolution),
    "item catalog should rank exact-prefix token matches ahead of in-order token matches and unordered token matches"
)

local craftedVariantSearchCatalog = {
    { itemID = 311001, name = "Flask of the Test Magisters", craftedQuality = 2, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2" },
    { itemID = 311002, name = "Flask of the Test Magisters", craftedQuality = 5, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5" },
    { itemID = 311003, name = "Flask of the Test Magisters", craftedQuality = 3, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3" },
}

local craftedVariantResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = craftedVariantSearchCatalog,
}, "flask test magister")
assert.equal("multiple", craftedVariantResolution.status, "item catalog should keep duplicate-name crafted variants grouped as multiple matches")
assert.equal(3, #craftedVariantResolution.matches, "item catalog should keep every crafted-quality variant for the same item name")
assert.equal(
    "311002 | 311003 | 311001",
    table.concat({
        tostring((craftedVariantResolution.matches[1] or {}).itemID or ""),
        tostring((craftedVariantResolution.matches[2] or {}).itemID or ""),
        tostring((craftedVariantResolution.matches[3] or {}).itemID or ""),
    }, " | "),
    "item catalog should order identical-name crafted variants by higher crafted tier before lower crafted tiers"
)

local indexedSessionPayload = {
    metadata = {
        itemCount = 4,
        tokenCount = 4,
        ready = true,
    },
    itemsByID = {
        [241323] = { itemID = 241323, name = "Flask of the Magisters" },
        [241324] = { itemID = 241324, name = "Flask of the Blood Knights" },
        [241326] = { itemID = 241326, name = "Flask of the Shattered Sun", craftedQuality = 5, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5" },
        [241327] = { itemID = 241327, name = "Flask of the Shattered Sun", craftedQuality = 3, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3" },
    },
    tokenToItemIDs = {
        flask = { 241323, 241324, 241326, 241327 },
        of = { 241323, 241324, 241326, 241327 },
        magister = { 241323 },
        blood = { 241324 },
        knight = { 241324 },
        shattered = { 241326, 241327 },
        sun = { 241326, 241327 },
    },
}

local session = itemCatalog.CreateSearchSession({
    items = snapshot.items,
    searchCatalog = supplementalCatalog,
})
assert.truthy(itemCatalog.IsSearchSessionIndexedReady(session) == true, "search session should stay indexed-ready when bundled item data is available")
assert.truthy(#(session.fallbackItems or {}) < #(bundledItems or {}), "search session fallback items should stay much smaller than the bundled catalog")
assert.truthy((session.fallbackItems or {})[1] == nil or tonumber((session.fallbackItems or {})[1].itemID or 0) ~= 7007, "search session fallback items should not preload bundled rows")

local indexedPrefixFallbackPayload = {
    metadata = {
        itemCount = 5,
        tokenCount = 5,
        ready = true,
    },
    itemsByID = {
        [241323] = { itemID = 241323, name = "Flask of the Magisters" },
        [241324] = { itemID = 241324, name = "Flask of the Blood Knights" },
        [241326] = { itemID = 241326, name = "Flask of the Shattered Sun" },
        [241327] = { itemID = 241327, name = "Flask of the Shattered Sun" },
        [555555] = { itemID = 555555, name = "Sha-Touched Test Relic" },
    },
    tokenToItemIDs = {
        flask = { 241323, 241324, 241326, 241327 },
        of = { 241323, 241324, 241326, 241327 },
        magister = { 241323 },
        blood = { 241324 },
        knight = { 241324 },
        shattered = { 241326, 241327 },
        sun = { 241326, 241327 },
        sha = { 555555 },
    },
}

local exactAndPrefixResolution = itemCatalog.ResolveIndexedQuery(indexedPrefixFallbackPayload, "flask of the sha")
assert.equal("multiple", exactAndPrefixResolution.status, "indexed search should keep exact token hits and matching prefix-token hits in the same candidate set")
assert.equal(2, #(exactAndPrefixResolution.matches or {}), "indexed search should still surface the Shattered Sun family when a shorter query token also exists as an exact token")
assert.equal(
    "241326 | 241327",
    table.concat({
        tostring((exactAndPrefixResolution.matches[1] or {}).itemID or ""),
        tostring((exactAndPrefixResolution.matches[2] or {}).itemID or ""),
    }, " | "),
    "indexed search should keep the intended prefix-token family instead of collapsing to unrelated exact-token rows"
)

local bundledFlaskSunResolution = itemCatalog.ResolveIndexedQuery(itemCatalog.GetBundledSearchPayload(), "flask sun")
assert.equal("multiple", bundledFlaskSunResolution.status, "bundled indexed search should resolve flask sun against the shipped token index")
local bundledFlaskSunIds = {}
for _, item in ipairs(bundledFlaskSunResolution.matches or {}) do
    bundledFlaskSunIds[tonumber(item.itemID)] = true
end
assert.truthy(bundledFlaskSunIds[241326] == true and bundledFlaskSunIds[241327] == true, "bundled indexed search should include both Flask of the Shattered Sun item ids")
assert.equal(2, tonumber((itemCatalog.GetBundledItemByID(241326) or {}).craftedQuality or 0), "bundled item lookup should preserve the higher two-rank Shattered Sun tier")
assert.equal(2, tonumber((itemCatalog.GetBundledItemByID(241326) or {}).craftedQualityMax or 0), "bundled item lookup should expose the two-rank family size for Shattered Sun")
assert.equal("Interface-Crafting-ReagentQuality-2-Med", tostring((itemCatalog.GetBundledItemByID(241326) or {}).craftedQualityDisplayAtlas or ""), "bundled item lookup should expose the canonical gold display atlas for the higher two-rank Shattered Sun variant")
assert.equal(1, tonumber((itemCatalog.GetBundledItemByID(241327) or {}).craftedQuality or 0), "bundled item lookup should preserve the lower two-rank Shattered Sun tier")
assert.equal("Professions-ChatIcon-Quality-Tier1", tostring((itemCatalog.GetBundledItemByID(241327) or {}).craftedQualityDisplayAtlas or ""), "bundled item lookup should expose the canonical silver display atlas for the lower two-rank Shattered Sun variant")
assert.equal(2, tonumber((itemCatalog.GetBundledItemByID(243734) or {}).craftedQualityMax or 0), "bundled item lookup should expose the two-rank family size for Phoenix Oil")

local originalResolveIndexedQuery = itemCatalog.ResolveIndexedQuery
local indexedSessionQueryCalls = 0
itemCatalog.ResolveIndexedQuery = function(payload, query)
    indexedSessionQueryCalls = indexedSessionQueryCalls + 1
    return originalResolveIndexedQuery(payload, query)
end

local indexedSession = {
    payload = indexedSessionPayload,
    recentQueries = {},
    fallbackItems = {
        { itemID = 241328, name = "Flask of the Local Sun" },
    },
}

local firstSessionResolution = itemCatalog.ResolveSearchSessionQuery(indexedSession, "flask of the sha")
local secondSessionResolution = itemCatalog.ResolveSearchSessionQuery(indexedSession, "flask of the sha")
itemCatalog.ResolveIndexedQuery = originalResolveIndexedQuery

assert.equal("multiple", firstSessionResolution.status, "item catalog search sessions should keep broad indexed token queries grouped")
assert.equal(2, #(firstSessionResolution.matches or {}), "item catalog search sessions should return both indexed Shattered Sun variants")
assert.equal(1, indexedSessionQueryCalls, "item catalog search sessions should cache repeated query results inside the session")
assert.same(firstSessionResolution, secondSessionResolution, "item catalog search sessions should reuse the cached resolution table for repeated queries")

local mergedSessionResolution = itemCatalog.ResolveSearchSessionQuery({
    payload = indexedSessionPayload,
    recentQueries = {},
    fallbackItems = {
        { itemID = 241329, name = "Flask of the Local Test" },
    },
}, "flask of")
assert.truthy(#(mergedSessionResolution.matches or {}) >= 5, "item catalog search sessions should merge bundled indexed matches with fallback session items")

local unavailableSessionResolution = itemCatalog.ResolveSearchSessionQuery({
    payload = nil,
    recentQueries = {},
    fallbackItems = {
        { itemID = 241323, name = "Flask of the Magisters" },
        { itemID = 241324, name = "Flask of the Blood Knights" },
    },
}, "flask of")
assert.equal("unavailable", unavailableSessionResolution.status, "item catalog search sessions should report bundled name search as unavailable when the indexed payload is missing")
assert.equal(0, #(unavailableSessionResolution.matches or {}), "item catalog search sessions should not fall back to a misleading sparse local name result set when the indexed payload is unavailable")

local numericResolverResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = resolverSearchCatalog,
}, "111004")
assert.equal("resolved", numericResolverResolution.status, "item catalog should continue resolving exact numeric item IDs")
assert.equal("Flask of the Magisters", numericResolverResolution.item.name, "item catalog should keep exact numeric item ID resolution unchanged")

local originalGetItemInfo = _G.GetItemInfo
local originalRequestLoadItemDataByID = _G.C_Item and _G.C_Item.RequestLoadItemDataByID or nil
local requestedItemID = nil

_G.C_Item = _G.C_Item or {}
_G.C_Item.RequestLoadItemDataByID = function(itemID)
    requestedItemID = itemID
end

_G.GetItemInfo = function(query)
    if tonumber(query) == 424242 then
        return "Client Cache Idol", "item:424242::::::::::::", 4
    end
    return nil
end

local numericFallbackResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = {},
}, "424242")

_G.GetItemInfo = originalGetItemInfo
_G.C_Item.RequestLoadItemDataByID = originalRequestLoadItemDataByID

assert.equal("resolved", numericFallbackResolution.status, "item catalog should resolve exact numeric item IDs from the client cache when they are missing from the search catalog")
assert.equal(424242, numericFallbackResolution.item.itemID, "item catalog should preserve exact numeric fallback item IDs")
assert.equal("Client Cache Idol", numericFallbackResolution.item.name, "item catalog should return client cache item data for exact numeric fallback resolution")
assert.equal(4, numericFallbackResolution.item.quality, "item catalog should carry quality through exact numeric fallback resolution")
assert.equal(nil, requestedItemID, "item catalog should not request item data again when exact numeric fallback already succeeds through GetItemInfo")

_G.GBankManagerNamespace = nil
