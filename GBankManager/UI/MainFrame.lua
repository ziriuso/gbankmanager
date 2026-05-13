local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}
local mainTableController = ns.modules.mainTableController or {}
local mainRequestsController = ns.modules.mainRequestsController or {}
local mainFrame = mainFrameShell.EnsureShell and mainFrameShell.EnsureShell(ns.modules.mainFrame) or ns.modules.mainFrame
local theme = mainFrameShell.GetTheme and mainFrameShell.GetTheme() or (ns.ui.theme or {})
local apply_panel_style = mainFrameShell.ApplyPanelStyle
local make_label = mainFrameShell.MakeLabel
local make_button = mainFrameShell.MakeButton
local set_button_icon = mainFrameShell.SetButtonIcon
local make_input = mainFrameShell.MakeInput
local make_slider = mainFrameShell.MakeSlider
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

local function export_quality_for_item(db, itemID)
    db = db or {}
    local snapshots = db.snapshots or {}
    local currentSnapshot = db.currentSnapshotId and snapshots[db.currentSnapshotId] or nil
    local snapshotItems = (currentSnapshot and currentSnapshot.items) or {}
    local sources = {
        db.minimums,
        db.oneTimeTargets,
        db.requests,
    }

    local snapshotItem = snapshotItems[itemID]
    if snapshotItem and tonumber(snapshotItem.craftedQuality or 0) and tonumber(snapshotItem.craftedQuality or 0) > 0 then
        return tonumber(snapshotItem.craftedQuality or 0) or 0
    end

    for _, source in ipairs(sources) do
        for _, entry in ipairs(source or {}) do
            if entry.itemID == itemID then
                local quality = tonumber(entry.quality or entry.craftedQuality or 0) or 0
                if quality > 0 then
                    return quality
                end
            end
        end
    end

    return 0
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

local function minimum_rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

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

local MINIMUM_DRAFT_ROW_COLORS = {
    added = { 0.16, 0.30, 0.18, 0.98 },
    changed = { 0.34, 0.31, 0.12, 0.98 },
    deleted = { 0.34, 0.14, 0.14, 0.98 },
}

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

local function is_db_empty(db)
    db = db or {}

    if db.currentSnapshotId ~= nil then
        return false
    end

    if next(db.snapshots or {}) ~= nil then
        return false
    end

    if next(db.requests or {}) ~= nil then
        return false
    end

    if next(db.minimums or {}) ~= nil then
        return false
    end

    if next(db.oneTimeTargets or {}) ~= nil then
        return false
    end

    return true
end

local function current_db()
    local store = ns.data.store or ns.modules.store
    local runtime = _G.GBankManagerDB or {}
    local stateDb = ns.state.db or {}

    if runtime ~= stateDb and (is_db_empty(runtime) and not is_db_empty(stateDb)) then
        runtime = stateDb
    elseif runtime == nil or next(runtime) == nil then
        runtime = stateDb
    end

    if store and type(store.Normalize) == "function" then
        runtime = store.Normalize(runtime)
    end

    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function procurement_audit_entries(entries)
    local filtered = {}
    local allowedCategories = {
        REQUEST = true,
        MINIMUM = true,
    }

    for _, entry in ipairs(entries or {}) do
        if allowedCategories[entry.category] then
            table.insert(filtered, entry)
        end
    end

    return filtered
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

mainFrame.contentBodyText = mainFrame.contentBodyText or make_label(mainFrame.content, "", "GameFontNormal")
mainFrame.contentBodyText:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)

mainFrame.minimumEmptyStateText = mainFrame.minimumEmptyStateText or make_label(mainFrame.content, "", "GameFontHighlightSmall")
mainFrame.minimumEmptyStateText:SetPoint("TOPLEFT", mainFrame.tableScrollFrame, "TOPLEFT", 12, -12)
mainFrame.minimumEmptyStateText:Hide()

mainFrame.optionsPanel = mainFrame.optionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.optionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.optionsPanel:SetHeight(224)
apply_panel_style(mainFrame.optionsPanel, theme.colors.panel)
mainFrame.optionsPanel:Hide()

mainFrame.optionsAppearancePanel = mainFrame.optionsAppearancePanel or _G.CreateFrame("Frame", nil, mainFrame.optionsPanel, "BackdropTemplate")
mainFrame.optionsAppearancePanel:SetPoint("TOPLEFT", mainFrame.optionsPanel, "TOPLEFT", 0, 0)
mainFrame.optionsAppearancePanel:SetPoint("TOPRIGHT", mainFrame.optionsPanel, "TOPRIGHT", 0, 0)
mainFrame.optionsAppearancePanel:SetHeight(96)
apply_panel_style(mainFrame.optionsAppearancePanel, theme.colors.panelAlt)

mainFrame.optionsRestockPanel = mainFrame.optionsRestockPanel or _G.CreateFrame("Frame", nil, mainFrame.optionsPanel, "BackdropTemplate")
mainFrame.optionsRestockPanel:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "BOTTOMLEFT", 0, -16)
mainFrame.optionsRestockPanel:SetPoint("TOPRIGHT", mainFrame.optionsAppearancePanel, "BOTTOMRIGHT", 0, -16)
mainFrame.optionsRestockPanel:SetHeight(96)
apply_panel_style(mainFrame.optionsRestockPanel, theme.colors.panelAlt)

mainFrame.minimumsPanel = mainFrame.minimumsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.minimumsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.minimumsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.minimumsPanel:SetHeight(80)
apply_panel_style(mainFrame.minimumsPanel, theme.colors.panel)
mainFrame.minimumsPanel:Hide()

mainFrame.minimumsTitle = mainFrame.minimumsTitle or make_label(mainFrame.minimumsPanel, "Minimum Draft Actions", "GameFontHighlight")
mainFrame.minimumsTitle:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -16)
mainFrame.minimumsTitle:Hide()

mainFrame.minimumsHint = mainFrame.minimumsHint or make_label(mainFrame.minimumsPanel, "Use Add to stage items, edit Bank Tab / Restock / Minimum inline, Save to commit, or Undo to discard draft changes.", "GameFontHighlightSmall")
mainFrame.minimumsHint:SetPoint("TOPLEFT", mainFrame.minimumsTitle, "BOTTOMLEFT", 0, -8)
mainFrame.minimumsHint:Hide()

mainFrame.minimumEditorStateText = mainFrame.minimumEditorStateText or make_label(mainFrame.minimumsPanel, "No draft minimum changes yet.", "GameFontHighlightSmall")
mainFrame.minimumEditorStateText:SetPoint("TOPLEFT", mainFrame.minimumsHint, "BOTTOMLEFT", 0, -14)
mainFrame.minimumEditorStateText:Hide()

mainFrame.minimumShowAllToggleButton = mainFrame.minimumShowAllToggleButton or make_button(mainFrame.minimumsPanel, 110, 28, "Show All")
mainFrame.minimumShowAllToggleButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumsPanel, "BOTTOMRIGHT", -16, 12)

mainFrame.minimumSearchLabel = mainFrame.minimumSearchLabel or make_label(mainFrame.minimumsPanel, "Search", "GameFontHighlightSmall")
mainFrame.minimumSearchLabel:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -14)

mainFrame.minimumSearchInput = mainFrame.minimumSearchInput or make_input(mainFrame.minimumsPanel, 120, 22)
mainFrame.minimumSearchInput:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -32)

mainFrame.minimumManualOnlyToggleButton = mainFrame.minimumManualOnlyToggleButton or make_button(mainFrame.minimumsPanel, 86, 28, "Manual Only")
mainFrame.minimumManualOnlyToggleButton:SetPoint("RIGHT", mainFrame.minimumSearchInput, "LEFT", -8, 0)
mainFrame.minimumManualOnlyToggleButton:Hide()

mainFrame.minimumNewButton = mainFrame.minimumNewButton or make_button(mainFrame.minimumsPanel, 64, 28, "Add")
mainFrame.minimumNewButton:SetPoint("BOTTOMLEFT", mainFrame.minimumsPanel, "BOTTOMLEFT", 16, 12)

mainFrame.minimumSaveButton = mainFrame.minimumSaveButton or make_button(mainFrame.minimumsPanel, 88, 28, "Save")
mainFrame.minimumSaveButton:SetPoint("LEFT", mainFrame.minimumNewButton, "RIGHT", 8, 0)
mainFrame.minimumSaveButton.labelText:SetText("Save All")

mainFrame.minimumSaveAllButton = mainFrame.minimumSaveAllButton or make_button(mainFrame.minimumsPanel, 84, 28, "Undo")
mainFrame.minimumSaveAllButton:SetPoint("LEFT", mainFrame.minimumSaveButton, "RIGHT", 8, 0)
mainFrame.minimumSaveAllButton:Hide()

mainFrame.minimumAddModal = mainFrame.minimumAddModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.minimumAddModal:SetSize(500, 300)
mainFrame.minimumAddModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.minimumAddModal.frameStrata = "FULLSCREEN_DIALOG"
if type(mainFrame.minimumAddModal.SetFrameStrata) == "function" then
    mainFrame.minimumAddModal:SetFrameStrata(mainFrame.minimumAddModal.frameStrata)
end
mainFrame.minimumAddModal.frameLevel = (mainFrame.frameLevel or 0) + 20
if type(mainFrame.minimumAddModal.SetFrameLevel) == "function" then
    mainFrame.minimumAddModal:SetFrameLevel(mainFrame.minimumAddModal.frameLevel)
end
apply_panel_style(mainFrame.minimumAddModal, theme.colors.panelAlt)
mainFrame.minimumAddModal:Hide()

