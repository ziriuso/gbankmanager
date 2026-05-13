local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}

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

local function theme()
    return ns.ui.theme
end

function mainFrameShell.GetTheme()
    return theme()
end

function mainFrameShell.ApplyPanelStyle(frame, color)
    if not frame then
        return
    end

    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop(backdrop)
    end

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(unpack(color or theme().colors.panel))
    end

    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(unpack(theme().colors.border))
    end
end

function mainFrameShell.MakeLabel(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    if type(label.SetJustifyH) == "function" then
        label:SetJustifyH("LEFT")
    end
    label:SetText(text or "")
    return label
end

function mainFrameShell.MakeButton(parent, width, height, text)
    local button = _G.CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    mainFrameShell.ApplyPanelStyle(button, theme().colors.panel)
    button.labelText = button.labelText or mainFrameShell.MakeLabel(button, text, "GameFontNormal")
    if type(button.labelText.SetJustifyH) == "function" then
        button.labelText:SetJustifyH("CENTER")
    end
    if type(button.labelText.ClearAllPoints) == "function" then
        button.labelText:ClearAllPoints()
    end
    button.labelText:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.labelText:SetText(text or "")
    return button
end

function mainFrameShell.SetButtonIcon(button, kind)
    if not button then
        return
    end

    button.iconKind = kind
    if button.labelText then
        button.labelText:SetText("")
    end

    button.iconTexture = button.iconTexture or button:CreateTexture()
    if type(button.iconTexture.SetAllPoints) == "function" then
        button.iconTexture:SetAllPoints()
    end
    if type(button.iconTexture.SetAtlas) == "function" then
        button.iconTexture:SetAtlas(kind == "remove" and "common-icon-redx" or "common-icon-undo", true)
    end

    button.iconLabel = button.iconLabel or mainFrameShell.MakeLabel(button, "", "GameFontHighlightSmall")
    if type(button.iconLabel.ClearAllPoints) == "function" then
        button.iconLabel:ClearAllPoints()
    end
    button.iconLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.iconLabel:SetText(kind == "remove" and "X" or "U")
end

function mainFrameShell.MakeInput(parent, width, height)
    local input = _G.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(width, height)
    mainFrameShell.ApplyPanelStyle(input, theme().colors.background)
    if type(input.SetAutoFocus) == "function" then
        input:SetAutoFocus(false)
    end
    if type(input.SetFontObject) == "function" then
        input:SetFontObject("GameFontHighlightSmall")
    end
    if type(input.SetTextColor) == "function" then
        input:SetTextColor(unpack(theme().colors.accentStrong))
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

function mainFrameShell.MakeSlider(parent, width, height, minValue, maxValue, initialValue)
    local slider = _G.CreateFrame("Slider", nil, parent, "BackdropTemplate")
    slider:SetSize(width, height)
    slider.minValue = minValue or 0
    slider.maxValue = maxValue or 1
    slider.value = initialValue or slider.minValue
    mainFrameShell.ApplyPanelStyle(slider, theme().colors.background)

    local baseSetValue = slider.SetValue
    function slider:SetValue(value)
        value = math.max(self.minValue, math.min(self.maxValue, value or self.minValue))
        baseSetValue(self, value)
        local handler = self.scripts and self.scripts.OnValueChanged
        if type(handler) == "function" then
            handler(self, value)
        end
    end

    return slider
end

function mainFrameShell.SetFrameShown(frame, shouldShow)
    if not frame then
        return
    end

    if shouldShow then
        frame:Show()
    else
        frame:Hide()
    end
end

function mainFrameShell.EnsureShell(mainFrame)
    if type(mainFrame) ~= "table" or type(mainFrame.SetSize) ~= "function" then
        mainFrame = _G.CreateFrame("Frame", "GBankManagerFrame", _G.UIParent, "BackdropTemplate")
    end

    local currentTheme = theme()

    mainFrame:SetSize(currentTheme.spacing.frameWidth, currentTheme.spacing.frameHeight)
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
    mainFrameShell.ApplyPanelStyle(mainFrame, currentTheme.colors.background)
    mainFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    mainFrame.activeView = mainFrame.activeView or "DASHBOARD"
    if mainFrame.collapsedSidebar == nil then
        mainFrame.collapsedSidebar = false
    end
    mainFrame.navItems = mainFrame.navItems or {
        { key = "DASHBOARD", label = "Dashboard" },
        { key = "INVENTORY", label = "Inventory" },
        { key = "HISTORY", label = "History" },
        { key = "MINIMUMS", label = "Minimums" },
        { key = "REQUESTS", label = "Requests" },
        { key = "EXPORTS", label = "Exports" },
        { key = "ABOUT", label = "About" },
        { key = "OPTIONS", label = "Options" },
    }
    mainFrame.viewDescriptions = mainFrame.viewDescriptions or {
        DASHBOARD = "Critical shortages, pending requests, and export readiness.",
        INVENTORY = "Search the latest bank snapshot and inspect current counts.",
        HISTORY = "Review procurement audit events with explicit timestamps and before/after values.",
        MINIMUMS = "Manage Guild Bank Item Minimum Stock Levels",
        REQUESTS = "Review officer-first request queues and member-visible demand.",
        EXPORTS = "Prepare Auctionator and spreadsheet-ready purchase output.",
        ABOUT = "Reference addon ownership, guild identity, runtime build info, and support notes.",
        OPTIONS = "Adjust shell behavior like transparency without cluttering the main toolbar.",
    }

    mainFrame.sidebar = mainFrame.sidebar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    mainFrame.sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
    mainFrame.sidebar:SetWidth(currentTheme.spacing.sidebarExpanded)
    mainFrameShell.ApplyPanelStyle(mainFrame.sidebar, currentTheme.colors.panel)

    mainFrame.topBar = mainFrame.topBar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.topBar:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetHeight(currentTheme.spacing.topBarHeight)
    mainFrameShell.ApplyPanelStyle(mainFrame.topBar, currentTheme.colors.panelAlt)

    mainFrame.content = mainFrame.content or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.content:SetPoint("TOPLEFT", mainFrame.topBar, "BOTTOMLEFT", 0, 0)
    mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
    mainFrameShell.ApplyPanelStyle(mainFrame.content, currentTheme.colors.background)

    mainFrame.titleText = mainFrame.titleText or mainFrameShell.MakeLabel(mainFrame.topBar, "Guild Bank Manager", "GameFontHighlightLarge")
    if type(mainFrame.titleText.ClearAllPoints) == "function" then
        mainFrame.titleText:ClearAllPoints()
    end
    mainFrame.titleText:SetPoint("TOPLEFT", mainFrame.topBar, "TOPLEFT", 36, -14)

    mainFrame.subtitleText = mainFrame.subtitleText or mainFrameShell.MakeLabel(mainFrame.topBar, "Guild Bank Management", "GameFontHighlightSmall")
    if type(mainFrame.subtitleText.ClearAllPoints) == "function" then
        mainFrame.subtitleText:ClearAllPoints()
    end
    mainFrame.subtitleText:SetPoint("TOPLEFT", mainFrame.titleText, "BOTTOMLEFT", 0, -6)

    mainFrame.statusText = mainFrame.statusText or mainFrameShell.MakeLabel(mainFrame.topBar, "No scan yet", "GameFontNormal")
    if type(mainFrame.statusText.ClearAllPoints) == "function" then
        mainFrame.statusText:ClearAllPoints()
    end
    mainFrame.statusText:SetPoint("RIGHT", mainFrame.topBar, "RIGHT", -152, 0)

    mainFrame.collapseButton = mainFrame.collapseButton or mainFrameShell.MakeButton(mainFrame.sidebar, 28, 28, "<")
    mainFrame.collapseButton:SetPoint("TOPRIGHT", mainFrame.sidebar, "TOPRIGHT", -10, -10)
    mainFrame.collapseButton:SetScript("OnClick", function()
        if type(mainFrame.ToggleSidebar) == "function" then
            mainFrame:ToggleSidebar()
        end
    end)

    mainFrame.scanButton = mainFrame.scanButton or mainFrameShell.MakeButton(mainFrame.topBar, 120, 28, "Scan Bank")
    mainFrame.scanButton:SetPoint("TOP", mainFrame.topBar, "TOP", 0, -16)
    mainFrame.scanButton:SetScript("OnClick", function()
        local scanner = ns.modules.scanner
        if scanner and type(scanner.BeginScan) == "function" then
            scanner.BeginScan()
        end
    end)

    return mainFrame
end

ns.modules.mainFrameShell = mainFrameShell

return mainFrameShell
