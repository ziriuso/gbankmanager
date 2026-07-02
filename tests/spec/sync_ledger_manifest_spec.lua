local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

_G.UnitName = function()
    return "SyncTester"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

_G.__guildRoster = {
    {
        name = "MemberOne",
        rankName = "Officer",
        rankIndex = 1,
        online = true,
    },
    {
        name = "SyncTester",
        rankName = "Officer",
        rankIndex = 1,
        online = true,
    },
}
_G.GetNumGuildMembers = function()
    return #_G.__guildRoster
end
_G.GetGuildRosterInfo = function(index)
    local row = _G.__guildRoster[index]
    if type(row) ~= "table" then
        return nil
    end

    return row.name, row.rankName, row.rankIndex, nil, nil, nil, nil, nil, row.online
end

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
assert.truthy(sameFingerprint.globalHash ~= differentEntryId.globalHash, "manifest hashes should prefer entry IDs over shared row fingerprints")

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

local codec = ns.modules.syncCodec
local syncEvents = ns.modules.syncEvents
local syncTransport = ns.modules.syncTransport
assert.truthy(type(syncEvents.HandleEvent) == "function", "sync events should be available for ledger manifest flow tests")
local originalSyncTransportSend = syncTransport.Send
local capturedSyncSends = {}
syncTransport.Send = function(distribution, target, message)
    capturedSyncSends[#capturedSyncSends + 1] = {
        distribution = distribution,
        target = target,
        message = message,
    }
    return codec.EncodeTable(message)
end

local syncDb = ns.state.db
syncDb.meta = syncDb.meta or {}
syncDb.meta.guildName = "Guild Testers"
syncDb.auth = syncDb.auth or {}
syncDb.auth.capabilities = syncDb.auth.capabilities or {}
syncDb.auth.capabilities.full_ui = { [1] = true }
syncDb.ui = syncDb.ui or {}
syncDb.ui.chatSettings = syncDb.ui.chatSettings or {}
syncDb.ui.chatSettings.suppressRoutineMessages = false
syncDb.bankLedger = {
    itemLogs = {
        {
            entryId = "local-item-a",
            timestamp = 21600,
            action = "Deposit",
            who = "SyncTester-Stormrage",
            itemID = 1,
            item = "Manifest Oil",
            quantity = 2,
            tabIndex = 1,
            tabName = "Alchemy",
        },
        {
            entryId = "local-item-b",
            timestamp = 21700,
            action = "Deposit",
            who = "SyncTester-Stormrage",
            itemID = 2,
            item = "Manifest Flask",
            quantity = 1,
            tabIndex = 1,
            tabName = "Alchemy",
        },
    },
    moneyLogs = {
        {
            entryId = "local-money-c",
            timestamp = 43200,
            action = "Repair",
            who = "SyncTester-Stormrage",
            amountCopper = 100,
        },
    },
}

local function reset_sync_output()
    _G.C_ChatInfo.sentMessages = {}
    _G.DEFAULT_CHAT_FRAME.messages = {}
    syncTransport.chunkBuffers = {}
    capturedSyncSends = {}
end

