_G = _G or {}

_G.SlashCmdList = _G.SlashCmdList or {}
_G.UIParent = _G.UIParent or { children = {} }
_G.C_ChatInfo = _G.C_ChatInfo or {
    sentMessages = {},
    loggedMessages = {},
    registeredPrefixes = {},
}
_G.C_Timer = _G.C_Timer or {
    pending = {},
}
_G.Enum = _G.Enum or {}
_G.C_GuildInfo = _G.C_GuildInfo or {
    infoText = "",
    motd = "",
    canEditGuildInfo = true,
    canEditOfficerNote = true,
    canViewOfficerNote = true,
    setNotes = {},
    guildRosterRequests = 0,
}
_G.C_Secrets = _G.C_Secrets or {
    hasSecretRestrictions = false,
}
_G.C_TradeSkillUI = _G.C_TradeSkillUI or {}
_G.StaticPopupDialogs = _G.StaticPopupDialogs or {
    ["SET_GUILDOFFICERNOTE"] = {
        maxLetters = 31,
    },
}
_G.StaticPopupCalls = _G.StaticPopupCalls or {}
_G.__lastOpenedMenu = nil
_G.__lastMenuAnchor = nil
_G.DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME or {
    messages = {},
}
_G.GuildRosterSetOfficerNoteCalls = _G.GuildRosterSetOfficerNoteCalls or {}
_G.guildRosterSelection = _G.guildRosterSelection or 0
_G.SetGuildRosterSelectionCalls = _G.SetGuildRosterSelectionCalls or {}
_G.currentGuildBankTab = _G.currentGuildBankTab or 1
_G.SetCurrentGuildBankTabCalls = _G.SetCurrentGuildBankTabCalls or {}
_G.__eventFrames = _G.__eventFrames or {}
_G.AceCommStub = _G.AceCommStub or {}

if _G.time == nil then
    _G.time = function()
        return 0
    end
end

if _G.GetTime == nil then
    _G.__wowTestNow = _G.__wowTestNow or 0
    _G.GetTime = function()
        _G.__wowTestNow = _G.__wowTestNow + 1
        return _G.__wowTestNow
    end
end

if _G.GetFramerate == nil then
    _G.GetFramerate = function()
        return 60
    end
end

if _G.geterrorhandler == nil then
    _G.geterrorhandler = function()
        return error
    end
end

if _G.securecallfunction == nil then
    _G.securecallfunction = function(func, ...)
        return func(...)
    end
end

if _G.Ambiguate == nil then
    _G.Ambiguate = function(value)
        return value
    end
end

if _G.hooksecurefunc == nil then
    _G.hooksecurefunc = function(target, methodName, hook)
        if type(target) == "string" then
            hook = methodName
            methodName = target
            target = _G
        end

        local original = target[methodName]
        if type(original) ~= "function" then
            target[methodName] = function(...) end
            original = target[methodName]
        end

        target[methodName] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
end

if _G.table and _G.table.wipe == nil then
    _G.table.wipe = function(target)
        for key in pairs(target or {}) do
            target[key] = nil
        end
    end
end

_G.Enum.SendAddonMessageResult = _G.Enum.SendAddonMessageResult or {
    Success = 0,
    AddonMessageThrottle = 3,
    NotInGroup = 5,
    ChannelThrottle = 8,
    GeneralError = 9,
}

if _G.UnitName == nil then
    _G.UnitName = function()
        return "TestPlayer"
    end
end

function _G.C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    table.insert(_G.C_ChatInfo.registeredPrefixes, prefix)
    return true
end

function _G.C_ChatInfo.SendChatMessage(messageType, language, target)
    _G.C_ChatInfo.lastChatMessage = {
        messageType = messageType,
        language = language,
        target = target,
    }
    return true
end

function _G.C_ChatInfo.SendAddonMessage(prefix, payload, distribution, channel)
    table.insert(_G.C_ChatInfo.sentMessages, {
        prefix = prefix,
        payload = payload,
        distribution = distribution,
        channel = channel,
    })
    return true
end

function _G.C_ChatInfo.SendAddonMessageLogged(prefix, payload, distribution, channel)
    table.insert(_G.C_ChatInfo.loggedMessages, {
        prefix = prefix,
        payload = payload,
        distribution = distribution,
        channel = channel,
    })
    return _G.C_ChatInfo.SendAddonMessage(prefix, payload, distribution, channel)
end

local function append_event_frame(eventName, frame)
    _G.__eventFrames[eventName] = _G.__eventFrames[eventName] or {}
    for _, existing in ipairs(_G.__eventFrames[eventName]) do
        if existing == frame then
            return
        end
    end
    table.insert(_G.__eventFrames[eventName], frame)
end

local function remove_event_frame(eventName, frame)
    local frames = _G.__eventFrames[eventName]
    if type(frames) ~= "table" then
        return
    end

    for index = #frames, 1, -1 do
        if frames[index] == frame then
            table.remove(frames, index)
        end
    end
end

