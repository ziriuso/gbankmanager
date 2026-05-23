local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

dofile("tests/helpers/wow_stubs.lua")
_G.C_Timer.ClearPending()

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
local activeTheme = env.mainFrameShell.GetTheme()
local syncEvents = env.ns.modules.syncEvents

_G.GBankManagerDB.auth.capabilities.auth_manage[0] = true
_G.GBankManagerDB.auth.capabilities.auth_manage[1] = true

_G.GBankManagerDB.auth.updatedAt = 0
_G.GBankManagerDB.auth.updatedBy = "Stormrage-OfficerOne"
mainFrame:SelectView("OPTIONS")

assert.equal("OPTIONS", mainFrame.activeView, "options tab should be selectable")
assert.truthy(mainFrame.optionsPanel:IsShown(), "options panel should show in the options view")
assert.truthy(mainFrame.optionsAuthPanel:IsShown(), "options view should include the auth management panel")
assert.equal(6, #(mainFrame.optionsTabButtons or {}), "options should expose six top-level tab buttons")
assert.equal("Appearance", ((mainFrame.optionsTabButtons or {})[1] or {}).labelText:GetText(), "options should expose an Appearance tab")
assert.equal("Permissions", ((mainFrame.optionsTabButtons or {})[2] or {}).labelText:GetText(), "options should expose a Permissions tab")
assert.equal("Blacklist", ((mainFrame.optionsTabButtons or {})[3] or {}).labelText:GetText(), "options should expose a Blacklist tab")
assert.equal("Automation", ((mainFrame.optionsTabButtons or {})[4] or {}).labelText:GetText(), "options should expose an Automation tab")
assert.equal("Exports", ((mainFrame.optionsTabButtons or {})[5] or {}).labelText:GetText(), "options should expose an Exports tab")
assert.equal("Requests", ((mainFrame.optionsTabButtons or {})[6] or {}).labelText:GetText(), "options should expose a Requests tab")
assert.equal("APPEARANCE", mainFrame.optionsActiveTab, "options should default to the Appearance tab")
assert.truthy(mainFrame.optionsAppearancePanel:IsShown(), "options should show the Appearance content by default")
assert.truthy(not mainFrame.optionsPermissionsPanel:IsShown(), "options should hide the Permissions content by default")
assert.truthy(not mainFrame.optionsBlacklistPanel:IsShown(), "options should hide the Blacklist content by default")
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
assert.truthy(type(mainFrame.optionsThemeDefaultButton) == "table", "options appearance should expose a Generic WoW theme preset button")
assert.truthy(type(mainFrame.optionsThemeContrastButton) == "table", "options appearance should expose a high-contrast theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).horde) == "table", "options appearance should expose a horde theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).alliance) == "table", "options appearance should expose an alliance theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).generic_wow) == "table", "options appearance should expose a Generic WoW theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).nature) == "table", "options appearance should expose a nature theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).high_contrast) == "table", "options appearance should expose a High Contrast theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).void) == "table", "options appearance should expose a void theme preset button")
assert.equal("Generic WoW", mainFrame.optionsThemeDefaultButton.labelText:GetText(), "options appearance should label the default preset as Generic WoW")
assert.equal("High Contrast", mainFrame.optionsThemeContrastButton.labelText:GetText(), "options appearance should label the contrast preset as High Contrast")
assert.equal("Nature", ((mainFrame.optionsThemeButtons or {}).nature or {}).labelText:GetText(), "options appearance should label the green preset as Nature")
assert.truthy(type(mainFrame.optionsShellScaleSlider) == "table", "options appearance should expose a shell scale slider")
assert.truthy(type(mainFrame.optionsShellOpacitySlider) == "table", "options appearance should expose a shell opacity slider")
assert.truthy(type(mainFrame.optionsModalOpacitySlider) == "table", "options appearance should expose a modal opacity slider")
assert.equal("UI Scale", mainFrame.optionsShellScaleLabel:GetText(), "options appearance should rename the scale control to UI Scale")
assert.truthy(string.find(mainFrame.optionsHint:GetText() or "", "UI scale", 1, true) ~= nil, "options appearance should explain the linked UI scale behavior")
assert.truthy(mainFrame.optionsTableDensitySlider == nil or not mainFrame.optionsTableDensitySlider:IsShown(), "options appearance should stop showing a separate table density slider")
assert.truthy(mainFrame.optionsTableDensityLabel == nil or not mainFrame.optionsTableDensityLabel:IsShown(), "options appearance should stop showing a separate table density label")
assert.equal("UISliderTemplate", mainFrame.optionsShellScaleSlider.template, "options appearance should use the built-in WoW slider template for UI Scale")
assert.equal("UISliderTemplate", mainFrame.optionsShellOpacitySlider.template, "options appearance should use the built-in WoW slider template for shell opacity")
assert.equal("UISliderTemplate", mainFrame.optionsModalOpacitySlider.template, "options appearance should use the built-in WoW slider template for modal opacity")
assert.equal(0.9, select(1, mainFrame.optionsShellScaleSlider:GetMinMaxValues()), "UI Scale should allow scaling down to 90 percent")
assert.equal(1.2, select(2, mainFrame.optionsShellScaleSlider:GetMinMaxValues()), "UI Scale should allow scaling up to 120 percent")
assert.equal(0, select(1, mainFrame.optionsShellOpacitySlider:GetMinMaxValues()), "shell opacity should allow fully transparent minimum")
assert.equal(1, select(2, mainFrame.optionsShellOpacitySlider:GetMinMaxValues()), "shell opacity should allow fully opaque maximum")
assert.equal(0, select(1, mainFrame.optionsModalOpacitySlider:GetMinMaxValues()), "modal opacity should allow fully transparent minimum")
assert.equal(1, select(2, mainFrame.optionsModalOpacitySlider:GetMinMaxValues()), "modal opacity should allow fully opaque maximum")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Guild Info", 1, true) ~= nil, "options auth should explain that the policy string lives in Guild Info")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Copy", 1, true) ~= nil, "options auth should explain that publishing to Guild Info is now a manual copy step")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Accept", 1, true) ~= nil, "options auth should explain that the Guild Information dialog must be accepted after pasting")
assert.equal("Select All", mainFrame.optionsPolicyStringSelectAllButton.labelText:GetText(), "options auth should expose a select-all button for the compact policy string")
assert.truthy(string.find(mainFrame.optionsAuthHint:GetText() or "", "Character-Server", 1, true) ~= nil, "options auth should explicitly document Character-Server blacklist formatting")
assert.truthy((mainFrame.optionsPolicyStringHelpText:GetWidth() or 0) <= 280, "options auth help copy should stay narrow enough to avoid bleeding into the blacklist column")
assert.truthy((mainFrame.optionsAuthStatusText:GetWidth() or 0) <= 280, "options auth status copy should stay narrow enough to avoid bleeding into the blacklist column")
assert.same(mainFrame.optionsAuthStatusText, (mainFrame.optionsAuthSaveButton.points[1] or {})[2], "options auth save row should anchor below the status line so wrapped policy copy stays readable")
assert.equal(nil, mainFrame.optionsAuthWriteButton, "options auth should remove the unreliable Write Guild Info button")
assert.equal("<< Add", mainFrame.optionsAuthAddPermissionButton.labelText:GetText(), "options auth add button should point toward the allowed-permissions list")
assert.equal("Remove >>", mainFrame.optionsAuthRemovePermissionButton.labelText:GetText(), "options auth remove button should point toward the available-permissions list")

