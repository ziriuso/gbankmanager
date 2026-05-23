local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}
local themeManager = ns.modules.themeManager or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.NormalizeDisplayAtlas == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end
ns.ui.theme = ns.ui.theme or {}

local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local backdrop = {
    bgFile = SOLID_TEXTURE,
    edgeFile = SOLID_TEXTURE,
    edgeSize = 1,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },
}

local SURFACE_VARIANTS = {
    shell = {
        colorToken = "bg",
        borderToken = "modalBorder",
    },
    sidebar = {
        colorToken = "panel",
        borderToken = "border",
    },
    header = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
    panel = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["panel-alt"] = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
    ["metric-card"] = {
        colorToken = "panelAlt",
        borderToken = "border",
    },
    ["action-card"] = {
        colorToken = "panelAlt",
        borderToken = "border",
    },
    ["brand-card"] = {
        colorToken = "panelAlt",
        borderToken = "modalBorder",
    },
    ["wizard-rail"] = {
        colorToken = "bgAlt",
        borderToken = "borderSoft",
    },
    ["table-header"] = {
        colorToken = "bgAlt",
        borderToken = "border",
    },
    ["table-filter"] = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["table-viewport"] = {
        colorToken = "bg",
        borderToken = "borderSoft",
    },
    row = {
        colorToken = "row",
        borderToken = "borderSoft",
    },
    ["row-alt"] = {
        colorToken = "rowAlt",
        borderToken = "borderSoft",
    },
    ["row-selected"] = {
        colorToken = "rowHover",
        borderToken = "accent",
    },
    modal = {
        colorToken = "modalBg",
        borderToken = "modalBorder",
    },
    input = {
        colorToken = "inputBg",
        borderToken = "inputBorder",
    },
}

local BUTTON_VARIANTS = {
    nav = {
        surfaceVariant = "panel",
    },
    primary = {
        surfaceVariant = "action-card",
    },
    secondary = {
        surfaceVariant = "panel",
    },
    tab = {
        surfaceVariant = "panel-alt",
    },
    icon = {
        surfaceVariant = "panel",
    },
    danger = {
        surfaceVariant = "panel-alt",
        borderToken = "danger",
    },
}

local function theme()
    if type(themeManager.EnsureState) == "function" then
        ns.ui.theme = themeManager.EnsureState(ns.ui.theme or {})
        return ns.ui.theme
    end

    return ns.ui.theme or {}
end

local function next_window_level()
    ns.state.uiWindowLevelCounter = math.max(tonumber(ns.state.uiWindowLevelCounter or 30) or 30, 30) + 10
    return ns.state.uiWindowLevelCounter
end

function mainFrameShell.GetTheme()
    return theme()
end

function mainFrameShell.GetThemePresets()
    if type(themeManager.GetThemes) == "function" then
        return themeManager.GetThemes()
    end

    return {}
end

function mainFrameShell.GetThemePresetOrder()
    if type(themeManager.GetThemePresetOrder) == "function" then
        return themeManager.GetThemePresetOrder()
    end

    return { "generic_wow" }
end

function mainFrameShell.ApplyThemePreset(presetKey)
    if type(themeManager.ApplyThemePreset) == "function" then
        ns.ui.theme = themeManager.ApplyThemePreset(ns.ui.theme or {}, presetKey)
        return ns.ui.theme
    end

    return theme()
end

function mainFrameShell.ApplyShellScale(scale)
    if type(themeManager.ApplyShellScale) == "function" then
        ns.ui.theme = themeManager.ApplyShellScale(ns.ui.theme or {}, scale)
        return ns.ui.theme
    end

    return theme()
end

local function theme_token_color(tokenName, fallback)
    local currentTheme = theme()
    local tokens = currentTheme.tokens or {}
    local value = tokens[tokenName]
    if type(value) == "table" then
        return { unpack(value) }
    end

    if type(fallback) == "table" then
        return { unpack(fallback) }
    end

    return { 0.1, 0.1, 0.1, 1.0 }
end

local function copy_color(color, alphaOverride)
    local resolved = type(color) == "table" and { unpack(color) } or { 0, 0, 0, 1 }
    if alphaOverride ~= nil then
        resolved[4] = alphaOverride
    elseif resolved[4] == nil then
        resolved[4] = 1
    end
    return resolved
end

local function tint_color(color, multiplier, alphaOverride)
    local resolved = copy_color(color)
    multiplier = tonumber(multiplier or 1) or 1
    resolved[1] = math.max(0, math.min(1, resolved[1] * multiplier))
    resolved[2] = math.max(0, math.min(1, resolved[2] * multiplier))
    resolved[3] = math.max(0, math.min(1, resolved[3] * multiplier))
    if alphaOverride ~= nil then
        resolved[4] = alphaOverride
    end
    return resolved
end

local function set_texture_color(texture, color)
    if not texture then
        return
    end

    color = copy_color(color)
    texture.color = color
    texture.texture = SOLID_TEXTURE
    if type(texture.SetTexture) == "function" then
        texture:SetTexture(SOLID_TEXTURE)
    end
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(unpack(color))
    elseif type(texture.SetVertexColor) == "function" then
        texture:SetVertexColor(unpack(color))
    end
end

local function ensure_texture(parent, existing, layer, subLevel)
    local texture = existing
    if not texture and parent and type(parent.CreateTexture) == "function" then
        texture = parent:CreateTexture(nil, layer or "BORDER")
    end
    if texture and type(texture.SetDrawLayer) == "function" and layer then
        texture:SetDrawLayer(layer, subLevel or 0)
    end
    return texture
end

local function set_art_shown(region, isShown)
    if not region then
        return
    end

    if isShown == false then
        if type(region.Hide) == "function" then
            region:Hide()
        end
    elseif type(region.Show) == "function" then
        region:Show()
    end
end