function _G.FireEvent(eventName, ...)
    local lastResult = nil
    for _, frame in ipairs(_G.__eventFrames[eventName] or {}) do
        local handler = frame.GetScript and frame:GetScript("OnEvent")
        if type(handler) == "function" then
            lastResult = handler(frame, eventName, ...)
        end
    end
    return lastResult
end

function _G.AceCommStub.attach()
    local libStub = _G.LibStub
    local aceComm = libStub and libStub("AceComm-3.0", true)
    if not aceComm then
        return nil
    end

    local chatThrottleLib = _G.ChatThrottleLib
    if type(chatThrottleLib) == "table" then
        chatThrottleLib.HardThrottlingBeginTime = -1000
        chatThrottleLib.LastAvailUpdate = -1000
        chatThrottleLib.avail = chatThrottleLib.BURST or 4000
        chatThrottleLib.bQueueing = false
    end

    if _G.AceCommStub.boundAceComm ~= aceComm then
        local originalSendCommMessage = aceComm.SendCommMessage
        aceComm.SendCommMessage = function(self, prefix, text, distribution, target, ...)
            _G.AceCommStub.lastPrefix = prefix
            _G.AceCommStub.lastMessage = text
            _G.AceCommStub.lastDistribution = distribution
            _G.AceCommStub.lastTarget = target
            return originalSendCommMessage(self, prefix, text, distribution, target, ...)
        end
        _G.AceCommStub.boundAceComm = aceComm
    end

    return aceComm
end

function _G.AceCommStub.reset()
    _G.AceCommStub.lastPrefix = nil
    _G.AceCommStub.lastMessage = nil
    _G.AceCommStub.lastDistribution = nil
    _G.AceCommStub.lastTarget = nil
    return _G.AceCommStub.attach()
end

function _G.AceCommStub.fire(prefix, message, distribution, sender)
    local aceComm = _G.AceCommStub.attach()
    if not aceComm or not aceComm.callbacks then
        error("AceComm-3.0 is not available for the sync transport test harness")
    end

    aceComm.callbacks:Fire(prefix, message, distribution, sender)
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

if _G.GetCursorPosition == nil then
    _G.GetCursorPosition = function()
        return 0, 0
    end
end

function _G.C_Secrets.HasSecretRestrictions()
    return _G.C_Secrets.hasSecretRestrictions == true
end

function _G.GuildRosterSetOfficerNote(index, text)
    table.insert(_G.GuildRosterSetOfficerNoteCalls, {
        index = index,
        text = text,
    })
    return true
end

function _G.SetGuildRosterSelection(index)
    _G.guildRosterSelection = tonumber(index) or 0
    table.insert(_G.SetGuildRosterSelectionCalls, _G.guildRosterSelection)
end

function _G.GetGuildRosterSelection()
    return tonumber(_G.guildRosterSelection) or 0
end

function _G.SetCurrentGuildBankTab(index)
    _G.currentGuildBankTab = tonumber(index) or 1
    table.insert(_G.SetCurrentGuildBankTabCalls, _G.currentGuildBankTab)
end

function _G.GetCurrentGuildBankTab()
    return tonumber(_G.currentGuildBankTab) or 1
end

function _G.DEFAULT_CHAT_FRAME:AddMessage(message)
    table.insert(self.messages, tostring(message or ""))
end

function _G.C_Timer.After(delaySeconds, callback)
    table.insert(_G.C_Timer.pending, {
        delaySeconds = delaySeconds,
        callback = callback,
    })
    return #_G.C_Timer.pending
end

function _G.C_Timer.RunPending()
    local pending = _G.C_Timer.pending or {}
    _G.C_Timer.pending = {}
    for _, entry in ipairs(pending) do
        if type(entry.callback) == "function" then
            entry.callback()
        end
    end
end

function _G.C_Timer.ClearPending()
    _G.C_Timer.pending = {}
end

_G.MenuUtil = _G.MenuUtil or {}

function _G.MenuUtil.CreateContextMenuDescription()
    local description = {
        buttons = {},
    }

    function description:CreateButton(text, callback)
        local button = {
            text = tostring(text or ""),
            callback = callback,
        }
        table.insert(self.buttons, button)
        return button
    end

    return description
end

function _G.CreateAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        offsetX = offsetX,
        offsetY = offsetY,
    }
end

_G.Menu = _G.Menu or {}

function _G.Menu.GetManager()
    return {
        OpenMenu = function(_, owner, description, anchor)
            _G.__lastOpenedMenu = {
                owner = owner,
                description = description,
                buttons = description and description.buttons or {},
            }
            _G.__lastMenuAnchor = anchor
        end,
    }
end

function _G.UIDropDownMenu_CreateInfo()
    return {}
end

function _G.EasyMenu(menuList, dropdownFrame, anchor, offsetX, offsetY, displayMode, autoHideDelay)
    local buttons = {}
    for _, entry in ipairs(menuList or {}) do
        buttons[#buttons + 1] = {
            text = tostring(entry.text or ""),
            callback = entry.func,
            notCheckable = entry.notCheckable,
            checked = entry.checked,
            value = entry.value,
        }
    end
    _G.__lastOpenedMenu = {
        owner = (type(dropdownFrame) == "table" and dropdownFrame.__gbmOwnerButton) or anchor,
        dropdownFrame = dropdownFrame,
        anchor = anchor,
        buttons = buttons,
        displayMode = displayMode,
        autoHideDelay = autoHideDelay,
    }
    _G.__lastMenuAnchor = {
        point = "TOPLEFT",
        relativeTo = anchor,
        relativePoint = "BOTTOMLEFT",
        offsetX = offsetX,
        offsetY = offsetY,
    }
