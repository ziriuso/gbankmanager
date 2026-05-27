package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
_G.C_Timer.ClearPending()
_G.DEFAULT_CHAT_FRAME.messages = {}

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame
local slash = env.slash
local scanner = env.scanner
local auth = env.ns.modules.auth or env.ns.modules.permissions

local originalGetLivePlayerContext = auth.GetLivePlayerContext
local originalGetEffectiveAccessProfile = auth.GetEffectiveAccessProfile
local originalBeginScan = scanner.BeginScan

local scanCalls = 0
scanner.BeginScan = function()
    scanCalls = scanCalls + 1
end

auth.GetLivePlayerContext = function()
    return {
        name = "GuildLead",
        characterKey = "Stormrage-GuildLead",
    }
end

auth.GetEffectiveAccessProfile = function()
    return "full_shell"
end

mainFrame:Hide()
slash.command("")
assert.equal("DASHBOARD", mainFrame.activeView, "/gbm should open the full shell for full-shell access")
assert.truthy(mainFrame:IsShown(), "/gbm should show the addon shell")
assert.equal(0, scanCalls, "/gbm should stop triggering a bank scan by default")

auth.GetEffectiveAccessProfile = function()
    return "request_only"
end

if mainFrame.requestWizardModal then
    mainFrame.requestWizardModal:Hide()
end
slash.command("")
_G.C_Timer.RunPending()
assert.equal("REQUESTS", mainFrame.activeView, "/gbm should switch to Requests for request-only access")
assert.truthy(mainFrame.requestWizardModal:IsShown(), "/gbm should open the request wizard for request-only access")

_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("help")
local helpText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(helpText, "/gbm", 1, true) ~= nil, "/gbm help should describe the base slash command")
assert.truthy(string.find(helpText, "/gbm help", 1, true) ~= nil, "/gbm help should include the help command")
assert.truthy(string.find(helpText, "/gbm scan", 1, true) ~= nil, "/gbm help should include the scan command")
assert.truthy(string.find(helpText, "/gbm ui", 1, true) ~= nil, "/gbm help should include the full-shell command")
assert.truthy(string.find(helpText, "/gbm request", 1, true) ~= nil, "/gbm help should include the request-only command")
assert.truthy(string.find(helpText, "/gbm test smoke", 1, true) ~= nil, "/gbm help should include the smoke test command")
assert.truthy(string.find(helpText, "/gbm test unit", 1, true) ~= nil, "/gbm help should include the unit test command")
assert.truthy(string.find(helpText, "/gbm debug quality", 1, true) ~= nil, "/gbm help should include the crafted-quality debug command")

_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("debug quality 241322")
local debugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(debugText, "Crafted quality debug for 241322", 1, true) ~= nil, "slash debug quality should label the inspected item id")
assert.truthy(string.find(debugText, "final atlas", 1, true) ~= nil, "slash debug quality should report the final chosen atlas")
assert.truthy(string.find(debugText, "Interface-Crafting-ReagentQuality-2-Med", 1, true) ~= nil, "slash debug quality should report the bundled two-rank inline atlas for non-inventory surfaces")
assert.truthy(string.find(debugText, "final display atlas=Interface-Crafting-ReagentQuality-2-Med", 1, true) ~= nil, "slash debug quality should still report the separate bundled texture-display atlas")

local originalCraftedQuality = env.ns.modules.craftedQuality
env.ns.modules.craftedQuality = nil
_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("debug quality 241322")
local lazyLoadedDebugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(lazyLoadedDebugText, "GBankManager: Crafted quality debug for 241322", 1, true) ~= nil, "slash debug quality should still emit chat feedback after lazily loading crafted-quality helpers")
env.ns.modules.craftedQuality = originalCraftedQuality

scanner.BeginScan = originalBeginScan
auth.GetLivePlayerContext = originalGetLivePlayerContext
auth.GetEffectiveAccessProfile = originalGetEffectiveAccessProfile
