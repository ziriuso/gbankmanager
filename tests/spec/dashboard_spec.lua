local assert = require("tests.helpers.assert")
local dashboard = dofile("GBankManager/UI/DashboardView.lua")

local summary = dashboard.BuildSummary({
    meta = {
        updatedAt = 1715523300,
    },
    requests = {},
}, {
    [240154] = {
        itemID = 240154,
        itemName = "Arcanoweave Spellthread",
        totalToBuy = 0,
    },
    [241304] = {
        itemID = 241304,
        itemName = "Silvermoon Health Potion",
        totalToBuy = 250,
    },
})

assert.equal(1, summary.exportReadyCount, "dashboard summary should ignore zero-shortage demand rows when counting export-ready rows")
assert.equal(250, summary.totalPurchaseQuantity, "dashboard summary should keep the positive purchase total")

local cards = dashboard.BuildCards({
    minimums = {
        {
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 100,
            scope = "GLOBAL",
            enabled = true,
        },
        {
            itemID = 2002,
            itemName = "Potion Beta",
            quantity = 50,
            scope = "GLOBAL",
            enabled = true,
        },
    },
    snapshots = {
        scan1 = {
            scanId = "scan1",
            scannedAt = 10,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 120, tabs = { Alchemy = 120 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 55, tabs = { Potions = 55 } },
            },
        },
        scan2 = {
            scanId = "scan2",
            scannedAt = 20,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 35, tabs = { Alchemy = 35 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 45, tabs = { Potions = 45 } },
            },
        },
        scan3 = {
            scanId = "scan3",
            scannedAt = 30,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 140, tabs = { Alchemy = 140 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 40, tabs = { Potions = 40 } },
            },
        },
        scan4 = {
            scanId = "scan4",
            scannedAt = 40,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 30, tabs = { Alchemy = 30 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 70, tabs = { Potions = 70 } },
            },
        },
    },
    changeLog = {
        {
            type = "QUANTITY_DECREASED",
            itemID = 9009,
            name = "Mega Feast",
            delta = 800,
        },
    },
    requests = {},
}, {})

assert.equal("Top 5 Most Used", cards[4].title, "dashboard should keep the restock-frequency card title stable")
assert.truthy(string.find(cards[4].lines[1], "Flask Alpha", 1, true) ~= nil, "dashboard top-five card should rank repeated restock items first")
assert.truthy(string.find(cards[4].lines[1], "2 restocks", 1, true) ~= nil, "dashboard top-five card should show repeated shortage cycles")
assert.truthy(string.find(cards[4].lines[2], "Potion Beta", 1, true) ~= nil, "dashboard top-five card should include other minimum-tracked shortage history")
assert.truthy(string.find(cards[4].lines[1], "Mega Feast", 1, true) == nil, "dashboard top-five card should prefer stocking history over raw withdrawal totals when minimum history exists")
