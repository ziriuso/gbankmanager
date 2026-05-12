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
    input:SetText("")
    return input
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
mainFrame.subtitleText = mainFrame.subtitleText or make_label(mainFrame.topBar, "Action queue first", "GameFontHighlightSmall")
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
mainFrame.tableViewportWidth = 690
mainFrame.tableViewportInnerWidth = 690
mainFrame.tableHeaderHeight = 28
mainFrame.tableFilterHeight = 28
mainFrame.tableRowHeight = 26
mainFrame.tableViewportHeight = 364
mainFrame.tableVisibleCount = math.floor(mainFrame.tableViewportHeight / mainFrame.tableRowHeight)

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

mainFrame.tableRows = mainFrame.tableRows or {}
    for rowIndex = 1, mainFrame.tableVisibleCount do
        local row = mainFrame.tableRows[rowIndex] or _G.CreateFrame("Frame", nil, mainFrame.tableScrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", mainFrame.tableScrollChild, "TOPLEFT", 0, -((rowIndex - 1) * mainFrame.tableRowHeight))
        row:SetSize(mainFrame.tableViewportWidth, mainFrame.tableRowHeight - 2)
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

mainFrame.optionsPanel = mainFrame.optionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.optionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
mainFrame.optionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
mainFrame.optionsPanel:SetHeight(92)
apply_panel_style(mainFrame.optionsPanel, theme.colors.panel)
mainFrame.optionsPanel:Hide()

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
    apply_panel_style(self.transparencyDownButton, theme.colors.panel)
    apply_panel_style(self.transparencyUpButton, theme.colors.panel)
    apply_panel_style(self.tableScrollBar, theme.colors.panel)
    apply_panel_style(self.tableScrollBar.scrollUpButton, theme.colors.panelAlt)
    apply_panel_style(self.tableScrollBar.scrollDownButton, theme.colors.panelAlt)

    for index, row in ipairs(self.tableRows) do
        apply_panel_style(row, index % 2 == 1 and theme.colors.panel or theme.colors.panelAlt)
    end

    for _, input in ipairs(self.tableFilterInputs) do
        apply_panel_style(input, theme.colors.background)
    end
end

function mainFrame:ConfigureTable(columns, rows)
    self.tableColumnLayout = columns or {}
    self.tableColumnKeys = {}
    local offset = 12

    for index = 1, #self.tableHeaderLabels do
        local label = self.tableHeaderLabels[index]
        local columnLayout = self.tableColumnLayout[index] or {}
        local width = columnLayout.width or 120
        self.tableColumnKeys[index] = columnLayout.key

        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset, -8)
        label:SetWidth(width)
        label:SetText(columnLayout.label or "")
        if type(label.SetJustifyH) == "function" then
            label:SetJustifyH(columnLayout.justifyH or "LEFT")
        end

        local input = self.tableFilterInputs[index]
        input:ClearAllPoints()
        input:SetPoint("TOPLEFT", self.tableFilterFrame, "TOPLEFT", offset, -3)
        input:SetWidth(width)

        for _, rowFrame in ipairs(self.tableRows) do
            local column = rowFrame.columns[index]
            column:ClearAllPoints()
            column:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", offset, -4)
            column:SetWidth(width)
            if type(column.SetJustifyH) == "function" then
                column:SetJustifyH(columnLayout.justifyH or "LEFT")
            end
        end

        if index < #self.tableHeaderLabels then
            local handle = self.tableColumnResizeHandles[index] or _G.CreateFrame("Button", nil, self.tableHeaderFrame, "BackdropTemplate")
            handle:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset + width + 4, 0)
            handle:SetSize(8, 28)
            apply_panel_style(handle, theme.colors.border)
            handle:SetScript("OnClick", function()
                mainFrame:ResizeInventoryColumn(index, 24)
            end)
            self.tableColumnResizeHandles[index] = handle
        end

        offset = offset + width + 12
    end

    self.tableRowsData = rows or {}
    self.tableViewportInnerWidth = self.tableViewportWidth
    self.tableScrollChild:SetSize(self.tableViewportInnerWidth, math.max(self.tableViewportHeight, (#self.tableRowsData * self.tableRowHeight)))
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
    end

    local maxRow = math.max(1, #self.tableRowsData)
    self.tableScrollBar.valueText:SetText(string.format("%d-%d", math.min(maxRow, self.tableScrollOffset + 1), math.min(maxRow, self.tableScrollOffset + self.tableVisibleCount)))
end

function mainFrame:ScrollTableRows(delta)
    self.tableScrollOffset = (self.tableScrollOffset or 0) + (delta or 0)
    self:RefreshVisibleTableRows()
    return self.tableScrollOffset
end

function mainFrame:ResizeInventoryColumn(index, delta)
    local inventoryView = ns.modules.inventoryView
    if not inventoryView or type(inventoryView.ResizeColumnLayout) ~= "function" then
        return
    end

    self.tableColumnLayout = inventoryView.ResizeColumnLayout(self.tableColumnLayout, index, delta, 720)
    ns.state.db = ns.state.db or {}
    ns.state.db.ui = ns.state.db.ui or {}
    ns.state.db.ui.inventoryColumnWidths = ns.state.db.ui.inventoryColumnWidths or {}

    local defaults = inventoryView.GetDefaultColumns()
    for columnIndex, column in ipairs(self.tableColumnLayout) do
        ns.state.db.ui.inventoryColumnWidths[columnIndex] = (column.width or 0) - (defaults[columnIndex].width or 0)
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
    local db = self.cachedInventoryDb or ns.state.db or {}
    local snapshot = self.cachedInventorySnapshot or { items = {} }
    local layout = inventoryView.GetColumnLayout(db, self.tableViewportWidth)
    local rows = inventoryView.BuildTableRows(snapshot, db, self:GetInventoryFilterState())
    local displayRows = inventoryView.BuildDisplayRows(rows, layout)

    self.tableColumnLayout = layout
    self.tableScrollOffset = 0
    self.cachedInventoryRows = rows
    self:ConfigureTable(layout, displayRows)
    self:RefreshVisibleTableRows()
end

function mainFrame:RefreshView()
    local db = ns.state.db or {}
    local currentSnapshot = nil
    local planning = ns.modules.planning
    local dashboardView = ns.modules.dashboardView
    local inventoryView = ns.modules.inventoryView
    local historyView = ns.modules.historyView
    local requestsView = ns.modules.requestsView

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
        local rows = historyView.BuildTableRows(db.auditLog or {}, {})
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
    elseif self.activeView == "REQUESTS" then
        local rows = requestsView.BuildTableRows(db.requests or {})
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
    elseif self.activeView == "OPTIONS" then
        bodyText = "Transparency controls moved here to keep the top bar focused."
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
end

mainFrame.tableScrollBar.scrollUpButton:SetScript("OnClick", function()
    mainFrame:ScrollTableRows(-1)
end)

mainFrame.tableScrollBar.scrollDownButton:SetScript("OnClick", function()
    mainFrame:ScrollTableRows(1)
end)

mainFrame.tableScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    mainFrame:ScrollTableRows(-delta)
end)

for _, input in ipairs(mainFrame.tableFilterInputs) do
    input:SetScript("OnTextChanged", function()
        if mainFrame.activeView == "INVENTORY" then
            mainFrame:ApplyInventoryFilters()
        end
    end)
end

function mainFrame:SelectView(name)
    self.activeView = name or "DASHBOARD"
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
    local pending = summary.pendingRequestCount or 0
    local suggested = summary.suggestedFulfillmentCount or 0
    self.statusText:SetText(string.format("Last scan %s | %d pending | %d suggested", tostring(lastScanAt), pending, suggested))
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