local function ensure_art_layers(frame)
    if not frame then
        return nil
    end

    frame.gbmArt = frame.gbmArt or {}
    local art = frame.gbmArt

    art.background = ensure_texture(frame, art.background, "BACKGROUND", 0)
    if art.background and type(art.background.SetAllPoints) == "function" then
        art.background:SetAllPoints(frame)
    end

    art.innerFill = ensure_texture(frame, art.innerFill, "BACKGROUND", 1)
    if art.innerFill then
        if type(art.innerFill.ClearAllPoints) == "function" then
            art.innerFill:ClearAllPoints()
        end
        art.innerFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        art.innerFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    end

    art.shadow = ensure_texture(frame, art.shadow, "BACKGROUND", 2)
    if art.shadow then
        if type(art.shadow.ClearAllPoints) == "function" then
            art.shadow:ClearAllPoints()
        end
        art.shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        art.shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    art.topLine = ensure_texture(frame, art.topLine, "BORDER", 2)
    art.bottomLine = ensure_texture(frame, art.bottomLine, "BORDER", 2)
    art.leftLine = ensure_texture(frame, art.leftLine, "BORDER", 2)
    art.rightLine = ensure_texture(frame, art.rightLine, "BORDER", 2)
    art.innerTopLine = ensure_texture(frame, art.innerTopLine, "BORDER", 1)
    art.innerBottomLine = ensure_texture(frame, art.innerBottomLine, "BORDER", 1)
    art.innerLeftLine = ensure_texture(frame, art.innerLeftLine, "BORDER", 1)
    art.innerRightLine = ensure_texture(frame, art.innerRightLine, "BORDER", 1)
    art.headerBand = ensure_texture(frame, art.headerBand, "ARTWORK", 0)
    art.headerBandShadow = ensure_texture(frame, art.headerBandShadow, "ARTWORK", 1)
    art.accentBar = ensure_texture(frame, art.accentBar, "ARTWORK", 2)
    art.glow = ensure_texture(frame, art.glow, "ARTWORK", 3)

    if art.topLine then
        if type(art.topLine.ClearAllPoints) == "function" then
            art.topLine:ClearAllPoints()
        end
        art.topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        art.topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        art.topLine:SetHeight(1)
    end
    if art.bottomLine then
        if type(art.bottomLine.ClearAllPoints) == "function" then
            art.bottomLine:ClearAllPoints()
        end
        art.bottomLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        art.bottomLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        art.bottomLine:SetHeight(1)
    end
    if art.leftLine then
        if type(art.leftLine.ClearAllPoints) == "function" then
            art.leftLine:ClearAllPoints()
        end
        art.leftLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        art.leftLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        art.leftLine:SetWidth(1)
    end
    if art.rightLine then
        if type(art.rightLine.ClearAllPoints) == "function" then
            art.rightLine:ClearAllPoints()
        end
        art.rightLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        art.rightLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        art.rightLine:SetWidth(1)
    end
    if art.innerTopLine then
        if type(art.innerTopLine.ClearAllPoints) == "function" then
            art.innerTopLine:ClearAllPoints()
        end
        art.innerTopLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        art.innerTopLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        art.innerTopLine:SetHeight(1)
    end
    if art.innerBottomLine then
        if type(art.innerBottomLine.ClearAllPoints) == "function" then
            art.innerBottomLine:ClearAllPoints()
        end
        art.innerBottomLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
        art.innerBottomLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        art.innerBottomLine:SetHeight(1)
    end
    if art.innerLeftLine then
        if type(art.innerLeftLine.ClearAllPoints) == "function" then
            art.innerLeftLine:ClearAllPoints()
        end
        art.innerLeftLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        art.innerLeftLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
        art.innerLeftLine:SetWidth(1)
    end
    if art.innerRightLine then
        if type(art.innerRightLine.ClearAllPoints) == "function" then
            art.innerRightLine:ClearAllPoints()
        end
        art.innerRightLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        art.innerRightLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        art.innerRightLine:SetWidth(1)
    end
    if art.headerBand then
        if type(art.headerBand.ClearAllPoints) == "function" then
            art.headerBand:ClearAllPoints()
        end
        art.headerBand:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
        art.headerBand:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
        art.headerBand:SetHeight(18)
    end
    if art.headerBandShadow then
        if type(art.headerBandShadow.ClearAllPoints) == "function" then
            art.headerBandShadow:ClearAllPoints()
        end
        art.headerBandShadow:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -20)
        art.headerBandShadow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -20)
        art.headerBandShadow:SetHeight(1)
    end
    if art.accentBar then
        if type(art.accentBar.ClearAllPoints) == "function" then
            art.accentBar:ClearAllPoints()
        end
        art.accentBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        art.accentBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 4)
        art.accentBar:SetWidth(3)
    end
    if art.glow then
        if type(art.glow.ClearAllPoints) == "function" then
            art.glow:ClearAllPoints()
        end
        art.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        art.glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end

    return art
end

local function apply_surface_art(frame, variant, baseColor, borderColor)
    local art = ensure_art_layers(frame)
    if not art then
        return
    end

    local currentTheme = theme()
    local accent = theme_token_color("accent", currentTheme.colors.accent)
    local accentMuted = theme_token_color("accentMuted", currentTheme.colors.accentMuted)
    local shadow = theme_token_color("shadow", currentTheme.colors.shadow)
    local innerLine = theme_token_color("borderSoft", currentTheme.colors.borderSoft)
    local darkFill = tint_color(baseColor, 0.72, math.min(1, (baseColor[4] or 1) + 0.02))
    local bandColor = copy_color(accentMuted, 0.16)
    local glowColor = copy_color(accent, 0.0)
    local shadowColor = copy_color(shadow, 0.38)
    local minimalRow = variant == "row" or variant == "row-alt" or variant == "row-selected"
    local isElevated = variant == "panel-alt"
        or variant == "metric-card"
        or variant == "action-card"
        or variant == "brand-card"
        or variant == "modal"
        or variant == "header"
    local showHeaderBand = isElevated
        or variant == "table-header"
        or variant == "sidebar"
        or variant == "input"

    if variant == "shell" then
        darkFill = tint_color(baseColor, 0.62, 0.96)
        bandColor = copy_color(accentMuted, 0.10)
        shadowColor = copy_color(shadow, 0.44)
    elseif variant == "sidebar" then
        darkFill = tint_color(baseColor, 0.70, 0.96)
        bandColor = copy_color(accentMuted, 0.12)
    elseif variant == "header" then
        darkFill = tint_color(baseColor, 0.78, 0.98)
        bandColor = copy_color(accent, 0.12)
        glowColor = copy_color(accent, 0.10)
    elseif variant == "metric-card" or variant == "action-card" or variant == "brand-card" then
        darkFill = tint_color(baseColor, 0.76, 0.98)
        bandColor = copy_color(accentMuted, 0.18)
        glowColor = copy_color(accent, 0.05)
    elseif variant == "table-header" then
        darkFill = tint_color(baseColor, 0.85, 0.98)
        bandColor = copy_color(accentMuted, 0.20)
    elseif variant == "table-filter" or variant == "table-viewport" then
        darkFill = tint_color(baseColor, 0.78, baseColor[4] or 0.96)
        bandColor = copy_color(accentMuted, 0.08)
    elseif minimalRow then
        darkFill = tint_color(baseColor, 0.92, baseColor[4] or 0.94)
        bandColor = copy_color(accentMuted, 0.0)
        showHeaderBand = false
    elseif variant == "modal" then
        darkFill = tint_color(baseColor, 0.68, 0.98)
        bandColor = copy_color(accentMuted, 0.20)
        glowColor = copy_color(accent, 0.06)
    elseif variant == "input" then
        darkFill = tint_color(baseColor, 0.78, 0.98)
        bandColor = copy_color(accentMuted, 0.08)
    end

    set_texture_color(art.background, baseColor)
    set_texture_color(art.innerFill, darkFill)
    set_texture_color(art.shadow, shadowColor)
    set_texture_color(art.topLine, borderColor)
    set_texture_color(art.bottomLine, borderColor)
    set_texture_color(art.leftLine, borderColor)
    set_texture_color(art.rightLine, borderColor)
    set_texture_color(art.innerTopLine, innerLine)
    set_texture_color(art.innerBottomLine, innerLine)
    set_texture_color(art.innerLeftLine, innerLine)
    set_texture_color(art.innerRightLine, innerLine)
    set_texture_color(art.headerBand, bandColor)
    set_texture_color(art.headerBandShadow, copy_color(borderColor, 0.44))
    set_texture_color(art.accentBar, copy_color(accent, 0.0))
    set_texture_color(art.glow, glowColor)

    art.surfaceVariant = variant
    set_art_shown(art.headerBand, showHeaderBand)
    set_art_shown(art.headerBandShadow, showHeaderBand)
    set_art_shown(art.accentBar, variant == "nav-active")
    set_art_shown(art.glow, (glowColor[4] or 0) > 0)

    if minimalRow then
        set_art_shown(art.topLine, false)
        set_art_shown(art.leftLine, false)
        set_art_shown(art.rightLine, false)
        set_art_shown(art.innerTopLine, false)
        set_art_shown(art.innerLeftLine, false)
        set_art_shown(art.innerRightLine, false)
        set_art_shown(art.innerBottomLine, false)
    else
        set_art_shown(art.topLine, true)
        set_art_shown(art.bottomLine, true)
        set_art_shown(art.leftLine, true)
        set_art_shown(art.rightLine, true)
        set_art_shown(art.innerTopLine, true)
        set_art_shown(art.innerBottomLine, true)
        set_art_shown(art.innerLeftLine, true)
        set_art_shown(art.innerRightLine, true)
    end
