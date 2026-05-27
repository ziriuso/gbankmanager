local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

dofile("tests/helpers/wow_stubs.lua")

local env = fixture.load()
local mainFrame = env.mainFrame

local function shown_option_count()
    local count = 0
    for _, option in ipairs(mainFrame.sharedChoiceDropdownOptions or {}) do
        if option:IsShown() then
            count = count + 1
        end
    end
    return count
end

_G.GBankManagerDB.bankLedger = {
    itemLogs = {
        {
            timestamp = 1716577200,
            when = 1716577200,
            who = "GuildLead-Stormrage",
            action = "Deposit",
            itemID = 211878,
            qualityTier = 3,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3",
            item = "Flask of Tempered Swiftness",
            quantity = 12,
            tabName = "Flasks",
            fromTabName = "-",
        },
        {
            timestamp = 1716577100,
            when = 1716577100,
            who = "RaiderOne-Stormrage",
            action = "Withdrawal",
            itemID = 211878,
            qualityTier = 3,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3",
            item = "Flask of Tempered Swiftness",
            quantity = 7,
            tabName = "Flasks",
            fromTabName = "-",
        },
        {
            timestamp = 1716000000,
            when = 1716000000,
            who = "Archivist-Stormrage",
            action = "Deposit",
            itemID = 210999,
            qualityTier = 2,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
            item = "Potion of Controlled Fury",
            quantity = 3,
            tabName = "Potions",
            fromTabName = "-",
        },
    },
    moneyLogs = {
        {
            timestamp = 1716577000,
            when = 1716577000,
            who = "RepairDruid-Stormrage",
            action = "Repair",
            amountCopper = 12345600,
            amount = 12345600,
        },
        {
            timestamp = 1716576900,
            when = 1716576900,
            who = "GuildLead-Stormrage",
            action = "Deposit",
            amountCopper = 500000000,
            amount = 500000000,
        },
    },
}
_G.GBankManagerDB.ui.logsHistorySettings = {
    ledgerRetention = "indefinite",
    historyRetention = "indefinite",
    ledgerScanIntervalSeconds = 300,
}
env.ns.state.db = _G.GBankManagerDB
_G.time = function()
    return 1716577300
end

mainFrame:SelectView("BANK_LEDGER")

