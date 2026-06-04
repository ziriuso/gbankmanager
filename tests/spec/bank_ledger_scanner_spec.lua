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
local syncCodec = ns.modules.syncCodec or dofile("GBankManager/Sync/Codec.lua")
local transport = ns.modules.syncTransport or {}

local originalStoreGetDatabase = store.GetDatabase
if type(originalStoreGetDatabase) == "function" then
    store.GetDatabase = function(...)
        local db = originalStoreGetDatabase(...)
        if type(_G.GBankManagerDB) == "table" and type(db) == "table" and _G.GBankManagerDB ~= db then
            _G.GBankManagerDB.meta = db.meta
            _G.GBankManagerDB.bankLedger = db.bankLedger
            _G.GBankManagerDB.ui = db.ui
        end
        return db
    end
end

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB

local function current_db()
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    return ns.state.db or _G.GBankManagerDB
end

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
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
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
local beginLedgerOptions = {}

scanner.BeginScan = function()
    beginScanCalls = beginScanCalls + 1
    scanner.scanInProgress = true
    return "Scanning 0/2 tabs"
end

scanner.BeginLedgerScan = function(options)
    beginLedgerCalls = beginLedgerCalls + 1
    beginLedgerOptions[beginLedgerCalls] = options or {}
    return true
end

current_db().meta.updatedAt = 0
current_db().bankLedger.lastScanAt = 0
current_db().ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

scanner.OnGuildBankOpened()
assert.equal(1, beginScanCalls, "guild bank open should still route through the main inventory scan path")
assert.equal(0, beginLedgerCalls, "guild bank open should not start a parallel ledger scan before the inventory scan finishes")

current_db().meta.updatedAt = 1716577200
current_db().bankLedger.lastScanAt = 0
scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.guildBankOpen = false
scanner.OnGuildBankOpened()
assert.equal(1, beginScanCalls, "guild bank open should skip a second inventory scan when the main snapshot is still inside the scan interval")
assert.equal(1, beginLedgerCalls, "guild bank open should still trigger a direct ledger scan when ledger data is stale but the main snapshot is still fresh")
assert.truthy(beginLedgerOptions[1] and beginLedgerOptions[1].force == true, "bank-open ledger scans should force one ledger pass instead of depending on the stale-data throttle")

current_db().meta.updatedAt = 1716577200
current_db().bankLedger.lastScanAt = 1716577200
scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.guildBankOpen = false
scanner.OnGuildBankOpened()
assert.equal(1, beginScanCalls, "guild bank open should still skip inventory when the main snapshot is fresh")
assert.equal(2, beginLedgerCalls, "guild bank open should still kick off a ledger scan even when the previous ledger scan is inside the interval")
assert.truthy(beginLedgerOptions[2] and beginLedgerOptions[2].force == true, "fresh bank-open ledger scans should use the same forced follow-up behavior as the scan button")

scanner.BeginScan = originalBeginScan
scanner.BeginLedgerScan = originalBeginLedgerScan
scanner.pendingLedgerScanAfterInventory = false
current_db().bankLedger.lastScanAt = 0
_G.C_Timer.ClearPending()

local queuedAutoLedgerDb = store.CreateFreshDatabase("Guild Testers")
_G.GBankManagerDB = queuedAutoLedgerDb
ns.state.db = queuedAutoLedgerDb
current_db().meta.updatedAt = 0
current_db().bankLedger.lastScanAt = 1716577200
current_db().ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.pendingLedgerScanAfterInventory = false
scanner.pendingLedgerScanOptions = nil
scanner.guildBankOpen = false
_G.QueryGuildBankTab = function()
    return true
end
scanner.OnGuildBankOpened()
assert.truthy(scanner.scanInProgress == true, "fresh guild-bank open should start the inventory auto-scan when the main snapshot is stale")
assert.truthy(scanner.pendingLedgerScanAfterInventory == true, "fresh guild-bank inventory auto-scans should still queue a ledger follow-up even when ledger freshness is inside the interval")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.force == true, "fresh guild-bank inventory auto-scans should force the queued ledger follow-up")
scanner.OnGuildBankClosed()
current_db().bankLedger.lastScanAt = 0