end

function mainFrameShell.ApplySurfaceVariant(frame, variant, colorOverride)
    if not frame then
        return
    end

    local resolvedVariant = SURFACE_VARIANTS[variant or "panel"] and variant or "panel"
    local variantDefinition = SURFACE_VARIANTS[resolvedVariant] or SURFACE_VARIANTS.panel
    local baseColor = type(colorOverride) == "table"
        and { unpack(colorOverride) }
        or theme_token_color(variantDefinition.colorToken, theme().colors.panel)
    local borderColor = theme_token_color(variantDefinition.borderToken, theme().colors.border)

    frame.gbmSurfaceVariant = resolvedVariant
    frame.gbmBackdropBaseColor = baseColor
    frame.gbmBorderColor = borderColor

    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop(backdrop)
    end

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(unpack(baseColor))
    end

    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end

    apply_surface_art(frame, resolvedVariant, baseColor, borderColor)
end

function mainFrameShell.SetAccentBar(frame, color, isVisible)
    local art = ensure_art_layers(frame)
    if not art then
        return
    end

    local resolvedColor = copy_color(color or theme_token_color("accent", theme().colors.accent), isVisible == false and 0 or ((color or {})[4] or 1))
    set_texture_color(art.accentBar, resolvedColor)
    set_art_shown(art.accentBar, isVisible ~= false)
end

function mainFrameShell.SetHeaderBand(frame, color, isVisible)
    local art = ensure_art_layers(frame)
    if not art then
        return
    end

    set_texture_color(art.headerBand, copy_color(color or theme_token_color("accentMuted", theme().colors.accent), (color or {})[4] or 0.16))
    set_texture_color(art.headerBandShadow, copy_color(theme_token_color("border", theme().colors.border), 0.36))
    set_art_shown(art.headerBand, isVisible ~= false)
    set_art_shown(art.headerBandShadow, isVisible ~= false)
end

function mainFrameShell.SetGlow(frame, color, isVisible)
    local art = ensure_art_layers(frame)
    if not art then
        return
    end

    set_texture_color(art.glow, copy_color(color or theme_token_color("accent", theme().colors.accent), isVisible == false and 0 or ((color or {})[4] or 0.08)))
    set_art_shown(art.glow, isVisible ~= false)
end

function mainFrameShell.ApplyPanelStyle(frame, color)
    if type(color) == "string" then
        return mainFrameShell.ApplySurfaceVariant(frame, color)
    end

    return mainFrameShell.ApplySurfaceVariant(frame, "panel", color or theme().colors.panel)
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
    mainFrameShell.ApplySurfaceVariant(button, "panel", theme().colors.panel)
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

function mainFrameShell.ApplyButtonVariant(button, variant, colorOverride)
    if not button then
        return
    end

    local resolvedVariant = BUTTON_VARIANTS[variant or "secondary"] and variant or "secondary"
    local definition = BUTTON_VARIANTS[resolvedVariant] or BUTTON_VARIANTS.secondary
    mainFrameShell.ApplySurfaceVariant(button, definition.surfaceVariant or "panel", colorOverride)
    button.gbmButtonVariant = resolvedVariant

    if type(button.SetBackdropBorderColor) == "function" and definition.borderToken then
        button:SetBackdropBorderColor(unpack(theme_token_color(definition.borderToken, theme().colors.border)))
    end

    local art = ensure_art_layers(button)
    if art then
        if resolvedVariant == "primary" then
            set_texture_color(art.background, theme_token_color("button", theme().colors.panelAlt))
            set_texture_color(art.innerFill, tint_color(theme_token_color("buttonHover", theme().colors.panelAlt), 0.92, 0.98))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.22), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.06), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "secondary" then
            set_texture_color(art.background, tint_color(theme_token_color("button", theme().colors.panel), 0.88, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 1.0, 0.95))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.12), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.0), false)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "tab" then
            set_texture_color(art.background, tint_color(theme_token_color("panelAlt", theme().colors.panelAlt), 0.94, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 1.0, 0.96))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.18), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.04), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "danger" then
            set_texture_color(art.background, tint_color(theme_token_color("danger", theme().colors.panelAlt), 0.45, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("danger", theme().colors.panelAlt), 0.60, 0.94))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0.22), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0.07), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0), false)
        elseif resolvedVariant == "nav" then
            set_texture_color(art.background, tint_color(theme_token_color("panel", theme().colors.panel), 0.78, 0.96))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 0.96, 0.90))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.08), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.0), false)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "icon" then
            set_texture_color(art.background, tint_color(theme_token_color("panel", theme().colors.panel), 0.80, 0.96))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 0.94, 0.90))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.10), true)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.02), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        end
    end

    if button.labelText and type(button.labelText.SetTextColor) == "function" then
        if resolvedVariant == "primary" then
            button.labelText:SetTextColor(unpack(theme_token_color("buttonText", theme().colors.accentStrong)))
        elseif resolvedVariant == "danger" then
            button.labelText:SetTextColor(unpack(theme_token_color("textStrong", theme().colors.accentStrong)))
        elseif resolvedVariant == "nav" then
            button.labelText:SetTextColor(unpack(theme_token_color("text", theme().colors.accentStrong)))
        else
            button.labelText:SetTextColor(unpack(theme_token_color("accent", theme().colors.accentStrong)))
        end
    end

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
    local atlasByKind = {
        add = "common-icon-plus",
        remove = "common-icon-redx",
        undo = "common-icon-undo",
    }
    local tintByKind = {
        add = { 0.35, 1.0, 0.35, 1.0 },
        remove = { 1.0, 0.35, 0.35, 1.0 },
        undo = { 1.0, 0.82, 0.0, 1.0 },
    }
    if type(button.iconTexture.SetAtlas) == "function" then
        button.iconTexture:SetAtlas(atlasByKind[kind] or "common-icon-undo", true)
    end
    button.iconTexture.tint = tintByKind[kind] or { 1, 1, 1, 1 }
    if type(button.iconTexture.SetVertexColor) == "function" then
        button.iconTexture:SetVertexColor(unpack(button.iconTexture.tint))
    end

    button.iconLabel = button.iconLabel or mainFrameShell.MakeLabel(button, "", "GameFontHighlightSmall")
    if type(button.iconLabel.ClearAllPoints) == "function" then
        button.iconLabel:ClearAllPoints()
    end
    button.iconLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.iconLabel:SetText("")
    button.iconLabel:Hide()
end

function mainFrameShell.MakeInput(parent, width, height)
    local input = _G.CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(width, height)
    mainFrameShell.ApplySurfaceVariant(input, "input", theme().colors.background)
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

local function item_result_key(item)
    if type(item) ~= "table" then
        return nil
    end

    return table.concat({
        tostring(item.itemID or ""),
        tostring(item.craftedQuality or ""),
        tostring(item.name or item.itemName or ""),
    }, "::")
end

