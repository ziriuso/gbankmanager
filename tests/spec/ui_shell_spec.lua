local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame
local slash = env.slash
local scanner = env.scanner

assert.truthy(type(mainFrame.closeButton) == "table", "main frame should expose a close button")
assert.truthy(type(mainFrame.collapseButton) == "table", "main frame should expose a collapse control")
assert.truthy(type(mainFrame.scanButton) == "table", "main frame should expose a scan button")
assert.truthy(type(mainFrame.sidebarButtons[1]:GetScript("OnClick")) == "function", "sidebar buttons should switch views when clicked")
assert.equal(920, mainFrame.resizeBounds.minWidth, "main frame should keep the shell resize minimum width")
assert.equal(560, mainFrame.resizeBounds.minHeight, "main frame should keep the shell resize minimum height")

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "slash ui command should show the main frame")
assert.truthy(mainFrame.mouseEnabled == true, "opening the main frame should enable mouse capture")

mainFrame.collapseButton:GetScript("OnClick")(mainFrame.collapseButton)
assert.truthy(mainFrame.collapsedSidebar == true, "toggle should collapse the sidebar")
assert.equal(40, mainFrame.sidebarButtons[1]:GetWidth(), "collapsed sidebar should shrink nav button width")
assert.equal("", mainFrame.sidebarButtons[1].labelText:GetText(), "collapsed sidebar should hide nav labels instead of stacking characters")

scanner.scanInProgress = false
mainFrame.scanButton:GetScript("OnClick")(mainFrame.scanButton)
assert.truthy(type(mainFrame.scanButton:GetScript("OnClick")) == "function", "scan button should stay wired to the scanner entrypoint")
