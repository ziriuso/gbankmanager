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
assert.truthy(type(mainFrame.sidebarButtons[1].navIcon) == "table", "sidebar buttons should expose nav icons for collapsed navigation")
assert.truthy(mainFrame.sidebarButtons[1].navIcon.texture ~= nil, "sidebar buttons should assign a nav icon texture")
assert.truthy((mainFrame.sidebarButtons[1].backdropBorderColor or {})[1] == 0.85, "active sidebar view should use a stronger border glow")
assert.same(mainFrame.closeButton, (mainFrame.scanButton.points[1] or {})[2], "scan button should anchor from the close button side to avoid scaled-header overlap")
assert.same(mainFrame.scanButton, (mainFrame.statusText.points[1] or {})[2], "status text should anchor from the scan button side to avoid scaled-header overlap")
assert.equal(920, mainFrame.resizeBounds.minWidth, "main frame should keep the shell resize minimum width")
assert.equal(560, mainFrame.resizeBounds.minHeight, "main frame should keep the shell resize minimum height")

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "slash ui command should show the main frame")
assert.truthy(mainFrame.mouseEnabled == true, "opening the main frame should enable mouse capture")
assert.truthy(mainFrame.topLevel == true, "main frame should opt into top-level window ordering")
assert.equal("MEDIUM", mainFrame.frameStrata, "main frame should sit below higher-priority Blizzard dialogs until refocused")

local originalFrameLevel = tonumber(mainFrame.frameLevel or 0) or 0
local onMouseDown = mainFrame:GetScript("OnMouseDown")
assert.truthy(type(onMouseDown) == "function", "main frame should expose a mouse-down front-focus handler")
onMouseDown(mainFrame)
assert.truthy((tonumber(mainFrame.frameLevel or 0) or 0) > originalFrameLevel, "clicking the shell should raise it in the local frame stack")

mainFrame.collapseButton:GetScript("OnClick")(mainFrame.collapseButton)
assert.truthy(mainFrame.collapsedSidebar == true, "toggle should collapse the sidebar")
assert.equal(40, mainFrame.sidebarButtons[1]:GetWidth(), "collapsed sidebar should shrink nav button width")
assert.equal("", mainFrame.sidebarButtons[1].labelText:GetText(), "collapsed sidebar should hide nav labels instead of stacking characters")
assert.truthy(mainFrame.sidebarButtons[1].navIcon.texture ~= nil, "collapsed sidebar should keep the nav icon visible")

local modal = mainFrame:OpenMinimumAddModal()
assert.truthy(type(modal) == "table", "minimum add modal should still open from the shared shell")
local raisedShellLevel = tonumber(mainFrame.frameLevel or 0) or 0
assert.equal(raisedShellLevel + 20, modal.frameLevel, "opened modals should layer above the current shell level")
onMouseDown(mainFrame)
assert.equal((tonumber(mainFrame.frameLevel or 0) or 0) + 20, modal.frameLevel, "raising the shell should keep registered modals above it")

scanner.scanInProgress = false
mainFrame.scanButton:GetScript("OnClick")(mainFrame.scanButton)
assert.truthy(type(mainFrame.scanButton:GetScript("OnClick")) == "function", "scan button should stay wired to the scanner entrypoint")
