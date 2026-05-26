package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "history-test",
    snapshots = {
        ["history-test"] = {
            items = {},
        },
    },
    minimums = {},
    requests = {},
    auditLog = {
        { type = "MINIMUM_UPDATED", category = "MINIMUM", itemName = "Old Item", actor = "OfficerOne", oldValue = "50", newValue = "100", timestamp = 100 },
        { type = "REQUEST_APPROVED", category = "REQUEST", itemName = "Newest Item", actor = "OfficerTwo", oldValue = "PENDING", newValue = "APPROVED", timestamp = 300 },
    },
}

env.ns.state.db = _G.GBankManagerDB
mainFrame:SelectView("HISTORY")

assert.equal("When", mainFrame.tableHeaderLabels[1]:GetText(), "history should keep the timestamp summary column")
assert.equal("Category", mainFrame.tableHeaderLabels[2]:GetText(), "history should keep the category summary column")
assert.equal("Item", mainFrame.tableHeaderLabels[3]:GetText(), "history should keep the item summary column")
assert.equal("Action", mainFrame.tableHeaderLabels[4]:GetText(), "history should keep the action summary column")
assert.equal("Who", mainFrame.tableHeaderLabels[5]:GetText(), "history should keep the actor summary column")
assert.equal("", mainFrame.tableHeaderLabels[6]:GetText(), "history should drop the old value table column")
assert.equal("", mainFrame.tableHeaderLabels[7]:GetText(), "history should drop the new value table column")
assert.equal("Newest Item", mainFrame.tableRowsData[1].itemName, "history should still sort newest-first after the summary-table redesign")

mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.historyDetailsModal:IsShown(), "clicking a history row should open the history details modal")
assert.equal("History Details", mainFrame.historyDetailsTitle:GetText(), "history details should use a clear modal title")
assert.equal("Newest Item", mainFrame.historyDetailsItemText:GetText(), "history details should show the clicked item name")
assert.equal("OfficerTwo", mainFrame.historyDetailsWhoText:GetText(), "history details should show who made the change")
assert.equal("PENDING", mainFrame.historyDetailsOldValueText:GetText(), "history details should show the old value outside the table")
assert.equal("APPROVED", mainFrame.historyDetailsNewValueText:GetText(), "history details should show the new value outside the table")
assert.equal("modal-sheet", mainFrame.historyDetailsModal.gbmSurfaceVariant, "history details should reuse the cleaner floating-sheet modal surface")
