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
