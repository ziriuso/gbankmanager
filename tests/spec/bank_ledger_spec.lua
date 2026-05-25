local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local bankLedger = dofile("GBankManager/Domain/BankLedger.lua")
local defaults = dofile("GBankManager/Data/Defaults.lua")
local migrations = dofile("GBankManager/Data/Migrations.lua")

local function fresh_db()
    return migrations.Apply(defaults.CreateDatabase("Guild Testers"))
end

local db = fresh_db()

assert.truthy(type(db.bankLedger) == "table", "database defaults should include a bank-ledger container")
assert.truthy(type(db.ui.logsHistorySettings) == "table", "database defaults should include logs/history settings")
assert.equal("indefinite", db.ui.logsHistorySettings.ledgerRetention, "ledger retention should default to indefinite to avoid surprise data loss")
assert.equal("indefinite", db.ui.logsHistorySettings.historyRetention, "history retention should default to indefinite to avoid surprise data loss")
assert.equal(300, db.ui.logsHistorySettings.ledgerScanIntervalSeconds, "ledger scan interval should default to five minutes")

local mergedItemCount = bankLedger.MergeItemTransactions(db, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "move",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 4,
            fromTabName = "Raid",
            year = 2024,
            month = 5,
            day = 24,
            hour = 8,
        },
    },
})

assert.equal(2, mergedItemCount, "ledger item merge should add unseen transactions")
assert.equal(2, #db.bankLedger.itemLogs, "ledger item merge should persist item log rows")
assert.equal("Deposit", db.bankLedger.itemLogs[1].action, "ledger item rows should humanize deposit actions")
assert.equal("Moved", db.bankLedger.itemLogs[2].action, "ledger item rows should humanize move actions")
assert.equal("Raid", db.bankLedger.itemLogs[2].fromTabName, "ledger move rows should keep the origin tab")

local duplicateItemCount = bankLedger.MergeItemTransactions(db, {
    scanStartedAt = 1716573900,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})

assert.equal(0, duplicateItemCount, "ledger item merge should skip duplicate transactions during later scans")
assert.equal(2, #db.bankLedger.itemLogs, "ledger item merge should stay append-only when no deltas appear")

local repeatedVisibleScanCount = bankLedger.MergeItemTransactions(db, {
    scanStartedAt = 1716574200,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "move",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 4,
            fromTabName = "Raid",
            year = 2024,
            month = 5,
            day = 24,
            hour = 8,
        },
    },
})

assert.equal(0, repeatedVisibleScanCount, "re-reading the same visible item-log window should not append duplicate rows")
assert.equal(2, #db.bankLedger.itemLogs, "re-reading the same visible item-log window should leave stored rows unchanged")

local identicalLeadingItemCount = bankLedger.MergeItemTransactions(db, {
    scanStartedAt = 1716574500,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "move",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 4,
            fromTabName = "Raid",
            year = 2024,
            month = 5,
            day = 24,
            hour = 8,
        },
    },
})

assert.equal(1, identicalLeadingItemCount, "a newly added log row should still append even if it matches an older row exactly")
assert.equal(3, #db.bankLedger.itemLogs, "item ledger merges should append only the unseen leading delta rows")

local mergedMoneyCount = bankLedger.MergeMoneyTransactions(db, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "RepairDruid-Stormrage",
            amount = 1234.56 * 10000,
            year = 2024,
            month = 5,
            day = 24,
            hour = 7,
        },
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            amount = 10000 * 10000,
            year = 2024,
            month = 5,
            day = 24,
            hour = 6,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 50000 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 5,
        },
    },
})

assert.equal(3, mergedMoneyCount, "ledger money merge should add unseen money-log rows")
assert.equal("Repair", db.bankLedger.moneyLogs[1].action, "small non-round withdrawals should classify as repairs")
assert.equal("Withdrawal", db.bankLedger.moneyLogs[2].action, "large withdrawals should stay normal withdrawals")
assert.equal("Deposit", db.bankLedger.moneyLogs[3].action, "deposits should stay deposits")

local repeatedVisibleMoneyCount = bankLedger.MergeMoneyTransactions(db, {
    scanStartedAt = 1716573900,
    transactions = {
        {
            type = "withdraw",
            who = "RepairDruid-Stormrage",
            amount = 1234.56 * 10000,
            year = 2024,
            month = 5,
            day = 24,
            hour = 7,
        },
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            amount = 10000 * 10000,
            year = 2024,
            month = 5,
            day = 24,
            hour = 6,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 50000 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 5,
        },
    },
})

