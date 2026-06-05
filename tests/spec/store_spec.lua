local assert = require("tests.helpers.assert")
_G.GBankManagerItemSearchPayload = nil
_G.GBankManagerItemCatalogData = nil
_G.GBankManagerDB = {
    meta = {
        guildName = "Existing Guild",
        schemaVersion = 1,
        ledgerClearedForVersion = "1.2.0",
    },
    bankLedger = {
        itemLogs = {
            { entryId = "item-preserved", timestamp = 1780540000 },
        },
        moneyLogs = {
            {
                entryId = "money-preload-original",
                timestamp = 1780540360,
                who = "Zerobrews",
                action = "Repair",
                amountCopper = 1874304,
                amount = 1874304,
                hour = 21,
                legacyFingerprint = "unknown|Zerobrews|withdraw|1874304|1",
            },
            {
                entryId = "money-preload-duplicate",
                timestamp = 1780594903,
                who = "Zerobrews",
                action = "Repair",
                amountCopper = 1874304,
                amount = 1874304,
                hour = 22,
                legacyFingerprint = "unknown|Zerobrews|withdraw|1874304|1",
            },
        },
    },
}

local addonName, ns, loaded = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
_G.GBankManagerItemSearchPayload = nil
_G.GBankManagerItemCatalogData = nil
ns.data.staticItemSearch = nil
ns.data.staticItemCatalog = nil
ns.modules.staticItemSearch = nil
ns.modules.staticItemCatalog = nil
local store = ns.modules.store
local permissions = ns.modules.permissions
local migrations = ns.modules.migrations
local scanner = ns.modules.scanner
local events = ns.modules.events
local itemCatalog = ns.modules.itemCatalog
local defaults = ns.modules.defaults

