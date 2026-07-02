local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local bankLedger = dofile("GBankManager/Domain/BankLedger.lua")
local defaults = dofile("GBankManager/Data/Defaults.lua")
local migrations = dofile("GBankManager/Data/Migrations.lua")

local function fresh_db()
    local root = migrations.Apply(defaults.CreateDatabase("Guild Testers"), "Guild Testers")
    if type(root.guilds) == "table" then
        return root.guilds[root.activeGuildKey or "Guild Testers"] or root.guilds["Guild Testers"] or {}
    end

    return root
end

local db = fresh_db()

assert.truthy(type(db.bankLedger) == "table", "database defaults should include a bank-ledger container")
assert.equal(nil, db.bankLedger.itemFingerprints, "database defaults should not persist runtime item fingerprint indexes")
assert.equal(nil, db.bankLedger.moneyFingerprints, "database defaults should not persist runtime money fingerprint indexes")
assert.truthy(type(db.ui.logsHistorySettings) == "table", "database defaults should include logs/history settings")
assert.equal("indefinite", db.ui.logsHistorySettings.ledgerRetention, "ledger retention should default to indefinite to avoid surprise data loss")
assert.equal("indefinite", db.ui.logsHistorySettings.historyRetention, "history retention should default to indefinite to avoid surprise data loss")
assert.equal(300, db.ui.logsHistorySettings.ledgerScanIntervalSeconds, "ledger scan interval should default to five minutes")
assert.equal(5000, db.ui.logsHistorySettings.repairThresholdGold, "ledger repair classification threshold should default to five thousand gold")
assert.truthy(not db.ui.logsHistorySettings.muteSilvermoonCitizen, "Silvermoon Citizen chat mute should default off")
assert.truthy(type(db.ui.chatSettings) == "table", "database defaults should include reusable chat settings")
assert.equal(true, db.ui.chatSettings.suppressRoutineMessages, "routine addon chat suppression should default on")

local indexRuntimeDb = fresh_db()
indexRuntimeDb.bankLedger.itemLogs = {
    {
        entryId = "runtime-item-1",
        timestamp = 1716573600,
        action = "Deposit",
        who = "GuildLead-Stormrage",
        itemID = 211878,
        item = "Runtime Flask",
        quantity = 1,
        tabIndex = 1,
        tabName = "Flasks",
    },
}
indexRuntimeDb.bankLedger.moneyLogs = {
    {
        entryId = "runtime-money-1",
        timestamp = 1716573660,
        action = "Deposit",
        who = "GuildLead-Stormrage",
        amountCopper = 12345,
    },
}
bankLedger.EnsureState(indexRuntimeDb)
local firstRuntimeState = bankLedger.GetRuntimeIndexState(indexRuntimeDb)
assert.equal(1, tonumber(firstRuntimeState.itemRebuilds or 0), "initial EnsureState should build the item runtime index once")
assert.equal(1, tonumber(firstRuntimeState.moneyRebuilds or 0), "initial EnsureState should build the money runtime index once")
bankLedger.EnsureState(indexRuntimeDb)
local secondRuntimeState = bankLedger.GetRuntimeIndexState(indexRuntimeDb)
assert.equal(firstRuntimeState.itemRebuilds, secondRuntimeState.itemRebuilds, "second EnsureState with unchanged item logs should not rebuild the item runtime index")
assert.equal(firstRuntimeState.moneyRebuilds, secondRuntimeState.moneyRebuilds, "second EnsureState with unchanged money logs should not rebuild the money runtime index")

local appendRuntimeDb = fresh_db()
bankLedger.EnsureState(appendRuntimeDb)
local cleanRuntimeState = bankLedger.GetRuntimeIndexState(appendRuntimeDb)
assert.truthy(cleanRuntimeState.itemDirty ~= true, "freshly ensured item runtime index should start clean")
assert.truthy(cleanRuntimeState.moneyDirty ~= true, "freshly ensured money runtime index should start clean")
bankLedger.MergeItemTransactions(appendRuntimeDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Runtime Flask",
            quantity = 1,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})
local dirtyItemRuntimeState = bankLedger.GetRuntimeIndexState(appendRuntimeDb)
assert.truthy(dirtyItemRuntimeState.itemDirty == true, "appending item ledger rows should mark the item runtime index dirty")
bankLedger.MergeMoneyTransactions(appendRuntimeDb, {
    scanStartedAt = 1716573660,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amountCopper = 12345,
            year = 2024,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})
local dirtyRuntimeState = bankLedger.GetRuntimeIndexState(appendRuntimeDb)
assert.truthy(dirtyRuntimeState.moneyDirty == true, "appending money ledger rows should mark the money runtime index dirty")

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