_G.GBankManagerDB.auth.blacklist = {
    ["Stormrage-Ziriously"] = {
        name = "Ziriously",
        reason = "Abused System",
        updatedAt = 77,
    },
}
mainFrame.authDraftPolicy = nil
mainFrame:RefreshAuthOptions()
assert.equal(
    "Ziriously-Stormrage",
    ((mainFrame.optionsBlacklistButtons or {})[1] or {}).labelText:GetText(),
    "options blacklist should render parsed guild blacklists in Character-Server display order"
)
assert.truthy(type((mainFrame.optionsBlacklistButtons or {})[1]) == "table", "options blacklist should render rows for parsed blacklist members")
assert.truthy(((mainFrame.optionsBlacklistButtons or {})[1] or {}).isShown == true or ((mainFrame.optionsBlacklistButtons or {})[1] or {}):IsShown(), "options blacklist should show parsed blacklist rows")
mainFrame:SetOptionsTab("BLACKLIST")
assert.truthy(mainFrame.optionsBlacklistPanel:IsShown(), "options should show the Blacklist panel after tab switch")
assert.truthy(string.find(mainFrame.optionsBlacklistPanelHint:GetText() or "", "read-only", 1, true) ~= nil, "options blacklist should explain that the view is read-only")
assert.truthy(string.find(mainFrame.optionsBlacklistInstructionText:GetText() or "", "[GBMBL]", 1, true) ~= nil, "options blacklist should explain the shared officer-note tag")
assert.truthy(not mainFrame.optionsBlacklistNameInput:IsShown(), "options blacklist should hide the old editable character input")
assert.truthy(not mainFrame.optionsBlacklistReasonInput:IsShown(), "options blacklist should hide the old reason input")
assert.truthy(not mainFrame.optionsBlacklistAddButton:IsShown(), "options blacklist should not expose add or update actions")
assert.truthy(not mainFrame.optionsBlacklistRemoveButton:IsShown(), "options blacklist should not expose remove actions")
assert.truthy(not mainFrame.optionsBlacklistSaveButton:IsShown(), "options blacklist should not expose a save action")
assert.truthy(not mainFrame.optionsBlacklistResetButton:IsShown(), "options blacklist should not expose a revert action")
assert.truthy(not mainFrame.optionsBlacklistTitle:IsShown(), "options blacklist should hide the legacy duplicate blacklist header in the read-only view")
assert.truthy(mainFrame.optionsBlacklistRefreshButton:IsShown(), "options blacklist should expose a refresh action for reparsing officer-note tags")
assert.equal("Refresh", mainFrame.optionsBlacklistRefreshButton.labelText:GetText(), "options blacklist should label the read-only reparse action clearly")
assert.equal("secondary", mainFrame.optionsBlacklistRefreshButton.gbmButtonVariant, "options blacklist refresh should use the themed secondary button variant")
assert.equal("BOTTOMRIGHT", select(1, mainFrame.optionsBlacklistRefreshButton:GetPoint(1)), "options blacklist refresh should anchor above the parsed-member list")
assert.equal(mainFrame.optionsBlacklistListPanel, select(2, mainFrame.optionsBlacklistRefreshButton:GetPoint(1)), "options blacklist refresh should position from the blacklist list panel")
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Parsed", 1, true) ~= nil, "options blacklist should summarize how many tagged guild members were parsed")