local function table_count(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local db = store and store.CreateFreshDatabase("My Guild")
local normalizedMalformed = migrations and migrations.Apply({
    meta = "broken",
    syncState = "broken",
})
local futureDb = {
    meta = {
        schemaVersion = 99,
        guildName = "Future Guild",
    },
    syncState = "broken",
}
local normalizedFuture = migrations and migrations.Apply(futureDb)
local isolatedRoot = store and store.Normalize({
    guilds = {
        ["Guild Testers"] = defaults.CreateDatabase("Guild Testers"),
        ["Bank Alts"] = defaults.CreateDatabase("Bank Alts"),
    },
    activeGuildKey = "Guild Testers",
}, "Guild Testers")
local legacyRoot = store and store.Normalize({
    meta = { guildName = "Legacy Guild" },
    requests = {
        { requestId = "legacy-1" },
    },
}, "Legacy Guild")

local loadedByPath = {}
for _, entry in ipairs(loaded) do
    loadedByPath[entry.path] = entry.value
end

assert.equal("GBankManager", addonName, "toc should load the addon by name")
assert.equal("GBankManager", ns.addonName, "namespace should expose addon name")
assert.truthy(type(ns.modules) == "table", "namespace should expose module table")
assert.truthy(type(ns.state) == "table", "namespace should expose state table")
assert.truthy(type(ns.constants) == "table", "constants should populate the shared namespace")
assert.equal(1, ns.constants.SCHEMA_VERSION, "constants should expose schema version")
assert.equal(3, ns.constants.LEDGER_PROTOCOL_VERSION, "constants should expose the 1.2.3 ledger cleanup protocol version")
assert.truthy(type(ns.modules.events) == "table", "events module should populate the shared namespace")
assert.truthy(type(ns.modules.slash) == "table", "slash module should populate the shared namespace")
assert.same(ns, loadedByPath["GBankManager/Core/Namespace.lua"], "namespace chunk should return the shared namespace table")
assert.same(ns.modules.store, loadedByPath["GBankManager/Data/Store.lua"], "store chunk should return the shared store module")
assert.same(ns.modules.permissions, loadedByPath["GBankManager/Domain/Permissions.lua"], "permissions chunk should return the shared permissions module")
assert.same(ns, loadedByPath["GBankManager/Bootstrap.lua"], "bootstrap chunk should return the shared namespace table")
assert.same(ns.modules.events, loadedByPath["GBankManager/Core/Events.lua"], "events chunk should return the shared events module")
assert.same(ns.modules.slash, loadedByPath["GBankManager/Core/SlashCommands.lua"], "slash chunk should return the shared slash module")
assert.truthy(type(store) == "table", "store module should be loaded for specs")
assert.truthy(type(permissions) == "table", "permissions module should be loaded for specs")
assert.truthy(type(migrations) == "table", "migrations module should be loaded for specs")
assert.truthy(type(scanner) == "table", "scanner module should be loaded for specs")
assert.equal(1, (function()
    local count = 0
    for line in io.lines("GBankManager/GBankManager.toc") do
        if line == "## LoadSavedVariablesFirst: 1" then
            count = count + 1
        end
    end
    return count
end)(), "toc should load saved variables before addon lua files")
assert.truthy(type(store.GetDatabase) == "function", "store should expose a shared database accessor")
assert.truthy(type(store.GetCurrentSnapshot) == "function", "store should expose a current snapshot accessor")
assert.truthy(type(store.GetUiState) == "function", "store should expose a shared ui-state accessor")
assert.truthy(type(store.GetInventoryColumnWidths) == "function", "store should expose saved inventory column-width access")
assert.truthy(type(store.GetMinimumSettings) == "function", "store should expose minimum-settings access")
assert.truthy(type(store.GetMinimumItemCatalog) == "function", "store should expose the saved minimum item catalog")
assert.truthy(type(store.GetExportSettings) == "function", "store should expose export-settings access")
assert.truthy(type(store.GetAppearanceSettings) == "function", "store should expose appearance-settings access")
assert.truthy(type(itemCatalog) == "table", "item catalog module should load from the toc")
assert.truthy(itemCatalog.IsBundledDataLoaded() ~= true, "bundled item data should remain unloaded until a search path requests it")
local preloadedDb = (((_G.GBankManagerDB or {}).guilds or {})["Existing Guild"] or {})
assert.equal("1.2.3-money-v5", tostring(((preloadedDb.meta or {}).moneyLedgerDedupedForVersion or "")), "bootstrap should normalize preloaded saved variables before addon events fire")
assert.equal(1, #(((preloadedDb.bankLedger or {}).itemLogs) or {}), "bootstrap money cleanup should preserve preloaded item ledger rows")
assert.equal(1, #(((preloadedDb.bankLedger or {}).moneyLogs) or {}), "bootstrap money cleanup should dedupe preloaded raw-relative money rows")
assert.truthy(type(db) == "table", "fresh db should be created")
assert.equal(1, db.meta.schemaVersion, "fresh db should use schema version 1")
assert.equal("My Guild", db.meta.guildName, "guild name should be stored")
assert.truthy(db.requests ~= nil, "requests table should exist")
assert.truthy(type(db.bankLedger) == "table", "fresh db should include a bank ledger container")
assert.truthy(type(db.testing) == "table", "fresh db should include a testing container for smoke persistence")
assert.truthy(type(db.testing.liveSmoke) == "table", "fresh db should include a live-smoke persistence container")
assert.truthy(type(db.testing.inGameUnit) == "table", "fresh db should include an in-game-unit persistence container")
assert.equal("NEVER", db.testing.liveSmoke.status, "fresh db should default live smoke status to NEVER")
assert.equal("NEVER", db.testing.inGameUnit.status, "fresh db should default in-game unit status to NEVER")
assert.truthy(type(isolatedRoot.guilds) == "table", "normalized root should expose guild buckets")
assert.equal("Guild Testers", isolatedRoot.activeGuildKey, "active guild key should track the requested guild")
assert.equal("Guild Testers", isolatedRoot.guilds["Guild Testers"].meta.guildName, "requested guild bucket should preserve guild metadata")
assert.equal("Bank Alts", isolatedRoot.guilds["Bank Alts"].meta.guildName, "other guild buckets should remain isolated")
assert.truthy(type(legacyRoot.guilds) == "table", "legacy single-db saves should migrate into guild buckets")
assert.equal("legacy-1", (((legacyRoot.guilds["Legacy Guild"] or {}).requests or {})[1] or {}).requestId, "legacy requests should move into the migrated guild bucket")
assert.truthy(permissions.CanApproveRequests("OFFICER"), "officers should approve requests")
assert.truthy(not permissions.CanViewInventory("MEMBER"), "members should not view inventory")
store.GetDatabase("My Guild")
assert.same(((_G.GBankManagerDB.guilds or {})["My Guild"]), ns.state.db, "addon loaded should keep the active guild db in addon state")
assert.equal(1, (((_G.GBankManagerDB.guilds or {})["My Guild"] or {}).meta or {}).schemaVersion, "addon loaded should normalize schema version at runtime")
assert.truthy((((_G.GBankManagerDB.guilds or {})["My Guild"] or {}).requests) ~= nil, "addon loaded should normalize missing tables at runtime")
assert.equal(0, ((((_G.GBankManagerDB.guilds or {})["My Guild"] or {}).meta or {}).lastScanSequence), "addon loaded should normalize the scan sequence counter at runtime")
assert.truthy(type(((normalizedMalformed.guilds or {}).Unknown or {}).meta) == "table", "migrations should repair malformed meta containers")
assert.truthy(type(((normalizedMalformed.guilds or {}).Unknown or {}).syncState) == "table", "migrations should repair malformed sync state containers")
assert.equal(1, (((normalizedMalformed.guilds or {}).Unknown or {}).meta or {}).schemaVersion, "migrations should apply v1 schema to malformed data")
assert.same(futureDb, normalizedFuture, "migrations should return the same table for newer schemas")
assert.equal(99, normalizedFuture.meta.schemaVersion, "migrations should preserve newer schema versions")
assert.equal("Future Guild", normalizedFuture.meta.guildName, "migrations should preserve newer schema metadata")
assert.truthy((((_G.GBankManagerDB.guilds or {})["My Guild"] or {}).auditLog) ~= nil, "addon loaded should normalize the audit log container at runtime")

local persisted = store.Normalize({
    meta = {
        schemaVersion = 1,
        guildName = "Persisted Guild",
        updatedAt = 77,
    },
    currentSnapshotId = "scan-old",
    snapshots = {
        ["scan-old"] = {
            scanId = "scan-old",
            scannedAt = 77,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 5, tabs = { Flasks = 5 } },
            },
        },
    },
    changeLog = {},
    minimums = {},
    oneTimeTargets = {},
    requests = {},
    exportTemplates = {},
    syncState = {
        lastSyncAt = 22,
    },
})
local persistedDb = (persisted.guilds or {})["Persisted Guild"] or {}

assert.equal("scan-old", persistedDb.currentSnapshotId, "normalize should preserve the current snapshot id across reloads")
assert.equal(5, persistedDb.snapshots["scan-old"].items[1001].totalCount, "normalize should preserve scanned inventory rows across reloads")
assert.equal(77, persistedDb.meta.updatedAt, "normalize should preserve last scan metadata across reloads")
assert.truthy(type(persistedDb.auditLog) == "table", "normalize should preserve an audit log container for workflow history")
assert.truthy(type(persistedDb.ui) == "table", "normalize should preserve a ui settings container")
assert.truthy(type(persistedDb.ui.exportSettings) == "table", "normalize should preserve export ui settings")
assert.truthy(type(persistedDb.ui.appearance) == "table", "normalize should preserve appearance ui settings")
assert.truthy(type(persistedDb.ui.inventoryColumnWidths) == "table", "normalize should preserve inventory column width settings")
assert.truthy(type(persistedDb.ui.minimumSettings) == "table", "normalize should preserve minimum ui settings")
assert.truthy(type(persistedDb.ui.logsHistorySettings) == "table", "normalize should preserve logs/history ui settings")
assert.truthy(type(persistedDb.ui.minimumItemCatalog) == "table", "normalize should preserve the saved minimum item catalog")
assert.truthy(type(persistedDb.testing) == "table", "normalize should preserve the testing container")
assert.truthy(type(persistedDb.testing.liveSmoke) == "table", "normalize should preserve the live-smoke persistence container")
assert.truthy(type(persistedDb.testing.inGameUnit) == "table", "normalize should preserve the in-game-unit persistence container")
assert.equal(100, persistedDb.ui.minimumSettings.defaultQuantity, "normalize should seed the default minimum quantity setting")
assert.equal(50, persistedDb.ui.minimumSettings.criticalThresholdPercent, "normalize should seed the default critical shortage threshold percentage")
assert.equal("indefinite", persistedDb.ui.logsHistorySettings.ledgerRetention, "normalize should seed the default ledger retention setting")
assert.equal("indefinite", persistedDb.ui.logsHistorySettings.historyRetention, "normalize should seed the default history retention setting")
assert.equal(300, persistedDb.ui.logsHistorySettings.ledgerScanIntervalSeconds, "normalize should seed the default ledger scan interval")
assert.equal(100, db.ui.minimumSettings.defaultQuantity, "fresh databases should default minimum quantity to 100")
assert.equal("generic_wow", persistedDb.ui.appearance.themePreset, "normalize should seed the default appearance theme preset")
assert.equal(1, persistedDb.ui.appearance.shellScale, "normalize should seed the default shell scale")
assert.equal(1, persistedDb.ui.appearance.tableDensity, "normalize should seed the default table density")
assert.same(persistedDb.ui, store.GetUiState(persisted), "store ui-state accessor should return the normalized ui container")
assert.same(persistedDb.ui.inventoryColumnWidths, store.GetInventoryColumnWidths(persisted), "store should return the normalized inventory column-width table")
assert.same(persistedDb.ui.minimumSettings, store.GetMinimumSettings(persisted), "store should return the normalized minimum-settings table")
assert.same(persistedDb.ui.minimumItemCatalog, store.GetMinimumItemCatalog(persisted), "store should return the normalized minimum item catalog")
assert.same(persistedDb.ui.exportSettings, store.GetExportSettings(persisted), "store should return the normalized export-settings table")
assert.same(persistedDb.ui.appearance, store.GetAppearanceSettings(persisted), "store should return the normalized appearance-settings table")
assert.same(persistedDb.snapshots["scan-old"], store.GetCurrentSnapshot(persisted), "store current snapshot accessor should resolve the active snapshot row")

local compactedRoot = store.Normalize({
    activeGuildKey = "Compact Guild",
    guilds = {
        ["Compact Guild"] = {
            meta = {
                schemaVersion = 1,
                guildName = "Compact Guild",
                ledgerClearedForVersion = "1.2.0",
                moneyLedgerDedupedForVersion = "1.2.3-money-v5",
            },
            currentSnapshotId = "scan-current",
            snapshots = {
                ["scan-current"] = {
                    scanId = "scan-current",
                    scannedAt = 1717000000,
                    items = {
                        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 5 },
                    },
                    searchCatalog = {
                        { itemID = 1001, name = "Flask Alpha" },
                    },
                },
                ["scan-old"] = {
                    scanId = "scan-old",
                    scannedAt = 1716900000,
                    items = {
                        [1002] = { itemID = 1002, name = "Flask Beta", totalCount = 2 },
                    },
                    searchCatalog = {
                        { itemID = 1002, name = "Flask Beta" },
                    },
                },
                ["scan-recent"] = {
                    scanId = "scan-recent",
                    scannedAt = 1717100000,
                    items = {
                        [1003] = { itemID = 1003, name = "Flask Gamma", totalCount = 3 },
                    },
                    searchCatalog = {
                        { itemID = 1003, name = "Flask Gamma" },
                    },
                },
                ["scan-newest"] = {
                    scanId = "scan-newest",
                    scannedAt = 1717200000,
                    items = {
                        [1004] = { itemID = 1004, name = "Flask Delta", totalCount = 4 },
                    },
                    searchCatalog = {
                        { itemID = 1004, name = "Flask Delta" },
                    },
                },
                ["scan-ancient"] = {
                    scanId = "scan-ancient",
                    scannedAt = 1716800000,
                    items = {
                        [1005] = { itemID = 1005, name = "Flask Epsilon", totalCount = 1 },
                    },
                    searchCatalog = {
                        { itemID = 1005, name = "Flask Epsilon" },
                    },
                },
            },
            changeLog = {},
            bankLedger = {
                itemLogs = {},
                moneyLogs = {},
            },
        },
    },
}, "Compact Guild")
local compactedDb = (compactedRoot.guilds or {})["Compact Guild"] or {}
assert.equal("1.2.3-snapshot-v2", tostring((compactedDb.meta or {}).savedVariablesCompactedForVersion or ""), "snapshot compaction should stamp the saved-variable compaction marker")
assert.equal(nil, ((compactedDb.snapshots or {})["scan-current"] or {}).searchCatalog, "snapshot compaction should remove generated search catalogs from the current snapshot")
assert.equal(nil, ((compactedDb.snapshots or {})["scan-newest"] or {}).searchCatalog, "snapshot compaction should remove generated search catalogs from retained historical snapshots")
assert.equal(3, table_count(compactedDb.snapshots or {}), "snapshot compaction should keep only the current inventory snapshot plus two recent backups")
assert.truthy(((compactedDb.snapshots or {})["scan-current"] ~= nil), "snapshot compaction should always keep the current inventory snapshot")
assert.truthy(((compactedDb.snapshots or {})["scan-newest"] ~= nil), "snapshot compaction should keep the newest historical inventory snapshot")
assert.truthy(((compactedDb.snapshots or {})["scan-recent"] ~= nil), "snapshot compaction should keep the second-newest historical inventory snapshot")
assert.equal(nil, (compactedDb.snapshots or {})["scan-old"], "snapshot compaction should remove older historical inventory snapshots")
assert.equal(nil, (compactedDb.snapshots or {})["scan-ancient"], "snapshot compaction should remove ancient historical inventory snapshots")
assert.equal(5, (((compactedDb.snapshots or {})["scan-current"] or {}).items or {})[1001].totalCount, "snapshot compaction should preserve current inventory items")
assert.equal(4, (((compactedDb.snapshots or {})["scan-newest"] or {}).items or {})[1004].totalCount, "snapshot compaction should preserve retained historical inventory items")

