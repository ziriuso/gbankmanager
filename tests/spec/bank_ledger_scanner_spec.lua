local assert = require("tests.helpers.assert")

_G.UnitName = function()
    return "OfficerOne"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

dofile("tests/helpers/wow_stubs.lua")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local scanner = ns.modules.scanner
local store = ns.modules.store

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB

_G.time = function()
    return 1716577200
end

_G.GetNumGuildBankTabs = function()
    return 2
end

_G.GetGuildBankTabInfo = function(tabIndex)
    if tabIndex == 1 then
        return "Flasks", nil, true
    end
    if tabIndex == 2 then
        return "Raid", nil, true
    end
end

_G.C_Item = {
    GetItemNameByID = function(itemID)
        local names = {
            [211878] = "Flask of Tempered Swiftness",
            [210000] = "Potion of Controlled Fury",
        }
        return names[itemID]
    end,
}

local queriedLogs = {}
_G.QueryGuildBankLog = function(queryId)
    table.insert(queriedLogs, queryId)
end
_G.currentGuildBankTab = 1
_G.SetCurrentGuildBankTabCalls = {}

local function run_all_pending(maxPasses)
    local passes = 0
    maxPasses = maxPasses or 20
    while #(_G.C_Timer.pending or {}) > 0 and passes < maxPasses do
        _G.C_Timer.RunPending()
        passes = passes + 1
    end
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex == 1 then
        return 1
    end
    if tabIndex == 2 then
        return 1
    end
    return 0
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    if tabIndex == 1 and index == 1 then
        return "deposit", "GuildLead-Stormrage", "item:211878:0:0:0", 12, nil, nil, 2026, 5, 24, 9
    end
    if tabIndex == 2 and index == 1 then
        return "withdraw", "RaiderOne-Stormrage", "item:210000:0:0:0", 3, nil, nil, 2026, 5, 24, 8
    end
end

_G.GetNumGuildBankMoneyTransactions = function()
    return 2
end

_G.GetGuildBankMoneyTransaction = function(index)
    if index == 1 then
        return "repair", "RepairDruid-Stormrage", 12345600, 2026, 5, 24, 7
    end
    if index == 2 then
        return "deposit", "GuildLead-Stormrage", 500000000, 2026, 5, 24, 6
    end
end

local originalBeginScan = scanner.BeginScan
local originalBeginLedgerScan = scanner.BeginLedgerScan
local beginScanCalls = 0
local beginLedgerCalls = 0

scanner.BeginScan = function()
    beginScanCalls = beginScanCalls + 1
    scanner.scanInProgress = true
    return "Scanning 0/2 tabs"
end

scanner.BeginLedgerScan = function()
    beginLedgerCalls = beginLedgerCalls + 1
    return true
end

_G.GBankManagerDB.meta.updatedAt = 0
_G.GBankManagerDB.bankLedger.lastScanAt = 0
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

scanner.OnGuildBankOpened()
assert.equal(1, beginScanCalls, "guild bank open should still route through the main inventory scan path")
assert.equal(0, beginLedgerCalls, "guild bank open should not start a parallel ledger scan before the inventory scan finishes")

_G.GBankManagerDB.meta.updatedAt = 1716577200
_G.GBankManagerDB.bankLedger.lastScanAt = 0
scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.OnGuildBankOpened()
assert.equal(1, beginScanCalls, "guild bank open should skip a second inventory scan when the main snapshot is still inside the scan interval")
assert.equal(1, beginLedgerCalls, "guild bank open should still trigger a direct ledger scan when ledger data is stale but the main snapshot is still fresh")

scanner.BeginScan = originalBeginScan
scanner.BeginLedgerScan = originalBeginLedgerScan
scanner.pendingLedgerScanAfterInventory = false

assert.truthy(scanner.BeginLedgerScan(), "ledger scan should start when guild bank logs are available")
assert.equal(1, queriedLogs[1], "ledger scan should bulk-query the first item-log tab")
assert.equal(2, queriedLogs[2], "ledger scan should bulk-query the second item-log tab")
assert.equal(3, queriedLogs[3], "ledger scan should bulk-query the money log")
run_all_pending()
assert.equal(0, #(_G.SetCurrentGuildBankTabCalls or {}), "ledger scan should not visually switch selected guild-bank tabs")

assert.equal(2, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "ledger scan should persist new item-log rows")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "ledger scan should persist new money-log rows")
assert.equal("Deposit", _G.GBankManagerDB.bankLedger.itemLogs[1].action, "ledger scan should humanize deposit log actions")
assert.equal("Withdrawal", _G.GBankManagerDB.bankLedger.itemLogs[2].action, "ledger scan should humanize withdrawal log actions")
assert.equal("Repair", _G.GBankManagerDB.bankLedger.moneyLogs[1].action, "ledger scan should preserve repair actions from money logs")
assert.equal(1716577200, _G.GBankManagerDB.bankLedger.lastScanAt, "ledger scan should stamp the combined scan time")
assert.equal("Guild bank ledger scan finished (2 item rows, 2 money rows).", scanner:GetStatusText(), "ledger scan should report a visible completion summary with merged row counts")

