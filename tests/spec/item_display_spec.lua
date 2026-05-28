package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")

_G.GBankManagerNamespace = nil

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local itemDisplay = ns.modules.itemDisplay

assert.equal("GBankManager", addonName, "item display spec should load the addon toc")
assert.truthy(type(itemDisplay) == "table", "item display module should load from toc")
assert.truthy(type(itemDisplay.BuildDisplayPayload) == "function", "item display module should expose a shared display payload builder")

local hyperlinkItem = {
    itemID = 241322,
    name = "Flask of the Magisters",
    itemLink = "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    craftedQuality = 2,
    craftedQualityMax = 2,
}

local hyperlinkDisplay = itemDisplay.BuildDisplayPayload(hyperlinkItem)
assert.equal(hyperlinkItem.itemLink, hyperlinkDisplay.visibleText, "display payload should prefer a trusted stored hyperlink when present")
assert.equal("Flask of the Magisters", hyperlinkDisplay.plainTextName, "display payload should preserve a plain-text export-safe item name")
assert.equal(2, hyperlinkDisplay.tierValue, "display payload should preserve numeric crafted quality for sorting and CSV")
assert.equal(241322, hyperlinkDisplay.itemID, "display payload should preserve numeric item ids")

local fallbackDisplay = itemDisplay.BuildDisplayPayload({
    itemID = 244559,
    name = "Thalassian Phoenix Oil",
    craftedQuality = 2,
    craftedQualityMax = 2,
})
assert.equal("Thalassian Phoenix Oil", fallbackDisplay.plainTextName, "fallback display should still expose a stable plain-text item name")
assert.equal("Thalassian Phoenix Oil", fallbackDisplay.visibleText, "fallback display should fall back to plain-text item names when no trusted link exists")
assert.equal(2, fallbackDisplay.tierValue, "fallback display should preserve numeric quality even without a link")

_G.GBankManagerNamespace = nil
