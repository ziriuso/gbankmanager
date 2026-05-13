local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

assert.truthy(type(mainFrame) == "table", "main frame should load from the toc")
assert.truthy(type(env.mainFrameShell) == "table", "main frame shell should load from the toc")
assert.truthy(type(env.mainFrameShell.EnsureShell) == "function", "main frame shell should expose a shell builder")
assert.same(mainFrame, env.mainFrameShell.EnsureShell(mainFrame), "main frame shell should idempotently configure the shared main frame")
assert.truthy(type(env.mainTableController) == "table", "main table controller should load from the toc")
assert.truthy(type(env.mainRequestsController) == "table", "main requests controller should load from the toc")
assert.truthy(type(env.mainExportsController) == "table", "main exports controller should load from the toc")
assert.truthy(type(env.mainMinimumsController) == "table", "main minimums controller should load from the toc")
assert.truthy(type(env.dashboard) == "table", "dashboard view should load from the toc")
assert.truthy(type(env.inventory) == "table", "inventory view should load from the toc")
assert.truthy(type(env.history) == "table", "history view should load from the toc")
assert.truthy(type(env.exportsView) == "table", "exports view should load from the toc")
assert.truthy(type(env.minimumsView) == "table", "minimums view should load from the toc")
assert.truthy(type(env.requestsView) == "table", "requests view should load from the toc")
assert.truthy(type(env.requestDialog) == "table", "request dialog should load from the toc")

assert.equal("DASHBOARD", mainFrame.activeView, "main frame should default to dashboard")
assert.truthy(mainFrame.collapsedSidebar == false, "sidebar should start expanded")
assert.truthy(not mainFrame:IsShown(), "main frame should start hidden")
assert.truthy(mainFrame.mouseEnabled == false, "main frame should not capture mouse before opening")

local navKeys = {}
for _, item in ipairs(mainFrame.navItems or {}) do
    navKeys[item.key] = true
end

assert.truthy(navKeys.HISTORY and navKeys.ABOUT, "history and about should remain in navigation")
assert.truthy(not navKeys.TARGETS, "targets should no longer appear in shell navigation")
assert.truthy(mainFrame.viewDescriptions.TARGETS == nil, "targets should no longer appear in shell view descriptions")