mainFrame.minimumAddModalTitle = mainFrame.minimumAddModalTitle or make_label(mainFrame.minimumAddModal, "Add Minimum Item", "GameFontHighlight")
mainFrame.minimumAddModalTitle:SetPoint("TOPLEFT", mainFrame.minimumAddModal, "TOPLEFT", 16, -16)

mainFrame.minimumAddModalHint = mainFrame.minimumAddModalHint or make_label(mainFrame.minimumAddModal, "Search by Item ID or Item Name, then add the item and finish Bank Tab / Restock / Minimum inline in the table.", "GameFontHighlightSmall")
mainFrame.minimumAddModalHint:SetPoint("TOPLEFT", mainFrame.minimumAddModalTitle, "BOTTOMLEFT", 0, -8)
mainFrame.minimumAddModalHint:SetWidth(452)

mainFrame.minimumAddItemIDLabel = mainFrame.minimumAddItemIDLabel or make_label(mainFrame.minimumAddModal, "Item ID", "GameFontHighlightSmall")
mainFrame.minimumAddItemIDLabel:SetPoint("TOPLEFT", mainFrame.minimumAddModalHint, "BOTTOMLEFT", 0, -14)

mainFrame.minimumAddItemNameLabel = mainFrame.minimumAddItemNameLabel or make_label(mainFrame.minimumAddModal, "Item Name", "GameFontHighlightSmall")
mainFrame.minimumAddItemNameLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDLabel, "TOPRIGHT", 96, 0)

mainFrame.minimumAddQuantityLabel = mainFrame.minimumAddQuantityLabel or make_label(mainFrame.minimumAddModal, "Minimum", "GameFontHighlightSmall")
mainFrame.minimumAddQuantityLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemNameLabel, "TOPRIGHT", 208, 0)

mainFrame.minimumAddItemIDInput = mainFrame.minimumAddItemIDInput or make_input(mainFrame.minimumAddModal, 84, 22)
mainFrame.minimumAddItemIDInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDLabel, "BOTTOMLEFT", 0, -4)

mainFrame.minimumAddItemNameInput = mainFrame.minimumAddItemNameInput or make_input(mainFrame.minimumAddModal, 196, 22)
mainFrame.minimumAddItemNameInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemNameLabel, "BOTTOMLEFT", 0, -4)

mainFrame.minimumAddQuantityInput = mainFrame.minimumAddQuantityInput or make_input(mainFrame.minimumAddModal, 64, 22)
mainFrame.minimumAddQuantityInput:SetPoint("TOPLEFT", mainFrame.minimumAddQuantityLabel, "BOTTOMLEFT", 0, -4)

mainFrame.minimumAddButton = mainFrame.minimumAddButton or make_button(mainFrame.minimumAddModal, 64, 28, "Add")
mainFrame.minimumAddButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumAddModal, "BOTTOMRIGHT", -16, 16)

mainFrame.minimumAddCancelButton = mainFrame.minimumAddCancelButton or make_button(mainFrame.minimumAddModal, 72, 28, "Cancel")
mainFrame.minimumAddCancelButton:SetPoint("RIGHT", mainFrame.minimumAddButton, "LEFT", -8, 0)

mainFrame.minimumAddBankTabInput = mainFrame.minimumAddBankTabInput or make_input(mainFrame.minimumAddModal, 110, 22)
mainFrame.minimumAddBankTabInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDInput, "BOTTOMLEFT", 0, -12)
mainFrame.minimumAddBankTabInput:Hide()

mainFrame.minimumScopeInput = mainFrame.minimumScopeInput or make_input(mainFrame.minimumAddModal, 88, 22)
mainFrame.minimumScopeInput:SetPoint("LEFT", mainFrame.minimumAddBankTabInput, "RIGHT", 8, 0)
mainFrame.minimumScopeInput:Hide()

mainFrame.minimumItemIDInput = mainFrame.minimumItemIDInput or mainFrame.minimumAddItemIDInput
mainFrame.minimumItemNameInput = mainFrame.minimumItemNameInput or mainFrame.minimumAddItemNameInput
mainFrame.minimumQuantityInput = mainFrame.minimumQuantityInput or mainFrame.minimumAddQuantityInput
mainFrame.minimumTabNameInput = mainFrame.minimumTabNameInput or mainFrame.minimumAddBankTabInput

mainFrame.minimumRestockToggleButton = mainFrame.minimumRestockToggleButton or make_button(mainFrame.minimumAddModal, 78, 28, "Restock: Yes")
mainFrame.minimumRestockToggleButton:SetPoint("LEFT", mainFrame.minimumScopeInput, "RIGHT", 8, 0)
mainFrame.minimumRestockToggleButton:Hide()

mainFrame.minimumAddResultsLabel = mainFrame.minimumAddResultsLabel or make_label(mainFrame.minimumAddModal, "Matches", "GameFontHighlightSmall")
mainFrame.minimumAddResultsLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDInput, "BOTTOMLEFT", 0, -16)

mainFrame.minimumAddResultsPanel = mainFrame.minimumAddResultsPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumAddModal, "BackdropTemplate")
mainFrame.minimumAddResultsPanel:SetPoint("TOPLEFT", mainFrame.minimumAddResultsLabel, "BOTTOMLEFT", 0, -6)
mainFrame.minimumAddResultsPanel:SetSize(452, 86)
apply_panel_style(mainFrame.minimumAddResultsPanel, theme.colors.background)
mainFrame.minimumAddResultsPanel:Hide()

mainFrame.minimumAddMatchButtons = mainFrame.minimumAddMatchButtons or {}
for index = 1, 3 do
    local button = mainFrame.minimumAddMatchButtons[index] or make_button(mainFrame.minimumAddResultsPanel, 444, 22, "")
    button:SetPoint("TOPLEFT", mainFrame.minimumAddResultsPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
    button:SetWidth(444)
    button:Hide()
    mainFrame.minimumAddMatchButtons[index] = button
end

mainFrame.exportsPanel = mainFrame.exportsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.exportsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.exportsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.exportsPanel:SetHeight(154)
apply_panel_style(mainFrame.exportsPanel, theme.colors.panel)
mainFrame.exportsPanel:Hide()

mainFrame.exportsTitle = mainFrame.exportsTitle or make_label(mainFrame.exportsPanel, "Export Output", "GameFontHighlight")
mainFrame.exportsTitle:SetPoint("TOPLEFT", mainFrame.exportsPanel, "TOPLEFT", 16, -16)

mainFrame.exportsHint = mainFrame.exportsHint or make_label(mainFrame.exportsPanel, "Generate preset text from the active procurement plan.", "GameFontHighlightSmall")
mainFrame.exportsHint:SetPoint("TOPLEFT", mainFrame.exportsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.exportPresetSpreadsheetButton = mainFrame.exportPresetSpreadsheetButton or make_button(mainFrame.exportsPanel, 84, 28, "CSV")
mainFrame.exportPresetSpreadsheetButton:SetPoint("TOPLEFT", mainFrame.exportsHint, "BOTTOMLEFT", 0, -14)
mainFrame.exportPresetSpreadsheetButton.labelText:SetText("CSV")

mainFrame.exportPresetAuctionatorButton = mainFrame.exportPresetAuctionatorButton or make_button(mainFrame.exportsPanel, 84, 28, "Auctionator")
mainFrame.exportPresetAuctionatorButton:SetPoint("LEFT", mainFrame.exportPresetSpreadsheetButton, "RIGHT", 8, 0)

mainFrame.exportPresetCustomButton = mainFrame.exportPresetCustomButton or make_button(mainFrame.exportsPanel, 68, 28, "Custom")
mainFrame.exportPresetCustomButton:SetPoint("LEFT", mainFrame.exportPresetAuctionatorButton, "RIGHT", 8, 0)

mainFrame.exportsPresetTitle = mainFrame.exportsPresetTitle or make_label(mainFrame.exportsPanel, "CSV", "GameFontHighlight")
mainFrame.exportsPresetTitle:SetPoint("LEFT", mainFrame.exportPresetCustomButton, "RIGHT", 16, 0)

mainFrame.exportsOutputText = mainFrame.exportsOutputText or make_label(mainFrame.exportsPanel, "", "GameFontNormal")
mainFrame.exportsOutputText:SetPoint("TOPLEFT", mainFrame.exportPresetSpreadsheetButton, "BOTTOMLEFT", 0, -12)
mainFrame.exportsOutputText:SetWidth(760)
mainFrame.exportsOutputText:Hide()

mainFrame.exportDelimiterInput = mainFrame.exportDelimiterInput or make_input(mainFrame.exportsPanel, 42, 22)
mainFrame.exportDelimiterInput:SetPoint("LEFT", mainFrame.exportsPresetTitle, "RIGHT", 16, 0)
mainFrame.exportDelimiterInput:SetText(mainFrame.exportCustomTemplate.delimiter or "|")

mainFrame.exportAuctionatorListNameInput = mainFrame.exportAuctionatorListNameInput or make_input(mainFrame.exportsPanel, 140, 22)
mainFrame.exportAuctionatorListNameInput:SetPoint("LEFT", mainFrame.exportsPresetTitle, "RIGHT", 16, 0)
mainFrame.exportAuctionatorListNameInput:SetText(mainFrame.exportShoppingListName or "GBankManager")
mainFrame.exportAuctionatorListNameInput:Hide()

mainFrame.exportFieldsInput = mainFrame.exportFieldsInput or make_input(mainFrame.exportsPanel, 250, 22)
mainFrame.exportFieldsInput:SetPoint("LEFT", mainFrame.exportDelimiterInput, "RIGHT", 8, 0)
mainFrame.exportFieldsInput:SetText(table.concat(mainFrame.exportCustomTemplate.fields or {}, ","))

mainFrame.exportHeaderToggleButton = mainFrame.exportHeaderToggleButton or make_button(mainFrame.exportsPanel, 88, 28, "Header: Yes")
mainFrame.exportHeaderToggleButton:SetPoint("LEFT", mainFrame.exportFieldsInput, "RIGHT", 8, 0)

mainFrame.exportApplyCustomButton = mainFrame.exportApplyCustomButton or make_button(mainFrame.exportsPanel, 64, 28, "Apply")
mainFrame.exportApplyCustomButton:SetPoint("LEFT", mainFrame.exportHeaderToggleButton, "RIGHT", 8, 0)

mainFrame.exportModal = mainFrame.exportModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.exportModal:SetSize(760, 252)
mainFrame.exportModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.exportModal.frameStrata = "FULLSCREEN_DIALOG"
if type(mainFrame.exportModal.SetFrameStrata) == "function" then
    mainFrame.exportModal:SetFrameStrata(mainFrame.exportModal.frameStrata)
end
mainFrame.exportModal.frameLevel = (mainFrame.frameLevel or 0) + 20
if type(mainFrame.exportModal.SetFrameLevel) == "function" then
    mainFrame.exportModal:SetFrameLevel(mainFrame.exportModal.frameLevel)
end
apply_panel_style(mainFrame.exportModal, theme.colors.panelAlt)
mainFrame.exportModal:Hide()

mainFrame.exportModalTitle = mainFrame.exportModalTitle or make_label(mainFrame.exportModal, "Export Output", "GameFontHighlight")
mainFrame.exportModalTitle:SetPoint("TOPLEFT", mainFrame.exportModal, "TOPLEFT", 16, -16)

mainFrame.exportModalHint = mainFrame.exportModalHint or make_label(mainFrame.exportModal, "Select all or copy the generated output into external tools.", "GameFontHighlightSmall")
mainFrame.exportModalHint:SetPoint("TOPLEFT", mainFrame.exportModalTitle, "BOTTOMLEFT", 0, -8)

mainFrame.exportModalScrollFrame = mainFrame.exportModalScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.exportModal, "BackdropTemplate")
mainFrame.exportModalScrollFrame:SetPoint("TOPLEFT", mainFrame.exportModalHint, "BOTTOMLEFT", 0, -12)
mainFrame.exportModalScrollFrame:SetSize(728, 146)
mainFrame.exportModalScrollFrame:EnableMouseWheel(true)
mainFrame.exportModalScrollFrame.verticalScroll = mainFrame.exportModalScrollFrame.verticalScroll or 0
mainFrame.exportModalScrollFrame.verticalScrollRange = mainFrame.exportModalScrollFrame.verticalScrollRange or 0
if type(mainFrame.exportModalScrollFrame.SetVerticalScroll) ~= "function" then
    function mainFrame.exportModalScrollFrame:SetVerticalScroll(value)
        local clamped = math.max(0, math.min(tonumber(value or 0) or 0, self.verticalScrollRange or 0))
        self.verticalScroll = clamped
    end
end

mainFrame.exportModalScrollChild = mainFrame.exportModalScrollChild or _G.CreateFrame("Frame", nil, mainFrame.exportModalScrollFrame, "BackdropTemplate")
mainFrame.exportModalScrollChild:SetSize(728, 146)
mainFrame.exportModalScrollFrame:SetScrollChild(mainFrame.exportModalScrollChild)

mainFrame.exportModalOutputInput = mainFrame.exportModalOutputInput or make_export_output_input(mainFrame.exportModalScrollChild, 712, 130)
mainFrame.exportModalOutputInput:SetPoint("TOPLEFT", mainFrame.exportModalScrollChild, "TOPLEFT", 8, -8)

mainFrame.exportModalSelectAllButton = mainFrame.exportModalSelectAllButton or make_button(mainFrame.exportModal, 84, 28, "Select All")
mainFrame.exportModalSelectAllButton:SetPoint("BOTTOMLEFT", mainFrame.exportModal, "BOTTOMLEFT", 16, 16)

mainFrame.exportModalCopyButton = mainFrame.exportModalCopyButton or make_button(mainFrame.exportModal, 64, 28, "Copy")
mainFrame.exportModalCopyButton:SetPoint("LEFT", mainFrame.exportModalSelectAllButton, "RIGHT", 8, 0)

mainFrame.exportModalCloseButton = mainFrame.exportModalCloseButton or make_button(mainFrame.exportModal, 64, 28, "Close")
mainFrame.exportModalCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.exportModal, "BOTTOMRIGHT", -16, 16)

