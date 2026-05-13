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
    local slider = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slider:SetSize(width, height)
    slider.minValue = minValue or 0
    slider.maxValue = maxValue or 1
    slider.value = initialValue or slider.minValue
    mainFrameShell.ApplyPanelStyle(slider, theme().colors.background)
    if type(slider.SetBackdropColor) == "function" then
        slider:SetBackdropColor(0, 0, 0, 0)
    end
    if type(slider.SetBackdropBorderColor) == "function" then
        slider:SetBackdropBorderColor(0, 0, 0, 0)
    end
    slider.track = slider.track or _G.CreateFrame("Frame", nil, slider, "BackdropTemplate")
    slider.track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    slider.track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    slider.track:SetWidth(width)
    slider.track:SetHeight(math.max(6, math.floor((height or 18) / 3)))
    mainFrameShell.ApplyPanelStyle(slider.track, theme().colors.panel)

    slider.fill = slider.fill or _G.CreateFrame("Frame", nil, slider.track, "BackdropTemplate")
    slider.fill:SetPoint("TOPLEFT", slider.track, "TOPLEFT", 0, 0)
    slider.fill:SetPoint("BOTTOMLEFT", slider.track, "BOTTOMLEFT", 0, 0)
    slider.fill:SetWidth(0)
    mainFrameShell.ApplyPanelStyle(slider.fill, theme().colors.accent)

    slider.thumb = slider.thumb or _G.CreateFrame("Frame", nil, slider, "BackdropTemplate")
    slider.thumb:SetSize(8, math.max(12, height or 18))
    slider.thumb:SetPoint("CENTER", slider.track, "LEFT", 0, 0)
    mainFrameShell.ApplyPanelStyle(slider.thumb, theme().colors.accentStrong)

    local function clamp_value(self, value)
        return math.max(self.minValue, math.min(self.maxValue, value or self.minValue))
    end

    local function sync_visuals(self, value)
        local range = math.max(1, (self.maxValue or 1) - (self.minValue or 0))
        local ratio = (value - (self.minValue or 0)) / range
        local usableWidth = math.max(0, (self.track:GetWidth() or self:GetWidth() or width or 0))
        if self.fill and type(self.fill.SetWidth) == "function" then
            self.fill:SetWidth(math.max(0, math.floor(usableWidth * ratio)))
        end
        if self.thumb then
            if type(self.thumb.ClearAllPoints) == "function" then
                self.thumb:ClearAllPoints()
            end
            self.thumb:SetPoint("CENTER", self.track, "LEFT", math.floor(usableWidth * ratio), 0)
        end
    end

    function slider:SetValue(value)
        value = clamp_value(self, value)
        self.value = value
        sync_visuals(self, value)
        if type(self.onValueChanged) == "function" then
            self.onValueChanged(self, value)
        end
    end

    if type(slider.EnableMouse) == "function" then
        slider:EnableMouse(false)
    end
    if type(slider.track.EnableMouse) == "function" then
        slider.track:EnableMouse(false)
    end
    if type(slider.thumb.EnableMouse) == "function" then
        slider.thumb:EnableMouse(false)
    end

    slider:SetValue(slider.value)

    return slider
end