local rosterRequestsBefore = _G.C_GuildInfo.guildRosterRequests or 0
mainFrame.optionsBlacklistRefreshButton:GetScript("OnClick")(mainFrame.optionsBlacklistRefreshButton)
assert.truthy((_G.C_GuildInfo.guildRosterRequests or 0) > rosterRequestsBefore, "options blacklist refresh should request fresh guild roster data before reparsing officer notes")
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Refreshing", 1, true) ~= nil, "options blacklist refresh should report that officer-note parsing is refreshing")
syncEvents.HandleEvent("GUILD_ROSTER_UPDATE")
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Parsed", 1, true) ~= nil, "options blacklist refresh should restore the parsed-member summary after the guild roster update arrives")
mainFrame.optionsBlacklistRefreshButton:GetScript("OnClick")(mainFrame.optionsBlacklistRefreshButton)
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Refreshing", 1, true) ~= nil, "options blacklist refresh should enter refreshing state on repeat clicks")
_G.C_Timer.RunPending()
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Parsed", 1, true) ~= nil, "options blacklist refresh should recover to the parsed-member summary even if no roster event arrives")

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
assert.equal((activeTheme.colors.accent or {})[1], (selectedAvailableButton.backdropColor or {})[1], "options auth should visibly highlight the selected available capability")
assert.equal((activeTheme.colors.accentStrong or {})[1], (selectedAvailableButton.labelText.textColor or {})[1], "options auth should brighten selected capability text")

mainFrame.optionsScrollFrame.height = 0
mainFrame.optionsScrollChild.height = 0
mainFrame.optionsScrollFrame:GetScript("OnMouseWheel")(mainFrame.optionsScrollFrame, -1)
assert.truthy(mainFrame.optionsScrollBar:IsShown(), "options scrollbar should stay visible while scrolling even if the live client reports a transient zero height")

