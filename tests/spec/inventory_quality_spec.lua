local assert = require("tests.helpers.assert")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")

assert.truthy(type(addonName) == "string", "addon should load for inventory quality spec")

local inventory = ns.modules.inventoryView

local multiTabRows = inventory.BuildTableRows({
    items = {
        [9001] = {
            itemID = 9001,
            name = "Shared Flask",
            totalCount = 15,
            tabs = {
                Alchemy = 10,
                Raid = 5,
            },
        },
    },
    itemRows = {
        {
            itemID = 9001,
            name = "Shared Flask",
            quantity = 10,
            tabName = "Alchemy",
            rowKey = "9001|TAB|Alchemy",
        },
        {
            itemID = 9001,
            name = "Shared Flask",
            quantity = 5,
            tabName = "Raid",
            rowKey = "9001|TAB|Raid",
        },
    },
}, {}, "")

assert.equal(2, #multiTabRows, "inventory should render one row per bank tab for shared items")
assert.equal("Alchemy", multiTabRows[1].bankTab, "inventory should keep the first shared item row tab-scoped")
assert.equal("10", multiTabRows[1].current, "inventory should show the first tab quantity instead of the item total")
assert.equal("Raid", multiTabRows[2].bankTab, "inventory should keep the second shared item row tab-scoped")
assert.equal("5", multiTabRows[2].current, "inventory should show the second tab quantity instead of the item total")

local itemIDFilteredRows = inventory.BuildTableRows({
    items = {
        [9015] = {
            itemID = 9015,
            name = "Filtered Flask",
            totalCount = 2,
            tabs = { Alchemy = 2 },
        },
        [9020] = {
            itemID = 9020,
            name = "Other Flask",
            totalCount = 3,
            tabs = { Raid = 3 },
        },
    },
}, {}, {
    itemID = "9015",
})

assert.equal(1, #itemIDFilteredRows, "inventory view model should filter rows by Item ID")
assert.equal("9015", itemIDFilteredRows[1].itemID, "inventory Item ID filtering should preserve the matching item row")

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
    rowsByName[row.itemName] = row
end

assert.equal(
    "|A:Interface-Crafting-ReagentQuality-1-Med:16:16|a",
    rowsByName["Potion Bomb of Speed"].tier,
    "inventory should preserve crafted-quality atlas markup that is already formatted"
)
assert.equal(
    1,
    rowsByName["Potion Bomb of Speed"].tierValue,
    "inventory should derive tier 1 from live-client reagent-quality icon markup variants"
)
assert.equal(
    "|A:Professions-ChatIcon-Quality-Tier2:22:22|a",
    rowsByName["Algari Mana Oil"].tier,
    "inventory should normalize plain quality atlas variants into the shared visible crafted-quality icon family"
)
assert.equal(
    2,
    rowsByName["Algari Mana Oil"].tierValue,
    "inventory should derive tier 2 from quality atlas variants that omit the Tier token"
)

local sorted = inventory.SortRows(rows, {
    key = "tier",
    direction = "asc",
})

assert.equal(
    "Potion Bomb of Speed",
    sorted[1].itemName,
    "inventory tier sorting should keep Potion Bomb of Speed with other tier 1 entries"
)
assert.equal(
    "Algari Mana Oil",
    sorted[2].itemName,
    "inventory tier sorting should place Algari Mana Oil in the tier 2 group"
)
assert.equal(
    "Flask Alpha",
    sorted[3].itemName,
    "inventory tier sorting should keep tier 3 items after lower tiers"
)
assert.equal(
    "Basic Thread",
    sorted[4].itemName,
    "inventory tier sorting should still push unranked rows after ranked tiers"
)

local rankRows = inventory.BuildTableRows({
    items = {
        [2001] = {
            itemID = 2001,
            name = "Potion Bomb of Speed Rank Markup",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "|A:Interface-Crafting-ReagentRank1-Med:16:16|a",
            tabs = { Potions = 5 },
        },
        [2002] = {
            itemID = 2002,
            name = "Algari Mana Oil Rank Atlas",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "Professions-Icon-Rank2-Inv",
            tabs = { Potions = 5 },
        },
        [2003] = {
            itemID = 2003,
            name = "Basic Cloth",
            totalCount = 5,
            craftedQuality = 0,
            craftedQualityIcon = "",
            tabs = { Cloth = 5 },
        },
    },
}, {}, "")

local rankRowsByName = {}
for _, row in ipairs(rankRows) do
    rankRowsByName[row.itemName] = row
end

assert.equal(
    1,
    rankRowsByName["Potion Bomb of Speed Rank Markup"].tierValue,
    "inventory should derive tier 1 from live-client reagent-quality rank markup variants"
)
assert.equal(
    2,
    rankRowsByName["Algari Mana Oil Rank Atlas"].tierValue,
    "inventory should derive tier 2 from live-client crafted-quality rank atlas variants"
)

local rankSorted = inventory.SortRows(rankRows, {
    key = "tier",
    direction = "asc",
})

assert.equal(
    "Potion Bomb of Speed Rank Markup",
    rankSorted[1].itemName,
    "inventory tier sorting should treat rank atlas variants as tier 1 entries"
)
assert.equal(
    "Algari Mana Oil Rank Atlas",
    rankSorted[2].itemName,
    "inventory tier sorting should place rank atlas variants into the derived tier 2 group"
)
assert.equal(
    "Basic Cloth",
    rankSorted[3].itemName,
    "inventory tier sorting should still push unranked items after parsed rank atlas variants"
)
