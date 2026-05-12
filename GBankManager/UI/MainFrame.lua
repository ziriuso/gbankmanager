local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrame = ns.modules.mainFrame

if type(mainFrame) ~= "table" or type(mainFrame.SetSize) ~= "function" then
    mainFrame = _G.CreateFrame("Frame", "GBankManagerFrame", _G.UIParent, "BackdropTemplate")
end

ns.ui.theme = ns.ui.theme or {
    colors = {
        background = { 0.07, 0.09, 0.13, 0.96 },
        panel = { 0.10, 0.14, 0.20, 0.98 },
        panelAlt = { 0.13, 0.17, 0.24, 0.98 },
        border = { 0.24, 0.31, 0.40, 0.90 },
        accent = { 0.58, 0.67, 0.78, 1.00 },
        accentStrong = { 0.85, 0.89, 0.94, 1.00 },
        muted = { 0.56, 0.65, 0.76, 1.00 },
    },
    spacing = {
        sidebarExpanded = 212,
        sidebarCollapsed = 72,
        frameWidth = 1040,
        frameHeight = 640,
        topBarHeight = 64,
    },
}

local theme = ns.ui.theme
local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3,
    },
}

local function apply_panel_style(frame, color)
    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop(backdrop)
    end

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(unpack(color))
    end

    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(unpack(theme.colors.border))
    end
end

local function make_label(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    if type(label.SetJustifyH) == "function" then
        label:SetJustifyH("LEFT")
    end
    label:SetText(text or "")
    return label
end

local function make_button(parent, width, height, text)
    local button = _G.CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    apply_panel_style(button, theme.colors.panel)
    button.labelText = button.labelText or make_label(button, text, "GameFontNormal")
    if type(button.labelText.SetJustifyH) == "function" then
        button.labelText:SetJustifyH("CENTER")
    end
    button.labelText:SetPoint("CENTER", button, "CENTER", 0, 0)
    return button
end

local function make_input(parent, width, height)
    local input = _G.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(width, height)
    apply_panel_style(input, theme.colors.background)
    if type(input.SetAutoFocus) == "function" then
        input:SetAutoFocus(false)
    end
    if type(input.SetFontObject) == "function" then
        input:SetFontObject("GameFontHighlightSmall")
    end
    if type(input.SetTextColor) == "function" then
        input:SetTextColor(unpack(theme.colors.accentStrong))
    end
    if type(input.EnableMouse) == "function" then
        input:EnableMouse(true)
    end
    if type(input.SetTextInsets) == "function" then
        input:SetTextInsets(6, 6, 0, 0)
    end
    input:SetText("")
    return input
end

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

local function minimum_rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local function target_rule_key(rule)
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

mainFrame:SetSize(theme.spacing.frameWidth, theme.spacing.frameHeight)
mainFrame:SetPoint("CENTER")
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(false)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetResizable(true)
mainFrame:SetResizeBounds(920, 560, 1280, 760)
mainFrame:SetFrameStrata("DIALOG")
mainFrame.currentAlpha = mainFrame.currentAlpha or 0.96
mainFrame:SetAlpha(mainFrame.currentAlpha)
apply_panel_style(mainFrame, theme.colors.background)
mainFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

mainFrame.activeView = mainFrame.activeView or "DASHBOARD"
mainFrame.collapsedSidebar = false
mainFrame.navItems = {
    { key = "DASHBOARD", label = "Dashboard" },
    { key = "INVENTORY", label = "Inventory" },
    { key = "HISTORY", label = "History" },
    { key = "MINIMUMS", label = "Minimums" },
    { key = "TARGETS", label = "Targets" },
    { key = "REQUESTS", label = "Requests" },
    { key = "EXPORTS", label = "Exports" },
    { key = "OPTIONS", label = "Options" },
}
mainFrame.viewDescriptions = {
    DASHBOARD = "Critical shortages, pending requests, and export readiness.",
    INVENTORY = "Search the latest bank snapshot and inspect current counts.",
    HISTORY = "Audit request changes and minimum updates with timestamps and before/after values.",
    MINIMUMS = "Manage recurring stock floors by item, scope, and tab.",
    TARGETS = "Track one-time buy-up goals and suggested fulfillment state.",
    REQUESTS = "Review officer-first request queues and member-visible demand.",
    EXPORTS = "Prepare Auctionator and spreadsheet-ready purchase output.",
    OPTIONS = "Adjust shell behavior like transparency without cluttering the main toolbar.",
}

mainFrame.sidebar = mainFrame.sidebar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
mainFrame.sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
mainFrame.sidebar:SetWidth(theme.spacing.sidebarExpanded)
apply_panel_style(mainFrame.sidebar, theme.colors.panel)

mainFrame.topBar = mainFrame.topBar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
mainFrame.topBar:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 0, 0)
mainFrame.topBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
mainFrame.topBar:SetHeight(theme.spacing.topBarHeight)
apply_panel_style(mainFrame.topBar, theme.colors.panelAlt)

mainFrame.content = mainFrame.content or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
mainFrame.content:SetPoint("TOPLEFT", mainFrame.topBar, "BOTTOMLEFT", 0, 0)
mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
apply_panel_style(mainFrame.content, theme.colors.background)

mainFrame.titleText = mainFrame.titleText or make_label(mainFrame.topBar, "Guild Bank Dashboard", "GameFontHighlightLarge")
mainFrame.titleText:SetPoint("TOPLEFT", mainFrame.topBar, "TOPLEFT", 36, -14)
mainFrame.subtitleText = mainFrame.subtitleText or make_label(mainFrame.topBar, "Inventory Management", "GameFontHighlightSmall")
mainFrame.subtitleText:SetPoint("TOPLEFT", mainFrame.titleText, "BOTTOMLEFT", 0, -6)
mainFrame.statusText = mainFrame.statusText or make_label(mainFrame.topBar, "No scan yet", "GameFontNormal")
mainFrame.statusText:SetPoint("RIGHT", mainFrame.topBar, "RIGHT", -152, 0)

mainFrame.collapseButton = mainFrame.collapseButton or make_button(mainFrame.sidebar, 28, 28, "<")
mainFrame.collapseButton:SetPoint("TOPRIGHT", mainFrame.sidebar, "TOPRIGHT", -10, -10)
mainFrame.collapseButton:SetScript("OnClick", function()
    mainFrame:ToggleSidebar()
end)

mainFrame.scanButton = mainFrame.scanButton or make_button(mainFrame.topBar, 120, 28, "Scan Bank")
mainFrame.scanButton:SetPoint("TOP", mainFrame.topBar, "TOP", 0, -16)
mainFrame.scanButton:SetScript("OnClick", function()
    local scanner = ns.modules.scanner
    if scanner and type(scanner.BeginScan) == "function" then
        scanner.BeginScan()
    end
end)

local function set_alpha(nextAlpha)
    mainFrame.currentAlpha = math.max(0.55, math.min(1.0, nextAlpha))
    mainFrame:SetAlpha(mainFrame.currentAlpha)
end

mainFrame.viewTitle = mainFrame.viewTitle or make_label(mainFrame.content, "Dashboard", "GameFontNormal")
mainFrame.viewTitle:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 24, -24)
mainFrame.viewSubtitle = mainFrame.viewSubtitle or make_label(mainFrame.content, "Critical shortages, pending requests, and export readiness.", "GameFontHighlightSmall")
mainFrame.viewSubtitle:SetPoint("TOPLEFT", mainFrame.viewTitle, "BOTTOMLEFT", 0, -8)
mainFrame.tableViewportWidth = 730
mainFrame.tableViewportInnerWidth = 730
mainFrame.tableHeaderHeight = 28
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
mainFrame.selectedTargetKey = mainFrame.selectedTargetKey or nil
mainFrame.selectedTargetStatus = mainFrame.selectedTargetStatus or "OPEN"
mainFrame.exportSelectedPreset = mainFrame.exportSelectedPreset or "Spreadsheet"
mainFrame.exportCustomTemplate = mainFrame.exportCustomTemplate or clone_export_template()

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

mainFrame.tableHeaderFrame = mainFrame.tableHeaderFrame or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.tableHeaderFrame:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.tableHeaderFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableHeaderHeight)
apply_panel_style(mainFrame.tableHeaderFrame, theme.colors.panel)

