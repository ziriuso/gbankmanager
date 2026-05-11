_G = _G or {}

_G.SlashCmdList = _G.SlashCmdList or {}
_G.UIParent = _G.UIParent or { children = {} }

if _G.time == nil then
    _G.time = function()
        return 0
    end
end

if _G.CreateFrame == nil then
    local function make_region()
        return {
            SetPoint = function() end,
            SetText = function(self, value) self.text = value end,
            GetText = function(self) return self.text end,
            SetVertexColor = function() end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            SetFontObject = function() end,
            SetWidth = function() end,
            SetHeight = function() end,
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

        function frame:CreateFontString()
            local region = make_region()
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

        function frame:SetBackdropColor() end
        function frame:SetBackdropBorderColor() end
        function frame:SetMovable() end
        function frame:EnableMouse() end
        function frame:RegisterForDrag() end
        function frame:SetResizable() end
        function frame:SetMinResize() end
        function frame:SetMaxResize() end
        function frame:SetClampedToScreen() end
        function frame:SetFrameStrata() end
        function frame:SetFrameLevel() end
        function frame:SetNormalFontObject() end
        function frame:SetHighlightFontObject() end
        function frame:SetText(text) self.text = text end
        function frame:GetText() return self.text end
        function frame:SetStatusBarColor() end
        function frame:SetValue(value) self.value = value end
        function frame:GetValue() return self.value end

        table.insert((parent or _G.UIParent).children, frame)
        return frame
    end
end

return _G
