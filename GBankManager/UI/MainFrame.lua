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