mainFrame.tableHeaderLabels = mainFrame.tableHeaderLabels or {}
for index = 1, 6 do
    local label = mainFrame.tableHeaderLabels[index] or make_label(mainFrame.tableHeaderFrame, "", "GameFontHighlight")
    mainFrame.tableHeaderLabels[index] = label
end
mainFrame.tableHeaderButtons = mainFrame.tableHeaderButtons or {}

mainFrame.tableFilterFrame = mainFrame.tableFilterFrame or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.tableFilterFrame:SetPoint("TOPLEFT", mainFrame.tableHeaderFrame, "BOTTOMLEFT", 0, -4)
mainFrame.tableFilterFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableFilterHeight)
apply_panel_style(mainFrame.tableFilterFrame, theme.colors.background)

mainFrame.tableFilterInputs = mainFrame.tableFilterInputs or {}
for index = 1, 6 do
    local input = mainFrame.tableFilterInputs[index] or make_input(mainFrame.tableFilterFrame, 80, 22)
    mainFrame.tableFilterInputs[index] = input
end

mainFrame.tableScrollFrame = mainFrame.tableScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.tableScrollFrame:SetPoint("TOPLEFT", mainFrame.tableFilterFrame, "BOTTOMLEFT", 0, -4)
mainFrame.tableScrollFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableViewportHeight)
apply_panel_style(mainFrame.tableScrollFrame, theme.colors.background)
mainFrame.tableScrollFrame:EnableMouseWheel(true)

mainFrame.tableScrollChild = mainFrame.tableScrollChild or _G.CreateFrame("Frame", nil, mainFrame.tableScrollFrame, "BackdropTemplate")
mainFrame.tableScrollChild:SetSize(mainFrame.tableViewportWidth, mainFrame.tableViewportHeight)
mainFrame.tableScrollFrame:SetScrollChild(mainFrame.tableScrollChild)
mainFrame.tableScrollOffset = mainFrame.tableScrollOffset or 0
mainFrame.tableRowsData = mainFrame.tableRowsData or {}
mainFrame.tableColumnLayout = mainFrame.tableColumnLayout or {}
mainFrame.tableColumnResizeHandles = mainFrame.tableColumnResizeHandles or {}
mainFrame.cachedInventoryRows = mainFrame.cachedInventoryRows or {}
mainFrame.inventorySortState = mainFrame.inventorySortState or {
    key = nil,
    direction = "asc",
}

mainFrame.tableScrollBar = mainFrame.tableScrollBar or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.tableScrollBar:SetPoint("TOPLEFT", mainFrame.tableHeaderFrame, "TOPRIGHT", 8, 0)
mainFrame.tableScrollBar:SetPoint("BOTTOMLEFT", mainFrame.tableScrollFrame, "BOTTOMRIGHT", 8, 0)
mainFrame.tableScrollBar:SetWidth(24)
mainFrame.tableScrollBar.topButtonOffset = mainFrame.tableHeaderHeight
apply_panel_style(mainFrame.tableScrollBar, theme.colors.panel)

mainFrame.tableScrollBar.scrollUpButton = mainFrame.tableScrollBar.scrollUpButton or make_button(mainFrame.tableScrollBar, 24, 24, "^")
mainFrame.tableScrollBar.scrollUpButton:SetPoint("TOPLEFT", mainFrame.tableScrollBar, "TOPLEFT", 0, 0)
mainFrame.tableScrollBar.scrollDownButton = mainFrame.tableScrollBar.scrollDownButton or make_button(mainFrame.tableScrollBar, 24, 24, "v")
mainFrame.tableScrollBar.scrollDownButton:SetPoint("BOTTOMLEFT", mainFrame.tableScrollBar, "BOTTOMLEFT", 0, 0)
mainFrame.tableScrollBar.valueText = mainFrame.tableScrollBar.valueText or make_label(mainFrame.tableScrollBar, "", "GameFontHighlightSmall")
mainFrame.tableScrollBar.valueText:SetPoint("TOP", mainFrame.tableScrollBar.scrollUpButton, "BOTTOM", 0, -12)
mainFrame.tableScrollBar.track = mainFrame.tableScrollBar.track or _G.CreateFrame("Frame", nil, mainFrame.tableScrollBar, "BackdropTemplate")
mainFrame.tableScrollBar.track:SetPoint("TOPLEFT", mainFrame.tableScrollBar.scrollUpButton, "BOTTOMLEFT", 0, -30)
mainFrame.tableScrollBar.track:SetPoint("BOTTOMLEFT", mainFrame.tableScrollBar.scrollDownButton, "TOPLEFT", 0, 30)
mainFrame.tableScrollBar.track:SetWidth(24)
apply_panel_style(mainFrame.tableScrollBar.track, theme.colors.background)
mainFrame.tableScrollBar.thumb = mainFrame.tableScrollBar.thumb or _G.CreateFrame("Button", nil, mainFrame.tableScrollBar.track, "BackdropTemplate")
mainFrame.tableScrollBar.thumb:SetSize(18, 48)
mainFrame.tableScrollBar.thumb:SetPoint("TOP", mainFrame.tableScrollBar.track, "TOP", 0, -2)
apply_panel_style(mainFrame.tableScrollBar.thumb, theme.colors.accent)
mainFrame.tableScrollBar.thumb:EnableMouse(true)

mainFrame.tableRows = mainFrame.tableRows or {}
    for rowIndex = 1, mainFrame.tableVisibleCount do
        local row = mainFrame.tableRows[rowIndex] or _G.CreateFrame("Button", nil, mainFrame.tableScrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", mainFrame.tableScrollChild, "TOPLEFT", 0, -((rowIndex - 1) * mainFrame.tableRowHeight))
        row:SetSize(mainFrame.tableViewportWidth, mainFrame.tableRowHeight - 2)
        row:EnableMouse(true)
        apply_panel_style(row, rowIndex % 2 == 1 and theme.colors.panel or theme.colors.panelAlt)
        row.columns = row.columns or {}

        for columnIndex = 1, 6 do
            local column = row.columns[columnIndex] or make_label(row, "", "GameFontNormal")
            row.columns[columnIndex] = column
        end

        mainFrame.tableRows[rowIndex] = row
end

mainFrame.contentBodyText = mainFrame.contentBodyText or make_label(mainFrame.content, "", "GameFontNormal")
mainFrame.contentBodyText:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)

mainFrame.minimumEmptyStateText = mainFrame.minimumEmptyStateText or make_label(mainFrame.content, "", "GameFontHighlightSmall")
mainFrame.minimumEmptyStateText:SetPoint("TOPLEFT", mainFrame.tableScrollFrame, "TOPLEFT", 12, -12)
mainFrame.minimumEmptyStateText:Hide()

mainFrame.optionsPanel = mainFrame.optionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.optionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.optionsPanel:SetHeight(92)
apply_panel_style(mainFrame.optionsPanel, theme.colors.panel)
mainFrame.optionsPanel:Hide()

mainFrame.requestActionsPanel = mainFrame.requestActionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.requestActionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.requestActionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.requestActionsPanel:SetHeight(92)
apply_panel_style(mainFrame.requestActionsPanel, theme.colors.panel)
mainFrame.requestActionsPanel:Hide()

mainFrame.requestActionsTitle = mainFrame.requestActionsTitle or make_label(mainFrame.requestActionsPanel, "Workflow Actions", "GameFontHighlight")
mainFrame.requestActionsTitle:SetPoint("TOPLEFT", mainFrame.requestActionsPanel, "TOPLEFT", 16, -16)

