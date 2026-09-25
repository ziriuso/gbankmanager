local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local previousNamespace = _G.GBankManagerNamespace
local previousDatabase = _G.GBankManagerDB
local previousUnitName = _G.UnitName
local previousUnitGUID = _G.UnitGUID
local previousRealmName = _G.GetRealmName
local previousGuildInfo = _G.GetGuildInfo
local previousGuildCount = _G.GetNumGuildMembers
local previousRosterInfo = _G.GetGuildRosterInfo
local previousIsSecretValue = _G.issecretvalue

local roster = {
    { name = "Ziri Shadow", rank = "Guild Master", index = 0, guid = "Player-4620-0077C499" },
    { name = "Ziri Jr", rank = "Initiate", index = 4, guid = "Player-4620-00CA6CB7" },
}

_G.UnitName = function()
    return "Ziri"
end
_G.UnitGUID = function()
    return "Player-4620-0077C499"
end
_G.GetRealmName = function()
    return "Classic Beta PvE 2"
end
_G.GetGuildInfo = function()
    return "Tyrrish Rebellion", "Guild Master", 0
end
_G.GetNumGuildMembers = function()
    return #roster
end
_G.GetGuildRosterInfo = function(index)
    local row = roster[index]
    if not row then
        return nil
    end
    return row.name, row.rank, row.index, nil, nil, nil, nil, nil,
        true, nil, nil, nil, nil, nil, nil, nil, row.guid
end

_G.GBankManagerNamespace = nil
local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local originalIsForever = ns.IsForever
ns.IsForever = function()
    return true
end

local permissions = ns.modules.permissions
local live = permissions.GetLivePlayerContext({})
assert.equal("Ziri Shadow", live.name, "Forever should resolve the player's complete roster name using GUID")
assert.equal("Ziri Shadow", live.characterKey, "Forever character keys should use the region-unique complete name")
assert.equal(true, live.identityVerified, "a GUID-matched complete roster name should be verified")
assert.equal("Ziri Shadow", permissions.NormalizeCharacterKey("Ziri Shadow-Classic Beta PvE 2"), "Forever should not use the beta realm label in its character key")
local migratedPolicy = permissions.CreateDefaultPolicy()
migratedPolicy.blacklist["Ziri Jr-Classic Beta PvE 2"] = { name = "Ziri Jr", reason = "old beta key" }
permissions.NormalizePolicy(migratedPolicy)
assert.truthy(migratedPolicy.blacklist["Ziri Jr"] ~= nil, "a complete legacy beta key should migrate to the full Forever name")
assert.equal(nil, migratedPolicy.blacklist["Ziri Shadow"], "migration must not merge two members who share a first name")

local master = permissions.GetGuildRosterContextBySender("Ziri Shadow", live)
local initiate = permissions.GetGuildRosterContextBySender("Ziri Jr", live)
local ambiguous = permissions.GetGuildRosterContextBySender("Ziri", live)
assert.equal("Ziri Shadow", master.characterKey, "a complete sender should match the correct roster member")
assert.equal(0, master.guildRankIndex, "the complete master name should retain its own rank")
assert.equal("Ziri Jr", initiate.characterKey, "the same first name with a different surname should stay separate")
assert.equal(4, initiate.guildRankIndex, "the initiate must not inherit the master's rank")
assert.truthy(not ambiguous.inGuild, "an ambiguous first name must not acquire a roster identity")

