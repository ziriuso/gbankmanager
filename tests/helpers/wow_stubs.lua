_G = _G or {}

_G.SlashCmdList = _G.SlashCmdList or {}
_G.UIParent = _G.UIParent or { children = {} }
_G.C_ChatInfo = _G.C_ChatInfo or {
    sentMessages = {},
    registeredPrefixes = {},
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
            SetWidth = function(self, value) self.width = value end,
            SetHeight = function(self, value) self.height = value end,
            Show = function(self) self.shown = true end,
            Hide = function(self) self.shown = false end,
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
        function frame:SetFrameLevel() end
        function frame:SetScrollChild(child)
            self.scrollChild = child
        end
        function frame:EnableMouseWheel(enabled)
            self.mouseWheelEnabled = enabled
        end
        function frame:SetNormalFontObject() end
        function frame:SetHighlightFontObject() end
        function frame:SetAutoFocus(value)
            self.autoFocus = value
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