assert.equal(0, repeatedVisibleMoneyCount, "re-reading the same visible money-log window should not append duplicate rows")
assert.equal(3, #db.bankLedger.moneyLogs, "re-reading the same visible money-log window should leave stored money rows unchanged")

local oldestFirstMoneyDb = fresh_db()
local oldestFirstInitialCount = bankLedger.MergeMoneyTransactions(oldestFirstMoneyDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 100000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 8,
        },
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 110000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 120000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 10,
        },
    },
})
assert.equal(3, oldestFirstInitialCount, "the first oldest-first money-log window should import every visible row")

local oldestFirstNextWindowCount = bankLedger.MergeMoneyTransactions(oldestFirstMoneyDb, {
    scanStartedAt = 1716574200,
    transactions = {
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 110000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 120000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 10,
        },
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 130000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 11,
        },
    },
})
assert.equal(1, oldestFirstNextWindowCount, "a slid-forward oldest-first money-log window should append only the newest trailing row")
assert.equal(4, #oldestFirstMoneyDb.bankLedger.moneyLogs, "oldest-first money-log windows should stay append-only without duplicating overlapping rows")

local singleWindowDb = fresh_db()
local singleWindowInitialCount = bankLedger.MergeItemTransactions(singleWindowDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 3,
    sourceTabName = "Elixirs",
    transactions = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 200001,
            itemName = "Single Window Item",
            craftedQuality = 2,
            quantity = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 12,
        },
    },
})
assert.equal(1, singleWindowInitialCount, "a one-row ledger window should import its first row")

local singleWindowDuplicateCount = bankLedger.MergeItemTransactions(singleWindowDb, {
    scanStartedAt = 1716573900,
    sourceTabIndex = 3,
    sourceTabName = "Elixirs",
    transactions = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 200001,
            itemName = "Single Window Item",
            craftedQuality = 2,
            quantity = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 12,
        },
    },
})
assert.equal(0, singleWindowDuplicateCount, "re-reading a one-row visible item-log window should not duplicate that row")
assert.equal(1, #singleWindowDb.bankLedger.itemLogs, "one-row item-log windows should remain append-only across repeated scans")

local singleWindowNewLeadingCount = bankLedger.MergeItemTransactions(singleWindowDb, {
    scanStartedAt = 1716574200,
    sourceTabIndex = 3,
    sourceTabName = "Elixirs",
    transactions = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 200001,
            itemName = "Single Window Item",
            craftedQuality = 2,
            quantity = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 12,
        },
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 200001,
            itemName = "Single Window Item",
            craftedQuality = 2,
            quantity = 5,
            year = 2026,
            month = 5,
            day = 24,
            hour = 12,
        },
    },
})
assert.equal(1, singleWindowNewLeadingCount, "a new leading row should still append when the only overlap is a single older visible row")
assert.equal(2, #singleWindowDb.bankLedger.itemLogs, "one-row overlap windows should append only the unseen leading delta")

local missingDateDb = fresh_db()
local missingDateInitialCount = bankLedger.MergeItemTransactions(missingDateDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 4,
    sourceTabName = "Missing Dates",
    transactions = {
        {
            type = "deposit",
            who = "OfficerOne-Stormrage",
            itemID = 300001,
            itemName = "Date-Less Flask",
            craftedQuality = 3,
            quantity = 8,
        },
    },
})
assert.equal(1, missingDateInitialCount, "rows without explicit date parts should still import on first scan")

local missingDateDuplicateCount = bankLedger.MergeItemTransactions(missingDateDb, {
    scanStartedAt = 1716577200,
    sourceTabIndex = 4,
    sourceTabName = "Missing Dates",
    transactions = {
        {
            type = "deposit",
            who = "OfficerOne-Stormrage",
            itemID = 300001,
            itemName = "Date-Less Flask",
            craftedQuality = 3,
            quantity = 8,
        },
    },
})
assert.equal(0, missingDateDuplicateCount, "rows without explicit date parts should not duplicate across later scans that use a different fallback timestamp")
assert.equal(1, #missingDateDb.bankLedger.itemLogs, "date-less item rows should remain append-only across repeated scans")

local missingDateMoneyDb = fresh_db()
local missingDateMoneyInitial = bankLedger.MergeMoneyTransactions(missingDateMoneyDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 250000000,
        },
    },
})
assert.equal(1, missingDateMoneyInitial, "money rows without explicit date parts should still import on first scan")

