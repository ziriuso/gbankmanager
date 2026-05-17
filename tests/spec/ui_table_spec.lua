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
assert.same(mainFrame.tableViewportFrame, (mainFrame.tableScrollBar.points[1] or {})[2], "shared table scrollbar should anchor to the viewport")
assert.equal(-4, (mainFrame.tableScrollBar.points[1] or {})[4], "shared table scrollbar should stay inside the viewport right edge")
assert.equal(-4, (mainFrame.tableScrollBar.points[2] or {})[4], "shared table scrollbar bottom anchor should stay inside the viewport right edge")
assert.equal(24, mainFrame.tableScrollbarGutterWidth, "shared table layout should reserve a gutter for the inset scrollbar")
assert.equal(mainFrame.tableViewportWidth - mainFrame.tableScrollbarGutterWidth, mainFrame.tableViewportInnerWidth, "shared table content width should leave room for the scrollbar gutter")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableHeaderFrame:GetWidth(), "shared table header should stop before the scrollbar gutter")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableFilterFrame:GetWidth(), "shared table filters should stop before the scrollbar gutter")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableRows[1]:GetWidth(), "shared table rows should stop before the scrollbar gutter")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "inventory should use the minimums table layout starting with Item ID")
assert.equal("Tier", mainFrame.tableHeaderLabels[2]:GetText(), "inventory should use the minimums table layout tier column")
assert.equal("Item", mainFrame.tableHeaderLabels[3]:GetText(), "inventory should use the minimums table layout item column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "inventory should use the minimums table layout bank tab column")
assert.equal("Current", mainFrame.tableHeaderLabels[5]:GetText(), "inventory should use the minimums table layout current column")
assert.equal("Restock", mainFrame.tableHeaderLabels[6]:GetText(), "inventory should use the minimums table layout restock column")
assert.equal("Minimum", mainFrame.tableHeaderLabels[7]:GetText(), "inventory should use the minimums table layout minimum column")
assert.truthy((mainFrame.tableColumnLayout[3].width or 0) >= 300, "inventory item column should absorb the right-side whitespace for item names")
mainFrame.tableFilterInputs[1]:SetText("1015")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal(1, #mainFrame.tableRowsData, "inventory shared table filters should search by Item ID")
assert.equal("1015", mainFrame.tableRowsData[1].itemID, "inventory Item ID filter should keep the matching item row")
mainFrame.tableFilterInputs[1]:SetText("")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
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