assert.equal("BANK_LEDGER", mainFrame.activeView, "bank ledger view should be selectable")
assert.equal("Review guild bank ledger history", mainFrame.viewSubtitle:GetText(), "bank ledger should use the shorter subtitle copy")
assert.truthy(mainFrame.tableHeaderFrame:IsShown(), "bank ledger should use the shared table surface")
assert.truthy(mainFrame.bankLedgerPanel and mainFrame.bankLedgerPanel:IsShown(), "bank ledger should expose a footer/control panel")
assert.equal("Item Log", mainFrame.bankLedgerItemModeButton.labelText:GetText(), "bank ledger should expose an item-log mode button")
assert.equal("Money Log", mainFrame.bankLedgerMoneyModeButton.labelText:GetText(), "bank ledger should expose a money-log mode button")
assert.equal("Action", mainFrame.bankLedgerActionFilterTitle:GetText(), "bank ledger should expose an action filter")
assert.equal("Date Range", mainFrame.bankLedgerDateRangeTitle:GetText(), "bank ledger should expose a preset date-range filter")
assert.equal("All", mainFrame.bankLedgerDateRangeButton.labelText:GetText(), "bank ledger should default the date-range filter to All")
assert.equal("Export CSV", mainFrame.bankLedgerExportButton.labelText:GetText(), "bank ledger should expose csv export")
assert.equal("Date", mainFrame.tableHeaderLabels[1]:GetText(), "bank ledger item mode should show date column")
assert.equal("Who", mainFrame.tableHeaderLabels[2]:GetText(), "bank ledger item mode should show actor column")
assert.equal("Action", mainFrame.tableHeaderLabels[3]:GetText(), "bank ledger item mode should show action column")
assert.equal("Tier", mainFrame.tableHeaderLabels[4]:GetText(), "bank ledger item mode should show tier column")
assert.equal("Item", mainFrame.tableHeaderLabels[5]:GetText(), "bank ledger item mode should show item name column")
assert.equal("Quantity", mainFrame.tableHeaderLabels[6]:GetText(), "bank ledger item mode should show quantity column")
assert.equal("Tab", mainFrame.tableHeaderLabels[7]:GetText(), "bank ledger item mode should show tab column")
assert.equal("Moved From", mainFrame.tableHeaderLabels[8]:GetText(), "bank ledger item mode should show moved-from column")
assert.equal("Flask of Tempered Swiftness", (mainFrame.tableRowsData[1] or {}).item, "bank ledger item mode should populate item log rows")
assert.equal("Flasks", (mainFrame.tableRowsData[1] or {}).tab, "bank ledger item mode should show the source bank tab")
assert.truthy(string.find(((mainFrame.tableRowsData[1] or {}).tier or ""), "|A:", 1, true) ~= nil, "bank ledger item mode should render the tier as icon markup")
assert.truthy(string.find(mainFrame.bankLedgerSummaryPrimaryText:GetText() or "", "Deposits", 1, true) ~= nil, "bank ledger should summarize deposit and withdrawal activity")
assert.truthy(string.find(mainFrame.bankLedgerSummarySecondaryText:GetText() or "", "Gold In", 1, true) ~= nil, "bank ledger should summarize gold totals on the second row")
assert.equal("", mainFrame.bankLedgerSummaryTertiaryText:GetText() or "", "bank ledger should no longer show the third summary row")
mainFrame.bankLedgerActionFilterButton:GetScript("OnClick")(mainFrame.bankLedgerActionFilterButton)
assert.same(mainFrame.bankLedgerActionFilterButton, mainFrame.sharedChoiceDropdownOwner, "bank ledger action filter should open a real dropdown menu")
assert.truthy(mainFrame.sharedChoiceDropdownPanel:IsShown(), "bank ledger item action filter should show the shared dropdown panel")
assert.equal(4, shown_option_count(), "bank ledger item action filter should expose all action choices")
mainFrame.sharedChoiceDropdownOptions[2]:GetScript("OnClick")(mainFrame.sharedChoiceDropdownOptions[2])
assert.equal("deposit", mainFrame.bankLedgerActionFilter, "bank ledger action filter should persist the selected item action")
mainFrame.bankLedgerDateRangeButton:GetScript("OnClick")(mainFrame.bankLedgerDateRangeButton)
assert.same(mainFrame.bankLedgerDateRangeButton, mainFrame.sharedChoiceDropdownOwner, "bank ledger date range should open a real dropdown menu")
assert.equal(7, shown_option_count(), "bank ledger date range should expose all preset date ranges")
mainFrame.sharedChoiceDropdownOptions[1]:GetScript("OnClick")(mainFrame.sharedChoiceDropdownOptions[1])
assert.equal("1_day", mainFrame.bankLedgerDateRangeFilter, "bank ledger date range should persist the selected preset")
assert.equal(1, #mainFrame.tableRowsData, "bank ledger date range should refresh rows immediately from the selected preset and current action filter")

mainFrame.bankLedgerMoneyModeButton:GetScript("OnClick")(mainFrame.bankLedgerMoneyModeButton)

assert.equal("MONEY", mainFrame.bankLedgerMode, "bank ledger should switch to money-log mode")
assert.equal("tab", mainFrame.bankLedgerItemModeButton.gbmButtonVariant, "bank ledger item mode button should drop out of the active state when money mode is selected")
assert.equal("primary", mainFrame.bankLedgerMoneyModeButton.gbmButtonVariant, "bank ledger money mode button should show the active state when selected")
assert.equal("Amount", mainFrame.tableHeaderLabels[4]:GetText(), "bank ledger money mode should show the amount column")
assert.equal("", mainFrame.tableHeaderLabels[5]:GetText(), "bank ledger money mode should hide item-only columns")
assert.equal("Repair", (mainFrame.tableRowsData[1] or {}).action, "bank ledger money mode should populate money log rows")
assert.truthy(string.find(mainFrame.bankLedgerSummaryPrimaryText:GetText() or "", "Deposits", 1, true) ~= nil, "bank ledger money mode should keep the item summary row visible")
assert.truthy(string.find(mainFrame.bankLedgerSummarySecondaryText:GetText() or "", "Repairs", 1, true) ~= nil, "bank ledger money mode should summarize repair spend on the second row")
mainFrame.bankLedgerActionFilterButton:GetScript("OnClick")(mainFrame.bankLedgerActionFilterButton)
assert.same(mainFrame.bankLedgerActionFilterButton, mainFrame.sharedChoiceDropdownOwner, "bank ledger money action filter should open a real dropdown menu")
assert.equal(4, shown_option_count(), "bank ledger money action filter should expose all money action choices")
