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
local activeTheme = env.mainFrameShell.GetTheme()

local function color_distance(left, right)
    left = left or {}
    right = right or {}
    local total = 0
    for index = 1, 3 do
        total = total + math.abs((left[index] or 0) - (right[index] or 0))
    end
    return total
end

_G.GBankManagerDB = _G.GBankManagerDB or {}
_G.GBankManagerDB.meta = _G.GBankManagerDB.meta or {}
_G.GBankManagerDB.meta.updatedAt = 1715523300
_G.GBankManagerDB.ui = _G.GBankManagerDB.ui or {}
_G.GBankManagerDB.ui.minimumSettings = _G.GBankManagerDB.ui.minimumSettings or {}
_G.GBankManagerDB.ui.minimumSettings.criticalThresholdPercent = 16
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
_G.GBankManagerDB.bankLedger = {
    itemLogs = {
        { action = "Withdrawal", itemName = "Flask of the Magisters", quantity = 12, timestamp = 1715523250 },
        { action = "Withdrawal", itemName = "Silvermoon Health Potion", quantity = 8, timestamp = 1715523240 },
        { action = "Withdrawal", itemName = "Thalassian Phoenix Oil", quantity = 6, timestamp = 1715523230 },
        { action = "Withdrawal", itemName = "Bright Eyeball", quantity = 5, timestamp = 1715523220 },
        { action = "Withdrawal", itemName = "Flask of Tempered Swiftness", quantity = 4, timestamp = 1715523210 },
        { action = "Withdrawal", itemName = "Potion of Controlled Fury", quantity = 3, timestamp = 1715523200 },
        { action = "Withdrawal", itemName = "Arcanoweave Spellthread", quantity = 2, timestamp = 1715523190 },
        { action = "Withdrawal", itemName = "Dawn Crystal", quantity = 2, timestamp = 1715523180 },
        { action = "Withdrawal", itemName = "Contract: The Amani Tribe", quantity = 1, timestamp = 1715523170 },
        { action = "Withdrawal", itemName = "Flask of Frozen Focus", quantity = 1, timestamp = 1715523160 },
        { action = "Withdrawal", itemName = "Overflow Item", quantity = 1, timestamp = 1715523150 },
    },
    moneyLogs = {},
}
_G.GBankManagerDB.ui.logsHistorySettings = {
    ledgerRetention = "indefinite",
    historyRetention = "indefinite",
    ledgerScanIntervalSeconds = 300,
}
_G.GBankManagerDB.requests = {}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("DASHBOARD")

