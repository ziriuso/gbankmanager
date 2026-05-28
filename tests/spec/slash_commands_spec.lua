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
assert.truthy(string.find(helpText, "/gbm debug atlas", 1, true) ~= nil, "/gbm help should include the crafted-quality atlas sampler command")
assert.truthy(string.find(helpText, "/gbm debug render", 1, true) ~= nil, "/gbm help should include the table render diagnostics command")
assert.truthy(string.find(helpText, "/gbm debug request", 1, true) ~= nil, "/gbm help should include the request wizard diagnostics command")

_G.DEFAULT_CHAT_FRAME.messages = {}
local atlasSampler = slash.command("debug atlas")
local atlasSamplerText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(type(atlasSampler) == "table", "/gbm debug atlas should return the sampler frame for test inspection")
assert.truthy(atlasSampler:IsShown(), "/gbm debug atlas should show the atlas sampler")
assert.truthy(type(atlasSampler.rows) == "table" and #atlasSampler.rows >= 8, "/gbm debug atlas should render a useful set of atlas candidates")
assert.equal("Professions-Icon-Quality-12-Tier1-Inv", atlasSampler.rows[1].atlasName, "/gbm debug atlas should start with the proved low-rank atlas candidate")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", atlasSampler.rows[2].atlasName, "/gbm debug atlas should include the proved high-rank atlas candidate")
assert.truthy(atlasSampler.rows[1].fixedIcon.atlas == atlasSampler.rows[1].atlasName, "/gbm debug atlas should paint the fixed-size preview from the atlas name")
assert.truthy(atlasSampler.rows[1].atlasSizedIcon.useAtlasSize == true, "/gbm debug atlas should also paint an atlas-sized preview")
assert.truthy(string.find(atlasSamplerText, "Atlas sampler opened", 1, true) ~= nil, "/gbm debug atlas should explain what to inspect")

mainFrame.activeView = "EXPORTS"
mainFrame:ConfigureTable({
    { key = "itemDisplayText", label = "Item", width = 260 },
    { key = "itemTier", label = "Tier", width = 80 },
}, {
    {
        itemID = "241322",
        itemName = "Flask of the Magisters",
        itemDisplayText = "Flask of the Magisters",
        itemDisplayTextIconAtlas = "Professions-Icon-Quality-Tier2-Inv",
        itemTier = "",
        itemTierIconAtlas = "Professions-Icon-Quality-Tier2-Inv",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityMax = 2,
    },
})
mainFrame:RefreshVisibleTableRows()
_G.DEFAULT_CHAT_FRAME.messages = {}
local renderLines = slash.command("debug render 241322")
local renderText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(type(renderLines) == "table", "/gbm debug render should return diagnostic lines for tests")
assert.truthy(string.find(renderText, "render debug itemID=241322 activeView=EXPORTS", 1, true) ~= nil, "/gbm debug render should report the active view")
assert.truthy(string.find(renderText, "itemDisplayTextIconAtlas=Professions-Icon-Quality-Tier2-Inv", 1, true) ~= nil, "/gbm debug render should report pre-render row atlas fields")
assert.truthy(string.find(renderText, "visible[1].col1.key=itemDisplayText atlas=Professions-Icon-Quality-12-Tier2-Inv", 1, true) ~= nil, "/gbm debug render should report the atlas painted by the visible shared table texture")

mainFrame:OpenRequestWizard()
mainFrame.requestCreateSearchSelector:ShowMatches({
    {
        itemID = 241326,
        name = "Flask of the Shattered Sun",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityFamilySize = 2,
        craftedQualityDisplayAtlas = "Professions-Icon-Quality-12-Tier2-Inv",
    },
})
_G.DEFAULT_CHAT_FRAME.messages = {}
local requestDebugLines = slash.command("debug request 241326")
local requestDebugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(type(requestDebugLines) == "table", "/gbm debug request should return request wizard diagnostics for tests")
assert.truthy(string.find(requestDebugText, "request debug itemID=241326", 1, true) ~= nil, "/gbm debug request should report the inspected item id")
assert.truthy(string.find(requestDebugText, "result[1].itemID=241326", 1, true) ~= nil, "/gbm debug request should report visible request selector rows")
assert.truthy(string.find(requestDebugText, "qualityAtlas=Professions-Icon-Quality-12-Tier2-Inv shown=true", 1, true) ~= nil, "/gbm debug request should report the icon painted in the request wizard result row")

_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("debug quality 241322")
local debugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(debugText, "Crafted quality debug for 241322", 1, true) ~= nil, "slash debug quality should label the inspected item id")
assert.truthy(string.find(debugText, "final atlas", 1, true) ~= nil, "slash debug quality should report the final chosen atlas")
assert.truthy(string.find(debugText, "final non-inventory atlas=Professions-Icon-Quality-12-Tier2-Inv", 1, true) ~= nil, "slash debug quality should report the visible bundled higher-rank non-inventory atlas")
assert.truthy(string.find(debugText, "final display atlas=Professions-Icon-Quality-12-Tier2-Inv", 1, true) ~= nil, "slash debug quality should report the higher-rank gold-pentagram display atlas")

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
