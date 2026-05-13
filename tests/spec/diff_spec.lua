local assert = require("tests.helpers.assert")

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
assert.equal(10, snapshot.items[1001].totalCount, "snapshot should aggregate duplicate item stacks")
assert.equal("QUANTITY_INCREASED", changes[1].type, "diff should report quantity increase")
assert.equal(7, changes[1].delta, "diff should capture quantity delta")

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
