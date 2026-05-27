package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

mainFrame:SelectView("ABOUT")

assert.equal("ABOUT", mainFrame.activeView, "about should be the active view")
assert.truthy(type(mainFrame.aboutPanel) == "table", "about should expose a dedicated branded panel")
assert.truthy(mainFrame.aboutPanel:IsShown(), "about should show the branded panel")
assert.equal("panel-alt", mainFrame.aboutPanel.gbmSurfaceVariant, "about should use the elevated branded panel surface")
assert.truthy(type((mainFrame.aboutPanel.gbmArt or {}).headerBand) == "table", "about should use the shared art-band treatment")
assert.truthy(type(mainFrame.aboutCrestTexture) == "table", "about should expose a crest texture")
assert.truthy((mainFrame.aboutCrestTexture.texture or "") ~= "", "about should assign a crest texture")
assert.equal("Guild Bank Manager", mainFrame.aboutNameText:GetText(), "about should show the addon name")
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "Version", 1, true) ~= nil, "about should show a version line")
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "v0.9.0-beta.2", 1, true) ~= nil, "about should show the latest tagged release identifier")
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "(", 1, true) == nil, "about should drop the runtime build stamp from the visible version line")
assert.equal("Guild: Guild Testers", mainFrame.aboutAuthorText:GetText(), "about should replace the ownership line with the guild only")
assert.equal("", mainFrame.aboutGuildText:GetText() or "", "about should remove the extra character and realm identity line")
assert.equal("", mainFrame.aboutDescriptionText:GetText() or "", "about should remove the support note description text")
assert.equal("/gbm help", mainFrame.aboutSlashHintText:GetText(), "about should trim the slash hint copy")
assert.equal("", mainFrame.viewSubtitle:GetText() or "", "about should remove the old descriptive subtitle text")
assert.truthy(not mainFrame.contentBodyText:IsShown(), "about should no longer fall back to the generic body text block")
