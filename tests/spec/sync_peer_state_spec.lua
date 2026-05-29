local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local defaults = dofile("GBankManager/Data/Defaults.lua")
local migrations = dofile("GBankManager/Data/Migrations.lua")
local peerState = dofile("GBankManager/Sync/PeerState.lua")

local function fresh_db()
    local root = migrations.Apply(defaults.CreateDatabase("Guild Testers"), "Guild Testers")
    if type(root.guilds) == "table" then
        return root.guilds[root.activeGuildKey or "Guild Testers"] or root.guilds["Guild Testers"] or {}
    end

    return root
end

local db = fresh_db()

peerState.TouchPeer(db, {
    guildKey = "Guild Testers",
    characterKey = "Stormrage-OfficerOne",
    version = "0.9.0-beta.3",
    messageType = "SYNC_HELLO",
    seenAt = 1717000000,
})

local peers = (((db.syncState or {}).peers or {})["Guild Testers"] or {})
assert.equal(1717000000, tonumber(((peers["Stormrage-OfficerOne"] or {}).lastSeen) or 0), "peer state should persist the last seen timestamp by guild key")
assert.equal("SYNC_HELLO", ((peers["Stormrage-OfficerOne"] or {}).lastMessageType), "peer state should persist the last message type")
assert.equal("0.9.0-beta.3", ((peers["Stormrage-OfficerOne"] or {}).version), "peer state should persist the last reported addon version")

peerState.TouchPeer(db, {
    guildKey = "Bank Alts",
    characterKey = "Stormrage-OfficerOne",
    version = "0.9.0-beta.3",
    messageType = "REQUEST_UPDATED",
    seenAt = 1717001111,
})

assert.equal(1717000000, tonumber((((db.syncState or {}).peers or {})["Guild Testers"]["Stormrage-OfficerOne"] or {}).lastSeen or 0), "touching a peer in another guild should not bleed over the active guild peer history")
assert.equal(1717001111, tonumber((((db.syncState or {}).peers or {})["Bank Alts"]["Stormrage-OfficerOne"] or {}).lastSeen or 0), "peer state should keep independent per-guild peer history buckets")
