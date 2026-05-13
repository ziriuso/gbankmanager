local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}
local mainTableController = ns.modules.mainTableController or {}
local mainRequestsController = ns.modules.mainRequestsController or {}
local mainExportsController = ns.modules.mainExportsController or {}
local mainMinimumsController = ns.modules.mainMinimumsController or {}
local mainFrame = mainFrameShell.EnsureShell and mainFrameShell.EnsureShell(ns.modules.mainFrame) or ns.modules.mainFrame
local theme = mainFrameShell.GetTheme and mainFrameShell.GetTheme() or (ns.ui.theme or {})
local apply_panel_style = mainFrameShell.ApplyPanelStyle
local make_label = mainFrameShell.MakeLabel
local make_button = mainFrameShell.MakeButton
local set_button_icon = mainFrameShell.SetButtonIcon
local make_input = mainFrameShell.MakeInput
local make_slim_scroll_bar = mainFrameShell.MakeSlimScrollBar
local create_page_overflow_viewport = mainFrameShell.CreatePageOverflowViewport
local set_frame_shown = mainFrameShell.SetFrameShown

local function parse_number(value)
    local parsed = tonumber(value)
    if not parsed then
        return nil
    end

    return math.floor(parsed)
end

local function copy_list(list)
    local output = {}

    for index, value in ipairs(list or {}) do
        output[index] = value
    end

    return output
end

local function clone_table(value)
    if type(value) ~= "table" then
        return value
    end

    local cloned = {}
    for key, child in pairs(value) do
        cloned[key] = clone_table(child)
    end

    return cloned
end

local function clone_export_template(template)
    template = template or {}

    return {
        delimiter = template.delimiter or "|",
        includeHeader = template.includeHeader ~= false,
        fields = (#(template.fields or {}) > 0) and copy_list(template.fields) or { "itemID", "itemName", "totalToBuy" },
    }
end

local function normalize_export_preset_name(presetName)
    if presetName == nil or presetName == "" or presetName == "Spreadsheet" then
        return "CSV"
    end

    return presetName
end

local function normalize_shopping_list_name(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return "GBankManager"
    end

    return value
end

local function title_case_words(value)
    local words = {}
    for part in tostring(value or ""):gmatch("[^_]+") do
        words[#words + 1] = part:gsub("^%l", string.upper)
    end

    return table.concat(words, " ")
end

local function capability_label(capability)
    if capability == "full_ui" then
        return "Full UI"
    end

    if capability == "auth_manage" then
        return "Auth Manage"
    end

    return title_case_words(capability)
end

local function make_export_output_input(parent, width, height)
    local input = make_input(parent, width, height)
    input.lastCopiedText = nil
    input.highlightStart = nil
    input.highlightEnd = nil
    input.multiLine = true

    if type(input.SetMultiLine) == "function" then
        input:SetMultiLine(true)
    else
        function input:SetMultiLine(value)
            self.multiLine = value and true or false
        end
    end

    function input:HighlightText(startIndex, endIndex)
        self.highlightStart = startIndex
        self.highlightEnd = endIndex
    end

    function input:SetFocus()
        self.hasFocus = true
    end

    return input
end

local function uses_auctionator_controls(presetName)
    return normalize_export_preset_name(presetName) == "Auctionator"
end

local function uses_custom_export_controls(presetName)
    return normalize_export_preset_name(presetName) == "Custom"
end

local function count_lines(text)
    local lineCount = 1
    text = tostring(text or "")

    for _ in string.gmatch(text, "\n") do
        lineCount = lineCount + 1
    end

    return lineCount
end

local function format_timestamp(timestamp)
    if not timestamp or timestamp == 0 then
        return "No scan yet"
    end

    local formatter = _G.date or os.date
    if type(formatter) == "function" then
        return formatter("%Y-%m-%d %H:%M", timestamp)
    end

    return tostring(timestamp)
end

local function display_character_key(characterKey)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.DisplayCharacterKey) == "function" then
        return auth.DisplayCharacterKey(characterKey)
    end

    return tostring(characterKey or "")
end

local function auth_metadata_text(policy)
    policy = policy or {}
    local updatedAt = format_timestamp(policy.updatedAt)
    local updatedBy = display_character_key(policy.updatedBy)
    if updatedBy == "" then
        updatedBy = "Unknown"
    end

    return string.format("Last Update: %s by %s", tostring(updatedAt), tostring(updatedBy))
end

local function build_about_stamp()
    local timestampProvider = _G.time or os.time
    local formatter = _G.date or os.date
    local buildTimestamp = type(timestampProvider) == "function" and timestampProvider() or 0

    if type(formatter) == "function" then
        return formatter("%Y-%m-%d-%H%M%S", buildTimestamp)
    end

    return tostring(buildTimestamp)
end

local ABOUT_BUILD_STAMP = build_about_stamp()

local function apply_table_row_style(rowFrame, rowIndex, isSelected)
    if not rowFrame then
        return
    end

    if isSelected then
        apply_panel_style(rowFrame, theme.colors.accent)
    else
        apply_panel_style(rowFrame, rowIndex % 2 == 1 and theme.colors.panel or theme.colors.panelAlt)
    end

    rowFrame.isSelected = isSelected and true or false
end

local function label_with_sort_marker(columnLayout, sortState)
    local label = (columnLayout and columnLayout.label) or ""
    if not columnLayout or columnLayout.sortable ~= true then
        return label
    end

    if not sortState or sortState.key ~= columnLayout.key then
        return label
    end

    if sortState.direction == "desc" then
        return label .. " v"
    end

    return label .. " ^"
end

local function current_db()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    local runtime = _G.GBankManagerDB or ns.state.db or {}
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function current_auth_context(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetLivePlayerContext) == "function" then
        return auth.GetLivePlayerContext(db)
    end

    return {}
end

local function current_policy(db)
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetAuthPolicy) == "function" then
        return store.GetAuthPolicy(db)
    end

    return (db or {}).auth or {}
end

local function can_access(context, capability, policy)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.Can) == "function" then
        return auth.Can(context, capability, policy)
    end

    return true
end

local function actor_summary_text(context)
    local name = tostring((context or {}).name or "Unknown")
    local rankName = tostring((context or {}).guildRankName or "")
    if rankName ~= "" then
        return string.format("%s (%s)", name, rankName)
    end

    return name
end

local function current_access_profile(db)
    local auth = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = current_policy(db)
    if auth and type(auth.GetEffectiveAccessProfile) == "function" then
        return auth.GetEffectiveAccessProfile(context, policy), context
    end

    return "full_shell", context
end

local function request_only_layout(mainFrame)
    return mainFrame.requestOnlyMode == true and mainFrame.activeView == "REQUESTS"
end

mainFrame.collapsedSidebar = mainFrame.collapsedSidebar and true or false

local function set_alpha(nextAlpha)
    mainFrame.currentAlpha = math.max(0.55, math.min(1.0, nextAlpha))
    mainFrame:SetAlpha(mainFrame.currentAlpha)
end

local function view_label_for(key)
    for _, item in ipairs(mainFrame.navItems or {}) do
        if item.key == key then
            return item.label
        end
    end

    local normalized = string.lower(tostring(key or "Dashboard"))
    return normalized:gsub("^%l", string.upper)
end

mainFrame.viewTitle = mainFrame.viewTitle or make_label(mainFrame.content, "Dashboard", "GameFontNormal")
mainFrame.viewTitle:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 24, -24)
mainFrame.viewSubtitle = mainFrame.viewSubtitle or make_label(mainFrame.content, "Critical shortages, pending requests, and export readiness.", "GameFontHighlightSmall")
mainFrame.viewSubtitle:SetPoint("TOPLEFT", mainFrame.viewTitle, "BOTTOMLEFT", 0, -8)
mainFrame.tableViewportWidth = 730
mainFrame.tableViewportInnerWidth = 730
mainFrame.tableHeaderHeight = 34
mainFrame.tableFilterHeight = 28
mainFrame.tableRowHeight = 26
mainFrame.defaultTableViewportHeight = 364
mainFrame.tableViewportHeight = 364
mainFrame.tableVisibleCount = math.floor(mainFrame.tableViewportHeight / mainFrame.tableRowHeight)
mainFrame.selectedRequestId = mainFrame.selectedRequestId or nil
mainFrame.selectedMinimumKey = mainFrame.selectedMinimumKey or nil
mainFrame.selectedMinimumEnabled = mainFrame.selectedMinimumEnabled or false
mainFrame.minimumShowAllRows = mainFrame.minimumShowAllRows or false
mainFrame.minimumManualOnlyRows = mainFrame.minimumManualOnlyRows or false
mainFrame.exportSelectedPreset = normalize_export_preset_name(mainFrame.exportSelectedPreset)
mainFrame.exportCustomTemplate = mainFrame.exportCustomTemplate or clone_export_template()
mainFrame.exportShoppingListName = normalize_shopping_list_name(mainFrame.exportShoppingListName)

mainFrame.dashboardCards = mainFrame.dashboardCards or {}
for index = 1, 4 do
    local card = mainFrame.dashboardCards[index] or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    card:SetSize(index < 4 and 220 or 456, index < 4 and 110 or 170)
    apply_panel_style(card, theme.colors.panel)

    card.titleText = card.titleText or make_label(card, "", "GameFontHighlight")
    card.titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)
    card.valueText = card.valueText or make_label(card, "", "GameFontNormal")
    card.valueText:SetPoint("TOPLEFT", card.titleText, "BOTTOMLEFT", 0, -10)
    card.noteText = card.noteText or make_label(card, "", "GameFontHighlightSmall")
    card.noteText:SetPoint("TOPLEFT", card.valueText, "BOTTOMLEFT", 0, -8)
    card.linesText = card.linesText or make_label(card, "", "GameFontNormal")
    card.linesText:SetPoint("TOPLEFT", card.titleText, "BOTTOMLEFT", 0, -10)

    mainFrame.dashboardCards[index] = card