function mainFrameShell.MakeSlimScrollBar(parent, width)
    local function assign_atlas(texture, atlas)
        if not texture then
            return
        end

        texture.atlas = atlas
        if type(texture.SetAtlas) == "function" then
            texture:SetAtlas(atlas, true)
        end
    end

    local scrollBar = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollBar:SetWidth(width or 14)
    if type(scrollBar.SetBackdrop) == "function" then
        scrollBar:SetBackdrop(nil)
    end

    scrollBar.track = scrollBar.track or _G.CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    scrollBar.track:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", 0, 0)
    scrollBar.track:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", 0, 0)
    if type(scrollBar.track.SetBackdrop) == "function" then
        scrollBar.track:SetBackdrop(nil)
    end
    scrollBar.track.Begin = scrollBar.track.Begin or scrollBar.track:CreateTexture(nil, "ARTWORK")
    scrollBar.track.Middle = scrollBar.track.Middle or scrollBar.track:CreateTexture(nil, "ARTWORK")
    scrollBar.track.End = scrollBar.track.End or scrollBar.track:CreateTexture(nil, "ARTWORK")
    scrollBar.track.Begin:SetPoint("TOPLEFT", scrollBar.track, "TOPLEFT", 0, 0)
    scrollBar.track.End:SetPoint("BOTTOMLEFT", scrollBar.track, "BOTTOMLEFT", 0, 0)
    scrollBar.track.Middle:SetPoint("TOPLEFT", scrollBar.track.Begin, "BOTTOMLEFT", 0, 0)
    scrollBar.track.Middle:SetPoint("BOTTOMRIGHT", scrollBar.track.End, "TOPRIGHT", 0, 0)
    assign_atlas(scrollBar.track.Begin, "minimal-scrollbar-track-top")
    assign_atlas(scrollBar.track.Middle, "!minimal-scrollbar-track-middle")
    assign_atlas(scrollBar.track.End, "minimal-scrollbar-track-bottom")

    scrollBar.thumb = scrollBar.thumb or _G.CreateFrame("Button", nil, scrollBar.track, "BackdropTemplate")
    scrollBar.thumb:SetWidth(math.max(8, (width or 14) - 4))
    scrollBar.thumb:SetHeight(48)
    scrollBar.thumb:SetPoint("TOP", scrollBar.track, "TOP", 0, -2)
    if type(scrollBar.thumb.SetBackdrop) == "function" then
        scrollBar.thumb:SetBackdrop(nil)
    end
    scrollBar.thumb:EnableMouse(true)
    scrollBar.thumb.Begin = scrollBar.thumb.Begin or scrollBar.thumb:CreateTexture(nil, "ARTWORK")
    scrollBar.thumb.Middle = scrollBar.thumb.Middle or scrollBar.thumb:CreateTexture(nil, "ARTWORK")
    scrollBar.thumb.End = scrollBar.thumb.End or scrollBar.thumb:CreateTexture(nil, "ARTWORK")
    scrollBar.thumb.Begin:SetPoint("TOPLEFT", scrollBar.thumb, "TOPLEFT", 0, 0)
    scrollBar.thumb.End:SetPoint("BOTTOMLEFT", scrollBar.thumb, "BOTTOMLEFT", 0, 0)
    scrollBar.thumb.Middle:SetPoint("TOPLEFT", scrollBar.thumb.Begin, "BOTTOMLEFT", 0, 0)
    scrollBar.thumb.Middle:SetPoint("BOTTOMRIGHT", scrollBar.thumb.End, "TOPRIGHT", 0, 0)
    assign_atlas(scrollBar.thumb.Begin, "minimal-scrollbar-small-thumb-top")
    assign_atlas(scrollBar.thumb.Middle, "minimal-scrollbar-small-thumb-middle")
    assign_atlas(scrollBar.thumb.End, "minimal-scrollbar-small-thumb-bottom")

    function scrollBar:UpdateThumb(progress, visibleRatio)
        local trackHeight = self.track:GetHeight() or self:GetHeight() or 0
        local thumbHeight = math.max(24, math.floor(trackHeight * math.max(0.08, math.min(1, visibleRatio or 0.25))))
        local travel = math.max(0, trackHeight - thumbHeight)
        local clampedProgress = math.max(0, math.min(1, progress or 0))

        self.thumb:SetHeight(thumbHeight)
        if type(self.thumb.ClearAllPoints) == "function" then
            self.thumb:ClearAllPoints()
        end
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -math.floor(travel * clampedProgress))
        self.thumb.progress = clampedProgress
        self.thumb.travel = travel
    end

    return scrollBar
end

