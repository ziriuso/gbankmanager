local assert = require("tests.helpers.assert")
local exports = dofile("GBankManager/Domain/Exports.lua")

local text = exports.BuildDelimited({
    { itemID = 1001, itemName = "Flask Alpha", totalToBuy = 4, reason = "RESTOCK" },
}, {
    delimiter = ",",
    includeHeader = true,
    fields = { "itemName", "totalToBuy", "reason" },
})

assert.equal("itemName,totalToBuy,reason\nFlask Alpha,4,RESTOCK", text, "spreadsheet export should honor field order")

local custom = exports.BuildDelimited({
    { itemName = "Flask Alpha", totalToBuy = 4 },
}, {
    delimiter = "|",
    includeHeader = false,
    fields = { "totalToBuy", "itemName" },
})

assert.equal("4|Flask Alpha", custom, "custom delimited export should honor delimiter and suppress header")

local auctionator = exports.BuildAuctionator({
    { itemName = "Flask Alpha", totalToBuy = 4, quality = 3 },
    { itemName = "", totalToBuy = 7, quality = 5 },
    { itemName = "Potion Beta", totalToBuy = 2, quality = 0 },
    { itemName = "Feast Gamma", totalToBuy = 0, quality = 1 },
}, "Raid Prep")

assert.equal("Raid Prep^Flask Alpha^Potion Beta", auctionator, "auctionator export should use Auctionator's current caret-delimited import format")

local rows = exports.MaterializePlanRows({
    [2002] = {
        itemID = 2002,
        itemName = "Potion Beta",
        totalToBuy = 2,
        sources = { RESTOCK = 0, ONE_TIME_TARGET = 2, REQUEST = 0 },
    },
    [1001] = {
        itemID = 1001,
        itemName = "Flask Alpha",
        totalToBuy = 5,
        sources = { RESTOCK = 4, ONE_TIME_TARGET = 0, REQUEST = 1 },
    },
})

assert.equal("Flask Alpha", rows[1].itemName, "materialized rows should sort by item name")
assert.equal("REQUEST:1|RESTOCK:4", rows[1].reason, "materialized rows should include sorted reason tags")
assert.equal(1001, rows[1].itemID, "materialized rows should keep item ids for release exports")
assert.equal(5, rows[1].totalToBuy, "materialized rows should keep purchase totals")
assert.equal(5, rows[1].amountToStock, "materialized rows should expose Amount to Stock for the exports table")

local outOfStockQualityRows = exports.MaterializePlanRows({
    [4004] = {
        itemID = 4004,
        itemName = "Ranked Rune",
        totalToBuy = 6,
        craftedQuality = 2,
        sources = { RESTOCK = 6, ONE_TIME_TARGET = 0, REQUEST = 0 },
    },
}, {
    items = {},
})

assert.equal(2, outOfStockQualityRows[1].quality, "materialized rows should preserve row quality when an item is missing from the current snapshot")
assert.equal("|A:Professions-ChatIcon-Quality-Tier2:22:22|a", outOfStockQualityRows[1].itemTier, "materialized rows should normalize two-rank fallback icons to the shared visible crafted-quality icon family")

local enrichedRows = exports.MaterializePlanRows({
    [3003] = {
        itemID = 3003,
        itemName = "Feast Gamma",
        totalToBuy = 0,
        sources = { RESTOCK = 0, ONE_TIME_TARGET = 0, REQUEST = 0 },
    },
    [1001] = {
        itemID = 1001,
        itemName = "Flask Alpha",
        totalToBuy = 5,
        sources = { RESTOCK = 4, ONE_TIME_TARGET = 0, REQUEST = 1 },
        details = {
            { source = "RESTOCK", quantity = 4, scope = "GLOBAL" },
            { source = "REQUEST", quantity = 1, scope = "GLOBAL" },
        },
    },
}, {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, craftedQuality = 3 },
    },
})