local function create_virtualized_item_results_list(parent, options)
    options = options or {}

    local list = {}
    list.parent = parent
    list.width = math.max(0, options.width or 0)
    list.viewportHeight = math.max(0, options.viewportHeight or 0)
    list.rowHeight = math.max(1, options.rowHeight or 22)
    list.rowSpacing = math.max(0, options.rowSpacing or 2)
    list.scrollFrame = options.scrollFrame
    list.scrollChild = options.scrollChild
    list.scrollController = options.scrollController
    list.scrollBar = options.scrollBar
    list.formatLabel = options.formatLabel or function(item)
        return tostring((item or {}).name or (item or {}).itemName or "")
    end
    list.onItemSelected = options.onItemSelected
    list.dataProvider = _G.CreateDataProvider()
    list.scrollBox = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list.scrollBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    list.scrollBox:SetWidth(list.width)
    list.scrollBox:SetHeight(list.viewportHeight)
    list.rowPool = {}
    list.selectedItem = nil
    list.selectedKey = nil
    list.contentHeight = list.viewportHeight
    list.visibleStartIndex = 0
    list.visibleEndIndex = 0

    list.scrollBox.dataProvider = list.dataProvider

    function list:GetStride()
        return self.rowHeight + self.rowSpacing
    end

    function list:GetVisibleCapacity()
        local stride = math.max(1, self:GetStride())
        return math.max(1, math.ceil(math.max(0, self.viewportHeight) / stride) + 1)
    end

    function list:EnsureRow(slotIndex)
        local row = self.rowPool[slotIndex]
        if row then
            return row
        end

        row = mainFrameShell.MakeButton(self.scrollBox, self.width, self.rowHeight, "")
        row:SetPoint("TOPLEFT", self.scrollBox, "TOPLEFT", 0, -((slotIndex - 1) * self:GetStride()))
        row:SetWidth(self.width)
        if row.labelText then
            row.labelText:Hide()
        end

        row.qualityIcon = row.qualityIcon or row:CreateTexture()
        row.qualityIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        if type(row.qualityIcon.SetWidth) == "function" then
            row.qualityIcon:SetWidth(16)
        end
        if type(row.qualityIcon.SetHeight) == "function" then
            row.qualityIcon:SetHeight(16)
        end
        row.qualityIcon:Hide()

        row.itemText = row.itemText or mainFrameShell.MakeLabel(row, "", "GameFontHighlightSmall")
        row.itemText:SetPoint("LEFT", row.qualityIcon, "RIGHT", 6, 0)
        if type(row.itemText.SetWidth) == "function" then
            row.itemText:SetWidth(math.max(0, self.width - 36))
        end

        row:SetScript("OnClick", function(button)
            if button.elementData then
                self:SetSelectedItem(button.elementData, true)
            end
        end)

        self.rowPool[slotIndex] = row
        return row
    end

    function list:HideExtraRows(startIndex)
        for slotIndex = startIndex, #(self.rowPool or {}) do
            self.rowPool[slotIndex].elementData = nil
            self.rowPool[slotIndex].resolvedItem = nil
            self.rowPool[slotIndex].isSelected = false
            self.rowPool[slotIndex]:Hide()
        end
    end

    function list:RefreshVisibleRows()
        local size = self.dataProvider:GetSize()
        if size <= 0 then
            self.visibleStartIndex = 0
            self.visibleEndIndex = 0
            self:HideExtraRows(1)
            return
        end

        local offset = 0
        if self.scrollFrame and type(self.scrollFrame.GetVerticalScroll) == "function" then
            offset = math.max(0, self.scrollFrame:GetVerticalScroll() or 0)
        end

        local stride = math.max(1, self:GetStride())
        local firstIndex = math.floor(offset / stride) + 1
        firstIndex = math.max(1, math.min(size, firstIndex))
        local lastIndex = math.min(size, firstIndex + self:GetVisibleCapacity() - 1)

        self.visibleStartIndex = firstIndex
        self.visibleEndIndex = lastIndex

        local slotIndex = 1
        for dataIndex = firstIndex, lastIndex do
            local row = self:EnsureRow(slotIndex)
            local elementData = self.dataProvider:Find(dataIndex)
            row.virtualIndex = dataIndex
            row.elementData = elementData
            row.resolvedItem = elementData
            row.itemText:SetText(self.formatLabel(elementData))

            local atlas = tostring((elementData or {}).craftedQualityIcon or "")
            local displayAtlas = type(craftedQuality.NormalizeDisplayAtlas) == "function" and craftedQuality.NormalizeDisplayAtlas(atlas) or atlas
            if displayAtlas ~= "" then
                row.qualityIcon.atlas = displayAtlas
                if type(row.qualityIcon.SetAtlas) == "function" then
                    row.qualityIcon:SetAtlas(displayAtlas, true)
                end
                row.qualityIcon:Show()
            else
                row.qualityIcon.atlas = nil
                row.qualityIcon:Hide()
            end

            local isSelected = item_result_key(elementData) ~= nil and item_result_key(elementData) == self.selectedKey
            row.isSelected = isSelected
            mainFrameShell.ApplyPanelStyle(row, isSelected and theme().colors.panelAlt or theme().colors.panel)
            row:Show()
            slotIndex = slotIndex + 1
        end

        self:HideExtraRows(slotIndex)
    end

    function list:RefreshMetrics()
        local size = self.dataProvider:GetSize()
        local stride = self:GetStride()
        if size > 0 then
            self.contentHeight = math.max(self.viewportHeight, (size * stride) - self.rowSpacing)
        else
            self.contentHeight = self.viewportHeight
        end

        if self.scrollChild and type(self.scrollChild.SetSize) == "function" then
            self.scrollChild:SetSize(self.width, self.contentHeight)
        end
        if self.scrollBox and type(self.scrollBox.SetSize) == "function" then
            self.scrollBox:SetSize(self.width, self.contentHeight)
        end
    end

    function list:SetSelectedItem(item, notify)
        self.selectedItem = item
        self.selectedKey = item_result_key(item)
        self:RefreshVisibleRows()
        if notify == true and type(self.onItemSelected) == "function" then
            self.onItemSelected(item)
        end
    end

    function list:SetData(items)
        self.dataProvider:Flush()
        for _, item in ipairs(items or {}) do
            self.dataProvider:Insert(item)
        end

        self.scrollBox.dataProvider = self.dataProvider

        self:RefreshMetrics()
        if self.scrollController then
            self.scrollController:Refresh(self.contentHeight, self.viewportHeight)
        else
            self:RefreshVisibleRows()
        end
    end

    if list.scrollController then
        list.scrollController.options = list.scrollController.options or {}
        list.scrollController.options.getContentHeight = function()
            return list.contentHeight
        end
        list.scrollController.options.getViewportHeight = function()
            return list.viewportHeight
        end
        list.scrollController.options.onOffsetChanged = function()
            list:RefreshVisibleRows()
        end
    end

    return list
end

