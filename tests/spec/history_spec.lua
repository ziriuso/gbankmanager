local assert = require("tests.helpers.assert")
local historyView = dofile("GBankManager/UI/HistoryView.lua")

local filtered = historyView.FilterProcurementEntries({
    { type = "OPTIONS_CHANGED", category = "OPTIONS", itemName = "Opacity" },
    { type = "AUTH_POLICY_UPDATED", category = "OPTIONS", itemName = "Guild Permissions", actor = "GuildLead-Stormrage", oldValue = "100", newValue = "250", timestamp = 123 },
    { type = "MINIMUM_UPDATED", category = "MINIMUM", itemName = "Potion Beta" },
    { type = "REQUEST_APPROVED", category = "REQUEST", itemName = "Flask Alpha" },
})

assert.equal(3, #filtered, "history procurement filtering should also keep auth-policy updates")
assert.equal("OPTIONS", filtered[1].category, "history procurement filtering should preserve auth-policy entries")
assert.equal("MINIMUM", filtered[2].category, "history procurement filtering should preserve minimum entries")
assert.equal("REQUEST", filtered[3].category, "history procurement filtering should preserve request entries")

local optionRows = historyView.BuildTableRows({
    { type = "AUTH_POLICY_UPDATED", category = "OPTIONS", itemName = "Guild Permissions", actor = "GuildLead-Stormrage", oldValue = "100", newValue = "250", timestamp = 123 },
}, {})

assert.equal("Options", optionRows[1].category, "history rows should humanize auth-policy option categories")
assert.equal("Updated", optionRows[1].action, "history rows should humanize auth-policy update actions")

local sortedRows = historyView.BuildTableRows({
    { type = "MINIMUM_UPDATED", category = "MINIMUM", itemName = "Old Item", actor = "A", oldValue = "1", newValue = "2", timestamp = 100 },
    { type = "REQUEST_APPROVED", category = "REQUEST", itemName = "Newest Item", actor = "B", oldValue = "PENDING", newValue = "APPROVED", timestamp = 300 },
    { type = "REQUEST_CREATED", category = "REQUEST", itemName = "Middle Item", actor = "C", oldValue = "-", newValue = "-", timestamp = 200 },
}, {})

assert.equal("Newest Item", sortedRows[1].itemName, "history rows should sort newest-first by timestamp")
assert.equal("Middle Item", sortedRows[2].itemName, "history rows should keep the second-newest entry in the middle")
assert.equal("Old Item", sortedRows[3].itemName, "history rows should place the oldest entry last")
assert.equal(nil, sortedRows[1].oldValue, "history rows should no longer expose old value as a visible table column")
assert.equal(nil, sortedRows[1].newValue, "history rows should no longer expose new value as a visible table column")
assert.equal("PENDING", sortedRows[1].details.oldValue, "history rows should preserve the old value in drill-in details")
assert.equal("APPROVED", sortedRows[1].details.newValue, "history rows should preserve the new value in drill-in details")
assert.equal("REQUEST_APPROVED", sortedRows[1].details.type, "history rows should keep the raw audit type for detail modals")
