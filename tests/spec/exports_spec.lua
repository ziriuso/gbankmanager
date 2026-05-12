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
    { itemName = "Flask Alpha", totalToBuy = 4 },
    { itemName = "Potion Beta", totalToBuy = 2 },
})

assert.equal("Flask Alpha x4; Potion Beta x2", auctionator, "auctionator export should build a compact item list")

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
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10 },
    },
})

assert.equal(1, #enrichedRows, "materialized rows should omit zero-demand export rows")
assert.equal(10, enrichedRows[1].currentQuantity, "materialized rows should include current snapshot quantity")
assert.equal(4, enrichedRows[1].restockQuantity, "materialized rows should expose restock contribution")
assert.equal(0, enrichedRows[1].targetQuantity, "materialized rows should expose one-time target contribution")
assert.equal(1, enrichedRows[1].requestQuantity, "materialized rows should expose approved request contribution")
assert.equal("GLOBAL", enrichedRows[1].scopeSummary, "materialized rows should summarize involved scopes")

local exportDialog = dofile("GBankManager/UI/ExportDialog.lua")
local auctionatorState = exportDialog.BuildPresetState(rows, "Auctionator")
local customState = exportDialog.BuildPresetState(rows, "Custom", {
    delimiter = "|",
    includeHeader = false,
    fields = { "totalToBuy", "itemName" },
})

assert.equal("Auctionator", auctionatorState.presetName, "export dialog should preserve the selected preset")
assert.equal("Flask Alpha x5; Potion Beta x2", auctionatorState.text, "auctionator preset should build compact output")
assert.equal("5|Flask Alpha\n2|Potion Beta", customState.text, "custom preset should honor caller template settings")

local exportsView = dofile("GBankManager/UI/ExportsView.lua")
local spreadsheetText = exportsView.BuildSpreadsheetText(enrichedRows)
local customText = exportsView.BuildCustomText(enrichedRows, {
    delimiter = "|",
    includeHeader = false,
    fields = { "itemID", "itemName", "totalToBuy" },
})

assert.equal("itemName,itemID,currentQuantity,restockQuantity,targetQuantity,requestQuantity,totalToBuy,scopeSummary,reason\nFlask Alpha,1001,10,4,0,1,5,GLOBAL,REQUEST:1|RESTOCK:4", spreadsheetText, "spreadsheet preset should expose export audit columns")
assert.equal("1001|Flask Alpha|5", customText, "custom view helper should pass templates through to the export domain")
