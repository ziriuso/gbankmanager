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
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "v1.2.0", 1, true) ~= nil, "about should show the latest tagged release identifier")
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "(", 1, true) ~= nil, "about should restore the local build stamp on the visible version line")
assert.equal("Author: Zirleficent-Stormrage", mainFrame.aboutAuthorText:GetText(), "about should restore the author line")
assert.equal("Guild: Guild Testers", mainFrame.aboutGuildText:GetText() or "", "about should keep the guild on its own line")
local guildPoint = (mainFrame.aboutGuildText.points or {})[1] or {}
local guildOffsetY = guildPoint[5]
assert.truthy((guildOffsetY or 0) <= -16, "about should leave extra vertical spacing between author and guild")
assert.equal("", mainFrame.aboutDescriptionText:GetText() or "", "about should remove the support note description text")
assert.equal("/gbm help", mainFrame.aboutSlashHintText:GetText(), "about should trim the slash hint copy")
assert.equal("", mainFrame.viewSubtitle:GetText() or "", "about should remove the old descriptive subtitle text")
assert.truthy(not mainFrame.contentBodyText:IsShown(), "about should no longer fall back to the generic body text block")
