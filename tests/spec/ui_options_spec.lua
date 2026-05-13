local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB.auth.updatedAt = 0
_G.GBankManagerDB.auth.updatedBy = "Stormrage-OfficerOne"
mainFrame:SelectView("OPTIONS")

assert.equal("OPTIONS", mainFrame.activeView, "options tab should be selectable")
assert.truthy(mainFrame.optionsPanel:IsShown(), "options panel should show in the options view")
assert.truthy(mainFrame.optionsAuthPanel:IsShown(), "options view should include the auth management panel")
assert.truthy(mainFrame.optionsViewportFrame:IsShown(), "options view should show its dedicated viewport frame")
assert.equal(mainFrame.optionsViewportFrame, mainFrame.optionsScrollFrame.parent, "options scroll frame should live inside the dedicated viewport")
assert.equal(nil, mainFrame.optionsScrollFrame.template, "options view should use a plain scroll frame")
assert.equal(mainFrame.optionsScrollChild, mainFrame.optionsScrollFrame.scrollChild, "options scroll frame should attach its settings canvas as the scroll child")
assert.truthy(mainFrame.optionsScrollFrame.mouseWheelEnabled == true, "options view should enable mouse-wheel scrolling")
assert.same(mainFrame.optionsPanel, (mainFrame.optionsScrollBar.points[1] or {})[2], "options custom scrollbar should anchor directly to the options panel edge")
assert.equal(-4, (mainFrame.optionsScrollBar.points[1] or {})[4], "options custom scrollbar should sit closer to the right edge")
assert.truthy(type(mainFrame.optionsScrollBar.track.Begin) == "table", "options custom scrollbar should expose Blizzard-style split track art")
assert.equal("minimal-scrollbar-track-top", mainFrame.optionsScrollBar.track.Begin.atlas, "options custom scrollbar should use Blizzard-style track atlas art")
assert.truthy(type(mainFrame.optionsScrollBar.thumb.Begin) == "table", "options custom scrollbar should expose Blizzard-style split thumb art")
assert.equal("minimal-scrollbar-small-thumb-top", mainFrame.optionsScrollBar.thumb.Begin.atlas, "options custom scrollbar should use Blizzard-style thumb atlas art")
assert.equal(nil, mainFrame.optionsScrollUpButton, "options view should stop rendering the old scroll-up button")
assert.equal(nil, mainFrame.optionsScrollDownButton, "options view should stop rendering the old scroll-down button")
assert.equal(nil, mainFrame.optionsScrollStatusText, "options view should stop rendering the old scroll percentage label")
assert.equal("Guild Master", mainFrame.optionsAuthRankButton.labelText:GetText(), "options auth should default the selected rank picker to the guildmaster label")
assert.truthy((mainFrame.optionsAvailablePermissionPanel:GetHeight() or 0) >= 132, "options auth should give available permissions enough height to avoid clipping the last row")
assert.truthy((mainFrame.optionsAuthPanel:GetHeight() or 0) < 800, "options auth should size to its actual content instead of leaving a giant dead zone")

local alphaAfterDown
mainFrame.transparencyDecreaseButton:GetScript("OnClick")(mainFrame.transparencyDecreaseButton)
alphaAfterDown = mainFrame.currentAlpha
assert.truthy(alphaAfterDown < 0.96, "transparency down should reduce alpha")
assert.equal("Opacity 95%", mainFrame.transparencyValueText:GetText(), "opacity decrease should keep the visible percentage label in sync")
assert.equal(nil, mainFrame.transparencySlider, "options should remove the faux slider after the live-client cleanup")
mainFrame.transparencyIncreaseButton:GetScript("OnClick")(mainFrame.transparencyIncreaseButton)
assert.truthy(mainFrame.currentAlpha > alphaAfterDown, "transparency up should increase alpha")
