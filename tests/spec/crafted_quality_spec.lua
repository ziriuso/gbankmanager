local assert = require("tests.helpers.assert")

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local craftedQuality = ns.modules.craftedQuality

assert.equal(
    "Professions-ChatIcon-Quality-Tier1",
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier1", 1, nil, 2),
    "generic two-tier display resolution should keep the standard chat-atlas family when no item-aware bundled display atlas is involved"
)

assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, nil, 2),
    "generic two-tier display resolution should keep the standard chat-atlas family when no item-aware bundled display atlas is involved"
)

assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    craftedQuality.GetDisplayAtlas("Professions-ChatIcon-Quality-Tier2", 2, "reagent", 2),
    "generic non-item-aware two-rank reagent display should stay on the standard chat-atlas family when no bundled item-aware display atlas is involved"
)

assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    craftedQuality.GetDisplayAtlas("|A:Professions-ChatIcon-Quality-Tier2:22:22|a", 2, nil, 2),
    "generic two-tier display resolution should unwrap existing atlas markup without switching to a special two-rank family"
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
    "Professions-ChatIcon-Quality-12-Tier1",
    craftedQuality.GetDisplayAtlasForItem(1002, "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a", 0, "reagent", 2),
    "item-aware display resolution should normalize true two-rank tier-one items into the shared silver-diamond atlas family even when bundled item data is unavailable"
)

assert.equal(
    "|A:Professions-ChatIcon-Quality-12-Tier1:22:22|a",
    craftedQuality.DisplayMarkupForItem(1002, "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a", 22, "reagent", 0, 2),
    "item-aware inline markup should match the inventory-style lower two-rank atlas family when callers only provide a live reagent icon variant"
)

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    craftedQuality.DisplayMarkupForItem(2001, "Professions-ChatIcon-Quality-Tier2", 22, "reagent", 2, 0),
    "generic tier-two inventory-style rows without bundled authoritative metadata should keep the older live reagent medal atlas instead of being promoted into the bundled shared two-rank family"
)

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    craftedQuality.DisplayMarkupForItem(241326, "", 22, "reagent", 0, 0),
    "item-aware inline markup should recover the bundled higher-rank two-rank atlas when callers only know the item id"
)

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    craftedQuality.DisplayMarkupForItem(241320, "Professions-ChatIcon-Quality-Tier1", 22, "reagent", 1, 0),
    "item-aware inline markup should prefer the bundled higher-rank two-rank atlas over a stale lower-rank row icon"
)

assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    craftedQuality.GetMarkupAtlasForItem(241320, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0),
    "item-aware markup atlas resolution should return the bundled inventory-style higher-rank atlas for two-rank items"
)

local debugInfo = craftedQuality.DebugItemResolution(241320, "Professions-ChatIcon-Quality-Tier1", 1, 0, "reagent")
assert.equal(2, debugInfo.bundledCraftedQuality, "crafted-quality diagnostics should expose bundled quality rank")
assert.equal(2, debugInfo.bundledCraftedQualityMax, "crafted-quality diagnostics should expose bundled family size")
assert.equal("Interface-Crafting-ReagentQuality-2-Med", debugInfo.finalAtlas, "crafted-quality diagnostics should expose the final atlas chosen by the shared item-aware inline resolver")
assert.equal("Interface-Crafting-ReagentQuality-2-Med", debugInfo.finalMarkupAtlas, "crafted-quality diagnostics should expose the final inline atlas chosen for text-based consumers")
assert.equal("Interface-Crafting-ReagentQuality-2-Med", debugInfo.finalDisplayAtlas, "crafted-quality diagnostics should still expose the separate texture-display atlas")
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
                craftedQualityDisplayAtlas = "Interface-Crafting-ReagentQuality-2-Med",
            }
        end

        return nil
    end,
}

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
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
        craftedQualityDisplayAtlas = "Interface-Crafting-ReagentQuality-2-Med",
        craftedQualityPreferredAtlas = "Interface-Crafting-ReagentQuality-2-Med",
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
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
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
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    craftedQuality.DisplayMarkupForItem(241320, "Professions-ChatIcon-Quality-Tier1", 22, "reagent", 1, 0),
    "item-aware inline markup should keep bundled addon metadata authoritative even when the live client reports a different atlas family"
)

_G.C_TradeSkillUI = originalTradeSkillUI