mainFrame.exportModalScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll((self.verticalScroll or 0) - ((delta or 0) * 24))
end)

mainFrame.exportModalOutputInput:SetScript("OnTextChanged", function()
    mainFrame:RefreshExportModalScrollMetrics()
end)

mainFrame.minimumNewButton:SetScript("OnClick", function()
    mainFrame:OpenMinimumAddModal()
end)

mainFrame.minimumRestockToggleButton:SetScript("OnClick", function()
    mainFrame:ToggleMinimumRestock()
end)

mainFrame.minimumShowAllToggleButton:SetScript("OnClick", function()
    mainFrame:ToggleMinimumShowAllRows()
end)

mainFrame.minimumManualOnlyToggleButton:SetScript("OnClick", function()
    mainFrame:ToggleMinimumManualOnlyRows()
end)

mainFrame.minimumSaveButton:SetScript("OnClick", function()
    mainFrame:SaveAllMinimumChanges()
end)

mainFrame.minimumSaveAllButton:SetScript("OnClick", function()
    mainFrame:SaveAllMinimumChanges()
end)

mainFrame.minimumAddButton:SetScript("OnClick", function()
    mainFrame:CreateMinimumFromAddRow()
end)

mainFrame.minimumAddCancelButton:SetScript("OnClick", function()
    mainFrame:HideMinimumAddModal()
end)

mainFrame.exportPresetSpreadsheetButton:SetScript("OnClick", function()
    mainFrame:SelectExportPreset("CSV")
end)

mainFrame.exportPresetAuctionatorButton:SetScript("OnClick", function()
    mainFrame:SelectExportPreset("Auctionator")
end)

mainFrame.exportPresetCustomButton:SetScript("OnClick", function()
    mainFrame:SelectExportPreset("Custom")
end)

mainFrame.exportHeaderToggleButton:SetScript("OnClick", function()
    mainFrame:ToggleExportHeader()
end)

mainFrame.exportApplyCustomButton:SetScript("OnClick", function()
    mainFrame:ApplyCustomExportTemplate()
end)

mainFrame.exportModalSelectAllButton:SetScript("OnClick", function()
    mainFrame.exportModalOutputInput:HighlightText(0, -1)
    if type(mainFrame.exportModalOutputInput.SetFocus) == "function" then
        mainFrame.exportModalOutputInput:SetFocus()
    end
end)

mainFrame.exportModalCopyButton:SetScript("OnClick", function()
    mainFrame.exportModalOutputInput.lastCopiedText = mainFrame.exportModalOutputInput:GetText() or ""
    mainFrame.exportModalOutputInput:HighlightText(0, -1)
    if type(mainFrame.exportModalOutputInput.SetFocus) == "function" then
        mainFrame.exportModalOutputInput:SetFocus()
    end
end)

mainFrame.exportModalCloseButton:SetScript("OnClick", function()
    mainFrame.exportModal:Hide()
end)

mainFrame.optionsTitle = mainFrame.optionsTitle or make_label(mainFrame.optionsAppearancePanel, "Window Transparency", "GameFontHighlight")
mainFrame.optionsTitle:SetPoint("TOPLEFT", mainFrame.optionsAppearancePanel, "TOPLEFT", 16, -16)

