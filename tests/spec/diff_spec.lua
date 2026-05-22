local assert = require("tests.helpers.assert")

_G.UnitName = function()
    return "OfficerOne"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

local function load_module(path, addonName, ns)
    local chunk, loadError = loadfile(path)
    if not chunk then
        error(loadError)
    end

    return chunk(addonName, ns)
end

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")

local snapshots = ns.modules.snapshots
local diff = ns.modules.diff
local scanner = ns.modules.scanner
local dashboard = ns.modules.dashboardView
local historyView = ns.modules.historyView

local snapshot = snapshots.FromTabScan({
    scanId = "scan-2",
    guildName = "My Guild",
    actor = "OfficerOne",
    scannedTabs = {
        {
            index = 1,
            name = "Flasks",
            slots = {
                { itemID = 1001, name = "Flask Alpha", count = 4 },
                { itemID = 1001, name = "Flask Alpha", count = 6 },
            },
        },
        {
            index = 2,
            name = "Raid",
            slots = {
                { itemID = 1001, name = "Flask Alpha", count = 5 },
            },
        },
    },
})

local previous = {
    items = {
        [1001] = {
            itemID = 1001,
            name = "Flask Alpha",
            totalCount = 3,
            tabs = {
                Flasks = 3,
            },
        },
    },
}

local changes = diff.BuildChangeLog(previous, snapshot)