function mainFrameShell.CreateItemSearchSelector(parent, options)
    options = options or {}

    local selector = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    selector:SetSize(options.width or 360, options.height or 156)

    local idLabelText = options.itemIDLabelText or "Search Item ID"
    local nameLabelText = options.itemNameLabelText or "Search Item Name"
    local selectedLabelText = options.selectedItemLabelText or "Selected Item"
    local resultsLabelText = options.resultsLabelText or "Matches"
    local idInputWidth = options.itemIDInputWidth or 92
    local nameInputWidth = options.itemNameInputWidth or 180
    local selectedTextWidth = options.selectedItemTextWidth or math.max(120, (options.width or 360) - 64)
    local resultsPanelWidth = options.resultsPanelWidth or (options.width or 360)
    local resultsPanelHeight = options.resultsPanelHeight or 74
    local resultRowHeight = options.resultRowHeight or 22
    local resultRowSpacing = options.resultRowSpacing or 2
    local resultsPanelInset = 4
    local resultsScrollBarWidth = 14
    local resultsViewportRightInset = resultsScrollBarWidth + 6
    local resultsContentWidth = math.max(0, resultsPanelWidth - resultsPanelInset - resultsViewportRightInset)
    local resultsViewportHeight = math.max(0, resultsPanelHeight - (resultsPanelInset * 2))
    local onResolved = options.onResolved
    local onSelectionChanged = options.onSelectionChanged
    local resolveQuery = options.resolveQuery
    local minimumNameQueryLength = math.max(0, tonumber(options.minimumNameQueryLength) or 0)

    local function trim_text(value)
        return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function match_label(item)
        local name = tostring((item or {}).name or (item or {}).itemName or "")
        local itemID = tostring((item or {}).itemID or "")
        local craftedQuality = tonumber((item or {}).craftedQuality)
        if craftedQuality and craftedQuality > 0 then
            return string.format("[T%d] %s (%s)", craftedQuality, name, itemID)
        end
        return string.format("%s (%s)", name, itemID)
    end

    local function should_auto_apply(source, rawQuery, resolutionItem)
        if source == "id" then
            local queryItemID = tonumber(trim_text(rawQuery))
            return queryItemID ~= nil and queryItemID == tonumber((resolutionItem or {}).itemID)
        end

        local queryName = string.lower(trim_text(rawQuery))
        local resolvedName = string.lower(tostring((resolutionItem or {}).name or (resolutionItem or {}).itemName or ""))
        return queryName ~= "" and queryName == resolvedName
    end

    selector.itemIDLabel = mainFrameShell.MakeLabel(selector, idLabelText, "GameFontHighlightSmall")
    selector.itemIDLabel:SetPoint("TOPLEFT", selector, "TOPLEFT", 0, 0)

    selector.itemNameLabel = mainFrameShell.MakeLabel(selector, nameLabelText, "GameFontHighlightSmall")
    selector.itemNameLabel:SetPoint("TOPLEFT", selector.itemIDLabel, "TOPRIGHT", idInputWidth + 16, 0)

    selector.itemIDInput = mainFrameShell.MakeInput(selector, idInputWidth, 22)
    selector.itemIDInput:SetPoint("TOPLEFT", selector.itemIDLabel, "BOTTOMLEFT", 0, -4)

    selector.itemNameInput = mainFrameShell.MakeInput(selector, nameInputWidth, 22)
    selector.itemNameInput:SetPoint("TOPLEFT", selector.itemNameLabel, "BOTTOMLEFT", 0, -4)

    selector.selectedItemLabel = mainFrameShell.MakeLabel(selector, selectedLabelText, "GameFontHighlightSmall")
    selector.selectedItemLabel:SetPoint("TOPLEFT", selector.itemIDInput, "BOTTOMLEFT", 0, -12)

    selector.selectedItemQualityIcon = selector.selectedItemQualityIcon or selector:CreateTexture()
    selector.selectedItemQualityIcon:SetPoint("TOPLEFT", selector.selectedItemLabel, "BOTTOMLEFT", 0, -6)
    if type(selector.selectedItemQualityIcon.SetWidth) == "function" then
        selector.selectedItemQualityIcon:SetWidth(18)
    end
    if type(selector.selectedItemQualityIcon.SetHeight) == "function" then
        selector.selectedItemQualityIcon:SetHeight(18)
    end
    selector.selectedItemQualityIcon:Hide()

    selector.selectedItemNameText = mainFrameShell.MakeLabel(selector, "No item selected.", "GameFontNormal")
    selector.selectedItemNameText:SetPoint("LEFT", selector.selectedItemQualityIcon, "RIGHT", 6, 0)
    if type(selector.selectedItemNameText.SetWidth) == "function" then
        selector.selectedItemNameText:SetWidth(selectedTextWidth)
    end

    selector.statusText = mainFrameShell.MakeLabel(selector, "", "GameFontHighlightSmall")
    selector.statusText:SetPoint("TOPLEFT", selector.selectedItemQualityIcon, "BOTTOMLEFT", 0, -6)
    if type(selector.statusText.SetWidth) == "function" then
        selector.statusText:SetWidth(selectedTextWidth)
    end
    selector.statusText:Hide()

    selector.resultsLabel = mainFrameShell.MakeLabel(selector, resultsLabelText, "GameFontHighlightSmall")
    selector.resultsLabel:SetPoint("TOPLEFT", selector.statusText, "BOTTOMLEFT", 0, -10)

    selector.resultsPanel = _G.CreateFrame("Frame", nil, selector, "BackdropTemplate")
    selector.resultsPanel:SetPoint("TOPLEFT", selector.resultsLabel, "BOTTOMLEFT", 0, -6)
    selector.resultsPanel:SetSize(resultsPanelWidth, resultsPanelHeight)
    mainFrameShell.ApplyPanelStyle(selector.resultsPanel, theme().colors.background)
    selector.resultsPanel:Hide()

    local resultsOverflow = mainFrameShell.CreateTableOverflowViewport(selector.resultsPanel, {
        viewportInsetLeft = resultsPanelInset,
        viewportInsetTop = resultsPanelInset,
        viewportInsetRight = resultsViewportRightInset,
        viewportInsetBottom = resultsPanelInset,
        scrollInsetLeft = 0,
        scrollInsetTop = 0,
        scrollInsetRight = 0,
        scrollInsetBottom = 0,
        scrollBarWidth = resultsScrollBarWidth,
        scrollBarRightInset = resultsPanelInset,
        scrollBarTopInset = resultsPanelInset,
        scrollBarBottomInset = resultsPanelInset,
        viewportColor = theme().colors.background,
        controllerOptions = {
            wheelStep = resultRowHeight,
        },
    })

    selector.resultsViewportFrame = resultsOverflow.viewportFrame
    selector.resultsScrollFrame = resultsOverflow.scrollFrame
    selector.resultsScrollChild = resultsOverflow.scrollChild
    selector.resultsScrollBar = resultsOverflow.scrollBar
    selector.resultsScrollController = resultsOverflow.controller
    selector.resultsScrollChild:SetSize(resultsContentWidth, resultsViewportHeight)
    selector.resultRowHeight = resultRowHeight
    selector.resultRowSpacing = resultRowSpacing
    selector.resultsViewportHeight = resultsViewportHeight

    selector.resultsList = selector.resultsList or create_virtualized_item_results_list(selector.resultsScrollChild, {
        width = resultsContentWidth,
        viewportHeight = resultsViewportHeight,
        rowHeight = resultRowHeight,
        rowSpacing = resultRowSpacing,
        scrollFrame = selector.resultsScrollFrame,
        scrollChild = selector.resultsScrollChild,
        scrollController = selector.resultsScrollController,
        scrollBar = selector.resultsScrollBar,
        formatLabel = match_label,
        onItemSelected = function(item)
            selector:ApplySelectedItem(item, true)
        end,
    })
    selector.resultsScrollBox = selector.resultsList.scrollBox
    selector.resultsDataProvider = selector.resultsList.dataProvider
    selector.resultRows = selector.resultsList.rowPool
    selector.matchButtons = selector.resultRows
    selector.pendingProgrammaticInputs = selector.pendingProgrammaticInputs or {}

    function selector:SetProgrammaticInputValue(fieldKey, input, value)
        local resolvedValue = tostring(value or "")
        self.pendingProgrammaticInputs[fieldKey] = resolvedValue
        self.isResolving = true
        input:SetText(resolvedValue)
        self.isResolving = false
    end

    function selector:ConsumeProgrammaticInputValue(fieldKey, value)
        local pendingInputs = self.pendingProgrammaticInputs or {}
        local expectedValue = pendingInputs[fieldKey]
        if expectedValue == nil then
            return false
        end

        pendingInputs[fieldKey] = nil
        return tostring(value or "") == expectedValue
    end

    function selector:HideMatches()
        if self.resultsList then
            self.resultsList:SetData({})
            self.resultsList:SetSelectedItem(self.selectedItem, false)
            self.resultsContentHeight = self.resultsList.contentHeight
        end
        if self.resultsScrollController then
            self.resultsScrollController:SetOffset(0, 0, resultsViewportHeight)
        end
        self.resultsPanel:Hide()
        self.resolvedMatches = {}
    end

    function selector:SetStatusMessage(message)
        local resolvedMessage = tostring(message or "")
        if resolvedMessage == "" then
            self.statusText:SetText("")
            self.statusText:Hide()
            return
        end

        self.statusText:SetText(resolvedMessage)
        self.statusText:Show()
    end

    function selector:ApplySelectedItem(item, shouldPopulateInputs)
        self.selectedItem = item
        if shouldPopulateInputs ~= false then
            self:SetProgrammaticInputValue("id", self.itemIDInput, tostring((item or {}).itemID or ""))
            self:SetProgrammaticInputValue("name", self.itemNameInput, tostring((item or {}).name or (item or {}).itemName or ""))
        end

        if item then
            self.selectedItemNameText:SetText(tostring(item.name or item.itemName or ""))
            local atlas = tostring(item.craftedQualityIcon or "")
            local displayAtlas = type(craftedQuality.NormalizeDisplayAtlas) == "function" and craftedQuality.NormalizeDisplayAtlas(atlas) or atlas
            if displayAtlas ~= "" then
                self.selectedItemQualityIcon.atlas = displayAtlas
                if type(self.selectedItemQualityIcon.SetAtlas) == "function" then
                self.selectedItemQualityIcon:SetAtlas(displayAtlas, true)
                end
                self.selectedItemQualityIcon:Show()
            else
                self.selectedItemQualityIcon.atlas = nil
                self.selectedItemQualityIcon:Hide()
            end
            self:SetStatusMessage(nil)
        else
            self.selectedItemNameText:SetText("No item selected.")
            self.selectedItemQualityIcon.atlas = nil
            self.selectedItemQualityIcon:Hide()
        end

        if self.resultsList then
            self.resultsList:SetSelectedItem(item, false)
        end

        self:HideMatches()
        if type(onResolved) == "function" then
            onResolved(item)
        end
        if type(onSelectionChanged) == "function" then
            onSelectionChanged(item)
        end
        return item
    end

    function selector:ClearSelection(source)
        if source == "id" then
            self:SetProgrammaticInputValue("name", self.itemNameInput, "")
        elseif source == "name" then
            self:SetProgrammaticInputValue("id", self.itemIDInput, "")
        end
        if self.resultsList then
            self.resultsList:SetSelectedItem(nil, false)
        end
        self:SetStatusMessage(nil)
        return self:ApplySelectedItem(nil, false)
    end

    function selector:ShowMatches(matches)
        self.resolvedMatches = matches or {}
        if #self.resolvedMatches == 0 then
            self:HideMatches()
            return
        end

        self.resultsPanel:Show()
        if self.resultsList then
            self.resultsList:SetData(self.resolvedMatches)
            self.resultsList:SetSelectedItem(self.selectedItem, false)
            self.resultsContentHeight = self.resultsList.contentHeight
        end
    end

    function selector:ResolveQuery(rawQuery, source)
        if type(resolveQuery) ~= "function" then
            return nil
        end

        local normalizedQuery = trim_text(rawQuery)
        source = source or "name"
        if normalizedQuery == "" then
            self:HideMatches()
            self:ClearSelection(source)
            return nil
        end

        if source == "name" and minimumNameQueryLength > 0 and string.len(normalizedQuery) < minimumNameQueryLength then
            self:HideMatches()
            self:ClearSelection(source)
            return nil
        end

        local resolution = resolveQuery(rawQuery, source) or { status = "missing", matches = {} }
        self:HideMatches()

        if resolution.status == "resolved" then
            if source == "name" and not should_auto_apply(source, rawQuery, resolution.item) then
                self:ClearSelection(source)
                self:ShowMatches(resolution.matches or { resolution.item })
                return nil
            end
            return self:ApplySelectedItem(resolution.item, true)
        end

        if resolution.status == "multiple" then
            self:ClearSelection(source)
            self:ShowMatches(resolution.matches or {})
            return nil
        end

        if resolution.status == "unavailable" then
            self:ClearSelection(source)
            self:SetStatusMessage(resolution.message or "Bundled item database unavailable.")
            return nil
        end

        self:ClearSelection(source)
        return nil
    end

    function selector:SetSearchEnabled(enabled)
        self.itemIDInput:SetEnabled(enabled)
        self.itemNameInput:SetEnabled(enabled)
        for _, row in ipairs(self.resultRows or {}) do
            row:SetEnabled(enabled)
        end
    end

    selector.itemIDInput:SetScript("OnTextChanged", function()
        if selector.isResolving then
            return
        end
        local value = selector.itemIDInput:GetText() or ""
        if selector:ConsumeProgrammaticInputValue("id", value) then
            return
        end
        selector:ResolveQuery(value, "id")
    end)

    selector.itemNameInput:SetScript("OnTextChanged", function()
        if selector.isResolving then
            return
        end
        local value = selector.itemNameInput:GetText() or ""
        if selector:ConsumeProgrammaticInputValue("name", value) then
            return
        end
        selector:ResolveQuery(value, "name")
    end)

    selector:ClearSelection()

    return selector