mainFrame.optionsHint = mainFrame.optionsHint or make_label(mainFrame.optionsAppearancePanel, "Adjust shell opacity with a slider and keep the percentage visible.", "GameFontHighlightSmall")
mainFrame.optionsHint:SetPoint("TOPLEFT", mainFrame.optionsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.transparencySlider = mainFrame.transparencySlider or make_slider(mainFrame.optionsAppearancePanel, 220, 18, 55, 100, math.floor(mainFrame.currentAlpha * 100 + 0.5))
mainFrame.transparencySlider:SetPoint("TOPLEFT", mainFrame.optionsHint, "BOTTOMLEFT", 0, -18)

mainFrame.transparencyValueText = mainFrame.transparencyValueText or make_label(mainFrame.optionsAppearancePanel, "", "GameFontNormal")
mainFrame.transparencyValueText:SetPoint("LEFT", mainFrame.transparencySlider, "RIGHT", 16, 0)

mainFrame.optionsRestockTitle = mainFrame.optionsRestockTitle or make_label(mainFrame.optionsRestockPanel, "Restock Default", "GameFontHighlight")
mainFrame.optionsRestockTitle:SetPoint("TOPLEFT", mainFrame.optionsRestockPanel, "TOPLEFT", 16, -16)

mainFrame.optionsRestockHint = mainFrame.optionsRestockHint or make_label(mainFrame.optionsRestockPanel, "Save Min stores the maximum amount allowed for restock when new rows are staged.", "GameFontHighlightSmall")
mainFrame.optionsRestockHint:SetPoint("TOPLEFT", mainFrame.optionsRestockTitle, "BOTTOMLEFT", 0, -8)

mainFrame.defaultMinimumInput = mainFrame.defaultMinimumInput or make_input(mainFrame.optionsRestockPanel, 72, 22)
mainFrame.defaultMinimumInput:SetPoint("TOPLEFT", mainFrame.optionsRestockHint, "BOTTOMLEFT", 0, -16)

mainFrame.defaultMinimumSaveButton = mainFrame.defaultMinimumSaveButton or make_button(mainFrame.optionsRestockPanel, 86, 28, "Save Min")
mainFrame.defaultMinimumSaveButton:SetPoint("LEFT", mainFrame.defaultMinimumInput, "RIGHT", 8, 0)

local function refresh_alpha_text()
    local percentage = math.floor(mainFrame.currentAlpha * 100 + 0.5)
    mainFrame.transparencyValueText:SetText(string.format("Opacity %d%%", percentage))
end

mainFrame.transparencySlider:SetScript("OnValueChanged", function(_, value)
    set_alpha((value or 100) / 100)
    refresh_alpha_text()
end)
mainFrame.transparencySlider:SetValue(math.floor(mainFrame.currentAlpha * 100 + 0.5))

mainFrame.defaultMinimumSaveButton:SetScript("OnClick", function()
    mainFrame:SaveDefaultMinimumSetting()
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
    local sidebarWidth = self.collapsedSidebar and theme.spacing.sidebarCollapsed or theme.spacing.sidebarExpanded
    self.sidebar:SetWidth(sidebarWidth)
    apply_panel_style(self, theme.colors.background)
    apply_panel_style(self.sidebar, theme.colors.panel)
    apply_panel_style(self.topBar, theme.colors.panelAlt)
    apply_panel_style(self.content, theme.colors.background)
    apply_panel_style(self.optionsPanel, theme.colors.panel)
    apply_panel_style(self.optionsAppearancePanel, theme.colors.panelAlt)
    apply_panel_style(self.optionsRestockPanel, theme.colors.panelAlt)
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
    apply_panel_style(self.tableScrollFrame, theme.colors.background)

    for _, card in ipairs(self.dashboardCards) do
        apply_panel_style(card, theme.colors.panel)
    end

    for _, button in ipairs(self.sidebarButtons) do
        local isActive = button.key == self.activeView
        apply_panel_style(button, isActive and theme.colors.panelAlt or theme.colors.panel)
        button:SetWidth(self.collapsedSidebar and 40 or (theme.spacing.sidebarExpanded - 32))
        button.labelText:SetText(self.collapsedSidebar and "" or button.key:sub(1, 1) .. string.lower(button.key:sub(2)))
    end

    self.collapseButton.labelText:SetText(self.collapsedSidebar and ">" or "<")
    if self.activeView == "OPTIONS" then
        self.optionsPanel:Show()
    else
        self.optionsPanel:Hide()
    end
    apply_panel_style(self.closeButton, theme.colors.panel)
    apply_panel_style(self.scanButton, theme.colors.panelAlt)
    apply_panel_style(self.collapseButton, theme.colors.panel)
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
    for _, button in ipairs(self.minimumAddMatchButtons or {}) do
        apply_panel_style(button, theme.colors.panel)
    end
    apply_panel_style(self.exportPresetSpreadsheetButton, theme.colors.panelAlt)
    apply_panel_style(self.exportPresetAuctionatorButton, theme.colors.panel)
    apply_panel_style(self.exportPresetCustomButton, theme.colors.panel)
    apply_panel_style(self.exportHeaderToggleButton, theme.colors.panel)
    apply_panel_style(self.exportApplyCustomButton, theme.colors.panelAlt)
    apply_panel_style(self.exportModalSelectAllButton, theme.colors.panel)
    apply_panel_style(self.exportModalCopyButton, theme.colors.panelAlt)
    apply_panel_style(self.exportModalCloseButton, theme.colors.panel)
    apply_panel_style(self.transparencySlider, theme.colors.background)
    apply_panel_style(self.tableScrollBar, theme.colors.panel)
    apply_panel_style(self.tableScrollBar.track, theme.colors.background)
    apply_panel_style(self.tableScrollBar.thumb, theme.colors.accent)
    apply_panel_style(self.tableScrollBar.scrollUpButton, theme.colors.panelAlt)
    apply_panel_style(self.tableScrollBar.scrollDownButton, theme.colors.panelAlt)

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
    db.ui = db.ui or {}
    db.ui.inventoryColumnWidths = db.ui.inventoryColumnWidths or {}

    local defaults = inventoryView.GetDefaultColumns()
    for columnIndex, column in ipairs(self.tableColumnLayout) do
        db.ui.inventoryColumnWidths[columnIndex] = (column.width or 0) - (defaults[columnIndex].width or 0)
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

function mainFrame:GetMinimumSettings(db)
    local minimumsView = ns.modules.minimumsView
    if type(minimumsView) == "table" and type(minimumsView.GetMinimumSettings) == "function" then
        return minimumsView.GetMinimumSettings(db or current_db())
    end

    db = db or current_db()
    db.ui = db.ui or {}
    db.ui.minimumSettings = db.ui.minimumSettings or { defaultQuantity = 100 }
    db.ui.minimumSettings.defaultQuantity = tonumber(db.ui.minimumSettings.defaultQuantity or 100) or 100
    return db.ui.minimumSettings
end

function mainFrame:LoadMinimumSettingsFromDb(db)
    local settings = self:GetMinimumSettings(db)
    self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity or 100))
    if (self.minimumAddQuantityInput:GetText() or "") == "" then
        self.minimumAddQuantityInput:SetText(tostring(settings.defaultQuantity or 100))
    end
    return settings
end

function mainFrame:SaveDefaultMinimumSetting()
    local settings = self:GetMinimumSettings(current_db())
    settings.defaultQuantity = parse_number(self.defaultMinimumInput:GetText() or "") or 100
    self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity))
    return settings.defaultQuantity
end

function mainFrame:ApplyMinimumFilters()
    local minimumsView = ns.modules.minimumsView
    local db = current_db()
    local snapshot = self:GetCurrentSnapshot()
    self.minimumManualOnlyRows = false
    if self.minimumPendingDb ~= db then
        self.minimumPendingDb = db
        self.minimumPendingRules = {}
        self.minimumPendingDirty = {}
        self.minimumPendingDeleted = {}
        self.minimumSessionBaseline = {}
        for _, rule in ipairs(db.minimums or {}) do
            table.insert(self.minimumSessionBaseline, self:CloneMinimumRule(rule))
        end
        self.selectedMinimumKey = nil
    end
    local layout = minimumsView.GetDefaultColumns()
    local rows = minimumsView.BuildTableRows(self:GetMergedMinimumRules(db), snapshot, {
        showAll = self.minimumShowAllRows,
        search = self.minimumSearchInput:GetText() or "",
        manualOnly = false,
        columnFilters = self:GetSharedFilterState(),
    })

    rows = minimumsView.SortRows(rows, self.minimumSortState)
    self.tableColumnLayout = layout
    self.tableScrollOffset = 0
    self.cachedMinimumRows = rows
    self:ConfigureTable(layout, rows)
    self:RefreshVisibleTableRows()

    local emptyStateText = self:GetMinimumEmptyStateText(rows)
    self.minimumEmptyStateText:SetText(emptyStateText)
    if emptyStateText ~= "" then
        self.minimumEmptyStateText:Show()
    else
        self.minimumEmptyStateText:Hide()
    end
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

function mainFrame:LoadMinimumRuleIntoEditor(rule)
    self.selectedMinimumKey = (rule or {}).draftKey or minimum_rule_key(rule)
    return rule
end

function mainFrame:ClearMinimumEditor()
    self.selectedMinimumKey = nil
    self.selectedMinimumEnabled = true
end

function mainFrame:CloneMinimumRule(rule)
    rule = rule or {}
    return {
        itemID = rule.itemID,
        itemName = rule.itemName,
        quantity = rule.quantity,
        scope = rule.scope,
        tabName = rule.tabName,
        enabled = rule.enabled,
        craftedQuality = rule.craftedQuality,
        craftedQualityIcon = rule.craftedQualityIcon,
        draftKey = rule.draftKey,
        originalItemID = rule.originalItemID,
        originalScope = rule.originalScope,
        originalTabName = rule.originalTabName,
    }
end

function mainFrame:GetMinimumBaselineRule(rowOrKey)
    local rowKey = rowOrKey
    if type(rowOrKey) == "table" then
        rowKey = rowOrKey.rowKey or rowOrKey.draftKey or minimum_rule_key(rowOrKey)
    end

    for _, rule in ipairs(self.minimumSessionBaseline or {}) do
        local baselineKey = rule.draftKey or minimum_rule_key(rule)
        if baselineKey == rowKey then
            return self:CloneMinimumRule(rule)
        end
    end

    return nil
end

function mainFrame:BuildMinimumRuleFromRow(row)
    if not row then
        return nil
    end

    local quantity = tonumber(row.quantityValue or row.quantity or 0) or 0
    local scope = row.scope or "TAB"
    local tabName = row.tabKey
    if row.configured ~= true then
        quantity = self:GetMinimumSettings(current_db()).defaultQuantity or 100
        scope = "TAB"
        tabName = nil
    end

    return {
        itemID = tonumber(row.itemID),
        itemName = row.itemName,
        quantity = quantity,
        scope = scope,
        tabName = (tabName and tabName ~= "" and tabName) or nil,
        enabled = row.restock == "Yes",
        craftedQuality = row.craftedQuality,
        craftedQualityIcon = row.craftedQualityIcon,
        draftKey = row.rowKey,
        originalItemID = row.originalItemID or tonumber(row.itemID),
        originalScope = row.originalScope or row.scope,
        originalTabName = row.originalTabName,
    }
end

function mainFrame:GetPendingMinimumDraft(row)
    if not row then
        return nil
    end

    self.minimumPendingRules = self.minimumPendingRules or {}
    self.minimumPendingDirty = self.minimumPendingDirty or {}
    local draft = self.minimumPendingRules[row.rowKey]
    if draft then
        return draft
    end

    draft = self:BuildMinimumRuleFromRow(row)
    self.minimumPendingRules[row.rowKey] = draft
    return draft
end

