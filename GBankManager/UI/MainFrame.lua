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

local function apply_panel_style(frame, color)
    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(unpack(color))
    end

    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(unpack(theme.colors.border))
    end
end

local function make_label(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetText(text or "")
    return label
end

mainFrame:SetSize(theme.spacing.frameWidth, theme.spacing.frameHeight)
mainFrame:SetPoint("CENTER")
mainFrame:SetClampedToScreen(true)
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetResizable(true)
mainFrame:SetMinResize(920, 560)
mainFrame:SetMaxResize(1280, 760)
mainFrame:Hide()
apply_panel_style(mainFrame, theme.colors.background)

mainFrame.activeView = mainFrame.activeView or "DASHBOARD"
mainFrame.collapsedSidebar = false
mainFrame.navItems = {
    { key = "DASHBOARD", label = "Dashboard" },
    { key = "INVENTORY", label = "Inventory" },
    { key = "MINIMUMS", label = "Minimums" },
    { key = "TARGETS", label = "Targets" },
    { key = "REQUESTS", label = "Requests" },
    { key = "HISTORY", label = "History" },
    { key = "EXPORTS", label = "Exports" },
}
mainFrame.viewDescriptions = {
    DASHBOARD = "Critical shortages, pending requests, and export readiness.",
    INVENTORY = "Search the latest bank snapshot and inspect current counts.",
    MINIMUMS = "Manage recurring stock floors by item, scope, and tab.",
    TARGETS = "Track one-time buy-up goals and suggested fulfillment state.",
    REQUESTS = "Review officer-first request queues and member-visible demand.",
    HISTORY = "Audit scan-to-scan item changes with focused filters.",
    EXPORTS = "Prepare Auctionator and spreadsheet-ready purchase output.",
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

mainFrame.titleText = mainFrame.titleText or make_label(mainFrame.topBar, "Guild Bank Dashboard")
mainFrame.subtitleText = mainFrame.subtitleText or make_label(mainFrame.topBar, "Action queue first")
mainFrame.statusText = mainFrame.statusText or make_label(mainFrame.topBar, "No scan yet")
mainFrame.primaryActionText = mainFrame.primaryActionText or make_label(mainFrame.topBar, "Scan Bank")

mainFrame.viewTitle = mainFrame.viewTitle or make_label(mainFrame.content, "Dashboard")
mainFrame.viewSubtitle = mainFrame.viewSubtitle or make_label(mainFrame.content, "Critical shortages, pending requests, and export readiness.")

mainFrame.sidebarButtons = mainFrame.sidebarButtons or {}
for index, item in ipairs(mainFrame.navItems) do
    local button = mainFrame.sidebarButtons[index] or _G.CreateFrame("Button", nil, mainFrame.sidebar, "BackdropTemplate")
    button.key = item.key
    button.labelText = button.labelText or make_label(button, item.label)
    button.labelText:SetText(item.label)
    button:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -40 - ((index - 1) * 44))
    button:SetSize(theme.spacing.sidebarExpanded - 32, 32)
    apply_panel_style(button, item.key == mainFrame.activeView and theme.colors.panelAlt or theme.colors.panel)
    mainFrame.sidebarButtons[index] = button
end

function mainFrame:ApplyTheme()
    local sidebarWidth = self.collapsedSidebar and theme.spacing.sidebarCollapsed or theme.spacing.sidebarExpanded
    self.sidebar:SetWidth(sidebarWidth)
    apply_panel_style(self, theme.colors.background)
    apply_panel_style(self.sidebar, theme.colors.panel)
    apply_panel_style(self.topBar, theme.colors.panelAlt)
    apply_panel_style(self.content, theme.colors.background)

    for _, button in ipairs(self.sidebarButtons) do
        local isActive = button.key == self.activeView
        apply_panel_style(button, isActive and theme.colors.panelAlt or theme.colors.panel)
        button.labelText:SetText(self.collapsedSidebar and string.sub(button.key, 1, 1) or button.key:sub(1, 1) .. string.lower(button.key:sub(2)))
    end
end

function mainFrame:SelectView(name)
    self.activeView = name or "DASHBOARD"
    self.viewTitle:SetText((name or "Dashboard"):gsub("^%l", string.upper):gsub("_", " "))
    self.viewSubtitle:SetText(self.viewDescriptions[self.activeView] or self.viewDescriptions.DASHBOARD)
    self:ApplyTheme()
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

mainFrame:ApplyTheme()

ns.modules.mainFrame = mainFrame

return mainFrame
