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

local function color_distance(left, right)
    left = left or {}
    right = right or {}
    local total = 0
    for index = 1, 3 do
        total = total + math.abs((left[index] or 0) - (right[index] or 0))
    end
    return total
end

_G.GBankManagerDB.auth.capabilities.auth_manage[0] = true
_G.GBankManagerDB.auth.capabilities.auth_manage[1] = true

_G.GBankManagerDB.auth.updatedAt = 0
_G.GBankManagerDB.auth.updatedBy = "Stormrage-OfficerOne"
mainFrame:SelectView("OPTIONS")

assert.equal("OPTIONS", mainFrame.activeView, "options tab should be selectable")
assert.truthy(mainFrame.optionsPanel:IsShown(), "options panel should show in the options view")
assert.truthy(mainFrame.optionsAppearancePanel:IsShown(), "options view should open on the appearance panel")
assert.equal(5, #(mainFrame.optionsTabButtons or {}), "options should expose five top-level tab buttons after trimming the unused placeholders")
assert.equal("Appearance", ((mainFrame.optionsTabButtons or {})[1] or {}).labelText:GetText(), "options should expose an Appearance tab")
assert.equal("Stock Settings", ((mainFrame.optionsTabButtons or {})[2] or {}).labelText:GetText(), "options should expose a Stock Settings tab")
assert.equal("Permissions", ((mainFrame.optionsTabButtons or {})[3] or {}).labelText:GetText(), "options should expose a Permissions tab")
assert.equal("Blacklist", ((mainFrame.optionsTabButtons or {})[4] or {}).labelText:GetText(), "options should expose a Blacklist tab")
assert.equal("Data", ((mainFrame.optionsTabButtons or {})[5] or {}).labelText:GetText(), "options should expose a Data tab")
assert.equal("segmented-soft", ((mainFrame.optionsTabButtons or {})[1] or {}).gbmTabStyle, "options tabs should use the softer segmented-tab treatment")
assert.equal("APPEARANCE", mainFrame.optionsActiveTab, "options should default to the Appearance tab")
assert.truthy(mainFrame.optionsAppearancePanel:IsShown(), "options should show the Appearance content by default")
assert.truthy(not mainFrame.optionsStockSettingsPanel:IsShown(), "options should hide the Stock Settings content by default")
assert.truthy(not mainFrame.optionsPermissionsPanel:IsShown(), "options should hide the Permissions content by default")
assert.truthy(not mainFrame.optionsBlacklistPanel:IsShown(), "options should hide the Blacklist content by default")
assert.truthy(not mainFrame.optionsLogsHistoryPanel:IsShown(), "options should hide the Data content by default")
assert.truthy(mainFrame.optionsViewportFrame:IsShown(), "options view should show its dedicated viewport frame")
assert.equal(mainFrame.optionsViewportFrame, mainFrame.optionsScrollFrame.parent, "options scroll frame should live inside the dedicated viewport")
assert.equal(nil, mainFrame.optionsScrollFrame.template, "options view should use a plain scroll frame")
assert.equal(mainFrame.optionsScrollChild, mainFrame.optionsScrollFrame.scrollChild, "options scroll frame should attach its settings canvas as the scroll child")
assert.equal(0, (((mainFrame.optionsTabBar or {}).backdropBorderColor or {})[4] or 0), "options tab bar should not draw a ghost border container behind the tab buttons")
assert.equal(0, (((mainFrame.optionsViewportFrame or {}).backdropBorderColor or {})[4] or 0), "options viewport should not draw a second ghost border around the active settings panel")
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
assert.equal("select", mainFrame.optionsAuthRankButton.gbmButtonVariant, "options auth rank picker should use the shared select control styling")
assert.truthy(color_distance(((mainFrame.optionsAuthRankButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.optionsPermissionsPanel.gbmArt or {}).innerFill or {}).color) >= 0.10, "options auth rank picker should contrast from the permissions panel")
assert.truthy((mainFrame.optionsAvailablePermissionPanel:GetHeight() or 0) >= 132, "options auth should give available permissions enough height to avoid clipping the last row")
assert.truthy((mainFrame.optionsAuthPanel:GetHeight() or 0) < 800, "options auth should size to its actual content instead of leaving a giant dead zone")
assert.equal("Save", mainFrame.optionsAuthSaveButton.labelText:GetText(), "options auth should expose a dedicated local save button")
mainFrame:SetOptionsTab("STOCK")
assert.equal("STOCK", mainFrame.optionsActiveTab, "options should switch to the Stock Settings tab when clicked")
assert.truthy(mainFrame.optionsStockSettingsPanel:IsShown(), "options should show the Stock Settings panel after tab switch")
assert.truthy(not mainFrame.optionsAppearancePanel:IsShown(), "options should hide the Appearance panel after switching away")
assert.equal("Restock Default", mainFrame.optionsRestockTitle:GetText(), "stock settings should keep the restock default control")
assert.equal("Critical Shortage Threshold", mainFrame.optionsCriticalThresholdTitle:GetText(), "stock settings should expose the critical shortage threshold control")
assert.truthy(string.find(mainFrame.optionsCriticalThresholdHint:GetText() or "", "at or below", 1, true) ~= nil, "stock settings should explain that critical uses current stock at or below the chosen percentage of minimum")
assert.truthy((mainFrame.optionsRestockHint:GetWidth() or 0) <= 240, "stock settings should keep the restock hint narrow enough to stay inside its column")
assert.truthy((mainFrame.optionsCriticalThresholdHint:GetWidth() or 0) <= 250, "stock settings should keep the critical-threshold hint narrow enough to avoid overflowing the panel")
assert.equal("50", mainFrame.optionsCriticalThresholdInput:GetText(), "stock settings should default the critical threshold to 50 percent")
assert.equal("Save Settings", mainFrame.optionsStockSettingsSaveButton.labelText:GetText(), "stock settings should save the stock controls together")
assert.equal("primary", mainFrame.optionsStockSettingsSaveButton.gbmButtonVariant, "stock settings save should use the primary action variant")
assert.truthy(color_distance(((mainFrame.optionsStockSettingsSaveButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.optionsStockSettingsPanel.gbmArt or {}).innerFill or {}).color) >= 0.10, "stock settings save should contrast from the stock settings panel")
mainFrame.defaultMinimumInput:SetText("250")
mainFrame.optionsCriticalThresholdInput:SetText("40")
mainFrame.optionsStockSettingsSaveButton:GetScript("OnClick")(mainFrame.optionsStockSettingsSaveButton)
assert.equal(250, (((_G.GBankManagerDB or {}).ui or {}).minimumSettings or {}).defaultQuantity, "stock settings should persist the restock default")
assert.equal(40, (((_G.GBankManagerDB or {}).ui or {}).minimumSettings or {}).criticalThresholdPercent, "stock settings should persist the critical shortage threshold")
assert.equal(250, ((_G.GBankManagerDB or {}).auth or {}).restockDefault, "stock settings should continue mirroring restock default into auth metadata")
mainFrame:SetOptionsTab("LOGS_HISTORY")
assert.equal("LOGS_HISTORY", mainFrame.optionsActiveTab, "options should switch to the Data tab when clicked")
assert.truthy(mainFrame.optionsLogsHistoryPanel:IsShown(), "options should show the Data panel after tab switch")
assert.equal("Data", mainFrame.optionsLogsHistoryTitle:GetText(), "data settings should rename the panel title to Data")
assert.equal("Guild Bank Log Retention", mainFrame.optionsLedgerRetentionTitle:GetText(), "logs/history settings should expose ledger retention")
assert.equal("History Retention", mainFrame.optionsHistoryRetentionTitle:GetText(), "logs/history settings should expose audit-history retention")
assert.equal("Scan Interval", mainFrame.optionsLedgerScanIntervalTitle:GetText(), "logs/history settings should expose the shared scan interval label")
assert.equal("5 Minutes", mainFrame.optionsLedgerScanIntervalButton.labelText:GetText(), "logs/history settings should default the ledger scan interval to five minutes")
assert.equal("Indefinite", mainFrame.optionsLedgerRetentionButton.labelText:GetText(), "logs/history settings should default ledger retention to indefinite")
assert.equal("Indefinite", mainFrame.optionsHistoryRetentionButton.labelText:GetText(), "logs/history settings should default history retention to indefinite")
assert.equal((mainFrame.optionsLedgerRetentionTitle.points[1] or {})[5], (mainFrame.optionsHistoryRetentionTitle.points[1] or {})[5], "data dropdown labels should align to the same vertical baseline")
assert.equal((mainFrame.optionsLedgerRetentionTitle.points[1] or {})[5], (mainFrame.optionsLedgerScanIntervalTitle.points[1] or {})[5], "data scan interval label should align with the other dropdown labels")
assert.equal((mainFrame.optionsLedgerRetentionButton.points[1] or {})[5], (mainFrame.optionsHistoryRetentionButton.points[1] or {})[5], "data dropdown controls should sit on the same row")
assert.equal((mainFrame.optionsLedgerRetentionButton.points[1] or {})[5], (mainFrame.optionsLedgerScanIntervalButton.points[1] or {})[5], "data scan interval control should sit on the same row as the retention controls")
assert.truthy(type(mainFrame.optionsLogsHistoryStatusText) == "table", "logs/history settings should expose visible save-feedback text")
mainFrame.optionsLedgerScanIntervalButton:GetScript("OnClick")(mainFrame.optionsLedgerScanIntervalButton)
assert.same(mainFrame.optionsLedgerScanIntervalButton, mainFrame.sharedChoiceDropdownOwner, "logs/history scan interval should open a real dropdown menu from the select control")
assert.truthy(mainFrame.sharedChoiceDropdownPanel:IsShown(), "logs/history scan interval dropdown should show its shared panel")
assert.equal(5, #(mainFrame.sharedChoiceDropdownOptions or {}), "logs/history scan interval should expose all supported interval choices in its dropdown")
mainFrame.sharedChoiceDropdownOptions[2]:GetScript("OnClick")(mainFrame.sharedChoiceDropdownOptions[2])
mainFrame.optionsLedgerRetentionButton:GetScript("OnClick")(mainFrame.optionsLedgerRetentionButton)
assert.same(mainFrame.optionsLedgerRetentionButton, mainFrame.sharedChoiceDropdownOwner, "logs/history ledger retention should open a real dropdown menu from the select control")
assert.equal(6, #(mainFrame.sharedChoiceDropdownOptions or {}), "logs/history ledger retention should expose all supported retention choices in its dropdown")
mainFrame.sharedChoiceDropdownOptions[1]:GetScript("OnClick")(mainFrame.sharedChoiceDropdownOptions[1])
mainFrame.optionsHistoryRetentionButton:GetScript("OnClick")(mainFrame.optionsHistoryRetentionButton)
assert.same(mainFrame.optionsHistoryRetentionButton, mainFrame.sharedChoiceDropdownOwner, "logs/history history retention should open a real dropdown menu from the select control")
assert.equal(6, #(mainFrame.sharedChoiceDropdownOptions or {}), "logs/history history retention should expose all supported retention choices in its dropdown")
mainFrame.sharedChoiceDropdownOptions[1]:GetScript("OnClick")(mainFrame.sharedChoiceDropdownOptions[1])
mainFrame.optionsLogsHistorySaveButton:GetScript("OnClick")(mainFrame.optionsLogsHistorySaveButton)
assert.equal(600, (((_G.GBankManagerDB or {}).ui or {}).logsHistorySettings or {}).ledgerScanIntervalSeconds, "logs/history settings should persist the selected ledger scan interval")
assert.equal("1_week", (((_G.GBankManagerDB or {}).ui or {}).logsHistorySettings or {}).ledgerRetention, "logs/history settings should persist the selected ledger retention")
assert.equal("1_week", (((_G.GBankManagerDB or {}).ui or {}).logsHistorySettings or {}).historyRetention, "logs/history settings should persist the selected history retention")
assert.equal("Saved logs/history settings.", mainFrame.optionsLogsHistoryStatusText:GetText(), "logs/history settings should report visible save feedback after saving")
assert.same(mainFrame.optionsLedgerRetentionButton, (mainFrame.optionsLogsHistorySaveButton.points[1] or {})[2], "data save should sit up near the retention controls")
assert.truthy((mainFrame.optionsLogsHistoryPanel:GetHeight() or 0) >= 320, "data panel should stay tall enough to keep save and clear-data controls inside the chrome")
assert.equal("Clear Data", mainFrame.optionsClearDataTitle:GetText(), "data settings should expose a clear-data section")
assert.equal("Clear Guild Bank Log Data", mainFrame.optionsClearBankLedgerButton.labelText:GetText(), "data settings should expose a clear guild-bank log action")
assert.equal(mainFrame.optionsClearInventoryDataButton:GetWidth(), mainFrame.optionsClearBankLedgerButton:GetWidth(), "data settings should size the clear guild-bank log action like the sibling destructive controls so its text stays centered")
assert.equal(mainFrame.optionsClearCompletedRequestsButton:GetWidth(), mainFrame.optionsClearBankLedgerButton:GetWidth(), "data settings should keep all clear-data buttons the same width")
assert.equal("Clear Guild Bank Inventory Data", mainFrame.optionsClearInventoryDataButton.labelText:GetText(), "data settings should expose a clear guild-bank inventory action")
assert.equal("Clear Completed Request History", mainFrame.optionsClearCompletedRequestsButton.labelText:GetText(), "data settings should expose a clear completed request-history action")
mainFrame.optionsClearBankLedgerButton:GetScript("OnClick")(mainFrame.optionsClearBankLedgerButton)
assert.equal("GBM_CONFIRM_CLEAR_BANK_LEDGER", (_G.LastStaticPopup or {}).which, "clearing guild-bank log data should require confirmation")
assert.truthy(string.find((((_G.StaticPopupCalls or {})[#(_G.StaticPopupCalls or {})] or {}).text_arg1 or ""), "irreversible", 1, true) ~= nil, "clear-data confirmation should warn that the action is irreversible")
_G.StaticPopupDialogs["GBM_CONFIRM_CLEAR_BANK_LEDGER"].OnAccept((_G.LastStaticPopup or {}), (_G.LastStaticPopup or {}).data)
assert.equal(0, #((((_G.GBankManagerDB or {}).bankLedger or {}).itemLogs or {})), "confirmed clear-data should remove saved bank-ledger item rows")
assert.equal(0, #((((_G.GBankManagerDB or {}).bankLedger or {}).moneyLogs or {})), "confirmed clear-data should remove saved bank-ledger money rows")
mainFrame.optionsClearInventoryDataButton:GetScript("OnClick")(mainFrame.optionsClearInventoryDataButton)
assert.equal("GBM_CONFIRM_CLEAR_INVENTORY", (_G.LastStaticPopup or {}).which, "clearing inventory data should require confirmation")
_G.StaticPopupDialogs["GBM_CONFIRM_CLEAR_INVENTORY"].OnAccept((_G.LastStaticPopup or {}), (_G.LastStaticPopup or {}).data)
assert.equal(nil, (_G.GBankManagerDB or {}).currentSnapshotId, "confirmed inventory clear should remove the active snapshot pointer")
assert.equal(0, #((((_G.GBankManagerDB or {}).changeLog or {}))), "confirmed inventory clear should remove saved diff history")
mainFrame.optionsClearCompletedRequestsButton:GetScript("OnClick")(mainFrame.optionsClearCompletedRequestsButton)
assert.equal("GBM_CONFIRM_CLEAR_COMPLETED_REQUESTS", (_G.LastStaticPopup or {}).which, "clearing completed request history should require confirmation")
_G.StaticPopupDialogs["GBM_CONFIRM_CLEAR_COMPLETED_REQUESTS"].OnAccept((_G.LastStaticPopup or {}), (_G.LastStaticPopup or {}).data)
for _, request in ipairs((_G.GBankManagerDB or {}).requests or {}) do
    assert.truthy(not (request.approval == "REJECTED" or request.approval == "CANCELED" or (request.approval == "APPROVED" and request.fulfillment == "FULFILLED")), "confirmed request-history clear should remove completed request rows")
end
mainFrame:SetOptionsTab("APPEARANCE")
assert.truthy(type(mainFrame.optionsThemeDefaultButton) == "table", "options appearance should expose a Default theme preset button")
assert.truthy(type(mainFrame.optionsThemeContrastButton) == "table", "options appearance should expose a high-contrast theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).horde) == "table", "options appearance should expose a horde theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).alliance) == "table", "options appearance should expose an alliance theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).generic_wow) == "table", "options appearance should expose a Default theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).legion) == "table", "options appearance should expose a Legion theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).nature) == "table", "options appearance should expose a nature theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).pride) == "table", "options appearance should expose a Pride theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).high_contrast) == "table", "options appearance should expose a High Contrast theme preset button")
assert.truthy(type((mainFrame.optionsThemeButtons or {}).void) == "table", "options appearance should expose a void theme preset button")
assert.equal("Default", mainFrame.optionsThemeDefaultButton.labelText:GetText(), "options appearance should label the default preset as Default")
assert.equal("High Contrast", mainFrame.optionsThemeContrastButton.labelText:GetText(), "options appearance should label the contrast preset as High Contrast")
assert.equal("Nature", ((mainFrame.optionsThemeButtons or {}).nature or {}).labelText:GetText(), "options appearance should label the green preset as Nature")
assert.equal("Legion", ((mainFrame.optionsThemeButtons or {}).legion or {}).labelText:GetText(), "options appearance should label the fel preset as Legion")
assert.equal("Pride", ((mainFrame.optionsThemeButtons or {}).pride or {}).labelText:GetText(), "options appearance should label the pride preset as Pride")
assert.truthy((mainFrame.optionsAppearancePanel:GetHeight() or 0) >= 220, "appearance panel should stay tall enough to keep the minimap toggle and sliders inside the chrome")
assert.truthy((mainFrame.optionsAppearancePanel:GetHeight() or 0) <= 280, "appearance panel should not leave a large empty ghost box below the appearance controls")
assert.truthy(type(mainFrame.optionsShellScaleSlider) == "table", "options appearance should expose a shell scale slider")
assert.truthy(type(mainFrame.optionsShellOpacitySlider) == "table", "options appearance should expose a shell opacity slider")
assert.truthy(type(mainFrame.optionsModalOpacitySlider) == "table", "options appearance should expose a modal opacity slider")
assert.equal("UI Scale", mainFrame.optionsShellScaleLabel:GetText(), "options appearance should rename the scale control to UI Scale")
assert.equal(mainFrame.optionsShellOpacitySlider:GetWidth(), mainFrame.optionsShellScaleSlider:GetWidth(), "UI Scale slider should match the opacity slider width")
assert.same(mainFrame.optionsAppearancePanel, (mainFrame.optionsShellScaleLabel.points[1] or {})[2], "UI Scale should now anchor in the right-hand control column")
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
assert.truthy(type(mainFrame.optionsMinimapToggle) == "table", "options appearance should expose a minimap-button toggle")
assert.equal("Show Minimap Button", mainFrame.optionsMinimapToggle.labelText:GetText(), "options appearance should label the minimap toggle clearly")
assert.truthy(mainFrame.optionsMinimapToggle:GetChecked() == true, "options appearance should enable the minimap toggle by default")
assert.same((mainFrame.optionsThemeButtons or {}).pride, (mainFrame.optionsMinimapToggle.points[1] or {})[2], "minimap toggle should now sit below the last visible theme row")
assert.same(mainFrame.optionsAppearancePanel, (mainFrame.optionsShellScaleLabel.points[1] or {})[2], "UI Scale should now anchor in the right-hand appearance column instead of under the theme buttons")
assert.same(mainFrame.optionsShellScaleValueText, (mainFrame.optionsShellOpacityLabel.points[1] or {})[2], "shell opacity should now stack beneath UI Scale in the right-hand column")
assert.truthy((mainFrame.optionsLogsHistoryTitle.points[1] or {})[5] == -16, "data panel title should keep the shared top inset")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Guild Info", 1, true) ~= nil, "options auth should explain that the policy string lives in Guild Info")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Copy", 1, true) ~= nil, "options auth should explain that publishing to Guild Info is now a manual copy step")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "Accept", 1, true) ~= nil, "options auth should explain that the Guild Information dialog must be accepted after pasting")
assert.truthy(string.find(mainFrame.optionsPolicyStringHelpText:GetText() or "", "1.", 1, true) ~= nil, "options auth should format the policy-string guidance as ordered steps")
assert.equal("Select All", mainFrame.optionsPolicyStringSelectAllButton.labelText:GetText(), "options auth should expose a select-all button for the compact policy string")
assert.truthy(string.find(mainFrame.optionsAuthHint:GetText() or "", "Character-Server", 1, true) ~= nil, "options auth should explicitly document Character-Server blacklist formatting")
assert.truthy((mainFrame.optionsAuthHint:GetWidth() or 0) <= 620, "guild permissions intro copy should wrap inside the permissions panel")
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
assert.truthy(string.find(mainFrame.optionsBlacklistInstructionText:GetText() or "", "1.", 1, true) ~= nil, "options blacklist should format the officer-note instructions as a short ordered list")
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
assert.truthy(color_distance(((mainFrame.optionsBlacklistRefreshButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.optionsBlacklistPanel.gbmArt or {}).innerFill or {}).color) >= 0.10, "options blacklist refresh should contrast from the blacklist panel")
assert.equal("TOPLEFT", select(1, mainFrame.optionsBlacklistRefreshButton:GetPoint(1)), "options blacklist refresh should anchor below the parsed-member list")
assert.equal(mainFrame.optionsBlacklistListPanel, select(2, mainFrame.optionsBlacklistRefreshButton:GetPoint(1)), "options blacklist refresh should position from the blacklist list panel")
assert.truthy(((mainFrame.optionsBlacklistRefreshButton.points[1] or {})[5] or 0) < 0, "options blacklist refresh should sit beneath the blacklist member box")
assert.truthy(string.find(mainFrame.optionsBlacklistStatusText:GetText() or "", "Parsed", 1, true) ~= nil, "options blacklist should summarize how many tagged guild members were parsed")
assert.truthy((mainFrame.optionsBlacklistPanel:GetHeight() or 0) >= ((mainFrame.optionsBlacklistListPanel:GetHeight() or 0) + 180), "options blacklist should leave a little more bottom padding below the parsed summary text")

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
local originalDashboardCardWidth = ((mainFrame.dashboardCards or {})[1] or {}):GetWidth() or 0
local originalDashboardCardHeight = ((mainFrame.dashboardCards or {})[1] or {}):GetHeight() or 0
local originalDashboardPanelHeight = (mainFrame.dashboardTopItemsPanel and mainFrame.dashboardTopItemsPanel:GetHeight()) or 0
mainFrame:SetThemePreset("horde")
assert.equal("horde", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should persist in local appearance settings")
assert.truthy((mainFrame.sidebar.backdropColor or {})[1] ~= 0.10, "theme preset changes should update visible shell colors")
mainFrame:SetThemePreset("nature")
assert.equal("nature", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should support the expanded preset list")
mainFrame:SetThemePreset("legion")
assert.equal("legion", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should support the Legion preset")
mainFrame:SetThemePreset("pride")
assert.equal("pride", _G.GBankManagerDB.ui.appearance.themePreset, "theme preset changes should support the Pride preset")
mainFrame:SetShellScale(1.1)
assert.truthy(mainFrame:GetWidth() > originalWidth, "shell scale should grow the main shell width")
assert.equal(1.1, _G.GBankManagerDB.ui.appearance.shellScale, "shell scale changes should persist in local appearance settings")
assert.equal(1.1, _G.GBankManagerDB.ui.appearance.tableDensity, "shell scale should keep persisted table density linked to the same scale")
assert.equal("110%", mainFrame.optionsShellScaleValueText:GetText(), "shell scale changes should refresh the visible percentage label")
mainFrame:SetShellScale(1.15)
assert.truthy(mainFrame.tableRowHeight > originalRowHeight, "UI Scale should still grow shared table row height through the linked table-density behavior")
assert.truthy((((mainFrame.dashboardCards or {})[1] or {}):GetWidth() or 0) > originalDashboardCardWidth, "UI Scale should also grow dashboard card width")
assert.truthy((((mainFrame.dashboardCards or {})[1] or {}):GetHeight() or 0) > originalDashboardCardHeight, "UI Scale should also grow dashboard card height")
assert.truthy((mainFrame.dashboardTopItemsPanel and mainFrame.dashboardTopItemsPanel:GetHeight() or 0) > originalDashboardPanelHeight, "UI Scale should resize dashboard support panels with the same shell scale pass")
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
mainFrame.optionsMinimapToggle:SetChecked(false)
mainFrame.optionsMinimapToggle:GetScript("OnClick")(mainFrame.optionsMinimapToggle)
assert.equal(false, _G.GBankManagerDB.ui.appearance.showMinimapButton, "appearance minimap toggle should persist the hidden state")
mainFrame.optionsMinimapToggle:SetChecked(true)
mainFrame.optionsMinimapToggle:GetScript("OnClick")(mainFrame.optionsMinimapToggle)
assert.equal(true, _G.GBankManagerDB.ui.appearance.showMinimapButton, "appearance minimap toggle should persist the shown state")

mainFrame:SaveAuthPolicy()
assert.truthy(string.find(mainFrame.optionsAuthStatusText:GetText() or "", "Copy the policy string", 1, true) ~= nil, "options auth save should remind the user to copy the policy string into Guild Information manually")
assert.equal("AUTH_POLICY_UPDATED", ((_G.GBankManagerDB.auditLog or {})[1] or {}).type, "options auth save should append an auth-policy history entry")
assert.truthy(string.find(mainFrame.optionsPolicyStringInput:GetText() or "", "#", 1, true) ~= nil, "options auth save should persist the compact updater hash into the visible policy string")

local authPolicySource = env.ns.modules.authPolicySource
local pullCalled
local originalPullPolicyFromGuildInfo = authPolicySource.PullPolicyFromGuildInfo
authPolicySource.PullPolicyFromGuildInfo = function(db, options)
    pullCalled = options and options.force == true
    db.auth.guildPolicyString = "[GBMAUTH:3;Z;Y;#HASH;0;7N;U;3;-]"
    db.auth.guildPolicySource = "guild_info"
    db.auth.updatedAt = 123
    db.auth.updatedBy = "Stormrage-GuildLead"
    db.auth.capabilities.request_submit[0] = true
    db.ui.minimumSettings.defaultQuantity = 275
    db.ui.minimumSettings.criticalThresholdPercent = 30
    return true, "applied", db.auth
end

mainFrame:RefreshAuthPolicyFromGuildInfo()
assert.truthy(pullCalled == true, "options auth refresh should force a fresh pull from Guild Info")
assert.equal("[GBMAUTH:3;Z;Y;#HASH;0;7N;U;3;-]", mainFrame.optionsPolicyStringInput:GetText(), "options auth refresh should reload the current Guild Info snippet into the visible policy string")
assert.equal("Reloaded auth policy from Guild Info.", mainFrame.optionsAuthStatusText:GetText(), "options auth refresh should report a successful Guild Info reload")
assert.equal("275", mainFrame.defaultMinimumInput:GetText(), "options auth refresh should also preload the shared restock default from Guild Info")
assert.equal("30", mainFrame.optionsCriticalThresholdInput:GetText(), "options auth refresh should also preload the shared critical shortage threshold from Guild Info")
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
mainFrame.optionsTabButtons[3]:GetScript("OnClick")(mainFrame.optionsTabButtons[3])
assert.equal("PERMISSIONS", mainFrame.optionsActiveTab, "options should switch to the Permissions tab when clicked")
assert.truthy(mainFrame.optionsPermissionsPanel:IsShown(), "options should show the Permissions panel after tab switch")
assert.truthy(not mainFrame.optionsAppearancePanel:IsShown(), "options should hide the Appearance panel after switching away")
mainFrame.optionsTabButtons[4]:GetScript("OnClick")(mainFrame.optionsTabButtons[4])
assert.equal("BLACKLIST", mainFrame.optionsActiveTab, "options should switch to the Blacklist tab when clicked")
assert.truthy(mainFrame.optionsBlacklistPanel:IsShown(), "options should show the Blacklist panel after tab switch")
assert.truthy(not mainFrame.optionsPermissionsPanel:IsShown(), "options should hide the Permissions panel after switching away")
mainFrame.optionsTabButtons[5]:GetScript("OnClick")(mainFrame.optionsTabButtons[5])
assert.equal("LOGS_HISTORY", mainFrame.optionsActiveTab, "options should switch to the Data tab when clicked")
assert.truthy(mainFrame.optionsLogsHistoryPanel:IsShown(), "options should show the Data panel after tab switch")
authPolicySource.PullPolicyFromGuildInfo = originalPullPolicyFromGuildInfo