end

function mainFrameShell.MakeSlider(parent, width, height, minValue, maxValue, initialValue)
    local slider = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    slider:SetSize(width, height)
    slider.minValue = minValue or 0
    slider.maxValue = maxValue or 1
    slider.value = initialValue or slider.minValue
    slider.valueStep = nil
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
    slider.track:SetHeight(math.max(8, math.floor((height or 18) / 3)))
    mainFrameShell.ApplySurfaceVariant(slider.track, "input")
    if type(slider.track.SetBackdropBorderColor) == "function" then
        slider.track:SetBackdropBorderColor(0, 0, 0, 0)
    end
    slider.trackBase = slider.trackBase or slider.track:CreateTexture()
    slider.trackBase:SetPoint("TOPLEFT", slider.track, "TOPLEFT", 1, -1)
    slider.trackBase:SetPoint("BOTTOMRIGHT", slider.track, "BOTTOMRIGHT", -1, 1)
    set_texture_color(slider.trackBase, tint_color(theme_token_color("bgAlt", theme().colors.background), 1.0, 0.94))
    slider.trackRidge = slider.trackRidge or slider.track:CreateTexture()
    slider.trackRidge:SetPoint("TOPLEFT", slider.track, "TOPLEFT", 2, -2)
    slider.trackRidge:SetPoint("BOTTOMRIGHT", slider.track, "BOTTOMRIGHT", -2, 2)
    set_texture_color(slider.trackRidge, copy_color(theme_token_color("borderSoft", theme().colors.border), 0.22))

    slider.fill = slider.fill or _G.CreateFrame("Frame", nil, slider.track, "BackdropTemplate")
    slider.fill:SetPoint("TOPLEFT", slider.track, "TOPLEFT", 0, 0)
    slider.fill:SetPoint("BOTTOMLEFT", slider.track, "BOTTOMLEFT", 0, 0)
    slider.fill:SetWidth(0)
    mainFrameShell.ApplySurfaceVariant(slider.fill, "panel-alt", theme_token_color("accentMuted", theme().colors.accent))
    if type(slider.fill.SetBackdropBorderColor) == "function" then
        slider.fill:SetBackdropBorderColor(0, 0, 0, 0)
    end
    slider.fillGlow = slider.fillGlow or slider.fill:CreateTexture()
    slider.fillGlow:SetPoint("TOPLEFT", slider.fill, "TOPLEFT", 1, -1)
    slider.fillGlow:SetPoint("BOTTOMRIGHT", slider.fill, "BOTTOMRIGHT", -1, 1)
    set_texture_color(slider.fillGlow, copy_color(theme_token_color("accent", theme().colors.accent), 0.34))

    slider.thumb = slider.thumb or _G.CreateFrame("Frame", nil, slider, "BackdropTemplate")
    slider.thumb:SetSize(18, math.max(20, height or 18))
    slider.thumb:SetPoint("CENTER", slider.track, "LEFT", 0, 0)
    mainFrameShell.ApplySurfaceVariant(slider.thumb, "panel-alt", theme_token_color("header", theme().colors.accentStrong))
    if type(slider.thumb.SetBackdropBorderColor) == "function" then
        slider.thumb:SetBackdropBorderColor(0, 0, 0, 0)
    end
    slider.thumbGlow = slider.thumbGlow or slider.thumb:CreateTexture()
    slider.thumbGlow:SetPoint("TOPLEFT", slider.thumb, "TOPLEFT", 1, -1)
    slider.thumbGlow:SetPoint("BOTTOMRIGHT", slider.thumb, "BOTTOMRIGHT", -1, 1)
    set_texture_color(slider.thumbGlow, copy_color(theme_token_color("accent", theme().colors.accent), 0.08))
    slider.thumbCore = slider.thumbCore or _G.CreateFrame("Frame", nil, slider.thumb, "BackdropTemplate")
    slider.thumbCore:SetSize(10, 10)
    slider.thumbCore:SetPoint("CENTER", slider.thumb, "CENTER", 0, 0)
    mainFrameShell.ApplySurfaceVariant(slider.thumbCore, "input", theme_token_color("bg", theme().colors.background))
    if type(slider.thumbCore.SetBackdropBorderColor) == "function" then
        slider.thumbCore:SetBackdropBorderColor(0, 0, 0, 0)
    end
    slider.dragReleaseTarget = slider.dragReleaseTarget or _G.CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
    slider.dragReleaseTarget:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
    slider.dragReleaseTarget:SetPoint("BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", 0, 0)
    if type(slider.dragReleaseTarget.EnableMouse) == "function" then
        slider.dragReleaseTarget:EnableMouse(true)
    end
    slider.dragReleaseTarget:Hide()

    local function clamp_value(self, value)
        value = math.max(self.minValue, math.min(self.maxValue, value or self.minValue))
        local step = tonumber(self.valueStep or 0) or 0
        if step > 0 then
            value = self.minValue + (math.floor(((value - self.minValue) / step) + 0.5) * step)
            value = math.max(self.minValue, math.min(self.maxValue, value))
        end
        return value
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

    function slider:SetValueFromRatio(ratio)
        ratio = math.max(0, math.min(1, tonumber(ratio or 0) or 0))
        local span = (self.maxValue or 1) - (self.minValue or 0)
        self:SetValue((self.minValue or 0) + (span * ratio))
    end

    function slider:SetValueStep(step)
        self.valueStep = tonumber(step or 0) or 0
    end

    local function cursor_ratio(frame)
        local track = frame and frame.track or slider.track
        if type(_G.GetCursorPosition) == "function"
            and track
            and type(track.GetLeft) == "function"
            and type(track.GetRight) == "function"
        then
            local left = track:GetLeft()
            local right = track:GetRight()
            if left ~= nil and right ~= nil and right > left then
                local cursorX = _G.GetCursorPosition()
                local scale = (_G.UIParent and type(_G.UIParent.GetEffectiveScale) == "function" and _G.UIParent:GetEffectiveScale()) or 1
                cursorX = (tonumber(cursorX or 0) or 0) / math.max(0.001, scale)
                return (cursorX - left) / (right - left)
            end
        end

        return nil
    end

    local function update_from_cursor(frame, ratio)
        ratio = tonumber(ratio)
        if ratio == nil then
            ratio = cursor_ratio(frame)
        end
        if ratio ~= nil then
            slider:SetValueFromRatio(ratio)
        end

        return slider.value
    end

    local function begin_drag(frame, _, ratio)
        slider.dragging = true
        return update_from_cursor(frame, ratio)
    end

    local function end_drag()
        slider.dragging = false
        if slider.dragReleaseTarget then
            slider.dragReleaseTarget:Hide()
        end
    end

    for _, target in ipairs({ slider, slider.track, slider.thumb }) do
        if type(target.EnableMouse) == "function" then
            target:EnableMouse(true)
        end
        if type(target.SetScript) == "function" then
            target:SetScript("OnMouseDown", begin_drag)
            target:SetScript("OnMouseUp", end_drag)
        end
    end
    if type(slider.SetScript) == "function" then
        slider:SetScript("OnUpdate", function()
            if slider.dragging then
                update_from_cursor(slider)
            end
        end)
        slider:SetScript("OnHide", end_drag)
    end
    if slider.dragReleaseTarget and type(slider.dragReleaseTarget.SetScript) == "function" then
        slider.dragReleaseTarget:SetScript("OnMouseUp", end_drag)
    end

    local original_begin_drag = begin_drag
    begin_drag = function(frame, button, ratio)
        slider.dragging = true
        if slider.dragReleaseTarget then
            slider.dragReleaseTarget:Show()
        end
        return update_from_cursor(frame, ratio)
    end
    for _, target in ipairs({ slider, slider.track, slider.thumb }) do
        if type(target.SetScript) == "function" then
            target:SetScript("OnMouseDown", begin_drag)
            target:SetScript("OnMouseUp", end_drag)
        end
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