end

mainFrame.dashboardCards[1]:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.dashboardCards[2]:SetPoint("LEFT", mainFrame.dashboardCards[1], "RIGHT", 16, 0)
mainFrame.dashboardCards[3]:SetPoint("LEFT", mainFrame.dashboardCards[2], "RIGHT", 16, 0)
mainFrame.dashboardCards[4]:SetPoint("TOPLEFT", mainFrame.dashboardCards[1], "BOTTOMLEFT", 0, -16)

mainTableController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    makeSlimScrollBar = make_slim_scroll_bar,
    createTableOverflowViewport = mainFrameShell.CreateTableOverflowViewport,
    attachScrollBehavior = mainFrameShell.AttachScrollBehavior,
    theme = theme,
    labelWithSortMarker = label_with_sort_marker,
    applyTableRowStyle = apply_table_row_style,
    usesInlineFilters = function(frame)
        return frame.activeView ~= "MINIMUMS"
    end,
    getActiveSortState = function(frame)
        return frame:GetActiveSortState()
    end,
    isSelectedTableRow = function(frame, row)
        return frame:IsSelectedTableRow(row)
    end,
    handleTableRowClick = function(frame, row)
        return frame:HandleTableRowClick(row)
    end,
    syncMinimumInlineRow = function(frame, rowFrame, row, rowIndex)
        return frame:SyncMinimumInlineRow(rowFrame, row, rowIndex)
    end,
    hideMinimumInlineRow = function(frame, rowFrame)
        return frame:HideMinimumInlineRow(rowFrame)
    end,
})

mainRequestsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    theme = theme,
    parseNumber = parse_number,
})

mainExportsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    makeExportOutputInput = make_export_output_input,
    theme = theme,
    setFrameShown = set_frame_shown,
    normalizeExportPresetName = normalize_export_preset_name,
    normalizeShoppingListName = normalize_shopping_list_name,
    cloneExportTemplate = clone_export_template,
    countLines = count_lines,
    currentDb = current_db,
})

mainMinimumsController.Attach(mainFrame, {
    applyPanelStyle = apply_panel_style,
    makeLabel = make_label,
    makeButton = make_button,
    makeInput = make_input,
    setButtonIcon = set_button_icon,
    parseNumber = parse_number,
    currentDb = current_db,
    applyTableRowStyle = apply_table_row_style,
    theme = theme,
})

mainFrame.contentBodyText = mainFrame.contentBodyText or make_label(mainFrame.content, "", "GameFontNormal")
mainFrame.contentBodyText:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)

mainFrame.minimumEmptyStateText = mainFrame.minimumEmptyStateText or make_label(mainFrame.content, "", "GameFontHighlightSmall")
mainFrame.minimumEmptyStateText:SetPoint("TOPLEFT", mainFrame.tableScrollFrame, "TOPLEFT", 12, -12)
mainFrame.minimumEmptyStateText:Hide()

mainFrame.optionsPanel = mainFrame.optionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.optionsPanel:SetPoint("BOTTOMRIGHT", mainFrame.content, "BOTTOMRIGHT", -24, 0)
apply_panel_style(mainFrame.optionsPanel, theme.colors.panel)
mainFrame.optionsPanel:Hide()

mainFrame.optionsScrollUpButton = nil
mainFrame.optionsScrollDownButton = nil
mainFrame.optionsScrollStatusText = nil
local optionsOverflow = create_page_overflow_viewport and create_page_overflow_viewport(mainFrame.optionsPanel, {
    viewportFrame = mainFrame.optionsViewportFrame,
    scrollFrame = mainFrame.optionsScrollFrame,
    scrollChild = mainFrame.optionsScrollChild,
    scrollBar = mainFrame.optionsScrollBar,
    controllerOptions = {
        wheelStep = 24,
    },
}) or nil
mainFrame.optionsViewportFrame = optionsOverflow and optionsOverflow.viewportFrame or mainFrame.optionsViewportFrame
mainFrame.optionsScrollFrame = optionsOverflow and optionsOverflow.scrollFrame or mainFrame.optionsScrollFrame
mainFrame.optionsScrollChild = optionsOverflow and optionsOverflow.scrollChild or mainFrame.optionsScrollChild
mainFrame.optionsScrollBar = optionsOverflow and optionsOverflow.scrollBar or (mainFrame.optionsScrollBar or make_slim_scroll_bar(mainFrame.optionsPanel, 14))
mainFrame.optionsScrollController = optionsOverflow and optionsOverflow.controller or mainFrame.optionsScrollController

mainFrame.optionsAppearancePanel = mainFrame.optionsAppearancePanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsAppearancePanel:SetPoint("TOPLEFT", mainFrame.optionsScrollChild, "TOPLEFT", 0, 0)
mainFrame.optionsAppearancePanel:SetPoint("TOPRIGHT", mainFrame.optionsScrollChild, "TOPRIGHT", 0, 0)
mainFrame.optionsAppearancePanel:SetHeight(92)
apply_panel_style(mainFrame.optionsAppearancePanel, theme.colors.panelAlt)

mainFrame.optionsRestockPanel = mainFrame.optionsRestockPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsRestockPanel:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "BOTTOMLEFT", 0, -16)
mainFrame.optionsRestockPanel:SetPoint("TOPRIGHT", mainFrame.optionsAppearancePanel, "BOTTOMRIGHT", 0, -16)
mainFrame.optionsRestockPanel:SetHeight(96)
apply_panel_style(mainFrame.optionsRestockPanel, theme.colors.panelAlt)

mainFrame.optionsAuthPanel = mainFrame.optionsAuthPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsScrollChild, "BackdropTemplate")
mainFrame.optionsAuthPanel:SetPoint("TOPLEFT", mainFrame.optionsRestockPanel, "BOTTOMLEFT", 0, -16)
mainFrame.optionsAuthPanel:SetPoint("TOPRIGHT", mainFrame.optionsRestockPanel, "BOTTOMRIGHT", 0, -16)
mainFrame.optionsAuthPanel:SetHeight(560)
apply_panel_style(mainFrame.optionsAuthPanel, theme.colors.panelAlt)

mainFrame.optionsTitle = mainFrame.optionsTitle or make_label(mainFrame.optionsAppearancePanel, "Window Transparency", "GameFontHighlight")
mainFrame.optionsTitle:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "TOPLEFT", 16, -16)

mainFrame.optionsHint = mainFrame.optionsHint or make_label(mainFrame.optionsAppearancePanel, "Adjust shell opacity with simple buttons and keep the percentage visible.", "GameFontHighlightSmall")
mainFrame.optionsHint:SetPoint("TOPLEFT", mainFrame.optionsTitle, "BOTTOMLEFT", 0, -8)

if mainFrame.transparencySlider then
    mainFrame.transparencySlider:Hide()
end
mainFrame.transparencySlider = nil

mainFrame.transparencyDecreaseButton = mainFrame.transparencyDecreaseButton or make_button(mainFrame.optionsAppearancePanel, 32, 24, "-")
mainFrame.transparencyDecreaseButton:SetPoint("TOPLEFT", mainFrame.optionsHint, "BOTTOMLEFT", 0, -16)

mainFrame.transparencyIncreaseButton = mainFrame.transparencyIncreaseButton or make_button(mainFrame.optionsAppearancePanel, 32, 24, "+")
mainFrame.transparencyIncreaseButton:SetPoint("LEFT", mainFrame.transparencyDecreaseButton, "RIGHT", 92, 0)

mainFrame.transparencyValueText = mainFrame.transparencyValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.transparencyValueText:SetPoint("LEFT", mainFrame.transparencyDecreaseButton, "RIGHT", 14, 0)

mainFrame.optionsRestockTitle = mainFrame.optionsRestockTitle or make_label(mainFrame.optionsRestockPanel, "Restock Default", "GameFontHighlight")
mainFrame.optionsRestockTitle:SetPoint("TOPLEFT", mainFrame.optionsRestockPanel, "TOPLEFT", 16, -16)

mainFrame.optionsRestockHint = mainFrame.optionsRestockHint or make_label(mainFrame.optionsRestockPanel, "Save Min stores the maximum amount allowed for restock when new rows are staged.", "GameFontHighlightSmall")
mainFrame.optionsRestockHint:SetPoint("TOPLEFT", mainFrame.optionsRestockTitle, "BOTTOMLEFT", 0, -8)

mainFrame.defaultMinimumInput = mainFrame.defaultMinimumInput or make_input(mainFrame.optionsRestockPanel, 72, 22)
mainFrame.defaultMinimumInput:SetPoint("TOPLEFT", mainFrame.optionsRestockHint, "BOTTOMLEFT", 0, -16)

mainFrame.defaultMinimumSaveButton = mainFrame.defaultMinimumSaveButton or make_button(mainFrame.optionsRestockPanel, 86, 28, "Save Min")
mainFrame.defaultMinimumSaveButton:SetPoint("LEFT", mainFrame.defaultMinimumInput, "RIGHT", 8, 0)

mainFrame.optionsAuthTitle = mainFrame.optionsAuthTitle or make_label(mainFrame.optionsAuthPanel, "Guild Permissions", "GameFontHighlight")
mainFrame.optionsAuthTitle:SetPoint("TOPLEFT", mainFrame.optionsAuthPanel, "TOPLEFT", 16, -16)

mainFrame.optionsAuthHint = mainFrame.optionsAuthHint or make_label(mainFrame.optionsAuthPanel, "Configure rank-based access, request submission, and blacklist entries.", "GameFontHighlightSmall")
mainFrame.optionsAuthHint:SetPoint("TOPLEFT", mainFrame.optionsAuthTitle, "BOTTOMLEFT", 0, -8)