mainFrame.requestActionHint = mainFrame.requestActionHint or make_label(mainFrame.requestActionsPanel, "Select a request, then approve, reject, fulfill, or reopen it.", "GameFontHighlightSmall")
mainFrame.requestActionHint:SetPoint("TOPLEFT", mainFrame.requestActionsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.requestApproveButton = mainFrame.requestApproveButton or make_button(mainFrame.requestActionsPanel, 78, 28, "Approve")
mainFrame.requestApproveButton:SetPoint("TOPLEFT", mainFrame.requestActionHint, "BOTTOMLEFT", 0, -16)

mainFrame.requestRejectButton = mainFrame.requestRejectButton or make_button(mainFrame.requestActionsPanel, 72, 28, "Reject")
mainFrame.requestRejectButton:SetPoint("LEFT", mainFrame.requestApproveButton, "RIGHT", 8, 0)

mainFrame.requestFulfillButton = mainFrame.requestFulfillButton or make_button(mainFrame.requestActionsPanel, 72, 28, "Fulfill")
mainFrame.requestFulfillButton:SetPoint("LEFT", mainFrame.requestRejectButton, "RIGHT", 8, 0)

mainFrame.requestReopenButton = mainFrame.requestReopenButton or make_button(mainFrame.requestActionsPanel, 72, 28, "Reopen")
mainFrame.requestReopenButton:SetPoint("LEFT", mainFrame.requestFulfillButton, "RIGHT", 8, 0)

mainFrame.requestActionNoteInput = mainFrame.requestActionNoteInput or make_input(mainFrame.requestActionsPanel, 248, 22)
mainFrame.requestActionNoteInput:SetPoint("LEFT", mainFrame.requestReopenButton, "RIGHT", 12, 0)

mainFrame.requestCreatePanel = mainFrame.requestCreatePanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.requestCreatePanel:SetPoint("TOPLEFT", mainFrame.requestActionsPanel, "BOTTOMLEFT", 0, -12)
mainFrame.requestCreatePanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.requestCreatePanel:SetHeight(92)
apply_panel_style(mainFrame.requestCreatePanel, theme.colors.panel)
mainFrame.requestCreatePanel:Hide()

mainFrame.requestCreateTitle = mainFrame.requestCreateTitle or make_label(mainFrame.requestCreatePanel, "Create Request", "GameFontHighlight")
mainFrame.requestCreateTitle:SetPoint("TOPLEFT", mainFrame.requestCreatePanel, "TOPLEFT", 16, -16)

mainFrame.requestCreateRequesterInput = mainFrame.requestCreateRequesterInput or make_input(mainFrame.requestCreatePanel, 88, 22)
mainFrame.requestCreateRequesterInput:SetPoint("TOPLEFT", mainFrame.requestCreateTitle, "BOTTOMLEFT", 0, -16)

mainFrame.requestCreateRoleInput = mainFrame.requestCreateRoleInput or make_input(mainFrame.requestCreatePanel, 84, 22)
mainFrame.requestCreateRoleInput:SetPoint("LEFT", mainFrame.requestCreateRequesterInput, "RIGHT", 8, 0)

mainFrame.requestCreateItemIDInput = mainFrame.requestCreateItemIDInput or make_input(mainFrame.requestCreatePanel, 72, 22)
mainFrame.requestCreateItemIDInput:SetPoint("LEFT", mainFrame.requestCreateRoleInput, "RIGHT", 8, 0)

mainFrame.requestCreateItemNameInput = mainFrame.requestCreateItemNameInput or make_input(mainFrame.requestCreatePanel, 160, 22)
mainFrame.requestCreateItemNameInput:SetPoint("LEFT", mainFrame.requestCreateItemIDInput, "RIGHT", 8, 0)

mainFrame.requestCreateQuantityInput = mainFrame.requestCreateQuantityInput or make_input(mainFrame.requestCreatePanel, 56, 22)
mainFrame.requestCreateQuantityInput:SetPoint("LEFT", mainFrame.requestCreateItemNameInput, "RIGHT", 8, 0)

mainFrame.requestCreateNoteInput = mainFrame.requestCreateNoteInput or make_input(mainFrame.requestCreatePanel, 116, 22)
mainFrame.requestCreateNoteInput:SetPoint("LEFT", mainFrame.requestCreateQuantityInput, "RIGHT", 8, 0)

mainFrame.requestCreateButton = mainFrame.requestCreateButton or make_button(mainFrame.requestCreatePanel, 68, 28, "Create")
mainFrame.requestCreateButton:SetPoint("LEFT", mainFrame.requestCreateNoteInput, "RIGHT", 12, 0)

mainFrame.minimumsPanel = mainFrame.minimumsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.minimumsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.minimumsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.minimumsPanel:SetHeight(132)
apply_panel_style(mainFrame.minimumsPanel, theme.colors.panel)
mainFrame.minimumsPanel:Hide()

mainFrame.minimumsTitle = mainFrame.minimumsTitle or make_label(mainFrame.minimumsPanel, "Minimum Rule Editor", "GameFontHighlight")
mainFrame.minimumsTitle:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -16)