local missingDateMoneyDuplicate = bankLedger.MergeMoneyTransactions(missingDateMoneyDb, {
    scanStartedAt = 1716577200,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 250000000,
        },
    },
})
assert.equal(0, missingDateMoneyDuplicate, "money rows without explicit date parts should not duplicate across later scans that use a different fallback timestamp")
assert.equal(1, #missingDateMoneyDb.bankLedger.moneyLogs, "date-less money rows should remain append-only across repeated scans")

local staleReadDb = fresh_db()
bankLedger.MergeItemTransactions(staleReadDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 5,
    sourceTabName = "Herbs",
    transactions = {
        {
            type = "deposit",
            who = "Gatherer-Stormrage",
            itemID = 400001,
            itemName = "Stable Snapshot Item",
            quantity = 9,
            year = 2026,
            month = 5,
            day = 24,
            hour = 14,
        },
        {
            type = "withdraw",
            who = "Gatherer-Stormrage",
            itemID = 400002,
            itemName = "Stable Snapshot Item Two",
            quantity = 3,
            year = 2026,
            month = 5,
            day = 24,
            hour = 13,
        },
    },
})

local staleEmptyReadCount = bankLedger.MergeItemTransactions(staleReadDb, {
    scanStartedAt = 1716573900,
    sourceTabIndex = 5,
    sourceTabName = "Herbs",
    transactions = {},
})
assert.equal(0, staleEmptyReadCount, "an empty follow-up read should not replace a previously known non-empty ledger snapshot")

