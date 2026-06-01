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
local onboarding = env.ns.modules.onboarding

local originalGetLivePlayerContext = auth.GetLivePlayerContext
local originalGetEffectiveAccessProfile = auth.GetEffectiveAccessProfile
local originalBeginScan = scanner.BeginScan
local originalShouldAutoOpen = onboarding.ShouldAutoOpen

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

onboarding.ShouldAutoOpen = function()
    return false
end

if mainFrame.requestWizardModal then
    mainFrame.requestWizardModal:Hide()
end
slash.command("")
_G.C_Timer.RunPending()
assert.equal("REQUESTS", mainFrame.activeView, "/gbm should switch to Requests for request-only access")
assert.truthy(mainFrame:IsShown(), "/gbm should keep the request-only shell visible")
assert.truthy(mainFrame.requestOnlyMode == true, "/gbm should keep request-only mode active for request-only access")
assert.truthy(mainFrame.requestWorkflowPanel:IsShown(), "/gbm should open the request-only request UI for request-only access")
assert.truthy(not mainFrame.requestWizardModal:IsShown(), "/gbm should not auto-open the request wizard for request-only access")

local originalOpenOnboarding = mainFrame.OpenOnboarding
local openedFlow = nil
mainFrame.OpenOnboarding = function(_, flowKey, options)
    openedFlow = {
        flowKey = flowKey,
        reason = options and options.reason,
    }
end

onboarding.ShouldAutoOpen = function(_, flowKey)
    return flowKey == "manager"
end

auth.GetEffectiveAccessProfile = function()
    return "full_shell"
end

openedFlow = nil
slash.command("")
assert.equal("manager", openedFlow and openedFlow.flowKey, "/gbm should auto-open manager onboarding for a first-run full-shell user")
assert.equal("slash_default", openedFlow and openedFlow.reason, "/gbm should report the default slash-open reason")

onboarding.ShouldAutoOpen = function(_, flowKey)
    return flowKey == "requestOnly"
end

auth.GetEffectiveAccessProfile = function()
    return "request_only"
end

openedFlow = nil
slash.command("")
assert.equal("requestOnly", openedFlow and openedFlow.flowKey, "/gbm should auto-open request onboarding for a first-run request-only user")
assert.equal("slash_default", openedFlow and openedFlow.reason, "/gbm should report the default slash-open reason for request-only onboarding")

mainFrame.OpenOnboarding = originalOpenOnboarding
onboarding.ShouldAutoOpen = originalShouldAutoOpen

_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("help")
local helpText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(helpText, "/gbm", 1, true) ~= nil, "/gbm help should describe the base slash command")
assert.truthy(string.find(helpText, "/gbm help", 1, true) ~= nil, "/gbm help should include the help command")
assert.truthy(string.find(helpText, "/gbm scan", 1, true) ~= nil, "/gbm help should include the scan command")
assert.truthy(string.find(helpText, "/gbm sync", 1, true) ~= nil, "/gbm help should include the sync command")
assert.truthy(string.find(helpText, "[requests/minimums/ledger/all]", 1, true) ~= nil, "/gbm help should render sync actions without WoW chat escape collisions")
assert.truthy(string.find(helpText, "/gbm ui", 1, true) ~= nil, "/gbm help should include the full-shell command")
assert.truthy(string.find(helpText, "/gbm request", 1, true) ~= nil, "/gbm help should include the request-only command")
assert.truthy(string.find(helpText, "/gbm auth", 1, true) == nil, "/gbm help should stop exposing the retired auth policy slash command")
assert.truthy(string.find(helpText, "/gbm test", 1, true) == nil, "/gbm help should not expose internal test commands")
assert.truthy(string.find(helpText, "/gbm debug", 1, true) == nil, "/gbm help should not expose internal debug commands")

