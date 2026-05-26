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
assert.truthy(string.find(mainFrame.aboutVersionText:GetText() or "", "0.9.0-beta", 1, true) ~= nil, "about should show the addon version from TOC metadata")
assert.truthy(string.find(mainFrame.aboutAuthorText:GetText() or "", "Zirleficent", 1, true) ~= nil, "about should show the author line")
assert.truthy(string.find(mainFrame.aboutGuildText:GetText() or "", "Guild Testers", 1, true) ~= nil, "about should show guild identity when available")
assert.truthy(string.find(mainFrame.aboutSlashHintText:GetText() or "", "/gbm", 1, true) ~= nil, "about should include the slash command hint")
assert.truthy(not mainFrame.contentBodyText:IsShown(), "about should no longer fall back to the generic body text block")
