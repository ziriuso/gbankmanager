_G = _G or {}

_G.SlashCmdList = _G.SlashCmdList or {}
_G.UIParent = _G.UIParent or { children = {} }
_G.C_ChatInfo = _G.C_ChatInfo or {
    sentMessages = {},
    registeredPrefixes = {},
}
_G.C_GuildInfo = _G.C_GuildInfo or {
    infoText = "",
    motd = "",
    canEditGuildInfo = true,
    canEditOfficerNote = true,
    canViewOfficerNote = true,
    setNotes = {},
    guildRosterRequests = 0,
}
_G.DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME or {
    messages = {},
}

if _G.time == nil then
    _G.time = function()
        return 0
    end
end

if _G.UnitName == nil then
    _G.UnitName = function()
        return "TestPlayer"
    end
end

function _G.C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    table.insert(_G.C_ChatInfo.registeredPrefixes, prefix)
    return true
end

function _G.C_ChatInfo.SendAddonMessage(prefix, payload, distribution, channel)
    table.insert(_G.C_ChatInfo.sentMessages, {
        prefix = prefix,
        payload = payload,
        distribution = distribution,
        channel = channel,
    })
end

function _G.C_GuildInfo.GetInfoText()
    return _G.C_GuildInfo.infoText or ""
end

function _G.C_GuildInfo.SetInfoText(text)
    _G.C_GuildInfo.infoText = text or ""
end

function _G.C_GuildInfo.GetMOTD()
    return _G.C_GuildInfo.motd or ""
end

function _G.C_GuildInfo.CanEditGuildInfo()
    return _G.C_GuildInfo.canEditGuildInfo == true
end

function _G.C_GuildInfo.CanEditOfficerNote()
    return _G.C_GuildInfo.canEditOfficerNote == true
end

function _G.C_GuildInfo.CanViewOfficerNote()
    return _G.C_GuildInfo.canViewOfficerNote == true
end

function _G.C_GuildInfo.SetNote(guid, text, isPublic)
    table.insert(_G.C_GuildInfo.setNotes, {
        guid = guid,
        text = text,
        isPublic = isPublic,
    })
    return true
end

function _G.C_GuildInfo.GuildRoster()
    _G.C_GuildInfo.guildRosterRequests = (_G.C_GuildInfo.guildRosterRequests or 0) + 1
end

function _G.DEFAULT_CHAT_FRAME:AddMessage(message)
    table.insert(self.messages, tostring(message or ""))
end

_G.CreateDataProvider = _G.CreateDataProvider or function(initial)
    local provider = {
        data = {},
    }

    function provider:Flush()
        self.data = {}
    end

    function provider:Insert(value)
        table.insert(self.data, value)
    end

    function provider:GetSize()
        return #self.data
    end

    function provider:Find(index)
        return self.data[index]
    end

    function provider:SetCollection(collection)
        self.data = {}
        for _, value in ipairs(collection or {}) do
            table.insert(self.data, value)
        end
    end

    provider:SetCollection(initial or {})
    return provider
end

_G.CreateScrollBoxListLinearView = _G.CreateScrollBoxListLinearView or function(top, bottom, left, right, spacing)
    local view = {
        padding = {
            top = top,
            bottom = bottom,
            left = left,
            right = right,
        },
        spacing = spacing or 0,
    }

    function view:SetElementInitializer(template, initializer)
        self.template = template
        self.elementInitializer = initializer
    end

    return view
end

_G.ScrollUtil = _G.ScrollUtil or {}
_G.ScrollUtil.InitScrollBoxListWithScrollBar = _G.ScrollUtil.InitScrollBoxListWithScrollBar or function(scrollBox, scrollBar, view)
    if type(scrollBar) ~= "table" or type(scrollBar.RegisterCallback) ~= "function" then
        error("ScrollUtil.InitScrollBoxListWithScrollBar requires a Blizzard-compatible scrollbar")
    end
    scrollBox.view = view
    scrollBox.scrollBar = scrollBar
    scrollBox.SetDataProvider = scrollBox.SetDataProvider or function(self, dataProvider)
        self.dataProvider = dataProvider
    end
end

