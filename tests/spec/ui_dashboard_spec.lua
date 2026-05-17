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

_G.GBankManagerDB = _G.GBankManagerDB or {}
_G.GBankManagerDB.meta = _G.GBankManagerDB.meta or {}
_G.GBankManagerDB.meta.updatedAt = 1715523300
_G.GBankManagerDB.currentSnapshotId = "dashboard-scan"
_G.GBankManagerDB.snapshots = {
    ["dashboard-scan"] = {
        scanId = "dashboard-scan",
        scannedAt = 1715523300,
        items = {
            [240154] = { itemID = 240154, name = "Arcanoweave Spellthread", totalCount = 20, tabs = { Tailoring = 20 } },
            [241304] = { itemID = 241304, name = "Silvermoon Health Potion", totalCount = 40, tabs = { Potions = 40 } },
        },
    },
}
_G.GBankManagerDB.minimums = {
    { itemID = 240154, itemName = "Arcanoweave Spellthread", quantity = 100, scope = "TAB", tabName = "Tailoring", enabled = true },
    { itemID = 241304, itemName = "Silvermoon Health Potion", quantity = 250, scope = "TAB", tabName = "Potions", enabled = true },
}
_G.GBankManagerDB.auditLog = {
    {
        category = "REQUEST",
        type = "REQUEST_APPROVED",
        itemName = "Silvermoon Health Potion",
        actor = "OfficerOne",
        timestamp = 1715523200,
    },
    {
        category = "MINIMUM",
        type = "MINIMUM_UPDATED",
        itemName = "Arcanoweave Spellthread",
        actor = "GuildLead",
        timestamp = 1715523100,
    },
}
_G.GBankManagerDB.requests = {}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("DASHBOARD")

assert.equal("DASHBOARD", mainFrame.activeView, "dashboard should be the active view")
assert.equal(4, #(mainFrame.dashboardCards or {}), "dashboard should expose four metric cards")
assert.equal("Critical Shortages", ((mainFrame.dashboardCards or {})[4] or {}).titleText:GetText(), "dashboard should use the fourth metric card for critical shortages")
assert.truthy(type(((mainFrame.dashboardCards or {})[1] or {}).iconTexture) == "table", "dashboard metric cards should expose an icon texture")
assert.truthy((((mainFrame.dashboardCards or {})[1] or {}).iconTexture or {}).texture ~= nil, "dashboard metric cards should assign a real icon texture")
assert.truthy(mainFrame.dashboardTopItemsPanel:IsShown(), "dashboard should show the top-items panel")
assert.truthy(mainFrame.dashboardRecentActivityPanel:IsShown(), "dashboard should show the recent-activity panel")
assert.truthy(mainFrame.dashboardQuickActionsPanel:IsShown(), "dashboard should show the quick-actions row")
assert.equal("Top 5 Most Used", mainFrame.dashboardTopItemsTitle:GetText(), "dashboard top-items panel should keep the stable title")
assert.equal("Recent Activity", mainFrame.dashboardRecentActivityTitle:GetText(), "dashboard should title the recent-activity panel")
assert.equal("Quick Actions", mainFrame.dashboardQuickActionsTitle:GetText(), "dashboard should title the quick-actions row")
assert.equal(5, #(mainFrame.dashboardQuickActionButtons or {}), "dashboard should expose five quick actions")
assert.equal("Scan Bank", ((mainFrame.dashboardQuickActionButtons or {})[1] or {}).labelText:GetText(), "dashboard quick actions should include Scan Bank")
assert.equal("View Inventory", ((mainFrame.dashboardQuickActionButtons or {})[2] or {}).labelText:GetText(), "dashboard quick actions should include View Inventory")
assert.equal("Add Minimum", ((mainFrame.dashboardQuickActionButtons or {})[3] or {}).labelText:GetText(), "dashboard quick actions should include Add Minimum")
assert.equal("Request Overview", ((mainFrame.dashboardQuickActionButtons or {})[4] or {}).labelText:GetText(), "dashboard quick actions should include Request Overview")
assert.equal("Export Data", ((mainFrame.dashboardQuickActionButtons or {})[5] or {}).labelText:GetText(), "dashboard quick actions should include Export Data")
assert.truthy(string.find(mainFrame.dashboardTopItemsText:GetText() or "", "Arcanoweave Spellthread", 1, true) ~= nil, "dashboard top-items panel should include ranked item text")
assert.truthy(string.find(mainFrame.dashboardRecentActivityText:GetText() or "", "Silvermoon Health Potion", 1, true) ~= nil, "dashboard recent-activity panel should include recent audit rows")

mainFrame.dashboardQuickActionButtons[2]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[2])
assert.equal("INVENTORY", mainFrame.activeView, "dashboard quick action should jump to inventory")
mainFrame:SelectView("DASHBOARD")
mainFrame.dashboardQuickActionButtons[4]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[4])
assert.equal("REQUESTS", mainFrame.activeView, "dashboard quick action should jump to requests")
mainFrame:SelectView("DASHBOARD")
mainFrame.dashboardQuickActionButtons[5]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[5])
assert.equal("EXPORTS", mainFrame.activeView, "dashboard quick action should jump to exports")