end

function _G.StaticPopup_Show(which, text_arg1, text_arg2, data)
    local dialog = (_G.StaticPopupDialogs or {})[which] or {}
    local popup = {
        which = which,
        data = data,
        editBox = {
            text = "",
        },
    }

    function popup.editBox:SetText(text)
        self.text = tostring(text or "")
    end

    function popup.editBox:GetText()
        return tostring(self.text or "")
    end

    table.insert(_G.StaticPopupCalls, {
        which = which,
        text_arg1 = text_arg1 or dialog.text,
        text_arg2 = text_arg2,
        data = data,
        popup = popup,
    })
    _G.LastStaticPopup = popup
    return popup
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
            SetParent = function(self, parent)
                self.parent = parent
            end,
            GetParent = function(self)
                return self.parent
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
            SetWordWrap = function(self, value) self.wordWrap = value and true or false end,
            SetMaxLines = function(self, value) self.maxLines = value end,
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
        function frame:SetParent(parent)
            self.parent = parent
        end
        function frame:GetParent()
            return self.parent
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
            append_event_frame(event, self)
        end

        function frame:UnregisterEvent(event)
            remove_event_frame(event, self)
            for index = #self.events, 1, -1 do
                if self.events[index] == event then
                    table.remove(self.events, index)
                end
            end
        end

        function frame:UnregisterAllEvents()
            for _, event in ipairs(self.events) do
                remove_event_frame(event, self)
            end
            self.events = {}
        end

        function frame:SetScript(scriptName, handler)
            self.scripts[scriptName] = handler
        end

        function frame:GetScript(scriptName)
            return self.scripts[scriptName]
        end

        function frame:SetMinMaxValues(minValue, maxValue)
            self.minValue = minValue
            self.maxValue = maxValue
        end

        function frame:GetMinMaxValues()
            return self.minValue, self.maxValue
        end

        function frame:SetValueStep(step)
            self.valueStep = step
        end

        function frame:SetObeyStepOnDrag(value)
            self.obeyStepOnDrag = value and true or false
        end

        function frame:SetOrientation(value)
            self.orientation = value
        end

        function frame:SetThumbTexture(texture)
            self.thumbTexture = texture
        end

        function frame:CreateFontString(name, layer, inherits)
            local region = make_region()
            region.name = name
            region.layer = layer
            region.fontObject = inherits
            region.parent = self
            table.insert(self.children, region)
            return region
        end

        function frame:CreateTexture(name, layer, inherits, subLevel)
            local region = make_region()
            region.name = name
            region.layer = layer
            region.inherits = inherits
            region.subLevel = subLevel
            region.parent = self
            region.SetColorTexture = function() end
            region.SetAllPoints = function() end
            region.SetAtlas = function(self, atlas) self.atlas = atlas end
            region.SetTexture = function(self, texture) self.texture = texture end
            region.SetTexCoord = function(self, ...)
                self.texCoord = { ... }
            end
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
        function frame:EnableKeyboard(enabled)
            self.keyboardEnabled = enabled
        end
        function frame:SetPropagateKeyboardInput(enabled)
            self.propagateKeyboardInput = enabled
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
        function frame:GetChildren()
            return unpack(self.children)
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
        function frame:SetValue(value)
            self.value = value
            if type(self.scripts.OnValueChanged) == "function" then
                self.scripts.OnValueChanged(self, value)
            elseif type(self.onValueChanged) == "function" then
                self.onValueChanged(self, value)
            end
        end
        function frame:GetValue() return self.value end
        function frame:SetEnabled(enabled)
            self.enabled = enabled and true or false
        end
        function frame:IsEnabled()
            return self.enabled ~= false
        end
        function frame:SetChecked(value)
            self.checked = value and true or false
        end
        function frame:GetChecked()
            return self.checked == true
        end

        if type(template) == "string" and string.find(template, "UISliderTemplate", 1, true) then
            frame.Low = make_region()
            frame.High = make_region()
            frame.Text = make_region()
            frame.Thumb = make_region()
            table.insert(frame.children, frame.Low)
            table.insert(frame.children, frame.High)
            table.insert(frame.children, frame.Text)
            table.insert(frame.children, frame.Thumb)
        end

        table.insert((parent or _G.UIParent).children, frame)
        return frame
    end
end

_G.Minimap = _G.Minimap or _G.CreateFrame("Frame", "Minimap", _G.UIParent)
_G.Minimap.width = _G.Minimap.width or 140
_G.Minimap.height = _G.Minimap.height or 140
function _G.Minimap:GetCenter()
    return 70, 70
end
function _G.Minimap:GetEffectiveScale()
    return 1
end

return _G