local function ensure_vertical_scroll_api(scrollFrame)
    if type(scrollFrame.SetVerticalScroll) ~= "function" then
        function scrollFrame:SetVerticalScroll(value)
            self.verticalScroll = value
        end
    end
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function mainFrameShell.AttachScrollBehavior(scrollFrame, scrollBar, options)
    options = options or {}
    ensure_vertical_scroll_api(scrollFrame)
    scrollFrame.verticalScroll = scrollFrame.verticalScroll or 0
    scrollFrame.verticalScrollRange = scrollFrame.verticalScrollRange or 0

    local controller = scrollFrame.slimScrollController or {}
    controller.scrollFrame = scrollFrame
    controller.scrollBar = scrollBar
    controller.options = options
    scrollFrame.slimScrollController = controller

    function controller:GetViewportHeight()
        if type(self.options.getViewportHeight) == "function" then
            return math.max(0, self.options.getViewportHeight(self) or 0)
        end

        return math.max(0, scrollFrame:GetHeight() or 0)
    end

    function controller:GetContentHeight()
        if type(self.options.getContentHeight) == "function" then
            return math.max(0, self.options.getContentHeight(self) or 0)
        end

        local child = scrollFrame.scrollChild
        return math.max(0, child and (child:GetHeight() or 0) or 0)
    end

    function controller:NormalizeOffset(offset, range)
        offset = clamp(offset or 0, 0, math.max(0, range or 0))
        if type(self.options.normalizeOffset) == "function" then
            offset = self.options.normalizeOffset(self, offset, range or 0)
            offset = clamp(offset or 0, 0, math.max(0, range or 0))
        end
        return offset
    end

    function controller:SyncVisuals(contentHeight, viewportHeight)
        local range = math.max(0, scrollFrame.verticalScrollRange or 0)
        local offset = clamp(scrollFrame.verticalScroll or 0, 0, range)
        local progress = range > 0 and (offset / range) or 0
        local visibleRatio = contentHeight > 0 and math.min(1, viewportHeight / contentHeight) or 1

        if scrollBar and type(scrollBar.UpdateThumb) == "function" then
            scrollBar:UpdateThumb(progress, visibleRatio)
        end

        mainFrameShell.SetFrameShown(scrollBar, range > 0 and visibleRatio < 0.999)
    end

    function controller:SetOffset(offset, contentHeight, viewportHeight)
        contentHeight = math.max(0, contentHeight or self:GetContentHeight())
        viewportHeight = math.max(0, viewportHeight or self:GetViewportHeight())

        local range = math.max(0, contentHeight - viewportHeight)
        offset = self:NormalizeOffset(offset, range)

        scrollFrame.verticalScrollRange = range
        scrollFrame.verticalScroll = offset
        scrollFrame:SetVerticalScroll(offset)

        if type(self.options.onOffsetChanged) == "function" then
            self.options.onOffsetChanged(self, offset, range)
        end

        self:SyncVisuals(contentHeight, viewportHeight)
        return offset
    end

    function controller:ScrollBy(delta)
        local step = delta or 0
        return self:SetOffset((scrollFrame.verticalScroll or 0) + step)
    end

    function controller:SetProgress(progress)
        local range = math.max(0, scrollFrame.verticalScrollRange or 0)
        local offset = range * clamp(progress or 0, 0, 1)
        return self:SetOffset(offset)
    end

    function controller:Refresh(contentHeight, viewportHeight)
        contentHeight = math.max(0, contentHeight or self:GetContentHeight())
        viewportHeight = math.max(0, viewportHeight or self:GetViewportHeight())
        return self:SetOffset(scrollFrame.verticalScroll or 0, contentHeight, viewportHeight)
    end

    if options.installMouseWheel ~= false then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(_, delta)
            controller:ScrollBy(-((delta or 0) * (options.wheelStep or 24)))
        end)
    end

    if scrollBar and scrollBar.thumb then
        scrollBar.thumb:SetScript("OnMouseDown", function(self)
            self.dragging = true
            self.dragStartProgress = self.progress or 0
            if type(_G.GetCursorPosition) == "function" then
                local _, cursorY = _G.GetCursorPosition()
                self.dragStartCursorY = cursorY
            else
                self.dragStartCursorY = 0
            end
        end)

        scrollBar.thumb:SetScript("OnMouseUp", function(self)
            self.dragging = false
            self.dragStartProgress = nil
            self.dragStartCursorY = nil
        end)
    end

    if scrollBar and scrollBar.track then
        scrollBar.track:SetScript("OnMouseDown", function()
            if type(_G.GetCursorPosition) ~= "function" then
                return
            end

            local _, cursorY = _G.GetCursorPosition()
            local trackHeight = scrollBar.track:GetHeight() or scrollBar:GetHeight() or 1
            local thumbHeight = scrollBar.thumb and (scrollBar.thumb:GetHeight() or 0) or 0
            local travel = math.max(1, trackHeight - thumbHeight)
            local progress = 0.5

            if type(scrollBar.track.GetTop) == "function" then
                local top = scrollBar.track:GetTop()
                if top then
                    progress = clamp((top - cursorY - (thumbHeight / 2)) / travel, 0, 1)
                end
            end

            controller:SetProgress(progress)
        end)
    end

    if scrollBar then
        scrollBar:SetScript("OnUpdate", function()
            local thumb = scrollBar.thumb
            if not thumb or thumb.dragging ~= true or type(_G.GetCursorPosition) ~= "function" then
                return
            end

            local _, cursorY = _G.GetCursorPosition()
            local travel = math.max(1, thumb.travel or 1)
            local deltaY = (thumb.dragStartCursorY or cursorY) - cursorY
            local progress = (thumb.dragStartProgress or 0) + (deltaY / travel)
            controller:SetProgress(progress)
        end)
    end

    return controller