local bucketMergeDb = fresh_db()
local bucketPayload = {
    rows = {
        item = {
            {
                action = "Deposit",
                who = "OfficerOne-Stormrage",
                itemID = 211878,
                item = "Flask of Tempered Swiftness",
                quantity = 5,
                tabIndex = 3,
                tabName = "Raid Supplies",
                year = 2024,
                month = 5,
                day = 24,
                hour = 7,
            },
        },
        money = {
            {
                action = "Deposit",
                who = "OfficerOne-Stormrage",
                amountCopper = 2500000,
                year = 2024,
                month = 5,
                day = 24,
                hour = 8,
            },
        },
    },
}
local bucketMergeInitialCount = bankLedger.MergeBucketRows(bucketMergeDb, bucketPayload)
assert.equal(2, bucketMergeInitialCount, "ledger bucket merge should append item and money bucket rows")
assert.equal(1, #bucketMergeDb.bankLedger.itemLogs, "ledger bucket merge should persist item bucket rows")
assert.equal(1, #bucketMergeDb.bankLedger.moneyLogs, "ledger bucket merge should persist money bucket rows")
assert.equal(3, bucketMergeDb.bankLedger.itemLogs[1].tabIndex, "ledger bucket merge should preserve source tab index metadata")
assert.equal("Raid Supplies", bucketMergeDb.bankLedger.itemLogs[1].tabName, "ledger bucket merge should preserve source tab name metadata")
local bucketMergeReplayCount = bankLedger.MergeBucketRows(bucketMergeDb, bucketPayload)
assert.equal(0, bucketMergeReplayCount, "ledger bucket merge should skip duplicate bucket payload rows")
assert.equal(1, #bucketMergeDb.bankLedger.itemLogs, "ledger bucket replay should not duplicate item rows")
assert.equal(1, #bucketMergeDb.bankLedger.moneyLogs, "ledger bucket replay should not duplicate money rows")

local bucketBatchDb = fresh_db()
bankLedger.__debugMergeCounters = {
    item = 0,
    money = 0,
}
local bucketBatchPayload = {
    rows = {
        item = {
            {
                action = "Deposit",
                who = "OfficerOne-Stormrage",
                itemID = 211878,
                item = "Flask of Tempered Swiftness",
                quantity = 5,
                tabIndex = 3,
                tabName = "Raid Supplies",
                year = 2024,
                month = 5,
                day = 24,
                hour = 7,
            },
            {
                action = "Withdraw",
                who = "OfficerTwo-Stormrage",
                itemID = 211879,
                item = "Potion of Tempered Swiftness",
                quantity = 2,
                tabIndex = 3,
                tabName = "Raid Supplies",
                year = 2024,
                month = 5,
                day = 24,
                hour = 7,
                minute = 5,
            },
        },
        money = {
            {
                action = "Deposit",
                who = "OfficerOne-Stormrage",
                amountCopper = 2500000,
                year = 2024,
                month = 5,
                day = 24,
                hour = 8,
            },
            {
                action = "Withdraw",
                who = "OfficerTwo-Stormrage",
                amountCopper = -750000,
                year = 2024,
                month = 5,
                day = 24,
                hour = 8,
                minute = 10,
            },
        },
    },
}
local bucketBatchInitialCount = bankLedger.MergeBucketRows(bucketBatchDb, bucketBatchPayload)
assert.equal(4, bucketBatchInitialCount, "batched ledger bucket merge should append every valid item and money row")
assert.equal(2, #bucketBatchDb.bankLedger.itemLogs, "batched ledger bucket merge should persist all item rows")
assert.equal(2, #bucketBatchDb.bankLedger.moneyLogs, "batched ledger bucket merge should persist all money rows")
assert.equal(1, bankLedger.__debugMergeCounters.item, "batched ledger bucket merge should call item source merge once per source tab")
assert.equal(1, bankLedger.__debugMergeCounters.money, "batched ledger bucket merge should call money source merge once per source key")
local bucketBatchReplayCount = bankLedger.MergeBucketRows(bucketBatchDb, bucketBatchPayload)
assert.equal(0, bucketBatchReplayCount, "batched ledger bucket replay should skip duplicate rows")
assert.equal(2, #bucketBatchDb.bankLedger.itemLogs, "batched ledger bucket replay should not duplicate item rows")
assert.equal(2, #bucketBatchDb.bankLedger.moneyLogs, "batched ledger bucket replay should not duplicate money rows")
assert.equal(2, bankLedger.__debugMergeCounters.item, "batched ledger bucket replay should still call item source merge once per source tab")
assert.equal(2, bankLedger.__debugMergeCounters.money, "batched ledger bucket replay should still call money source merge once per source key")
bankLedger.__debugMergeCounters = nil

local malformedBucketDb = fresh_db()
local malformedBucketCount = bankLedger.MergeBucketRows(malformedBucketDb, {
    rows = {
        item = { "bad" },
        money = { "bad" },
    },
})
assert.equal(0, malformedBucketCount, "ledger bucket merge should ignore malformed non-table bucket rows")
assert.equal(0, #malformedBucketDb.bankLedger.itemLogs, "malformed item bucket rows should not append synthetic item rows")
assert.equal(0, #malformedBucketDb.bankLedger.moneyLogs, "malformed money bucket rows should not append synthetic money rows")

local emptyBucketRowDb = fresh_db()
local emptyBucketRowCount = bankLedger.MergeBucketRows(emptyBucketRowDb, {
    rows = {
        item = { {} },
        money = { {} },
    },
})
assert.equal(0, emptyBucketRowCount, "ledger bucket merge should ignore empty table bucket rows")
assert.equal(0, #emptyBucketRowDb.bankLedger.itemLogs, "empty item bucket rows should not append synthetic item rows")
assert.equal(0, #emptyBucketRowDb.bankLedger.moneyLogs, "empty money bucket rows should not append synthetic money rows")

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

local remoteLedgerDb = fresh_db()
remoteLedgerDb.bankLedger.lastScanAt = 1716570000
local remoteMergedCount = bankLedger.MergeRemoteDelta(remoteLedgerDb, {
    kind = "item",
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
    },
})
assert.equal(1, remoteMergedCount, "remote ledger deltas should append unseen rows into the local ledger")
assert.equal(1, #remoteLedgerDb.bankLedger.itemLogs, "remote ledger deltas should persist their rows in the item ledger")
assert.equal(1716570000, tonumber(remoteLedgerDb.bankLedger.lastScanAt or 0), "remote ledger deltas should not advance the local ledger scan freshness")
local laterVisibleScanMergedCount = bankLedger.MergeItemTransactions(remoteLedgerDb, {
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
    },
})
assert.equal(0, laterVisibleScanMergedCount, "a later local ledger scan of the same visible row should not duplicate a row that already arrived through remote sync")
assert.equal(1, #remoteLedgerDb.bankLedger.itemLogs, "a later local ledger scan of the same visible row should leave the remote-synced ledger row count unchanged")

local remoteMoneyBatchDb = fresh_db()
local remoteMoneyBatchInitial = bankLedger.MergeMoneyTransactions(remoteMoneyBatchDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "repair",
            who = "Unholy-Skullcrusher",
            amount = 839240066,
            year = 2026,
            month = 6,
            day = 1,
            hour = 11,
            minute = 15,
        },
    },
})
assert.equal(1, remoteMoneyBatchInitial, "baseline local money import should persist the first visible repair row")
local remoteMoneyBatchMerged = bankLedger.MergeRemoteDelta(remoteMoneyBatchDb, {
    kind = "money",
    scanStartedAt = 1716573900,
    repairThresholdGold = 5000,
    transactions = {
        {
            type = "repair",
            who = "Unholy-Skullcrusher",
            amount = 839240066,
            year = 2026,
            month = 6,
            day = 1,
            hour = 11,
            minute = 15,
        },
        {
            type = "repair",
            who = "Unholy-Skullcrusher",
            amount = 839240066,
            year = 2026,
            month = 6,
            day = 1,
            hour = 11,
            minute = 15,
        },
    },
})
assert.equal(0, remoteMoneyBatchMerged, "remote money deltas should not trust duplicate visible occurrences from a peer cache")
assert.equal(1, #remoteMoneyBatchDb.bankLedger.moneyLogs, "remote money deltas should leave a cleaned receiver with one visible row")
local remoteMoneyBatchRepeat = bankLedger.MergeMoneyTransactions(remoteMoneyBatchDb, {
    scanStartedAt = 1716574200,
    transactions = {
        {
            type = "repair",
            who = "Unholy-Skullcrusher",
            amount = 839240066,
            year = 2026,
            month = 6,
            day = 1,
            hour = 11,
            minute = 15,
        },
        {
            type = "repair",
            who = "Unholy-Skullcrusher",
            amount = 839240066,
            year = 2026,
            month = 6,
            day = 1,
            hour = 11,
            minute = 15,
        },
    },
})
assert.equal(1, remoteMoneyBatchRepeat, "a later local money scan remains the source of truth for repeated visible occurrences")
assert.equal(2, #remoteMoneyBatchDb.bankLedger.moneyLogs, "a later local money scan should be able to grow real repeated money rows")

local itemReplayBridgeDb = fresh_db()
local itemReplayBridgeInitial = bankLedger.MergeItemTransactions(itemReplayBridgeDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 1,
    sourceTabName = "Freebiez",
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent",
            itemID = 241305,
            itemName = "Silvermoon Health Potion",
            quantity = 80,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 36,
        },
    },
})
assert.equal(1, itemReplayBridgeInitial, "baseline item import should persist the visible Freebiez deposit")
itemReplayBridgeDb.bankLedger.itemSourceSnapshots = {}
local itemReplayBridgeRepeat = bankLedger.MergeItemTransactions(itemReplayBridgeDb, {
    scanStartedAt = 1716573900,
    sourceTabIndex = 1,
    sourceTabName = "Freebiez",
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent",
            itemID = 241305,
            itemName = "Silvermoon Health Potion",
            quantity = 80,
            year = 2026,
            month = 6,
            day = 2,
            hour = 13,
            minute = 54,
        },
    },
})
assert.equal(0, itemReplayBridgeRepeat, "item scans should not regrow a visible duplicate when source snapshots are empty and only the timestamp shifted")
assert.equal(1, #itemReplayBridgeDb.bankLedger.itemLogs, "shifted item replay should leave the repaired item ledger clean")

local pollutedRemoteMoneyDb = fresh_db()
local pollutedRemoteMoneyInitial = bankLedger.MergeMoneyTransactions(pollutedRemoteMoneyDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 11,
            minute = 55,
        },
    },
})
assert.equal(1, pollutedRemoteMoneyInitial, "baseline clean receiver should already have the visible money row")
local pollutedRemoteMoneyMerged = bankLedger.MergeRemoteDelta(pollutedRemoteMoneyDb, {
    kind = "money",
    scanStartedAt = 1716573900,
    repairThresholdGold = 5000,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 11,
            minute = 55,
        },
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 27,
        },
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 55,
        },
    },
})
assert.equal(0, pollutedRemoteMoneyMerged, "polluted remote money payloads should not re-contaminate a cleaned receiver")
assert.equal(1, #pollutedRemoteMoneyDb.bankLedger.moneyLogs, "polluted remote money payloads should not append visible duplicates")

local pollutedRemoteMoneyDifferentFirstDb = fresh_db()
local pollutedRemoteMoneyDifferentFirstInitial = bankLedger.MergeMoneyTransactions(pollutedRemoteMoneyDifferentFirstDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 11,
            minute = 55,
        },
    },
})
assert.equal(1, pollutedRemoteMoneyDifferentFirstInitial, "baseline clean receiver should have one visible money row before older-client sync")
local pollutedRemoteMoneyDifferentFirstMerged = bankLedger.MergeRemoteDelta(pollutedRemoteMoneyDifferentFirstDb, {
    kind = "money",
    scanStartedAt = 1716573900,
    repairThresholdGold = 5000,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 27,
        },
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 11,
            minute = 55,
        },
    },
})
assert.equal(0, pollutedRemoteMoneyDifferentFirstMerged, "older-client sync should not append a visible duplicate when its first kept row has a different timestamp")
assert.equal(1, #pollutedRemoteMoneyDifferentFirstDb.bankLedger.moneyLogs, "older-client sync should leave the repaired receiver clean")

local sanitizedRemoteMoneyPayload = bankLedger.SanitizeRemoteDeltaPayload({
    kind = "money",
    scanStartedAt = 1716573900,
    repairThresholdGold = 5000,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 11,
            minute = 55,
        },
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 27,
        },
    },
})
assert.equal(1, #(sanitizedRemoteMoneyPayload.transactions or {}), "outbound money ledger sync should collapse dirty visible duplicates")

local sanitizedRemoteItemPayload = bankLedger.SanitizeRemoteDeltaPayload({
    kind = "item",
    scanStartedAt = 1716573900,
    sourceTabIndex = 2,
    sourceTabName = "Freebiez",
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            itemID = 244559,
            itemName = "Void-Touched Augment Rune",
            quantity = 1,
            year = 2026,
            month = 5,
            day = 29,
            hour = 17,
            minute = 52,
        },
        {
            type = "withdraw",
            who = "Zirleficent",
            itemID = 244559,
            itemName = "Void-Touched Augment Rune",
            quantity = 1,
            year = 2026,
            month = 5,
            day = 29,
            hour = 17,
            minute = 52,
        },
    },
})
assert.equal(1, #(sanitizedRemoteItemPayload.transactions or {}), "outbound item ledger sync should collapse dirty visible duplicates")

local relogStableItemDb = fresh_db()
_G.GetServerTime = function()
    return 1716577200
end
local relogStableItemInitial = bankLedger.MergeItemTransactions(relogStableItemDb, {
    scanStartedAt = 1716577200,
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
            year = 0,
            month = 0,
            day = 0,
            hour = 1,
        },
    },
})
assert.equal(1, relogStableItemInitial, "baseline relative-offset item import should persist the initial visible ledger row")
_G.GetServerTime = function()
    return 1716580800