local originalTransportSend = transport.Send
local outboundLedgerSyncMessages = {}
transport.Send = function(distribution, target, message)
    outboundLedgerSyncMessages[#outboundLedgerSyncMessages + 1] = {
        distribution = distribution,
        target = target,
        message = message,
        encoded = type(originalTransportSend) == "function" and originalTransportSend(distribution, target, message) or nil,
    }
    return outboundLedgerSyncMessages[#outboundLedgerSyncMessages].encoded
end

_G.C_ChatInfo.sentMessages = {}
assert.truthy(scanner.BeginLedgerScan(), "ledger scan should start when guild bank logs are available")
run_all_pending()
assert.equal(1, queriedLogs[1], "ledger scan should query the first item-log tab")
assert.equal(2, queriedLogs[2], "ledger scan should query the second item-log tab")
assert.equal(9, queriedLogs[3], "ledger scan should query the fixed guild-bank money-log slot")
assert.equal(0, #(_G.SetCurrentGuildBankTabCalls or {}), "ledger scan should not rotate the visible guild-bank tab during log imports")

assert.equal(2, #(current_db().bankLedger.itemLogs or {}), "ledger scan should persist new item-log rows")
assert.equal(2, #(current_db().bankLedger.moneyLogs or {}), "ledger scan should persist new money-log rows")
assert.equal("Deposit", current_db().bankLedger.itemLogs[1].action, "ledger scan should humanize deposit log actions")
assert.equal("Withdrawal", current_db().bankLedger.itemLogs[2].action, "ledger scan should humanize withdrawal log actions")
assert.equal("Repair", current_db().bankLedger.moneyLogs[1].action, "ledger scan should preserve repair actions from money logs")
assert.equal(1716577200, current_db().bankLedger.lastScanAt, "ledger scan should stamp the combined scan time")
assert.equal("Guild bank ledger scan finished (2 item rows, 2 money rows).", scanner:GetStatusText(), "ledger scan should report a visible completion summary with merged row counts")
assert.equal(1, #(outboundLedgerSyncMessages or {}), "ledger scan should publish exactly one manifest sync message after native writes")
local publishedLedgerManifest = ((outboundLedgerSyncMessages or {})[1] or {}).message or {}
assert.equal("LEDGER_MANIFEST", tostring(publishedLedgerManifest.type or ""), "ledger scan should publish a manifest instead of row chunks")
assert.equal(2, tonumber(((publishedLedgerManifest.payload or {}).ledgerProtocol) or 0) or 0, "ledger manifest sync should stamp the protocol version")
assert.truthy(tostring((((publishedLedgerManifest.payload or {}).manifest or {}).globalHash) or "") ~= "", "ledger manifest sync should include a global hash")
local ledgerDiagnostics = scanner.GetLedgerDiagnostics()
assert.equal("event", tostring((ledgerDiagnostics or {}).finalizeMode or ""), "ledger scan should record event debounce finalization")
assert.equal((tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1, tonumber((ledgerDiagnostics or {}).moneyQueryId or 0) or 0, "ledger scan should expose the fixed money-log query id in diagnostics")

queriedLogs = {}
assert.truthy(not scanner.BeginLedgerScan(), "ledger scan should throttle inside the configured interval")
assert.equal(0, #queriedLogs, "throttled ledger scans should not query any logs")

current_db().bankLedger.lastScanAt = 0
local autoPublishCountBeforeNoChangeRepeat = #(outboundLedgerSyncMessages or {})
assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "forced ledger scan should still run when we want to verify no-change publish suppression")
run_all_pending()
assert.equal(autoPublishCountBeforeNoChangeRepeat, #(outboundLedgerSyncMessages or {}), "re-reading the same visible ledger windows should not auto-publish duplicate no-op ledger manifests")
transport.Send = originalTransportSend

local manualLedgerStartCalls = 0
scanner.BeginLedgerScan = function(options)
    manualLedgerStartCalls = manualLedgerStartCalls + 1
    assert.truthy(options and options.force == true, "plain manual inventory scans should force the queued ledger follow-up even when the ledger interval gate is closed")
    return true
end
local originalQueryGuildBankTab = _G.QueryGuildBankTab
local originalGetGuildBankItemInfo = _G.GetGuildBankItemInfo
local originalGetGuildBankItemLink = _G.GetGuildBankItemLink

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
current_db().meta.updatedAt = 0
current_db().bankLedger.lastScanAt = 1716577200
current_db().ui.logsHistorySettings.ledgerScanIntervalSeconds = 3600
_G.GetNumGuildBankTabs = function()
    return 1
end
_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end
_G.QueryGuildBankTab = nil
_G.GetGuildBankItemInfo = function()
    return nil, 0
end
_G.GetGuildBankItemLink = function()
    return nil
end

assert.truthy(scanner.BeginScan(), "plain manual scan should start even when the ledger interval gate is closed")
assert.equal(1, manualLedgerStartCalls, "plain manual inventory scans should still hand off into a ledger scan")

local closedInventoryLedgerStartCalls = 0
scanner.BeginLedgerScan = function()
    closedInventoryLedgerStartCalls = closedInventoryLedgerStartCalls + 1
    return true
end

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
current_db().meta.updatedAt = 0
current_db().bankLedger.lastScanAt = 0
current_db().ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.QueryGuildBankTab = function()
    return true
end
_G.GetGuildBankItemInfo = function()
    return nil, 0
end
_G.GetGuildBankItemLink = function()
    return nil
end
_G.GetNumGuildBankTabs = function()
    return 1
end
_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

assert.truthy(scanner.BeginScan(), "manual inventory scan should start for the mid-close cancellation case")
assert.truthy(scanner.scanInProgress == true, "inventory scan should be in flight before the guild bank closes")
if type(scanner.OnGuildBankClosed) == "function" then
    scanner.OnGuildBankClosed()
end
assert.truthy(scanner.scanInProgress ~= true, "closing the guild bank should cancel any in-flight inventory scan")
assert.truthy(scanner.waitingForTab == nil, "closing the guild bank should clear the active inventory-tab wait state")
assert.equal(0, tonumber((_G.GBankManagerDB.meta or {}).updatedAt or 0) or 0, "closing the guild bank mid-inventory-scan should not mutate snapshot freshness")
local closedSnapshot, closedChanges = scanner.FinishScan("OfficerOne", "Guild Testers")
assert.equal(nil, closedSnapshot, "cancelled inventory scans should not materialize a snapshot after close")
assert.equal(0, #(closedChanges or {}), "cancelled inventory scans should not emit change records after close")
assert.equal(0, closedInventoryLedgerStartCalls, "closing the guild bank mid-inventory-scan should not start a ledger follow-up")
_G.QueryGuildBankTab = originalQueryGuildBankTab
_G.GetGuildBankItemInfo = originalGetGuildBankItemInfo
_G.GetGuildBankItemLink = originalGetGuildBankItemLink

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

local rejectedAutoLedgerStartCalls = 0
scanner.BeginLedgerScan = function(options)
    rejectedAutoLedgerStartCalls = rejectedAutoLedgerStartCalls + 1
    assert.truthy(options and options.force ~= true, "rejected bank-open auto scans should preserve the normal stale-ledger handoff options")
    return true
end

local partialAutoDb = store.CreateFreshDatabase("Guild Testers")
partialAutoDb.snapshots = {
    stable = {
        scanId = "stable",
        scannedAt = 1716577200,
        items = {
            [211878] = { itemID = 211878, name = "Flask of Tempered Swiftness", totalCount = 12, tabs = { Flasks = 12 } },
        },
        itemRows = {
            { itemID = 211878, name = "Flask of Tempered Swiftness", tabName = "Flasks", quantity = 12 },
        },
    },
}
partialAutoDb.currentSnapshotId = "stable"
partialAutoDb.bankLedger.lastScanAt = 0
partialAutoDb.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB = partialAutoDb
ns.state.db = partialAutoDb

scanner.pendingLedgerScanAfterInventory = true
scanner.pendingLedgerScanOptions = {
    force = false,
}
scanner.scanInProgress = true
scanner.inventoryScanAuto = true
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        scanSource = "timeout",
        slots = {},
    },
}

local rejectedAutoSnapshot = scanner.FinishScan("OfficerOne", "Guild Testers")
assert.equal(nil, rejectedAutoSnapshot, "partial bank-open auto scans should still be rejected before replacing the snapshot")
assert.equal(1, rejectedAutoLedgerStartCalls, "rejecting a partial bank-open auto scan should not squash the queued ledger scan")
assert.truthy(scanner.pendingLedgerScanAfterInventory ~= true, "rejected partial auto scans should clear the queued ledger handoff after attempting it")
assert.truthy(scanner.pendingLedgerScanOptions == nil, "rejected partial auto scans should clear queued ledger options after attempting the handoff")

local closedLedgerStartCalls = 0
scanner.BeginLedgerScan = function()
    closedLedgerStartCalls = closedLedgerStartCalls + 1
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

if type(scanner.OnGuildBankClosed) == "function" then
    scanner.OnGuildBankClosed()
end

scanner.FinishScan("OfficerOne", "Guild Testers")
assert.equal(0, closedLedgerStartCalls, "closing the guild bank should clear the queued inventory-to-ledger handoff before the inventory scan finishes")
assert.truthy(scanner.pendingLedgerScanAfterInventory ~= true, "closing the guild bank should clear the queued ledger handoff flag")
assert.truthy(scanner.pendingLedgerScanOptions == nil, "closing the guild bank should clear any queued ledger handoff options")

scanner.BeginLedgerScan = originalBeginLedgerScan
_G.GBankManagerDB.bankLedger.lastScanAt = 1716577800
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 3600
scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
_G.C_Timer.ClearPending()
queriedLogs = {}
assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "forced ledger scans should bypass the normal ledger scan throttle")
assert.equal(1, queriedLogs[1], "forced ledger scans should still query the first item-log tab")
run_all_pending()
assert.equal(9, queriedLogs[#queriedLogs], "forced ledger scans should still query the fixed money-log slot")

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
    elseif queryId == 9 then
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

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

ns.modules.bankLedger.MergeItemTransactions(_G.GBankManagerDB, {
    scanStartedAt = 1716579000,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "OfficerOne-Stormrage",
            itemID = 310001,
            itemName = "Older Ledger Flask",
            quantity = 4,
            year = 2026,
            month = 5,
            day = 24,
            hour = 8,
        },
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            itemID = 310002,
            itemName = "Older Ledger Potion",
            quantity = 2,
            year = 2026,
            month = 5,
            day = 24,
            hour = 7,
        },
    },
})

ns.modules.bankLedger.MergeMoneyTransactions(_G.GBankManagerDB, {
    scanStartedAt = 1716579000,
    transactions = {
        {
            type = "deposit",
            who = "OfficerOne-Stormrage",
            amount = 100000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 8,
        },
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            amount = 200000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 7,
        },
    },
})

local rotatedScannerItemRows = {
    {
        type = "deposit",
        who = "GuildLead-Stormrage",
        itemLink = "item:310003:0:0:0",
        count = 8,
        year = 2026,
        month = 5,
        day = 24,
        hour = 10,
    },
    {
        type = "withdraw",
        who = "RaiderOne-Stormrage",
        itemLink = "item:310004:0:0:0",
        count = 3,
        year = 2026,
        month = 5,
        day = 24,
        hour = 9,
    },
}
local rotatedScannerMoneyRows = {
    {
        type = "deposit",
        who = "GuildLead-Stormrage",
        amount = 300000000,
        year = 2026,
        month = 5,
        day = 24,
        hour = 10,
    },
    {
        type = "withdraw",
        who = "RaiderOne-Stormrage",
        amount = 400000000,
        year = 2026,
        month = 5,
        day = 24,
        hour = 9,
    },
}

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex == 1 then
        return #rotatedScannerItemRows
    end
    return 0
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    local row = tabIndex == 1 and rotatedScannerItemRows[index] or nil
    if not row then
        return nil
    end
    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #rotatedScannerMoneyRows
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = rotatedScannerMoneyRows[index]
    if not row then
        return nil
    end
    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.time = function()
    return 1716580300
end

scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
scanner.ledgerWaitingTarget = nil
_G.C_Timer.ClearPending()

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start for a fully rotated live item and money log window")
run_all_pending(10)
assert.equal(4, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "scanner-driven item log reads should append a fully rotated visible window instead of leaving the item log stuck")
assert.equal(4, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "scanner-driven money log reads should append a fully rotated visible window instead of leaving the money log stuck")
assert.equal("Guild bank ledger scan finished (2 item rows, 2 money rows).", scanner:GetStatusText(), "fully rotated live ledger windows should report the appended item and money rows")

_G.time = function()
    return 1716580000
end

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0
_G.currentGuildBankTab = 1
_G.SetCurrentGuildBankTabCalls = {}

local emptyOffscreenTransactions = {
    [1] = {},
    [2] = {},
    [3] = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemLink = "item:210000:0:0:0",
            count = 4,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
}

_G.GetNumGuildBankTabs = function()
    return 3
end

_G.GetGuildBankTabInfo = function(tabIndex)
    if tabIndex == 1 then
        return "Flasks", nil, true
    end
    if tabIndex == 2 then
        return "Empty Alt", nil, true
    end
    if tabIndex == 3 then
        return "Raid", nil, true
    end
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    return #(emptyOffscreenTransactions[tonumber(tabIndex) or 0] or {})
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    local row = (emptyOffscreenTransactions[tonumber(tabIndex) or 0] or {})[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return 0
end

_G.GetGuildBankMoneyTransaction = function()
    return nil
end

queriedLogs = {}
_G.QueryGuildBankLog = function(queryId)
    table.insert(queriedLogs, queryId)
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start when the visible item-log tab is empty and an off-screen tab has rows")
run_all_pending(20)
assert.equal(1, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "ledger scan should still complete when the visible tab is empty and another queried tab has rows")
assert.equal(210000, _G.GBankManagerDB.bankLedger.itemLogs[1].itemID, "ledger scan should still import the readable off-screen tab while treating empty queried tabs as settled")
assert.equal(1716580000, tonumber(_G.GBankManagerDB.bankLedger.lastScanAt or 0) or 0, "ledger scan should still advance freshness after empty queried tabs settle successfully")

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

local delayedMoneyTransactions = {}
local delayedMoneyQueryId = 0
local originalDelayedMoneyRunPending = _G.C_Timer.RunPending
_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function()
    return 0
end

_G.GetGuildBankTransaction = function()
    return nil
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #delayedMoneyTransactions
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = delayedMoneyTransactions[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.QueryGuildBankLog = function(queryId)
    delayedMoneyQueryId = queryId
    if queryId ~= 9 then
        return
    end

    _G.C_Timer.After(0.1, function()
        _G.C_Timer.After(0.1, function()
            delayedMoneyTransactions = {
                {
                    type = "repair",
                    who = "RepairDruid-Stormrage",
                    amount = 12345600,
                    year = 2026,
                    month = 5,
                    day = 24,
                    hour = 12,
                },
                {
                    type = "deposit",
                    who = "GuildLead-Stormrage",
                    amount = 250000000,
                    year = 2026,
                    month = 5,
                    day = 24,
                    hour = 11,
                },
            }
            scanner.OnGuildBankLogUpdated()
        end)
    end)
end

_G.C_Timer.RunPending = function()
    local pending = _G.C_Timer.pending or {}
    if #pending == 0 then
        return
    end

    local nextDelay = nil
    for _, entry in ipairs(pending) do
        local delaySeconds = tonumber((entry or {}).delaySeconds) or 0
        if nextDelay == nil or delaySeconds < nextDelay then
            nextDelay = delaySeconds
        end
    end

    local remaining = {}
    _G.C_Timer.pending = remaining
    for _, entry in ipairs(pending) do
        local delaySeconds = tonumber((entry or {}).delaySeconds) or 0
        if delaySeconds ~= nextDelay then
            remaining[#remaining + 1] = entry
        elseif type(entry.callback) == "function" then
            entry.callback()
        end
    end
end

_G.time = function()
    return 1716581000
end

scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
scanner.ledgerWaitingTarget = nil
_G.C_Timer.ClearPending()

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start when the money log arrives on a later guild-bank-log update")
run_all_pending(10)
assert.equal(9, delayedMoneyQueryId, "the delayed ledger case should still query the fixed money-log slot")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "ledger scan should merge money rows that only become available after GUILDBANKLOG_UPDATE")
assert.equal("Guild bank ledger scan finished (0 item rows, 2 money rows).", scanner:GetStatusText(), "ledger scan should wait long enough to report the delayed money-log rows")
_G.C_Timer.RunPending = originalDelayedMoneyRunPending

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

local earlyEventMoneyTransactions = {}
local earlyEventMoneyQueryId = 0
local earlyEventPass = 0
local originalRunPending = _G.C_Timer.RunPending
_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function()
    return 0
end

_G.GetGuildBankTransaction = function()
    return nil
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #earlyEventMoneyTransactions
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = earlyEventMoneyTransactions[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.QueryGuildBankLog = function(queryId)
    earlyEventMoneyQueryId = queryId
    if queryId ~= 9 then
        return
    end

    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

_G.C_Timer.RunPending = function()
    local pending = _G.C_Timer.pending or {}
    _G.C_Timer.pending = {}
    earlyEventPass = earlyEventPass + 1
    for _, entry in ipairs(pending) do
        if type(entry.callback) == "function" then
            entry.callback()
        end
    end
    if earlyEventPass == 3 then
        earlyEventMoneyTransactions = {
            {
                type = "repair",
                who = "RepairDruid-Stormrage",
                amount = 65432100,
                year = 2026,
                month = 5,
                day = 24,
                hour = 13,
            },
        }
    end
end

_G.time = function()
    return 1716581600
end

scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
scanner.ledgerWaitingTarget = nil
_G.C_Timer.ClearPending()

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start when guild-bank-log update fires before the money log is readable")
run_all_pending(10)
assert.equal(9, earlyEventMoneyQueryId, "the early-event case should still query the fixed money-log slot")
assert.equal(1, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "ledger scan should keep debouncing long enough to import rows that appear after an early guild-bank-log update")
assert.equal("Guild bank ledger scan finished (0 item rows, 1 money rows).", scanner:GetStatusText(), "ledger scan should finalize through the shared debounced path after late money rows settle")
_G.C_Timer.RunPending = originalRunPending

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

local fallbackDrivenMoneyTransactions = {}
local capturedLedgerCallbacks = {}
local originalTimerAfter = _G.C_Timer.After
_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function()
    return 0
end

_G.GetGuildBankTransaction = function()
    return nil
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #fallbackDrivenMoneyTransactions
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = fallbackDrivenMoneyTransactions[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.C_Timer.After = function(delaySeconds, callback)
    capturedLedgerCallbacks[#capturedLedgerCallbacks + 1] = {
        delaySeconds = delaySeconds,
        callback = callback,
    }
    return #capturedLedgerCallbacks
end

_G.QueryGuildBankLog = function(queryId)
    if queryId ~= 9 then
        return
    end

    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

_G.time = function()
    return 1716581900
end

scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}

assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start for the hard-fallback ownership regression")
assert.equal(2, #capturedLedgerCallbacks, "ledger scan should arm both the initial batch signal and the hard fallback")
capturedLedgerCallbacks[1].callback()
assert.equal(3, #capturedLedgerCallbacks, "guild-bank-log update should schedule a debounced settle callback")
capturedLedgerCallbacks[2].callback()
assert.equal(0, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "hard fallback should not finalize early once a newer settle pass has already been scheduled")
fallbackDrivenMoneyTransactions = {
    {
        type = "repair",
        who = "RepairDruid-Stormrage",
        amount = 7770000,
        year = 2026,
        month = 5,
        day = 24,
        hour = 13,
    },
}
capturedLedgerCallbacks[3].callback()
capturedLedgerCallbacks[4].callback()
capturedLedgerCallbacks[5].callback()
assert.equal(1, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "the later debounced settle path should still import rows after the hard fallback yields")
assert.equal("Guild bank ledger scan finished (0 item rows, 1 money rows).", scanner:GetStatusText(), "the yielded hard fallback case should still finish through the shared debounce path")
_G.C_Timer.After = originalTimerAfter

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
_G.GBankManagerDB.bankLedger.lastScanAt = 0

local closeCancelTransactions = {
    item = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemLink = "item:211878:0:0:0",
            count = 8,
            year = 2026,
            month = 5,
            day = 24,
            hour = 14,
        },
    },
    money = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 123000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 14,
        },
    },
}

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex ~= 1 then
        return 0
    end

    return #(closeCancelTransactions.item or {})
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    local row = tabIndex == 1 and (closeCancelTransactions.item or {})[index] or nil
    if not row then
        return nil
    end

    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #(closeCancelTransactions.money or {})
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = (closeCancelTransactions.money or {})[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.QueryGuildBankLog = function()
    return true
end

_G.time = function()
    return 1716582200
end

scanner.guildBankOpen = true
scanner.ledgerScanInProgress = false
scanner.ledgerTargets = {}
_G.C_Timer.ClearPending()
assert.truthy(scanner.BeginLedgerScan({
    force = true,
}), "ledger scan should start before a guild-bank close cancellation test")
assert.truthy(scanner.ledgerScanInProgress == true, "ledger scan should be active before the guild bank is closed")
scanner.OnGuildBankClosed()
closeCancelTransactions.item = {}
closeCancelTransactions.money = {}
run_all_pending(10)
assert.truthy(scanner.ledgerScanInProgress ~= true, "closing the guild bank should cancel any in-flight ledger scan")
assert.equal(0, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "closing the guild bank should prevent cancelled item-log scans from importing rows afterward")
assert.equal(0, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "closing the guild bank should prevent cancelled money-log scans from importing rows afterward")
assert.equal(0, tonumber(_G.GBankManagerDB.bankLedger.lastScanAt or 0) or 0, "closing the guild bank should not advance ledger freshness for a cancelled scan")

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716582400
_G.GBankManagerDB.bankLedger.lastScanAt = 1716582400
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

local passiveTabsReady = false
local passiveNoTabsQueryIds = {}
local passiveNoTabsTransactions = {
    {
        type = "deposit",
        who = "GuildLead-Stormrage",
        itemLink = "item:211878:0:0:0",
        count = 6,
        year = 2026,
        month = 5,
        day = 24,
        hour = 15,
    },
}

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    if passiveTabsReady == true then
        return "Flasks", nil, true
    end
    return "Flasks", nil, false
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if passiveTabsReady ~= true or tabIndex ~= 1 then
        return 0
    end

    return #passiveNoTabsTransactions
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    if passiveTabsReady ~= true or tabIndex ~= 1 then
        return nil
    end

    local row = passiveNoTabsTransactions[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return 0
end

_G.GetGuildBankMoneyTransaction = function()
    return nil
end

_G.QueryGuildBankLog = function(queryId)
    passiveNoTabsQueryIds[#passiveNoTabsQueryIds + 1] = queryId
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

scanner.guildBankOpen = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
_G.C_Timer.ClearPending()
scanner.OnGuildBankOpened()
_G.C_Timer.RunPending()
assert.equal(0, #passiveNoTabsQueryIds, "passive refresh should skip ledger queries while no guild-bank tabs are yet viewable")
assert.equal(1716582400, tonumber(_G.GBankManagerDB.bankLedger.lastScanAt or 0) or 0, "passive refresh should not advance ledger freshness from a premature money-only scan")
assert.equal(0, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "passive refresh should not import ledger rows before any item-log tabs are accessible")
passiveTabsReady = true
run_all_pending(20)
assert.truthy(#passiveNoTabsQueryIds >= 2, "once tabs become viewable, the later passive refresh should issue a real ledger query batch")
assert.equal(1, passiveNoTabsQueryIds[1], "once tabs become viewable, the first real passive batch should query the item log")
assert.equal(9, passiveNoTabsQueryIds[2], "once tabs become viewable, the first real passive batch should also query the money log")
assert.equal(1, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "the later passive refresh should import ledger rows once guild-bank tabs are accessible")
assert.equal(1716582400, tonumber(_G.GBankManagerDB.bankLedger.lastScanAt or 0) or 0, "the later passive refresh should stamp freshness with the real settled scan time")
scanner.OnGuildBankClosed()

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716582980
_G.GBankManagerDB.bankLedger.lastScanAt = 1716582000
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

local staleOpenTabsReady = false
local staleOpenQueryIds = {}

_G.time = function()
    return 1716583000
end

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    if staleOpenTabsReady == true then
        return "Flasks", nil, true
    end
    return "Flasks", nil, false
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if staleOpenTabsReady ~= true or tabIndex ~= 1 then
        return 0
    end

    return 1
end

_G.GetGuildBankTransaction = function(tabIndex)
    if staleOpenTabsReady ~= true or tabIndex ~= 1 then
        return nil
    end

    return "deposit", "GuildLead-Stormrage", "item:211878:0:0:0", 4, nil, nil, 2026, 5, 24, 15
end

_G.GetNumGuildBankMoneyTransactions = function()
    return 0
end

_G.GetGuildBankMoneyTransaction = function()
    return nil
end

_G.QueryGuildBankLog = function(queryId)
    staleOpenQueryIds[#staleOpenQueryIds + 1] = queryId
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

scanner.guildBankOpen = false
scanner.pendingLedgerAutoScan = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
_G.C_Timer.ClearPending()
scanner.OnGuildBankOpened()
_G.C_Timer.RunPending()
assert.equal(0, #staleOpenQueryIds, "opening the guild bank with stale ledger data should not issue an early no-tab ledger scan before the tabs become viewable")
assert.equal(1716582000, tonumber(_G.GBankManagerDB.bankLedger.lastScanAt or 0) or 0, "opening the guild bank before tabs are ready should not advance ledger freshness")
assert.truthy(scanner.pendingLedgerAutoScan == true, "opening the guild bank with stale ledger data should keep the pending ledger scan armed until tabs are ready")
staleOpenTabsReady = true
scanner.OnGuildBankTabsUpdated()
run_all_pending(20)
assert.truthy(#staleOpenQueryIds >= 2, "once tabs become viewable, the deferred stale-open ledger scan should issue a real item and money log query batch")
assert.equal(1, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "once tabs become viewable, the deferred stale-open ledger scan should import the newly available item log row")
scanner.OnGuildBankClosed()

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716582995
_G.GBankManagerDB.bankLedger.lastScanAt = 1716582995
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

local passivePhase = 1
local passiveItemLogs = {
    [1] = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemLink = "item:211878:0:0:0",
            count = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
    [2] = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemLink = "item:211878:0:0:0",
            count = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
    [3] = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemLink = "item:210000:0:0:0",
            count = 2,
            year = 2026,
            month = 5,
            day = 24,
            hour = 16,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemLink = "item:211878:0:0:0",
            count = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
}
local passiveMoneyLogs = {
    [1] = {},
    [2] = {},
    [3] = {},
}
local passiveQueryCount = 0
local originalPassiveRunPending = _G.C_Timer.RunPending
local passiveAdvancedToPhaseTwo = false
local passiveAdvancedToPhaseThree = false
local passiveClosedAfterImports = false

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex ~= 1 then
        return 0
    end

    return #(passiveItemLogs[passivePhase] or {})
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    local row = tabIndex == 1 and (passiveItemLogs[passivePhase] or {})[index] or nil
    if not row then
        return nil
    end

    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #(passiveMoneyLogs[passivePhase] or {})
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = (passiveMoneyLogs[passivePhase] or {})[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.QueryGuildBankLog = function(queryId)
    passiveQueryCount = passiveQueryCount + 1
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

_G.C_Timer.RunPending = function()
    originalPassiveRunPending()
    local itemLogCount = #(_G.GBankManagerDB.bankLedger.itemLogs or {})
    if passiveAdvancedToPhaseTwo ~= true and itemLogCount == 1 then
        assert.equal(1, itemLogCount, "passive refresh should import the first available ledger row while the bank remains open")
        passivePhase = 2
        passiveAdvancedToPhaseTwo = true
    elseif passiveAdvancedToPhaseTwo == true and passiveAdvancedToPhaseThree ~= true and passiveQueryCount >= 4 and itemLogCount == 1 then
        assert.equal(1, itemLogCount, "repeated passive refreshes should not duplicate ledger rows that were already imported")
        passivePhase = 3
        passiveAdvancedToPhaseThree = true
    elseif passiveAdvancedToPhaseThree == true and passiveClosedAfterImports ~= true and itemLogCount == 2 and type(scanner.OnGuildBankClosed) == "function" then
        scanner.OnGuildBankClosed()
        passiveClosedAfterImports = true
    end
end

scanner.guildBankOpen = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
_G.C_Timer.ClearPending()
scanner.OnGuildBankOpened()
run_all_pending(60)
assert.truthy(passiveAdvancedToPhaseTwo == true, "passive refresh test harness should observe the first passive import before advancing phases")
assert.truthy(passiveAdvancedToPhaseThree == true, "passive refresh test harness should advance into the new-row passive phase")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.itemLogs or {}), "passive refresh should import newly available ledger rows without requiring a manual rescan")
assert.truthy(passiveQueryCount >= 4, "passive refresh should continue polling while the bank stays open across repeated end-to-end ledger scans")
local passiveQueryCountAfterClose = passiveQueryCount
run_all_pending(10)
assert.equal(passiveQueryCountAfterClose, passiveQueryCount, "passive refresh should stop scheduling additional ledger queries once the guild bank closes")
_G.C_Timer.RunPending = originalPassiveRunPending

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716583595
_G.GBankManagerDB.bankLedger.lastScanAt = 1716583595
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

local moneyPassivePhase = 1
local moneyPassiveItemLogs = {
    [1] = {},
    [2] = {},
    [3] = {},
}
local moneyPassiveLogs = {
    [1] = {
        {
            type = "repair",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
    },
    [2] = {
        {
            type = "repair",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
    },
    [3] = {
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            amount = 550000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
        {
            type = "repair",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
    },
}
local moneyPassiveQueryCount = 0
local originalMoneyPassiveRunPending = _G.C_Timer.RunPending
local moneyPassiveAdvancedToPhaseTwo = false
local moneyPassiveAdvancedToPhaseThree = false
local moneyPassiveClosedAfterImports = false

_G.GetNumGuildBankTabs = function()
    return 1
end

_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end

_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex ~= 1 then
        return 0
    end

    return #(moneyPassiveItemLogs[moneyPassivePhase] or {})
end

_G.GetGuildBankTransaction = function(tabIndex, index)
    local row = tabIndex == 1 and (moneyPassiveItemLogs[moneyPassivePhase] or {})[index] or nil
    if not row then
        return nil
    end

    return row.type, row.who, row.itemLink, row.count, nil, nil, row.year, row.month, row.day, row.hour
end

_G.GetNumGuildBankMoneyTransactions = function()
    return #(moneyPassiveLogs[moneyPassivePhase] or {})
end

_G.GetGuildBankMoneyTransaction = function(index)
    local row = (moneyPassiveLogs[moneyPassivePhase] or {})[index]
    if not row then
        return nil
    end

    return row.type, row.who, row.amount, row.year, row.month, row.day, row.hour
end

_G.QueryGuildBankLog = function(queryId)
    moneyPassiveQueryCount = moneyPassiveQueryCount + 1
    _G.C_Timer.After(0.1, function()
        scanner.OnGuildBankLogUpdated()
    end)
end

_G.C_Timer.RunPending = function()
    originalMoneyPassiveRunPending()
    local moneyLogCount = #(_G.GBankManagerDB.bankLedger.moneyLogs or {})
    if moneyPassiveAdvancedToPhaseTwo ~= true and moneyLogCount == 1 then
        moneyPassivePhase = 2
        moneyPassiveAdvancedToPhaseTwo = true
    elseif moneyPassiveAdvancedToPhaseTwo == true and moneyPassiveAdvancedToPhaseThree ~= true and moneyPassiveQueryCount >= 4 and moneyLogCount == 1 then
        moneyPassivePhase = 3
        moneyPassiveAdvancedToPhaseThree = true
    elseif moneyPassiveAdvancedToPhaseThree == true and moneyPassiveClosedAfterImports ~= true and moneyLogCount == 2 and type(scanner.OnGuildBankClosed) == "function" then
        scanner.OnGuildBankClosed()
        moneyPassiveClosedAfterImports = true
    end
end

scanner.guildBankOpen = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
_G.C_Timer.ClearPending()
scanner.OnGuildBankOpened()
run_all_pending(60)
assert.truthy(moneyPassiveAdvancedToPhaseTwo == true, "passive refresh should observe the baseline money-log import before advancing phases")
assert.truthy(moneyPassiveAdvancedToPhaseThree == true, "passive refresh should advance into the new-row money-log phase")
assert.equal(2, #(_G.GBankManagerDB.bankLedger.moneyLogs or {}), "passive refresh should import newly available money-log rows without requiring a manual rescan")
assert.truthy(moneyPassiveQueryCount >= 4, "passive refresh should continue polling while the bank stays open across money-log-only changes")
local moneyPassiveQueryCountAfterClose = moneyPassiveQueryCount
run_all_pending(10)
assert.equal(moneyPassiveQueryCountAfterClose, moneyPassiveQueryCount, "passive refresh should stop scheduling additional money-log polling once the guild bank closes")
_G.C_Timer.RunPending = originalMoneyPassiveRunPending

_G.C_PlayerInteractionManager = {
    IsInteractingWithNpcOfType = function(interactionType)
        return interactionType == 10
    end,
}
_G.Enum = {
    PlayerInteractionType = {
        GuildBanker = 10,
    },
}
_G.GBankManagerDB.meta.updatedAt = 1716582995
_G.GBankManagerDB.bankLedger.lastScanAt = 1716582995
scanner.guildBankOpen = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
_G.C_Timer.ClearPending()
assert.truthy(type(scanner.SyncGuildBankOpenState) == "function", "scanner should expose a guild-bank-open state sync helper for reload-safe passive refresh")
assert.truthy(scanner.SyncGuildBankOpenState() == true, "scanner should detect an already-open guild bank through the interaction API")
assert.truthy(scanner.guildBankOpen == true, "reload-safe guild-bank-open sync should restore the open state when the interaction is already active")
assert.truthy(#(_G.C_Timer.pending or {}) > 0, "reload-safe guild-bank-open sync should arm passive ledger refresh without requiring another manual scan")

local passiveEventScanCalls = {}
local originalPassiveEventBeginLedgerScan = scanner.BeginLedgerScan
scanner.BeginLedgerScan = function(options)
    passiveEventScanCalls[#passiveEventScanCalls + 1] = options or {}
    return true
end
scanner.guildBankOpen = true
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
scanner.OnGuildBankLogUpdated()
assert.equal(1, #passiveEventScanCalls, "live guild-bank log updates should trigger a passive ledger scan while the bank is open and idle")
assert.truthy(passiveEventScanCalls[1].force == true, "passive guild-bank log updates should force the follow-up ledger scan")
assert.truthy(passiveEventScanCalls[1].silent == true, "passive guild-bank log updates should keep the auto-refresh silent")
assert.truthy(passiveEventScanCalls[1].passive == true, "live guild-bank log updates should reuse the passive ledger scan path")
scanner.guildBankOpen = false
scanner.OnGuildBankLogUpdated()
assert.equal(1, #passiveEventScanCalls, "guild-bank log updates should not trigger passive scans after the bank closes")
scanner.BeginLedgerScan = originalPassiveEventBeginLedgerScan

local midInventoryLedgerCalls = 0
local originalMidInventoryBeginLedgerScan = scanner.BeginLedgerScan
scanner.BeginLedgerScan = function()
    midInventoryLedgerCalls = midInventoryLedgerCalls + 1
    return true
end
_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716582995
_G.GBankManagerDB.bankLedger.lastScanAt = 1716582995
scanner.guildBankOpen = true
scanner.scanInProgress = true
scanner.ledgerScanInProgress = false
scanner.pendingLedgerAutoScan = true
scanner.OnGuildBankTabsUpdated()
assert.equal(0, midInventoryLedgerCalls, "guild-bank tab updates should not start the pending ledger scan while the main bank scan is still running")
scanner.scanInProgress = false
scanner.OnGuildBankTabsUpdated()
assert.equal(1, midInventoryLedgerCalls, "the pending ledger scan should start once the main bank scan is no longer running")
scanner.BeginLedgerScan = originalMidInventoryBeginLedgerScan

local passiveChainStartCalls = 0
local passiveChainTimerDelays = {}
local originalPassiveChainBeginLedgerScan = scanner.BeginLedgerScan
local originalPassiveChainTimerAfter = _G.C_Timer.After
scanner.BeginLedgerScan = function(options)
    passiveChainStartCalls = passiveChainStartCalls + 1
    scanner.ledgerScanInProgress = true
    return true
end
_G.C_Timer.After = function(delaySeconds, callback)
    passiveChainTimerDelays[#passiveChainTimerDelays + 1] = delaySeconds
    if #passiveChainTimerDelays == 1 and type(callback) == "function" then
        callback()
    end
end
scanner.guildBankOpen = true
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0
scanner.SyncGuildBankOpenState()
assert.equal(1, passiveChainStartCalls, "passive refresh should start one ledger scan when its cadence fires")
assert.equal(1, #passiveChainTimerDelays, "passive refresh should not arm the next cadence timer until the active ledger scan finishes")
scanner.BeginLedgerScan = originalPassiveChainBeginLedgerScan
_G.C_Timer.After = originalPassiveChainTimerAfter
scanner.ledgerScanInProgress = false
scanner.passiveLedgerRefreshActive = false

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.GBankManagerDB.meta.updatedAt = 1716583600
_G.GBankManagerDB.bankLedger.lastScanAt = 1716583600
_G.GBankManagerDB.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300

local deferredDirectLedgerQueryIds = {}
_G.GetNumGuildBankTabs = function()
    return 1
end
_G.GetGuildBankTabInfo = function()
    return "Flasks", nil, true
end
_G.QueryGuildBankLog = function(queryId)
    deferredDirectLedgerQueryIds[#deferredDirectLedgerQueryIds + 1] = queryId
end

scanner.guildBankOpen = true
scanner.scanInProgress = true
scanner.ledgerScanInProgress = false
scanner.pendingLedgerScanAfterInventory = false
scanner.pendingLedgerScanOptions = nil
scanner.ledgerTargets = {}
assert.truthy(scanner.BeginLedgerScan({
    force = true,
    silent = true,
    passive = true,
}) == true, "ledger requests made during inventory scans should be accepted for deferred handoff")
assert.equal(0, #deferredDirectLedgerQueryIds, "direct ledger requests should not query Blizzard logs while the inventory scan is still running")
assert.truthy(scanner.ledgerScanInProgress ~= true, "direct ledger requests should not mark the ledger scan active while inventory is still scanning")
assert.truthy(scanner.pendingLedgerScanAfterInventory == true, "direct ledger requests during inventory scans should queue the inventory-to-ledger handoff")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.force == true, "deferred direct ledger requests should preserve force semantics")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.silent == true, "deferred direct ledger requests should preserve silent semantics")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.passive == true, "deferred direct ledger requests should preserve passive semantics")

scanner.pendingLedgerScanAfterInventory = true
scanner.pendingLedgerScanOptions = {
    force = true,
    silent = false,
    passive = false,
}
scanner.BeginLedgerScan({
    force = true,
    silent = true,
    passive = true,
})
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.force == true, "a later passive ledger request should not remove the already queued forced follow-up")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.silent ~= true, "a later passive ledger request should not turn a visible manual follow-up into a silent scan")
assert.truthy(scanner.pendingLedgerScanOptions and scanner.pendingLedgerScanOptions.passive ~= true, "a later passive ledger request should not turn a manual follow-up into a passive-only scan")

local scannerEvents = ns.modules.guildBankScannerEvents
local interactionOpens = 0
local interactionCloses = 0
local originalOnGuildBankOpened = scanner.OnGuildBankOpened
local originalOnGuildBankClosed = scanner.OnGuildBankClosed
scanner.OnGuildBankOpened = function(...)
    interactionOpens = interactionOpens + 1
    if originalOnGuildBankOpened then
        return originalOnGuildBankOpened(...)
    end
end
scanner.OnGuildBankClosed = function(...)
    interactionCloses = interactionCloses + 1
    if originalOnGuildBankClosed then
        return originalOnGuildBankClosed(...)
    end
end
local registeredEvents = scannerEvents.GetRegisteredEvents()
local hasInteractionShow = false
local hasInteractionHide = false
for _, eventName in ipairs(registeredEvents or {}) do
    if eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        hasInteractionShow = true
    elseif eventName == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        hasInteractionHide = true
    end
end
assert.truthy(hasInteractionShow == true, "scanner events should register the player-interaction show event for reliable guild-bank open detection")
assert.truthy(hasInteractionHide == true, "scanner events should register the player-interaction hide event for reliable guild-bank close detection")
scanner.guildBankOpen = false
scannerEvents.HandleEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", _G.Enum.PlayerInteractionType.GuildBanker)
scannerEvents.HandleEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", _G.Enum.PlayerInteractionType.GuildBanker)
assert.equal(1, interactionOpens, "scanner events should route guild-bank interaction shows through the shared open handler")
assert.equal(1, interactionCloses, "scanner events should route guild-bank interaction hides through the shared close handler")
scanner.OnGuildBankOpened = originalOnGuildBankOpened
scanner.OnGuildBankClosed = originalOnGuildBankClosed
