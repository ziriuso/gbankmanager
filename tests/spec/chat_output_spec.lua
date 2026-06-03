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

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")

local chatOutput = ns.modules.chatOutput
local transport = ns.modules.syncTransport
local slash = ns.modules.slash
local scanner = ns.modules.scanner
local db = ns.state.db

assert.truthy(type(chatOutput) == "table", "chat output module should load from the toc")
assert.truthy(type(chatOutput.Send) == "function", "chat output module should expose a shared Send helper")
assert.truthy(type(db.ui.chatSettings) == "table", "database defaults should include persisted chat settings")
assert.truthy(db.ui.chatSettings.suppressRoutineMessages ~= true, "routine chat suppression should default off")

_G.DEFAULT_CHAT_FRAME.messages = {}
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
