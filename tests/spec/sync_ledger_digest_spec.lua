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

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local codec = ns.modules.syncCodec
local transport = ns.modules.syncTransport
local manualActions = ns.modules.syncManualActions
local bankLedger = ns.modules.bankLedger
local syncEvents = ns.modules.syncEvents

local sentMessages = {}
transport.Send = function(_, _, message)
    sentMessages[#sentMessages + 1] = message
    return codec.EncodeTable(message)
end

local db = ns.state.db
db.auth.capabilities.full_ui = { [1] = true }
db.bankLedger = {
    itemLogs = {
        {
            timestamp = 1716573600,
            when = 1716573600,
            action = "Deposit",
            who = "MemberOne-Stormrage",
            itemID = 243734,
            item = "Thalassian Phoenix Oil",
            quantity = 4,
            tabIndex = 1,
            tabName = "Alchemy",
            fingerprint = "item-a",
        },
    },
    moneyLogs = {
        {
            timestamp = 1716573660,
            when = 1716573660,
            action = "Repair",
            who = "MemberTwo-Stormrage",
            amountCopper = 12345,
            fingerprint = "money-a",
        },
    },
}

local digest = bankLedger.BuildSyncDigest(db)
assert.equal("table", type(digest), "bank ledger should build a compact ledger sync digest")
assert.equal(1, digest.itemCount, "ledger digest should count item rows")
assert.equal(1, digest.moneyCount, "ledger digest should count money rows")
assert.truthy(type(digest.hash) == "string" and digest.hash ~= "", "ledger digest should expose a stable non-empty hash")

sentMessages = {}
local first = manualActions.Run(db, {
    action = "ledger",
    accessProfile = "full_shell",
    now = 1717001000,
    skipCooldown = true,
})

assert.truthy(first.ok, "first ledger sync should succeed")
assert.equal("LEDGER_MANIFEST", sentMessages[1].type, "ledger sync should announce the current manifest before peers request rows")

local firstDeltaCount = 0
for _, message in ipairs(sentMessages) do
    if message.type == "LEDGER_DELTA" then
        firstDeltaCount = firstDeltaCount + 1
    end
end
assert.equal(1, #sentMessages, "first ledger sync should send only the compact manifest")
assert.equal(0, firstDeltaCount, "first ledger sync should not eagerly send row deltas before peers request buckets")

sentMessages = {}
local second = manualActions.Run(db, {
    action = "ledger",
    accessProfile = "full_shell",
    now = 1717001005,
    skipCooldown = true,
})

assert.truthy(second.ok, "replayed ledger sync should still succeed for peer bookkeeping")
local secondDeltaCount = 0
for _, message in ipairs(sentMessages) do
    if message.type == "LEDGER_DELTA" then
        secondDeltaCount = secondDeltaCount + 1
    end
end
assert.equal(1, #sentMessages, "replayed same-state ledger sync should only send the compact manifest")
assert.equal("LEDGER_MANIFEST", sentMessages[1].type, "replayed same-state ledger sync should keep the manifest visible to peers")
assert.equal(0, secondDeltaCount, "replayed same-state ledger sync should not resend row deltas")

local remoteDigestPayload = codec.EncodeTable({
    type = "LEDGER_DIGEST",
    updatedAt = 1717001010,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "MemberOne-Stormrage",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = tostring((ns.constants or {}).ADDON_VERSION or ""),
        digest = digest,
    },
})

local digestAccepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", remoteDigestPayload, "GUILD", "MemberOne")
assert.truthy(digestAccepted, "sync events should recognize ledger digest messages")
assert.equal("ledger_digest", tostring(((ns.state or {}).lastSyncDecision or {}).category or ""), "ledger digest handling should record a debug decision category")
assert.equal("matched", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "matching ledger digests should record a converged decision")
