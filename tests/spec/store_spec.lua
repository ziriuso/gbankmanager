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

assert.equal("GBankManager", addonName, "toc should load the addon by name")
assert.equal("GBankManager", ns.addonName, "namespace should expose addon name")
assert.truthy(type(ns.modules) == "table", "namespace should expose module table")
assert.truthy(type(ns.state) == "table", "namespace should expose state table")
assert.truthy(type(ns.constants) == "table", "constants should populate the shared namespace")
assert.equal(1, ns.constants.SCHEMA_VERSION, "constants should expose schema version")
assert.truthy(type(ns.modules.events) == "table", "events module should populate the shared namespace")
assert.truthy(type(ns.modules.slash) == "table", "slash module should populate the shared namespace")
assert.same(ns, loaded[1].value, "namespace chunk should return the shared namespace table")
assert.same(ns.modules.store, loaded[5].value, "store chunk should return the shared store module")
assert.same(ns.modules.permissions, loaded[6].value, "permissions chunk should return the shared permissions module")
assert.same(ns, loaded[7].value, "bootstrap chunk should return the shared namespace table")
assert.same(ns.modules.events, loaded[8].value, "events chunk should return the shared events module")
assert.same(ns.modules.slash, loaded[9].value, "slash chunk should return the shared slash module")
assert.truthy(type(store) == "table", "store module should be loaded for specs")
assert.truthy(type(permissions) == "table", "permissions module should be loaded for specs")
assert.truthy(type(migrations) == "table", "migrations module should be loaded for specs")
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