if _G.CreateFrame == nil then
    local function make_region()
        return {
            points = {},
            SetPoint = function(self, ...)
                table.insert(self.points, { ... })
            end,
            ClearAllPoints = function(self)
                self.points = {}
            end,
            SetText = function(self, value) self.text = value end,
            GetText = function(self) return self.text end,
            SetVertexColor = function() end,
            SetTextColor = function(self, r, g, b, a) self.textColor = { r, g, b, a } end,
            SetJustifyH = function(self, value) self.justifyH = value end,
            SetJustifyV = function(self, value) self.justifyV = value end,
            SetFontObject = function() end,
            SetSize = function(self, width, height)
                self.width = width
                self.height = height
            end,
            SetWidth = function(self, value) self.width = value end,
            SetHeight = function(self, value) self.height = value end,
            GetWidth = function(self) return self.width end,
            GetHeight = function(self) return self.height end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
            IsShown = function(self) return self.shown ~= false end,
        }
    end

    _G.CreateFrame = function(frameType, name, parent, template)
        local frame = {
            frameType = frameType,
            name = name,
            parent = parent,
            template = template,
            shown = true,
            width = 0,
            height = 0,
            points = {},
            scripts = {},
            events = {},
            children = {},
        }

        function frame:SetSize(width, height)
            self.width = width
            self.height = height
        end

        function frame:SetWidth(width)
            self.width = width
        end

        function frame:SetHeight(height)
            self.height = height
        end

        function frame:GetWidth()
            return self.width
        end

        function frame:GetHeight()
            return self.height
        end

        function frame:SetPoint(...)
            table.insert(self.points, { ... })
        end
        function frame:ClearAllPoints()
            self.points = {}
        end
        function frame:GetPoint(index)
            local point = self.points[(index or 1)]
            if point then
                return unpack(point)
            end

            return nil
        end

        function frame:Hide()
            self.shown = false
        end

        function frame:Show()
            self.shown = true
        end

        function frame:IsShown()
            return self.shown
        end

        function frame:RegisterEvent(event)
            table.insert(self.events, event)
        end

        function frame:SetScript(scriptName, handler)
            self.scripts[scriptName] = handler
        end

        function frame:GetScript(scriptName)
            return self.scripts[scriptName]
        end

        function frame:CreateFontString(name, layer, inherits)
            local region = make_region()
            region.name = name
            region.layer = layer
            region.fontObject = inherits
            table.insert(self.children, region)
            return region
        end

        function frame:CreateTexture()
            local region = make_region()
            region.SetColorTexture = function() end
            region.SetAllPoints = function() end
            region.SetAtlas = function(self, atlas) self.atlas = atlas end
            region.SetTexture = function(self, texture) self.texture = texture end
            table.insert(self.children, region)
            return region
        end

        function frame:SetBackdropColor(r, g, b, a)
            self.backdropColor = { r, g, b, a }
        end
        function frame:SetBackdropBorderColor(r, g, b, a)
            self.backdropBorderColor = { r, g, b, a }
        end
        function frame:SetBackdrop(backdrop)
            self.backdrop = backdrop
        end
        function frame:SetMovable() end
        function frame:EnableMouse(enabled)
            self.mouseEnabled = enabled
        end
        function frame:RegisterForDrag(...)
            self.dragButtons = { ... }
        end
        function frame:StartMoving()
            self.moving = true
        end
        function frame:StopMovingOrSizing()
            self.moving = false
        end
        function frame:SetResizable() end
        function frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            self.resizeBounds = {
                minWidth = minWidth,
                minHeight = minHeight,
                maxWidth = maxWidth,
                maxHeight = maxHeight,
            }
        end
        function frame:SetClampedToScreen() end
        function frame:SetFrameStrata(value)
            self.frameStrata = value
        end
        function frame:SetFrameLevel(value)
            self.frameLevel = value
        end
        function frame:SetToplevel(value)
            self.topLevel = value and true or false
        end
        function frame:Raise()
            self.raiseCount = (self.raiseCount or 0) + 1
        end
        function frame:SetScrollChild(child)
            self.scrollChild = child
        end
        function frame:SetVerticalScroll(value)
            self.verticalScroll = value
        end
        function frame:GetVerticalScroll()
            return self.verticalScroll or 0
        end
        function frame:EnableMouseWheel(enabled)
            self.mouseWheelEnabled = enabled
        end
        function frame:SetNormalFontObject() end
        function frame:SetHighlightFontObject() end
        function frame:SetAutoFocus(value)
            self.autoFocus = value
        end
        function frame:SetFocus()
            self.hasFocus = true
        end
        function frame:ClearFocus()
            self.hasFocus = false
        end
        function frame:HasFocus()
            return self.hasFocus == true
        end
        function frame:SetCursorPosition(value)
            self.cursorPosition = value
        end
        function frame:HighlightText(startIndex, endIndex)
            self.highlightStart = startIndex
            self.highlightEnd = endIndex
        end
        function frame:SetTextInsets(left, right, top, bottom)
            self.textInsets = { left, right, top, bottom }
        end
        function frame:SetFontObject(value)
            self.fontObject = value
        end
        function frame:SetTextColor(r, g, b, a)
            self.textColor = { r, g, b, a }
        end
        function frame:SetAlpha(value)
            self.alpha = value
        end
        function frame:GetAlpha()
            return self.alpha
        end
        function frame:SetText(text)
            self.text = text
            local handler = self.scripts and self.scripts.OnTextChanged
            if type(handler) == "function" then
                handler(self, text)
            end
        end
        function frame:GetText() return self.text end
        function frame:SetStatusBarColor() end
        function frame:SetValue(value) self.value = value end
        function frame:GetValue() return self.value end
        function frame:SetEnabled(enabled)
            self.enabled = enabled and true or false
        end
        function frame:IsEnabled()
            return self.enabled ~= false
        end

        table.insert((parent or _G.UIParent).children, frame)
        return frame
    end
end

return _G