local originalWidth = mainFrame:GetWidth()
local originalRowHeight = mainFrame.tableRowHeight
mainFrame:SetThemePreset("horde")
assert.equal("horde", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should persist in local appearance settings")
assert.truthy((mainFrame.sidebar.backdropColor or {})[1] ~= 0.10, "theme preset changes should update visible shell colors")
mainFrame:SetThemePreset("nature")
assert.equal("nature", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should support the expanded preset list")
mainFrame:SetShellScale(1.1)
assert.truthy(mainFrame:GetWidth() > originalWidth, "shell scale should grow the main shell width")
assert.equal(1.1, _G.GBankManagerDB.ui.appearance.shellScale, "shell scale changes should persist in local appearance settings")
assert.equal(1.1, _G.GBankManagerDB.ui.appearance.tableDensity, "shell scale should keep persisted table density linked to the same scale")
assert.equal("110%", mainFrame.optionsShellScaleValueText:GetText(), "shell scale changes should refresh the visible percentage label")
mainFrame:SetShellScale(1.15)
assert.truthy(mainFrame.tableRowHeight > originalRowHeight, "UI Scale should still grow shared table row height through the linked table-density behavior")
assert.equal(1.15, _G.GBankManagerDB.ui.appearance.shellScale, "UI Scale adjustments should persist through the shell scale setting")
assert.equal(1.15, _G.GBankManagerDB.ui.appearance.tableDensity, "UI Scale should keep the linked table density persisted to the same value")
mainFrame:SetShellOpacity(0.95)
assert.equal(0.95, mainFrame.currentAlpha, "shell opacity should persist the current shell opacity setting")
assert.truthy(mainFrame.alpha == nil or mainFrame.alpha == 1, "shell opacity should not dim the entire main shell frame")
assert.equal("95%", mainFrame.optionsShellOpacityValueText:GetText(), "shell opacity changes should refresh the visible percentage label")
mainFrame:SetModalOpacity(0.88)
assert.equal(0.88, _G.GBankManagerDB.ui.appearance.modalOpacity, "modal opacity changes should persist in local appearance settings")
assert.truthy(mainFrame.requestDetailsModal.alpha == nil or mainFrame.requestDetailsModal.alpha == 1, "modal opacity should not dim the entire request-details modal frame")
assert.truthy(mainFrame.minimumAddModal.alpha == nil or mainFrame.minimumAddModal.alpha == 1, "modal opacity should not dim the entire minimum-add modal frame")
assert.truthy(mainFrame.minimumDetailsModal.alpha == nil or mainFrame.minimumDetailsModal.alpha == 1, "modal opacity should not dim the entire minimum-details modal frame")
assert.truthy(mainFrame.exportModal.alpha == nil or mainFrame.exportModal.alpha == 1, "modal opacity should not dim the entire export modal frame")
assert.truthy(mainFrame.exportStockedElsewhereModal.alpha == nil or mainFrame.exportStockedElsewhereModal.alpha == 1, "modal opacity should not dim the entire stocked-elsewhere modal frame")
assert.truthy(mainFrame.exportManualShoppingListModal.alpha == nil or mainFrame.exportManualShoppingListModal.alpha == 1, "modal opacity should not dim the entire manual shopping-list modal frame")
assert.equal("88%", mainFrame.optionsModalOpacityValueText:GetText(), "modal opacity changes should refresh the visible percentage label")
local loweredBackdropAlpha = ((mainFrame.minimumAddModal.backdropColor or {})[4] or 0)
mainFrame:SetModalOpacity(0.99)
assert.truthy((((mainFrame.minimumAddModal.backdropColor or {})[4] or 0) > loweredBackdropAlpha), "raising modal opacity should restore modal backdrop alpha instead of getting stuck at the lower setting")
mainFrame:SetModalOpacity(0.88)

local scaleBeforeButtons = _G.GBankManagerDB.ui.appearance.shellScale
mainFrame.optionsShellScaleIncreaseButton:GetScript("OnClick")(mainFrame.optionsShellScaleIncreaseButton)
assert.truthy(_G.GBankManagerDB.ui.appearance.shellScale > scaleBeforeButtons, "shell-scale plus should step the slider value upward")
mainFrame.optionsShellScaleDecreaseButton:GetScript("OnClick")(mainFrame.optionsShellScaleDecreaseButton)
assert.equal(scaleBeforeButtons, _G.GBankManagerDB.ui.appearance.shellScale, "shell-scale minus should step the slider value back down")
assert.truthy(mainFrame.optionsShellScaleSlider.mouseEnabled == true, "UI Scale slider should allow direct mouse interaction")
assert.equal(true, mainFrame.optionsShellScaleSlider.obeyStepOnDrag, "UI Scale slider should obey step increments while dragging")
mainFrame.optionsShellScaleSlider:SetValue(1.2)
assert.truthy(math.abs((_G.GBankManagerDB.ui.appearance.shellScale or 0) - 1.2) < 0.0001, "dragging the shell-scale slider should persist the new shell scale")
mainFrame.optionsShellScaleSlider:SetValue(0.95)
assert.truthy(math.abs((_G.GBankManagerDB.ui.appearance.tableDensity or 0) - 0.95) < 0.0001, "dragging the UI Scale slider should keep the linked table density in sync")

local shellOpacityBeforeButtons = _G.GBankManagerDB.ui.appearance.shellOpacity
mainFrame.optionsShellOpacityIncreaseButton:GetScript("OnClick")(mainFrame.optionsShellOpacityIncreaseButton)
assert.truthy(_G.GBankManagerDB.ui.appearance.shellOpacity > shellOpacityBeforeButtons, "shell-opacity plus should step the slider value upward")
mainFrame.optionsShellOpacityDecreaseButton:GetScript("OnClick")(mainFrame.optionsShellOpacityDecreaseButton)
assert.equal(shellOpacityBeforeButtons, _G.GBankManagerDB.ui.appearance.shellOpacity, "shell-opacity minus should step the slider value back down")
assert.equal(true, mainFrame.optionsShellOpacitySlider.obeyStepOnDrag, "shell opacity slider should obey step increments while dragging")
mainFrame.optionsShellOpacitySlider:SetValue(0.9)
assert.truthy(math.abs((_G.GBankManagerDB.ui.appearance.shellOpacity or 0) - 0.9) < 0.0001, "dragging the shell-opacity slider should persist the new opacity")

local modalOpacityBeforeButtons = _G.GBankManagerDB.ui.appearance.modalOpacity
mainFrame.optionsModalOpacityIncreaseButton:GetScript("OnClick")(mainFrame.optionsModalOpacityIncreaseButton)
assert.truthy(_G.GBankManagerDB.ui.appearance.modalOpacity > modalOpacityBeforeButtons, "modal-opacity plus should step the slider value upward")
mainFrame.optionsModalOpacityDecreaseButton:GetScript("OnClick")(mainFrame.optionsModalOpacityDecreaseButton)
assert.equal(modalOpacityBeforeButtons, _G.GBankManagerDB.ui.appearance.modalOpacity, "modal-opacity minus should step the slider value back down")
assert.equal(true, mainFrame.optionsModalOpacitySlider.obeyStepOnDrag, "modal opacity slider should obey step increments while dragging")
mainFrame.optionsModalOpacitySlider:SetValue(0.93)
assert.truthy(math.abs((_G.GBankManagerDB.ui.appearance.modalOpacity or 0) - 0.93) < 0.0001, "dragging the modal-opacity slider should persist the new opacity")

mainFrame:SaveAuthPolicy()
assert.truthy(string.find(mainFrame.optionsAuthStatusText:GetText() or "", "Copy the policy string", 1, true) ~= nil, "options auth save should remind the user to copy the policy string into Guild Information manually")
assert.equal("AUTH_POLICY_UPDATED", ((_G.GBankManagerDB.auditLog or {})[1] or {}).type, "options auth save should append an auth-policy history entry")
assert.truthy(string.find(mainFrame.optionsPolicyStringInput:GetText() or "", "#", 1, true) ~= nil, "options auth save should persist the compact updater hash into the visible policy string")

local authPolicySource = env.ns.modules.authPolicySource
local pullCalled
local originalPullPolicyFromGuildInfo = authPolicySource.PullPolicyFromGuildInfo
authPolicySource.PullPolicyFromGuildInfo = function(db, options)
    pullCalled = options and options.force == true
    db.auth.guildPolicyString = "[GBMAUTH:1;Z;Y;3;-]"
    db.auth.guildPolicySource = "guild_info"
    db.auth.updatedAt = 123
    db.auth.updatedBy = "Stormrage-GuildLead"
    db.auth.capabilities.request_submit[0] = true
    db.ui.minimumSettings.defaultQuantity = 275
    return true, "applied", db.auth
end

mainFrame:RefreshAuthPolicyFromGuildInfo()
assert.truthy(pullCalled == true, "options auth refresh should force a fresh pull from Guild Info")
assert.equal("[GBMAUTH:1;Z;Y;3;-]", mainFrame.optionsPolicyStringInput:GetText(), "options auth refresh should reload the current Guild Info snippet into the visible policy string")
assert.equal("Reloaded auth policy from Guild Info.", mainFrame.optionsAuthStatusText:GetText(), "options auth refresh should report a successful Guild Info reload")
assert.equal("275", mainFrame.defaultMinimumInput:GetText(), "options auth refresh should also preload the shared restock default from Guild Info")
assert.truthy(string.find(mainFrame.optionsAuthMetadataText:GetText() or "", "GuildLead-Stormrage", 1, true) ~= nil, "options auth refresh should show the updater loaded from Guild Info metadata")

authPolicySource.PullPolicyFromGuildInfo = originalPullPolicyFromGuildInfo

mainFrame.optionsPolicyStringInput:SetText("[GBMAUTH:2;A;B;4;-]")
mainFrame.optionsPolicyStringSelectAllButton:GetScript("OnClick")(mainFrame.optionsPolicyStringSelectAllButton)
assert.truthy(mainFrame.optionsPolicyStringInput:HasFocus(), "policy-string select all should focus the compact policy-string input")
assert.equal(0, mainFrame.optionsPolicyStringInput.cursorPosition, "policy-string select all should rewind the cursor before highlighting")
assert.equal(0, mainFrame.optionsPolicyStringInput.highlightStart, "policy-string select all should highlight from the start of the policy string")
assert.equal(-1, mainFrame.optionsPolicyStringInput.highlightEnd, "policy-string select all should extend the highlight through the entire policy string")
assert.equal("Selected the policy string. Press Ctrl+C to copy.", mainFrame.optionsAuthStatusText:GetText(), "policy-string select all should give visible copy guidance")

local preloadCalls = 0
authPolicySource.PullPolicyFromGuildInfo = function(db, options)
    preloadCalls = preloadCalls + 1
    db.auth.guildPolicyString = "[GBMAUTH:2;A;B;4;-]"
    db.auth.guildPolicySource = "guild_info"
    db.auth.updatedAt = 456
    db.auth.updatedBy = "Stormrage-PolicyLead"
    return true, "applied", db.auth
end
mainFrame:ShowDashboard()
mainFrame:SelectView("OPTIONS")
assert.truthy(preloadCalls > 0, "opening options should pull the latest auth policy from Guild Info before populating the controls")
assert.equal("[GBMAUTH:2;A;B;4;-]", mainFrame.optionsPolicyStringInput:GetText(), "opening options should preload the current Guild Info policy string into the visible controls")
assert.truthy(string.find(mainFrame.optionsAuthMetadataText:GetText() or "", "PolicyLead-Stormrage", 1, true) ~= nil, "opening options should refresh the auth metadata after preloading Guild Info")
mainFrame.optionsTabButtons[2]:GetScript("OnClick")(mainFrame.optionsTabButtons[2])
assert.equal("PERMISSIONS", mainFrame.optionsActiveTab, "options should switch to the Permissions tab when clicked")
assert.truthy(mainFrame.optionsPermissionsPanel:IsShown(), "options should show the Permissions panel after tab switch")
assert.truthy(not mainFrame.optionsAppearancePanel:IsShown(), "options should hide the Appearance panel after switching away")
mainFrame.optionsTabButtons[3]:GetScript("OnClick")(mainFrame.optionsTabButtons[3])
assert.equal("BLACKLIST", mainFrame.optionsActiveTab, "options should switch to the Blacklist tab when clicked")
assert.truthy(mainFrame.optionsBlacklistPanel:IsShown(), "options should show the Blacklist panel after tab switch")
assert.truthy(not mainFrame.optionsPermissionsPanel:IsShown(), "options should hide the Permissions panel after switching away")
authPolicySource.PullPolicyFromGuildInfo = originalPullPolicyFromGuildInfo
