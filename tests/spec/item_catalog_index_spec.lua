package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")

_G.GBankManagerNamespace = nil

assert.load_addon_from_toc("GBankManager_ItemData/GBankManager_ItemData.toc")
local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local itemCatalog = ns.modules.itemCatalog

assert.truthy(type(itemCatalog) == "table", "item catalog module should load for indexed search contract coverage")
assert.truthy(type(itemCatalog.IsBundledSearchReady) == "function", "item catalog should expose readiness validation for bundled indexed search payloads")
assert.truthy(type(itemCatalog.ResolveIndexedQuery) == "function", "item catalog should expose indexed bundled query resolution")

local indexedPayload = {
    metadata = {
        itemCount = 4,
        tokenCount = 5,
        ready = true,
    },
    itemsByID = {
        [241323] = { itemID = 241323, name = "Flask of the Magisters" },
        [241324] = { itemID = 241324, name = "Flask of the Blood Knights" },
        [241326] = { itemID = 241326, name = "Flask of the Shattered Sun" },
        [241327] = { itemID = 241327, name = "Flask of the Shattered Sun" },
    },
    tokenToItemIDs = {
        flask = { 241323, 241324, 241326, 241327 },
        of = { 241323, 241324, 241326, 241327 },
        shattered = { 241326, 241327 },
        sun = { 241326, 241327 },
        magisters = { 241323 },
    },
}

assert.truthy(itemCatalog.IsBundledSearchReady(indexedPayload), "bundled indexed payload should require a ready metadata marker")

local flaskResolution = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask")
assert.equal("multiple", flaskResolution.status, "indexed search should keep broad single-token family queries grouped")
assert.truthy(#(flaskResolution.matches or {}) >= 4, "indexed search should return the full flask family, not a tiny subset")

local flaskOfResolution = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask of")
assert.equal("multiple", flaskOfResolution.status, "indexed search should keep broad token combinations grouped")
assert.truthy(#(flaskOfResolution.matches or {}) >= 4, "indexed search should support broad multi-token family queries")

local shatteredSunResolution = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask of the sha")
assert.equal("multiple", shatteredSunResolution.status, "indexed search should keep broad token matches grouped")
assert.equal(2, #(shatteredSunResolution.matches or {}), "shattered-sun query should return both quality variants")

_G.GBankManagerNamespace = nil

local _, bundledDataNamespace = assert.load_addon_from_toc("GBankManager_ItemData/GBankManager_ItemData.toc")
local bundledPayload = ((bundledDataNamespace or {}).data or {}).staticItemSearch

assert.truthy(type(bundledPayload) == "table", "indexed search bootstrap should be loadable")
assert.truthy(type((bundledPayload or {}).itemsByID) == "table", "indexed bootstrap should attach compact item records")
assert.truthy(type((bundledPayload or {}).tokenToItemIDs) == "table", "indexed bootstrap should attach token index data")
assert.equal(true, (((bundledPayload or {}).metadata or {}).ready), "indexed bootstrap should mark readiness only after all chunks attach")

_G.GBankManagerNamespace = nil