queriedLogs = {}
assert.truthy(not scanner.BeginLedgerScan(), "ledger scan should throttle inside the configured interval")
assert.equal(0, #queriedLogs, "throttled ledger scans should not query any logs")

local ledgerStartCalls = 0
scanner.BeginLedgerScan = function()
    ledgerStartCalls = ledgerStartCalls + 1
    return true
end

scanner.pendingLedgerScanAfterInventory = true
scanner.pendingLedgerScanOptions = {
    force = true,
}
scanner.scanInProgress = true
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        slots = {
            { itemID = 211878, name = "Flask of Tempered Swiftness", count = 12 },
        },
    },
}

_G.time = function()
    return 1716577800
end

scanner.FinishScan("OfficerOne", "Guild Testers")
assert.equal(1, ledgerStartCalls, "completing the main guild-bank scan should kick off the queued ledger scan")
assert.truthy(scanner.pendingLedgerScanAfterInventory ~= true, "ledger follow-up should clear once the main scan hands off into the ledger scan")
assert.truthy(scanner.pendingLedgerScanOptions == nil, "ledger follow-up options should clear once the handoff completes")

scanner.BeginLedgerScan = originalBeginLedgerScan
_G.GBankManagerDB.bankLedger.lastScanAt = 1716577800
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 3600
queriedLogs = {}
assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "forced ledger scans should bypass the normal ledger scan throttle")
assert.equal(1, queriedLogs[1], "forced ledger scans should still query the first item-log tab")
run_all_pending()
assert.truthy(#queriedLogs >= 3, "forced ledger scans should still walk the full queued log target list even if a target is retried once")

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.meta.updatedAt = 1716580000
_G.GBankManagerDB.bankLedger.lastScanAt = 0

ns.modules.bankLedger.MergeItemTransactions(_G.GBankManagerDB, {
    scanStartedAt = 1716579000,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            quantity = 12,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})

ns.modules.bankLedger.MergeMoneyTransactions(_G.GBankManagerDB, {
    scanStartedAt = 1716579000,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 500000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 6,
        },
    },
})

local itemQueryCount = 0
local moneyQueryCount = 0
queriedLogs = {}
_G.QueryGuildBankLog = function(queryId)
    table.insert(queriedLogs, queryId)
    if queryId == 1 then
        itemQueryCount = itemQueryCount + 1
    elseif queryId == 2 then
        moneyQueryCount = moneyQueryCount + 1
    end
end

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex == 1 then
        return 2
    end
    return 0
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    if tabIndex ~= 1 then
        return nil
    end

    if index == 1 then
        return "deposit", "GuildLead-Stormrage", "item:211878:0:0:0", 5, nil, nil, 2026, 5, 24, 9
    end
    if index == 2 then
        return "deposit", "GuildLead-Stormrage", "item:211878:0:0:0", 12, nil, nil, 2026, 5, 24, 9
    end
end

_G.GetNumGuildBankMoneyTransactions = function()
    return 2
end

_G.GetGuildBankMoneyTransaction = function(index)
    if index == 1 then
        return "deposit", "GuildLead-Stormrage", 250000000, 2026, 5, 24, 6
    end
    if index == 2 then
        return "deposit", "GuildLead-Stormrage", 500000000, 2026, 5, 24, 6
    end
end

_G.time = function()
    return 1716580000
end

scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
scanner.ledgerWaitingTarget = nil

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start for the fast bulk-query merge case")
run_all_pending(10)
assert.equal(1, itemQueryCount, "fast ledger scans should query each item-log source once")
assert.equal(1, moneyQueryCount, "fast ledger scans should query the money log once")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "the bulk-query path should append the genuinely new item row")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "the bulk-query path should append the genuinely new money row")
assert.equal("Guild bank ledger scan finished (1 item rows, 1 money rows).", scanner:GetStatusText(), "the bulk-query path should report only the genuinely new ledger rows")