assert.equal("DASHBOARD", mainFrame.activeView, "dashboard should be the active view")
assert.equal(4, #(mainFrame.dashboardCards or {}), "dashboard should expose four metric cards")
assert.equal("Critical Shortages", ((mainFrame.dashboardCards or {})[4] or {}).titleText:GetText(), "dashboard should use the fourth metric card for critical shortages")
assert.equal("1", ((mainFrame.dashboardCards or {})[4] or {}).valueText:GetText(), "dashboard critical shortages should count only items at or below the configured threshold")
assert.equal("<= 16% of Min", (((mainFrame.dashboardCards or {})[4] or {}).noteText or {}):GetText(), "dashboard should keep the critical-threshold note short enough to avoid overflow")
assert.truthy(type(((mainFrame.dashboardCards or {})[1] or {}).iconTexture) == "table", "dashboard metric cards should expose an icon texture")
assert.truthy((((mainFrame.dashboardCards or {})[1] or {}).iconTexture or {}).texture ~= nil, "dashboard metric cards should assign a real icon texture")
assert.equal("metric-card-flat", ((mainFrame.dashboardCards or {})[1] or {}).gbmSurfaceVariant, "dashboard metrics should remain separate cards but use the flatter card variant")
assert.truthy(mainFrame.dashboardTopItemsPanel:IsShown(), "dashboard should show the top-items panel")
assert.truthy(mainFrame.dashboardRecentActivityPanel:IsShown(), "dashboard should show the recent-activity panel")
assert.truthy(mainFrame.dashboardQuickActionsPanel:IsShown(), "dashboard should show the quick-actions row")
assert.equal("panel-flat", mainFrame.dashboardTopItemsPanel.gbmSurfaceVariant, "dashboard top-items panel should inherit the flatter dark-band surface")
assert.equal("panel-flat", mainFrame.dashboardRecentActivityPanel.gbmSurfaceVariant, "dashboard recent-activity panel should inherit the flatter dark-band surface")
assert.equal("panel-flat", mainFrame.dashboardQuickActionsPanel.gbmSurfaceVariant, "dashboard quick-actions panel should inherit the flatter dark-band surface")
assert.equal("Top 10 Most Used", mainFrame.dashboardTopItemsTitle:GetText(), "dashboard top-items panel should now expose the top ten usage title")
assert.equal("Recent Activity", mainFrame.dashboardRecentActivityTitle:GetText(), "dashboard should title the recent-activity panel")
assert.equal("Quick Actions", mainFrame.dashboardQuickActionsTitle:GetText(), "dashboard should title the quick-actions row")
assert.equal(3, #(mainFrame.dashboardQuickActionButtons or {}), "dashboard should expose the trimmed quick-action set")
assert.equal("Add Minimum", ((mainFrame.dashboardQuickActionButtons or {})[1] or {}).labelText:GetText(), "dashboard quick actions should include Add Minimum")
assert.equal("Create Request", ((mainFrame.dashboardQuickActionButtons or {})[2] or {}).labelText:GetText(), "dashboard quick actions should include Create Request")
assert.equal("Export Data", ((mainFrame.dashboardQuickActionButtons or {})[3] or {}).labelText:GetText(), "dashboard quick actions should include Export Data")
assert.truthy((mainFrame.dashboardQuickActionButtons[2]:GetWidth() or 0) >= 148, "dashboard quick actions should widen enough for longer labels")
assert.truthy((mainFrame.dashboardQuickActionButtons[2]:GetHeight() or 0) >= 52, "dashboard quick actions should give wrapped labels a little more vertical room")
assert.equal(true, mainFrame.dashboardQuickActionButtons[2].labelText.wordWrap, "dashboard quick action labels should wrap instead of overflowing")
assert.truthy((mainFrame.dashboardQuickActionButtons[2].labelText.width or 0) <= ((mainFrame.dashboardQuickActionButtons[2]:GetWidth() or 0) - 42), "dashboard quick action labels should reserve space for the icon and padding")
assert.equal("action-slim", mainFrame.dashboardQuickActionButtons[2].gbmButtonFamily, "dashboard quick actions should use the slimmer shared action family")
assert.truthy(
    color_distance(
        ((mainFrame.dashboardQuickActionButtons[2].gbmArt or {}).innerFill or {}).color,
        ((mainFrame.dashboardQuickActionsPanel.gbmArt or {}).innerFill or {}).color
    ) >= 0.10,
    "dashboard quick actions should contrast from the quick-actions panel background"
)
assert.truthy(string.find(mainFrame.dashboardTopItemsText:GetText() or "", "Flask of the Magisters", 1, true) ~= nil, "dashboard top-items panel should now use ledger withdrawals to rank the most used items")
assert.truthy(string.find(mainFrame.dashboardTopItemsText:GetText() or "", "Flask of Frozen Focus", 1, true) ~= nil, "dashboard top-items panel should render through the tenth ranked withdrawal item")
assert.truthy(string.find(mainFrame.dashboardTopItemsText:GetText() or "", "Overflow Item", 1, true) == nil, "dashboard top-items panel should stop at ten ranked withdrawal items")
assert.truthy(string.find(mainFrame.dashboardRecentActivityText:GetText() or "", "Silvermoon Health Potion", 1, true) ~= nil, "dashboard recent-activity panel should include recent audit rows")

mainFrame.dashboardQuickActionButtons[1]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[1])
assert.equal("MINIMUMS", mainFrame.activeView, "dashboard quick action should jump to minimums")
mainFrame:SelectView("DASHBOARD")
mainFrame.dashboardQuickActionButtons[2]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[2])
_G.C_Timer.RunPending()
assert.equal("REQUESTS", mainFrame.activeView, "dashboard quick action should jump to requests")
assert.truthy(mainFrame.requestWizardModal:IsShown(), "create request quick action should launch the request workflow")
mainFrame:HideRequestWizard()
mainFrame:SelectView("DASHBOARD")
mainFrame.dashboardQuickActionButtons[3]:GetScript("OnClick")(mainFrame.dashboardQuickActionButtons[3])
assert.equal("EXPORTS", mainFrame.activeView, "dashboard quick action should jump to exports")