local store = ns.modules.store
local db = store.CreateFreshDatabase("Tyrrish Rebellion")
_G.GBankManagerDB = db
ns.state.db = db
local hello = ns.modules.syncCodec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 100,
    payload = "Ziri Jr",
})
local ambiguousAccepted = ns.modules.syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", hello, "GUILD", "Ziri")
assert.truthy(not ambiguousAccepted, "a first-name-only addon sender must not announce a Forever peer")
assert.equal(0, #ns.modules.syncPeerState.GetPeers(db, "Tyrrish Rebellion"), "an ambiguous hello must not create a trusted peer")
local fullAccepted = ns.modules.syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", hello, "GUILD", "Ziri Jr")
assert.truthy(fullAccepted, "a complete addon sender matching the roster should announce its own peer")
local peers = ns.modules.syncPeerState.GetPeers(db, "Tyrrish Rebellion")
assert.equal(1, #peers, "full-name traffic should register exactly one peer")
assert.equal("Ziri Jr", peers[1].characterKey, "the peer key should come from the verified sender, not the payload")

local function request_message(actorName, requestId)
    return ns.modules.syncCodec.EncodeTable({
        type = "REQUEST_CREATED",
        updatedAt = 110,
        payload = {
            guildKey = "Tyrrish Rebellion",
            actorContext = {
                name = actorName,
                characterKey = actorName,
                guildRankIndex = 4,
                inGuild = true,
            },
            request = {
                requestId = requestId,
                requester = actorName,
                requesterCharacterKey = actorName,
                itemID = 2589,
                itemName = "Linen Cloth",
                quantity = 1,
                approval = "PENDING",
                fulfillment = "OPEN",
                updatedAt = 110,
            },
        },
    })
end

local forged = ns.modules.syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", request_message("Ziri Shadow", "forever-forged"), "GUILD", "Ziri Jr")
assert.truthy(not forged, "a member with the same first name must not claim another member's full identity")
assert.equal(0, #(db.requests or {}), "a same-first-name forgery must not create a request")
local accepted = ns.modules.syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", request_message("Ziri Jr", "forever-valid"), "GUILD", "Ziri Jr")
assert.truthy(accepted, "a full sender and matching actor should still sync a legitimate request")
assert.equal("Ziri Jr", db.requests[1].requesterCharacterKey, "the accepted request must retain the complete requester key")

_G.UnitGUID = function()
    return nil
end
local unresolved = permissions.GetLivePlayerContext({})
assert.truthy(not unresolved.identityVerified, "a first name alone must not be a verified Forever identity")
local manual = ns.modules.syncManualActions.Run(db, { action = "requests", accessProfile = "full_shell", now = 200 })
assert.truthy(not manual.ok and manual.message:find("full Forever name", 1, true), "manual sync should explain why an unresolved full name cannot send")
local sendCount = #(_G.C_ChatInfo.sentMessages or {})
local sent, reason = ns.modules.syncTransport.Send("GUILD", "GUILD", { type = "SYNC_HELLO", payload = unresolved.characterKey })
assert.equal(false, sent, "Forever should not send sync traffic with an unresolved local identity")
assert.equal("identity_unverified", reason, "an unresolved send should explain why it was withheld")
assert.equal(sendCount, #(_G.C_ChatInfo.sentMessages or {}), "an unresolved send should not reach the addon channel")

_G.UnitGUID = function()
    return "Player-4620-0077C499"
end
_G.issecretvalue = function(value)
    return value == "Player-4620-0077C499"
end
assert.truthy(not permissions.GetLivePlayerContext({}).identityVerified, "a restricted player GUID must not be compared or used for sync identity")
_G.issecretvalue = previousIsSecretValue
local savedRoster = roster
roster = {}
local sentHelloCount = 0
local originalSend = ns.modules.syncTransport.Send
ns.modules.syncTransport.Send = function(_, _, message)
    if message.type == "SYNC_HELLO" then
        sentHelloCount = sentHelloCount + 1
    end
    return true
end
ns.modules.syncEvents.HandleEvent("PLAYER_LOGIN")
assert.equal(0, sentHelloCount, "Forever must wait for a GUID-matched roster identity before announcing itself")
roster = savedRoster
ns.modules.syncEvents.HandleEvent("GUILD_ROSTER_UPDATE")
assert.equal(1, sentHelloCount, "Forever should announce itself when the complete roster identity becomes available")
ns.modules.syncTransport.Send = originalSend
ns.IsForever = originalIsForever
_G.GBankManagerNamespace = previousNamespace
_G.GBankManagerDB = previousDatabase
_G.UnitName = previousUnitName
_G.UnitGUID = previousUnitGUID
_G.GetRealmName = previousRealmName
_G.GetGuildInfo = previousGuildInfo
_G.GetNumGuildMembers = previousGuildCount
_G.GetGuildRosterInfo = previousRosterInfo
_G.issecretvalue = previousIsSecretValue
