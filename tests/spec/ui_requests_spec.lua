local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB.requests = {
    {
        requestId = "req-1",
        requester = "OfficerOne-Stormrage",
        itemName = "Raid Flask",
        quantity = 5,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "Raid night",
        createdAt = 100,
    },
}

mainFrame:SelectView("REQUESTS")
assert.equal("REQUESTS", mainFrame.activeView, "requests tab should be selectable")
assert.truthy(mainFrame.requestCreatePanel:IsShown(), "request create controls should show in the requests view")
assert.truthy(mainFrame.requestActionsPanel:IsShown(), "officer request actions should show in the full requests view")
assert.same(mainFrame.requestCreatePanel, (mainFrame.tableHeaderFrame.points[1] or {})[2], "requests view should anchor the shared table directly beneath the create panel")
assert.truthy(mainFrame.tableViewportFrame:IsShown(), "requests view should show the shared table viewport")

mainFrame:ShowRequestOnly()
assert.equal("REQUESTS", mainFrame.activeView, "request-only mode should stay on the requests view")
assert.truthy(mainFrame.requestOnlyMode == true, "request-only mode should be tracked on the shell")
assert.truthy(mainFrame.requestCreatePanel:IsShown(), "request-only mode should still show the request entry panel")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request-only mode should hide officer action controls")
assert.truthy(not mainFrame.sidebar:IsShown(), "request-only mode should hide the sidebar")
assert.same(mainFrame.viewSubtitle, (mainFrame.requestCreatePanel.points[1] or {})[2], "request-only mode should place request entry directly below the request subtitle")
