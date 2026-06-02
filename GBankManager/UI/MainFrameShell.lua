local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local mainFrameShell = ns.modules.mainFrameShell or {}
local themeManager = ns.modules.themeManager or {}
local styleTokens = ns.modules.styleTokens or {}
local craftedQuality = ns.modules.craftedQuality or {}
local itemDisplay = ns.modules.itemDisplay or {}
if craftedQuality.NormalizeDisplayAtlas == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end
if itemDisplay.BuildDisplayPayload == nil and type(_G.dofile) == "function" then
    itemDisplay = _G.dofile("GBankManager/Domain/ItemDisplay.lua")
end
ns.ui.theme = ns.ui.theme or {}

local SOLID_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local function current_item_catalog()
    local itemCatalog = ns.modules.itemCatalog or {}
    if itemCatalog.ApplyCanonicalCraftedQuality == nil and type(_G.dofile) == "function" then
        itemCatalog = _G.dofile("GBankManager/Domain/ItemCatalog.lua")
    end
    return itemCatalog
end

local function sanitize_search_display_name(value)
    local itemCatalog = current_item_catalog()
    if type(itemCatalog.StripLegacyTierPrefix) == "function" then
        return itemCatalog.StripLegacyTierPrefix(value)
    end

    return tostring(value or ""):gsub("^%s*%[[Tt]%d+%]%s*", "")
end

local function build_item_display(item)
    item = type(item) == "table" and item or {}
    local itemCatalog = current_item_catalog()
    if type(itemCatalog.HydrateItem) == "function" then
        itemCatalog.HydrateItem(item)
    end
    if type(itemCatalog.ApplyCanonicalCraftedQuality) == "function" then
        itemCatalog.ApplyCanonicalCraftedQuality(item)
    end

    if type(itemDisplay.BuildDisplayPayload) == "function" then
        return itemDisplay.BuildDisplayPayload(item)
    end

    return {
        visibleText = sanitize_search_display_name(item.name or item.itemName or ""),
    }
end

local function resolve_display_atlas_for_item(item)
    item = type(item) == "table" and item or {}
    local itemCatalog = current_item_catalog()
    if type(itemCatalog.ApplyCanonicalCraftedQuality) == "function" then
        itemCatalog.ApplyCanonicalCraftedQuality(item)
    end
    local atlas = tostring(item.craftedQualityPreferredAtlas or item.craftedQualityDisplayAtlas or item.craftedQualityIcon or "")
    if type(craftedQuality.GetNonInventoryDisplayAtlasForItem) == "function" then
        return craftedQuality.GetNonInventoryDisplayAtlasForItem(item.itemID, atlas, item.craftedQuality, "reagent", item.craftedQualityFamilySize or item.craftedQualityMax)
    end

    if type(craftedQuality.GetDisplayAtlasForItem) == "function" then
        return craftedQuality.GetDisplayAtlasForItem(item.itemID, atlas, item.craftedQuality, "reagent", item.craftedQualityFamilySize or item.craftedQualityMax)
    end

    return type(craftedQuality.NormalizeDisplayAtlas) == "function"
        and craftedQuality.NormalizeDisplayAtlas(atlas, item.craftedQuality, "reagent", item.craftedQualityFamilySize or item.craftedQualityMax)
        or atlas
end

local function resolve_display_markup_for_item(item)
    item = type(item) == "table" and item or {}
    local itemCatalog = current_item_catalog()
    if type(itemCatalog.ApplyCanonicalCraftedQuality) == "function" then
        itemCatalog.ApplyCanonicalCraftedQuality(item)
    end
    local atlas = tostring(item.craftedQualityPreferredAtlas or item.craftedQualityDisplayAtlas or item.craftedQualityIcon or "")
    if type(craftedQuality.DisplayNonInventoryMarkupForItem) == "function" then
        return craftedQuality.DisplayNonInventoryMarkupForItem(item.itemID, atlas, 22, "reagent", item.craftedQuality, item.craftedQualityFamilySize or item.craftedQualityMax)
    end

    if type(craftedQuality.DisplayMarkupForItem) == "function" then
        return craftedQuality.DisplayMarkupForItem(item.itemID, atlas, 22, "reagent", item.craftedQuality, item.craftedQualityFamilySize or item.craftedQualityMax)
    end

    if type(craftedQuality.DisplayMarkup) == "function" then
        return craftedQuality.DisplayMarkup(atlas, 22, "reagent", item.craftedQuality, item.craftedQualityFamilySize or item.craftedQualityMax)
    end

    return ""
