local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimapButton = ns.modules.minimapButton or {}
local mainFrameShell = ns.modules.mainFrameShell or {}

local function current_db()
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    return ns.state.db or _G.GBankManagerDB or {}
end

local function current_appearance()
    local db = current_db()
    db.ui = db.ui or {}
    db.ui.appearance = db.ui.appearance or {}
    if db.ui.appearance.showMinimapButton == nil then
        db.ui.appearance.showMinimapButton = true
    end
    db.ui.appearance.minimapAngle = tonumber(db.ui.appearance.minimapAngle or 315) or 315
    return db.ui.appearance
end

local function theme_minimap_icon()
    if type(mainFrameShell.GetMinimapButtonTexture) == "function" then
        return mainFrameShell.GetMinimapButtonTexture()
    end
    return "Interface\\ICONS\\INV_Misc_Map_01"
end

local function angle_to_offset(angleDegrees)
    local angleRadians = math.rad(tonumber(angleDegrees or 315) or 315)
    local radius = 76
    return math.cos(angleRadians) * radius, math.sin(angleRadians) * radius
end

function minimapButton.UpdatePosition()
    local button = minimapButton.button
    local minimap = _G.Minimap
    if type(button) ~= "table" or type(minimap) ~= "table" or type(button.SetPoint) ~= "function" then
        return
    end

    local appearance = current_appearance()
    local x, y = angle_to_offset(appearance.minimapAngle)
    if type(button.ClearAllPoints) == "function" then
        button:ClearAllPoints()
    end
    button:SetPoint("CENTER", minimap, "CENTER", x, y)
end

function minimapButton.ApplyVisibility()
    local button = minimapButton.button
    if type(button) ~= "table" then
        return
    end

    if current_appearance().showMinimapButton == true then
        if type(button.Show) == "function" then
            button:Show()
        end
    elseif type(button.Hide) == "function" then
        button:Hide()
    end
end

function minimapButton.RefreshAppearance()
    local button = minimapButton.button
    if type(button) ~= "table" then
        return
    end

    if button.icon and type(button.icon.SetTexture) == "function" then
        button.icon:SetTexture(theme_minimap_icon())
        button.icon.texture = theme_minimap_icon()
    end
    if button.icon and type(button.icon.SetVertexColor) == "function" then
        button.icon:SetVertexColor(1, 1, 1, 1)
    end
    minimapButton.UpdatePosition()
    minimapButton.ApplyVisibility()
end

local function begin_drag(self)
    if type(self) ~= "table" then
        return
    end

    self:SetScript("OnUpdate", function(button)
        local minimap = _G.Minimap
        if type(minimap) ~= "table" or type(minimap.GetCenter) ~= "function" or type(minimap.GetEffectiveScale) ~= "function" then
            return
        end

        local mx, my = minimap:GetCenter()
        local px, py = _G.GetCursorPosition()
        local scale = minimap:GetEffectiveScale()
        px = (tonumber(px or 0) or 0) / math.max(scale or 1, 0.0001)
        py = (tonumber(py or 0) or 0) / math.max(scale or 1, 0.0001)

        local angle = math.atan2 and math.atan2(py - my, px - mx) or math.atan(py - my, px - mx)
        local appearance = current_appearance()
        appearance.minimapAngle = math.deg(angle)
        minimapButton.UpdatePosition()
    end)
end

local function stop_drag(self)
    if type(self) == "table" then
        self:SetScript("OnUpdate", nil)
    end
end

function minimapButton.EnsureButton()
    if minimapButton.button or type(_G.CreateFrame) ~= "function" or type(_G.Minimap) ~= "table" then
        return minimapButton.button
    end

    local button = _G.CreateFrame("Button", "GBankManagerMinimapButton", _G.Minimap)
    button:SetSize(32, 32)
    if type(button.SetFrameStrata) == "function" then
        button:SetFrameStrata("HIGH")
    end
    if type(button.SetFrameLevel) == "function" then
        button:SetFrameLevel(40)
    end

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetSize(24, 24)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.icon:SetTexture(theme_minimap_icon())
    button.icon.texture = theme_minimap_icon()

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(54, 54)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border.texture = "Interface\\Minimap\\MiniMap-TrackingBorder"
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    if type(button.EnableMouse) == "function" then
        button:EnableMouse(true)
    end
    if type(button.RegisterForDrag) == "function" then
        button:RegisterForDrag("LeftButton")
    end

    button:SetScript("OnDragStart", begin_drag)
    button:SetScript("OnDragStop", stop_drag)
    button:SetScript("OnClick", function()
        local mainFrame = ns.modules.mainFrame
        if type(mainFrame) == "table" and type(mainFrame.IsShown) == "function" and mainFrame:IsShown() then
            if type(mainFrame.Hide) == "function" then
                mainFrame:Hide()
                return
            end
        end

        local slash = ns.modules.slash
        if slash and type(slash.command) == "function" then
            slash.command("ui")
        end
    end)

    minimapButton.button = button
    minimapButton.RefreshAppearance()
    if type(button.Show) == "function" then
        button:Show()
    end
    return button
end

function minimapButton.SetShown(isShown)
    local appearance = current_appearance()
    appearance.showMinimapButton = isShown == true
    minimapButton.EnsureButton()
    minimapButton.ApplyVisibility()
end

ns.modules.minimapButton = minimapButton

return minimapButton
