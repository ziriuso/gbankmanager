local assert = require("tests.helpers.assert")

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local craftedQuality = ns.modules.craftedQuality
local LOW_TWO_RANK_ATLAS = "Professions-Icon-Quality-12-Tier1-Inv"
local HIGH_TWO_RANK_ATLAS = "Professions-Icon-Quality-12-Tier2-Inv"
local LOW_TWO_RANK_MARKUP = "|A:Professions-Icon-Quality-12-Tier1-Inv:22:22|a"
local HIGH_TWO_RANK_MARKUP = "|A:Professions-Icon-Quality-12-Tier2-Inv:22:22|a"

assert.equal(
    LOW_TWO_RANK_ATLAS,
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier1", 1, nil, 2),
    "true two-rank family tier-one display should resolve to the single silver diamond atlas"
)

assert.equal(
    HIGH_TWO_RANK_ATLAS,
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, nil, 2),
    "true two-rank family tier-two display should resolve to the gold pentagram atlas"
)

assert.equal(
    HIGH_TWO_RANK_ATLAS,
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, "reagent", 2),
    "true two-rank reagent display should resolve to the gold pentagram atlas even before item-aware overrides are applied"
)

assert.equal(
    HIGH_TWO_RANK_ATLAS,
    craftedQuality.GetDisplayAtlas("|A:Professions-ChatIcon-Quality-Tier2:22:22|a", 2, nil, 2),
    "true two-rank display should unwrap existing chat-atlas markup and still resolve to the gold pentagram atlas"
)

assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, nil, 5),
    "five-tier items should keep the standard quality atlas family"
)

assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, "reagent", 5),
    "five-tier items should keep the standard quality atlas family even in reagent-style surfaces"
)

assert.equal(
    LOW_TWO_RANK_ATLAS,
    craftedQuality.GetDisplayAtlasForItem(1002, "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a", 0, "reagent", 2),
    "item-aware display resolution should normalize true two-rank tier-one items into the visible inventory-style silver-diamond atlas family even when bundled item data is unavailable"
)

assert.equal(
    LOW_TWO_RANK_MARKUP,
    craftedQuality.DisplayMarkupForItem(1002, "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a", 22, "reagent", 0, 2),
    "item-aware inline markup should match the inventory-style lower two-rank atlas family when callers only provide a live reagent icon variant"
)

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    craftedQuality.DisplayMarkupForItem(2001, "Professions-ChatIcon-Quality-Tier2", 22, "reagent", 2, 0),
    "generic tier-two inventory-style rows without bundled authoritative metadata should keep the older live reagent medal atlas instead of being promoted into the bundled shared two-rank family"
)

assert.equal(
    HIGH_TWO_RANK_MARKUP,
    craftedQuality.DisplayMarkupForItem(241326, "", 22, "reagent", 0, 0),
    "item-aware inline markup should recover the bundled higher-rank gold-pentagram atlas when callers only know the item id"
)

assert.equal(
    HIGH_TWO_RANK_MARKUP,
    craftedQuality.DisplayMarkupForItem(241320, "Professions-ChatIcon-Quality-Tier1", 22, "reagent", 1, 0),
    "item-aware inline markup should prefer the bundled higher-rank gold-pentagram atlas over a stale lower-rank row icon"
)

assert.equal(
    HIGH_TWO_RANK_ATLAS,
    craftedQuality.GetMarkupAtlasForItem(241320, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0),
    "item-aware markup atlas resolution should return the bundled higher-rank gold-pentagram atlas for two-rank items"
)

local nonInventoryPresentation = craftedQuality.GetNonInventoryPresentationForItem(241320, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0)
assert.equal(
    HIGH_TWO_RANK_ATLAS,
    tostring((nonInventoryPresentation or {}).atlas or ""),
    "non-inventory crafted-quality presentation should render true two-rank crafted consumables through the canonical gold-pentagram atlas family"
)
assert.equal(
    HIGH_TWO_RANK_MARKUP,
    tostring((nonInventoryPresentation or {}).markup or ""),
    "non-inventory crafted-quality presentation should expose the canonical gold-pentagram atlas through inline fallback markup"
)
assert.equal(
    2,
    tonumber((nonInventoryPresentation or {}).quality or 0),
    "non-inventory crafted-quality presentation should expose the bundled crafted quality rank"
)
assert.equal(
    2,
    tonumber((nonInventoryPresentation or {}).maxQuality or 0),
    "non-inventory crafted-quality presentation should expose the bundled family size"
)

local phoenixPresentation = craftedQuality.GetNonInventoryPresentationForItem(243734, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0)
assert.equal(
    HIGH_TWO_RANK_ATLAS,
    tostring((phoenixPresentation or {}).atlas or ""),
    "non-inventory crafted-quality presentation should render Phoenix Oil through the canonical gold-pentagram atlas when stale saved row data only knows the chat icon"
)

