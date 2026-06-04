local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local manifest = _G.dofile("GBankManager/Domain/LedgerManifest.lua")

local rows = {
    { entryId = "item-a", timestamp = 21600, itemID = 1 },
    { entryId = "item-b", timestamp = 21700, itemID = 2 },
    { entryId = "money-c", timestamp = 43200, amountCopper = 100 },
}

local ledger = {
    itemLogs = { rows[1], rows[2] },
    moneyLogs = { rows[3] },
}

local built = manifest.Build(ledger, { ledgerProtocol = 2, version = "1.2.0" })

assert.equal(1, manifest.BucketKey(21600), "six-hour bucket key should advance at the six-hour boundary")
assert.equal(1, manifest.BucketKey(21700), "six-hour bucket key should keep adjacent six-hour rows together")
assert.equal(2, manifest.BucketKey(43200), "six-hour bucket key should keep rows in deterministic time buckets")
assert.equal(2, tonumber(built.ledgerProtocol or 0), "manifest should carry ledger protocol")
assert.equal("1.2.0", built.version, "manifest should carry the provided version")
assert.equal(3, tonumber(built.totalCount or 0), "manifest should count item and money rows")
assert.truthy(type(built.globalHash) == "string" and built.globalHash ~= "", "manifest should expose a global hash")
assert.truthy((built.buckets or {})[1], "first 6-hour bucket should exist")
assert.truthy((built.buckets or {})[2], "second 6-hour bucket should exist")
assert.equal(2, tonumber(built.buckets[1].count or 0), "first bucket should count the two item rows")
assert.equal(1, tonumber(built.buckets[2].count or 0), "second bucket should count the money row")

local reordered = manifest.Build({
    itemLogs = { rows[2], rows[1] },
    moneyLogs = { rows[3] },
}, { ledgerProtocol = 2, version = "1.2.0" })
assert.equal(built.globalHash, reordered.globalHash, "global hash should not change when row order changes")
assert.equal(built.buckets[1].hash, reordered.buckets[1].hash, "bucket hash should not change when row order changes")

local sameFingerprint = manifest.Build({
    itemLogs = {
        { entryId = "local-item-a", fingerprint = "shared-item-a", timestamp = 21600, itemID = 1 },
    },
    moneyLogs = {},
}, { ledgerProtocol = 2, version = "1.2.0" })
local differentEntryId = manifest.Build({
    itemLogs = {
        { entryId = "remote-item-a", fingerprint = "shared-item-a", timestamp = 21600, itemID = 1 },
    },
    moneyLogs = {},
}, { ledgerProtocol = 2, version = "1.2.0" })
assert.equal(sameFingerprint.globalHash, differentEntryId.globalHash, "manifest hashes should prefer shared row fingerprints over local entry IDs")

local matching = manifest.Compare(built, manifest.Build(ledger, { ledgerProtocol = 2, version = "1.2.0" }))
assert.truthy(matching.matched == true, "matching manifests should report matched")
assert.equal(0, #(matching.differentBuckets or {}), "matching manifests should not request buckets")

local protocolMismatch = manifest.Compare(built, manifest.Build(ledger, { ledgerProtocol = 3, version = "1.2.0" }))
assert.truthy(protocolMismatch.matched ~= true, "protocol mismatches should not report matched")
assert.truthy(protocolMismatch.protocolMismatch == true, "protocol mismatches should expose a clear mismatch flag")

local diff = manifest.Compare(built, {
    ledgerProtocol = 2,
    buckets = {
        [1] = built.buckets[1],
        [2] = "different",
    },
})
assert.truthy(diff.matched ~= true, "differing bucket hashes should not report matched")
assert.equal(1, #(diff.differentBuckets or {}), "comparison should request only differing buckets")
assert.equal(2, tonumber(diff.differentBuckets[1] or 0), "bucket 2 should be the only differing bucket")

local selected = manifest.RowsForBuckets(ledger, { 2 })
assert.equal(0, #(selected.item or {}), "bucket row selection should omit item rows outside the request")
assert.equal(1, #(selected.money or {}), "bucket row selection should include matching money rows")
assert.same(rows[3], selected.money[1], "bucket row selection should return the original matching row")
assert.equal("money-c", rows[3].entryId, "bucket row selection should not mutate source rows")

local addonAssert = require("tests.helpers.assert")
local _, ns = addonAssert.load_addon_from_toc("GBankManager/GBankManager.toc")
local bankLedger = ns.modules.bankLedger
assert.truthy(type(ns.modules.ledgerManifest) == "table", "ledger manifest module should load from the toc")

local db = {
    bankLedger = {
        itemLogs = { rows[1], rows[2] },
        moneyLogs = { rows[3] },
    },
}
local wrapperManifest = bankLedger.BuildLedgerManifest(db)
assert.equal(3, tonumber(wrapperManifest.totalCount or 0), "bank ledger wrapper should build a ledger manifest")
assert.equal(tonumber((ns.constants or {}).LEDGER_PROTOCOL_VERSION or 0), tonumber(wrapperManifest.ledgerProtocol or 0), "bank ledger wrapper should use the constants ledger protocol")
assert.equal(tostring((ns.constants or {}).ADDON_VERSION or ""), tostring(wrapperManifest.version or ""), "bank ledger wrapper should use the constants addon version")
assert.truthy(type(wrapperManifest.globalHash) == "string" and wrapperManifest.globalHash ~= "", "bank ledger wrapper should expose the manifest global hash")

local wrapperDiff = bankLedger.CompareLedgerManifest(db, {
    ledgerProtocol = wrapperManifest.ledgerProtocol,
    buckets = {
        [1] = wrapperManifest.buckets[1],
        [2] = "different",
    },
})
assert.equal(1, #(wrapperDiff.differentBuckets or {}), "bank ledger wrapper should compare local and remote manifests")
assert.equal(2, tonumber(wrapperDiff.differentBuckets[1] or 0), "bank ledger wrapper should report the differing bucket")

local wrapperRows = bankLedger.RowsForLedgerBuckets(db, { 1 })
assert.equal(2, #(wrapperRows.item or {}), "bank ledger wrapper should select item rows for requested buckets")
assert.equal(0, #(wrapperRows.money or {}), "bank ledger wrapper should omit money rows outside requested buckets")

print("PASS tests/spec/sync_ledger_manifest_spec.lua")
