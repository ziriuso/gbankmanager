local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

dofile("tests/helpers/wow_stubs.lua")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "inventory-export",
    snapshots = {
        ["inventory-export"] = {
            items = {
                [241324] = {
                    itemID = 241324,
                    name = "Flask of the Blood Knights",
                    totalCount = 3,
                    craftedQuality = 2,
                    craftedQualityIcon = "Professions-ChatIcon-Quality-12-Tier1",
                    craftedQualityMax = 2,
                    tabs = {
                        ["Raid Buffet"] = 3,
                    },
                },
            },
        },
    },
    minimums = {
        { itemID = 241324, itemName = "Flask of the Blood Knights", quantity = 100, scope = "TAB", tabName = "Raid Buffet", enabled = true, craftedQuality = 2, craftedQualityIcon = "Professions-ChatIcon-Quality-12-Tier1" },
    },
    requests = {},
    auditLog = {},
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("INVENTORY")

assert.equal("INVENTORY", mainFrame.activeView, "inventory should be the active view")
assert.truthy(type(mainFrame.inventoryPanel) == "table" and mainFrame.inventoryPanel:IsShown(), "inventory should expose a footer panel for csv export")
assert.equal("Export CSV", mainFrame.inventoryExportButton.labelText:GetText(), "inventory should expose a csv export button")
assert.same(mainFrame.tableViewportFrame, (mainFrame.inventoryPanel.points[1] or {})[2], "inventory export controls should sit below the shared table viewport")
assert.equal(nil, mainFrame.inventoryPanel.backdrop, "inventory export footer should avoid a ghost container box")

mainFrame.inventoryExportButton:GetScript("OnClick")(mainFrame.inventoryExportButton)

assert.truthy(mainFrame.exportModal:IsShown(), "inventory csv export should open the shared export modal")
assert.equal("Inventory CSV", mainFrame.exportModalTitle:GetText(), "inventory export should label the shared modal clearly")
assert.equal("Select all and copy the filtered inventory export.", mainFrame.exportModalHint:GetText(), "inventory export should explain the modal action")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Item ID,Tier,Item,Bank Tab,Current,Restock,Minimum", 1, true) ~= nil, "inventory csv export should include the visible inventory header row")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "241324,1,Flask of the Blood Knights,Raid Buffet,3,Yes,100", 1, true) ~= nil, "inventory csv export should include the filtered inventory rows")