local debugInfo = craftedQuality.DebugItemResolution(241320, "Professions-ChatIcon-Quality-Tier1", 1, 0, "reagent")
assert.equal(2, debugInfo.bundledCraftedQuality, "crafted-quality diagnostics should expose bundled quality rank")
assert.equal(2, debugInfo.bundledCraftedQualityMax, "crafted-quality diagnostics should expose bundled family size")
assert.equal(HIGH_TWO_RANK_ATLAS, debugInfo.finalAtlas, "crafted-quality diagnostics should expose the final atlas chosen by the shared item-aware inline resolver")
assert.equal(HIGH_TWO_RANK_ATLAS, debugInfo.finalMarkupAtlas, "crafted-quality diagnostics should expose the final inline atlas chosen for text-based consumers")
assert.equal(HIGH_TWO_RANK_ATLAS, debugInfo.finalDisplayAtlas, "crafted-quality diagnostics should still expose the separate texture-display atlas")
assert.equal(HIGH_TWO_RANK_ATLAS, debugInfo.finalNonInventoryAtlas, "crafted-quality diagnostics should expose the canonical non-inventory gold-pentagram atlas directly")
assert.equal(HIGH_TWO_RANK_ATLAS, debugInfo.finalNonInventoryMarkupAtlas, "crafted-quality diagnostics should expose the canonical non-inventory markup atlas directly")
assert.truthy(type(craftedQuality.DescribeItemResolution(241320, "Professions-ChatIcon-Quality-Tier1", 1, 0, "reagent")) == "table", "crafted-quality diagnostics should format a chat-friendly summary")

local originalItemCatalog = ns.modules.itemCatalog
ns.modules.itemCatalog = {
    GetBundledItemByID = function(itemID)
        if itemID == 999999 then
            return {
                itemID = 999999,
                craftedQuality = 2,
                craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
                craftedQualityMax = 2,
                craftedQualityDisplayAtlas = HIGH_TWO_RANK_ATLAS,
            }
        end

        return nil
    end,
}

assert.equal(
    HIGH_TWO_RANK_MARKUP,
    craftedQuality.DisplayMarkupForItem(999999, "", 22, "reagent", 0, 0),
    "item-aware inline markup should consult the current item catalog module even when that module is assigned after crafted quality is initialized"
)

ns.modules.itemCatalog = originalItemCatalog

local originalQualityMap = _G.GBankManagerItemQualityByID
_G.GBankManagerItemQualityByID = {
    [888888] = {
        itemID = 888888,
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityMax = 2,
        craftedQualityDisplayAtlas = HIGH_TWO_RANK_ATLAS,
        craftedQualityPreferredAtlas = HIGH_TWO_RANK_ATLAS,
        craftedQualityFamilySize = 2,
    },
}

ns.modules.itemCatalog = {
    EnsureBundledDataLoaded = function()
        return true
    end,
    GetBundledItemByID = function()
        return nil
    end,
}

assert.equal(
    HIGH_TWO_RANK_MARKUP,
    craftedQuality.DisplayMarkupForItem(888888, "Professions-ChatIcon-Quality-Tier1", 22, "reagent", 1, 0),
    "item-aware inline markup should prefer the canonical quality map from the data addon even when the full bundled catalog path is unavailable"
)

ns.modules.itemCatalog = originalItemCatalog
_G.GBankManagerItemQualityByID = originalQualityMap

local originalTradeSkillUI = _G.C_TradeSkillUI
_G.C_TradeSkillUI = {
    GetItemReagentQualityInfo = function(itemInfo)
        if tonumber(itemInfo) == 241320 then
            return {
                quality = 2,
                iconChat = "Live-Chat-TwoTier-Gold",
                iconSmall = "Live-Small-TwoTier-Gold",
                iconInventory = "Live-Inventory-TwoTier-Gold",
            }
        end

        return nil
    end,
}

assert.equal(
    HIGH_TWO_RANK_MARKUP,
    craftedQuality.DisplayNonInventoryMarkupForItem(241320, "Professions-ChatIcon-Quality-Tier1", 22, "reagent", 1, 0),
    "non-inventory inline markup should prefer the canonical bundled gold-pentagram atlas even when the live reagent-quality payload exposes a different family"
)

local liveNonInventoryPresentation = craftedQuality.GetNonInventoryPresentationForItem(241320, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0)
assert.equal(
    HIGH_TWO_RANK_ATLAS,
    tostring((liveNonInventoryPresentation or {}).atlas or ""),
    "non-inventory presentation should prefer the canonical bundled gold-pentagram atlas even when the live reagent-quality payload exposes a different family"
)

_G.C_TradeSkillUI = originalTradeSkillUI
