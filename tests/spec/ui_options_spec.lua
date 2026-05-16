local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

_G.UnitName = function()
    return "GuildLead"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Guild Master", 0
end

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB.auth.capabilities.auth_manage[0] = true
_G.GBankManagerDB.auth.capabilities.auth_manage[1] = true

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
assert.truthy(mainFrame.optionsScrollBar:IsShown(), "options view should keep the shared scrollbar visible when the content overflows")
assert.equal("Guild Master", mainFrame.optionsAuthRankButton.labelText:GetText(), "options auth should default the selected rank picker to the guildmaster label")
assert.truthy((mainFrame.optionsAvailablePermissionPanel:GetHeight() or 0) >= 132, "options auth should give available permissions enough height to avoid clipping the last row")
assert.truthy((mainFrame.optionsAuthPanel:GetHeight() or 0) < 800, "options auth should size to its actual content instead of leaving a giant dead zone")
assert.equal("Save", mainFrame.optionsAuthSaveButton.labelText:GetText(), "options auth should expose a dedicated local save button")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Guild Info", 1, true) ~= nil, "options auth should explain that the policy string lives in Guild Info")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Copy", 1, true) ~= nil, "options auth should explain that publishing to Guild Info is now a manual copy step")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Accept", 1, true) ~= nil, "options auth should explain that the Guild Information dialog must be accepted after pasting")
assert.same(mainFrame.optionsPolicyStringHelpText, (mainFrame.optionsAuthSaveButton.points[1] or {})[2], "options auth save row should anchor from the policy-string help text so it stays visible")
assert.equal(nil, mainFrame.optionsAuthWriteButton, "options auth should remove the unreliable Write Guild Info button")
assert.equal("<< Add", mainFrame.optionsAuthAddPermissionButton.labelText:GetText(), "options auth add button should point toward the allowed-permissions list")
assert.equal("Remove >>", mainFrame.optionsAuthRemovePermissionButton.labelText:GetText(), "options auth remove button should point toward the available-permissions list")

mainFrame:SelectAuthRank(0)
mainFrame:SelectAuthCapability("available", "request_submit")
assert.equal("request_submit", mainFrame.selectedAvailableCapability, "options auth should track the selected available capability")
local selectedAvailableButton
for _, button in ipairs(mainFrame.optionsAvailablePermissionButtons or {}) do
    if button:IsShown() and button.labelText and button.labelText:GetText() == "Request Submit" then
        selectedAvailableButton = button
        break
    end
end
assert.truthy(selectedAvailableButton ~= nil, "options auth should render the selected available capability button")
assert.truthy((selectedAvailableButton.backdropColor or {})[1] == 0.58, "options auth should visibly highlight the selected available capability")
assert.truthy((selectedAvailableButton.labelText.textColor or {})[1] == 0.85, "options auth should brighten selected capability text")

mainFrame.optionsScrollFrame.height = 0
mainFrame.optionsScrollChild.height = 0
mainFrame.optionsScrollFrame:GetScript("OnMouseWheel")(mainFrame.optionsScrollFrame, -1)
assert.truthy(mainFrame.optionsScrollBar:IsShown(), "options scrollbar should stay visible while scrolling even if the live client reports a transient zero height")

local alphaAfterDown
mainFrame.transparencyDecreaseButton:GetScript("OnClick")(mainFrame.transparencyDecreaseButton)
alphaAfterDown = mainFrame.currentAlpha
assert.truthy(alphaAfterDown < 0.96, "transparency down should reduce alpha")
assert.equal("Opacity 95%", mainFrame.transparencyValueText:GetText(), "opacity decrease should keep the visible percentage label in sync")
assert.equal(nil, mainFrame.transparencySlider, "options should remove the faux slider after the live-client cleanup")
mainFrame.transparencyIncreaseButton:GetScript("OnClick")(mainFrame.transparencyIncreaseButton)
assert.truthy(mainFrame.currentAlpha > alphaAfterDown, "transparency up should increase alpha")

mainFrame:SaveAuthPolicy()
assert.truthy(string.find(mainFrame.optionsAuthStatusText:GetText() or "", "Copy the policy string", 1, true) ~= nil, "options auth save should remind the user to copy the policy string into Guild Information manually")

local authPolicySource = env.ns.modules.authPolicySource
local pullCalled
local originalPullPolicyFromGuildInfo = authPolicySource.PullPolicyFromGuildInfo
authPolicySource.PullPolicyFromGuildInfo = function(db, options)
    pullCalled = options and options.force == true
    db.auth.guildPolicyString = "[GBMAUTH:1;Z;Y;3;-]"
    db.auth.guildPolicySource = "guild_info"
    db.auth.capabilities.request_submit[0] = true
    return true, "applied", db.auth
end

mainFrame:RefreshAuthPolicyFromGuildInfo()
assert.truthy(pullCalled == true, "options auth refresh should force a fresh pull from Guild Info")
assert.equal("[GBMAUTH:1;Z;Y;3;-]", mainFrame.optionsPolicyStringInput:GetText(), "options auth refresh should reload the current Guild Info snippet into the visible policy string")
assert.equal("Reloaded auth policy from Guild Info.", mainFrame.optionsAuthStatusText:GetText(), "options auth refresh should report a successful Guild Info reload")

authPolicySource.PullPolicyFromGuildInfo = originalPullPolicyFromGuildInfo
