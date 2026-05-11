local assert = require("tests.helpers.assert")

local coordinator = dofile("GBankManager/Sync/Coordinator.lua")
local codec = dofile("GBankManager/Sync/Codec.lua")
local transport = dofile("GBankManager/Sync/Transport.lua")

local resolved = coordinator.ResolveConflict(
    { role = "MEMBER", updatedAt = 100, approval = "PENDING" },
    { role = "OFFICER", updatedAt = 90, approval = "APPROVED" }
)

assert.equal("APPROVED", resolved.approval, "officer authority should beat newer member record")

local encoded = codec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 44,
    payload = "OfficerOne",
})

assert.equal("SYNC_HELLO|44|OfficerOne", encoded, "codec should serialize sync messages")

local decoded = codec.DecodeTable(encoded)
assert.equal("SYNC_HELLO", decoded.type, "codec should restore message type")
assert.equal(44, decoded.updatedAt, "codec should restore update timestamps")
assert.equal("OfficerOne", decoded.payload, "codec should restore message payload")

_G.C_ChatInfo.sentMessages = {}
transport.Send("GUILD", "GUILD", {
    type = "SYNC_HELLO",
    updatedAt = 55,
    payload = "GuildLead",
})

assert.equal(1, #_G.C_ChatInfo.sentMessages, "transport should send addon messages through chat info")
assert.equal("GBankManager", _G.C_ChatInfo.sentMessages[1].prefix, "transport should use addon prefix")
assert.equal("SYNC_HELLO|55|GuildLead", _G.C_ChatInfo.sentMessages[1].payload, "transport should send encoded sync payload")

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local events = ns.modules.events

assert.truthy(type(events) == "table", "events module should load from the toc")
assert.truthy(type(events.GetScript) == "function", "events module should expose frame scripts")

local hasPlayerLogin = false
local hasChatMsgAddon = false
for _, eventName in ipairs(events.events or {}) do
    if eventName == "PLAYER_LOGIN" then
        hasPlayerLogin = true
    elseif eventName == "CHAT_MSG_ADDON" then
        hasChatMsgAddon = true
    end
end

assert.truthy(hasPlayerLogin, "task 7 events should listen for player login")
assert.truthy(hasChatMsgAddon, "task 7 events should listen for addon messages")

_G.C_ChatInfo.sentMessages = {}
_G.C_ChatInfo.registeredPrefixes = {}

local onEvent = events:GetScript("OnEvent")
onEvent(events, "PLAYER_LOGIN")

assert.equal("GBankManager", _G.C_ChatInfo.registeredPrefixes[1], "player login should register the addon message prefix")
assert.equal(1, #_G.C_ChatInfo.sentMessages, "player login should send a sync hello")
assert.equal("SYNC_HELLO|0|TestPlayer", _G.C_ChatInfo.sentMessages[1].payload, "sync hello should include the current player")