mainFrame.optionsAuthMetadataText = mainFrame.optionsAuthMetadataText or make_label(mainFrame.optionsAuthPanel, "", "GameFontHighlightSmall")
mainFrame.optionsAuthMetadataText:SetPoint("TOPLEFT", mainFrame.optionsAuthHint, "BOTTOMLEFT", 0, -8)

mainFrame.optionsAccessPreviewText = mainFrame.optionsAccessPreviewText or make_label(mainFrame.optionsAuthPanel, "", "GameFontNormal")
mainFrame.optionsAccessPreviewText:SetPoint("TOPLEFT", mainFrame.optionsAuthMetadataText, "BOTTOMLEFT", 0, -10)

mainFrame.optionsRankPickerLabel = mainFrame.optionsRankPickerLabel or make_label(mainFrame.optionsAuthPanel, "Selected Rank", "GameFontHighlightSmall")
mainFrame.optionsRankPickerLabel:SetPoint("TOPLEFT", mainFrame.optionsAccessPreviewText, "BOTTOMLEFT", 0, -12)

mainFrame.optionsAuthRankButton = mainFrame.optionsAuthRankButton or make_button(mainFrame.optionsAuthPanel, 180, 24, "")
mainFrame.optionsAuthRankButton:SetPoint("TOPLEFT", mainFrame.optionsRankPickerLabel, "BOTTOMLEFT", 0, -6)

mainFrame.optionsAuthRankDropdown = mainFrame.optionsAuthRankDropdown or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAuthRankDropdown:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -4)
mainFrame.optionsAuthRankDropdown:SetSize(196, 88)
apply_panel_style(mainFrame.optionsAuthRankDropdown, theme.colors.panel)
if type(mainFrame.optionsAuthRankDropdown.SetBackdropColor) == "function" then
    mainFrame.optionsAuthRankDropdown:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
end
if type(mainFrame.optionsAuthRankDropdown.SetFrameStrata) == "function" then
    mainFrame.optionsAuthRankDropdown:SetFrameStrata("DIALOG")
end
if type(mainFrame.optionsAuthRankDropdown.SetFrameLevel) == "function" then
    mainFrame.optionsAuthRankDropdown:SetFrameLevel(30)
end
mainFrame.optionsAuthRankDropdown:Hide()

mainFrame.optionsAuthRankDropdownBackdrop = mainFrame.optionsAuthRankDropdownBackdrop or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthRankDropdown, "BackdropTemplate")
mainFrame.optionsAuthRankDropdownBackdrop:SetPoint("TOPLEFT", mainFrame.optionsAuthRankDropdown, "TOPLEFT", 0, 0)
mainFrame.optionsAuthRankDropdownBackdrop:SetPoint("BOTTOMRIGHT", mainFrame.optionsAuthRankDropdown, "BOTTOMRIGHT", 0, 0)
apply_panel_style(mainFrame.optionsAuthRankDropdownBackdrop, theme.colors.background)
if type(mainFrame.optionsAuthRankDropdownBackdrop.SetBackdropColor) == "function" then
    mainFrame.optionsAuthRankDropdownBackdrop:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
end

mainFrame.optionsAuthRankButtons = mainFrame.optionsAuthRankButtons or {}
for index = 1, 8 do
    local button = mainFrame.optionsAuthRankButtons[index] or make_button(mainFrame.optionsAuthRankDropdown, 180, 20, "")
    button:SetPoint("TOPLEFT", mainFrame.optionsAuthRankDropdown, "TOPLEFT", 6, -6 - ((index - 1) * 22))
    mainFrame.optionsAuthRankButtons[index] = button
end

mainFrame.optionsAllowedPermissionTitle = mainFrame.optionsAllowedPermissionTitle or make_label(mainFrame.optionsAuthPanel, "Allowed Permissions", "GameFontHighlight")
mainFrame.optionsAllowedPermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAuthRankButton, "BOTTOMLEFT", 0, -18)

mainFrame.optionsAllowedPermissionPanel = mainFrame.optionsAllowedPermissionPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAllowedPermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionTitle, "BOTTOMLEFT", 0, -6)
mainFrame.optionsAllowedPermissionPanel:SetSize(250, 138)
apply_panel_style(mainFrame.optionsAllowedPermissionPanel, theme.colors.panel)

mainFrame.optionsAvailablePermissionTitle = mainFrame.optionsAvailablePermissionTitle or make_label(mainFrame.optionsAuthPanel, "Available Permissions", "GameFontHighlight")
mainFrame.optionsAvailablePermissionTitle:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 126, 6)

mainFrame.optionsAvailablePermissionPanel = mainFrame.optionsAvailablePermissionPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsAvailablePermissionPanel:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionTitle, "BOTTOMLEFT", 0, -6)
mainFrame.optionsAvailablePermissionPanel:SetSize(250, 138)
apply_panel_style(mainFrame.optionsAvailablePermissionPanel, theme.colors.panel)

mainFrame.optionsAuthRemovePermissionButton = mainFrame.optionsAuthRemovePermissionButton or make_button(mainFrame.optionsAuthPanel, 92, 24, "<< Remove")
mainFrame.optionsAuthRemovePermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPRIGHT", 16, -36)

mainFrame.optionsAuthAddPermissionButton = mainFrame.optionsAuthAddPermissionButton or make_button(mainFrame.optionsAuthPanel, 92, 24, "Add >>")
mainFrame.optionsAuthAddPermissionButton:SetPoint("TOPLEFT", mainFrame.optionsAuthRemovePermissionButton, "BOTTOMLEFT", 0, -10)

mainFrame.optionsAllowedPermissionButtons = mainFrame.optionsAllowedPermissionButtons or {}
mainFrame.optionsAvailablePermissionButtons = mainFrame.optionsAvailablePermissionButtons or {}
for index = 1, 11 do
    local allowedButton = mainFrame.optionsAllowedPermissionButtons[index] or make_button(mainFrame.optionsAllowedPermissionPanel, 114, 18, "")
    allowedButton:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "TOPLEFT", 8, -8 - ((index - 1) * 20))
    mainFrame.optionsAllowedPermissionButtons[index] = allowedButton

    local availableButton = mainFrame.optionsAvailablePermissionButtons[index] or make_button(mainFrame.optionsAvailablePermissionPanel, 114, 18, "")
    availableButton:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionPanel, "TOPLEFT", 8, -8 - ((index - 1) * 20))
    mainFrame.optionsAvailablePermissionButtons[index] = availableButton
end

mainFrame.optionsBlacklistTitle = mainFrame.optionsBlacklistTitle or make_label(mainFrame.optionsAuthPanel, "Blacklist", "GameFontHighlight")
mainFrame.optionsBlacklistTitle:SetPoint("TOPLEFT", mainFrame.optionsAvailablePermissionPanel, "BOTTOMLEFT", 0, -18)

mainFrame.optionsBlacklistCharacterLabel = mainFrame.optionsBlacklistCharacterLabel or make_label(mainFrame.optionsAuthPanel, "Character", "GameFontHighlightSmall")
mainFrame.optionsBlacklistCharacterLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistTitle, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistNameInput = mainFrame.optionsBlacklistNameInput or make_input(mainFrame.optionsAuthPanel, 220, 22)
mainFrame.optionsBlacklistNameInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistCharacterLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsBlacklistReasonLabel = mainFrame.optionsBlacklistReasonLabel or make_label(mainFrame.optionsAuthPanel, "Reason", "GameFontHighlightSmall")
mainFrame.optionsBlacklistReasonLabel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistNameInput, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistReasonInput = mainFrame.optionsBlacklistReasonInput or make_input(mainFrame.optionsAuthPanel, 220, 22)
mainFrame.optionsBlacklistReasonInput:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsBlacklistAddButton = mainFrame.optionsBlacklistAddButton or make_button(mainFrame.optionsAuthPanel, 96, 24, "Add / Update")
mainFrame.optionsBlacklistAddButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistReasonInput, "BOTTOMLEFT", 0, -10)

mainFrame.optionsBlacklistRemoveButton = mainFrame.optionsBlacklistRemoveButton or make_button(mainFrame.optionsAuthPanel, 74, 24, "Remove")
mainFrame.optionsBlacklistRemoveButton:SetPoint("LEFT", mainFrame.optionsBlacklistAddButton, "RIGHT", 8, 0)

mainFrame.optionsBlacklistListTitle = mainFrame.optionsBlacklistListTitle or make_label(mainFrame.optionsAuthPanel, "Blacklisted Entries", "GameFontHighlightSmall")
mainFrame.optionsBlacklistListTitle:SetPoint("TOPLEFT", mainFrame.optionsBlacklistAddButton, "BOTTOMLEFT", 0, -12)

mainFrame.optionsBlacklistListPanel = mainFrame.optionsBlacklistListPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsAuthPanel, "BackdropTemplate")
mainFrame.optionsBlacklistListPanel:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListTitle, "BOTTOMLEFT", 0, -4)
mainFrame.optionsBlacklistListPanel:SetSize(324, 74)
apply_panel_style(mainFrame.optionsBlacklistListPanel, theme.colors.panel)

mainFrame.optionsBlacklistButtons = mainFrame.optionsBlacklistButtons or {}
for index = 1, 3 do
    local button = mainFrame.optionsBlacklistButtons[index] or make_button(mainFrame.optionsBlacklistListPanel, 308, 18, "")
    button:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListPanel, "TOPLEFT", 8, -8 - ((index - 1) * 22))
    mainFrame.optionsBlacklistButtons[index] = button
end

mainFrame.optionsPolicyStringLabel = mainFrame.optionsPolicyStringLabel or make_label(mainFrame.optionsAuthPanel, "Policy String", "GameFontHighlightSmall")
mainFrame.optionsPolicyStringLabel:SetPoint("TOPLEFT", mainFrame.optionsAllowedPermissionPanel, "BOTTOMLEFT", 0, -18)

mainFrame.optionsPolicyStringInput = mainFrame.optionsPolicyStringInput or make_input(mainFrame.optionsAuthPanel, 250, 22)
mainFrame.optionsPolicyStringInput:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringLabel, "BOTTOMLEFT", 0, -4)

