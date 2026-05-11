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