local function resolve_sidebar_identity()
    local playerName = type(_G.UnitName) == "function" and tostring(_G.UnitName("player") or "Unknown") or "Unknown"
    local realmName = type(_G.GetRealmName) == "function" and tostring(_G.GetRealmName() or "") or ""
    local guildName = nil

    if type(_G.GetGuildInfo) == "function" then
        guildName = _G.GetGuildInfo("player")
    end

    if realmName ~= "" then
        playerName = string.format("%s-%s", playerName, realmName)
    end

    guildName = tostring(guildName or "")
    if guildName == "" then
        guildName = "No Guild"
    end

    return playerName, guildName
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
            local measured = math.max(0, self.options.getViewportHeight(self) or 0)
            if measured > 0 then
                return measured
            end
        end

        local measured = math.max(0, scrollFrame:GetHeight() or 0)
        if measured > 0 then
            return measured
        end

        return math.max(0, self.lastViewportHeight or 0)
    end

    function controller:GetContentHeight()
        if type(self.options.getContentHeight) == "function" then
            local measured = math.max(0, self.options.getContentHeight(self) or 0)
            if measured > 0 then
                return measured
            end
        end

        local child = scrollFrame.scrollChild
        local measured = math.max(0, child and (child:GetHeight() or 0) or 0)
        if measured > 0 then
            return measured
        end

        return math.max(0, self.lastContentHeight or 0)
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
        contentHeight = math.max(0, contentHeight or self.lastContentHeight or self:GetContentHeight())
        viewportHeight = math.max(0, viewportHeight or self.lastViewportHeight or self:GetViewportHeight())
        self.lastContentHeight = contentHeight
        self.lastViewportHeight = viewportHeight

        local range = math.max(0, contentHeight - viewportHeight)
        offset = self:NormalizeOffset(offset, range)

        scrollFrame.verticalScrollRange = range
        scrollFrame.verticalScroll = offset
        if type(self.options.applyScrollOffset) == "function" then
            self.options.applyScrollOffset(self, offset, range)
        else
            scrollFrame:SetVerticalScroll(offset)
        end

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
        self.lastContentHeight = contentHeight
        self.lastViewportHeight = viewportHeight
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

