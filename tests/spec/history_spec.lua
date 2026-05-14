local assert = require("tests.helpers.assert")
local historyView = dofile("GBankManager/UI/HistoryView.lua")

local filtered = historyView.FilterProcurementEntries({
    { type = "OPTIONS_CHANGED", category = "OPTIONS", itemName = "Opacity" },
    { type = "MINIMUM_UPDATED", category = "MINIMUM", itemName = "Potion Beta" },
    { type = "REQUEST_APPROVED", category = "REQUEST", itemName = "Flask Alpha" },
})

assert.equal(2, #filtered, "history procurement filtering should keep only request and minimum entries")
assert.equal("MINIMUM", filtered[1].category, "history procurement filtering should preserve minimum entries")
assert.equal("REQUEST", filtered[2].category, "history procurement filtering should preserve request entries")