function mainFrame:GetMinimumDraftState(row)
    if not row then
        return nil
    end

    if (self.minimumPendingDeleted or {})[row.rowKey] then
        return "deleted"
    end

    if not (self.minimumPendingDirty or {})[row.rowKey] then
        return nil
    end

    if self:GetMinimumBaselineRule(row) then
        return "changed"
    end

    return "added"
end

function mainFrame:GetMergedMinimumRules(db)
    local minimumsView = ns.modules.minimumsView
    local merged = {}

    for _, rule in ipairs((db or {}).minimums or {}) do
        table.insert(merged, self:CloneMinimumRule(rule))
    end

    for _, pending in pairs(self.minimumPendingRules or {}) do
        merged = minimumsView.Upsert(merged, self:CloneMinimumRule(pending))
    end

    return merged
end

function mainFrame:HideMinimumInlineRow(rowFrame)
    if not rowFrame then
        return
    end

    if rowFrame.minimumValueInput then
        rowFrame.minimumValueInput:Hide()
    end
    if rowFrame.restockToggleButton then
        rowFrame.restockToggleButton:Hide()
    end
    if rowFrame.bankTabValueInput then
        rowFrame.bankTabValueInput:Hide()
    end
    if rowFrame.bankTabDropdownButton then
        rowFrame.bankTabDropdownButton:Hide()
    end
    if rowFrame.bankTabDropdownPanel then
        rowFrame.bankTabDropdownPanel:Hide()
    end
    if rowFrame.removeButton then
        rowFrame.removeButton:Hide()
    end
    if rowFrame.undoButton then
        rowFrame.undoButton:Hide()
    end
end

function mainFrame:ApplyMinimumDraftStyle(rowFrame, rowIndex, draftState)
    if not rowFrame then
        return
    end

    local tintByState = {
        added = "green",
        changed = "yellow",
        deleted = "red",
    }

    rowFrame.minimumDraftState = draftState
    rowFrame.minimumDraftTint = tintByState[draftState]
    rowFrame.minimumDraftIndicator = rowFrame.minimumDraftIndicator or _G.CreateFrame("Frame", nil, rowFrame, "BackdropTemplate")
    rowFrame.minimumDraftIndicator:ClearAllPoints()
    rowFrame.minimumDraftIndicator:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 1, -1)
    rowFrame.minimumDraftIndicator:SetPoint("BOTTOMLEFT", rowFrame, "BOTTOMLEFT", 1, 1)
    rowFrame.minimumDraftIndicator:SetWidth(8)

    if draftState and MINIMUM_DRAFT_ROW_COLORS[draftState] then
        apply_panel_style(rowFrame, MINIMUM_DRAFT_ROW_COLORS[draftState])
        apply_panel_style(rowFrame.minimumDraftIndicator, MINIMUM_DRAFT_ROW_COLORS[draftState])
        rowFrame.minimumDraftIndicator:Show()
        rowFrame.isSelected = self:IsSelectedTableRow(rowFrame.rowData)
        return
    end

    rowFrame.minimumDraftTint = nil
    rowFrame.minimumDraftIndicator:Hide()
    apply_table_row_style(rowFrame, rowIndex, self:IsSelectedTableRow(rowFrame.rowData))
end

function mainFrame:UndoMinimumRow(row)
    if not row then
        return nil
    end

    self.minimumPendingRules = self.minimumPendingRules or {}
    self.minimumPendingDirty = self.minimumPendingDirty or {}
    self.minimumPendingDeleted = self.minimumPendingDeleted or {}
    self.minimumPendingRules[row.rowKey] = nil
    self.minimumPendingDirty[row.rowKey] = nil
    self.minimumPendingDeleted[row.rowKey] = nil

    if self.selectedMinimumKey == row.rowKey and not self:GetMinimumBaselineRule(row) then
        self.selectedMinimumKey = nil
    end

    self:ApplyMinimumFilters()
    return row
end

function mainFrame:MarkMinimumRowDeleted(row)
    if not row then
        return nil
    end

    if not self:GetMinimumBaselineRule(row) then
        return self:UndoMinimumRow(row)
    end

    self.minimumPendingRules = self.minimumPendingRules or {}
    self.minimumPendingDirty = self.minimumPendingDirty or {}
    self.minimumPendingDeleted = self.minimumPendingDeleted or {}
    self.minimumPendingRules[row.rowKey] = nil
    self.minimumPendingDirty[row.rowKey] = nil
    self.minimumPendingDeleted[row.rowKey] = true
    self.selectedMinimumKey = row.rowKey
    self:ApplyMinimumFilters()
    return row
end

function mainFrame:GetKnownMinimumBankTabs(row)
    local tabs = {}
    local seen = {}

    local function add_tab(tabName)
        tabName = tostring(tabName or "")
        if tabName == "" or seen[tabName] then
            return
        end
        seen[tabName] = true
        table.insert(tabs, tabName)
    end

    for _, rule in ipairs(self:GetMergedMinimumRules(current_db()) or {}) do
        add_tab(rule.tabName)
    end

    for _, item in pairs((self:GetCurrentSnapshot() or {}).items or {}) do
        for tabName in pairs(item.tabs or {}) do
            add_tab(tabName)
        end
    end

    if type(row) == "table" then
        add_tab(row.tabName)
        add_tab(row.tabKey)
        add_tab(row.bankTab)
    end

    table.sort(tabs)
    return tabs
end

function mainFrame:RememberMinimumSearchItem(item)
    local db = current_db()
    db.ui = db.ui or {}
    db.ui.minimumItemCatalog = db.ui.minimumItemCatalog or {}

    local itemID = tonumber((item or {}).itemID)
    local itemName = tostring((item or {}).name or (item or {}).itemName or "")
    if not itemID or itemName == "" then
        return nil
    end

    for _, existing in ipairs(db.ui.minimumItemCatalog) do
        if tonumber(existing.itemID) == itemID then
            existing.name = itemName
            existing.craftedQuality = (item or {}).craftedQuality or existing.craftedQuality
            existing.craftedQualityIcon = (item or {}).craftedQualityIcon or existing.craftedQualityIcon
            return existing
        end
    end

    local entry = {
        itemID = itemID,
        name = itemName,
        craftedQuality = (item or {}).craftedQuality,
        craftedQualityIcon = (item or {}).craftedQualityIcon,
    }
    table.insert(db.ui.minimumItemCatalog, entry)
    return entry
end

function mainFrame:GetMinimumSearchSnapshot()
    local snapshot = self:GetCurrentSnapshot()
    local db = current_db()
    local searchCatalog = {}

    local function append_catalog_item(item)
        if type(item) ~= "table" then
            return
        end

        local itemID = tonumber(item.itemID)
        local itemName = tostring(item.name or item.itemName or "")
        if not itemID or itemName == "" then
            return
        end

        searchCatalog[#searchCatalog + 1] = {
            itemID = itemID,
            name = itemName,
            craftedQuality = item.craftedQuality,
            craftedQualityIcon = item.craftedQualityIcon,
        }
    end

    for _, item in ipairs(((db.ui or {}).minimumItemCatalog) or {}) do
        append_catalog_item(item)
    end

    for _, item in ipairs(db.minimums or {}) do
        append_catalog_item(item)
    end

    for _, item in ipairs(db.requests or {}) do
        append_catalog_item(item)
    end

    for _, item in ipairs(db.oneTimeTargets or {}) do
        append_catalog_item(item)
    end

    snapshot.searchCatalog = searchCatalog
    return snapshot
end

