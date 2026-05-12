local assert = require("tests.helpers.assert")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")

assert.truthy(type(addonName) == "string", "addon should load for inventory quality spec")

local inventory = ns.modules.inventoryView

local rows = inventory.BuildTableRows({
    items = {
        [1001] = {
            itemID = 1001,
            name = "Flask Alpha",
            totalCount = 5,
            craftedQuality = 3,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3",
            tabs = { Flasks = 5 },
        },
        [1002] = {
            itemID = 1002,
            name = "Potion Bomb of Speed",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a",
            tabs = { Potions = 5 },
        },
        [1003] = {
            itemID = 1003,
            name = "Algari Mana Oil",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "Professions-Icon-Quality-2-Inv",
            tabs = { Potions = 5 },
        },
        [1004] = {
            itemID = 1004,
            name = "Basic Thread",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "",
            tabs = { Cloth = 5 },
        },
    },
}, {}, "")

local rowsByName = {}
for _, row in ipairs(rows) do
    rowsByName[row.name] = row
end

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a",
    rowsByName["Potion Bomb of Speed"].quality,
    "inventory should preserve crafted-quality atlas markup that is already formatted"
)
assert.equal(
    1,
    rowsByName["Potion Bomb of Speed"].qualityValue,
    "inventory should derive tier 1 from live-client reagent-quality icon markup variants"
)
assert.equal(
    "|A:Professions-Icon-Quality-2-Inv:22:22|a",
    rowsByName["Algari Mana Oil"].quality,
    "inventory should wrap plain quality atlas variants for display"
)
assert.equal(
    2,
    rowsByName["Algari Mana Oil"].qualityValue,
    "inventory should derive tier 2 from quality atlas variants that omit the Tier token"
)

local sorted = inventory.SortRows(rows, {
    key = "quality",
    direction = "asc",
})

assert.equal(
    "Potion Bomb of Speed",
    sorted[1].name,
    "inventory tier sorting should keep Potion Bomb of Speed with other tier 1 entries"
)
assert.equal(
    "Algari Mana Oil",
    sorted[2].name,
    "inventory tier sorting should place Algari Mana Oil in the tier 2 group"
)
assert.equal(
    "Flask Alpha",
    sorted[3].name,
    "inventory tier sorting should keep tier 3 items after lower tiers"
)
assert.equal(
    "Basic Thread",
    sorted[4].name,
    "inventory tier sorting should still push unranked rows after ranked tiers"
)
