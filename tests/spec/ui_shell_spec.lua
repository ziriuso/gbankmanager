local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

dofile("tests/helpers/wow_stubs.lua")

local env = fixture.load()
local mainFrame = env.mainFrame
local slash = env.slash
local scanner = env.scanner
local themeManager = env.ns.modules.themeManager
local syncEvents = env.ns.modules.syncEvents
local activeTheme = env.mainFrameShell.GetTheme()

assert.truthy(type(mainFrame.closeButton) == "table", "main frame should expose a close button")
assert.truthy(type(mainFrame.collapseButton) == "table", "main frame should expose a collapse control")
assert.truthy(type(mainFrame.scanButton) == "table", "main frame should expose a scan button")
assert.truthy(type(themeManager) == "table", "ui shell should register a shared theme manager")
assert.equal("generic_wow", (_G.GBankManagerDB.ui.appearance or {}).themePreset, "ui shell should migrate the default saved preset to Generic WoW")
assert.equal("generic_wow", mainFrame.appearanceThemePreset, "ui shell should load the migrated Generic WoW preset into the shell state")
assert.equal("Generic WoW", ((themeManager.GetTheme("generic_wow") or {}).label or ""), "theme manager should expose the Generic WoW preset")
assert.equal("High Contrast", ((themeManager.GetTheme("high_contrast") or {}).label or ""), "theme manager should expose the High Contrast preset")
assert.equal("Nature", ((themeManager.GetTheme("nature") or {}).label or ""), "theme manager should expose the Nature preset")
assert.equal("generic_wow", themeManager.NormalizePresetKey("default"), "theme manager should migrate the old default preset key")
assert.equal("high_contrast", themeManager.NormalizePresetKey("contrast"), "theme manager should migrate the old contrast preset key")
assert.equal("nature", themeManager.NormalizePresetKey("moonglade"), "theme manager should migrate the old moonglade preset key")
assert.truthy(type(mainFrame.sidebarButtons[1]:GetScript("OnClick")) == "function", "sidebar buttons should switch views when clicked")
assert.truthy(type(mainFrame.sidebarButtons[1].navIcon) == "table", "sidebar buttons should expose nav icons for collapsed navigation")
assert.truthy(mainFrame.sidebarButtons[1].navIcon.texture ~= nil, "sidebar buttons should assign a nav icon texture")
assert.equal("shell", mainFrame.gbmSurfaceVariant, "main frame should use the shell surface variant")
assert.equal("sidebar", (mainFrame.sidebar or {}).gbmSurfaceVariant, "sidebar should use the dedicated sidebar surface variant")
assert.equal("header", (mainFrame.topBar or {}).gbmSurfaceVariant, "top bar should use the dedicated header surface variant")
assert.equal("nav", (mainFrame.sidebarButtons[1] or {}).gbmButtonVariant, "sidebar buttons should use the dedicated nav button variant")
assert.equal("metric-card", ((mainFrame.dashboardCards or {})[1] or {}).gbmSurfaceVariant, "dashboard cards should use the metric-card surface variant")
assert.equal("panel", (mainFrame.dashboardTopItemsPanel or {}).gbmSurfaceVariant, "dashboard support panels should use the main panel surface variant")
assert.equal("action-card", ((mainFrame.exportActionCards or {})[1] or {}).gbmSurfaceVariant, "export cards should use the action-card surface variant")
assert.truthy(type((mainFrame.gbmArt or {}).background) == "table", "main shell should expose a reusable art background texture")
assert.truthy(type(((mainFrame.sidebarButtons or {})[1] or {}).gbmArt) == "table", "nav buttons should expose reusable art layers")
assert.truthy(type((((mainFrame.sidebarButtons or {})[1] or {}).gbmArt or {}).accentBar) == "table", "nav buttons should expose an accent-bar art layer")
assert.truthy(type((((mainFrame.dashboardCards or {})[1] or {}).gbmArt or {}).headerBand) == "table", "dashboard cards should expose a shared header-band art layer")
assert.truthy(type(mainFrame.sidebarIdentityPanel) == "table", "sidebar should expose a footer identity card")
assert.truthy(type(mainFrame.sidebarIdentityNameText) == "table", "sidebar identity card should expose player identity text")
assert.truthy(type(mainFrame.sidebarIdentityGuildText) == "table", "sidebar identity card should expose guild identity text")
assert.truthy(type(mainFrame.RefreshSidebarIdentity) == "function", "sidebar identity card should expose a refresh helper for late guild data")
assert.equal((activeTheme.colors.accentStrong or {})[1], (mainFrame.sidebarButtons[1].backdropBorderColor or {})[1], "active sidebar view should use the theme's stronger border glow")
assert.same(mainFrame.closeButton, (mainFrame.scanButton.points[1] or {})[2], "scan button should anchor from the close button side to avoid scaled-header overlap")
assert.same(mainFrame.scanButton, (mainFrame.statusText.points[1] or {})[2], "status text should anchor from the scan button side to avoid scaled-header overlap")
assert.equal(920, mainFrame.resizeBounds.minWidth, "main frame should keep the shell resize minimum width")
assert.equal(560, mainFrame.resizeBounds.minHeight, "main frame should keep the shell resize minimum height")

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "slash ui command should show the main frame")
assert.truthy(mainFrame.mouseEnabled == true, "opening the main frame should enable mouse capture")
assert.truthy(mainFrame.topLevel == true, "main frame should opt into top-level window ordering")
assert.equal("MEDIUM", mainFrame.frameStrata, "main frame should sit below higher-priority Blizzard dialogs until refocused")

local originalGetGuildInfo = _G.GetGuildInfo
_G.GetGuildInfo = function()
    return nil, "Officer", 1
end
mainFrame:RefreshSidebarIdentity()
assert.equal("No Guild", mainFrame.sidebarIdentityGuildText:GetText(), "sidebar identity refresh should tolerate missing guild info during early load")
_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end
syncEvents.HandleEvent("PLAYER_GUILD_UPDATE")
assert.equal("Guild Testers", mainFrame.sidebarIdentityGuildText:GetText(), "sidebar identity should refresh when guild identity becomes available after load")
_G.GetGuildInfo = originalGetGuildInfo

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
assert.truthy(not mainFrame.sidebarIdentityNameText:IsShown(), "collapsed sidebar should hide the footer identity text")

local modal = mainFrame:OpenMinimumAddModal()
assert.truthy(type(modal) == "table", "minimum add modal should still open from the shared shell")
local raisedShellLevel = tonumber(mainFrame.frameLevel or 0) or 0
assert.equal(raisedShellLevel + 20, modal.frameLevel, "opened modals should layer above the current shell level")
onMouseDown(mainFrame)
assert.equal((tonumber(mainFrame.frameLevel or 0) or 0) + 20, modal.frameLevel, "raising the shell should keep registered modals above it")

scanner.scanInProgress = false
mainFrame.scanButton:GetScript("OnClick")(mainFrame.scanButton)
assert.truthy(type(mainFrame.scanButton:GetScript("OnClick")) == "function", "scan button should stay wired to the scanner entrypoint")