function mainFrameShell.ApplyFrameLayer(frame, strata, level)
    if type(frame) ~= "table" then
        return nil
    end

    frame.frameStrata = strata or frame.frameStrata or "DIALOG"
    frame.frameLevel = tonumber(level or frame.frameLevel or 0) or 0

    if type(frame.SetFrameStrata) == "function" then
        frame:SetFrameStrata(frame.frameStrata)
    end
    if type(frame.SetFrameLevel) == "function" then
        frame:SetFrameLevel(frame.frameLevel)
    end
    if type(frame.SetToplevel) == "function" then
        frame:SetToplevel(true)
    end

    return frame.frameLevel
end

function mainFrameShell.BringFrameToFront(frame, strata)
    if type(frame) ~= "table" then
        return nil
    end

    local nextLevel = next_window_level()
    mainFrameShell.ApplyFrameLayer(frame, strata or frame.frameStrata or "MEDIUM", nextLevel)
    if type(frame.Raise) == "function" then
        frame:Raise()
    end
    return nextLevel
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
    mainFrameShell.ApplyFrameLayer(mainFrame, "MEDIUM", tonumber(mainFrame.frameLevel or 40) or 40)
    mainFrame.currentAlpha = mainFrame.currentAlpha or 0.96
    mainFrame:SetAlpha(mainFrame.currentAlpha)
    mainFrameShell.ApplySurfaceVariant(mainFrame, "shell", currentTheme.colors.background)
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
        { key = "REQUESTS", label = "Request Admin" },
        { key = "EXPORTS", label = "Exports" },
        { key = "ABOUT", label = "About" },
        { key = "OPTIONS", label = "Options" },
    }
    mainFrame.viewDescriptions = mainFrame.viewDescriptions or {
        DASHBOARD = "Critical shortages, pending requests, and export readiness.",
        INVENTORY = "Search the latest bank snapshot and inspect current counts.",
        HISTORY = "Review procurement audit events with explicit timestamps and before/after values.",
        MINIMUMS = "Manage Guild Bank Item Minimum Stock Levels",
        REQUESTS = "Review and manage guild member requests.",
        EXPORTS = "Prepare Auctionator and spreadsheet-ready purchase output.",
        ABOUT = "Reference addon ownership, guild identity, runtime build info, and support notes.",
        OPTIONS = "Adjust shell behavior like transparency without cluttering the main toolbar.",
    }

    mainFrame.sidebar = mainFrame.sidebar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    mainFrame.sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
    mainFrame.sidebar:SetWidth(currentTheme.spacing.sidebarExpanded)
    mainFrameShell.ApplySurfaceVariant(mainFrame.sidebar, "sidebar", currentTheme.colors.panel)

    mainFrame.topBar = mainFrame.topBar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.topBar:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetHeight(currentTheme.spacing.topBarHeight)
    mainFrameShell.ApplySurfaceVariant(mainFrame.topBar, "header", currentTheme.colors.panelAlt)

    mainFrame.content = mainFrame.content or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.content:SetPoint("TOPLEFT", mainFrame.topBar, "BOTTOMLEFT", 0, 0)
    mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
    mainFrameShell.ApplySurfaceVariant(mainFrame.content, "panel", currentTheme.colors.background)

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
    mainFrameShell.ApplyButtonVariant(mainFrame.collapseButton, "icon")
    mainFrame.collapseButton:SetScript("OnClick", function()
        if type(mainFrame.ToggleSidebar) == "function" then
            mainFrame:ToggleSidebar()
        end
    end)

    mainFrame.sidebarCrestTexture = mainFrame.sidebarCrestTexture or mainFrame.sidebar:CreateTexture()
    mainFrame.sidebarCrestTexture:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 16, -12)
    if type(mainFrame.sidebarCrestTexture.SetSize) == "function" then
        mainFrame.sidebarCrestTexture:SetSize(24, 24)
    end
    if type(mainFrame.sidebarCrestTexture.SetTexture) == "function" then
        mainFrame.sidebarCrestTexture:SetTexture("Interface\\ICONS\\INV_Misc_Map_01")
    end
    mainFrame.sidebarCrestTexture.texture = "Interface\\ICONS\\INV_Misc_Map_01"

    mainFrame.scanButton = mainFrame.scanButton or mainFrameShell.MakeButton(mainFrame.topBar, 120, 28, "Scan Bank")
    mainFrame.scanButton:SetPoint("TOP", mainFrame.topBar, "TOP", 0, -16)
    mainFrameShell.ApplyButtonVariant(mainFrame.scanButton, "primary")
    mainFrame.scanButton:SetScript("OnClick", function()
        local scanner = ns.modules.scanner
        if scanner and type(scanner.BeginScan) == "function" then
            scanner.BeginScan()
        end
    end)

    mainFrame.sidebarIdentityPanel = mainFrame.sidebarIdentityPanel or _G.CreateFrame("Frame", nil, mainFrame.sidebar, "BackdropTemplate")
    mainFrame.sidebarIdentityPanel:SetPoint("LEFT", mainFrame.sidebar, "LEFT", 16, 0)
    mainFrame.sidebarIdentityPanel:SetPoint("RIGHT", mainFrame.sidebar, "RIGHT", -16, 0)
    mainFrame.sidebarIdentityPanel:SetHeight(76)
    mainFrameShell.ApplySurfaceVariant(mainFrame.sidebarIdentityPanel, "panel-alt")

    mainFrame.sidebarIdentityNameText = mainFrame.sidebarIdentityNameText or mainFrameShell.MakeLabel(mainFrame.sidebarIdentityPanel, "", "GameFontNormal")
    mainFrame.sidebarIdentityNameText:SetPoint("TOPLEFT", mainFrame.sidebarIdentityPanel, "TOPLEFT", 12, -12)
    if type(mainFrame.sidebarIdentityNameText.SetWidth) == "function" then
        mainFrame.sidebarIdentityNameText:SetWidth(160)
    end

    mainFrame.sidebarIdentityGuildText = mainFrame.sidebarIdentityGuildText or mainFrameShell.MakeLabel(mainFrame.sidebarIdentityPanel, "", "GameFontHighlightSmall")
    mainFrame.sidebarIdentityGuildText:SetPoint("TOPLEFT", mainFrame.sidebarIdentityNameText, "BOTTOMLEFT", 0, -8)
    if type(mainFrame.sidebarIdentityGuildText.SetWidth) == "function" then
        mainFrame.sidebarIdentityGuildText:SetWidth(160)
    end

    function mainFrame:RefreshSidebarIdentity()
        local playerName, guildName = resolve_sidebar_identity()
        self.sidebarIdentityNameText:SetText(playerName)
        self.sidebarIdentityGuildText:SetText(guildName)
        return playerName, guildName
    end

    mainFrame:RefreshSidebarIdentity()

    return mainFrame
end

ns.modules.mainFrameShell = mainFrameShell

return mainFrameShell
