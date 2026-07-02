local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

_G.UnitName = function()
    return "GuildLead"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Guild Master", 0
end

_G.__guildRoster = {
    {
        name = "MemberOne",
        rankName = "Officer",
        rankIndex = 1,
        online = true,
    },
    {
        name = "GuildLead",
        rankName = "Guild Master",
        rankIndex = 0,
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

local chatOutput = ns.modules.chatOutput
local transport = ns.modules.syncTransport
local slash = ns.modules.slash
local scanner = ns.modules.scanner
local db = ns.state.db

assert.truthy(type(chatOutput) == "table", "chat output module should load from the toc")
assert.truthy(type(chatOutput.Send) == "function", "chat output module should expose a shared Send helper")
assert.truthy(type(db.ui.chatSettings) == "table", "database defaults should include persisted chat settings")
assert.equal(true, db.ui.chatSettings.suppressRoutineMessages, "routine chat suppression should default on")

_G.DEFAULT_CHAT_FRAME.messages = {}
db.ui.chatSettings.suppressRoutineMessages = false
chatOutput.Send("GBankManager: Routine scan line.", { category = "routine" })
assert.equal("GBankManager: Routine scan line.", _G.DEFAULT_CHAT_FRAME.messages[1], "routine chat should remain visible by default")

db.ui.chatSettings.suppressRoutineMessages = true
_G.DEFAULT_CHAT_FRAME.messages = {}
chatOutput.Send("GBankManager: Routine scan line.", { category = "routine" })
assert.equal(0, #_G.DEFAULT_CHAT_FRAME.messages, "routine chat should be suppressed when the global mute is enabled")

chatOutput.Send("GBankManager: Guild bank ledger scan failed: timeout.", { category = "error" })
assert.equal("GBankManager: Guild bank ledger scan failed: timeout.", _G.DEFAULT_CHAT_FRAME.messages[1], "error chat should bypass routine suppression")

chatOutput.Send("GBankManager: sync debug local name=GuildLead", { category = "debug" })
assert.equal("GBankManager: sync debug local name=GuildLead", _G.DEFAULT_CHAT_FRAME.messages[2], "debug chat should bypass routine suppression")

_G.DEFAULT_CHAT_FRAME.messages = {}
transport.ReportStatus("Synced ledger delta from OfficerOne.")
assert.equal(0, #_G.DEFAULT_CHAT_FRAME.messages, "sync status helper should treat accepted sync chatter as routine")

_G.GetNumGuildBankTabs = function()
    return 1
end
_G.GetGuildBankTabInfo = function()
    return "Donations", nil, true
end
_G.QueryGuildBankTab = function() end
db.auth.capabilities.full_ui = { [0] = true, [1] = true }
scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.BeginScan()
assert.equal("Scanning 0/1 tabs", scanner:GetStatusText(), "muted scan chat should still update the visible scanner status")
assert.equal(0, #_G.DEFAULT_CHAT_FRAME.messages, "manual scan start chatter should use the muted routine output path")

_G.DEFAULT_CHAT_FRAME.messages = {}
db.ui.chatSettings.suppressRoutineMessages = true
slash.command("debug sync")
local debugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(debugText, "GBankManager: sync debug local", 1, true) ~= nil, "explicit debug slash output should stay visible while routine chat is muted")

db.ui.chatSettings.suppressRoutineMessages = false
_G.DEFAULT_CHAT_FRAME.messages = {}

local codec = ns.modules.syncCodec
local syncEvents = ns.modules.syncEvents
local bankLedger = ns.modules.bankLedger
local originalMergeBucketRows = bankLedger.MergeBucketRows
local function clone_table(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = clone_table(nested)
    end
    return copy
end

local originalSyncState = clone_table(db.syncState)
local originalLastSyncMessage = clone_table(ns.state.lastSyncMessage)
local originalLastSyncDecision = clone_table(ns.state.lastSyncDecision)
local function fire_bucket_reply(mergedCount)
    bankLedger.MergeBucketRows = function()
        return mergedCount
    end

    return syncEvents.HandleEvent(
        "CHAT_MSG_ADDON",
        "GBankManager",
        codec.EncodeTable({
            type = "LEDGER_BUCKET_REPLY",
            updatedAt = 700,
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
                ledgerProtocol = tonumber((ns.constants or {}).LEDGER_PROTOCOL_VERSION or 0) or 0,
                target = "GuildLead",
                buckets = { 3 },
                rows = { item = {}, money = {} },
            },
        }),
        "GUILD",
        "MemberOne"
    )
end

fire_bucket_reply(0)
assert.equal(0, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "zero-row bucket replies should not emit routine chat")

_G.DEFAULT_CHAT_FRAME.messages = {}
fire_bucket_reply(1)
assert.truthy(string.find(((_G.DEFAULT_CHAT_FRAME.messages or {})[1]) or "", "Synced 1 ledger bucket row", 1, true) ~= nil, "positive bucket replies may emit one useful routine status line")
bankLedger.MergeBucketRows = originalMergeBucketRows
db.syncState = originalSyncState
ns.state.lastSyncMessage = originalLastSyncMessage
ns.state.lastSyncDecision = originalLastSyncDecision