function mainFrame:ConfigureMinimumBankTabDropdown(rowFrame, row, rowIndex, state)
    if not rowFrame or not row then
        return
    end

    rowFrame.bankTabDropdownButton = rowFrame.bankTabDropdownButton or make_button(rowFrame, 104, 20, "")
    rowFrame.bankTabDropdownPanel = rowFrame.bankTabDropdownPanel or _G.CreateFrame("Frame", nil, rowFrame, "BackdropTemplate")
    apply_panel_style(rowFrame.bankTabDropdownPanel, theme.colors.panelAlt)
    rowFrame.bankTabDropdownOptions = rowFrame.bankTabDropdownOptions or {}

    rowFrame.bankTabDropdownButton:ClearAllPoints()
    rowFrame.bankTabDropdownButton:SetPoint("LEFT", rowFrame.columns[4], "LEFT", -4, 0)
    rowFrame.bankTabDropdownButton:SetWidth(math.max(96, (self.tableColumnLayout[4] and self.tableColumnLayout[4].width or 110) - 12))
    rowFrame.bankTabDropdownButton.labelText:SetText(((state and state.tabName) and state.tabName ~= "") and state.tabName or "Select Bank Tab")

    rowFrame.bankTabDropdownPanel:ClearAllPoints()
    rowFrame.bankTabDropdownPanel:SetPoint("TOPLEFT", rowFrame.bankTabDropdownButton, "BOTTOMLEFT", 0, -2)

    local tabOptions = self:GetKnownMinimumBankTabs(row)
    rowFrame.bankTabDropdownPanel:SetSize(rowFrame.bankTabDropdownButton:GetWidth(), math.max(28, (#tabOptions * 24) + 8))

    for index, tabName in ipairs(tabOptions) do
        local option = rowFrame.bankTabDropdownOptions[index] or make_button(rowFrame.bankTabDropdownPanel, rowFrame.bankTabDropdownButton:GetWidth() - 8, 22, "")
        option.value = tabName
        option:ClearAllPoints()
        option:SetPoint("TOPLEFT", rowFrame.bankTabDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
        option:SetWidth(rowFrame.bankTabDropdownButton:GetWidth() - 8)
        option.labelText:SetText(tabName)
        option:SetScript("OnClick", function()
            local current = self:GetPendingMinimumDraft(row)
            current.tabName = tabName
            current.scope = "TAB"
            self.minimumPendingDirty = self.minimumPendingDirty or {}
            self.minimumPendingDeleted = self.minimumPendingDeleted or {}
            self.minimumPendingDirty[row.rowKey] = true
            self.minimumPendingDeleted[row.rowKey] = nil
            rowFrame.bankTabDropdownButton.labelText:SetText(tabName)
            rowFrame.bankTabDropdownPanel:Hide()
            self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
        end)
        option:Show()
        rowFrame.bankTabDropdownOptions[index] = option
    end

    for index = #tabOptions + 1, #(rowFrame.bankTabDropdownOptions or {}) do
        rowFrame.bankTabDropdownOptions[index]:Hide()
    end

    rowFrame.bankTabDropdownPanel:Hide()
    rowFrame.bankTabDropdownButton:SetScript("OnClick", function()
        if rowFrame.bankTabDropdownPanel:IsShown() then
            rowFrame.bankTabDropdownPanel:Hide()
        else
            rowFrame.bankTabDropdownPanel:Show()
        end
    end)
end

function mainFrame:SyncMinimumInlineRow(rowFrame, row, rowIndex)
    if not rowFrame then
        return
    end

    rowFrame.minimumValueInput = rowFrame.minimumValueInput or make_input(rowFrame, 52, 18)
    rowFrame.restockToggleButton = rowFrame.restockToggleButton or make_button(rowFrame, 58, 20, "Yes")
    rowFrame.bankTabValueInput = rowFrame.bankTabValueInput or make_input(rowFrame, 74, 18)
    rowFrame.removeButton = rowFrame.removeButton or make_button(rowFrame, 20, 20, "-")
    rowFrame.undoButton = rowFrame.undoButton or make_button(rowFrame, 20, 20, "<")

    apply_panel_style(rowFrame.minimumValueInput, theme.colors.background)
    apply_panel_style(rowFrame.restockToggleButton, theme.colors.panel)
    apply_panel_style(rowFrame.bankTabValueInput, theme.colors.background)
    apply_panel_style(rowFrame.removeButton, MINIMUM_DRAFT_ROW_COLORS.deleted)
    apply_panel_style(rowFrame.undoButton, theme.colors.panelAlt)
    set_button_icon(rowFrame.removeButton, "remove")
    set_button_icon(rowFrame.undoButton, "undo")

    rowFrame.bankTabValueInput:ClearAllPoints()
    rowFrame.bankTabValueInput:SetPoint("LEFT", rowFrame.columns[4], "LEFT", -4, 0)
    rowFrame.bankTabValueInput:SetWidth((self.tableColumnLayout[4] and self.tableColumnLayout[4].width or 110) - 12)

    rowFrame.minimumValueInput:ClearAllPoints()
    rowFrame.minimumValueInput:SetPoint("LEFT", rowFrame.columns[7], "LEFT", -4, 0)
    rowFrame.minimumValueInput:SetWidth((self.tableColumnLayout[7] and self.tableColumnLayout[7].width or 70) - 12)

    rowFrame.restockToggleButton:ClearAllPoints()
    rowFrame.restockToggleButton:SetPoint("LEFT", rowFrame.columns[6], "LEFT", -4, 0)
    rowFrame.restockToggleButton:SetWidth((self.tableColumnLayout[6] and self.tableColumnLayout[6].width or 70) - 12)

    rowFrame.removeButton:ClearAllPoints()
    rowFrame.removeButton:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -6, -1)

    rowFrame.undoButton:ClearAllPoints()
    rowFrame.undoButton:SetPoint("RIGHT", rowFrame.removeButton, "LEFT", -4, 0)

    if not row or self.selectedMinimumKey ~= row.rowKey then
        self:HideMinimumInlineRow(rowFrame)
        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, row and self:GetMinimumDraftState(row) or nil)
        if row and self:GetMinimumBaselineRule(row) and row.restock == "Yes" and self:GetMinimumDraftState(row) ~= "added" then
            rowFrame.removeButton:Show()
        else
            rowFrame.removeButton:Hide()
        end
        if row and self:GetMinimumDraftState(row) ~= nil then
            rowFrame.undoButton:Show()
        else
            rowFrame.undoButton:Hide()
        end
        rowFrame.removeButton:SetScript("OnClick", function()
            self:MarkMinimumRowDeleted(row)
        end)
        rowFrame.undoButton:SetScript("OnClick", function()
            self:UndoMinimumRow(row)
        end)
        return
    end

    local state = self:GetPendingMinimumDraft(row)
    local draftState = self:GetMinimumDraftState(row)
    local isDeleted = draftState == "deleted"
    local baselineRule = self:GetMinimumBaselineRule(row)
    local allowBankTabSelection = baselineRule == nil
    rowFrame.syncingMinimumDraft = true
    rowFrame.bankTabValueInput:SetText(state.tabName or "")
    rowFrame.minimumValueInput:SetText(tostring(state.quantity or 0))
    rowFrame.syncingMinimumDraft = false
    rowFrame.restockToggleButton.labelText:SetText(state.enabled and "Yes" or "No")

    self:ApplyMinimumDraftStyle(rowFrame, rowIndex, draftState)
    self:ConfigureMinimumBankTabDropdown(rowFrame, row, rowIndex, state)

    if isDeleted then
        rowFrame.columns[4]:SetText(state.tabName or "")
        rowFrame.columns[6]:SetText(state.enabled and "Yes" or "No")
        rowFrame.columns[7]:SetText(tostring(state.quantity or 0))
        rowFrame.bankTabValueInput:Hide()
        if rowFrame.bankTabDropdownButton then
            rowFrame.bankTabDropdownButton:Hide()
        end
        if rowFrame.bankTabDropdownPanel then
            rowFrame.bankTabDropdownPanel:Hide()
        end
        rowFrame.minimumValueInput:Hide()
        rowFrame.restockToggleButton:Hide()
    else
        rowFrame.columns[6]:SetText("")
        rowFrame.columns[7]:SetText("")
        if allowBankTabSelection then
            rowFrame.columns[4]:SetText("")
            rowFrame.bankTabValueInput:Hide()
            if rowFrame.bankTabDropdownButton then
                rowFrame.bankTabDropdownButton:Show()
            end
        else
            rowFrame.columns[4]:SetText(state.tabName or "")
            rowFrame.bankTabValueInput:Hide()
            if rowFrame.bankTabDropdownButton then
                rowFrame.bankTabDropdownButton:Hide()
            end
            if rowFrame.bankTabDropdownPanel then
                rowFrame.bankTabDropdownPanel:Hide()
            end
        end
        rowFrame.minimumValueInput:Show()
        rowFrame.restockToggleButton:Show()
    end
    rowFrame.removeButton:Show()
    if draftState ~= nil then
        rowFrame.undoButton:Show()
    else
        rowFrame.undoButton:Hide()
    end

    rowFrame.removeButton:SetScript("OnClick", function()
        self:MarkMinimumRowDeleted(row)
    end)

    rowFrame.undoButton:SetScript("OnClick", function()
        self:UndoMinimumRow(row)
    end)

    rowFrame.restockToggleButton:SetScript("OnClick", function()
        local current = self:GetPendingMinimumDraft(row)
        current.enabled = not current.enabled
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingDirty[row.rowKey] = true
        self.minimumPendingDeleted[row.rowKey] = nil
        rowFrame.restockToggleButton.labelText:SetText(current.enabled and "Yes" or "No")
        if self.selectedMinimumKey ~= row.rowKey then
            rowFrame.columns[6]:SetText(current.enabled and "Yes" or "No")
        end
        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
    end)

    rowFrame.minimumValueInput:SetScript("OnTextChanged", function(input)
        if rowFrame.syncingMinimumDraft then
            return
        end
        local current = self:GetPendingMinimumDraft(row)
        current.quantity = parse_number(input:GetText() or "") or current.quantity or 0
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingDirty[row.rowKey] = true
        self.minimumPendingDeleted[row.rowKey] = nil
        if self.selectedMinimumKey ~= row.rowKey then
            rowFrame.columns[7]:SetText(tostring(current.quantity or 0))
        end
        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
    end)

    rowFrame.bankTabValueInput:SetScript("OnTextChanged", function(input)
        if rowFrame.syncingMinimumDraft then
            return
        end
        local current = self:GetPendingMinimumDraft(row)
        current.tabName = input:GetText() or ""
        current.scope = "TAB"
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingDirty[row.rowKey] = true
        self.minimumPendingDeleted[row.rowKey] = nil
        if self.selectedMinimumKey ~= row.rowKey then
            rowFrame.columns[4]:SetText(current.tabName or "")
        end
        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
    end)

    rowFrame.minimumValueInput:SetScript("OnEditFocusLost", function()
        self:ApplyMinimumFilters()
    end)

    rowFrame.bankTabValueInput:SetScript("OnEditFocusLost", function()
        self:ApplyMinimumFilters()
    end)
end

function mainFrame:HideMinimumVariantButtons()
    for _, button in ipairs(self.minimumAddMatchButtons or {}) do
        button:Hide()
    end
    if self.minimumAddResultsPanel then
        self.minimumAddResultsPanel:Hide()
    end
end

function mainFrame:ApplyMinimumResolvedItem(item)
    if not item then
        return nil
    end

    self:RememberMinimumSearchItem(item)
    self.isResolvingMinimumAdd = true
    self.minimumAddItemIDInput:SetText(tostring(item.itemID or ""))
    self.minimumAddItemNameInput:SetText(item.name or "")
    self.minimumScopeInput:SetText("TAB")
    self.isResolvingMinimumAdd = false

    return item
end

function mainFrame:ResolveMinimumAddByItemID()
    local minimumsView = ns.modules.minimumsView
    local resolution = minimumsView.ResolveItemQuery(self:GetMinimumSearchSnapshot(), self.minimumAddItemIDInput:GetText() or "")
    self:HideMinimumVariantButtons()

    if resolution.status == "resolved" then
        self:ApplyMinimumResolvedItem(resolution.item)
        return resolution.item
    end

    return nil
end

function mainFrame:ResolveMinimumAddByName()
    local minimumsView = ns.modules.minimumsView
    local resolution = minimumsView.ResolveItemQuery(self:GetMinimumSearchSnapshot(), self.minimumAddItemNameInput:GetText() or "")
    self.minimumAddResolvedMatches = resolution.matches or {}
    self:HideMinimumVariantButtons()

    if resolution.status == "resolved" then
        return self:ApplyMinimumResolvedItem(resolution.item)
    end

    if resolution.status == "multiple" then
        if self.minimumAddResultsPanel then
            self.minimumAddResultsPanel:Show()
        end
        for index, item in ipairs(self.minimumAddResolvedMatches) do
            local button = self.minimumAddMatchButtons[index]
            if button then
                button.labelText:SetText(string.format("%s (%s)", item.name or "", tostring(item.itemID or "")))
                button:SetScript("OnClick", function()
                    self:ApplyMinimumResolvedItem(item)
                    self:HideMinimumVariantButtons()
                end)
                button:Show()
            end
        end
    end

    return nil
end

function mainFrame:ResetMinimumAddRow()
    self.minimumAddItemIDInput:SetText("")
    self.minimumAddItemNameInput:SetText("")
    self.minimumAddBankTabInput:SetText("")
    self.minimumAddQuantityInput:SetText(tostring((self:GetMinimumSettings(current_db()).defaultQuantity or 100)))
    self.minimumScopeInput:SetText("TAB")
    self.minimumRestockToggleButton.labelText:SetText("Restock: Yes")
    self.selectedMinimumEnabled = true
    self:HideMinimumVariantButtons()
end

function mainFrame:OpenMinimumAddModal()
    self:ResetMinimumAddRow()
    self.minimumAddModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(self.minimumAddModal.SetFrameStrata) == "function" then
        self.minimumAddModal:SetFrameStrata(self.minimumAddModal.frameStrata)
    end
    self.minimumAddModal.frameLevel = (self.frameLevel or 0) + 20
    if type(self.minimumAddModal.SetFrameLevel) == "function" then
        self.minimumAddModal:SetFrameLevel(self.minimumAddModal.frameLevel)
    end
    self.minimumAddModal:Show()
    return self.minimumAddModal
end

function mainFrame:HideMinimumAddModal()
    self.minimumAddModal:Hide()
    self:ResetMinimumAddRow()
    return self.minimumAddModal
end

function mainFrame:CreateMinimumFromAddRow()
    local itemID = parse_number(self.minimumAddItemIDInput:GetText() or "")
    local quantity = parse_number(self.minimumAddQuantityInput:GetText() or "")
    local itemName = self.minimumAddItemNameInput:GetText() or ""

    if not itemID or itemName == "" or not quantity then
        return nil
    end

    local draftKey = table.concat({ "draft", tostring(itemID), tostring(_G.time()), tostring(math.random(1000, 9999)) }, "|")
    local rule = {
        itemID = itemID,
        itemName = itemName,
        quantity = quantity,
        scope = "TAB",
        tabName = nil,
        enabled = self.selectedMinimumEnabled ~= false,
        draftKey = draftKey,
        originalItemID = itemID,
        originalScope = "TAB",
        originalTabName = nil,
    }

    self:RememberMinimumSearchItem({
        itemID = itemID,
        name = itemName,
    })

    self.minimumPendingRules = self.minimumPendingRules or {}
    self.minimumPendingDirty = self.minimumPendingDirty or {}
    self.minimumPendingDeleted = self.minimumPendingDeleted or {}
    self.minimumPendingRules[draftKey] = rule
    self.minimumPendingDirty[draftKey] = true
    self.minimumPendingDeleted[draftKey] = nil
    self.selectedMinimumKey = draftKey
    self:HideMinimumAddModal()
    self:ApplyMinimumFilters()
    return rule
end

function mainFrame:SaveAllMinimumChanges()
    local minimumsView = ns.modules.minimumsView
    local db = current_db()
    local changed = false

    for key in pairs(self.minimumPendingDeleted or {}) do
        local pending = (self.minimumPendingRules or {})[key] or self:GetMinimumBaselineRule(key)
        if pending then
            minimumsView.RemoveWithAudit(db, self:CloneMinimumRule(pending), {
                actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
                timestamp = _G.time(),
            })
            changed = true
        end
    end

    for key, rule in pairs(self.minimumPendingRules or {}) do
        if not (self.minimumPendingDeleted or {})[key] and (self.minimumPendingDirty or {})[key] then
            local normalized = self:CloneMinimumRule(rule)
            if (tonumber(normalized.quantity or 0) or 0) <= 0 then
                normalized.enabled = false
            end
            local scope = tostring(normalized.scope or "TAB")
            local hasRequiredTabName = scope ~= "TAB" or tostring(normalized.tabName or "") ~= ""
            if tonumber(normalized.itemID) and tostring(normalized.itemName or "") ~= "" and hasRequiredTabName then
                minimumsView.UpsertWithAudit(db, normalized, {
                    actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
                    timestamp = _G.time(),
                })
                changed = true
            end
        end
    end

    if changed then
        self.minimumPendingRules = {}
        self.minimumPendingDirty = {}
        self.minimumPendingDeleted = {}
        self.minimumSessionBaseline = {}
        for _, rule in ipairs(db.minimums or {}) do
            table.insert(self.minimumSessionBaseline, self:CloneMinimumRule(rule))
        end
        self.selectedMinimumKey = nil
    end

    self:RefreshView()
    return changed
end

function mainFrame:UndoMinimumChanges()
    self.minimumPendingRules = {}
    self.minimumPendingDirty = {}
    self.minimumPendingDeleted = {}
    self.selectedMinimumKey = nil
    self:HideMinimumAddModal()
    self:RefreshView()
    return true
end

function mainFrame:ToggleMinimumShowAllRows()
    self.minimumShowAllRows = not self.minimumShowAllRows
    self.minimumShowAllToggleButton.labelText:SetText(self.minimumShowAllRows and "Enabled Only" or "Show All")
    self:RefreshView()
    return self.minimumShowAllRows
end

function mainFrame:ToggleMinimumManualOnlyRows()
    self.minimumManualOnlyRows = false
    self:ApplyMinimumFilters()
    return self.minimumManualOnlyRows
end

function mainFrame:GetMinimumEmptyStateText(rows)
    rows = rows or {}

    if #rows > 0 then
        return ""
    end

    if (self.minimumSearchInput:GetText() or "") ~= "" then
        return "No minimum rows match the current search and filters."
    end

    if not self.minimumShowAllRows then
        return "No enabled minimum rows yet. Toggle Show All or add a manual item."
    end

    return "No guild bank items or saved minimums are available yet."
end

function mainFrame:BuildExportRows()
    local exportsView = ns.modules.exportsView
    local db = current_db()
    local currentSnapshot = nil
    local planning = ns.modules.planning

    if db.currentSnapshotId ~= nil then
        currentSnapshot = (db.snapshots or {})[db.currentSnapshotId]
    end
    currentSnapshot = currentSnapshot or { items = {} }

    local demandPlan = {}
    if planning and type(planning.BuildDemandPlan) == "function" then
        demandPlan = planning.BuildDemandPlan({
            snapshot = currentSnapshot,
            minimums = db.minimums or {},
            oneTimeTargets = db.oneTimeTargets or {},
            requests = db.requests or {},
        })
    end

    local rows = exportsView and type(exportsView.BuildTableRows) == "function" and exportsView.BuildTableRows(demandPlan, currentSnapshot) or {}
    local db = current_db()

    for _, row in ipairs(rows) do
        if (tonumber(row.quality or 0) or 0) <= 0 then
            row.quality = export_quality_for_item(db, row.itemID)
        end
    end

    return rows, currentSnapshot
end

function mainFrame:GetCurrentSnapshot()
    local db = current_db()

    if db.currentSnapshotId ~= nil then
        return (db.snapshots or {})[db.currentSnapshotId] or { items = {} }
    end

    return { items = {} }
end

function mainFrame:GetExportUiState(db)
    db = db or current_db()
    db.ui = db.ui or {}
    db.ui.inventoryColumnWidths = db.ui.inventoryColumnWidths or {}
    db.ui.exportSettings = db.ui.exportSettings or {}
    db.ui.exportSettings.selectedPreset = normalize_export_preset_name(db.ui.exportSettings.selectedPreset)
    db.ui.exportSettings.shoppingListName = normalize_shopping_list_name(db.ui.exportSettings.shoppingListName)
    db.ui.exportSettings.customTemplate = clone_export_template(db.ui.exportSettings.customTemplate)
    return db.ui.exportSettings
end

function mainFrame:LoadExportSettingsFromDb(db)
    local exportSettings = self:GetExportUiState(db)
    self.exportSelectedPreset = normalize_export_preset_name(exportSettings.selectedPreset)
    self.exportShoppingListName = normalize_shopping_list_name(exportSettings.shoppingListName)
    self.exportCustomTemplate = clone_export_template(exportSettings.customTemplate)
    return exportSettings
end

function mainFrame:PersistExportSettings(db)
    local exportSettings = self:GetExportUiState(db)
    exportSettings.selectedPreset = normalize_export_preset_name(self.exportSelectedPreset)
    exportSettings.shoppingListName = normalize_shopping_list_name(self.exportShoppingListName)
    exportSettings.customTemplate = clone_export_template(self.exportCustomTemplate)
    return exportSettings
end

function mainFrame:RefreshExportControlVisibility()
    local showAuctionatorControls = uses_auctionator_controls(self.exportSelectedPreset)
    local showCustomControls = uses_custom_export_controls(self.exportSelectedPreset)

    set_frame_shown(self.exportAuctionatorListNameInput, showAuctionatorControls)
    set_frame_shown(self.exportDelimiterInput, showCustomControls)
    set_frame_shown(self.exportFieldsInput, showCustomControls)
    set_frame_shown(self.exportHeaderToggleButton, showCustomControls)
    set_frame_shown(self.exportApplyCustomButton, showCustomControls)
end

function mainFrame:RefreshExportModalScrollMetrics()
    local scrollFrame = self.exportModalScrollFrame
    local scrollChild = self.exportModalScrollChild
    local outputInput = self.exportModalOutputInput
    local lineHeight = 14
    local padding = 16
    local minimumInputHeight = 130
    local lineCount = count_lines(outputInput:GetText() or "")
    local contentHeight = math.max(minimumInputHeight, (lineCount * lineHeight) + 12)
    local childHeight = math.max(scrollFrame:GetHeight(), contentHeight + padding)

    outputInput:SetHeight(contentHeight)
    scrollChild:SetHeight(childHeight)
    scrollFrame.verticalScrollRange = math.max(0, childHeight - scrollFrame:GetHeight())
    scrollFrame:SetVerticalScroll(scrollFrame.verticalScroll or 0)
end

function mainFrame:RefreshExportOutput(rows)
    local exportDialog = ns.modules.exportDialog
    local exportState = {
        shoppingListName = normalize_shopping_list_name(self.exportShoppingListName),
    }

    for key, value in pairs(self.exportCustomTemplate or {}) do
        exportState[key] = value
    end

    local state = exportDialog and type(exportDialog.BuildPresetState) == "function" and exportDialog.BuildPresetState(rows or {}, self.exportSelectedPreset, exportState) or {
        presetName = normalize_export_preset_name(self.exportSelectedPreset),
        shoppingListName = exportState.shoppingListName,
        text = "",
    }

    self.exportSelectedPreset = normalize_export_preset_name(state.presetName or self.exportSelectedPreset)
    self.exportShoppingListName = normalize_shopping_list_name(state.shoppingListName or self.exportShoppingListName)
    self.exportsPresetTitle:SetText(self.exportSelectedPreset or "CSV")
    self.isRefreshingExportControls = true
    self.exportAuctionatorListNameInput:SetText(self.exportShoppingListName)
    self.isRefreshingExportControls = false
    self:RefreshExportControlVisibility()
    self.exportsOutputText:SetText("")
    self.exportsOutputText:Hide()
    self.exportModalTitle:SetText(string.format("%s Export", self.exportSelectedPreset or "CSV"))
    self.exportModalOutputInput:SetText(state.text or "")
    self:PersistExportSettings(ns.state.db or {})
    return state
end

function mainFrame:RefreshExportCustomControls()
    self.isRefreshingExportControls = true
    self.exportAuctionatorListNameInput:SetText(self.exportShoppingListName or "GBankManager")
    self.isRefreshingExportControls = false
    self.exportDelimiterInput:SetText(self.exportCustomTemplate.delimiter or "|")
    self.exportFieldsInput:SetText(table.concat(self.exportCustomTemplate.fields or {}, ","))
    self.exportHeaderToggleButton.labelText:SetText((self.exportCustomTemplate.includeHeader ~= false) and "Header: Yes" or "Header: No")
    self:RefreshExportControlVisibility()
end

function mainFrame:SelectExportPreset(presetName)
    self.exportSelectedPreset = normalize_export_preset_name(presetName)
    self:PersistExportSettings(ns.state.db or {})
    if self.activeView == "EXPORTS" then
        local rows = self.tableRowsData or {}
        self:RefreshExportOutput(rows)
        self.exportModal:Show()
    end
    return self.exportSelectedPreset
end

function mainFrame:BuildCustomExportTemplateFromControls()
    local fields = {}
    local rawFields = self.exportFieldsInput:GetText() or ""
    for token in string.gmatch(rawFields, "([^,]+)") do
        local field = token:gsub("^%s+", ""):gsub("%s+$", "")
        if field ~= "" then
            table.insert(fields, field)
        end
    end

    return {
        delimiter = (self.exportDelimiterInput:GetText() or "") ~= "" and (self.exportDelimiterInput:GetText() or "") or "|",
        includeHeader = self.exportCustomTemplate.includeHeader ~= false,
        fields = #fields > 0 and fields or { "itemID", "itemName", "totalToBuy" },
    }
end

function mainFrame:ToggleExportHeader()
    self.exportCustomTemplate.includeHeader = not (self.exportCustomTemplate.includeHeader ~= false)
    self.exportHeaderToggleButton.labelText:SetText((self.exportCustomTemplate.includeHeader ~= false) and "Header: Yes" or "Header: No")
    self:PersistExportSettings(ns.state.db or {})
    if self.activeView == "EXPORTS" and self.exportSelectedPreset == "Custom" then
        self:RefreshExportOutput(self.tableRowsData or {})
    end
    return self.exportCustomTemplate.includeHeader
end

function mainFrame:ApplyCustomExportTemplate()
    self.exportCustomTemplate = self:BuildCustomExportTemplateFromControls()
    self:PersistExportSettings(ns.state.db or {})
    self:RefreshExportCustomControls()
    if self.activeView == "EXPORTS" and self.exportSelectedPreset == "Custom" then
        self:RefreshExportOutput(self.tableRowsData or {})
    end
    return self.exportCustomTemplate
end

function mainFrame:BuildMinimumRuleFromEditor()
    local itemID = parse_number(self.minimumItemIDInput:GetText() or "")
    local quantity = parse_number(self.minimumQuantityInput:GetText() or "")
    local itemName = self.minimumItemNameInput:GetText() or ""
    local scope = self.minimumScopeInput:GetText() or "GLOBAL"
    local tabName = self.minimumTabNameInput:GetText() or ""

    if not itemID or itemName == "" then
        return nil
    end

    return {
        itemID = itemID,
        itemName = itemName,
        quantity = quantity or 0,
        scope = scope ~= "" and scope or "GLOBAL",
        tabName = tabName ~= "" and tabName or nil,
        enabled = self.selectedMinimumEnabled,
    }
end

function mainFrame:ToggleMinimumRestock()
    self.selectedMinimumEnabled = not self.selectedMinimumEnabled
    self.minimumRestockToggleButton.labelText:SetText(self.selectedMinimumEnabled and "Restock: Yes" or "Restock: No")
    return self.selectedMinimumEnabled
end

function mainFrame:SaveMinimumFromEditor()
    return self:SaveAllMinimumChanges()
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

    self:UpdateSharedTableLayout()

    if db.currentSnapshotId ~= nil then
        currentSnapshot = (db.snapshots or {})[db.currentSnapshotId]
    end

    local demandPlan = {}
    if planning and type(planning.BuildDemandPlan) == "function" then
        demandPlan = planning.BuildDemandPlan({
            snapshot = currentSnapshot or { items = {} },
            minimums = db.minimums or {},
            oneTimeTargets = db.oneTimeTargets or {},
            requests = db.requests or {},
        })
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
        local rows = historyView.BuildTableRows(procurement_audit_entries(db.auditLog or {}), self:GetSharedFilterState())
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
        local rows = requestsView.BuildTableRows(db.requests or {})
        if not self:GetSelectedRequest() then
            self:SelectFirstActionableRequest()
        end
        self:RefreshRequestActionButtons()
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "requester", label = "Requester", width = 110, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 170, justifyH = "LEFT" },
            { key = "quantity", label = "Qty", width = 50, justifyH = "LEFT" },
            { key = "approval", label = "Approval", width = 90, justifyH = "LEFT" },
            { key = "fulfillment", label = "Fulfillment", width = 100, justifyH = "LEFT" },
            { key = "note", label = "Note", width = 110, justifyH = "LEFT" },
        }, rows)
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

    if showTable then
        self.tableHeaderFrame:Show()
        if self:UsesInlineTableFilters() then
            self.tableFilterFrame:Show()
        else
            self.tableFilterFrame:Hide()
        end
        self.tableScrollFrame:Show()
        self.tableScrollBar:Show()
    else
        self.tableHeaderFrame:Hide()
        self.tableFilterFrame:Hide()
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

    if self.activeView == "REQUESTS" then
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
    else
        self.optionsPanel:Hide()
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