assert.equal(1, #enrichedRows, "materialized rows should omit zero-demand export rows")
assert.equal(10, enrichedRows[1].currentQuantity, "materialized rows should include current snapshot quantity")
assert.equal(4, enrichedRows[1].restockQuantity, "materialized rows should expose restock contribution")
assert.equal(0, enrichedRows[1].targetQuantity, "materialized rows should expose one-time target contribution")
assert.equal(1, enrichedRows[1].requestQuantity, "materialized rows should expose approved request contribution")
assert.equal("GLOBAL", enrichedRows[1].scopeSummary, "materialized rows should summarize involved scopes")
assert.equal(3, enrichedRows[1].quality, "materialized rows should expose crafted quality for Auctionator exports")
assert.equal("None", enrichedRows[1].excessStockIn, "materialized rows without another tab should show no excess stock elsewhere")

local exportDialog = dofile("GBankManager/UI/ExportDialog.lua")
local defaultState = exportDialog.BuildPresetState(rows)
local spreadsheetState = exportDialog.BuildPresetState(rows, "Spreadsheet")
local auctionatorState = exportDialog.BuildPresetState(rows, "Auctionator", {
    shoppingListName = "Raid Prep",
})
local customState = exportDialog.BuildPresetState(rows, "Custom", {
    delimiter = "|",
    includeHeader = false,
    fields = { "totalToBuy", "itemName" },
})

assert.equal("CSV", defaultState.presetName, "export dialog should default to the visible CSV preset name")
assert.equal("CSV", spreadsheetState.presetName, "export dialog should map legacy spreadsheet state to the visible CSV preset name")
assert.equal("Auctionator", auctionatorState.presetName, "export dialog should preserve the selected preset")
assert.equal("Raid Prep", auctionatorState.shoppingListName, "auctionator preset state should preserve the officer-selected shopping-list name")
assert.equal("Raid Prep^Flask Alpha^Potion Beta", auctionatorState.text, "auctionator preset should build Auctionator's current importable shopping-list text")
assert.equal("5|Flask Alpha\n2|Potion Beta", customState.text, "custom preset should honor caller template settings")

local exportsView = dofile("GBankManager/UI/ExportsView.lua")
local spreadsheetText = exportsView.BuildSpreadsheetText(enrichedRows)
local csvText = exportsView.BuildCsvText(enrichedRows)
local tsmText = exportsView.BuildTsmItemIdText(enrichedRows)

assert.equal("Item ID,Tier,Item Name,Bank Tab,Amount to Stock,Excess Stock\n1001,3,Flask Alpha,GLOBAL,5,None", csvText, "csv preset should mirror the visible export columns")
assert.equal(csvText, spreadsheetText, "spreadsheet alias should preserve the visible CSV output")
assert.equal("1001", tsmText, "TSM export should provide the supported comma-delimited item id import list")

local elsewhereRows = exports.MaterializePlanRows({
    [5005] = {
        itemID = 5005,
        itemName = "Oil Delta",
        totalToBuy = 6,
        sources = { RESTOCK = 6, ONE_TIME_TARGET = 0, REQUEST = 0 },
        details = {
            { source = "RESTOCK", quantity = 6, scope = "TAB", tabName = "Raid Buffer" },
        },
    },
}, {
    items = {
        [5005] = {
            itemID = 5005,
            name = "Oil Delta",
            totalCount = 7,
            craftedQuality = 2,
            tabs = {
                ["Raid Buffer"] = 1,
                ["Freebiez"] = 6,
                Overflow = 9,
            },
        },
    },
})

assert.equal("Raid Buffer", elsewhereRows[1].bankTab, "exports rows should expose the shortage bank tab")
assert.equal("Overflow", elsewhereRows[1].excessStockIn, "exports rows should show the other guild-bank tab with the most excess stock")
assert.equal("Overflow", elsewhereRows[1].stockedElsewhereTabs[1].tabName, "exports rows should sort stocked-elsewhere tabs by quantity descending")
assert.equal(9, elsewhereRows[1].stockedElsewhereTabs[1].quantity, "exports rows should keep the stocked-elsewhere quantities for the modal")
assert.equal("Freebiez", elsewhereRows[1].stockedElsewhereTabs[2].tabName, "exports rows should keep the remaining stocked-elsewhere tabs available for drill-in")
assert.equal(0, #exports.FilterRowsUnavailableElsewhere(elsewhereRows), "missing-only exports should skip rows stocked elsewhere")

local dbRows = exports.BuildRowsFromDatabase({
    currentSnapshotId = "scan-1",
    snapshots = {
        ["scan-1"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 3 },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 5, scope = "GLOBAL" },
    },
    oneTimeTargets = {},
    requests = {
        { itemID = 2002, itemName = "Potion Beta", quantity = 2, approval = "APPROVED", fulfillment = "OPEN" },
    },
})

assert.equal(2, #dbRows, "database export rows should be materialized from planning inputs in one domain call")
assert.equal("Flask Alpha", dbRows[1].itemName, "database export rows should stay sorted for UI consumers")
assert.equal(2, dbRows[1].totalToBuy, "database export rows should compute shortages from minimums")
assert.equal(2, dbRows[2].requestQuantity, "database export rows should include approved open requests")