end

local function create_overflow_viewport(parent, options)
    options = options or {}
    local viewportParent = options.viewportParent or parent
    local scrollBarParent = options.scrollBarParent or viewportParent
    local viewport = options.viewportFrame or _G.CreateFrame("Frame", nil, viewportParent, "BackdropTemplate")
    local scrollFrame = options.scrollFrame or _G.CreateFrame("ScrollFrame", nil, viewport)
    local scrollChild = options.scrollChild or _G.CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    local scrollBar = options.scrollBar or mainFrameShell.MakeSlimScrollBar(scrollBarParent, options.scrollBarWidth or 14)

    viewport:SetPoint("TOPLEFT", viewportParent, "TOPLEFT", options.viewportInsetLeft or 8, -(options.viewportInsetTop or 8))
    viewport:SetPoint("BOTTOMRIGHT", viewportParent, "BOTTOMRIGHT", -(options.viewportInsetRight or 22), options.viewportInsetBottom or 8)
    mainFrameShell.ApplyPanelStyle(viewport, options.viewportColor or theme().colors.background)

    scrollFrame:SetPoint("TOPLEFT", viewport, "TOPLEFT", options.scrollInsetLeft or 6, -(options.scrollInsetTop or 6))
    scrollFrame:SetPoint("BOTTOMRIGHT", viewport, "BOTTOMRIGHT", -(options.scrollInsetRight or 6), options.scrollInsetBottom or 6)
    if type(scrollFrame.SetBackdrop) == "function" then
        scrollFrame:SetBackdrop(nil)
    end

    scrollChild:SetSize(0, 0)
    scrollFrame:SetScrollChild(scrollChild)
    if type(scrollChild.SetBackdrop) == "function" then
        scrollChild:SetBackdrop(nil)
    end

    scrollBar:SetPoint("TOPRIGHT", scrollBarParent, "TOPRIGHT", -(options.scrollBarRightInset or 4), -(options.scrollBarTopInset or 8))
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBarParent, "BOTTOMRIGHT", -(options.scrollBarRightInset or 4), options.scrollBarBottomInset or 8)

    local controller = mainFrameShell.AttachScrollBehavior(scrollFrame, scrollBar, options.controllerOptions)

    return {
        viewportFrame = viewport,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        scrollBar = scrollBar,
        controller = controller,
    }
end

function mainFrameShell.CreatePageOverflowViewport(parent, options)
    return create_overflow_viewport(parent, options)
end

function mainFrameShell.CreateTableOverflowViewport(parent, options)
    options = options or {}
    options.viewportInsetLeft = options.viewportInsetLeft or 0
    options.viewportInsetTop = options.viewportInsetTop or 0
    options.viewportInsetBottom = options.viewportInsetBottom or 0
    options.scrollInsetLeft = options.scrollInsetLeft or 0
    options.scrollInsetTop = options.scrollInsetTop or 0
    options.scrollInsetBottom = options.scrollInsetBottom or 0
    options.scrollBarTopInset = options.scrollBarTopInset or 0
    options.scrollBarBottomInset = options.scrollBarBottomInset or 0
    return create_overflow_viewport(parent, options)
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