local resetRoot = store.Normalize({
    activeGuildKey = "Reset Guild",
    guilds = {
        ["Reset Guild"] = {
            meta = {
                schemaVersion = 1,
                guildName = "Reset Guild",
            },
            bankLedger = {
                itemLogs = {
                    { entryId = "item-polluted", timestamp = 1716500000 },
                },
                moneyLogs = {
                    { entryId = "money-polluted", timestamp = 1716500000 },
                },
                itemFingerprints = {
                    ["polluted-item"] = true,
                },
                moneyFingerprints = {
                    ["polluted-money"] = true,
                },
                itemSourceSnapshots = {
                    ["item:1"] = { "polluted-source" },
                },
                moneySourceSnapshots = {
                    money = { "polluted-money-source" },
                },
                nextEntrySequence = 99,
                lastScanAt = 1716500000,
                lastItemScanAt = 1716500000,
                lastMoneyScanAt = 1716500000,
            },
            syncState = {
                peers = {
                    ["Guild Testers"] = {
                        ["MemberOne-Stormrage"] = { lastSeen = 10 },
                    },
                },
                ledgerDigest = { hash = "old-hash" },
                ledgerPeerDigests = { ["MemberOne-Stormrage"] = { hash = "old-peer-hash" } },
                ledgerBucketManifests = { ["MemberOne-Stormrage"] = { globalHash = "old-global" } },
                ledgerPendingBucketRequests = { ["request-1"] = true },
            },
        },
    },
}, "Reset Guild")
local resetDb = (resetRoot.guilds or {})["Reset Guild"] or {}
assert.equal("1.2.0", tostring((resetDb.meta or {}).ledgerClearedForVersion or ""), "1.2.0 should stamp the ledger reset marker")
assert.equal(0, #(resetDb.bankLedger.itemLogs or {}), "1.2.0 reset should clear old item ledger rows")
assert.equal(0, #(resetDb.bankLedger.moneyLogs or {}), "1.2.0 reset should clear old money ledger rows")
assert.truthy(((resetDb.syncState or {}).peers or {})["Guild Testers"], "general sync peers should survive the ledger reset")
assert.equal(nil, ((resetDb.syncState or {}).ledgerDigest), "ledger digest sync state should reset")
assert.equal(nil, ((resetDb.syncState or {}).ledgerPeerDigests), "peer ledger digest sync state should reset")
assert.equal(nil, ((resetDb.syncState or {}).ledgerBucketManifests), "ledger bucket manifest state should reset")
assert.equal(nil, ((resetDb.syncState or {}).ledgerPendingBucketRequests), "ledger bucket request state should reset")

resetDb.bankLedger.itemLogs = {
    { entryId = "item-after-reset", timestamp = 1716600000 },
}
local resetRootRepeat = store.Normalize(resetRoot, "Reset Guild")
local resetDbRepeat = (resetRootRepeat.guilds or {})["Reset Guild"] or {}
assert.equal(1, #(resetDbRepeat.bankLedger.itemLogs or {}), "store normalization should not clear ledger rows again once the version marker is present")

local moneyCleanupRoot = store.Normalize({
    activeGuildKey = "Money Cleanup Guild",
    guilds = {
        ["Money Cleanup Guild"] = {
            meta = {
                schemaVersion = 1,
                guildName = "Money Cleanup Guild",
                ledgerClearedForVersion = "1.2.0",
            },
            bankLedger = {
                itemLogs = {
                    { entryId = "item-keep-1", timestamp = 1780540000 },
                    { entryId = "item-keep-2", timestamp = 1780543600 },
                },
                moneyLogs = {
                    {
                        entryId = "money-relative-original",
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
                    },
                    {
                        entryId = "money-relative-duplicate",
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
                    },
                    {
                        entryId = "money-real-later",
                        timestamp = 1780598503,
                        when = 1780598503,
                        who = "Zerobrews",
                        action = "Repair",
                        amountCopper = 1874304,
                        amount = 1874304,
                        year = 0,
                        month = 0,
                        day = 0,
                        hour = 20,
                    },
                },
                moneyFingerprints = {
                    ["polluted-money"] = true,
                },
                moneySourceSnapshots = {
                    money = { "polluted-money-source" },
                },
            },
            syncState = {
                peers = {
                    ["Money Cleanup Guild"] = {
                        ["MemberOne-Stormrage"] = { lastSeen = 10 },
                    },
                },
                ledgerLastManifest = { reason = "different" },
                ledgerLastBucketRequest = { buckets = { 1 } },
                ledgerLastBucketReply = { merged = 1 },
            },
        },
    },
}, "Money Cleanup Guild")
local moneyCleanupDb = (moneyCleanupRoot.guilds or {})["Money Cleanup Guild"] or {}
assert.equal("1.2.3-money-v5", tostring((moneyCleanupDb.meta or {}).moneyLedgerDedupedForVersion or ""), "1.2.3-money-v5 should stamp the money-ledger cleanup marker")
assert.equal(2, #(moneyCleanupDb.bankLedger.itemLogs or {}), "money-ledger cleanup should preserve item ledger rows")
assert.equal(2, #(moneyCleanupDb.bankLedger.moneyLogs or {}), "money-ledger cleanup should remove only duplicate money rows")
assert.equal("money-relative-original", tostring(((moneyCleanupDb.bankLedger.moneyLogs or {})[1] or {}).entryId or ""), "money-ledger cleanup should keep the first matching visible money row")
assert.equal("money-real-later", tostring(((moneyCleanupDb.bankLedger.moneyLogs or {})[2] or {}).entryId or ""), "money-ledger cleanup should preserve a different visible relative-hour money row")
assert.equal(nil, next((moneyCleanupDb.bankLedger.moneyFingerprints or {})), "money-ledger cleanup should clear polluted money fingerprints so they rebuild from kept rows")
assert.equal(nil, next((moneyCleanupDb.bankLedger.moneySourceSnapshots or {})), "money-ledger cleanup should clear polluted money source snapshots")
assert.truthy(((moneyCleanupDb.syncState or {}).peers or {})["Money Cleanup Guild"], "money-ledger cleanup should preserve general sync peers")
assert.equal(nil, (moneyCleanupDb.syncState or {}).ledgerLastManifest, "money-ledger cleanup should clear stale ledger manifest debug state")

local moneyCleanupRepeatRoot = store.Normalize(moneyCleanupRoot, "Money Cleanup Guild")
local moneyCleanupRepeatDb = (moneyCleanupRepeatRoot.guilds or {})["Money Cleanup Guild"] or {}
assert.equal(2, #(moneyCleanupRepeatDb.bankLedger.moneyLogs or {}), "money-ledger cleanup should not run again after the marker is stamped")

persistedDb.requests = {
    {
        requestId = "scan-fulfill-1",
        requester = "MemberOne",
        itemID = 1001,
        itemName = "Flask Alpha",
        quantity = 10,
        approval = "APPROVED",
        fulfillment = "OPEN",
    },
}
persistedDb.snapshots["scan-recent-a"] = {
    scanId = "scan-recent-a",
    scannedAt = 1715523100,
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 6, tabs = { Flasks = 6 } },
    },
}
persistedDb.snapshots["scan-recent-b"] = {
    scanId = "scan-recent-b",
    scannedAt = 1715523200,
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 7, tabs = { Flasks = 7 } },
    },
}
_G.GBankManagerDB = persisted
ns.state.dbRoot = persisted
ns.state.db = persistedDb
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        slots = {
            { itemID = 1001, name = "Flask Alpha", count = 8 },
        },
    },
    {
        index = 2,
        name = "Raid",
        slots = {
            { itemID = 1001, name = "Flask Alpha", count = 3 },
        },
    },
}

