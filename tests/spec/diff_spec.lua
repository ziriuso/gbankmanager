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
assert.equal(10, snapshot.items[1001].totalCount, "snapshot should aggregate duplicate item stacks")
assert.equal("QUANTITY_INCREASED", changes[1].type, "diff should report quantity increase")
assert.equal(7, changes[1].delta, "diff should capture quantity delta")

_G.GetNumGuildBankTabs = function()
    return 3
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
scanner.QueueAccessibleTabs()

assert.equal(2, #scanner.tabsToScan, "scanner should queue only accessible tabs")
assert.equal(1, scanner.tabsToScan[1], "scanner should queue the first accessible tab")
assert.equal(3, scanner.tabsToScan[2], "scanner should queue later accessible tabs")

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

local tabData = scanner.ReadCurrentTab(1)

assert.equal("Flasks", tabData.name, "scanner should label scanned tabs from guild bank metadata")
assert.equal(2, #tabData.slots, "scanner should collect populated slots only")
assert.equal(1001, tabData.slots[1].itemID, "scanner should parse item ids from links")
assert.equal(1, #scanner.rawTabs, "scanner should append scanned tabs to the raw scan state")
