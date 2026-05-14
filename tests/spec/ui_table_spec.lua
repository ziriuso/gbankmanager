local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "inventory-scroll",
    snapshots = {
        ["inventory-scroll"] = {
            items = {},
        },
    },
    minimums = {},
    requests = {},
    auditLog = {},
}

for index = 1, 30 do
    _G.GBankManagerDB.snapshots["inventory-scroll"].items[1000 + index] = {
        itemID = 1000 + index,
        name = string.format("Inventory Item %02d", index),
        totalCount = index,
        tabs = {
            Consumables = index,
        },
    }
end

env.ns.state.db = _G.GBankManagerDB
mainFrame:SelectView("INVENTORY")

assert.truthy(type(mainFrame.tableViewportFrame) == "table", "inventory should expose a dedicated viewport frame for the shared table shell")
assert.truthy(type(mainFrame.tableScrollBar) == "table", "inventory should expose a visible scroll bar")
assert.truthy(type(mainFrame.tableScrollBar.thumb) == "table", "inventory scroll bar should expose a draggable thumb")
assert.equal(nil, mainFrame.tableScrollBar.scrollUpButton, "inventory should remove the old scroll-up button")
assert.equal(nil, mainFrame.tableScrollBar.scrollDownButton, "inventory should remove the old scroll-down button")
assert.equal(nil, mainFrame.tableScrollBar.valueText, "inventory should remove the old row-range text label")
assert.equal("minimal-scrollbar-track-top", mainFrame.tableScrollBar.track.Begin.atlas, "inventory should reuse the Blizzard-style track art")
assert.equal("minimal-scrollbar-small-thumb-top", mainFrame.tableScrollBar.thumb.Begin.atlas, "inventory should reuse the Blizzard-style thumb art")

mainFrame.tableScrollFrame:GetScript("OnMouseWheel")(mainFrame.tableScrollFrame, -1)
assert.truthy((mainFrame.tableScrollOffset or 0) > 0, "inventory mouse-wheel scrolling should advance the shared table offset")
assert.truthy((mainFrame.tableScrollBar.thumb.progress or 0) > 0, "inventory scroll thumb should move forward when the table scrolls")

mainFrame.tableScrollFrame.height = 0
mainFrame.tableScrollChild.height = 0
mainFrame.tableScrollFrame:GetScript("OnMouseWheel")(mainFrame.tableScrollFrame, -1)
assert.truthy(mainFrame.tableScrollBar:IsShown(), "inventory scrollbar should stay visible while scrolling even if the live client reports a transient zero height")
