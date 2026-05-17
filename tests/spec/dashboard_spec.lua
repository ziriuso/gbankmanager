local assert = require("tests.helpers.assert")
local dashboard = dofile("GBankManager/UI/DashboardView.lua")

local summary = dashboard.BuildSummary({
    meta = {
        updatedAt = 1715523300,
    },
    minimums = {
        {
            itemID = 240154,
            itemName = "Arcanoweave Spellthread",
            quantity = 100,
            scope = "GLOBAL",
            enabled = true,
        },
        {
            itemID = 241304,
            itemName = "Silvermoon Health Potion",
            quantity = 250,
            scope = "GLOBAL",
            enabled = true,
        },
    },
    currentSnapshotId = "scan-now",
    snapshots = {
        ["scan-now"] = {
            scanId = "scan-now",
            scannedAt = 1715523300,
            items = {
                [240154] = { itemID = 240154, name = "Arcanoweave Spellthread", totalCount = 120, tabs = { Tailoring = 120 } },
                [241304] = { itemID = 241304, name = "Silvermoon Health Potion", totalCount = 30, tabs = { Potions = 30 } },
            },
        },
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
assert.equal(1, summary.criticalShortageCount, "dashboard summary should count enabled minimums that remain below their configured threshold")

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

assert.equal("Critical Shortages", cards[4].title, "dashboard should expose a dedicated critical-shortage metric card")
assert.truthy(tonumber(cards[4].value or "0") >= 0, "dashboard critical-shortage metric should expose a numeric value")

local topUsedLines = dashboard.BuildTopItemsLines({
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

assert.truthy(string.find(topUsedLines[1], "Flask Alpha", 1, true) ~= nil, "dashboard top-five panel should rank repeated restock items first")
assert.truthy(string.find(topUsedLines[1], "2 restocks", 1, true) ~= nil, "dashboard top-five panel should show repeated shortage cycles")
assert.truthy(string.find(topUsedLines[2], "Potion Beta", 1, true) ~= nil, "dashboard top-five panel should include other minimum-tracked shortage history")
assert.truthy(string.find(topUsedLines[1], "Mega Feast", 1, true) == nil, "dashboard top-five panel should prefer stocking history over raw withdrawal totals when minimum history exists")

local recentActivity = dashboard.BuildRecentActivityLines({
    auditLog = {
        {
            category = "REQUEST",
            type = "REQUEST_APPROVED",
            itemName = "Flask Alpha",
            actor = "OfficerOne",
            timestamp = 100,
        },
        {
            category = "MINIMUM",
            type = "MINIMUM_UPDATED",
            itemName = "Potion Beta",
            actor = "GuildLead",
            timestamp = 90,
        },
    },
}, 2)

assert.equal(2, #recentActivity, "dashboard recent-activity panel should limit itself to the requested number of rows")
assert.truthy(string.find(recentActivity[1], "Flask Alpha", 1, true) ~= nil, "dashboard recent activity should include the newest item name")