end
local relogStableItemRepeat = bankLedger.MergeItemTransactions(relogStableItemDb, {
    scanStartedAt = 1716580800,
    sourceTabIndex = 1,
    sourceTabName = "Flasks",
    transactions = {
        {
            type = "withdraw",
            who = "RaiderOne-Stormrage",
            itemID = 210000,
            itemName = "Potion of Controlled Fury",
            craftedQuality = 0,
            quantity = 3,
            year = 0,
            month = 0,
            day = 0,
            hour = 1,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            itemID = 211878,
            itemName = "Flask of Tempered Swiftness",
            craftedQuality = 3,
            quantity = 12,
            year = 0,
            month = 0,
            day = 0,
            hour = 2,
        },
    },
})
assert.equal(1, relogStableItemRepeat, "item dedupe should still append a new leading row after a relog even when Blizzard's relative offsets have all shifted")
assert.equal(2, #relogStableItemDb.bankLedger.itemLogs, "item dedupe should keep the old relative-offset row while appending the newly visible one after relog")

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

local thresholdDb = fresh_db()
thresholdDb.ui.logsHistorySettings.repairThresholdGold = 100
local thresholdMergeCount = bankLedger.MergeMoneyTransactions(thresholdDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 2024,
            month = 5,
            day = 24,
            hour = 7,
        },
    },
})
assert.equal(1, thresholdMergeCount, "money merge should still persist withdrawals when the repair threshold is lowered")
assert.equal("Withdrawal", thresholdDb.bankLedger.moneyLogs[1].action, "withdrawals above the configured repair threshold should stay withdrawals")

local relogStableMoneyDb = fresh_db()
_G.GetServerTime = function()
    return 1716577200
end
local relogStableMoneyInitial = bankLedger.MergeMoneyTransactions(relogStableMoneyDb, {
    scanStartedAt = 1716577200,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 500000000,
            year = 0,
            month = 0,
            day = 0,
            hour = 1,
        },
    },
})
assert.equal(1, relogStableMoneyInitial, "baseline relative-offset money import should persist the initial visible ledger row")
_G.GetServerTime = function()
    return 1716580800
