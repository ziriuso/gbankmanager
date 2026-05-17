package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "exports-modal",
    snapshots = {
        ["exports-modal"] = {
            items = {
                [1001] = {
                    itemID = 1001,
                    name = "Flask Alpha",
                    totalCount = 12,
                    craftedQuality = 3,
                    tabs = {
                        ["Raid Buffer"] = 2,
                        ["Freebiez"] = 10,
                    },
                },
                [2002] = {
                    itemID = 2002,
                    name = "Potion Beta",
                    totalCount = 0,
                    tabs = {},
                },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 5, scope = "TAB", tabName = "Raid Buffer", enabled = true },
        { itemID = 2002, itemName = "Potion Beta", quantity = 3, scope = "TAB", tabName = "Raid Buffer", enabled = true },
    },
    requests = {},
    auditLog = {},
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
assert.truthy(mainFrame.exportsPanel:IsShown(), "exports should expose a bottom action strip")
assert.same(mainFrame.tableViewportFrame, (mainFrame.exportsPanel.points[1] or {})[2], "exports buttons should sit below the table viewport")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "exports table should start with Item ID")
assert.equal("Item Tier", mainFrame.tableHeaderLabels[2]:GetText(), "exports table should show Item Tier")
assert.equal("Item Name", mainFrame.tableHeaderLabels[3]:GetText(), "exports table should show Item Name")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "exports table should show Bank Tab")
assert.equal("Amount to Stock", mainFrame.tableHeaderLabels[5]:GetText(), "exports table should show Amount to Stock")
assert.equal("Excess Stock In", mainFrame.tableHeaderLabels[6]:GetText(), "exports table should show the highest-quantity excess-stock tab")
assert.equal("Freebiez", mainFrame.tableRowsData[1].excessStockIn, "exports rows should name the other guild-bank tab with excess stock")
assert.truthy(not mainFrame.exportPresetCustomButton:IsShown(), "exports should remove the custom option")
assert.truthy(mainFrame.exportPresetTsmButton:IsShown(), "exports should expose a TSM item-id import option when supported")
mainFrame:OpenExportStockedElsewhereModal(mainFrame.tableRowsData[1])
assert.truthy(mainFrame.exportStockedElsewhereModal:IsShown(), "clicking stocked elsewhere should open the tab quantity modal")
assert.truthy(string.find(mainFrame.exportStockedElsewhereText:GetText() or "", "Freebiez: 10", 1, true) ~= nil, "stocked elsewhere modal should list other tabs and quantities")
mainFrame.exportStockedElsewhereCloseButton:GetScript("OnClick")(mainFrame.exportStockedElsewhereCloseButton)

mainFrame.exportPresetAuctionatorButton:GetScript("OnClick")(mainFrame.exportPresetAuctionatorButton)
assert.truthy(mainFrame.exportModal:IsShown(), "auctionator export should open a modal")
assert.truthy(mainFrame.exportModalBuyAllButton:IsShown(), "auctionator export should ask whether to buy all")
assert.truthy(mainFrame.exportModalMissingOnlyButton:IsShown(), "auctionator export should offer skipping items available in another tab")
assert.equal("Not In Guild Bank", mainFrame.exportModalMissingOnlyButton.labelText:GetText(), "auctionator export should label the missing-only path the same way as the exports table")
mainFrame.exportModalMissingOnlyButton:GetScript("OnClick")(mainFrame.exportModalMissingOnlyButton)
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Potion Beta", 1, true) ~= nil, "auctionator missing-only output should include unavailable rows")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Flask Alpha", 1, true) == nil, "auctionator missing-only output should exclude rows stocked elsewhere")