local originalSyncManualActions = env.ns.modules.syncManualActions
local capturedSyncCalls = {}
env.ns.modules.syncManualActions = {
    ResolveDefaultAction = function(profile)
        if profile == "request_only" then
            return "requests"
        end

        return "all"
    end,
    Run = function(_, options)
        capturedSyncCalls[#capturedSyncCalls + 1] = {
            action = options.action,
            accessProfile = options.accessProfile,
        }
        return {
            ok = true,
            message = "Triggered sync.",
        }
    end,
}

auth.GetEffectiveAccessProfile = function()
    return "full_shell"
end

capturedSyncCalls = {}
_G.DEFAULT_CHAT_FRAME.messages = {}
slash.command("sync")
slash.command("sync requests")
slash.command("sync ledger")
assert.equal("all", (capturedSyncCalls[1] or {}).action, "bare /gbm sync should default to all for full-shell access")
assert.equal("requests", (capturedSyncCalls[2] or {}).action, "explicit /gbm sync requests should route to requests")
assert.equal("ledger", (capturedSyncCalls[3] or {}).action, "explicit /gbm sync ledger should route to ledger")

auth.GetEffectiveAccessProfile = function()
    return "request_only"
end

capturedSyncCalls = {}
slash.command("sync")
assert.equal("requests", (capturedSyncCalls[1] or {}).action, "bare /gbm sync should default to requests for request-only access")
assert.equal("request_only", (capturedSyncCalls[1] or {}).accessProfile, "slash sync should forward the active access profile")
env.ns.modules.syncManualActions = originalSyncManualActions

_G.DEFAULT_CHAT_FRAME.messages = {}
local retiredAuthResult = slash.command("auth")
assert.equal("unknown_command", retiredAuthResult, "/gbm auth should be treated as a retired slash command")
assert.truthy(string.find(table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n"), "/gbm auth", 1, true) == nil, "retired /gbm auth should not come back through fallback help output")

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

_G.GetNumGuildBankTabs = function()
    return 1
end
_G.GetGuildBankTabInfo = function()
    return "Donations", nil, true
end
_G.GetNumGuildBankTransactions = function(tabIndex)
    if tabIndex == 1 then
        return 1
    end
    return 0
end
_G.GetGuildBankTransaction = function(tabIndex, index)
    if tabIndex == 1 and index == 1 then
        return "deposit", "GuildLead-Stormrage", "item:211878:0:0:0", 12, nil, nil, 0, 0, 0, 1
    end
end
_G.GetNumGuildBankMoneyTransactions = function()
    return 1
end
_G.GetGuildBankMoneyTransaction = function(index)
    if index == 1 then
        return "deposit", "GuildLead-Stormrage", 500000000, 0, 0, 0, 1
    end
end
scanner.scanInProgress = true
scanner.ledgerScanInProgress = false
scanner.pendingLedgerScanAfterInventory = true
scanner.pendingLedgerAutoScan = false
_G.DEFAULT_CHAT_FRAME.messages = {}
local ledgerDebugLines = slash.command("debug ledger")
local ledgerDebugText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(type(ledgerDebugLines) == "table", "/gbm debug ledger should return copy-friendly diagnostic lines")
assert.truthy(string.find(ledgerDebugText, "ledger debug state scanInProgress=true ledgerScanInProgress=false pendingAfterInventory=true", 1, true) ~= nil, "/gbm debug ledger should report scanner state flags")
assert.truthy(string.find(ledgerDebugText, "ledger debug tabs count=1", 1, true) ~= nil, "/gbm debug ledger should report guild-bank tab count")
assert.truthy(string.find(ledgerDebugText, "itemLog tab=1 name=Donations viewable=true count=1", 1, true) ~= nil, "/gbm debug ledger should report raw visible item-log counts")
assert.truthy(string.find(ledgerDebugText, "moneyLog queryId=9 count=1", 1, true) ~= nil, "/gbm debug ledger should report raw money-log counts")
assert.truthy(string.find(ledgerDebugText, "money[1] type=deposit who=GuildLead-Stormrage amount=500000000 age=0/0/0/1", 1, true) ~= nil, "/gbm debug ledger should include a raw money-log sample row")

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
