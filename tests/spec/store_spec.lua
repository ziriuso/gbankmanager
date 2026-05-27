local assert = require("tests.helpers.assert")
_G.GBankManagerItemSearchPayload = nil
_G.GBankManagerItemCatalogData = nil
_G.GBankManagerDB = {
    meta = {
        guildName = "Existing Guild",
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
assert.truthy(permissions.CanApproveRequests("OFFICER"), "officers should approve requests")
assert.truthy(not permissions.CanViewInventory("MEMBER"), "members should not view inventory")
store.GetDatabase("My Guild")
assert.same(_G.GBankManagerDB, ns.state.db, "addon loaded should keep normalized db in addon state")
assert.equal(1, _G.GBankManagerDB.meta.schemaVersion, "addon loaded should normalize schema version at runtime")
assert.truthy(_G.GBankManagerDB.requests ~= nil, "addon loaded should normalize missing tables at runtime")
assert.equal(0, _G.GBankManagerDB.meta.lastScanSequence, "addon loaded should normalize the scan sequence counter at runtime")
assert.truthy(type(normalizedMalformed.meta) == "table", "migrations should repair malformed meta containers")
assert.truthy(type(normalizedMalformed.syncState) == "table", "migrations should repair malformed sync state containers")
assert.equal(1, normalizedMalformed.meta.schemaVersion, "migrations should apply v1 schema to malformed data")
assert.same(futureDb, normalizedFuture, "migrations should return the same table for newer schemas")
assert.equal(99, normalizedFuture.meta.schemaVersion, "migrations should preserve newer schema versions")
assert.equal("Future Guild", normalizedFuture.meta.guildName, "migrations should preserve newer schema metadata")
assert.truthy(_G.GBankManagerDB.auditLog ~= nil, "addon loaded should normalize the audit log container at runtime")

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

assert.equal("scan-old", persisted.currentSnapshotId, "normalize should preserve the current snapshot id across reloads")
assert.equal(5, persisted.snapshots["scan-old"].items[1001].totalCount, "normalize should preserve scanned inventory rows across reloads")
assert.equal(77, persisted.meta.updatedAt, "normalize should preserve last scan metadata across reloads")
assert.truthy(type(persisted.auditLog) == "table", "normalize should preserve an audit log container for workflow history")
assert.truthy(type(persisted.ui) == "table", "normalize should preserve a ui settings container")
assert.truthy(type(persisted.ui.exportSettings) == "table", "normalize should preserve export ui settings")
assert.truthy(type(persisted.ui.appearance) == "table", "normalize should preserve appearance ui settings")
assert.truthy(type(persisted.ui.inventoryColumnWidths) == "table", "normalize should preserve inventory column width settings")
assert.truthy(type(persisted.ui.minimumSettings) == "table", "normalize should preserve minimum ui settings")
assert.truthy(type(persisted.ui.logsHistorySettings) == "table", "normalize should preserve logs/history ui settings")
assert.truthy(type(persisted.ui.minimumItemCatalog) == "table", "normalize should preserve the saved minimum item catalog")
assert.truthy(type(persisted.testing) == "table", "normalize should preserve the testing container")
assert.truthy(type(persisted.testing.liveSmoke) == "table", "normalize should preserve the live-smoke persistence container")
assert.truthy(type(persisted.testing.inGameUnit) == "table", "normalize should preserve the in-game-unit persistence container")
assert.equal(100, persisted.ui.minimumSettings.defaultQuantity, "normalize should seed the default minimum quantity setting")
assert.equal(50, persisted.ui.minimumSettings.criticalThresholdPercent, "normalize should seed the default critical shortage threshold percentage")
assert.equal("indefinite", persisted.ui.logsHistorySettings.ledgerRetention, "normalize should seed the default ledger retention setting")
assert.equal("indefinite", persisted.ui.logsHistorySettings.historyRetention, "normalize should seed the default history retention setting")
assert.equal(300, persisted.ui.logsHistorySettings.ledgerScanIntervalSeconds, "normalize should seed the default ledger scan interval")
assert.equal(100, db.ui.minimumSettings.defaultQuantity, "fresh databases should default minimum quantity to 100")
assert.equal("generic_wow", persisted.ui.appearance.themePreset, "normalize should seed the default appearance theme preset")
assert.equal(1, persisted.ui.appearance.shellScale, "normalize should seed the default shell scale")
assert.equal(1, persisted.ui.appearance.tableDensity, "normalize should seed the default table density")
assert.same(persisted.ui, store.GetUiState(persisted), "store ui-state accessor should return the normalized ui container")
assert.same(persisted.ui.inventoryColumnWidths, store.GetInventoryColumnWidths(persisted), "store should return the normalized inventory column-width table")
assert.same(persisted.ui.minimumSettings, store.GetMinimumSettings(persisted), "store should return the normalized minimum-settings table")
assert.same(persisted.ui.minimumItemCatalog, store.GetMinimumItemCatalog(persisted), "store should return the normalized minimum item catalog")
assert.same(persisted.ui.exportSettings, store.GetExportSettings(persisted), "store should return the normalized export-settings table")
assert.same(persisted.ui.appearance, store.GetAppearanceSettings(persisted), "store should return the normalized appearance-settings table")
assert.same(persisted.snapshots["scan-old"], store.GetCurrentSnapshot(persisted), "store current snapshot accessor should resolve the active snapshot row")

persisted.requests = {
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
_G.GBankManagerDB = persisted
ns.state.db = _G.GBankManagerDB
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
assert.equal(newSnapshot.scanId, _G.GBankManagerDB.currentSnapshotId, "fresh scans should move the current snapshot pointer forward")
assert.equal(5, _G.GBankManagerDB.snapshots["scan-old"].items[1001].totalCount, "fresh scans should keep older snapshots for persistence and history")
assert.equal(11, _G.GBankManagerDB.snapshots[newSnapshot.scanId].items[1001].totalCount, "fresh scans should store the new inventory snapshot in saved variables")
assert.equal(2, #_G.GBankManagerDB.snapshots[newSnapshot.scanId].itemRows, "fresh scans should persist tab-scoped item rows in saved variables")
assert.equal("Flasks", _G.GBankManagerDB.snapshots[newSnapshot.scanId].itemRows[1].tabName, "fresh scans should persist the first tab-scoped item row")
assert.equal(8, _G.GBankManagerDB.snapshots[newSnapshot.scanId].itemRows[1].quantity, "fresh scans should persist the first tab-scoped quantity")
assert.equal("Raid", _G.GBankManagerDB.snapshots[newSnapshot.scanId].itemRows[2].tabName, "fresh scans should persist the second tab-scoped item row")
assert.equal(3, _G.GBankManagerDB.snapshots[newSnapshot.scanId].itemRows[2].quantity, "fresh scans should persist the second tab-scoped quantity")
assert.equal(1715523300, _G.GBankManagerDB.meta.updatedAt, "fresh scans should persist the captured UTC scan timestamp as last-scan metadata")
assert.truthy(#changes >= 1, "fresh scans should still produce diff history against the prior saved snapshot")
assert.equal("FULFILLED", _G.GBankManagerDB.requests[1].fulfillment, "fresh scans should auto-fulfill approved requests once inventory meets the request amount")
assert.equal(1715523300, _G.GBankManagerDB.requests[1].fulfillmentUpdatedAt, "fresh scans should store date fulfilled from the scan timestamp")

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

assert.same(_G.GBankManagerDB, ns.state.db, "scanner should rebind runtime state back onto the saved variables table before writing")
assert.truthy(_G.GBankManagerDB.snapshots["scan-old"] ~= nil, "scanner should preserve prior saved snapshots even if runtime state drifted")
assert.equal(9, _G.GBankManagerDB.snapshots[reboundSnapshot.scanId].items[1001].totalCount, "scanner should append the new snapshot onto the persisted saved-variables history")

_G.GBankManagerDB = {}
ns.state.db = persisted

local reboundDb = store.GetDatabase()

assert.same(persisted, reboundDb, "store database accessor should prefer the populated runtime state when the saved-variables global is empty")
assert.same(_G.GBankManagerDB, ns.state.db, "store database accessor should keep the global and runtime db references aligned")

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

store.ClearGuildBankLogData(clearDb)
assert.equal(0, #((clearDb.bankLedger or {}).itemLogs or {}), "clearing guild-bank log data should remove saved item logs")
assert.equal(0, #((clearDb.bankLedger or {}).moneyLogs or {}), "clearing guild-bank log data should remove saved money logs")
assert.equal(0, (((clearDb.bankLedger or {}).lastScanAt) or 0), "clearing guild-bank log data should reset the combined ledger scan timestamp")
assert.equal(nil, next((clearDb.bankLedger or {}).itemFingerprints or {}), "clearing guild-bank log data should clear item fingerprints")
assert.equal(nil, next((clearDb.bankLedger or {}).moneyFingerprints or {}), "clearing guild-bank log data should clear money fingerprints")

store.ClearGuildBankInventoryData(clearDb)
assert.equal(nil, clearDb.currentSnapshotId, "clearing guild-bank inventory data should remove the current snapshot pointer")
assert.equal(nil, next(clearDb.snapshots or {}), "clearing guild-bank inventory data should remove saved snapshots")
assert.equal(0, #(clearDb.changeLog or {}), "clearing guild-bank inventory data should remove saved snapshot diff history")
assert.equal(0, tonumber(((clearDb.meta or {}).updatedAt) or 0), "clearing guild-bank inventory data should reset last-scan metadata")
assert.equal(0, tonumber(((clearDb.meta or {}).lastScanSequence) or 0), "clearing guild-bank inventory data should reset the snapshot id sequence")

store.ClearCompletedRequestHistory(clearDb)
assert.equal(1, #(clearDb.requests or {}), "clearing completed request history should keep only open requests")
assert.equal("req-open", ((clearDb.requests or {})[1] or {}).requestId, "clearing completed request history should preserve the still-open request")
assert.equal(2, #(clearDb.auditLog or {}), "clearing completed request history should also remove matching completed request audit rows")
assert.equal("req-open", ((clearDb.auditLog or {})[1] or {}).requestId, "clearing completed request history should preserve open-request audit rows")
assert.equal("MINIMUM", ((clearDb.auditLog or {})[2] or {}).category, "clearing completed request history should preserve unrelated audit history")