end
local relogStableMoneyRepeat = bankLedger.MergeMoneyTransactions(relogStableMoneyDb, {
    scanStartedAt = 1716580800,
    transactions = {
        {
            type = "withdraw",
            who = "OfficerTwo-Stormrage",
            amount = 100000000,
            year = 0,
            month = 0,
            day = 0,
            hour = 1,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 500000000,
            year = 0,
            month = 0,
            day = 0,
            hour = 2,
        },
    },
})
assert.equal(1, relogStableMoneyRepeat, "money dedupe should still append a new leading row after a relog even when Blizzard's relative offsets have all shifted")
assert.equal(2, #relogStableMoneyDb.bankLedger.moneyLogs, "money dedupe should keep the old relative-offset row while appending the newly visible one after relog")

local repeatedRealMoneyDb = fresh_db()
_G.GetServerTime = function()
    return 1779998400
end
local repeatedRealMoneyInitial = bankLedger.MergeMoneyTransactions(repeatedRealMoneyDb, {
    scanStartedAt = 1779998400,
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent",
            amount = 100 * 10000,
            year = 0,
            month = 0,
            day = 0,
            hour = 19,
        },
    },
})
assert.equal(1, repeatedRealMoneyInitial, "baseline repeated-real money import should persist the first matching transaction")
_G.GetServerTime = function()
    return 1780002000
end
local repeatedRealMoneyNext = bankLedger.MergeMoneyTransactions(repeatedRealMoneyDb, {
    scanStartedAt = 1780002000,
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent",
            amount = 100 * 10000,
            year = 0,
            month = 0,
            day = 0,
            hour = 2,
        },
    },
})
assert.equal(1, repeatedRealMoneyNext, "a real later money transaction with the same actor/action/amount should append instead of being hidden by timeless legacy dedupe")
assert.equal(2, #repeatedRealMoneyDb.bankLedger.moneyLogs, "repeated real money activity should keep both distinct timestamps")

local relativeMoneyReplayDb = fresh_db()
_G.GetServerTime = function()
    return 1780540360
end
local relativeMoneyReplayInitial = bankLedger.MergeMoneyTransactions(relativeMoneyReplayDb, {
    scanStartedAt = 1780540360,
    transactions = {
        {
            type = "withdraw",
            who = "Zerobrews",
            amount = 1874304,
            year = 0,
            month = 0,
            day = 0,
            hour = 21,
        },
    },
})
assert.equal(1, relativeMoneyReplayInitial, "baseline relative money replay import should persist the first visible ledger row")
_G.GetServerTime = function()
    return 1780594903
end
local relativeMoneyReplayRepeat = bankLedger.MergeMoneyTransactions(relativeMoneyReplayDb, {
    scanStartedAt = 1780594903,
    transactions = {
        {
            type = "withdraw",
            who = "Zerobrews",
            amount = 1874304,
            year = 0,
            month = 0,
            day = 0,
            hour = 21,
        },
    },
})
assert.equal(0, relativeMoneyReplayRepeat, "money replay should not duplicate the same raw relative Blizzard row when a later scan mints a new absolute timestamp")
assert.equal(1, #relativeMoneyReplayDb.bankLedger.moneyLogs, "money replay should keep one row for the same raw relative Blizzard money entry")

local driftedRelativeMoneyReplayDb = fresh_db()
driftedRelativeMoneyReplayDb.bankLedger.moneyLogs = {
    {
        entryId = "money-original-relative-hour",
        timestamp = 1780626109,
        when = 1780626109,
        who = "Zerobrews",
        action = "Repair",
        amountCopper = 5779554,
        amount = 5779554,
        year = 0,
        month = 0,
        day = 0,
        hour = 12,
        fingerprint = "2026|6|4|22|21|Zerobrews|withdraw|5779554|1",
        legacyFingerprint = "unknown|Zerobrews|withdraw|5779554|1",
    },
}
bankLedger.EnsureState(driftedRelativeMoneyReplayDb)
local driftedRelativeMoneyReplayRepeat = bankLedger.MergeMoneyTransactions(driftedRelativeMoneyReplayDb, {
    scanStartedAt = 1780625759,
    transactions = {
        {
            type = "withdraw",
            who = "Zerobrews",
            amountCopper = 5779554,
            year = 0,
            month = 0,
            day = 0,
            hour = 17,
        },
    },
})
assert.equal(0, driftedRelativeMoneyReplayRepeat, "money replay should not duplicate the same raw relative Blizzard row when its visible relative hour drifts")
assert.equal(1, #driftedRelativeMoneyReplayDb.bankLedger.moneyLogs, "drifted relative money replay should leave one canonical row")

local repeatedRealItemDb = fresh_db()
_G.GetServerTime = function()
    return 1779998400
end
local repeatedRealItemInitial = bankLedger.MergeItemTransactions(repeatedRealItemDb, {
    scanStartedAt = 1779998400,
    sourceTabIndex = 8,
    sourceTabName = "Donations",
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            itemID = 82800,
            itemName = "Pet Cage",
            quantity = 1,
            year = 0,
            month = 0,
            day = 1,
            hour = 13,
        },
    },
})
assert.equal(1, repeatedRealItemInitial, "baseline repeated-real item import should persist the first matching transaction")
_G.GetServerTime = function()
    return 1780002000
end
local repeatedRealItemNext = bankLedger.MergeItemTransactions(repeatedRealItemDb, {
    scanStartedAt = 1780002000,
    sourceTabIndex = 8,
    sourceTabName = "Donations",
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            itemID = 82800,
            itemName = "Pet Cage",
            quantity = 1,
            year = 0,
            month = 0,
            day = 0,
            hour = 13,
        },
    },
    allowSuspiciousUnknownAppend = true,
})
assert.equal(1, repeatedRealItemNext, "a real later item transaction with the same actor/action/item/quantity/tab should append instead of being hidden by timeless legacy dedupe")
assert.equal(2, #repeatedRealItemDb.bankLedger.itemLogs, "repeated real item activity should keep both distinct timestamps")

local regrownBatchMoneyDb = fresh_db()
local regrownBatchMoneyInitial = bankLedger.MergeMoneyTransactions(regrownBatchMoneyDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 100 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 100 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})
assert.equal(2, regrownBatchMoneyInitial, "baseline same-identity money import should store both visible occurrences")
local regrownBatchMoneyShrunk = bankLedger.MergeMoneyTransactions(regrownBatchMoneyDb, {
    scanStartedAt = 1716573900,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 100 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})
