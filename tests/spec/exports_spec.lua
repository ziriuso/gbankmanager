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