mainFrame.optionsAuthStatusText = mainFrame.optionsAuthStatusText or make_label(mainFrame.optionsAuthPanel, "", "GameFontHighlightSmall")
mainFrame.optionsAuthStatusText:SetPoint("TOPLEFT", mainFrame.optionsPolicyStringInput, "BOTTOMLEFT", 0, -8)

mainFrame.optionsAuthSaveButton = mainFrame.optionsAuthSaveButton or make_button(mainFrame.optionsAuthPanel, 88, 24, "Save")
mainFrame.optionsAuthSaveButton:SetPoint("TOPLEFT", mainFrame.optionsBlacklistListPanel, "BOTTOMLEFT", 236, -16)

mainFrame.optionsAuthWriteButton = mainFrame.optionsAuthWriteButton or make_button(mainFrame.optionsAuthPanel, 112, 24, "Write Guild Info")
mainFrame.optionsAuthWriteButton:SetPoint("RIGHT", mainFrame.optionsAuthSaveButton, "LEFT", -8, 0)

mainFrame.optionsAuthReadButton = mainFrame.optionsAuthReadButton or make_button(mainFrame.optionsAuthPanel, 128, 24, "Refresh Guild Info")
mainFrame.optionsAuthReadButton:SetPoint("RIGHT", mainFrame.optionsAuthWriteButton, "LEFT", -8, 0)

mainFrame.optionsAuthResetButton = mainFrame.optionsAuthResetButton or make_button(mainFrame.optionsAuthPanel, 70, 24, "Revert")
mainFrame.optionsAuthResetButton:SetPoint("RIGHT", mainFrame.optionsAuthReadButton, "LEFT", -8, 0)

local function refresh_alpha_text()
    local percentage = math.floor(mainFrame.currentAlpha * 100 + 0.5)
    mainFrame.transparencyValueText:SetText(string.format("Opacity %d%%", percentage))
end

local function adjust_alpha(delta)
    local currentPercent = math.floor((mainFrame.currentAlpha or 1) * 100 + 0.5)
    local nextPercent = math.max(55, math.min(100, currentPercent + (delta or 0)))
    set_alpha(nextPercent / 100)
    refresh_alpha_text()
end
refresh_alpha_text()

mainFrame.transparencyDecreaseButton:SetScript("OnClick", function()
    adjust_alpha(-1)
end)

mainFrame.transparencyIncreaseButton:SetScript("OnClick", function()
    adjust_alpha(1)
end)

mainFrame.defaultMinimumSaveButton:SetScript("OnClick", function()
    mainFrame:SaveDefaultMinimumSetting()
end)

function mainFrame:ScrollOptionsBy(delta)
    local controller = self.optionsScrollController
    if not controller then
        return 0
    end

    return controller:ScrollBy(delta or 0)
end

function mainFrame:SetOptionsScrollProgress(progress)
    local controller = self.optionsScrollController
    if not controller then
        return 0
    end

    return controller:SetProgress(progress or 0)
end

function mainFrame:UpdateOptionsCanvasHeight()
    local spacing = 16
    local contentHeight = 0
    contentHeight = contentHeight + (self.optionsAppearancePanel and (self.optionsAppearancePanel:GetHeight() or 0) or 0)
    contentHeight = contentHeight + spacing
    contentHeight = contentHeight + (self.optionsRestockPanel and (self.optionsRestockPanel:GetHeight() or 0) or 0)
    contentHeight = contentHeight + spacing
    contentHeight = contentHeight + (self.optionsAuthPanel and (self.optionsAuthPanel:GetHeight() or 0) or 0)
    contentHeight = contentHeight + 16
    if self.optionsScrollChild then
        self.optionsScrollChild:SetWidth(math.max(0, (self.optionsScrollFrame and (self.optionsScrollFrame:GetWidth() or 0) or 0) - 4))
        self.optionsScrollChild:SetHeight(contentHeight)
    end

    if self.optionsScrollFrame then
        self.optionsScrollFrame.verticalScrollRange = math.max(0, contentHeight - (self.optionsScrollFrame:GetHeight() or 0))
        self.optionsScrollFrame.verticalScroll = math.max(0, math.min(self.optionsScrollFrame.verticalScroll or 0, self.optionsScrollFrame.verticalScrollRange))
        self.optionsScrollFrame:SetVerticalScroll(self.optionsScrollFrame.verticalScroll)
    end

    if self.optionsScrollController then
        self.optionsScrollController:Refresh(contentHeight, self.optionsScrollFrame and (self.optionsScrollFrame:GetHeight() or 0) or 0)
    end

    return contentHeight
end

function mainFrame:SyncOptionsScrollVisuals()
    local controller = self.optionsScrollController
    if not controller then
        return
    end

    controller:Refresh()
end

function mainFrame:UpdateOptionsAuthLayout(allowedCount, availableCount)
    local visibleCount = math.max(allowedCount or 0, availableCount or 0)
    local rowCount = math.min(6, math.max(1, visibleCount))
    local permissionPanelHeight = math.max(74, 18 + (rowCount * 20))

    self.optionsAllowedPermissionPanel:SetHeight(permissionPanelHeight)
    self.optionsAvailablePermissionPanel:SetHeight(permissionPanelHeight)
    self.optionsAuthPanel:SetHeight(560 + math.max(0, permissionPanelHeight - 118))
    self:UpdateOptionsCanvasHeight()
end