assert.truthy(type(snapshots) == "table", "snapshots module should load from the toc")
assert.truthy(type(diff) == "table", "diff module should load from the toc")
assert.truthy(type(scanner) == "table", "scanner module should load")
assert.truthy(type(dashboard) == "table", "dashboard view should load from the toc")
assert.truthy(type(historyView) == "table", "history view should load from the toc")
assert.equal(15, snapshot.items[1001].totalCount, "snapshot should aggregate duplicate item stacks")
assert.equal(2, #snapshot.itemRows, "snapshot should preserve one canonical item row per bank tab")
assert.equal("Flasks", snapshot.itemRows[1].tabName, "snapshot item rows should keep the source bank tab")
assert.equal(10, snapshot.itemRows[1].quantity, "snapshot item rows should aggregate same-tab stacks")
assert.equal("Raid", snapshot.itemRows[2].tabName, "snapshot item rows should keep later bank tabs for the same item")
assert.equal(5, snapshot.itemRows[2].quantity, "snapshot item rows should keep per-tab quantities")
assert.equal("QUANTITY_INCREASED", changes[1].type, "diff should report quantity increase")
assert.equal(12, changes[1].delta, "diff should capture quantity delta")

local originalDate = _G.date
local dateCalls = {}
_G.date = function(format, timestamp)
    table.insert(dateCalls, {
        format = format,
        timestamp = timestamp,
    })

    return "2026-05-12 08:15 Eastern Daylight Time"
end

local dashboardLines = dashboard.BuildLines({
    meta = {
        updatedAt = 1715523300,
    },
    requests = {},
}, {})
local dashboardCards = dashboard.BuildCards({
    meta = {
        updatedAt = 1715523300,
    },
    changeLog = {},
    snapshots = {},
    requests = {},
}, {})
local historyRows = historyView.BuildTableRows({
    {
        type = "REQUEST_APPROVED",
        category = "REQUEST",
        actor = "GuildLead",
        itemName = "Flask Alpha",
        oldValue = "PENDING",
        newValue = "APPROVED",
        timestamp = 1715523300,
    },
}, {})

_G.date = originalDate

assert.equal("Last scan: 2026-05-12 08:15 EDT", dashboardLines[1], "dashboard lines should abbreviate localized scan timezones for display")
assert.equal("2026-05-12 08:15 EDT", dashboardCards[1].value, "dashboard cards should abbreviate localized scan timezones for display")
assert.equal("2026-05-12 08:15 EDT", historyRows[1].date, "history rows should abbreviate localized audit timezones for display")
assert.equal("%Y-%m-%d %H:%M %Z", dateCalls[1].format, "dashboard timestamp display should include the player's local timezone")
assert.equal(1715523300, dateCalls[1].timestamp, "dashboard timestamp display should format the stored UTC timestamp directly")

_G.GetNumGuildBankTabs = function()
    return 3
end

local queriedTabs = {}
_G.QueryGuildBankTab = function(tabIndex)
    table.insert(queriedTabs, tabIndex)
end

_G.GetGuildBankTabInfo = function(tabIndex)
    if tabIndex == 1 then
        return "Flasks", nil, true
    elseif tabIndex == 2 then
        return "Locked", nil, false
    elseif tabIndex == 3 then
        return "Potions", nil, true
    end
end

scanner.BeginScan()
assert.equal(2, scanner.totalTabs, "scanner should count only accessible tabs when a scan begins")
assert.equal(1, #scanner.tabsToScan, "scanner should keep remaining tabs queued after requesting the first tab")
assert.equal(3, scanner.tabsToScan[1], "scanner should leave later accessible tabs queued")
assert.equal(1, queriedTabs[1], "scanner should request the first tab immediately")
assert.equal("Scanning 0/2 tabs", scanner:GetStatusText(), "scanner should report queued scan progress")

_G.GetGuildBankItemInfo = function(tabIndex, slot)
    if tabIndex == 1 and slot == 1 then
        return nil, 4
    elseif tabIndex == 1 and slot == 2 then
        return nil, 2
    end

    return nil, 0
end

_G.GetGuildBankItemLink = function(tabIndex, slot)
    if tabIndex == 1 and slot == 1 then
        return "item:1001:0:0:0"
    elseif tabIndex == 1 and slot == 2 then
        return "item:2002:0:0:0"
    end
end

_G.C_Item = {
    GetItemNameByID = function(itemID)
        local names = {
            [1001] = "Flask Alpha",
            [2002] = "Potion Beta",
        }
        return names[itemID]
    end,
}

_G.C_TradeSkillUI = {
    GetItemCraftedQualityInfo = function(itemInfo)
        if itemInfo == "item:1001:0:0:0" then
            return {
                quality = 3,
                icon = "Professions-ChatIcon-Quality-Tier3",
            }
        end
    end,
}

local tabData = scanner.ReadCurrentTab(1)

assert.equal("Flasks", tabData.name, "scanner should label scanned tabs from guild bank metadata")
assert.equal(2, #tabData.slots, "scanner should collect populated slots only")
assert.equal(1001, tabData.slots[1].itemID, "scanner should parse item ids from links")
assert.equal(3, tabData.slots[1].craftedQuality, "scanner should capture crafted quality tier when the API provides it")
assert.equal("Professions-ChatIcon-Quality-Tier3", tabData.slots[1].craftedQualityIcon, "scanner should capture crafted quality atlas info for inventory display")
assert.equal(1, #scanner.rawTabs, "scanner should append scanned tabs to the raw scan state")

scanner.OnGuildBankSlotsChanged()
assert.equal(3, queriedTabs[2], "scanner should request the next queued tab after a tab finishes loading")
assert.equal("Scanning 1/2 tabs", scanner:GetStatusText(), "scanner should report completed tab progress")

local originalTime = _G.time
local originalBeginScan = scanner.BeginScan
local originalReadCurrentTab = scanner.ReadCurrentTab
local originalRetryPendingAutoScan = scanner.RetryPendingAutoScan
local originalMessages = _G.DEFAULT_CHAT_FRAME.messages
local autoScanCalls = 0
_G.time = function()
    return 1000
end
_G.C_Timer.ClearPending()
_G.DEFAULT_CHAT_FRAME.messages = {}

ns.state.db.meta.updatedAt = 0
scanner.scanInProgress = false
scanner.BeginScan = function()
    autoScanCalls = autoScanCalls + 1
    scanner.scanInProgress = true
    return "Scanning 0/2 tabs"
end

scanner.OnGuildBankOpened()
assert.equal(1, autoScanCalls, "opening the guild bank should auto-scan when there is no prior scan timestamp")

scanner.scanInProgress = false
ns.state.db.meta.updatedAt = 0
scanner.pendingAutoScan = false
scanner.OnGuildBankTabsUpdated()
assert.equal(2, autoScanCalls, "guild bank tab updates should also be able to start the first auto-scan if the open event was missed or premature")

scanner.scanInProgress = false
ns.state.db.meta.updatedAt = 500
scanner.OnGuildBankOpened()
assert.equal(2, autoScanCalls, "opening the guild bank within the throttle window should skip auto-scan")

scanner.scanInProgress = false
_G.time = function()
    return 1100
end
scanner.OnGuildBankOpened()
assert.equal(3, autoScanCalls, "opening the guild bank after 10 minutes should auto-scan again")

scanner.scanInProgress = true
_G.time = function()
    return 1800
end
scanner.OnGuildBankOpened()
assert.equal(3, autoScanCalls, "auto-scan should not restart while a scan is already in progress")

scanner.BeginScan = originalBeginScan
scanner.scanInProgress = false
ns.state.db.meta.updatedAt = 1750
queriedTabs = {}
scanner.BeginScan()
assert.equal(1, queriedTabs[1], "manual scan should still run even inside the auto-scan throttle window")
assert.equal("GBankManager: Guild bank scan started (2 tabs).", _G.DEFAULT_CHAT_FRAME.messages[1], "manual scans should announce chat-visible start status")
assert.truthy(_G.DEFAULT_CHAT_FRAME.messages[2] == nil, "scanner should not spam per-tab progress into chat")

_G.time = originalTime
_G.DEFAULT_CHAT_FRAME.messages = originalMessages

local timedOutTabs = {}
scanner.scanInProgress = true
scanner.totalTabs = 1
scanner.completedTabs = 0
scanner.tabsToScan = {}
scanner.rawTabs = {}
scanner.waitingForTab = 1
scanner.waitToken = 4
_G.DEFAULT_CHAT_FRAME.messages = {}
scanner.ReadCurrentTab = function(tabIndex)
    table.insert(timedOutTabs, tabIndex)
end
scanner.OnGuildBankSlotsChanged(2)
assert.equal(0, #timedOutTabs, "scanner should ignore guild bank slot events for tabs other than the one it is waiting on")

scanner.waitingForTab = nil
scanner.pendingAutoScan = true
local retryCalls = 0
scanner.RetryPendingAutoScan = function()
    retryCalls = retryCalls + 1
    return true
end
scanner.OnGuildBankSlotsChanged()
assert.equal(1, retryCalls, "guild bank slot updates should wake a pending auto-scan retry when the bank data arrives")
scanner.OnGuildBankTabsUpdated()
assert.equal(2, retryCalls, "guild bank tab updates should also wake a pending auto-scan retry when tab data arrives")

scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.totalTabs = 1
scanner.completedTabs = 0
scanner.tabsToScan = {}
scanner.rawTabs = {}
scanner.waitingForTab = nil
scanner.waitToken = 0
_G.DEFAULT_CHAT_FRAME.messages = {}
_G.C_Timer.ClearPending()
queriedTabs = {}
scanner.BeginScan()
_G.C_Timer.RunPending()
assert.equal(1, #timedOutTabs, "scanner timeout fallback should read the waited tab when no guild bank slot event arrives")
assert.equal(3, queriedTabs[2], "scanner timeout fallback should continue requesting queued tabs after a missed event")
assert.equal("GBankManager: Guild bank scan timed out waiting for tab 1. Capturing current tab contents.", _G.DEFAULT_CHAT_FRAME.messages[2], "timeout fallback should report a chat-visible recovery message")

local snapshotDb = ns.modules.store.CreateFreshDatabase("My Guild")
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        slots = {
            { itemID = 1001, name = "Flask Alpha", count = 2 },
        },
    },
}
snapshotDb.snapshots = {}
snapshotDb.changeLog = {}
snapshotDb.currentSnapshotId = nil
snapshotDb.meta.lastScanSequence = 0
ns.state.db = snapshotDb
_G.GBankManagerDB = snapshotDb
_G.time = function()
    return 2000
end
local firstSnapshot = scanner.FinishScan("OfficerOne", "My Guild")
scanner.rawTabs = {
    {
        index = 1,
        name = "Flasks",
        slots = {
            { itemID = 1001, name = "Flask Alpha", count = 3 },
        },
    },
}
local secondSnapshot = scanner.FinishScan("OfficerOne", "My Guild")
assert.truthy(firstSnapshot.scanId ~= secondSnapshot.scanId, "scanner should produce unique scan ids even when scans land in the same second")

scanner.ReadCurrentTab = originalReadCurrentTab
scanner.RetryPendingAutoScan = originalRetryPendingAutoScan
_G.DEFAULT_CHAT_FRAME.messages = originalMessages
_G.C_Timer.ClearPending()
_G.time = originalTime