mainFrame.minimumSearchInput:SetScript("OnTextChanged", function()
    if mainFrame.activeView == "MINIMUMS" then
        mainFrame:ApplyMinimumFilters()
    end
end)

mainFrame.minimumAddItemIDInput:SetScript("OnTextChanged", function()
    if mainFrame.activeView == "MINIMUMS" and not mainFrame.isResolvingMinimumAdd then
        mainFrame:ResolveMinimumAddByItemID()
    end
end)

mainFrame.minimumAddItemNameInput:SetScript("OnTextChanged", function()
    if mainFrame.activeView == "MINIMUMS" and not mainFrame.isResolvingMinimumAdd then
        mainFrame:ResolveMinimumAddByName()
    end
end)

mainFrame.exportAuctionatorListNameInput:SetScript("OnTextChanged", function()
    if mainFrame.isRefreshingExportControls then
        return
    end
    mainFrame.exportShoppingListName = normalize_shopping_list_name(mainFrame.exportAuctionatorListNameInput:GetText())
    mainFrame:PersistExportSettings(ns.state.db or {})
    if mainFrame.activeView == "EXPORTS" and mainFrame.exportSelectedPreset == "Auctionator" then
        mainFrame:RefreshExportOutput(mainFrame.tableRowsData or {})
    end
end)

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
    return self:SelectView("DASHBOARD")
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