function mainFrame:GetAuthDraftPolicy(db)
    db = db or current_db()
    local permissions = ns.modules.auth or ns.modules.permissions

    if not self.authDraftPolicy then
        self.authDraftPolicy = clone_table((db or {}).auth or {})
    end

    if permissions and type(permissions.NormalizePolicy) == "function" then
        self.authDraftPolicy = permissions.NormalizePolicy(self.authDraftPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end

    return self.authDraftPolicy
end

function mainFrame:LoadAuthOptionsFromDb(db)
    db = db or current_db()
    self.authDraftPolicy = clone_table((db or {}).auth or {})
    self.authBlacklistSelectedKey = nil
    self.authRankDropdownShown = false
    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self.selectedAuthRankIndex = nil
    self:RefreshAuthOptions()
end

function mainFrame:GetAuthRankList()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(current_db())
    if permissions and type(permissions.GetSortedRankMetadata) == "function" then
        return permissions.GetSortedRankMetadata(policy)
    end

    return {}
end

function mainFrame:GetSelectedAuthRankIndex()
    local ranks = self:GetAuthRankList()
    if self.selectedAuthRankIndex ~= nil then
        return self.selectedAuthRankIndex
    end

    if ranks[1] then
        self.selectedAuthRankIndex = ranks[1].rankIndex
        return self.selectedAuthRankIndex
    end

    return nil
end

function mainFrame:SelectAuthRank(rankIndex)
    self.selectedAuthRankIndex = tonumber(rankIndex)
    self.authRankDropdownShown = false
    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self:RefreshAuthOptions()
    return self.selectedAuthRankIndex
end

function mainFrame:ToggleAuthRankDropdown()
    self.authRankDropdownShown = not self.authRankDropdownShown
    self:RefreshAuthOptions()
end

function mainFrame:SelectAuthCapability(listKind, capability)
    if listKind == "allowed" then
        self.selectedAllowedCapability = capability
        self.selectedAvailableCapability = nil
    else
        self.selectedAvailableCapability = capability
        self.selectedAllowedCapability = nil
    end

    self:RefreshAuthOptions()
end

function mainFrame:MoveSelectedAuthCapability(listKind)
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = self:GetAuthDraftPolicy(db)
    local rankIndex = self:GetSelectedAuthRankIndex()
    local capability = listKind == "allowed" and self.selectedAllowedCapability or self.selectedAvailableCapability

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return false
    end

    if rankIndex == nil or capability == nil or capability == "" then
        self.optionsAuthStatusText:SetText("Select a rank and permission first.")
        return false
    end

    if permissions and type(permissions.SetCapabilityRank) == "function" then
        permissions.SetCapabilityRank(policy, capability, rankIndex, listKind ~= "allowed")
    end

    self.selectedAllowedCapability = nil
    self.selectedAvailableCapability = nil
    self.optionsAuthStatusText:SetText(string.format("Staged %s for %s.", capability_label(capability), listKind == "allowed" and "removal" or "grant"))
    self:RefreshAuthOptions()
    return true
end

function mainFrame:SelectBlacklistEntry(characterKey)
    local policy = self:GetAuthDraftPolicy(current_db())
    self.authBlacklistSelectedKey = characterKey
    local entry = characterKey and (policy.blacklist or {})[characterKey] or nil
    self.optionsBlacklistNameInput:SetText(characterKey or "")
    self.optionsBlacklistReasonInput:SetText(entry and entry.reason or "")
    self:RefreshAuthOptions()
end

function mainFrame:StageBlacklistEntry()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(db)
    local context = current_auth_context(db)
    local rawName = self.optionsBlacklistNameInput:GetText() or ""
    local reason = self.optionsBlacklistReasonInput:GetText() or ""
    local realmName = context.realmName or (type(_G.GetRealmName) == "function" and _G.GetRealmName() or "")
    local characterKey = permissions and type(permissions.NormalizeCharacterKey) == "function" and permissions.NormalizeCharacterKey(rawName, realmName) or rawName

    if characterKey == "" then
        self.optionsAuthStatusText:SetText("Enter a character name or Realm-Character key.")
        return nil
    end

    if context.isGuildMaster and characterKey == context.characterKey then
        self.optionsAuthStatusText:SetText("Guildmaster access cannot be blacklisted.")
        return nil
    end

    if permissions and type(permissions.UpsertBlacklist) == "function" then
        permissions.UpsertBlacklist(policy, characterKey, rawName, reason, _G.time and _G.time() or 0)
    else
        policy.blacklist[characterKey] = {
            name = rawName,
            reason = reason,
            updatedAt = _G.time and _G.time() or 0,
        }
    end

    self.authBlacklistSelectedKey = characterKey
    self.optionsAuthStatusText:SetText(string.format("Staged blacklist entry for %s.", characterKey))
    self:RefreshAuthOptions()
    return characterKey
end

function mainFrame:RemoveSelectedBlacklistEntry()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(db)
    local characterKey = self.authBlacklistSelectedKey or (self.optionsBlacklistNameInput:GetText() or "")

    if characterKey == "" then
        self.optionsAuthStatusText:SetText("Select a blacklist entry first.")
        return nil
    end

    if permissions and type(permissions.RemoveBlacklist) == "function" then
        permissions.RemoveBlacklist(policy, characterKey)
    else
        policy.blacklist[characterKey] = nil
    end

    self.authBlacklistSelectedKey = nil
    self.optionsBlacklistNameInput:SetText("")
    self.optionsBlacklistReasonInput:SetText("")
    self.optionsAuthStatusText:SetText(string.format("Removed blacklist entry for %s.", characterKey))
    self:RefreshAuthOptions()
    return characterKey
end

function mainFrame:ToggleAuthCapabilityRank(capability, rankIndex)
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local context = current_auth_context(db)
    local policy = self:GetAuthDraftPolicy(db)

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return false
    end

    local allowed = false
    if permissions and type(permissions.ToggleCapabilityRank) == "function" then
        allowed = permissions.ToggleCapabilityRank(policy, capability, rankIndex)
    end

    self.optionsAuthStatusText:SetText(string.format("Staged %s for rank %d: %s", capability_label(capability), rankIndex, allowed and "allowed" or "denied"))
    self:RefreshAuthOptions()
    return allowed
end

function mainFrame:SaveAuthPolicy()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local transport = ns.modules.syncTransport
    local authPolicyCodec = ns.modules.authPolicyCodec
    local context = current_auth_context(db)
    local draft = self:GetAuthDraftPolicy(db)

    if not can_access(context, "auth_manage", current_policy(db)) then
        self.optionsAuthStatusText:SetText("You do not have permission to manage auth settings.")
        return nil
    end

    if permissions and type(permissions.NormalizePolicy) == "function" then
        draft = permissions.NormalizePolicy(draft, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end

    if permissions and type(permissions.StampPolicy) == "function" then
        permissions.StampPolicy(draft, context, _G.time and _G.time() or 0)
    end

    if authPolicyCodec and type(authPolicyCodec.EncodePolicy) == "function" then
        draft.guildPolicyString = authPolicyCodec.EncodePolicy(draft)
    end

    db.auth = draft
    self.authDraftPolicy = clone_table(draft)
    self.optionsAuthStatusText:SetText("Saved guild auth policy.")

    if transport and type(transport.Send) == "function" then
        transport.Send("GUILD", "GUILD", {
            type = "AUTH_POLICY_SNAPSHOT",
            updatedAt = draft.updatedAt or (_G.time and _G.time() or 0),
            payload = {
                actorContext = context,
                policy = draft,
            },
        })
    end

    self:RefreshAuthOptions()
    return draft
end

function mainFrame:WriteAuthPolicyToGuildInfo()
    local db = current_db()
    local authPolicyCodec = ns.modules.authPolicyCodec
    if not authPolicyCodec then
        self.optionsAuthStatusText:SetText("Auth policy codec is unavailable.")
        return nil
    end

    local draft = self:SaveAuthPolicy()
    if not draft then
        return nil
    end

    local policyString = draft.guildPolicyString or ""
    self.optionsPolicyStringInput:SetText(policyString)

    if not (authPolicyCodec.CanWriteGuildInfo and authPolicyCodec.CanWriteGuildInfo()) then
        self.optionsAuthStatusText:SetText("Policy saved locally. Copy the policy string into Guild Info manually.")
        return policyString
    end

    local currentText = _G.C_GuildInfo and type(_G.C_GuildInfo.GetInfoText) == "function" and _G.C_GuildInfo.GetInfoText() or ""
    local nextText = type(authPolicyCodec.InjectPolicyString) == "function" and authPolicyCodec.InjectPolicyString(currentText, policyString) or policyString
    if string.len(nextText or "") > 499 then
        self.optionsAuthStatusText:SetText("Guild Info would exceed 499 characters. Reduce blacklist size or manual notes.")
        return nil
    end

    if _G.C_GuildInfo and type(_G.C_GuildInfo.SetInfoText) == "function" then
        _G.C_GuildInfo.SetInfoText(nextText)
        db.auth.guildPolicySource = "guild_info"
        self.optionsAuthStatusText:SetText("Saved auth policy and wrote compact string to Guild Info.")
    end

    self:RefreshAuthOptions()
    return policyString
end

function mainFrame:RefreshAuthPolicyFromGuildInfo()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    if permissions and type(permissions.RefreshPolicyFromGuild) == "function" then
        permissions.RefreshPolicyFromGuild(db)
    end
    self.authDraftPolicy = clone_table(db.auth or {})
    self.optionsAuthStatusText:SetText("Reloaded auth policy from Guild Info and local cache.")
    self:RefreshAuthOptions()
end

function mainFrame:RefreshAuthOptions()
    local db = current_db()
    local permissions = ns.modules.auth or ns.modules.permissions
    local policy = self:GetAuthDraftPolicy(db)
    local ranks = self:GetAuthRankList()
    local context = current_auth_context(db)
    local profile = current_access_profile(db)
    local canManage = can_access(context, "auth_manage", current_policy(db))
    local selectedRankIndex = self:GetSelectedAuthRankIndex()
    local selectedRankName = "Select Rank"

    for _, rank in ipairs(ranks) do
        if rank.rankIndex == selectedRankIndex then
            selectedRankName = rank.name
            break
        end
    end

    self.optionsAccessPreviewText:SetText(string.format("Current Access: %s (%s)", profile, actor_summary_text(context)))
    self.optionsAuthMetadataText:SetText(auth_metadata_text(policy))
    self.optionsAuthRankButton.labelText:SetText(selectedRankName)
    if self.optionsAuthStatusText:GetText() == "" then
        self.optionsAuthStatusText:SetText(canManage and "Guildmaster and delegated auth managers can save policy changes." or "Read-only auth preview. You do not have auth-manage access.")
    end

    local dropdownHeight = math.max(28, (#ranks * 22) + 12)
    self.optionsAuthRankDropdown:SetHeight(dropdownHeight)

    for index, button in ipairs(self.optionsAuthRankButtons or {}) do
        local rank = ranks[index]
        if rank then
            button.labelText:SetText(rank.name)
            button:SetEnabled(true)
            button:Show()
            button:SetScript("OnClick", function()
                self:SelectAuthRank(rank.rankIndex)
            end)
        else
            button:Hide()
        end
    end

    if self.authRankDropdownShown then
        self.optionsAuthRankDropdown:Show()
    else
        self.optionsAuthRankDropdown:Hide()
    end

    local capabilityList = (permissions and permissions.GetCapabilityList and permissions.GetCapabilityList()) or {}
    local allowedCapabilities = {}
    local availableCapabilities = {}
    for _, capability in ipairs(capabilityList) do
        local allowlist = (policy.capabilities[capability] or {})
        if selectedRankIndex ~= nil and allowlist[selectedRankIndex] == true then
            allowedCapabilities[#allowedCapabilities + 1] = capability
        else
            availableCapabilities[#availableCapabilities + 1] = capability
        end
    end

    self:UpdateOptionsAuthLayout(#allowedCapabilities, #availableCapabilities)

    local function bind_permission_buttons(buttons, parentFrame, capabilities, selectedCapability, listKind)
        for index, button in ipairs(buttons or {}) do
            local capability = capabilities[index]
            if capability then
                local rowIndex = ((index - 1) % 6)
                local columnIndex = math.floor((index - 1) / 6)
                if type(button.ClearAllPoints) == "function" then
                    button:ClearAllPoints()
                end
                button:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 8 + (columnIndex * 116), -8 - (rowIndex * 20))
                button:SetSize(110, 18)
                button.labelText:SetText(capability_label(capability))
                button:SetEnabled(true)
                button:Show()
                apply_panel_style(button, selectedCapability == capability and theme.colors.accent or theme.colors.panel)
                button:SetScript("OnClick", function()
                    self:SelectAuthCapability(listKind, capability)
                end)
            else
                button.labelText:SetText("")
                button:Hide()
            end
        end
    end

    bind_permission_buttons(self.optionsAllowedPermissionButtons, self.optionsAllowedPermissionPanel, allowedCapabilities, self.selectedAllowedCapability, "allowed")
    bind_permission_buttons(self.optionsAvailablePermissionButtons, self.optionsAvailablePermissionPanel, availableCapabilities, self.selectedAvailableCapability, "available")

    local blacklistEntries = {}
    for characterKey, entry in pairs(policy.blacklist or {}) do
        blacklistEntries[#blacklistEntries + 1] = {
            characterKey = characterKey,
            name = entry.name or characterKey,
            reason = entry.reason or "",
        }
    end
    table.sort(blacklistEntries, function(left, right)
        return left.characterKey < right.characterKey
    end)

    for index, button in ipairs(self.optionsBlacklistButtons or {}) do
        local entry = blacklistEntries[index]
        if entry then
            button.labelText:SetText(string.format("%s - %s", entry.characterKey, entry.reason ~= "" and entry.reason or "No reason"))
            button:SetEnabled(true)
            button:Show()
            button:SetScript("OnClick", function()
                self:SelectBlacklistEntry(entry.characterKey)
            end)
        else
            button.labelText:SetText("")
            button:Hide()
        end
    end

    self.optionsPolicyStringInput:SetText(policy.guildPolicyString or "")

    self.optionsAuthAddPermissionButton:SetEnabled(canManage and self.selectedAvailableCapability ~= nil and selectedRankIndex ~= nil)
    self.optionsAuthRemovePermissionButton:SetEnabled(canManage and self.selectedAllowedCapability ~= nil and selectedRankIndex ~= nil)
    self.optionsAuthRankButton:SetEnabled(#ranks > 0)
    self.optionsBlacklistAddButton:SetEnabled(canManage)
    self.optionsBlacklistRemoveButton:SetEnabled(canManage and (self.authBlacklistSelectedKey ~= nil))
    self.optionsAuthSaveButton:SetEnabled(canManage)
    self.optionsAuthWriteButton:SetEnabled(canManage)
    self.optionsAuthReadButton:SetEnabled(true)
    self.optionsAuthResetButton:SetEnabled(true)
end

mainFrame.optionsBlacklistAddButton:SetScript("OnClick", function()
    mainFrame:StageBlacklistEntry()
end)

mainFrame.optionsAuthRankButton:SetScript("OnClick", function()
    mainFrame:ToggleAuthRankDropdown()
end)

mainFrame.optionsAuthAddPermissionButton:SetScript("OnClick", function()
    mainFrame:MoveSelectedAuthCapability("available")
end)

mainFrame.optionsAuthRemovePermissionButton:SetScript("OnClick", function()
    mainFrame:MoveSelectedAuthCapability("allowed")
end)

mainFrame.optionsBlacklistRemoveButton:SetScript("OnClick", function()
    mainFrame:RemoveSelectedBlacklistEntry()
end)

mainFrame.optionsAuthSaveButton:SetScript("OnClick", function()
    mainFrame:SaveAuthPolicy()
end)

mainFrame.optionsAuthWriteButton:SetScript("OnClick", function()
    mainFrame:WriteAuthPolicyToGuildInfo()
end)

mainFrame.optionsAuthReadButton:SetScript("OnClick", function()
    mainFrame:RefreshAuthPolicyFromGuildInfo()
end)

mainFrame.optionsAuthResetButton:SetScript("OnClick", function()
    mainFrame.optionsAuthStatusText:SetText("")
    mainFrame:LoadAuthOptionsFromDb(current_db())
end)

mainFrame.closeButton = mainFrame.closeButton or make_button(mainFrame.topBar, 96, 28, "Close")
mainFrame.closeButton:SetPoint("TOPRIGHT", mainFrame.topBar, "TOPRIGHT", -16, -16)
mainFrame.closeButton:SetScript("OnClick", function()
    mainFrame:EnableMouse(false)
    mainFrame:Hide()
end)

mainFrame.sidebarButtons = mainFrame.sidebarButtons or {}
for index, item in ipairs(mainFrame.navItems) do
    local button = mainFrame.sidebarButtons[index] or make_button(mainFrame.sidebar, theme.spacing.sidebarExpanded - 32, 32, item.label)
    button.key = item.key
    button.labelText:SetText(item.label)
    button.labelText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -40 - ((index - 1) * 44))
    apply_panel_style(button, item.key == mainFrame.activeView and theme.colors.panelAlt or theme.colors.panel)
    button:SetScript("OnClick", function(self)
        mainFrame:SelectView(self.key)
    end)
    mainFrame.sidebarButtons[index] = button
end

function mainFrame:ApplyTheme()
    local compactRequestMode = request_only_layout(self)
    local sidebarWidth = self.collapsedSidebar and theme.spacing.sidebarCollapsed or theme.spacing.sidebarExpanded
    self.sidebar:SetWidth(sidebarWidth)
    if type(self.topBar.ClearAllPoints) == "function" then
        self.topBar:ClearAllPoints()
    end
    if type(self.content.ClearAllPoints) == "function" then
        self.content:ClearAllPoints()
    end
    if compactRequestMode then
        self.topBar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        self.topBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
        self.content:SetPoint("TOPLEFT", self.topBar, "BOTTOMLEFT", 0, 0)
        self.content:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    else
        self.topBar:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
        self.topBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
        self.content:SetPoint("TOPLEFT", self.topBar, "BOTTOMLEFT", 0, 0)
        self.content:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
    end
    self.topBar:SetHeight(compactRequestMode and 44 or theme.spacing.topBarHeight)
    apply_panel_style(self, theme.colors.background)
    apply_panel_style(self.sidebar, theme.colors.panel)
    apply_panel_style(self.topBar, theme.colors.panelAlt)
    apply_panel_style(self.content, theme.colors.background)
    apply_panel_style(self.optionsPanel, theme.colors.panel)
    apply_panel_style(self.optionsViewportFrame, theme.colors.background)
    if type(self.optionsScrollBar.SetBackdrop) == "function" then
        self.optionsScrollBar:SetBackdrop(nil)
    end
    if type(self.optionsScrollBar.track.SetBackdrop) == "function" then
        self.optionsScrollBar.track:SetBackdrop(nil)
    end
    if type(self.optionsScrollBar.thumb.SetBackdrop) == "function" then
        self.optionsScrollBar.thumb:SetBackdrop(nil)
    end
    if type(self.optionsScrollFrame.SetBackdrop) == "function" then
        self.optionsScrollFrame:SetBackdrop(nil)
    end
    if type(self.optionsScrollChild.SetBackdrop) == "function" then
        self.optionsScrollChild:SetBackdrop(nil)
    end
    apply_panel_style(self.optionsAppearancePanel, theme.colors.panelAlt)
    apply_panel_style(self.optionsRestockPanel, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthPanel, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthRankDropdown, theme.colors.panel)
    apply_panel_style(self.optionsAuthRankDropdownBackdrop, theme.colors.background)
    if type(self.optionsAuthRankDropdown.SetBackdropColor) == "function" then
        self.optionsAuthRankDropdown:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
    end
    if type(self.optionsAuthRankDropdownBackdrop.SetBackdropColor) == "function" then
        self.optionsAuthRankDropdownBackdrop:SetBackdropColor(0.02, 0.03, 0.05, 1.0)
    end
    apply_panel_style(self.optionsAllowedPermissionPanel, theme.colors.panel)
    apply_panel_style(self.optionsAvailablePermissionPanel, theme.colors.panel)
    apply_panel_style(self.optionsBlacklistListPanel, theme.colors.panel)
    apply_panel_style(self.requestActionsPanel, theme.colors.panel)
    apply_panel_style(self.requestCreatePanel, theme.colors.panel)
    apply_panel_style(self.minimumsPanel, theme.colors.panel)
    apply_panel_style(self.minimumAddModal, theme.colors.panelAlt)
    apply_panel_style(self.exportsPanel, theme.colors.panel)
    apply_panel_style(self.exportModal, theme.colors.panelAlt)
    apply_panel_style(self.exportModalScrollFrame, theme.colors.background)
    apply_panel_style(self.exportModalScrollChild, theme.colors.background)
    apply_panel_style(self.tableHeaderFrame, theme.colors.panel)
    apply_panel_style(self.tableFilterFrame, theme.colors.background)
    apply_panel_style(self.tableViewportFrame, theme.colors.background)
    apply_panel_style(self.tableScrollFrame, theme.colors.background)

    for _, card in ipairs(self.dashboardCards) do
        apply_panel_style(card, theme.colors.panel)
    end

    for _, button in ipairs(self.sidebarButtons) do
        local isActive = button.key == self.activeView
        apply_panel_style(button, isActive and theme.colors.panelAlt or theme.colors.panel)
        button:SetWidth(self.collapsedSidebar and 40 or (theme.spacing.sidebarExpanded - 32))
        button.labelText:SetText(self.collapsedSidebar and "" or button.key:sub(1, 1) .. string.lower(button.key:sub(2)))
        if compactRequestMode then
            button:Hide()
        else
            button:Show()
        end
    end

    self.collapseButton.labelText:SetText(self.collapsedSidebar and ">" or "<")
    if compactRequestMode then
        self.sidebar:Hide()
        self.collapseButton:Hide()
        self.scanButton:Hide()
        self.statusText:Hide()
        self.subtitleText:Hide()
        self.titleText:Hide()
    else
        self.sidebar:Show()
        self.collapseButton:Show()
        self.scanButton:Show()
        self.statusText:Show()
        self.subtitleText:Show()
        self.titleText:Show()
        self.titleText:SetText("Guild Bank Manager")
    end
    if type(self.closeButton.ClearAllPoints) == "function" then
        self.closeButton:ClearAllPoints()
    end
    self.closeButton:SetPoint("TOPRIGHT", self.topBar, "TOPRIGHT", -16, compactRequestMode and -8 or -16)
    if self.activeView == "OPTIONS" then
        self.optionsPanel:Show()
    else
        self.optionsPanel:Hide()
    end
    apply_panel_style(self.closeButton, theme.colors.panel)
    apply_panel_style(self.scanButton, theme.colors.panelAlt)
    apply_panel_style(self.collapseButton, theme.colors.panel)
    apply_panel_style(self.transparencyDecreaseButton, theme.colors.panel)
    apply_panel_style(self.transparencyIncreaseButton, theme.colors.panel)
    apply_panel_style(self.requestApproveButton, theme.colors.panelAlt)
    apply_panel_style(self.requestRejectButton, theme.colors.panel)
    apply_panel_style(self.requestFulfillButton, theme.colors.panelAlt)
    apply_panel_style(self.requestReopenButton, theme.colors.panel)
    apply_panel_style(self.requestCreateButton, theme.colors.panelAlt)
    apply_panel_style(self.minimumRestockToggleButton, theme.colors.panel)
    apply_panel_style(self.minimumShowAllToggleButton, theme.colors.panel)
    apply_panel_style(self.minimumManualOnlyToggleButton, theme.colors.panel)
    apply_panel_style(self.minimumNewButton, theme.colors.panel)
    apply_panel_style(self.minimumSaveButton, theme.colors.panelAlt)
    apply_panel_style(self.minimumSaveAllButton, theme.colors.panel)
    apply_panel_style(self.minimumAddButton, theme.colors.panelAlt)
    apply_panel_style(self.minimumAddCancelButton, theme.colors.panel)
    apply_panel_style(self.defaultMinimumSaveButton, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthRankButton, theme.colors.panel)
    apply_panel_style(self.optionsAuthAddPermissionButton, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthRemovePermissionButton, theme.colors.panel)
    apply_panel_style(self.optionsBlacklistAddButton, theme.colors.panelAlt)
    apply_panel_style(self.optionsBlacklistRemoveButton, theme.colors.panel)
    apply_panel_style(self.optionsAuthSaveButton, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthWriteButton, theme.colors.panelAlt)
    apply_panel_style(self.optionsAuthReadButton, theme.colors.panel)
    apply_panel_style(self.optionsAuthResetButton, theme.colors.panel)
    for _, button in ipairs(self.minimumAddMatchButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    for _, button in ipairs(self.optionsBlacklistButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    for _, button in ipairs(self.optionsAuthRankButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    for _, button in ipairs(self.optionsAllowedPermissionButtons or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    for _, button in ipairs(self.optionsAvailablePermissionButtons or {}) do
        if button:IsShown() then
            apply_panel_style(button, theme.colors.panel)
        end
    end
    apply_panel_style(self.exportPresetSpreadsheetButton, theme.colors.panelAlt)
    apply_panel_style(self.exportPresetAuctionatorButton, theme.colors.panel)
    apply_panel_style(self.exportPresetCustomButton, theme.colors.panel)
    apply_panel_style(self.exportHeaderToggleButton, theme.colors.panel)
    apply_panel_style(self.exportApplyCustomButton, theme.colors.panelAlt)
    apply_panel_style(self.exportModalSelectAllButton, theme.colors.panel)
    apply_panel_style(self.exportModalCopyButton, theme.colors.panelAlt)
    apply_panel_style(self.exportModalCloseButton, theme.colors.panel)
    if type(self.tableScrollBar.SetBackdrop) == "function" then
        self.tableScrollBar:SetBackdrop(nil)
    end
    if self.tableScrollBar.track and type(self.tableScrollBar.track.SetBackdrop) == "function" then
        self.tableScrollBar.track:SetBackdrop(nil)
    end
    if self.tableScrollBar.thumb and type(self.tableScrollBar.thumb.SetBackdrop) == "function" then
        self.tableScrollBar.thumb:SetBackdrop(nil)
    end

    for index, row in ipairs(self.tableRows) do
        apply_table_row_style(row, index, row.isSelected == true)
    end

    for _, input in ipairs(self.tableFilterInputs) do
        apply_panel_style(input, theme.colors.background)
    end

    apply_panel_style(self.requestActionNoteInput, theme.colors.background)
    apply_panel_style(self.requestCreateRequesterInput, theme.colors.background)
    apply_panel_style(self.requestCreateRoleInput, theme.colors.background)
    apply_panel_style(self.requestCreateItemIDInput, theme.colors.background)
    apply_panel_style(self.requestCreateItemNameInput, theme.colors.background)
    apply_panel_style(self.requestCreateQuantityInput, theme.colors.background)
    apply_panel_style(self.requestCreateNoteInput, theme.colors.background)
    apply_panel_style(self.minimumItemIDInput, theme.colors.background)
    apply_panel_style(self.minimumItemNameInput, theme.colors.background)
    apply_panel_style(self.minimumQuantityInput, theme.colors.background)
    apply_panel_style(self.minimumScopeInput, theme.colors.background)
    apply_panel_style(self.minimumTabNameInput, theme.colors.background)
    apply_panel_style(self.minimumSearchInput, theme.colors.background)
    apply_panel_style(self.defaultMinimumInput, theme.colors.background)
    apply_panel_style(self.optionsPolicyStringInput, theme.colors.background)
    apply_panel_style(self.optionsBlacklistNameInput, theme.colors.background)
    apply_panel_style(self.optionsBlacklistReasonInput, theme.colors.background)
    apply_panel_style(self.exportAuctionatorListNameInput, theme.colors.background)
    apply_panel_style(self.exportDelimiterInput, theme.colors.background)
    apply_panel_style(self.exportFieldsInput, theme.colors.background)
    apply_panel_style(self.exportModalOutputInput, theme.colors.background)
end

function mainFrame:GetActiveSortState()
    if self.activeView == "MINIMUMS" then
        return self.minimumSortState
    end

    return self.inventorySortState
end

function mainFrame:ResizeInventoryColumn(index, delta)
    local inventoryView = ns.modules.inventoryView
    if not inventoryView or type(inventoryView.ResizeColumnLayout) ~= "function" then
        return
    end

    self.tableColumnLayout = inventoryView.ResizeColumnLayout(self.tableColumnLayout, index, delta, self.tableViewportWidth)
    local db = current_db()
    local store = ns.data.store or ns.modules.store
    local inventoryColumnWidths = store.GetInventoryColumnWidths(db)

    local defaults = inventoryView.GetDefaultColumns()
    for columnIndex, column in ipairs(self.tableColumnLayout) do
        inventoryColumnWidths[columnIndex] = (column.width or 0) - (defaults[columnIndex].width or 0)
    end

    self:ConfigureTable(self.tableColumnLayout, self.tableRowsData)
    self:RefreshVisibleTableRows()
end

function mainFrame:GetInventoryFilterState()
    local filters = {}

    for index, column in ipairs(self.tableColumnLayout or {}) do
        local input = self.tableFilterInputs[index]
        if input then
            filters[column.key] = input:GetText() or ""
        end
    end

    return filters
end

function mainFrame:ApplyInventoryFilters()
    local inventoryView = ns.modules.inventoryView
    local db = current_db()
    local snapshot = self.cachedInventorySnapshot or { items = {} }
    local layout = inventoryView.GetColumnLayout(db, self.tableViewportWidth)
    local rows = inventoryView.BuildTableRows(snapshot, db, self:GetInventoryFilterState())
    rows = inventoryView.SortRows(rows, self.inventorySortState)
    local displayRows = inventoryView.BuildDisplayRows(rows, layout)

    self.tableColumnLayout = layout
    self.tableScrollOffset = 0
    self.cachedInventoryRows = rows
    self:ConfigureTable(layout, displayRows)
    self:RefreshVisibleTableRows()
end

function mainFrame:HandleHeaderClick(index)
    if self.activeView ~= "INVENTORY" and self.activeView ~= "MINIMUMS" then
        return nil
    end

    local column = self.tableColumnLayout[index]
    if not column or column.sortable ~= true then
        return nil
    end

    local sortState = self.activeView == "MINIMUMS" and self.minimumSortState or self.inventorySortState

    if sortState.key == column.key then
        sortState.direction = sortState.direction == "asc" and "desc" or "asc"
    else
        sortState.key = column.key
        sortState.direction = "asc"
    end

    if self.activeView == "MINIMUMS" then
        self:ApplyMinimumFilters()
    else
        self:ApplyInventoryFilters()
    end
    return sortState
end

function mainFrame:HandleTableRowClick(row)
    if not row then
        return nil
    end

    if self.activeView == "REQUESTS" and row.requestId then
        self:SelectRequestById(row.requestId)
        self:RefreshRequestActionButtons()
        return row
    end

    if self.activeView == "MINIMUMS" and row.itemID then
        self.selectedMinimumKey = row.rowKey
        self:ApplyMinimumFilters()
        return row
    end

    return nil
end

function mainFrame:IsSelectedTableRow(row)
    if not row then
        return false
    end

    if self.activeView == "REQUESTS" then
        return row.requestId ~= nil and row.requestId == self.selectedRequestId
    end

    if self.activeView == "MINIMUMS" then
        return self.selectedMinimumKey ~= nil and row.rowKey == self.selectedMinimumKey
    end

    return false
end

function mainFrame:BuildExportRows()
    local db = current_db()
    local exports = ns.modules.exports
    if exports and type(exports.BuildRowsFromDatabase) == "function" then
        return exports.BuildRowsFromDatabase(db)
    end

    return {}, { items = {} }
end

function mainFrame:GetCurrentSnapshot()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetCurrentSnapshot) == "function" then
        return store.GetCurrentSnapshot(current_db())
    end

    return { items = {} }
end

function mainFrame:RefreshView()
    local db = current_db()
    local currentSnapshot = nil
    local planning = ns.modules.planning
    local dashboardView = ns.modules.dashboardView
    local inventoryView = ns.modules.inventoryView
    local historyView = ns.modules.historyView
    local minimumsView = ns.modules.minimumsView
    local requestsView = ns.modules.requestsView
    local accessProfile, authContext = current_access_profile(db)
    local compactRequestMode = request_only_layout(self)

    self:UpdateSharedTableLayout()

    local demandPlan = {}
    currentSnapshot = self:GetCurrentSnapshot()
    if planning and type(planning.BuildDemandPlanFromDatabase) == "function" then
        demandPlan, currentSnapshot = planning.BuildDemandPlanFromDatabase(db)
    end

    if dashboardView and type(dashboardView.BuildSummary) == "function" then
        local scanner = ns.modules.scanner
        if not (scanner and scanner.scanInProgress) then
            self:SetStatusSummary(dashboardView.BuildSummary(db, demandPlan))
        end
    end

    for _, card in ipairs(self.dashboardCards) do
        card:Hide()
    end
    self.tableHeaderFrame:Hide()
    self.tableFilterFrame:Hide()
    self.tableViewportFrame:Hide()
    self.tableScrollFrame:Hide()
    self.tableScrollBar:Hide()
    self.requestActionsPanel:Hide()
    self.requestCreatePanel:Hide()
    self.minimumsPanel:Hide()
    self.minimumAddModal:Hide()
    self.minimumEmptyStateText:Hide()
    self.exportsPanel:Hide()
    self.exportModal:Hide()
    self.optionsPanel:Hide()
    self.contentBodyText:SetText("")
    self.contentBodyText:Hide()

    local showTable = false
    local showCards = false
    local bodyText = ""

    if self.activeView == "DASHBOARD" then
        local cards = dashboardView.BuildCards(db, demandPlan)
        for index, card in ipairs(self.dashboardCards) do
            local model = cards[index]
            if model then
                card.titleText:SetText(model.title or "")
                card.valueText:SetText(model.value or "")
                card.noteText:SetText(model.note or "")
                card.linesText:SetText(model.lines and table.concat(model.lines, "\n") or "")
                card:Show()
            else
                card:Hide()
            end
        end
        showCards = true
    elseif self.activeView == "INVENTORY" then
        self.cachedInventoryDb = db
        self.cachedInventorySnapshot = currentSnapshot or { items = {} }
        self:ApplyInventoryFilters()
        showTable = true
    elseif self.activeView == "HISTORY" then
        local procurementEntries = historyView.FilterProcurementEntries(db.auditLog or {})
        local rows = historyView.BuildTableRows(procurementEntries, self:GetSharedFilterState())
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "date", label = "When", width = 150, justifyH = "LEFT" },
            { key = "category", label = "Category", width = 90, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 150, justifyH = "LEFT" },
            { key = "action", label = "Action", width = 80, justifyH = "LEFT" },
            { key = "actor", label = "Who", width = 90, justifyH = "LEFT" },
            { key = "oldValue", label = "Old", width = 70, justifyH = "LEFT" },
            { key = "newValue", label = "New", width = 70, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        showTable = true
    elseif self.activeView == "MINIMUMS" then
        self.minimumShowAllToggleButton.labelText:SetText(self.minimumShowAllRows and "Enabled Only" or "Show All")
        self.minimumManualOnlyToggleButton:Hide()
        self.minimumSaveAllButton:Hide()
        self.minimumSaveButton.labelText:SetText("Save All")
        self:LoadMinimumSettingsFromDb(db)
        self:ApplyMinimumFilters()
        showTable = true
    elseif self.activeView == "REQUESTS" then
        local rows = requestsView.BuildTableRows(db.requests or {}, authContext, accessProfile)
        if not self:GetSelectedRequest() then
            self:SelectFirstActionableRequest()
        end
        self:RefreshRequestActionButtons()
        self.tableScrollOffset = 0
        if compactRequestMode then
            self:ConfigureTable({
                { key = "createdAt", label = "Submitted", width = 130, justifyH = "LEFT" },
                { key = "itemName", label = "Item", width = 190, justifyH = "LEFT" },
                { key = "quantity", label = "Qty", width = 60, justifyH = "LEFT" },
                { key = "approval", label = "Approval", width = 95, justifyH = "LEFT" },
                { key = "fulfillment", label = "Fulfillment", width = 105, justifyH = "LEFT" },
                { key = "note", label = "Note", width = 170, justifyH = "LEFT" },
            }, rows)
        else
            self:ConfigureTable({
                { key = "requester", label = "Requester", width = 110, justifyH = "LEFT" },
                { key = "itemName", label = "Item", width = 170, justifyH = "LEFT" },
                { key = "quantity", label = "Qty", width = 50, justifyH = "LEFT" },
                { key = "approval", label = "Approval", width = 90, justifyH = "LEFT" },
                { key = "fulfillment", label = "Fulfillment", width = 100, justifyH = "LEFT" },
                { key = "note", label = "Note", width = 110, justifyH = "LEFT" },
            }, rows)
        end
        self:RefreshVisibleTableRows()
        showTable = true
    elseif self.activeView == "EXPORTS" then
        self:LoadExportSettingsFromDb(db)
        local rows = self:BuildExportRows()
        self:RefreshExportCustomControls()
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "itemName", label = "Item", width = 170, justifyH = "LEFT" },
            { key = "currentQuantity", label = "Current", width = 70, justifyH = "LEFT" },
            { key = "totalToBuy", label = "Buy", width = 60, justifyH = "LEFT" },
            { key = "scopeSummary", label = "Scope", width = 90, justifyH = "LEFT" },
            { key = "reason", label = "Reason", width = 220, justifyH = "LEFT" },
            { key = "itemID", label = "Item ID", width = 80, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        self:RefreshExportOutput(rows)
        showTable = true
    elseif self.activeView == "OPTIONS" then
        self:LoadMinimumSettingsFromDb(db)
        self:LoadAuthOptionsFromDb(db)
        self:UpdateOptionsCanvasHeight()
        self.optionsScrollFrame.verticalScroll = 0
        self.optionsScrollFrame:SetVerticalScroll(0)
        self:SyncOptionsScrollVisuals()
        bodyText = ""
    elseif self.activeView == "ABOUT" then
        bodyText = table.concat({
            "Author: Zirleficent",
            "Server: Stormrage",
            "Guild: Tyrrish Rebellion",
            string.format("Build: %s", ABOUT_BUILD_STAMP),
            "Support: Placeholder text.",
        }, "\n")
    else
        bodyText = "Detailed content for this view is coming next."
    end

    for _, card in ipairs(self.dashboardCards) do
        if showCards then
            card:Show()
        else
            card:Hide()
        end
    end

    if type(self.requestActionsPanel.ClearAllPoints) == "function" then
        self.requestActionsPanel:ClearAllPoints()
    end
    self.requestActionsPanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
    self.requestActionsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
    if type(self.requestCreatePanel.ClearAllPoints) == "function" then
        self.requestCreatePanel:ClearAllPoints()
    end
    if compactRequestMode then
        self.requestCreatePanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
    else
        self.requestCreatePanel:SetPoint("TOPLEFT", self.requestActionsPanel, "BOTTOMLEFT", 0, -12)
    end
    self.requestCreatePanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
    if type(self.tableHeaderFrame.ClearAllPoints) == "function" then
        self.tableHeaderFrame:ClearAllPoints()
    end
    if self.activeView == "REQUESTS" then
        self.tableHeaderFrame:SetPoint("TOPLEFT", self.requestCreatePanel, "BOTTOMLEFT", 0, -16)
    else
        self.tableHeaderFrame:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
    end

    if showTable then
        self.tableHeaderFrame:Show()
        if self:UsesInlineTableFilters() then
            self.tableFilterFrame:Show()
        else
            self.tableFilterFrame:Hide()
        end
        self.tableViewportFrame:Show()
        self.tableScrollFrame:Show()
        self.tableScrollBar:Show()
    else
        self.tableHeaderFrame:Hide()
        self.tableFilterFrame:Hide()
        self.tableViewportFrame:Hide()
        self.tableScrollFrame:Hide()
        self.tableScrollBar:Hide()
    end

    if bodyText ~= "" then
        self.contentBodyText:SetText(bodyText)
        self.contentBodyText:Show()
    else
        self.contentBodyText:SetText("")
        self.contentBodyText:Hide()
    end

    if self.activeView == "REQUESTS" and not compactRequestMode then
        self.requestActionsPanel:Show()
    else
        self.requestActionsPanel:Hide()
    end

    if self.activeView == "REQUESTS" then
        self.requestCreatePanel:Show()
    else
        self.requestCreatePanel:Hide()
    end

    if self.activeView == "MINIMUMS" then
        self.minimumsPanel:Show()
    else
        self.minimumsPanel:Hide()
        self.minimumEmptyStateText:Hide()
    end

    if self.activeView == "EXPORTS" then
        self.exportsPanel:Show()
    else
        self.exportsPanel:Hide()
    end

    if self.activeView == "OPTIONS" then
        self.optionsPanel:Show()
        self.optionsViewportFrame:Show()
    else
        self.optionsPanel:Hide()
        self.optionsViewportFrame:Hide()
    end
end

for _, input in ipairs(mainFrame.tableFilterInputs) do
    input:SetScript("OnTextChanged", function()
        if mainFrame.isConfiguringTable then
            return
        end
        if mainFrame.activeView == "INVENTORY" then
            mainFrame:ApplyInventoryFilters()
        elseif mainFrame.activeView == "MINIMUMS" then
            mainFrame:ApplyMinimumFilters()
        elseif mainFrame.activeView == "HISTORY" then
            mainFrame:RefreshView()
        end
    end)
end

function mainFrame:SelectView(name)
    local nextView = name or "DASHBOARD"
    if nextView ~= self.activeView then
        self:ClearTableFilters()
    end
    self.activeView = nextView
    self.viewTitle:SetText(view_label_for(nextView))
    self.viewSubtitle:SetText(self.viewDescriptions[self.activeView] or self.viewDescriptions.DASHBOARD)
    self:ApplyTheme()
    self:RefreshView()
    self:EnableMouse(true)
    self:Show()
    return self.activeView
end

function mainFrame:ShowDashboard()
    self.requestOnlyMode = false
    return self:SelectView("DASHBOARD")
end

function mainFrame:ShowRequestOnly()
    self.requestOnlyMode = true
    return self:SelectView("REQUESTS")
end

function mainFrame:ShowBlockedAccess(message)
    self.requestOnlyMode = false
    self:SetStatusSummary({})
    self.statusText:SetText(message or "Access blocked")
    self:EnableMouse(false)
    self:Hide()
    return false
end

function mainFrame:ToggleSidebar()
    self.collapsedSidebar = not self.collapsedSidebar
    self:ApplyTheme()
    return self.collapsedSidebar
end

function mainFrame:SetStatusSummary(summary)
    summary = summary or {}
    local lastScanAt = summary.lastScanAt or 0
    self.statusText:SetText(string.format("Last scan %s", format_timestamp(lastScanAt)))
end

function mainFrame:SetScanStatus(text)
    self.statusText:SetText(text or "No scan yet")
    self:RefreshView()
end

refresh_alpha_text()
mainFrame:ApplyTheme()
mainFrame:Hide()

ns.modules.mainFrame = mainFrame

return mainFrame
