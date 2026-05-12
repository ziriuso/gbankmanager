local assert = require("tests.helpers.assert")
_G.GBankManagerDB = {
    meta = {
        guildName = "Existing Guild",
    },
}

local addonName, ns, loaded = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local store = ns.modules.store
local permissions = ns.modules.permissions
local migrations = ns.modules.migrations
local scanner = ns.modules.scanner
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
assert.truthy(type(db) == "table", "fresh db should be created")
assert.equal(1, db.meta.schemaVersion, "fresh db should use schema version 1")
assert.equal("My Guild", db.meta.guildName, "guild name should be stored")
assert.truthy(db.requests ~= nil, "requests table should exist")
assert.truthy(permissions.CanApproveRequests("OFFICER"), "officers should approve requests")
assert.truthy(not permissions.CanViewInventory("MEMBER"), "members should not view inventory")
assert.same(_G.GBankManagerDB, ns.state.db, "bootstrap should keep normalized db in addon state")
assert.equal(1, _G.GBankManagerDB.meta.schemaVersion, "bootstrap should normalize schema version at runtime")
assert.truthy(_G.GBankManagerDB.requests ~= nil, "bootstrap should normalize missing tables at runtime")
assert.truthy(type(normalizedMalformed.meta) == "table", "migrations should repair malformed meta containers")
assert.truthy(type(normalizedMalformed.syncState) == "table", "migrations should repair malformed sync state containers")
assert.equal(1, normalizedMalformed.meta.schemaVersion, "migrations should apply v1 schema to malformed data")
assert.same(futureDb, normalizedFuture, "migrations should return the same table for newer schemas")
assert.equal(99, normalizedFuture.meta.schemaVersion, "migrations should preserve newer schema versions")
assert.equal("Future Guild", normalizedFuture.meta.guildName, "migrations should preserve newer schema metadata")
assert.truthy(_G.GBankManagerDB.auditLog ~= nil, "bootstrap should normalize the audit log container at runtime")

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
assert.truthy(type(persisted.ui.inventoryColumnWidths) == "table", "normalize should preserve inventory column width settings")
assert.truthy(type(persisted.ui.minimumSettings) == "table", "normalize should preserve minimum ui settings")
assert.equal(100, persisted.ui.minimumSettings.defaultQuantity, "normalize should seed the default minimum quantity setting")
assert.equal(100, db.ui.minimumSettings.defaultQuantity, "fresh databases should default minimum quantity to 100")

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
}

local newSnapshot, changes = scanner.FinishScan("OfficerOne", "Persisted Guild")

assert.truthy(newSnapshot.scanId ~= "scan-old", "a fresh scan should create a new snapshot id")
assert.equal(newSnapshot.scanId, _G.GBankManagerDB.currentSnapshotId, "fresh scans should move the current snapshot pointer forward")
assert.equal(5, _G.GBankManagerDB.snapshots["scan-old"].items[1001].totalCount, "fresh scans should keep older snapshots for persistence and history")
assert.equal(8, _G.GBankManagerDB.snapshots[newSnapshot.scanId].items[1001].totalCount, "fresh scans should store the new inventory snapshot in saved variables")
assert.truthy(#changes >= 1, "fresh scans should still produce diff history against the prior saved snapshot")

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

local reboundSnapshot = scanner.FinishScan("OfficerOne", "Persisted Guild")

assert.same(_G.GBankManagerDB, ns.state.db, "scanner should rebind runtime state back onto the saved variables table before writing")
assert.truthy(_G.GBankManagerDB.snapshots["scan-old"] ~= nil, "scanner should preserve prior saved snapshots even if runtime state drifted")
assert.equal(9, _G.GBankManagerDB.snapshots[reboundSnapshot.scanId].items[1001].totalCount, "scanner should append the new snapshot onto the persisted saved-variables history")