assert.equal(0, regrownBatchMoneyShrunk, "shrinking visible money batches should not duplicate stored history")
local regrownBatchMoneyNext = bankLedger.MergeMoneyTransactions(regrownBatchMoneyDb, {
    scanStartedAt = 1716574200,
    transactions = {
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 100 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
        {
            type = "deposit",
            who = "GuildLead-Stormrage",
            amount = 100 * 10000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 9,
        },
    },
})
assert.equal(1, regrownBatchMoneyNext, "GBL-style session batch counts should append a same-identity money row when the visible batch regrows")
assert.equal(3, #regrownBatchMoneyDb.bankLedger.moneyLogs, "regrown same-identity money batches should preserve every distinct event")

local durableCountMoneyDb = fresh_db()
local durableCountMoneyPayload = {
    scanStartedAt = 1718300000,
    transactions = {
        { type = "deposit", who = "MemberOne", amount = 1234500, year = 0, month = 0, day = 0, hour = 16 },
        { type = "deposit", who = "MemberOne", amount = 1234500, year = 0, month = 0, day = 0, hour = 16 },
    },
}
local durableCountMoneyFirstMerge = bankLedger.MergeMoneyTransactions(durableCountMoneyDb, durableCountMoneyPayload)
assert.equal(2, durableCountMoneyFirstMerge, "first full money batch should append both same-hour occurrences")

local durableCountMoneyLedger = bankLedger.EnsureState(durableCountMoneyDb)
assert.truthy(type(((durableCountMoneyLedger.eventCounts or {}).money)) == "table", "money merge should persist durable event count metadata")
local durableCountMoneyHighWater = 0
for _, entry in pairs(durableCountMoneyLedger.eventCounts.money or {}) do
    durableCountMoneyHighWater = math.max(durableCountMoneyHighWater, tonumber((entry or {}).count or 0) or 0)
end
assert.equal(2, durableCountMoneyHighWater, "money durable event counts should remember both same-hour occurrences")
durableCountMoneyLedger.sessionBatchCounts = nil
bankLedger = dofile("GBankManager/Domain/BankLedger.lua")
local durableCountMoneyReplayMerge = bankLedger.MergeMoneyTransactions(durableCountMoneyDb, durableCountMoneyPayload)
assert.equal(0, durableCountMoneyReplayMerge, "persisted money event counts should prevent reload-time duplicate appends")

durableCountMoneyPayload.transactions[#durableCountMoneyPayload.transactions + 1] = { type = "deposit", who = "MemberOne", amount = 1234500, year = 0, month = 0, day = 0, hour = 16 }
local durableCountMoneyLaterMerge = bankLedger.MergeMoneyTransactions(durableCountMoneyDb, durableCountMoneyPayload)
assert.equal(1, durableCountMoneyLaterMerge, "one extra visible money occurrence should append exactly one row")

local driftedRelativeDepositDb = fresh_db()
bankLedger.MergeMoneyTransactions(driftedRelativeDepositDb, {
    scanStartedAt = 1780684429,
    transactions = {
        { type = "deposit", who = "Ziriously", amount = 50000000, year = 0, month = 0, day = 0, hour = 0 },
    },
})
local driftedRelativeDepositMerge = bankLedger.MergeMoneyTransactions(driftedRelativeDepositDb, {
    scanStartedAt = 1780685233,
    transactions = {
        { type = "deposit", who = "Ziriously", amount = 50000000, year = 0, month = 0, day = 0, hour = 1 },
    },
})
assert.equal(0, driftedRelativeDepositMerge, "raw relative money deposits should not duplicate when Blizzard's visible hour drifts")
assert.equal(1, #driftedRelativeDepositDb.bankLedger.moneyLogs, "drifted raw relative deposits should keep one canonical row")

local legacyStampedRelativeDepositDb = fresh_db()
legacyStampedRelativeDepositDb.bankLedger.moneyLogs = {
    {
        entryId = "money-live-5000-original",
        timestamp = 1780684429,
        when = 1780684429,
        who = "Ziriously",
        action = "Deposit",
        amountCopper = 50000000,
        amount = 50000000,
        year = 0,
        month = 0,
        day = 0,
        hour = 0,
        fingerprint = "2026|6|5|14|33|Ziriously|deposit|50000000|1",
        legacyFingerprint = "unknown|Ziriously|deposit|50000000|1",
        replayBridgeBase = "0|0|0|0||0|Ziriously|deposit|50000000",
    },
    {
        entryId = "money-live-5001-original",
        timestamp = 1780686959,
        when = 1780686959,
        who = "Ziriously",
        action = "Deposit",
        amountCopper = 50010000,
        amount = 50010000,
        year = 0,
        month = 0,
        day = 0,
        hour = 0,
        fingerprint = "2026|6|5|15|15|Ziriously|deposit|50010000|1",
        legacyFingerprint = "unknown|Ziriously|deposit|50010000|1",
        replayBridgeBase = "0|0|0|0||0|Ziriously|deposit|50010000",
    },
}
bankLedger.EnsureState(legacyStampedRelativeDepositDb)
_G.GetServerTime = function()
    return 1780690784
end
local legacyStampedRelativeDepositMerge = bankLedger.MergeMoneyTransactions(legacyStampedRelativeDepositDb, {
    scanStartedAt = 1780690782,
    transactions = {
        { type = "deposit", who = "Ziriously", amount = 50000000, year = 0, month = 0, day = 0, hour = 1 },
        { type = "deposit", who = "Ziriously", amount = 50010000, year = 0, month = 0, day = 0, hour = 1 },
    },
})
assert.equal(0, legacyStampedRelativeDepositMerge, "legacy-keyed raw relative deposits should not reappend when a later scan shifts their visible hour")
assert.equal(2, #legacyStampedRelativeDepositDb.bankLedger.moneyLogs, "legacy-keyed drifted deposits should keep only the canonical original rows")

local regrownBatchItemDb = fresh_db()
local regrownBatchItemInitial = bankLedger.MergeItemTransactions(regrownBatchItemDb, {
    scanStartedAt = 1716573600,
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
assert.equal(2, regrownBatchItemInitial, "baseline same-identity item import should store both visible occurrences")
local regrownBatchItemShrunk = bankLedger.MergeItemTransactions(regrownBatchItemDb, {
    scanStartedAt = 1716573900,
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
assert.equal(0, regrownBatchItemShrunk, "shrinking visible item batches should not duplicate stored history")
local regrownBatchItemNext = bankLedger.MergeItemTransactions(regrownBatchItemDb, {
    scanStartedAt = 1716574200,
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
assert.equal(1, regrownBatchItemNext, "GBL-style session batch counts should append a same-identity item row when the visible batch regrows")
assert.equal(3, #regrownBatchItemDb.bankLedger.itemLogs, "regrown same-identity item batches should preserve every distinct event")

local durableCountItemDb = fresh_db()
local durableCountItemPayload = {
    kind = "item",
    sourceTabIndex = 2,
    sourceTabName = "Extra Stuff",
    scanStartedAt = 1718300000,
    transactions = {
        { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 },
        { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 },
    },
}

local durableCountItemFirstMerge = bankLedger.MergeItemTransactions(durableCountItemDb, durableCountItemPayload)
assert.equal(2, durableCountItemFirstMerge, "first full batch should append both same-hour occurrences")

local durableCountItemLedger = bankLedger.EnsureState(durableCountItemDb)
assert.truthy(type(((durableCountItemLedger.eventCounts or {}).item)) == "table", "item merge should persist durable event count metadata")
local durableCountItemHighWater = 0
for _, entry in pairs(durableCountItemLedger.eventCounts.item or {}) do
    durableCountItemHighWater = math.max(durableCountItemHighWater, tonumber((entry or {}).count or 0) or 0)
end
assert.equal(2, durableCountItemHighWater, "item durable event counts should remember both same-hour occurrences")
durableCountItemLedger.sessionBatchCounts = nil
bankLedger = dofile("GBankManager/Domain/BankLedger.lua")
local durableCountItemReplayMerge = bankLedger.MergeItemTransactions(durableCountItemDb, durableCountItemPayload)
assert.equal(0, durableCountItemReplayMerge, "persisted event counts should prevent reload-time duplicate appends")

durableCountItemPayload.transactions[#durableCountItemPayload.transactions + 1] = { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 }
local durableCountItemLaterMerge = bankLedger.MergeItemTransactions(durableCountItemDb, durableCountItemPayload)
assert.equal(1, durableCountItemLaterMerge, "one extra visible occurrence should append exactly one row")

local thresholdStableFingerprintDb = fresh_db()
local thresholdStableFingerprintInitial = bankLedger.MergeMoneyTransactions(thresholdStableFingerprintDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "withdraw",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 2026,
            month = 5,
            day = 24,
            hour = 7,
        },
    },
})
assert.equal(1, thresholdStableFingerprintInitial, "baseline money import should persist the original withdrawal row before threshold changes")
thresholdStableFingerprintDb.ui.logsHistorySettings.repairThresholdGold = 100
local thresholdStableFingerprintRepeat = bankLedger.MergeMoneyTransactions(thresholdStableFingerprintDb, {
    scanStartedAt = 1716573900,
    transactions = {
        {
            type = "withdraw",
            who = "RepairDruid-Stormrage",
            amount = 12345600,
            year = 2026,
            month = 5,
            day = 24,
            hour = 7,
        },
    },
})
assert.equal(0, thresholdStableFingerprintRepeat, "money dedupe should stay stable when repairThresholdGold changes after the original import")
assert.equal(1, #thresholdStableFingerprintDb.bankLedger.moneyLogs, "threshold changes should not duplicate previously imported money rows on rescan")
assert.equal("Repair", thresholdStableFingerprintDb.bankLedger.moneyLogs[1].action, "threshold changes should not rewrite stored money row display classification")

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

local rotatedWindowMoneyDb = fresh_db()
local rotatedWindowMoneyInitial = bankLedger.MergeMoneyTransactions(rotatedWindowMoneyDb, {
    scanStartedAt = 1716935400,
    transactions = {
        {
            type = "repair",
            who = "A",
            amount = 10000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
        {
            type = "repair",
            who = "B",
            amount = 20000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
        {
            type = "repair",
            who = "C",
            amount = 30000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
    },
})
assert.equal(3, rotatedWindowMoneyInitial, "baseline busy money-window import should persist the initial visible rows")
local rotatedWindowMoneyNext = bankLedger.MergeMoneyTransactions(rotatedWindowMoneyDb, {
    scanStartedAt = 1716935700,
    transactions = {
        {
            type = "repair",
            who = "X",
            amount = 91000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
        {
            type = "repair",
            who = "Y",
            amount = 92000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
        {
            type = "repair",
            who = "Z",
            amount = 93000,
            year = 0,
            month = 0,
            day = 0,
            hour = 0,
        },
    },
})
assert.equal(3, rotatedWindowMoneyNext, "a fully rotated busy money-log window should still append the newly visible rows instead of being discarded as suspicious")
assert.equal(6, #rotatedWindowMoneyDb.bankLedger.moneyLogs, "busy money-log windows should stay append-only even when the full visible window changes between rescans")

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

local legacyMoneyReplayDb = fresh_db()
local legacyMoneyTimestamp = os.time({
    year = 2026,
    month = 6,
    day = 2,
    hour = 15,
    min = 5,
    sec = 0,
})
legacyMoneyReplayDb.bankLedger.moneyLogs = {
    {
        entryId = "money-legacy-1",
        timestamp = legacyMoneyTimestamp,
        when = legacyMoneyTimestamp,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
    },
}
local legacyMoneyReplayCount = bankLedger.MergeMoneyTransactions(legacyMoneyReplayDb, {
    scanStartedAt = legacyMoneyTimestamp + 300,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amount = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 15,
        },
    },
})
assert.equal(0, legacyMoneyReplayCount, "money rescans should not append a duplicate when a legacy stored row only differs by missing explicit minute precision")
assert.equal(1, #legacyMoneyReplayDb.bankLedger.moneyLogs, "legacy money rows should stay stable across later hour-precision rescans of the same visible Blizzard row")

local dedupePlanDb = fresh_db()
dedupePlanDb.bankLedger.itemLogs = {
    {
        entryId = "item-keep",
        timestamp = 1717287300,
        when = 1717287300,
        who = "OfficerOne-Stormrage",
        action = "Deposit",
        itemID = 300001,
        item = "Date-Less Flask",
        quantity = 8,
        tabName = "Raid Buffet",
        fromTabName = "-",
    },
    {
        entryId = "item-remove",
        timestamp = 1717287330,
        when = 1717287330,
        who = "OfficerOne-Stormrage",
        action = "Deposit",
        itemID = 300001,
        item = "Date-Less Flask",
        quantity = 8,
        tabName = "Raid Buffet",
        fromTabName = "-",
    },
    {
        entryId = "item-remove-later-scan",
        timestamp = 1717294500,
        when = 1717294500,
        who = "OfficerOne-Stormrage",
        action = "Deposit",
        itemID = 300001,
        item = "Date-Less Flask",
        quantity = 8,
        tabName = "Raid Buffet",
        fromTabName = "-",
    },
}
dedupePlanDb.bankLedger.moneyLogs = {
    {
        entryId = "money-keep",
        timestamp = 1717287300,
        when = 1717287300,
        who = "Unholy-Skullcrusher",
        action = "Repair",
        amountCopper = 839240066,
        amount = 839240066,
        year = 2024,
        month = 6,
        day = 2,
        hour = 11,
    },
    {
        entryId = "money-remove",
        timestamp = 1717287355,
        when = 1717287355,
        who = "Unholy-Skullcrusher",
        action = "Repair",
        amountCopper = 839240066,
        amount = 839240066,
        year = 2024,
        month = 6,
        day = 2,
        hour = 11,
    },
    {
        entryId = "money-remove-later-scan",
        timestamp = 1717294500,
        when = 1717294500,
        who = "Unholy-Skullcrusher",
        action = "Repair",
        amountCopper = 839240066,
        amount = 839240066,
        year = 2024,
        month = 6,
        day = 2,
        hour = 13,
    },
}
local dedupePlan = bankLedger.BuildDedupePlan(dedupePlanDb)
assert.equal(2, dedupePlan.itemDuplicateRowCount, "ledger dedupe planning should flag duplicate item rows that match the same visible ledger date")
assert.equal(2, dedupePlan.moneyDuplicateRowCount, "ledger dedupe planning should flag duplicate money rows that match the same visible ledger date, actor, action, and amount")
assert.equal(4, dedupePlan.totalDuplicateRowCount, "ledger dedupe planning should total item and money duplicate removals")
assert.equal(4, #dedupePlan.reviewRows, "ledger dedupe planning should expose review rows for every removable duplicate")
local dedupeApplied = bankLedger.ApplyDedupePlan(dedupePlanDb, dedupePlan)
assert.equal(2, dedupeApplied.itemRemoved, "ledger dedupe apply should remove duplicate item rows")
assert.equal(2, dedupeApplied.moneyRemoved, "ledger dedupe apply should remove duplicate money rows")
assert.equal(4, dedupeApplied.totalRemoved, "ledger dedupe apply should report the total removed duplicate count")
assert.equal(1, #dedupePlanDb.bankLedger.itemLogs, "ledger dedupe apply should keep one canonical item row per visible ledger row group")
assert.equal(1, #dedupePlanDb.bankLedger.moneyLogs, "ledger dedupe apply should keep one canonical money row per visible ledger row group")

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

local stalePersistedSnapshotDb = fresh_db()
stalePersistedSnapshotDb.bankLedger.itemLogs = {
    {
        entryId = "item-1",
        timestamp = 1716573600,
        when = 1716573600,
        who = "Gatherer-Stormrage",
        action = "Deposit",
        itemID = 410001,
        qualityTier = 0,
        item = "Persisted Herb Bundle",
        quantity = 9,
        tabName = "Herbs",
        tabIndex = 5,
        fromTabName = "-",
    },
}
stalePersistedSnapshotDb.bankLedger.itemSourceSnapshots = {
    ["item:5"] = {
        "stale|snapshot|one",
        "stale|snapshot|two",
    },
}
local stalePersistedSnapshotCount = bankLedger.MergeItemTransactions(stalePersistedSnapshotDb, {
    scanStartedAt = 1716574800,
    sourceTabIndex = 5,
    sourceTabName = "Herbs",
    transactions = {
        {
            type = "deposit",
            who = "Gatherer-Stormrage",
            itemID = 410002,
            itemName = "Fresh Herb Bundle",
            quantity = 4,
            year = 2026,
            month = 5,
            day = 24,
            hour = 16,
        },
        {
            type = "deposit",
            who = "Gatherer-Stormrage",
            itemID = 410001,
            itemName = "Persisted Herb Bundle",
            quantity = 9,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
})
assert.equal(1, stalePersistedSnapshotCount, "stale persisted item source snapshots should not block a real new leading row after reload")
assert.equal(2, #stalePersistedSnapshotDb.bankLedger.itemLogs, "item merges should still append the unseen row when persisted source snapshots are stale")

local stalePersistedMoneySnapshotDb = fresh_db()
stalePersistedMoneySnapshotDb.bankLedger.moneyLogs = {
    {
        entryId = "money-1",
        timestamp = 1716573600,
        when = 1716573600,
        who = "Treasurer-Stormrage",
        action = "Withdrawal",
        amountCopper = 110000000,
        amount = 110000000,
    },
}
stalePersistedMoneySnapshotDb.bankLedger.moneySourceSnapshots = {
    money = {
        "stale|money|one",
        "stale|money|two",
    },
}
local stalePersistedMoneySnapshotCount = bankLedger.MergeMoneyTransactions(stalePersistedMoneySnapshotDb, {
    scanStartedAt = 1716574800,
    transactions = {
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 120000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 16,
        },
        {
            type = "withdraw",
            who = "Treasurer-Stormrage",
            amount = 110000000,
            year = 2026,
            month = 5,
            day = 24,
            hour = 15,
        },
    },
})
assert.equal(1, stalePersistedMoneySnapshotCount, "stale persisted money source snapshots should not block a real new leading row after reload")
assert.equal(2, #stalePersistedMoneySnapshotDb.bankLedger.moneyLogs, "money merges should still append the unseen row when persisted source snapshots are stale")

local dedupeSourceStableMoneyDb = fresh_db()
dedupeSourceStableMoneyDb.bankLedger.moneySourceSnapshots = {
    money = {
        "2026|6|2|12|51|Zirleficent|withdraw|1500000000|1",
    },
}
dedupeSourceStableMoneyDb.bankLedger.moneyLogs = {
    {
        entryId = "money-old-visible-duplicate",
        timestamp = 1780415704,
        when = 1780415704,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
        fingerprint = "2026|6|2|11|55|Zirleficent|withdraw|1500000000|1",
        legacyFingerprint = "unknown|Zirleficent|withdraw|1500000000|1",
    },
    {
        entryId = "money-current-source-hour-duplicate",
        timestamp = 1780417641,
        when = 1780417641,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
        fingerprint = "2026|6|2|12|27|Zirleficent|withdraw|1500000000|1",
        legacyFingerprint = "unknown|Zirleficent|withdraw|1500000000|1",
    },
    {
        entryId = "money-later-visible-duplicate",
        timestamp = 1780422900,
        when = 1780422900,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
        fingerprint = "2026|6|2|12|55|0|Zirleficent|withdraw|1500000000|1",
        legacyFingerprint = "unknown|Zirleficent|withdraw|1500000000|1",
    },
}
local sourceStableDedupePlan = bankLedger.BuildDedupePlan(dedupeSourceStableMoneyDb)
assert.equal(2, sourceStableDedupePlan.moneyDuplicateRowCount, "money cleanup should flag same visible ledger rows before protecting source stability")
local sourceStableDedupeResult = bankLedger.ApplyDedupePlan(dedupeSourceStableMoneyDb, sourceStableDedupePlan)
assert.equal(2, sourceStableDedupeResult.moneyRemoved, "money cleanup should remove repeated visible rows")
assert.equal("money-current-source-hour-duplicate", dedupeSourceStableMoneyDb.bankLedger.moneyLogs[1].entryId, "money cleanup should keep the row whose hour still matches the current source snapshot")
assert.equal(0, bankLedger.MergeMoneyTransactions(dedupeSourceStableMoneyDb, {
    scanStartedAt = 1780453860,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 51,
        },
    },
}), "a money scan after cleanup should not reimport the same visible source row")

local dedupeRelativeMoneyDb = fresh_db()
dedupeRelativeMoneyDb.bankLedger.moneyLogs = {
    {
        entryId = "money-original-relative-row",
        timestamp = 1780540360,
        when = 1780540360,
        who = "Zerobrews",
        action = "Repair",
        amountCopper = 1874304,
        amount = 1874304,
        year = 0,
        month = 0,
        day = 0,
        hour = 21,
        fingerprint = "2026|6|3|22|32|Zerobrews|withdraw|1874304|1",
        legacyFingerprint = "unknown|Zerobrews|withdraw|1874304|1",
    },
    {
        entryId = "money-later-relative-row",
        timestamp = 1780594903,
        when = 1780594903,
        who = "Zerobrews",
        action = "Repair",
        amountCopper = 1874304,
        amount = 1874304,
        year = 0,
        month = 0,
        day = 0,
        hour = 21,
        fingerprint = "2026|6|4|13|41|Zerobrews|withdraw|1874304|1",
        legacyFingerprint = "unknown|Zerobrews|withdraw|1874304|1",
    },
}
local relativeMoneyDedupePlan = bankLedger.BuildDedupePlan(dedupeRelativeMoneyDb)
assert.equal(1, relativeMoneyDedupePlan.moneyDuplicateRowCount, "money cleanup should flag duplicate raw relative Blizzard rows even when their minted timestamps differ")
local relativeMoneyDedupeResult = bankLedger.ApplyDedupePlan(dedupeRelativeMoneyDb, relativeMoneyDedupePlan)
assert.equal(1, relativeMoneyDedupeResult.moneyRemoved, "money cleanup should remove duplicated raw relative Blizzard money rows")
assert.equal(1, #dedupeRelativeMoneyDb.bankLedger.moneyLogs, "money cleanup should leave one canonical raw relative Blizzard money row")

local dedupeDriftedRelativeMoneyDb = fresh_db()
dedupeDriftedRelativeMoneyDb.bankLedger.moneyLogs = {
    {
        entryId = "money-original-relative-hour",
        timestamp = 1780626109,
        when = 1780626109,
        who = "Zerobrews",
        action = "Repair",
        amountCopper = 5779554,
        amount = 5779554,
        year = 0,
        month = 0,
        day = 0,
        hour = 12,
        fingerprint = "2026|6|4|22|21|Zerobrews|withdraw|5779554|1",
        legacyFingerprint = "unknown|Zerobrews|withdraw|5779554|1",
    },
    {
        entryId = "money-drifted-relative-hour",
        timestamp = 1780624777,
        when = 1780624777,
        who = "Zerobrews",
        action = "Repair",
        amountCopper = 5779554,
        amount = 5779554,
        year = 0,
        month = 0,
        day = 0,
        hour = 15,
        fingerprint = "2026|6|4|21|59|Zerobrews|withdraw|5779554|1",
        legacyFingerprint = "unknown|Zerobrews|withdraw|5779554|1",
    },
}
local driftedRelativeMoneyDedupePlan = bankLedger.BuildDedupePlan(dedupeDriftedRelativeMoneyDb)
assert.equal(1, driftedRelativeMoneyDedupePlan.moneyDuplicateRowCount, "money cleanup should flag raw relative rows whose bridged visible hour drifted")
local driftedRelativeMoneyDedupeResult = bankLedger.ApplyDedupePlan(dedupeDriftedRelativeMoneyDb, driftedRelativeMoneyDedupePlan)
assert.equal(1, driftedRelativeMoneyDedupeResult.moneyRemoved, "money cleanup should remove relative rows that still share the same legacy source fingerprint")
assert.equal(1, #dedupeDriftedRelativeMoneyDb.bankLedger.moneyLogs, "money cleanup should leave one canonical drifted raw relative money row")

local dedupeTimezoneStableMoneyDb = fresh_db()
dedupeTimezoneStableMoneyDb.bankLedger.moneySourceSnapshots = {
    money = {
        "2026|6|2|12|51|Zirleficent|withdraw|1500000000|1",
    },
}
dedupeTimezoneStableMoneyDb.bankLedger.moneyLogs = {
    {
        entryId = "money-old-visible-duplicate",
        timestamp = 1780415704,
        when = 1780415704,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
        fingerprint = "2026|6|2|11|55|Zirleficent|withdraw|1500000000|1",
        legacyFingerprint = "unknown|Zirleficent|withdraw|1500000000|1",
    },
    {
        entryId = "money-current-source-hour-duplicate",
        timestamp = 1780417641,
        when = 1780417641,
        who = "Zirleficent",
        action = "Withdrawal",
        amountCopper = 1500000000,
        amount = 1500000000,
        fingerprint = "2026|6|2|12|27|Zirleficent|withdraw|1500000000|1",
        legacyFingerprint = "unknown|Zirleficent|withdraw|1500000000|1",
    },
}
local originalDate = _G.date
_G.date = function(format, timestamp)
    if format == "*t" then
        return os.date("!*t", timestamp)
    end
    return os.date(format, timestamp)
end
local timezoneStableDedupePlan = bankLedger.BuildDedupePlan(dedupeTimezoneStableMoneyDb)
local timezoneStableDedupeResult = bankLedger.ApplyDedupePlan(dedupeTimezoneStableMoneyDb, timezoneStableDedupePlan)
local timezoneStableRepeatCount = bankLedger.MergeMoneyTransactions(dedupeTimezoneStableMoneyDb, {
    scanStartedAt = 1780453860,
    transactions = {
        {
            type = "withdraw",
            who = "Zirleficent",
            amountCopper = 1500000000,
            year = 2026,
            month = 6,
            day = 2,
            hour = 12,
            minute = 51,
        },
    },
})
_G.date = originalDate
assert.equal(1, timezoneStableDedupeResult.moneyRemoved, "money cleanup should remove one visible duplicate under a UTC-style test runner")
assert.equal("money-current-source-hour-duplicate", dedupeTimezoneStableMoneyDb.bankLedger.moneyLogs[1].entryId, "money cleanup should use stored row fingerprints instead of runner timezone when protecting source-stable rows")
assert.equal(0, timezoneStableRepeatCount, "money cleanup should not reimport the same visible source row under a UTC-style test runner")
assert.equal(1, #dedupeSourceStableMoneyDb.bankLedger.moneyLogs, "money cleanup should stay stable after the next scan")

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

local originalDate = _G.date
_G.date = function(formatString, timestamp)
    if formatString == "%Y-%m-%d %H:%M" and tonumber(timestamp) == 1779894357 then
        return "2026-05-26 22:25"
    end
    if formatString == "%Z" and tonumber(timestamp) == 1779894357 then
        return "Eastern Daylight Time"
    end
    if type(originalDate) == "function" then
        return originalDate(formatString, timestamp)
    end
    return tostring(timestamp or 0)
end

local csvTimestampDb = fresh_db()
csvTimestampDb.bankLedger.itemLogs = {
    {
        entryId = "item-export-1",
        timestamp = 1779894357,
        when = 1779894357,
        who = "Zirleficent",
        action = "Deposit",
        itemID = 245795,
        qualityTier = 1,
        item = "Contract: The Hara'ti",
        quantity = 2,
        tabName = "Freebiez",
        fromTabName = "-",
    },
}
local timestampCsvText = bankLedger.ExportRowsToCsv(csvTimestampDb, "ITEM", {
    dateFrom = 0,
    dateTo = 9999999999,
})
assert.truthy(string.find(timestampCsvText, "2026%-05%-26 22:25 EDT,Zirleficent,Deposit,245795,1,Contract: The Hara'ti,2,Freebiez,%-") ~= nil, "ledger csv export should format timestamps as readable date time text instead of raw integers")
_G.date = originalDate

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
