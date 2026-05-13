local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "minimums-ui",
    snapshots = {
        ["minimums-ui"] = {
            items = {
                [7007] = {
                    itemID = 7007,
                    name = "Algari Mana Oil",
                    totalCount = 4,
                    tabs = {
                        Alchemy = 4,
                    },
                },
            },
        },
    },
    minimums = {},
    requests = {},
    auditLog = {},
    ui = {
        minimumSettings = {
            defaultQuantity = 250,
        },
    },
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("MINIMUMS")
assert.truthy(mainFrame.minimumsPanel:IsShown(), "minimums editor panel should show in the minimums view")
assert.truthy(mainFrame.tableViewportFrame:IsShown(), "minimums view should show the shared table viewport")
assert.equal("Save All", mainFrame.minimumSaveButton.labelText:GetText(), "minimums view should keep the top-level save action label")

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
assert.truthy(mainFrame.minimumAddModal:IsShown(), "add should open the minimum modal")
assert.equal("250", mainFrame.minimumAddQuantityInput:GetText(), "new minimum rows should start from the configured default minimum value")
assert.equal("Item ID", mainFrame.minimumAddItemIDLabel:GetText(), "minimum add modal should label the item-id field clearly")
assert.equal("Item Name", mainFrame.minimumAddItemNameLabel:GetText(), "minimum add modal should label the item-name field clearly")
assert.equal("Minimum", mainFrame.minimumAddQuantityLabel:GetText(), "minimum add modal should label the quantity field clearly")
assert.equal("Matches", mainFrame.minimumAddResultsLabel:GetText(), "minimum add modal should label the results list clearly")