mainFrame.exportPresetSpreadsheetButton:GetScript("OnClick")(mainFrame.exportPresetSpreadsheetButton)
assert.truthy(mainFrame.exportModalOutputInput:IsShown(), "csv export should show the output box immediately")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Item ID,Item Tier,Item Name,Bank Tab,Amount to Stock,Excess Stock In", 1, true) ~= nil, "csv export should include the visible table header row")
assert.truthy(type(mainFrame.exportModalOutputInput.EditBox) == "table", "export modal should use a real scrollable edit box for manual selection")
assert.truthy(type(mainFrame.exportModalOutputInput.EditBox:GetScript("OnTextChanged")) == "function", "export modal should bind text-change sizing on the embedded edit box")
assert.equal(nil, mainFrame.exportModalScrollFrame.backdrop, "export modal should remove the nested scroll-frame box around the output")
assert.equal(nil, mainFrame.exportModalOutputInput.backdrop, "export modal should remove the nested output-input box around the export text")
assert.truthy(not mainFrame.exportModalCopyButton:IsShown(), "export modal should remove the copy button because manual Ctrl+C is the supported path")
mainFrame.exportModalSelectAllButton:GetScript("OnClick")(mainFrame.exportModalSelectAllButton)
assert.truthy(mainFrame.exportModalOutputInput:HasFocus(), "select all should focus the scrollable edit box")
assert.equal(0, mainFrame.exportModalOutputInput.cursorPosition, "select all should rewind the cursor before highlighting")
assert.equal(0, mainFrame.exportModalOutputInput.highlightStart, "select all should highlight the full export output")
assert.equal(-1, mainFrame.exportModalOutputInput.highlightEnd, "select all should extend the highlight through the entire export output")
assert.equal("Selected all output. Press Ctrl+C to copy.", mainFrame.exportModalStatusText:GetText(), "select all should give the user visible copy guidance")

mainFrame.exportPresetTsmButton:GetScript("OnClick")(mainFrame.exportPresetTsmButton)
assert.truthy(mainFrame.exportModalBuyAllButton:IsShown(), "tsm export should use the same all-or-missing choice modal")
mainFrame.exportModalBuyAllButton:GetScript("OnClick")(mainFrame.exportModalBuyAllButton)
assert.equal("1001,2002", mainFrame.exportModalOutputInput:GetText(), "tsm export should build a comma-delimited item id import string")
assert.truthy(type(mainFrame.exportModalScrollFrame) == "table", "export modal should expose a scroll frame for long output")
assert.equal(mainFrame.exportModalOutputInput.EditBox, mainFrame.exportModalScrollFrame.scrollChild, "export modal should attach its edit box as the scroll child")
assert.equal(mainFrame.exportModalOutputInput.EditBox, mainFrame.exportModalScrollChild, "export modal should expose the edit box as the scroll child reference")
assert.truthy(mainFrame.exportModalScrollFrame.mouseWheelEnabled == true, "export modal should enable mouse-wheel scrolling")
assert.truthy(type(mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")) == "function", "export modal should wire a mouse-wheel scrolling handler")
assert.truthy(mainFrame.exportManualShoppingListButton ~= nil, "exports should expose the manual shopping-list helper button")
mainFrame.exportManualShoppingListButton:GetScript("OnClick")(mainFrame.exportManualShoppingListButton)
assert.truthy(mainFrame.exportManualShoppingListModal:IsShown(), "manual shopping list should open in a separate modal")
assert.truthy(mainFrame.exportManualShoppingListModal.mouseEnabled == true, "manual shopping list modal should be draggable")
assert.equal("LeftButton", (mainFrame.exportManualShoppingListModal.dragButtons or {})[1], "manual shopping list modal should register left-button dragging")
assert.equal("Check off purchases as you work through the list. Does not sync back to addon.", mainFrame.exportManualShoppingListHint:GetText(), "manual shopping list should explain that it is a one-session helper only")
assert.truthy(#(mainFrame.exportManualShoppingListRows or {}) >= 2, "manual shopping list should build one checklist row per purchase row")
local manualShoppingRow = (mainFrame.exportManualShoppingListRows or {})[1]
assert.equal("", manualShoppingRow.checkButton.labelText:GetText(), "unchecked manual shopping rows should use an empty checkbox instead of bracket text")
manualShoppingRow.checkButton:GetScript("OnClick")(manualShoppingRow.checkButton)
assert.equal("x", manualShoppingRow.checkButton.labelText:GetText(), "checked manual shopping rows should use a simple x inside the checkbox")
assert.truthy(manualShoppingRow.strikeLine:IsShown(), "checking a manual shopping list row should strike it through for the current session")