local function sent_sync_messages()
    local messages = {}
    for _, sent in ipairs(capturedSyncSends or {}) do
        messages[#messages + 1] = sent.message
    end
    return messages
end

local function sent_sync_messages_by_type(messageType)
    local messages = {}
    for _, message in ipairs(sent_sync_messages()) do
        if tostring((message or {}).type or "") == tostring(messageType or "") then
            messages[#messages + 1] = message
        end
    end
    return messages
end

local function fire_sync_message(message, sender)
    return syncEvents.HandleEvent(
        "CHAT_MSG_ADDON",
        "GBankManager",
        codec.EncodeTable(message),
        "GUILD",
        sender or "MemberOne"
    )
end

local localManifest = bankLedger.BuildLedgerManifest(syncDb)
local currentLedgerProtocol = tonumber((ns.constants or {}).LEDGER_PROTOCOL_VERSION or 0) or 0
reset_sync_output()
local staleProtocolTwoManifestAccepted = fire_sync_message({
    type = "LEDGER_MANIFEST",
    updatedAt = 299,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = 2,
        manifest = {
            ledgerProtocol = 2,
            version = "1.2.3",
            totalCount = 1,
            itemCount = 0,
            moneyCount = 1,
            globalHash = "older-1.2.3-protocol-two",
            buckets = {
                [2] = {
                    key = 2,
                    count = 1,
                    hash = "poisoned-money-bucket",
                },
            },
        },
    },
}, "MemberOne")
assert.truthy(not staleProtocolTwoManifestAccepted, "ledger manifests from older 1.2.3 protocol-2 clients should be rejected")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "stale protocol-2 manifest rejection should record the protocol reason")
assert.equal(0, #sent_sync_messages(), "stale protocol-2 manifests should not trigger bucket requests or replies")
reset_sync_output()
local matchingManifestAccepted = fire_sync_message({
    type = "LEDGER_MANIFEST",
    updatedAt = 300,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        manifest = localManifest,
    },
}, "MemberOne")
assert.truthy(matchingManifestAccepted, "matching ledger manifests should be accepted")
assert.equal("ledger_manifest", tostring(((ns.state or {}).lastSyncDecision or {}).category or ""), "matching manifests should record the ledger manifest decision category")
assert.equal("matched", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "matching manifests should record a matched decision")
assert.equal(0, #sent_sync_messages(), "matching manifests should not request any buckets")

local remoteDifferentManifest = {
    ledgerProtocol = currentLedgerProtocol,
    version = tostring((ns.constants or {}).ADDON_VERSION or ""),
    buckets = {
        [1] = localManifest.buckets[1],
        [2] = {
            key = 2,
            count = 1,
            hash = "remote-different",
        },
    },
}
reset_sync_output()
local differingManifestAccepted = fire_sync_message({
    type = "LEDGER_MANIFEST",
    updatedAt = 301,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        manifest = remoteDifferentManifest,
    },
}, "MemberOne")
local bucketRequests = sent_sync_messages()
assert.truthy(differingManifestAccepted, "differing ledger manifests should be accepted")
assert.equal("different", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "differing manifests should record a different decision")
assert.equal(1, #bucketRequests, "differing manifests should send exactly one bucket request")
assert.equal("LEDGER_BUCKET_REQUEST", bucketRequests[1].type, "differing manifests should request only changed ledger buckets")
assert.equal(currentLedgerProtocol, tonumber(((bucketRequests[1].payload or {}).ledgerProtocol) or 0), "bucket requests should advertise the current ledger protocol")
assert.equal("MemberOne", tostring(((bucketRequests[1].payload or {}).target) or ""), "bucket requests should target the manifest sender")
assert.equal(1, #(((bucketRequests[1].payload or {}).buckets) or {}), "bucket requests should include only differing buckets")
assert.equal(2, tonumber((((bucketRequests[1].payload or {}).buckets) or {})[1] or 0), "bucket request should ask for the differing bucket")

reset_sync_output()
local staleManifestAccepted = fire_sync_message({
    type = "LEDGER_MANIFEST",
    updatedAt = 301,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        manifest = {
            ledgerProtocol = currentLedgerProtocol,
            version = tostring((ns.constants or {}).ADDON_VERSION or ""),
            totalCount = 0,
            itemCount = 0,
            moneyCount = 0,
            globalHash = "empty-stale-ledger",
            buckets = {},
        },
    },
}, "MemberOne")
local staleBucketRequests = sent_sync_messages_by_type("LEDGER_BUCKET_REQUEST")
local staleBucketReplies = sent_sync_messages_by_type("LEDGER_BUCKET_REPLY")
assert.truthy(staleManifestAccepted, "stale ledger manifests should be accepted")
assert.equal(0, #staleBucketRequests, "clients with rows should not ask stale peers for buckets the stale peer does not have")
assert.equal(1, #staleBucketReplies, "clients with rows should push missing bucket rows back to a stale manifest sender")
assert.equal("MemberOne", tostring(((staleBucketReplies[1].payload or {}).target) or ""), "stale manifest replies should target the manifest sender")
assert.equal(2, #((((staleBucketReplies[1].payload or {}).rows or {}).item) or {}), "stale manifest replies should include local item rows")
assert.equal(1, #((((staleBucketReplies[1].payload or {}).rows or {}).money) or {}), "stale manifest replies should include local money rows")

reset_sync_output()
local bucketRequestAccepted = fire_sync_message({
    type = "LEDGER_BUCKET_REQUEST",
    updatedAt = 302,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        target = "SyncTester",
        buckets = { 2 },
    },
}, "MemberOne")
local bucketReplies = sent_sync_messages()
assert.truthy(bucketRequestAccepted, "addressed bucket requests should be accepted")
assert.equal(1, #bucketReplies, "addressed bucket requests should send exactly one bucket reply")
assert.equal("LEDGER_BUCKET_REPLY", bucketReplies[1].type, "addressed bucket requests should reply with bucket rows")
assert.equal(currentLedgerProtocol, tonumber(((bucketReplies[1].payload or {}).ledgerProtocol) or 0), "bucket replies should advertise the current ledger protocol")
assert.equal("MemberOne", tostring(((bucketReplies[1].payload or {}).target) or ""), "bucket replies should target the requesting sender")
assert.equal(1, #((((bucketReplies[1].payload or {}).rows or {}).money) or {}), "bucket replies should include rows for requested buckets")
assert.equal(0, #((((bucketReplies[1].payload or {}).rows or {}).item) or {}), "bucket replies should omit rows outside requested buckets")

reset_sync_output()
local misaddressedRequestAccepted = fire_sync_message({
    type = "LEDGER_BUCKET_REQUEST",
    updatedAt = 303,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        target = "OtherPlayer",
        buckets = { 2 },
    },
}, "MemberOne")
assert.truthy(misaddressedRequestAccepted, "bucket requests for another target should be safely ignored")
assert.equal(0, #sent_sync_messages(), "bucket requests for another target should not send replies")

local originalMergeBucketRows = bankLedger.MergeBucketRows
local mergeCalls = 0
bankLedger.MergeBucketRows = function(_, payload)
    mergeCalls = mergeCalls + 1
    assert.equal("table", type(payload), "bucket replies should pass the payload to the merge hook")
    return 1
end
reset_sync_output()
local staleProtocolTwoReplyAccepted = fire_sync_message({
    type = "LEDGER_BUCKET_REPLY",
    updatedAt = 304,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = 2,
        target = "SyncTester",
        buckets = { 2 },
        rows = { item = {}, money = syncDb.bankLedger.moneyLogs },
    },
}, "MemberOne")
assert.truthy(not staleProtocolTwoReplyAccepted, "bucket replies from older 1.2.3 protocol-2 clients should be rejected")
assert.equal(0, mergeCalls, "stale protocol-2 bucket replies should not merge poisoned rows")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "stale protocol-2 bucket reply rejection should record the protocol reason")

reset_sync_output()
local chatBeforeMisaddressedReply = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local misaddressedReplyAccepted = fire_sync_message({
    type = "LEDGER_BUCKET_REPLY",
    updatedAt = 304,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        target = "OtherPlayer",
        buckets = { 2 },
        rows = { item = {}, money = {} },
    },
}, "MemberOne")
assert.truthy(misaddressedReplyAccepted, "bucket replies for another target should be safely ignored")
assert.equal(0, mergeCalls, "bucket replies for another target should not merge")
assert.equal(chatBeforeMisaddressedReply, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "bucket replies for another target should not add chat noise")

reset_sync_output()
local addressedReplyAccepted = fire_sync_message({
    type = "LEDGER_BUCKET_REPLY",
    updatedAt = 305,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        ledgerProtocol = currentLedgerProtocol,
        target = "SyncTester",
        buckets = { 2 },
        rows = { item = {}, money = syncDb.bankLedger.moneyLogs },
    },
}, "MemberOne")
assert.truthy(addressedReplyAccepted, "addressed bucket replies should be accepted")
assert.equal(1, mergeCalls, "addressed bucket replies should call the merge hook when available")
assert.truthy(string.find(((_G.DEFAULT_CHAT_FRAME.messages or {})[1]) or "", "Synced 1 ledger bucket row", 1, true) ~= nil, "bucket replies should report routine chat only when rows merge")
bankLedger.MergeBucketRows = originalMergeBucketRows
syncTransport.Send = originalSyncTransportSend

print("PASS tests/spec/sync_ledger_manifest_spec.lua")
