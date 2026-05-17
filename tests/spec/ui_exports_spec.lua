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
assert.equal("Stocked Elsewhere", mainFrame.tableHeaderLabels[6]:GetText(), "exports table should show stocked-elsewhere status")
assert.equal("Yes", mainFrame.tableRowsData[1].stockedElsewhere, "exports rows should flag items stocked in another tab")
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
mainFrame.exportModalMissingOnlyButton:GetScript("OnClick")(mainFrame.exportModalMissingOnlyButton)
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Potion Beta", 1, true) ~= nil, "auctionator missing-only output should include unavailable rows")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Flask Alpha", 1, true) == nil, "auctionator missing-only output should exclude rows stocked elsewhere")

mainFrame.exportPresetSpreadsheetButton:GetScript("OnClick")(mainFrame.exportPresetSpreadsheetButton)
assert.truthy(mainFrame.exportModalOutputInput:IsShown(), "csv export should show the output box immediately")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Item ID,Item Tier,Item Name,Bank Tab,Amount to Stock,Stocked Elsewhere", 1, true) ~= nil, "csv export should include the visible table header row")

mainFrame.exportPresetTsmButton:GetScript("OnClick")(mainFrame.exportPresetTsmButton)
assert.truthy(mainFrame.exportModalBuyAllButton:IsShown(), "tsm export should use the same all-or-missing choice modal")
mainFrame.exportModalBuyAllButton:GetScript("OnClick")(mainFrame.exportModalBuyAllButton)
assert.equal("1001,2002", mainFrame.exportModalOutputInput:GetText(), "tsm export should build a comma-delimited item id import string")
assert.truthy(type(mainFrame.exportModalScrollFrame) == "table", "export modal should expose a scroll frame for long output")
assert.equal(mainFrame.exportModalScrollChild, mainFrame.exportModalScrollFrame.scrollChild, "export modal should attach its content frame as the scroll child")
assert.truthy(mainFrame.exportModalScrollFrame.mouseWheelEnabled == true, "export modal should enable mouse-wheel scrolling")
assert.truthy(type(mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")) == "function", "export modal should wire a mouse-wheel scrolling handler")