local staleMismatchedReadCount = bankLedger.MergeItemTransactions(staleReadDb, {
    scanStartedAt = 1716574200,
    sourceTabIndex = 5,
    sourceTabName = "Herbs",
    transactions = {
        {
            type = "withdraw",
            who = "OtherTab-Stormrage",
            itemID = 499999,
            itemName = "Wrong Buffer Item",
            quantity = 2,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
        {
            type = "deposit",
            who = "OtherTab-Stormrage",
            itemID = 499998,
            itemName = "Wrong Buffer Item Two",
            quantity = 7,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
})
assert.equal(0, staleMismatchedReadCount, "an ambiguous same-size ledger window with no overlap should be ignored instead of replacing the saved source snapshot")

local staleOriginalRepeatCount = bankLedger.MergeItemTransactions(staleReadDb, {
    scanStartedAt = 1716574500,
    sourceTabIndex = 5,
    sourceTabName = "Herbs",
    transactions = {
        {
            type = "deposit",
            who = "Gatherer-Stormrage",
            itemID = 400001,
            itemName = "Stable Snapshot Item",
            quantity = 9,
            year = 2026,
            month = 5,
            day = 24,
            hour = 14,
        },
    },
})
assert.equal(0, staleOriginalRepeatCount, "after ignoring stale or mismatched reads, the original ledger row should still dedupe correctly")
assert.equal(2, #staleReadDb.bankLedger.itemLogs, "stale or mismatched reads should not poison the saved ledger snapshot for later rescans")

local itemRows = bankLedger.BuildTableRows(db, "ITEM", {
    action = "withdraw",
})
assert.equal(0, #itemRows, "item action filtering should exclude non-matching rows")

bankLedger.MergeItemTransactions(db, {
    scanStartedAt = 1716574200,
    sourceTabIndex = 2,
    sourceTabName = "Raid",
    transactions = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 7,
            year = 2026,
            month = 5,
            day = 24,
            hour = 10,
        },
        {
            type = "withdraw",
            who = "RaiderTwo-Stormrage",
            itemID = 210000,
            itemName = "Potion of Controlled Fury",
            craftedQuality = 2,
            quantity = 3,
            year = 2026,
            month = 5,
            day = 24,
            hour = 11,
        },
    },
})

itemRows = bankLedger.BuildTableRows(db, "ITEM", {
    action = "withdraw",
})
assert.equal(2, #itemRows, "item rows should filter withdrawals from the ledger table")
assert.equal("Withdrawal", itemRows[1].action, "item ledger rows should expose humanized actions")

local moneyRows = bankLedger.BuildTableRows(db, "MONEY", {
    action = "repair",
})
assert.equal(1, #moneyRows, "money rows should filter repair actions")
assert.equal("Repair", moneyRows[1].action, "money ledger rows should preserve repair classification")

local itemSummary = bankLedger.BuildItemSummary(db, {
    dateFrom = 0,
    dateTo = 9999999999,
})
assert.equal(7, (((itemSummary.byItem or {})["Flask of Tempered Swiftness"] or {}).withdrawn or 0), "item summary should total withdrawals by item name")
assert.equal(24, (((itemSummary.byItem or {})["Flask of Tempered Swiftness"] or {}).deposited or 0), "item summary should total deposits by item name after appending legitimate new ledger rows")

local moneySummary = bankLedger.BuildMoneySummary(db, {
    dateFrom = 0,
    dateTo = 9999999999,
})
assert.equal(1234.56 * 10000, moneySummary.repairs, "money summary should total repair spend")
assert.equal(10000 * 10000, moneySummary.withdrawals, "money summary should total non-repair withdrawals")
assert.equal(50000 * 10000, moneySummary.deposits, "money summary should total deposits")

local csvText = bankLedger.ExportRowsToCsv(db, "ITEM", {
    dateFrom = 0,
    dateTo = 9999999999,
})
assert.truthy(string.find(csvText, "Date/Time,Who,Action,Item ID,Quality Tier,Item,Quantity,Tab,Moved From", 1, true) ~= nil, "ledger csv export should include both tab columns for item rows")

local usage = bankLedger.BuildUsageRows(db, {
    dateFrom = 0,
    dateTo = 9999999999,
})
assert.equal("GuildLead-Stormrage", usage[1].who, "usage rows should rank the heaviest total bank users first")
assert.equal(50000 * 10000, usage[1].goldIn, "usage rows should aggregate deposited gold for overall bank usage reporting")

local rankingDb = fresh_db()
for index = 1, 12 do
    bankLedger.MergeItemTransactions(rankingDb, {
        scanStartedAt = 1716573600 + index,
        sourceTabIndex = 1,
        sourceTabName = "Raid",
        transactions = {
            {
                type = "withdraw",
                who = "Raider" .. index .. "-Stormrage",
                itemID = 300000 + index,
                itemName = "Item " .. index,
                craftedQuality = 2,
                quantity = 20 - index,
                year = 2026,
                month = 5,
                day = 24,
                hour = 12,
            },
        },
    })
end

local rankings = bankLedger.BuildWithdrawalRankings(rankingDb, {
    limit = 10,
})
assert.equal(10, #rankings, "withdrawal rankings should cap at the top ten items")
assert.equal("Item 1", rankings[1].itemName, "withdrawal rankings should sort descending by withdrawn quantity")
assert.equal("Item 10", rankings[10].itemName, "withdrawal rankings should include the tenth-ranked item")

local retentionDb = fresh_db()
retentionDb.ui.logsHistorySettings.ledgerRetention = "1_week"
retentionDb.ui.logsHistorySettings.historyRetention = "1_month"
retentionDb.bankLedger.itemLogs = {
    { entryId = "item-old", timestamp = 1710000000 },
    { entryId = "item-new", timestamp = 1716500000 },
}
retentionDb.bankLedger.moneyLogs = {
    { entryId = "money-old", timestamp = 1710000000 },
    { entryId = "money-new", timestamp = 1716500000 },
}
retentionDb.auditLog = {
    { timestamp = 1712000000, type = "MINIMUM_UPDATED", category = "MINIMUM" },
    { timestamp = 1716500000, type = "REQUEST_CREATED", category = "REQUEST" },
}
bankLedger.PruneRetention(retentionDb, 1717000000)
assert.equal(1, #retentionDb.bankLedger.itemLogs, "ledger pruning should remove expired item logs")
assert.equal("item-new", retentionDb.bankLedger.itemLogs[1].entryId, "ledger pruning should preserve in-range item logs")
assert.equal(1, #retentionDb.bankLedger.moneyLogs, "ledger pruning should remove expired money logs")
assert.equal(1, #retentionDb.auditLog, "history pruning should remove expired audit entries")

local scanDb = fresh_db()
scanDb.bankLedger.lastScanAt = 1000
scanDb.ui.logsHistorySettings.ledgerScanIntervalSeconds = 300
assert.truthy(not bankLedger.ShouldScan(scanDb, 1200), "ledger scans should throttle within the configured interval")
assert.truthy(bankLedger.ShouldScan(scanDb, 1300), "ledger scans should resume once the configured interval has elapsed")