end

local function set_texture_atlas(texture, atlasName)
    if type(texture) ~= "table" then
        return false
    end

    atlasName = tostring(atlasName or "")
    if atlasName == "" then
        texture.atlas = nil
        if type(texture.Hide) == "function" then
            texture:Hide()
        end
        return false
    end

    if type(texture.SetAtlas) == "function" then
        texture:SetAtlas(atlasName, false)
    end
    texture.atlas = atlasName
    if type(texture.Show) == "function" then
        texture:Show()
    end
    return true
end

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
    ["header-toolbar"] = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
    header = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
    ["content-band"] = {
        colorToken = "bg",
        borderToken = "borderSoft",
    },
    panel = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["panel-flat"] = {
        colorToken = "panelAlt",
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
    ["metric-card-flat"] = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
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
    ["table-header-flat"] = {
        colorToken = "bgAlt",
        borderToken = "borderSoft",
    },
    ["table-filter"] = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["table-filter-flat"] = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["table-viewport"] = {
        colorToken = "bg",
        borderToken = "borderSoft",
    },
    ["table-viewport-structured"] = {
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
    ["modal-sheet"] = {
        colorToken = "modalBg",
        borderToken = "borderSoft",
    },
    input = {
        colorToken = "inputBg",
        borderToken = "inputBorder",
    },
}

local BUTTON_VARIANTS = {
    nav = {
        surfaceVariant = "panel-flat",
    },
    primary = {
        surfaceVariant = "action-card",
    },
    secondary = {
        surfaceVariant = "panel-flat",
    },
    select = {
        surfaceVariant = "input",
        borderToken = "inputBorder",
    },
    tab = {
        surfaceVariant = "panel-flat",
    },
    icon = {
        surfaceVariant = "panel-flat",
    },
    danger = {
        surfaceVariant = "panel-alt",
        borderToken = "danger",
    },
}

local BORDERLESS_VARIANTS = {
    shell = true,
    sidebar = true,
    ["header-toolbar"] = true,
    ["content-band"] = true,
    panel = true,
    ["panel-flat"] = true,
    ["panel-alt"] = true,
    ["metric-card"] = true,
    ["metric-card-flat"] = true,
    ["action-card"] = true,
    ["brand-card"] = true,
    ["wizard-rail"] = true,
    ["table-header"] = true,
    ["table-header-flat"] = true,
    ["table-filter"] = true,
    ["table-filter-flat"] = true,
    ["table-viewport"] = true,
    ["table-viewport-structured"] = true,
    row = true,
    ["row-alt"] = true,
    ["row-selected"] = true,
}

local TRANSPARENT_BACKDROP_VARIANTS = {
    shell = true,
    sidebar = true,
    ["header-toolbar"] = true,
    ["content-band"] = true,
    panel = true,
    ["panel-flat"] = true,
    ["panel-alt"] = true,
    ["metric-card"] = true,
    ["metric-card-flat"] = true,
    ["action-card"] = true,
    ["brand-card"] = true,
    ["wizard-rail"] = true,
    ["table-header"] = true,
    ["table-header-flat"] = true,
    ["table-filter"] = true,
    ["table-filter-flat"] = true,
    ["table-viewport"] = true,
    ["table-viewport-structured"] = true,
    row = true,
    ["row-alt"] = true,
    ["row-selected"] = true,
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

function mainFrameShell.GetThemeLogoTexture(presetKey)
    local definition = type(themeManager.GetTheme) == "function" and themeManager.GetTheme(presetKey) or nil
    return definition and definition.logoTexture or "Interface\\ICONS\\INV_Misc_Map_01"
end

function mainFrameShell.GetThemeLogoTexCoord(presetKey)
    if type(styleTokens.GetThemeLogoTexCoord) == "function" then
        local texCoord = styleTokens.GetThemeLogoTexCoord(presetKey)
        if type(texCoord) == "table" and #texCoord >= 4 then
            return { texCoord[1], texCoord[3], texCoord[2], texCoord[4] }
        end
    end
    return { 0, 0, 1, 1 }
end

function mainFrameShell.GetMinimapButtonTexture()
    if type(styleTokens.GetMinimapButtonTexture) == "function" then
        return styleTokens.GetMinimapButtonTexture()
    end
    return "Interface\\ICONS\\INV_Misc_Map_01"
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

local function set_texture_color(texture, color, preserveBaseColor)
    if not texture then
        return
    end

    color = copy_color(color)
    if preserveBaseColor ~= true then
        texture.gbmBaseColor = copy_color(color)
    end
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

local function apply_surface_alpha(frame, alpha)
    if not frame then
        return
    end

    alpha = math.max(0.0, math.min(1.0, tonumber(alpha or 1) or 1))
    frame.gbmSurfaceAlpha = alpha

    if frame.gbmBackdropBaseColor and type(frame.SetBackdropColor) == "function" then
        local color = copy_color(frame.gbmBackdropBaseColor, (frame.gbmBackdropBaseColor[4] or 1) * alpha)
        frame:SetBackdropColor(unpack(color))
    end

    if frame.gbmBorderColor and type(frame.SetBackdropBorderColor) == "function" then
        local color = copy_color(frame.gbmBorderColor, (frame.gbmBorderColor[4] or 1) * alpha)
        frame:SetBackdropBorderColor(unpack(color))
    end

    local art = frame.gbmArt
    if not art then
        return
    end

    for _, region in pairs(art) do
        if type(region) == "table" and region.gbmBaseColor then
            local color = copy_color(region.gbmBaseColor, (region.gbmBaseColor[4] or 1) * alpha)
            set_texture_color(region, color, true)
        end
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
        or variant == "metric-card-flat"
        or variant == "action-card"
        or variant == "brand-card"
        or variant == "modal"
        or variant == "header"
    local showHeaderBand = isElevated
        or variant == "table-header"
        or variant == "table-header-flat"
        or variant == "sidebar"
        or variant == "input"
    local showOuterTop = true
    local showOuterBottom = true
    local showOuterLeft = true
    local showOuterRight = true
    local showInnerTop = not minimalRow
    local showInnerBottom = not minimalRow
    local showInnerLeft = not minimalRow
    local showInnerRight = not minimalRow

    if variant == "shell" then
        darkFill = tint_color(baseColor, 0.62, 0.96)
        bandColor = copy_color(accentMuted, 0.10)
        shadowColor = copy_color(shadow, 0.44)
    elseif variant == "sidebar" then
        darkFill = tint_color(baseColor, 0.70, 0.96)
        bandColor = copy_color(accentMuted, 0.12)
        showHeaderBand = false
        showOuterTop = false
        showOuterLeft = false
        showOuterBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "header" then
        darkFill = tint_color(baseColor, 0.78, 0.98)
        bandColor = copy_color(accent, 0.12)
        glowColor = copy_color(accent, 0.10)
    elseif variant == "header-toolbar" then
        darkFill = tint_color(baseColor, 0.90, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.0)
        shadowColor = copy_color(shadow, 0.20)
        showHeaderBand = false
        showOuterTop = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "content-band" then
        darkFill = tint_color(baseColor, 0.86, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.0)
        shadowColor = copy_color(shadow, 0.18)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "panel" then
        darkFill = tint_color(baseColor, 0.82, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.0)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "panel-flat" then
        darkFill = tint_color(baseColor, 0.88, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.0)
        shadowColor = copy_color(shadow, 0.16)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "panel-alt" then
        darkFill = tint_color(baseColor, 0.86, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.02)
        shadowColor = copy_color(shadow, 0.18)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "metric-card" or variant == "metric-card-flat" or variant == "action-card" or variant == "brand-card" then
        darkFill = tint_color(baseColor, 0.86, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, variant == "brand-card" and 0.04 or 0.0)
        shadowColor = copy_color(shadow, 0.20)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "table-header" or variant == "table-header-flat" then
        darkFill = tint_color(baseColor, 0.92, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        showHeaderBand = false
        showOuterTop = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "table-filter" or variant == "table-filter-flat" then
        darkFill = tint_color(baseColor, 0.96, baseColor[4] or 0.97)
        bandColor = copy_color(accentMuted, 0.0)
        showHeaderBand = false
        showOuterTop = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "table-viewport" or variant == "table-viewport-structured" then
        darkFill = tint_color(baseColor, 0.82, baseColor[4] or 0.96)
        bandColor = copy_color(accentMuted, 0.0)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif minimalRow then
        darkFill = tint_color(baseColor, 1.00, baseColor[4] or 0.96)
        bandColor = copy_color(accentMuted, 0.0)
        showHeaderBand = false
        showOuterTop = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "modal" then
        darkFill = tint_color(baseColor, 0.68, 0.98)
        bandColor = copy_color(accentMuted, 0.20)
        glowColor = copy_color(accent, 0.06)
    elseif variant == "modal-sheet" then
        darkFill = tint_color(baseColor, 0.84, 0.98)
        bandColor = copy_color(accentMuted, 0.0)
        glowColor = copy_color(accent, 0.03)
        shadowColor = copy_color(shadow, 0.28)
        showHeaderBand = false
        showOuterTop = false
        showOuterBottom = false
        showOuterLeft = false
        showOuterRight = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    elseif variant == "input" then
        darkFill = tint_color(baseColor, 0.78, 0.98)
        bandColor = copy_color(accentMuted, 0.08)
        showHeaderBand = false
        showInnerTop = false
        showInnerBottom = false
        showInnerLeft = false
        showInnerRight = false
    end

    set_texture_color(art.background, baseColor)
    set_texture_color(art.innerFill, darkFill)
    set_texture_color(art.shadow, shadowColor)
    local rowSeparatorColor = copy_color(innerLine, 0.24)
    set_texture_color(art.topLine, minimalRow and rowSeparatorColor or borderColor)
    set_texture_color(art.bottomLine, minimalRow and rowSeparatorColor or borderColor)
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

    set_art_shown(art.topLine, showOuterTop)
    set_art_shown(art.bottomLine, showOuterBottom)
    set_art_shown(art.leftLine, showOuterLeft)
    set_art_shown(art.rightLine, showOuterRight)
    set_art_shown(art.innerTopLine, showInnerTop)
    set_art_shown(art.innerBottomLine, showInnerBottom)
    set_art_shown(art.innerLeftLine, showInnerLeft)
    set_art_shown(art.innerRightLine, showInnerRight)
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
    local backdropColor = copy_color(baseColor)
    local backdropBorderColor = copy_color(borderColor)

    if TRANSPARENT_BACKDROP_VARIANTS[resolvedVariant] == true then
        backdropColor[4] = 0
    end

    if BORDERLESS_VARIANTS[resolvedVariant] == true then
        backdropBorderColor[4] = 0
    end

    frame.gbmSurfaceVariant = resolvedVariant
    frame.gbmBackdropBaseColor = backdropColor
    frame.gbmBorderColor = backdropBorderColor

    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop(backdrop)
    end

    if type(frame.SetBackdropColor) == "function" then
        frame:SetBackdropColor(unpack(backdropColor))
    end

    if type(frame.SetBackdropBorderColor) == "function" then
        frame:SetBackdropBorderColor(unpack(backdropBorderColor))
    end

    apply_surface_art(frame, resolvedVariant, baseColor, borderColor)
    if frame.gbmSurfaceAlpha ~= nil then
        apply_surface_alpha(frame, frame.gbmSurfaceAlpha)
    end
end

function mainFrameShell.SetSurfaceAlpha(frame, alpha)
    apply_surface_alpha(frame, alpha)
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

function mainFrameShell.MakeCheckbox(parent, text)
    local checkbox = _G.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox.labelText = checkbox.labelText or mainFrameShell.MakeLabel(parent, text or "", "GameFontHighlightSmall")
    checkbox.labelText:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    checkbox.labelText:SetText(text or "")
    if type(checkbox.SetChecked) ~= "function" then
        function checkbox:SetChecked(value)
            self.checked = value and true or false
        end
    end
    if type(checkbox.GetChecked) ~= "function" then
        function checkbox:GetChecked()
            return self.checked == true
        end
    end
    return checkbox
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
    if type(button.labelText.SetWordWrap) == "function" then
        button.labelText:SetWordWrap(false)
    end
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
    button.gbmButtonFamily = nil
    button.gbmTabStyle = nil

    if resolvedVariant == "tab" then
        button.gbmTabStyle = "segmented-soft"
    elseif resolvedVariant == "primary" or resolvedVariant == "secondary" or resolvedVariant == "danger" then
        button.gbmButtonFamily = "action-slim"
    elseif resolvedVariant == "nav" then
        button.gbmButtonFamily = "nav-soft"
    end

    if type(button.SetBackdropBorderColor) == "function" and definition.borderToken and BORDERLESS_VARIANTS[definition.surfaceVariant or "panel"] ~= true then
        button:SetBackdropBorderColor(unpack(theme_token_color(definition.borderToken, theme().colors.border)))
    end

    local art = ensure_art_layers(button)
    if art then
        if resolvedVariant == "primary" then
            set_texture_color(art.background, tint_color(theme_token_color("button", theme().colors.panelAlt), 0.90, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("buttonHover", theme().colors.panelAlt), 1.18, 0.99))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.18), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.05), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "secondary" then
            set_texture_color(art.background, tint_color(theme_token_color("button", theme().colors.panel), 0.90, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("buttonHover", theme().colors.panelAlt), 1.18, 0.98))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.10), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.02), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "select" then
            set_texture_color(art.background, tint_color(theme_token_color("inputBg", theme().colors.background), 0.98, 0.99))
            set_texture_color(art.innerFill, tint_color(theme_token_color("buttonHover", theme().colors.panelAlt), 1.10, 0.97))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.08), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.03), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "tab" then
            set_texture_color(art.background, tint_color(theme_token_color("panelAlt", theme().colors.panelAlt), 0.94, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 1.0, 0.96))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.18), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.04), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "danger" then
            set_texture_color(art.background, tint_color(theme_token_color("danger", theme().colors.panelAlt), 0.45, 0.98))
            set_texture_color(art.innerFill, tint_color(theme_token_color("danger", theme().colors.panelAlt), 0.60, 0.94))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0.22), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0.07), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("danger", theme().colors.panelAlt), 0), false)
        elseif resolvedVariant == "nav" then
            set_texture_color(art.background, tint_color(theme_token_color("panel", theme().colors.panel), 0.78, 0.96))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 0.96, 0.90))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.08), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.0), false)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        elseif resolvedVariant == "icon" then
            set_texture_color(art.background, tint_color(theme_token_color("panel", theme().colors.panel), 0.80, 0.96))
            set_texture_color(art.innerFill, tint_color(theme_token_color("bgAlt", theme().colors.background), 0.94, 0.90))
            mainFrameShell.SetHeaderBand(button, copy_color(theme_token_color("accentMuted", theme().colors.accent), 0.10), false)
            mainFrameShell.SetGlow(button, copy_color(theme_token_color("accent", theme().colors.accent), 0.02), true)
            mainFrameShell.SetAccentBar(button, copy_color(theme_token_color("accent", theme().colors.accent), 0), false)
        end
    end

    button.dropdownGlyph = button.dropdownGlyph or mainFrameShell.MakeLabel(button, "v", "GameFontHighlightSmall")
    if type(button.dropdownGlyph.ClearAllPoints) == "function" then
        button.dropdownGlyph:ClearAllPoints()
    end
    button.dropdownGlyph:SetPoint("RIGHT", button, "RIGHT", -8, 0)

    if resolvedVariant == "select" then
        if button.labelText then
            if type(button.labelText.ClearAllPoints) == "function" then
                button.labelText:ClearAllPoints()
            end
            button.labelText:SetPoint("LEFT", button, "LEFT", 8, 0)
            if type(button.labelText.SetJustifyH) == "function" then
                button.labelText:SetJustifyH("LEFT")
            end
            if type(button.labelText.SetWidth) == "function" then
                button.labelText:SetWidth(math.max(0, (button:GetWidth() or 0) - 28))
            end
        end
        button.dropdownGlyph:SetText("v")
        if type(button.dropdownGlyph.SetTextColor) == "function" then
            button.dropdownGlyph:SetTextColor(unpack(theme_token_color("textMuted", theme().colors.textMuted)))
        end
        button.dropdownGlyph:Show()
    elseif button.dropdownGlyph then
        button.dropdownGlyph:Hide()
    end

    if button.labelText and type(button.labelText.SetTextColor) == "function" then
        if resolvedVariant == "primary" then
            button.labelText:SetTextColor(unpack(theme_token_color("buttonText", theme().colors.accentStrong)))
        elseif resolvedVariant == "secondary" then
            button.labelText:SetTextColor(unpack(theme_token_color("buttonText", theme().colors.accentStrong)))
        elseif resolvedVariant == "select" then
            button.labelText:SetTextColor(unpack(theme_token_color("textStrong", theme().colors.accentStrong)))
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
    mainFrameShell.ApplySurfaceVariant(input, "input")
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
    list.showQualityIcon = options.showQualityIcon == true
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
        row.qualityIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
        if type(row.qualityIcon.SetWidth) == "function" then
            row.qualityIcon:SetWidth(16)
        end
        if type(row.qualityIcon.SetHeight) == "function" then
            row.qualityIcon:SetHeight(16)
        end
        row.qualityIcon:Hide()

        row.tierText = row.tierText or mainFrameShell.MakeLabel(row, "", "GameFontHighlightSmall")
        row.tierText:SetPoint("LEFT", row.qualityIcon, "RIGHT", 6, 0)
        if type(row.tierText.SetWidth) == "function" then
            row.tierText:SetWidth(28)
        end
        if type(row.tierText.SetJustifyH) == "function" then
            row.tierText:SetJustifyH("LEFT")
        end

        row.itemText = row.itemText or mainFrameShell.MakeLabel(row, "", "GameFontHighlightSmall")
        row.itemText:SetPoint("LEFT", row, "LEFT", 8, 0)
        if type(row.itemText.SetWidth) == "function" then
            row.itemText:SetWidth(math.max(0, self.width - 16))
        end
        if type(row.itemText.SetJustifyH) == "function" then
            row.itemText:SetJustifyH("LEFT")
        end
        if type(row.itemText.SetJustifyV) == "function" then
            row.itemText:SetJustifyV("MIDDLE")
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
            local display = build_item_display(elementData)
            row.itemText:SetText(tostring(display.visibleText or ""))
            row.tierText:SetText("")
            row.tierText:Hide()
            local iconShown = false
            if self.showQualityIcon then
                iconShown = set_texture_atlas(row.qualityIcon, resolve_display_atlas_for_item(elementData))
            else
                row.qualityIcon.atlas = nil
                row.qualityIcon:Hide()
            end
            if type(row.itemText.ClearAllPoints) == "function" then
                row.itemText:ClearAllPoints()
            end
            if iconShown then
                row.itemText:SetPoint("LEFT", row, "LEFT", 30, 0)
                if type(row.itemText.SetWidth) == "function" then
                    row.itemText:SetWidth(math.max(0, self.width - 38))
                end
            else
                row.itemText:SetPoint("LEFT", row, "LEFT", 8, 0)
                if type(row.itemText.SetWidth) == "function" then
                    row.itemText:SetWidth(math.max(0, self.width - 16))
                end
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
    local showQualityIcon = options.showQualityIcon == true

    local function trim_text(value)
        return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function match_label(item)
        local name = sanitize_search_display_name((item or {}).name or (item or {}).itemName or "")
        local itemID = tostring((item or {}).itemID or "")
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
    selector.selectedItemNameText:SetPoint("TOPLEFT", selector.selectedItemLabel, "BOTTOMLEFT", 0, -6)
    if type(selector.selectedItemNameText.SetWidth) == "function" then
        selector.selectedItemNameText:SetWidth(selectedTextWidth)
    end

    selector.statusText = mainFrameShell.MakeLabel(selector, "", "GameFontHighlightSmall")
    selector.statusText:SetPoint("TOPLEFT", selector.selectedItemLabel, "BOTTOMLEFT", 0, -30)
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
        showQualityIcon = showQualityIcon,
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
            self:SetProgrammaticInputValue("name", self.itemNameInput, sanitize_search_display_name((item or {}).name or (item or {}).itemName or ""))
        end

        if item then
            local display = build_item_display(item)
            self.selectedItemNameText:SetText(tostring(display.visibleText or ""))
            local iconShown = false
            if showQualityIcon then
                iconShown = set_texture_atlas(self.selectedItemQualityIcon, resolve_display_atlas_for_item(item))
            else
                self.selectedItemQualityIcon.atlas = nil
                self.selectedItemQualityIcon:Hide()
            end
            if type(self.selectedItemNameText.ClearAllPoints) == "function" then
                self.selectedItemNameText:ClearAllPoints()
            end
            if iconShown then
                self.selectedItemNameText:SetPoint("TOPLEFT", self.selectedItemLabel, "BOTTOMLEFT", 24, -6)
            else
                self.selectedItemNameText:SetPoint("TOPLEFT", self.selectedItemLabel, "BOTTOMLEFT", 0, -6)
            end
            self:SetStatusMessage(nil)
        else
            self.selectedItemNameText:SetText("No item selected.")
            self.selectedItemQualityIcon.atlas = nil
            self.selectedItemQualityIcon:Hide()
            if type(self.selectedItemNameText.ClearAllPoints) == "function" then
                self.selectedItemNameText:ClearAllPoints()
            end
            self.selectedItemNameText:SetPoint("TOPLEFT", self.selectedItemLabel, "BOTTOMLEFT", 0, -6)
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
    local slider = _G.CreateFrame("Slider", nil, parent, "UISliderTemplate")
    slider:SetSize(width, height)
    if type(slider.SetOrientation) == "function" then
        slider:SetOrientation("HORIZONTAL")
    end
    if type(slider.EnableMouse) == "function" then
        slider:EnableMouse(true)
    end
    if type(slider.SetMinMaxValues) == "function" then
        slider:SetMinMaxValues(minValue or 0, maxValue or 1)
    end
    if type(slider.SetObeyStepOnDrag) == "function" then
        slider:SetObeyStepOnDrag(true)
    end
    if slider.Low and type(slider.Low.SetText) == "function" then
        slider.Low:SetText("")
    end
    if slider.High and type(slider.High.SetText) == "function" then
        slider.High:SetText("")
    end
    if slider.Text and type(slider.Text.SetText) == "function" then
        slider.Text:SetText("")
    end
    if type(slider.SetScript) == "function" then
        slider:SetScript("OnValueChanged", function(self, value)
            if type(self.onValueChanged) == "function" then
                self.onValueChanged(self, value)
            end
        end)
    end
    slider:SetValue(initialValue or minValue or 0)
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
    mainFrame:SetAlpha(1)
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
        { key = "MINIMUMS", label = "Minimums" },
        { key = "REQUESTS", label = "Requests" },
        { key = "EXPORTS", label = "Exports" },
        { key = "HISTORY", label = "History" },
        { key = "BANK_LEDGER", label = "Bank Ledger" },
        { key = "OPTIONS", label = "Options" },
        { key = "ABOUT", label = "About" },
    }
    mainFrame.viewDescriptions = mainFrame.viewDescriptions or {
        DASHBOARD = "Critical shortages, pending requests, and export readiness.",
        INVENTORY = "Search the latest bank snapshot and inspect current counts.",
        MINIMUMS = "Manage Guild Bank Item Minimum Stock Levels",
        REQUESTS = "Review and manage guild member requests.",
        EXPORTS = "Prepare Auctionator and spreadsheet-ready purchase output.",
        HISTORY = "Review audit history",
        BANK_LEDGER = "Review guild bank ledger history",
        OPTIONS = "",
        ABOUT = "",
    }

    mainFrame.sidebar = mainFrame.sidebar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.sidebarNavStyle = "sidebar-soft-row"
    mainFrame.headerStyle = "toolbar-band"
    mainFrame.contentSectionStyle = "flat-band"
    mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    mainFrame.sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 0, 0)
    mainFrame.sidebar:SetWidth(currentTheme.spacing.sidebarExpanded)
    mainFrameShell.ApplySurfaceVariant(mainFrame.sidebar, "sidebar", currentTheme.colors.panel)

    mainFrame.topBar = mainFrame.topBar or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.topBar:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    mainFrame.topBar:SetHeight(currentTheme.spacing.topBarHeight)
    mainFrameShell.ApplySurfaceVariant(mainFrame.topBar, "header-toolbar", currentTheme.colors.panelAlt)

    mainFrame.content = mainFrame.content or _G.CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    mainFrame.content:SetPoint("TOPLEFT", mainFrame.topBar, "BOTTOMLEFT", 0, 0)
    mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
    mainFrameShell.ApplySurfaceVariant(mainFrame.content, "content-band", currentTheme.colors.background)

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

    mainFrame.scanButton = mainFrame.scanButton or mainFrameShell.MakeButton(mainFrame.topBar, 120, 28, "Scan Bank")
    mainFrame.scanButton:SetPoint("TOP", mainFrame.topBar, "TOP", 0, -16)
    mainFrameShell.ApplyButtonVariant(mainFrame.scanButton, "primary")
    mainFrame.scanButton:SetScript("OnClick", function()
        local scanner = ns.modules.scanner
        if scanner and type(scanner.BeginScan) == "function" then
            scanner.BeginScan({
                forceLedgerScan = true,
            })
        end
    end)

    mainFrame.sidebarIdentityPanel = mainFrame.sidebarIdentityPanel or _G.CreateFrame("Frame", nil, mainFrame.sidebar, "BackdropTemplate")
    mainFrame.sidebarIdentityPanel:SetPoint("LEFT", mainFrame.sidebar, "LEFT", 16, 0)
    mainFrame.sidebarIdentityPanel:SetPoint("RIGHT", mainFrame.sidebar, "RIGHT", -16, 0)
    mainFrame.sidebarIdentityPanel:SetHeight(144)
    mainFrameShell.ApplySurfaceVariant(mainFrame.sidebarIdentityPanel, "panel-flat")

    if not mainFrame.sidebarCrestTexture or type(mainFrame.sidebarCrestTexture.GetParent) ~= "function"
        or mainFrame.sidebarCrestTexture:GetParent() ~= mainFrame.sidebarIdentityPanel then
        mainFrame.sidebarCrestTexture = mainFrame.sidebarIdentityPanel:CreateTexture()
    end
    if type(mainFrame.sidebarCrestTexture.SetDrawLayer) == "function" then
        mainFrame.sidebarCrestTexture:SetDrawLayer("ARTWORK", 2)
    end
    if type(mainFrame.sidebarCrestTexture.SetSize) == "function" then
        mainFrame.sidebarCrestTexture:SetSize(128, 128)
    end
    if type(mainFrame.sidebarCrestTexture.SetTexture) == "function" then
        mainFrame.sidebarCrestTexture:SetTexture(mainFrameShell.GetThemeLogoTexture((theme().themePreset or "generic_wow")))
    end
    if type(mainFrame.sidebarCrestTexture.SetTexCoord) == "function" then
        mainFrame.sidebarCrestTexture:SetTexCoord(unpack(mainFrameShell.GetThemeLogoTexCoord((theme().themePreset or "generic_wow"))))
    end
    mainFrame.sidebarCrestTexture.texture = mainFrameShell.GetThemeLogoTexture((theme().themePreset or "generic_wow"))

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
    mainFrame.sidebarCrestTexture:SetPoint("CENTER", mainFrame.sidebarIdentityPanel, "CENTER", 0, 0)

    return mainFrame
end

ns.modules.mainFrameShell = mainFrameShell

return mainFrameShell
