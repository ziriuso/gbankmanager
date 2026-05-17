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
