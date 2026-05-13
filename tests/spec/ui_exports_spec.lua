local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "exports-modal",
    snapshots = {
        ["exports-modal"] = {
            items = {},
        },
    },
    minimums = {},
    requests = {},
    auditLog = {},
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
assert.truthy(type(mainFrame.exportModalScrollFrame) == "table", "export modal should expose a scroll frame for long output")
assert.equal(mainFrame.exportModalScrollChild, mainFrame.exportModalScrollFrame.scrollChild, "export modal should attach its content frame as the scroll child")
assert.truthy(mainFrame.exportModalScrollFrame.mouseWheelEnabled == true, "export modal should enable mouse-wheel scrolling")
assert.truthy(type(mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")) == "function", "export modal should wire a mouse-wheel scrolling handler")