local originalTime = _G.time
local capturedTimes = {
    1715523300,
    1715523360,
}
local capturedTimeIndex = 0
_G.time = function()
    capturedTimeIndex = capturedTimeIndex + 1
    return capturedTimes[capturedTimeIndex] or capturedTimes[#capturedTimes]
end

local newSnapshot, changes = scanner.FinishScan("OfficerOne", "Persisted Guild")
_G.time = originalTime

assert.truthy(newSnapshot.scanId ~= "scan-old", "a fresh scan should create a new snapshot id")
assert.truthy(string.find(newSnapshot.scanId, "^1715523300%-"), "fresh scans should derive collision-safe snapshot ids from the captured UTC scan timestamp")
assert.equal(1715523300, newSnapshot.scannedAt, "fresh scans should persist the captured UTC scan timestamp on the snapshot")
assert.equal(newSnapshot.scanId, (((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).currentSnapshotId), "fresh scans should move the current snapshot pointer forward")
assert.equal(nil, (((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})["scan-old"], "fresh scans should prune older inventory snapshots after the rolling retention window is full")
assert.equal(3, table_count((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})), "fresh scans should keep only the new current snapshot plus two recent backups")
assert.equal(6, ((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})["scan-recent-a"] or {}).items[1001].totalCount, "fresh scans should retain the second newest backup snapshot")
assert.equal(7, ((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})["scan-recent-b"] or {}).items[1001].totalCount, "fresh scans should retain the newest backup snapshot")
assert.equal(11, (((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).items or {})[1001].totalCount, "fresh scans should store the new inventory snapshot in saved variables")
assert.equal(2, #(((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).itemRows or {}), "fresh scans should persist tab-scoped item rows in saved variables")
assert.equal("Flasks", ((((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).itemRows or {})[1] or {}).tabName, "fresh scans should persist the first tab-scoped item row")
assert.equal(8, ((((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).itemRows or {})[1] or {}).quantity, "fresh scans should persist the first tab-scoped quantity")
assert.equal("Raid", ((((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).itemRows or {})[2] or {}).tabName, "fresh scans should persist the second tab-scoped item row")
assert.equal(3, ((((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[newSnapshot.scanId] or {}).itemRows or {})[2] or {}).quantity, "fresh scans should persist the second tab-scoped quantity")
assert.equal(1715523300, ((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).meta or {}).updatedAt), "fresh scans should persist the captured UTC scan timestamp as last-scan metadata")
assert.truthy(#changes >= 1, "fresh scans should still produce diff history against the prior saved snapshot")
assert.equal("FULFILLED", (((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).requests or {})[1].fulfillment, "fresh scans should auto-fulfill approved requests once inventory meets the request amount")
assert.equal(1715523300, (((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).requests or {})[1].fulfillmentUpdatedAt, "fresh scans should store date fulfilled from the scan timestamp")

_G.GBankManagerDB = store.Normalize({
    meta = {
        schemaVersion = 1,
        guildName = "Persisted Guild",
        updatedAt = 77,
    },
    currentSnapshotId = "scan-old",
    snapshots = {
        ["scan-old"] = {
            scanId = "scan-old",
            scannedAt = 77,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 5, tabs = { Flasks = 5 } },
            },
        },
    },
    changeLog = {},
    minimums = {},
    oneTimeTargets = {},
    requests = {},
    exportTemplates = {},
    syncState = {
        lastSyncAt = 22,
    },
})
ns.state.db = {
    meta = {
        guildName = "Detached Runtime",
    },
}
ns.state.dbRoot = nil
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        slots = {
            { itemID = 1001, name = "Flask Alpha", count = 9 },
        },
    },
}

_G.time = function()
    return 1715523420
end
local reboundSnapshot = scanner.FinishScan("OfficerOne", "Persisted Guild")

assert.same(((_G.GBankManagerDB.guilds or {})["Persisted Guild"]), ns.state.db, "scanner should rebind runtime state back onto the active guild db before writing")
assert.truthy((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})["scan-old"] ~= nil, "scanner should preserve prior saved snapshots even if runtime state drifted")
assert.equal(9, (((((_G.GBankManagerDB.guilds or {})["Persisted Guild"] or {}).snapshots or {})[reboundSnapshot.scanId] or {}).items or {})[1001].totalCount, "scanner should append the new snapshot onto the persisted saved-variables history")

_G.GBankManagerDB = {}
ns.state.dbRoot = persisted
ns.state.db = persistedDb

local reboundDb = store.GetDatabase("Persisted Guild")

assert.same(persistedDb, reboundDb, "store database accessor should prefer the populated runtime state when the saved-variables global is empty")
assert.same(persisted, _G.GBankManagerDB, "store database accessor should keep the saved-variables root aligned")
assert.same(persistedDb, ns.state.db, "store database accessor should keep the active guild db aligned in runtime state")

local clearDb = store.Normalize({
    meta = {
        schemaVersion = 1,
        guildName = "Persisted Guild",
        updatedAt = 88,
        lastScanSequence = 12,
    },
    currentSnapshotId = "scan-clear",
    snapshots = {
        ["scan-clear"] = {
            scanId = "scan-clear",
            scannedAt = 88,
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 7 },
            },
        },
    },
    changeLog = {
        { type = "SNAPSHOT_DIFF", timestamp = 88 },
    },
    requests = {
        {
            requestId = "req-open",
            approval = "PENDING",
            fulfillment = "OPEN",
            itemName = "Open Request",
        },
        {
            requestId = "req-fulfilled",
            approval = "APPROVED",
            fulfillment = "FULFILLED",
            itemName = "Done Request",
        },
        {
            requestId = "req-rejected",
            approval = "REJECTED",
            fulfillment = "OPEN",
            itemName = "Denied Request",
        },
        {
            requestId = "req-canceled",
            approval = "CANCELED",
            fulfillment = "OPEN",
            itemName = "Canceled Request",
        },
    },
    auditLog = {
        { category = "REQUEST", requestId = "req-open", type = "REQUEST_CREATED", timestamp = 70 },
        { category = "REQUEST", requestId = "req-fulfilled", type = "REQUEST_FULFILLED", timestamp = 71 },
        { category = "REQUEST", requestId = "req-rejected", type = "REQUEST_REJECTED", timestamp = 72 },
        { category = "REQUEST", requestId = "req-canceled", type = "REQUEST_CANCELED", timestamp = 73 },
        { category = "MINIMUM", type = "MINIMUM_UPDATED", timestamp = 74 },
    },
    bankLedger = {
        itemLogs = {
            { entryId = "item-1", timestamp = 80 },
        },
        moneyLogs = {
            { entryId = "money-1", timestamp = 81 },
        },
        itemFingerprints = {
            ["item-1"] = true,
        },
        moneyFingerprints = {
            ["money-1"] = true,
        },
        lastScanAt = 90,
        lastItemScanAt = 91,
        lastMoneyScanAt = 92,
    },
})
local clearGuildDb = (clearDb.guilds or {})["Persisted Guild"] or {}

store.ClearGuildBankLogData(clearDb)
assert.equal(0, #((clearGuildDb.bankLedger or {}).itemLogs or {}), "clearing guild-bank log data should remove saved item logs")
assert.equal(0, #((clearGuildDb.bankLedger or {}).moneyLogs or {}), "clearing guild-bank log data should remove saved money logs")
assert.equal(0, (((clearGuildDb.bankLedger or {}).lastScanAt) or 0), "clearing guild-bank log data should reset the combined ledger scan timestamp")
assert.equal(nil, next((clearGuildDb.bankLedger or {}).itemFingerprints or {}), "clearing guild-bank log data should clear item fingerprints")
assert.equal(nil, next((clearGuildDb.bankLedger or {}).moneyFingerprints or {}), "clearing guild-bank log data should clear money fingerprints")

store.ClearGuildBankInventoryData(clearDb)
assert.equal(nil, clearGuildDb.currentSnapshotId, "clearing guild-bank inventory data should remove the current snapshot pointer")
assert.equal(nil, next(clearGuildDb.snapshots or {}), "clearing guild-bank inventory data should remove saved snapshots")
assert.equal(0, #(clearGuildDb.changeLog or {}), "clearing guild-bank inventory data should remove saved snapshot diff history")
assert.equal(0, tonumber(((clearGuildDb.meta or {}).updatedAt) or 0), "clearing guild-bank inventory data should reset last-scan metadata")
assert.equal(0, tonumber(((clearGuildDb.meta or {}).lastScanSequence) or 0), "clearing guild-bank inventory data should reset the snapshot id sequence")

store.ClearCompletedRequestHistory(clearDb)
assert.equal(1, #(clearGuildDb.requests or {}), "clearing completed request history should keep only open requests")
assert.equal("req-open", ((clearGuildDb.requests or {})[1] or {}).requestId, "clearing completed request history should preserve the still-open request")
assert.equal(2, #(clearGuildDb.auditLog or {}), "clearing completed request history should also remove matching completed request audit rows")
assert.equal("req-open", ((clearGuildDb.auditLog or {})[1] or {}).requestId, "clearing completed request history should preserve open-request audit rows")
assert.equal("MINIMUM", ((clearGuildDb.auditLog or {})[2] or {}).category, "clearing completed request history should preserve unrelated audit history")