mainFrame.minimumsHint = mainFrame.minimumsHint or make_label(mainFrame.minimumsPanel, "Edit a rule above the table and save straight into workflow history.", "GameFontHighlightSmall")
mainFrame.minimumsHint:SetPoint("TOPLEFT", mainFrame.minimumsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.minimumEditorStateText = mainFrame.minimumEditorStateText or make_label(mainFrame.minimumsPanel, "Create or select a rule to start editing.", "GameFontHighlightSmall")
mainFrame.minimumEditorStateText:SetPoint("TOPLEFT", mainFrame.minimumsHint, "BOTTOMLEFT", 0, -14)

mainFrame.minimumItemIDInput = mainFrame.minimumItemIDInput or make_input(mainFrame.minimumsPanel, 72, 22)
mainFrame.minimumItemIDInput:SetPoint("TOPLEFT", mainFrame.minimumEditorStateText, "BOTTOMLEFT", 0, -10)

mainFrame.minimumItemNameInput = mainFrame.minimumItemNameInput or make_input(mainFrame.minimumsPanel, 180, 22)
mainFrame.minimumItemNameInput:SetPoint("LEFT", mainFrame.minimumItemIDInput, "RIGHT", 8, 0)

mainFrame.minimumQuantityInput = mainFrame.minimumQuantityInput or make_input(mainFrame.minimumsPanel, 64, 22)
mainFrame.minimumQuantityInput:SetPoint("LEFT", mainFrame.minimumItemNameInput, "RIGHT", 8, 0)

mainFrame.minimumScopeInput = mainFrame.minimumScopeInput or make_input(mainFrame.minimumsPanel, 88, 22)
mainFrame.minimumScopeInput:SetPoint("LEFT", mainFrame.minimumQuantityInput, "RIGHT", 8, 0)

mainFrame.minimumTabNameInput = mainFrame.minimumTabNameInput or make_input(mainFrame.minimumsPanel, 110, 22)
mainFrame.minimumTabNameInput:SetPoint("LEFT", mainFrame.minimumScopeInput, "RIGHT", 8, 0)

mainFrame.minimumRestockToggleButton = mainFrame.minimumRestockToggleButton or make_button(mainFrame.minimumsPanel, 78, 28, "Restock: No")
mainFrame.minimumRestockToggleButton:SetPoint("TOPLEFT", mainFrame.minimumItemIDInput, "BOTTOMLEFT", 0, -10)

mainFrame.minimumShowAllToggleButton = mainFrame.minimumShowAllToggleButton or make_button(mainFrame.minimumsPanel, 80, 28, "Show All")
mainFrame.minimumShowAllToggleButton:SetPoint("LEFT", mainFrame.minimumRestockToggleButton, "RIGHT", 8, 0)

mainFrame.minimumSearchInput = mainFrame.minimumSearchInput or make_input(mainFrame.minimumsPanel, 110, 22)
mainFrame.minimumSearchInput:SetPoint("LEFT", mainFrame.minimumShowAllToggleButton, "RIGHT", 8, 0)

mainFrame.minimumManualOnlyToggleButton = mainFrame.minimumManualOnlyToggleButton or make_button(mainFrame.minimumsPanel, 86, 28, "Manual Only")
mainFrame.minimumManualOnlyToggleButton:SetPoint("LEFT", mainFrame.minimumSearchInput, "RIGHT", 8, 0)

mainFrame.minimumNewButton = mainFrame.minimumNewButton or make_button(mainFrame.minimumsPanel, 64, 28, "New")
mainFrame.minimumNewButton:SetPoint("LEFT", mainFrame.minimumManualOnlyToggleButton, "RIGHT", 8, 0)

mainFrame.minimumSaveButton = mainFrame.minimumSaveButton or make_button(mainFrame.minimumsPanel, 72, 28, "Save")
mainFrame.minimumSaveButton:SetPoint("LEFT", mainFrame.minimumNewButton, "RIGHT", 8, 0)

mainFrame.targetsPanel = mainFrame.targetsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.targetsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.targetsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.targetsPanel:SetHeight(132)
apply_panel_style(mainFrame.targetsPanel, theme.colors.panel)
mainFrame.targetsPanel:Hide()

mainFrame.targetsTitle = mainFrame.targetsTitle or make_label(mainFrame.targetsPanel, "One-Time Target Editor", "GameFontHighlight")
mainFrame.targetsTitle:SetPoint("TOPLEFT", mainFrame.targetsPanel, "TOPLEFT", 16, -16)

mainFrame.targetsHint = mainFrame.targetsHint or make_label(mainFrame.targetsPanel, "Create or adjust buy-up targets that should not recur forever.", "GameFontHighlightSmall")
mainFrame.targetsHint:SetPoint("TOPLEFT", mainFrame.targetsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.targetEditorStateText = mainFrame.targetEditorStateText or make_label(mainFrame.targetsPanel, "Create or select a target to start editing.", "GameFontHighlightSmall")
mainFrame.targetEditorStateText:SetPoint("TOPLEFT", mainFrame.targetsHint, "BOTTOMLEFT", 0, -14)

mainFrame.targetItemIDInput = mainFrame.targetItemIDInput or make_input(mainFrame.targetsPanel, 72, 22)
mainFrame.targetItemIDInput:SetPoint("TOPLEFT", mainFrame.targetEditorStateText, "BOTTOMLEFT", 0, -10)

mainFrame.targetItemNameInput = mainFrame.targetItemNameInput or make_input(mainFrame.targetsPanel, 180, 22)
mainFrame.targetItemNameInput:SetPoint("LEFT", mainFrame.targetItemIDInput, "RIGHT", 8, 0)

mainFrame.targetQuantityInput = mainFrame.targetQuantityInput or make_input(mainFrame.targetsPanel, 64, 22)
mainFrame.targetQuantityInput:SetPoint("LEFT", mainFrame.targetItemNameInput, "RIGHT", 8, 0)

mainFrame.targetScopeInput = mainFrame.targetScopeInput or make_input(mainFrame.targetsPanel, 88, 22)
mainFrame.targetScopeInput:SetPoint("LEFT", mainFrame.targetQuantityInput, "RIGHT", 8, 0)

mainFrame.targetTabNameInput = mainFrame.targetTabNameInput or make_input(mainFrame.targetsPanel, 110, 22)
mainFrame.targetTabNameInput:SetPoint("LEFT", mainFrame.targetScopeInput, "RIGHT", 8, 0)

mainFrame.targetStatusButton = mainFrame.targetStatusButton or make_button(mainFrame.targetsPanel, 90, 28, "Status: Closed")
mainFrame.targetStatusButton:SetPoint("TOPLEFT", mainFrame.targetItemIDInput, "BOTTOMLEFT", 0, -10)

mainFrame.targetNewButton = mainFrame.targetNewButton or make_button(mainFrame.targetsPanel, 64, 28, "New")
mainFrame.targetNewButton:SetPoint("LEFT", mainFrame.targetStatusButton, "RIGHT", 8, 0)

mainFrame.targetSaveButton = mainFrame.targetSaveButton or make_button(mainFrame.targetsPanel, 72, 28, "Save")
mainFrame.targetSaveButton:SetPoint("LEFT", mainFrame.targetNewButton, "RIGHT", 8, 0)

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

mainFrame.exportPresetSpreadsheetButton = mainFrame.exportPresetSpreadsheetButton or make_button(mainFrame.exportsPanel, 84, 28, "Spreadsheet")
mainFrame.exportPresetSpreadsheetButton:SetPoint("TOPLEFT", mainFrame.exportsHint, "BOTTOMLEFT", 0, -14)

mainFrame.exportPresetAuctionatorButton = mainFrame.exportPresetAuctionatorButton or make_button(mainFrame.exportsPanel, 84, 28, "Auctionator")
mainFrame.exportPresetAuctionatorButton:SetPoint("LEFT", mainFrame.exportPresetSpreadsheetButton, "RIGHT", 8, 0)

mainFrame.exportPresetCustomButton = mainFrame.exportPresetCustomButton or make_button(mainFrame.exportsPanel, 68, 28, "Custom")
mainFrame.exportPresetCustomButton:SetPoint("LEFT", mainFrame.exportPresetAuctionatorButton, "RIGHT", 8, 0)

mainFrame.exportsPresetTitle = mainFrame.exportsPresetTitle or make_label(mainFrame.exportsPanel, "Spreadsheet", "GameFontHighlight")
mainFrame.exportsPresetTitle:SetPoint("LEFT", mainFrame.exportPresetCustomButton, "RIGHT", 16, 0)

mainFrame.exportsOutputText = mainFrame.exportsOutputText or make_label(mainFrame.exportsPanel, "", "GameFontNormal")
mainFrame.exportsOutputText:SetPoint("TOPLEFT", mainFrame.exportPresetSpreadsheetButton, "BOTTOMLEFT", 0, -12)
mainFrame.exportsOutputText:SetWidth(760)

mainFrame.exportDelimiterInput = mainFrame.exportDelimiterInput or make_input(mainFrame.exportsPanel, 42, 22)
mainFrame.exportDelimiterInput:SetPoint("LEFT", mainFrame.exportsPresetTitle, "RIGHT", 16, 0)
mainFrame.exportDelimiterInput:SetText(mainFrame.exportCustomTemplate.delimiter or "|")

mainFrame.exportFieldsInput = mainFrame.exportFieldsInput or make_input(mainFrame.exportsPanel, 250, 22)
mainFrame.exportFieldsInput:SetPoint("LEFT", mainFrame.exportDelimiterInput, "RIGHT", 8, 0)
mainFrame.exportFieldsInput:SetText(table.concat(mainFrame.exportCustomTemplate.fields or {}, ","))

mainFrame.exportHeaderToggleButton = mainFrame.exportHeaderToggleButton or make_button(mainFrame.exportsPanel, 88, 28, "Header: Yes")
mainFrame.exportHeaderToggleButton:SetPoint("LEFT", mainFrame.exportFieldsInput, "RIGHT", 8, 0)

mainFrame.exportApplyCustomButton = mainFrame.exportApplyCustomButton or make_button(mainFrame.exportsPanel, 64, 28, "Apply")
mainFrame.exportApplyCustomButton:SetPoint("LEFT", mainFrame.exportHeaderToggleButton, "RIGHT", 8, 0)

mainFrame.requestApproveButton:SetScript("OnClick", function()
    mainFrame:ApplyRequestAction("APPROVE")
end)

mainFrame.requestRejectButton:SetScript("OnClick", function()
    mainFrame:ApplyRequestAction("REJECT")
end)

mainFrame.requestFulfillButton:SetScript("OnClick", function()
    mainFrame:ApplyRequestAction("FULFILL")
end)

mainFrame.requestReopenButton:SetScript("OnClick", function()
    mainFrame:ApplyRequestAction("REOPEN")
end)

mainFrame.requestCreateButton:SetScript("OnClick", function()
    mainFrame:CreateRequestFromEditor()
end)

mainFrame.minimumNewButton:SetScript("OnClick", function()
    mainFrame:ClearMinimumEditor()
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
    mainFrame:SaveMinimumFromEditor()
end)

mainFrame.targetNewButton:SetScript("OnClick", function()
    mainFrame:ClearTargetEditor()
end)

mainFrame.targetStatusButton:SetScript("OnClick", function()
    mainFrame:ToggleTargetStatus()
end)

mainFrame.targetSaveButton:SetScript("OnClick", function()
    mainFrame:SaveTargetFromEditor()
end)

mainFrame.exportPresetSpreadsheetButton:SetScript("OnClick", function()
    mainFrame:SelectExportPreset("Spreadsheet")
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

mainFrame.optionsTitle = mainFrame.optionsTitle or make_label(mainFrame.optionsPanel, "Window Transparency", "GameFontHighlight")
mainFrame.optionsTitle:SetPoint("TOPLEFT", mainFrame.optionsPanel, "TOPLEFT", 16, -16)

mainFrame.optionsHint = mainFrame.optionsHint or make_label(mainFrame.optionsPanel, "Use the controls below to lighten or darken the shell.", "GameFontHighlightSmall")
mainFrame.optionsHint:SetPoint("TOPLEFT", mainFrame.optionsTitle, "BOTTOMLEFT", 0, -8)

mainFrame.transparencyDownButton = mainFrame.transparencyDownButton or make_button(mainFrame.optionsPanel, 32, 28, "-")
mainFrame.transparencyDownButton:SetPoint("TOPLEFT", mainFrame.optionsHint, "BOTTOMLEFT", 0, -16)

mainFrame.transparencyUpButton = mainFrame.transparencyUpButton or make_button(mainFrame.optionsPanel, 32, 28, "+")
mainFrame.transparencyUpButton:SetPoint("LEFT", mainFrame.transparencyDownButton, "RIGHT", 4, 0)

mainFrame.transparencyValueText = mainFrame.transparencyValueText or make_label(mainFrame.optionsPanel, "", "GameFontNormal")
mainFrame.transparencyValueText:SetPoint("LEFT", mainFrame.transparencyUpButton, "RIGHT", 12, 0)

local function refresh_alpha_text()
    mainFrame.transparencyValueText:SetText(string.format("Opacity %d%%", math.floor(mainFrame.currentAlpha * 100 + 0.5)))
end

mainFrame.transparencyDownButton:SetScript("OnClick", function()
    set_alpha(mainFrame.currentAlpha - 0.08)
    refresh_alpha_text()
end)

mainFrame.transparencyUpButton:SetScript("OnClick", function()
    set_alpha(mainFrame.currentAlpha + 0.08)
    refresh_alpha_text()
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
    apply_panel_style(self.requestActionsPanel, theme.colors.panel)
    apply_panel_style(self.requestCreatePanel, theme.colors.panel)
    apply_panel_style(self.minimumsPanel, theme.colors.panel)
    apply_panel_style(self.targetsPanel, theme.colors.panel)
    apply_panel_style(self.exportsPanel, theme.colors.panel)
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
    apply_panel_style(self.targetStatusButton, theme.colors.panel)
    apply_panel_style(self.targetNewButton, theme.colors.panel)
    apply_panel_style(self.targetSaveButton, theme.colors.panelAlt)
    apply_panel_style(self.exportPresetSpreadsheetButton, theme.colors.panelAlt)
    apply_panel_style(self.exportPresetAuctionatorButton, theme.colors.panel)
    apply_panel_style(self.exportPresetCustomButton, theme.colors.panel)
    apply_panel_style(self.exportHeaderToggleButton, theme.colors.panel)
    apply_panel_style(self.exportApplyCustomButton, theme.colors.panelAlt)
    apply_panel_style(self.transparencyDownButton, theme.colors.panel)
    apply_panel_style(self.transparencyUpButton, theme.colors.panel)
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
    apply_panel_style(self.targetItemIDInput, theme.colors.background)
    apply_panel_style(self.targetItemNameInput, theme.colors.background)
    apply_panel_style(self.targetQuantityInput, theme.colors.background)
    apply_panel_style(self.targetScopeInput, theme.colors.background)
    apply_panel_style(self.targetTabNameInput, theme.colors.background)
    apply_panel_style(self.exportDelimiterInput, theme.colors.background)
    apply_panel_style(self.exportFieldsInput, theme.colors.background)
end

function mainFrame:ConfigureTable(columns, rows)
    self.isConfiguringTable = true
    self.tableColumnLayout = columns or {}
    self.tableColumnKeys = {}
    local offset = 4

    for index = 1, #self.tableHeaderLabels do
        local label = self.tableHeaderLabels[index]
        local columnLayout = self.tableColumnLayout[index] or {}
        local width = columnLayout.width or 120
        self.tableColumnKeys[index] = columnLayout.key

        local headerButton = self.tableHeaderButtons[index] or _G.CreateFrame("Button", nil, self.tableHeaderFrame, "BackdropTemplate")
        headerButton:ClearAllPoints()
        headerButton:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset, 0)
        headerButton:SetSize(width, self.tableHeaderHeight)
        headerButton:SetScript("OnClick", function()
            mainFrame:HandleHeaderClick(index)
        end)
        self.tableHeaderButtons[index] = headerButton

        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset + 6, -8)
        label:SetWidth(width)
        label:SetText(label_with_sort_marker(columnLayout, self.inventorySortState))
        if type(label.SetJustifyH) == "function" then
            label:SetJustifyH(columnLayout.justifyH or "LEFT")
        end

        local input = self.tableFilterInputs[index]
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", self.tableFilterFrame, "TOPLEFT", offset, -3)
        input:SetWidth(width)
        if columnLayout.filterMode == "none" then
            input:SetText("")
            input:Hide()
        else
            input:Show()
        end

        for _, rowFrame in ipairs(self.tableRows) do
            local column = rowFrame.columns[index]
            column:ClearAllPoints()
            column:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", offset + 6, -4)
            column:SetWidth(width)
            if type(column.SetJustifyH) == "function" then
                column:SetJustifyH(columnLayout.justifyH or "LEFT")
            end
        end

        if index < #self.tableHeaderLabels then
            local handle = self.tableColumnResizeHandles[index] or _G.CreateFrame("Button", nil, self.tableHeaderFrame, "BackdropTemplate")
            handle:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset + width - 2, 4)
            handle:SetSize(4, self.tableHeaderHeight - 8)
            if type(handle.SetBackdrop) == "function" then
                handle:SetBackdrop(nil)
            end
            handle:SetScript("OnClick", function()
                mainFrame:ResizeInventoryColumn(index, 24)
            end)
            self.tableColumnResizeHandles[index] = handle
        end

        offset = offset + width
    end

    self.tableRowsData = rows or {}
    self.tableViewportInnerWidth = self.tableViewportWidth
    self.tableScrollChild:SetSize(self.tableViewportInnerWidth, math.max(self.tableViewportHeight, (#self.tableRowsData * self.tableRowHeight)))
    self.isConfiguringTable = false
end

function mainFrame:RefreshVisibleTableRows()
    local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
    self.tableScrollOffset = math.max(0, math.min(self.tableScrollOffset or 0, maxOffset))

    for rowIndex, rowFrame in ipairs(self.tableRows) do
        local row = self.tableRowsData[rowIndex + self.tableScrollOffset]
        for colIndex = 1, #self.tableHeaderLabels do
            local key = self.tableColumnKeys[colIndex]
            rowFrame.columns[colIndex]:SetText(row and key and (row[key] or "") or "")
        end

        rowFrame.rowData = row
        apply_table_row_style(rowFrame, rowIndex, self:IsSelectedTableRow(row))
        rowFrame:SetScript("OnClick", function(frame)
            mainFrame:HandleTableRowClick(frame.rowData)
        end)
    end

    local maxRow = math.max(1, #self.tableRowsData)
    self.tableScrollBar.valueText:SetText(string.format("%d-%d", math.min(maxRow, self.tableScrollOffset + 1), math.min(maxRow, self.tableScrollOffset + self.tableVisibleCount)))
    self:UpdateScrollThumb()
end

function mainFrame:ScrollTableRows(delta)
    self.tableScrollOffset = (self.tableScrollOffset or 0) + (delta or 0)
    self:RefreshVisibleTableRows()
    return self.tableScrollOffset
end

function mainFrame:UpdateScrollThumb()
    local thumb = self.tableScrollBar and self.tableScrollBar.thumb
    local track = self.tableScrollBar and self.tableScrollBar.track

    if not thumb or not track then
        return
    end

    local totalRows = #self.tableRowsData
    local visibleRows = math.max(1, self.tableVisibleCount)
    local maxOffset = math.max(0, totalRows - visibleRows)
    local trackHeight = math.max(24, (track.height or self.tableViewportHeight or 0) - 4)
    local thumbHeight = math.max(24, math.floor(trackHeight * math.min(1, visibleRows / math.max(visibleRows, totalRows))))

    thumb:SetHeight(thumbHeight)

    local travel = math.max(0, trackHeight - thumbHeight)
    local progress = maxOffset > 0 and ((self.tableScrollOffset or 0) / maxOffset) or 0
    local yOffset = -2 - math.floor(travel * progress)

    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, yOffset)
    thumb.progress = progress
    thumb.travel = travel
end

function mainFrame:SetTableScrollOffset(offset)
    local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
    self.tableScrollOffset = math.max(0, math.min(offset or 0, maxOffset))
    self:RefreshVisibleTableRows()
    return self.tableScrollOffset
end

function mainFrame:DragScrollThumb(cursorY)
    local thumb = self.tableScrollBar and self.tableScrollBar.thumb

    if not thumb then
        return self.tableScrollOffset
    end

    local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
    local travel = math.max(1, thumb.travel or 1)
    local startCursorY = thumb.dragStartCursorY or cursorY or 0
    local startOffset = thumb.dragStartOffset or 0
    local deltaY = startCursorY - (cursorY or startCursorY)
    local progressDelta = deltaY / travel
    local nextOffset = startOffset + (maxOffset * progressDelta)

    return self:SetTableScrollOffset(math.floor(nextOffset + 0.5))
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

function mainFrame:GetSharedFilterState()
    local filters = {}

    for index, label in ipairs(self.tableHeaderLabels or {}) do
        local input = self.tableFilterInputs[index]
        local key = self.tableColumnKeys and self.tableColumnKeys[index]
        if key and input and label and label:GetText() ~= "" then
            filters[key] = input:GetText() or ""
        end
    end

    return filters
end

function mainFrame:ClearTableFilters()
    for _, input in ipairs(self.tableFilterInputs or {}) do
        input:SetText("")
    end
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
    if self.activeView ~= "INVENTORY" then
        return nil
    end

    local column = self.tableColumnLayout[index]
    if not column or column.sortable ~= true then
        return nil
    end

    if self.inventorySortState.key == column.key then
        self.inventorySortState.direction = self.inventorySortState.direction == "asc" and "desc" or "asc"
    else
        self.inventorySortState.key = column.key
        self.inventorySortState.direction = "asc"
    end

    self:ApplyInventoryFilters()
    return self.inventorySortState
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
        local db = ns.state.db or {}
        local key = minimum_rule_key({
            itemID = row.itemID,
            scope = row.scope,
            tabName = row.tabKey or row.tabName,
        })

        self.selectedMinimumKey = key
        local matchedRule = nil
        for _, rule in ipairs(db.minimums or {}) do
            local ruleKey = minimum_rule_key(rule)
            if ruleKey == key then
                matchedRule = rule
                break
            end
        end
        self:LoadMinimumRuleIntoEditor(matchedRule or {
            itemID = tonumber(row.itemID) or row.itemID,
            itemName = row.itemName,
            quantity = tonumber(row.quantity) or 0,
            scope = row.scope ~= "-" and row.scope or "GLOBAL",
            tabName = row.tabKey ~= "" and row.tabKey or nil,
            enabled = row.restock == "Yes",
            isDraft = matchedRule == nil,
        })
        self:RefreshVisibleTableRows()
        return row
    end

    if self.activeView == "TARGETS" and row.itemID then
        local db = ns.state.db or {}
        local key = target_rule_key({
            itemID = row.itemID,
            scope = row.scope,
            tabName = row.tabKey or row.tabName,
        })

        for _, target in ipairs(db.oneTimeTargets or {}) do
            if target_rule_key(target) == key then
                self:LoadTargetIntoEditor(target)
                break
            end
        end
        self:RefreshVisibleTableRows()
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
        return self.selectedMinimumKey ~= nil and minimum_rule_key({
            itemID = row.itemID,
            scope = row.scope,
            tabName = row.tabKey or row.tabName,
        }) == self.selectedMinimumKey
    end

    if self.activeView == "TARGETS" then
        return self.selectedTargetKey ~= nil and target_rule_key({
            itemID = row.itemID,
            scope = row.scope,
            tabName = row.tabKey or row.tabName,
        }) == self.selectedTargetKey
    end

    return false
end

function mainFrame:GetSelectedRequest()
    local db = ns.state.db or {}

    for _, request in ipairs(db.requests or {}) do
        if request.requestId == self.selectedRequestId then
            return request
        end
    end

    return nil
end

function mainFrame:SelectRequestById(requestId)
    self.selectedRequestId = requestId
    self:RefreshRequestActionButtons()
    return self:GetSelectedRequest()
end

function mainFrame:SelectFirstActionableRequest()
    local requestsView = ns.modules.requestsView
    local queue = requestsView and requestsView.BuildOfficerQueue and requestsView.BuildOfficerQueue((ns.state.db or {}).requests or {}) or {}
    local first = queue[1]

    self.selectedRequestId = first and first.requestId or nil
    self:RefreshRequestActionButtons()
    return first
end

function mainFrame:RefreshRequestActionButtons()
    local request = self:GetSelectedRequest()
    local isPending = request and request.approval == "PENDING"
    local isApprovedOpen = request and request.approval == "APPROVED" and request.fulfillment == "OPEN"
    local isFulfilled = request and request.fulfillment == "FULFILLED"

    self.requestApproveButton:SetEnabled(isPending)
    self.requestRejectButton:SetEnabled(isPending)
    self.requestFulfillButton:SetEnabled(isApprovedOpen)
    self.requestReopenButton:SetEnabled(isFulfilled)
end

function mainFrame:ApplyRequestAction(action)
    local requestsModule = ns.modules.requests
    local db = ns.state.db or {}
    local request = self:GetSelectedRequest()

    if not request or type(requestsModule) ~= "table" then
        return nil
    end

    local actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown"
    local note = self.requestActionNoteInput:GetText() or ""

    if action == "APPROVE" and type(requestsModule.ApproveStored) == "function" then
        request = requestsModule.ApproveStored(db, request.requestId, actor, _G.time())
    elseif action == "REJECT" and type(requestsModule.RejectStored) == "function" then
        request = requestsModule.RejectStored(db, request.requestId, actor, note, _G.time())
    elseif action == "FULFILL" and type(requestsModule.MarkFulfilledStored) == "function" then
        request = requestsModule.MarkFulfilledStored(db, request.requestId, actor, _G.time())
    elseif action == "REOPEN" and type(requestsModule.ReopenStored) == "function" then
        request = requestsModule.ReopenStored(db, request.requestId, actor, _G.time())
    else
        return nil
    end

    self.requestActionNoteInput:SetText("")
    if request and requestsModule then
        self.selectedRequestId = request.requestId
    end
    self:RefreshRequestActionButtons()
    self:RefreshView()
    return request
end

function mainFrame:LoadMinimumRuleIntoEditor(rule)
    rule = rule or {}
    self.minimumItemIDInput:SetText(rule.itemID and tostring(rule.itemID) or "")
    self.minimumItemNameInput:SetText(rule.itemName or "")
    self.minimumQuantityInput:SetText(rule.quantity and tostring(rule.quantity) or "")
    self.minimumScopeInput:SetText(rule.scope or "GLOBAL")
    self.minimumTabNameInput:SetText(rule.tabName or "")
    self.selectedMinimumEnabled = rule.enabled ~= false
    self.minimumRestockToggleButton.labelText:SetText(self.selectedMinimumEnabled and "Restock: Yes" or "Restock: No")
    self.selectedMinimumKey = minimum_rule_key(rule)
    self.minimumEditorStateText:SetText(rule.isDraft and "Draft from bank item. Set restock and save to include it in planning." or "Editing saved minimum rule.")
    return rule
end

function mainFrame:ClearMinimumEditor()
    self.selectedMinimumKey = nil
    self.selectedMinimumEnabled = false
    self.minimumItemIDInput:SetText("")
    self.minimumItemNameInput:SetText("")
    self.minimumQuantityInput:SetText("")
    self.minimumScopeInput:SetText("")
    self.minimumTabNameInput:SetText("")
    self.minimumRestockToggleButton.labelText:SetText("Restock: No")
    self.minimumEditorStateText:SetText("Create or select a rule to start editing.")
end

function mainFrame:LoadTargetIntoEditor(target)
    target = target or {}
    self.targetItemIDInput:SetText(target.itemID and tostring(target.itemID) or "")
    self.targetItemNameInput:SetText(target.itemName or "")
    self.targetQuantityInput:SetText(target.quantity and tostring(target.quantity) or "")
    self.targetScopeInput:SetText(target.scope or "GLOBAL")
    self.targetTabNameInput:SetText(target.tabName or "")
    self.selectedTargetStatus = target.status or "OPEN"
    self.selectedTargetKey = target_rule_key(target)
    self:UpdateTargetStatusLabel()
    if self:IsTargetSuggested(target) then
        self.targetEditorStateText:SetText("Inventory currently meets this target. Close it when the procurement work is done.")
    else
        self.targetEditorStateText:SetText("Editing saved target.")
    end
    return target
end

function mainFrame:ClearTargetEditor()
    self.selectedTargetKey = nil
    self.selectedTargetStatus = "OPEN"
    self.targetItemIDInput:SetText("")
    self.targetItemNameInput:SetText("")
    self.targetQuantityInput:SetText("")
    self.targetScopeInput:SetText("")
    self.targetTabNameInput:SetText("")
    self:UpdateTargetStatusLabel()
    self.targetEditorStateText:SetText("Create or select a target to start editing.")
end

function mainFrame:ToggleMinimumShowAllRows()
    self.minimumShowAllRows = not self.minimumShowAllRows
    self.minimumShowAllToggleButton.labelText:SetText(self.minimumShowAllRows and "Enabled Only" or "Show All")
    self:RefreshView()
    return self.minimumShowAllRows
end

function mainFrame:ToggleMinimumManualOnlyRows()
    self.minimumManualOnlyRows = not self.minimumManualOnlyRows
    self.minimumManualOnlyToggleButton.labelText:SetText(self.minimumManualOnlyRows and "All Sources" or "Manual Only")
    self:RefreshView()
    return self.minimumManualOnlyRows
end

function mainFrame:GetMinimumEmptyStateText(rows)
    rows = rows or {}

    if #rows > 0 then
        return ""
    end

    if self.minimumManualOnlyRows then
        return "No manual items match the current minimum filters."
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
    return rows, currentSnapshot
end

function mainFrame:GetCurrentSnapshot()
    local db = current_db()

    if db.currentSnapshotId ~= nil then
        return (db.snapshots or {})[db.currentSnapshotId] or { items = {} }
    end

    return { items = {} }
end

function mainFrame:IsTargetSuggested(target)
    target = target or {}

    if (target.status or "OPEN") ~= "OPEN" then
        return false
    end

    local snapshot = self:GetCurrentSnapshot()
    local item = (snapshot.items or {})[target.itemID]
    local current = item and item.totalCount or 0
    return current >= (target.quantity or 0)
end

function mainFrame:UpdateTargetStatusLabel()
    self.targetStatusButton.labelText:SetText(self.selectedTargetStatus == "OPEN" and "Status: Open" or "Status: Closed")
end

function mainFrame:GetExportUiState(db)
    db = db or current_db()
    db.ui = db.ui or {}
    db.ui.inventoryColumnWidths = db.ui.inventoryColumnWidths or {}
    db.ui.exportSettings = db.ui.exportSettings or {}
    db.ui.exportSettings.selectedPreset = db.ui.exportSettings.selectedPreset or "Spreadsheet"
    db.ui.exportSettings.customTemplate = clone_export_template(db.ui.exportSettings.customTemplate)
    return db.ui.exportSettings
end

function mainFrame:LoadExportSettingsFromDb(db)
    local exportSettings = self:GetExportUiState(db)
    self.exportSelectedPreset = exportSettings.selectedPreset or "Spreadsheet"
    self.exportCustomTemplate = clone_export_template(exportSettings.customTemplate)
    return exportSettings
end

function mainFrame:PersistExportSettings(db)
    local exportSettings = self:GetExportUiState(db)
    exportSettings.selectedPreset = self.exportSelectedPreset or "Spreadsheet"
    exportSettings.customTemplate = clone_export_template(self.exportCustomTemplate)
    return exportSettings
end

function mainFrame:UpdateSharedTableLayout()
    local anchor = self.viewSubtitle
    local offsetY = -24
    local viewportHeight = self.defaultTableViewportHeight

    if self.activeView == "REQUESTS" then
        anchor = self.requestCreatePanel
        offsetY = -16
        viewportHeight = 220
    elseif self.activeView == "MINIMUMS" then
        anchor = self.minimumsPanel
        offsetY = -16
        viewportHeight = 252
    elseif self.activeView == "TARGETS" then
        anchor = self.targetsPanel
        offsetY = -16
        viewportHeight = 252
    elseif self.activeView == "EXPORTS" then
        anchor = self.exportsPanel
        offsetY = -16
        viewportHeight = 224
    elseif self.activeView == "OPTIONS" then
        anchor = self.optionsPanel
        offsetY = -16
        viewportHeight = 0
    end

    self.tableViewportHeight = viewportHeight
    self.tableVisibleCount = math.max(1, math.floor(math.max(0, viewportHeight) / self.tableRowHeight))

    self.tableHeaderFrame:ClearAllPoints()
    self.tableHeaderFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)

    self.tableFilterFrame:ClearAllPoints()
    self.tableFilterFrame:SetPoint("TOPLEFT", self.tableHeaderFrame, "BOTTOMLEFT", 0, -4)

    self.tableScrollFrame:ClearAllPoints()
    self.tableScrollFrame:SetPoint("TOPLEFT", self.tableFilterFrame, "BOTTOMLEFT", 0, -4)
    self.tableScrollFrame:SetSize(self.tableViewportWidth, self.tableViewportHeight)

    self.tableScrollBar:ClearAllPoints()
    self.tableScrollBar:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPRIGHT", 8, 0)
    self.tableScrollBar:SetPoint("BOTTOMLEFT", self.tableScrollFrame, "BOTTOMRIGHT", 8, 0)
    self.tableScrollBar.track:SetHeight(math.max(24, self.tableViewportHeight - 64))
    self.tableScrollBar.track.topY = self.tableScrollBar.track.height or 0

    self.minimumEmptyStateText:ClearAllPoints()
    self.minimumEmptyStateText:SetPoint("TOPLEFT", self.tableScrollFrame, "TOPLEFT", 12, -12)
end

function mainFrame:RefreshExportOutput(rows)
    local exportDialog = ns.modules.exportDialog
    local state = exportDialog and type(exportDialog.BuildPresetState) == "function" and exportDialog.BuildPresetState(rows or {}, self.exportSelectedPreset, self.exportCustomTemplate) or {
        presetName = self.exportSelectedPreset,
        text = "",
    }

    self.exportsPresetTitle:SetText(state.presetName or self.exportSelectedPreset or "Spreadsheet")
    self.exportsOutputText:SetText(state.text or "")
    return state
end

function mainFrame:RefreshExportCustomControls()
    self.exportDelimiterInput:SetText(self.exportCustomTemplate.delimiter or "|")
    self.exportFieldsInput:SetText(table.concat(self.exportCustomTemplate.fields or {}, ","))
    self.exportHeaderToggleButton.labelText:SetText((self.exportCustomTemplate.includeHeader ~= false) and "Header: Yes" or "Header: No")
end

function mainFrame:SelectExportPreset(presetName)
    self.exportSelectedPreset = presetName or "Spreadsheet"
    self:PersistExportSettings(ns.state.db or {})
    if self.activeView == "EXPORTS" then
        local rows = self.tableRowsData or {}
        self:RefreshExportOutput(rows)
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

function mainFrame:BuildTargetFromEditor()
    local itemID = parse_number(self.targetItemIDInput:GetText() or "")
    local quantity = parse_number(self.targetQuantityInput:GetText() or "")
    local itemName = self.targetItemNameInput:GetText() or ""
    local scope = self.targetScopeInput:GetText() or "GLOBAL"
    local tabName = self.targetTabNameInput:GetText() or ""

    if not itemID or itemName == "" then
        return nil
    end

    return {
        itemID = itemID,
        itemName = itemName,
        quantity = quantity or 0,
        scope = scope ~= "" and scope or "GLOBAL",
        tabName = tabName ~= "" and tabName or nil,
        status = self.selectedTargetStatus or "OPEN",
    }
end

function mainFrame:ToggleMinimumRestock()
    self.selectedMinimumEnabled = not self.selectedMinimumEnabled
    self.minimumRestockToggleButton.labelText:SetText(self.selectedMinimumEnabled and "Restock: Yes" or "Restock: No")

    local minimumsView = ns.modules.minimumsView
    local db = ns.state.db or {}
    local rule = self:BuildMinimumRuleFromEditor()

    if rule and self.selectedMinimumKey and type(minimumsView) == "table" and type(minimumsView.SetEnabledWithAudit) == "function" then
        local updatedRule = minimumsView.SetEnabledWithAudit(db, rule, self.selectedMinimumEnabled, {
            actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
            timestamp = _G.time(),
        })
        self:LoadMinimumRuleIntoEditor(updatedRule)
        self:RefreshView()
        return updatedRule
    end

    return rule
end

function mainFrame:SaveMinimumFromEditor()
    local minimumsView = ns.modules.minimumsView
    local db = ns.state.db or {}
    local rule = self:BuildMinimumRuleFromEditor()

    if not rule or rule.quantity == nil or type(minimumsView) ~= "table" or type(minimumsView.UpsertWithAudit) ~= "function" then
        return nil
    end

    minimumsView.UpsertWithAudit(db, rule, {
        actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
        timestamp = _G.time(),
    })
    self:LoadMinimumRuleIntoEditor(rule)
    self:RefreshView()
    return rule
end

function mainFrame:ToggleTargetStatus()
    self.selectedTargetStatus = self.selectedTargetStatus == "OPEN" and "CLOSED" or "OPEN"
    self:UpdateTargetStatusLabel()

    local targetsView = ns.modules.targetsView
    local db = ns.state.db or {}
    local target = self:BuildTargetFromEditor()

    if target and self.selectedTargetKey and type(targetsView) == "table" and type(targetsView.SetStatusWithAudit) == "function" then
        local updatedTarget = targetsView.SetStatusWithAudit(db, target, self.selectedTargetStatus, {
            actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
            timestamp = _G.time(),
        })
        self:LoadTargetIntoEditor(updatedTarget)
        self:RefreshView()
        return updatedTarget
    end

    return target
end

function mainFrame:SaveTargetFromEditor()
    local targetsView = ns.modules.targetsView
    local db = ns.state.db or {}
    local target = self:BuildTargetFromEditor()

    if not target or target.quantity == nil or type(targetsView) ~= "table" or type(targetsView.UpsertWithAudit) ~= "function" then
        return nil
    end

    targetsView.UpsertWithAudit(db, target, {
        actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
        timestamp = _G.time(),
    })
    self:LoadTargetIntoEditor(target)
    self:RefreshView()
    return target
end

function mainFrame:CreateRequestFromEditor()
    local requestsModule = ns.modules.requests
    local db = ns.state.db or {}
    local requester = self.requestCreateRequesterInput:GetText() or ""
    local role = self.requestCreateRoleInput:GetText() or "MEMBER"
    local itemID = parse_number(self.requestCreateItemIDInput:GetText() or "")
    local itemName = self.requestCreateItemNameInput:GetText() or ""
    local quantity = parse_number(self.requestCreateQuantityInput:GetText() or "")
    local note = self.requestCreateNoteInput:GetText() or ""

    if requester == "" or role == "" or not itemID or itemName == "" or not quantity or type(requestsModule) ~= "table" or type(requestsModule.CreateAndStore) ~= "function" then
        return nil
    end

    local request = requestsModule.CreateAndStore(db, {
        requester = requester,
        role = role,
        itemID = itemID,
        itemName = itemName,
        quantity = quantity,
        note = note,
    })

    self.selectedRequestId = request and request.requestId or nil
    self.requestCreateRequesterInput:SetText("")
    self.requestCreateRoleInput:SetText("")
    self.requestCreateItemIDInput:SetText("")
    self.requestCreateItemNameInput:SetText("")
    self.requestCreateQuantityInput:SetText("")
    self.requestCreateNoteInput:SetText("")
    self:RefreshRequestActionButtons()
    self:RefreshView()
    return request
end

function mainFrame:RefreshView()
    local db = current_db()
    local currentSnapshot = nil
    local planning = ns.modules.planning
    local dashboardView = ns.modules.dashboardView
    local inventoryView = ns.modules.inventoryView
    local historyView = ns.modules.historyView
    local minimumsView = ns.modules.minimumsView
    local targetsView = ns.modules.targetsView
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
    self.minimumEmptyStateText:Hide()
    self.targetsPanel:Hide()
    self.exportsPanel:Hide()
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
        local rows = historyView.BuildTableRows(db.auditLog or {}, self:GetSharedFilterState())
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "category", label = "Category", width = 100, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 170, justifyH = "LEFT" },
            { key = "action", label = "Action", width = 100, justifyH = "LEFT" },
            { key = "actor", label = "Who", width = 100, justifyH = "LEFT" },
            { key = "oldValue", label = "Old", width = 80, justifyH = "LEFT" },
            { key = "newValue", label = "New", width = 80, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        showTable = true
    elseif self.activeView == "MINIMUMS" then
        self.minimumShowAllToggleButton.labelText:SetText(self.minimumShowAllRows and "Enabled Only" or "Show All")
        self.minimumManualOnlyToggleButton.labelText:SetText(self.minimumManualOnlyRows and "All Sources" or "Manual Only")
        local rows = minimumsView.BuildTableRows(db.minimums or {}, currentSnapshot or { items = {} }, {
            showAll = self.minimumShowAllRows,
            search = self.minimumSearchInput:GetText() or "",
            manualOnly = self.minimumManualOnlyRows,
        })
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "itemID", label = "Item ID", width = 70, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 180, justifyH = "LEFT" },
            { key = "current", label = "Current", width = 70, justifyH = "LEFT" },
            { key = "restock", label = "Restock", width = 80, justifyH = "LEFT" },
            { key = "quantity", label = "Minimum", width = 80, justifyH = "LEFT" },
            { key = "source", label = "Source", width = 90, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
        local emptyStateText = self:GetMinimumEmptyStateText(rows)
        self.minimumEmptyStateText:SetText(emptyStateText)
        if emptyStateText ~= "" then
            self.minimumEmptyStateText:Show()
        else
            self.minimumEmptyStateText:Hide()
        end
        showTable = true
    elseif self.activeView == "TARGETS" then
        local rows = targetsView and type(targetsView.BuildTableRows) == "function" and targetsView.BuildTableRows(db.oneTimeTargets or {}, currentSnapshot or { items = {} }) or {}
        self.tableScrollOffset = 0
        self:ConfigureTable({
            { key = "itemID", label = "Item ID", width = 70, justifyH = "LEFT" },
            { key = "itemName", label = "Item", width = 180, justifyH = "LEFT" },
            { key = "current", label = "Current", width = 70, justifyH = "LEFT" },
            { key = "status", label = "Status", width = 80, justifyH = "LEFT" },
            { key = "quantity", label = "Target", width = 80, justifyH = "LEFT" },
            { key = "scope", label = "Scope", width = 90, justifyH = "LEFT" },
        }, rows)
        self:RefreshVisibleTableRows()
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
        bodyText = ""
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
        self.tableFilterFrame:Show()
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

    if self.activeView == "TARGETS" then
        self.targetsPanel:Show()
    else
        self.targetsPanel:Hide()
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

mainFrame.tableScrollBar.scrollUpButton:SetScript("OnClick", function()
    mainFrame:ScrollTableRows(-1)
end)

mainFrame.tableScrollBar.scrollDownButton:SetScript("OnClick", function()
    mainFrame:ScrollTableRows(1)
end)

mainFrame.tableScrollBar.thumb:SetScript("OnMouseDown", function(self)
    self.dragging = true
    self.dragStartOffset = mainFrame.tableScrollOffset or 0
    if type(_G.GetCursorPosition) == "function" then
        local _, cursorY = _G.GetCursorPosition()
        self.dragStartCursorY = cursorY
    else
        self.dragStartCursorY = 0
    end
end)

mainFrame.tableScrollBar.thumb:SetScript("OnMouseUp", function(self)
    self.dragging = false
    self.dragStartOffset = nil
    self.dragStartCursorY = nil
end)

mainFrame.tableScrollBar.track:SetScript("OnMouseDown", function()
    return nil
end)

mainFrame.tableScrollBar:SetScript("OnUpdate", function()
    if mainFrame.tableScrollBar.thumb.dragging and type(_G.GetCursorPosition) == "function" then
        mainFrame:DragScrollThumb(select(2, _G.GetCursorPosition()))
    end
end)

mainFrame.tableScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    mainFrame:ScrollTableRows(-delta)
end)

for _, input in ipairs(mainFrame.tableFilterInputs) do
    input:SetScript("OnTextChanged", function()
        if mainFrame.isConfiguringTable then
            return
        end
        if mainFrame.activeView == "INVENTORY" then
            mainFrame:ApplyInventoryFilters()
        elseif mainFrame.activeView == "HISTORY" then
            mainFrame:RefreshView()
        end
    end)
end

mainFrame.minimumSearchInput:SetScript("OnTextChanged", function()
    if mainFrame.activeView == "MINIMUMS" then
        mainFrame:RefreshView()
    end
end)

function mainFrame:SelectView(name)
    local nextView = name or "DASHBOARD"
    if nextView ~= self.activeView then
        self:ClearTableFilters()
    end
    self.activeView = nextView
    self.viewTitle:SetText((name or "Dashboard"):gsub("^%l", string.upper):gsub("_", " "))
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
