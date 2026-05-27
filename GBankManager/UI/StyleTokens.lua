local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local styleTokens = ns.modules.styleTokens or {}

local PRESET_ALIASES = {
    ["default"] = "generic_wow",
    ["contrast"] = "high_contrast",
    ["horde"] = "horde",
    ["alliance"] = "alliance",
    ["legion"] = "legion",
    ["fel"] = "legion",
    ["void"] = "void",
    ["pride"] = "pride",
    ["adventurer"] = "generic_wow",
    ["warm"] = "generic_wow",
    ["moonglade"] = "nature",
    ["generic wow"] = "generic_wow",
    ["high contrast"] = "high_contrast",
}

local PRESET_ORDER = {
    "generic_wow",
    "high_contrast",
    "alliance",
    "horde",
    "legion",
    "nature",
    "pride",
    "void",
}

local ART_ROOT = "Interface\\AddOns\\GBankManager\\Art\\"
local MINIMAP_BUTTON_TEXTURE = ART_ROOT .. "GBM_Minimap_Button.png"

local BASE_SPACING = {
    spacingXS = 4,
    spacingSM = 8,
    spacingMD = 12,
    spacingLG = 16,
    spacingXL = 24,
    sidebarExpanded = 220,
    sidebarCollapsed = 72,
    frameWidth = 1080,
    frameHeight = 660,
    topBarHeight = 68,
    rowHeightCompact = 22,
    rowHeightComfortable = 26,
    rowHeightWide = 30,
}

local DENSITY = {
    compact = {
        key = "compact",
        label = "Compact",
        rowHeight = BASE_SPACING.rowHeightCompact,
    },
    comfortable = {
        key = "comfortable",
        label = "Comfortable",
        rowHeight = BASE_SPACING.rowHeightComfortable,
    },
    wide = {
        key = "wide",
        label = "Wide",
        rowHeight = BASE_SPACING.rowHeightWide,
    },
}

local THEMES = {
    generic_wow = {
        key = "generic_wow",
        label = "Default",
        logoTexture = ART_ROOT .. "GBM_Logo_Default.png",
        logoTexCoord = { 0.1074, 0.1084, 0.8926, 0.8008 },
        tokens = {
            bg = { 0.03, 0.04, 0.06, 0.95 },
            bgAlt = { 0.05, 0.06, 0.08, 0.96 },
            panel = { 0.07, 0.08, 0.10, 0.97 },
            panelAlt = { 0.10, 0.11, 0.14, 0.98 },
            border = { 0.67, 0.55, 0.24, 0.92 },
            borderSoft = { 0.28, 0.24, 0.12, 0.84 },
            accent = { 0.92, 0.75, 0.24, 1.00 },
            accentHover = { 1.00, 0.83, 0.36, 1.00 },
            accentMuted = { 0.57, 0.43, 0.16, 1.00 },
            text = { 0.90, 0.88, 0.82, 1.00 },
            textMuted = { 0.67, 0.69, 0.72, 1.00 },
            textStrong = { 1.00, 0.95, 0.82, 1.00 },
            header = { 0.98, 0.79, 0.18, 1.00 },
            button = { 0.11, 0.10, 0.08, 0.98 },
            buttonHover = { 0.18, 0.15, 0.10, 0.98 },
            buttonText = { 0.99, 0.92, 0.70, 1.00 },
            danger = { 0.80, 0.21, 0.18, 1.00 },
            warning = { 0.90, 0.66, 0.18, 1.00 },
            success = { 0.28, 0.69, 0.33, 1.00 },
            info = { 0.30, 0.56, 0.85, 1.00 },
            row = { 0.08, 0.09, 0.10, 0.96 },
            rowAlt = { 0.14, 0.15, 0.17, 0.96 },
            rowHover = { 0.17, 0.17, 0.19, 0.97 },
            inputBg = { 0.015, 0.016, 0.020, 0.99 },
            inputBorder = { 0.60, 0.49, 0.21, 0.96 },
            modalBg = { 0.04, 0.04, 0.05, 0.98 },
            modalBorder = { 0.74, 0.61, 0.26, 0.95 },
            shadow = { 0.00, 0.00, 0.00, 0.70 },
        },
    },
    alliance = {
        key = "alliance",
        label = "Alliance",
        logoTexture = ART_ROOT .. "GBM_Logo_Alliance.png",
        logoTexCoord = { 0.0801, 0.0977, 0.9209, 0.8125 },
        tokens = {
            bg = { 0.04, 0.07, 0.13, 0.96 },
            bgAlt = { 0.07, 0.11, 0.18, 0.96 },
            panel = { 0.08, 0.12, 0.21, 0.98 },
            panelAlt = { 0.10, 0.16, 0.28, 0.98 },
            border = { 0.71, 0.62, 0.33, 0.92 },
            borderSoft = { 0.27, 0.38, 0.56, 0.82 },
            accent = { 0.24, 0.51, 0.89, 1.00 },
            accentHover = { 0.34, 0.62, 0.99, 1.00 },
            accentMuted = { 0.21, 0.37, 0.66, 1.00 },
            text = { 0.88, 0.92, 0.98, 1.00 },
            textMuted = { 0.60, 0.70, 0.82, 1.00 },
            textStrong = { 0.98, 0.98, 1.00, 1.00 },
            header = { 0.96, 0.85, 0.42, 1.00 },
            button = { 0.09, 0.13, 0.22, 0.98 },
            buttonHover = { 0.12, 0.19, 0.32, 0.98 },
            buttonText = { 0.95, 0.95, 1.00, 1.00 },
            danger = { 0.80, 0.21, 0.18, 1.00 },
            warning = { 0.90, 0.66, 0.18, 1.00 },
            success = { 0.28, 0.69, 0.33, 1.00 },
            info = { 0.30, 0.56, 0.85, 1.00 },
            row = { 0.08, 0.12, 0.20, 0.95 },
            rowAlt = { 0.13, 0.18, 0.29, 0.95 },
            rowHover = { 0.12, 0.20, 0.31, 0.96 },
            inputBg = { 0.025, 0.045, 0.085, 0.98 },
            inputBorder = { 0.35, 0.56, 0.84, 0.92 },
            modalBg = { 0.05, 0.08, 0.14, 0.98 },
            modalBorder = { 0.72, 0.64, 0.35, 0.94 },
            shadow = { 0.00, 0.00, 0.00, 0.70 },
        },
    },
    horde = {
        key = "horde",
        label = "Horde",
        logoTexture = ART_ROOT .. "GBM_Logo_Horde.png",
        logoTexCoord = { 0.0488, 0.0615, 0.9521, 0.8047 },
        tokens = {
            bg = { 0.09, 0.04, 0.04, 0.96 },
            bgAlt = { 0.12, 0.06, 0.05, 0.96 },
            panel = { 0.16, 0.07, 0.06, 0.98 },
            panelAlt = { 0.22, 0.09, 0.07, 0.98 },
            border = { 0.73, 0.50, 0.24, 0.92 },
            borderSoft = { 0.40, 0.18, 0.14, 0.82 },
            accent = { 0.83, 0.22, 0.16, 1.00 },
            accentHover = { 0.92, 0.35, 0.24, 1.00 },
            accentMuted = { 0.58, 0.21, 0.16, 1.00 },
            text = { 0.94, 0.87, 0.82, 1.00 },
            textMuted = { 0.73, 0.58, 0.54, 1.00 },
            textStrong = { 1.00, 0.94, 0.89, 1.00 },
            header = { 0.95, 0.74, 0.31, 1.00 },
            button = { 0.19, 0.08, 0.07, 0.98 },
            buttonHover = { 0.25, 0.10, 0.08, 0.98 },
            buttonText = { 0.99, 0.89, 0.75, 1.00 },
            danger = { 0.83, 0.23, 0.20, 1.00 },
            warning = { 0.90, 0.66, 0.18, 1.00 },
            success = { 0.28, 0.69, 0.33, 1.00 },
            info = { 0.30, 0.56, 0.85, 1.00 },
            row = { 0.14, 0.06, 0.05, 0.95 },
            rowAlt = { 0.21, 0.10, 0.07, 0.95 },
            rowHover = { 0.23, 0.10, 0.08, 0.96 },
            inputBg = { 0.05, 0.02, 0.02, 0.98 },
            inputBorder = { 0.58, 0.23, 0.18, 0.92 },
            modalBg = { 0.10, 0.04, 0.04, 0.98 },
            modalBorder = { 0.80, 0.58, 0.24, 0.94 },
            shadow = { 0.00, 0.00, 0.00, 0.74 },
        },
    },
    nature = {
        key = "nature",
        label = "Nature",
        logoTexture = ART_ROOT .. "GBM_Logo_Nature.png",
        logoTexCoord = { 0.0654, 0.0791, 0.9443, 0.9063 },
        tokens = {
            bg = { 0.05, 0.09, 0.07, 0.96 },
            bgAlt = { 0.08, 0.13, 0.10, 0.96 },
            panel = { 0.09, 0.16, 0.12, 0.98 },
            panelAlt = { 0.12, 0.21, 0.15, 0.98 },
            border = { 0.71, 0.61, 0.29, 0.92 },
            borderSoft = { 0.25, 0.41, 0.30, 0.82 },
            accent = { 0.42, 0.76, 0.40, 1.00 },
            accentHover = { 0.54, 0.86, 0.50, 1.00 },
            accentMuted = { 0.31, 0.54, 0.29, 1.00 },
            text = { 0.90, 0.92, 0.86, 1.00 },
            textMuted = { 0.62, 0.72, 0.64, 1.00 },
            textStrong = { 0.96, 0.98, 0.92, 1.00 },
            header = { 0.95, 0.82, 0.34, 1.00 },
            button = { 0.11, 0.18, 0.13, 0.98 },
            buttonHover = { 0.15, 0.24, 0.17, 0.98 },
            buttonText = { 0.94, 0.96, 0.88, 1.00 },
            danger = { 0.80, 0.21, 0.18, 1.00 },
            warning = { 0.90, 0.66, 0.18, 1.00 },
            success = { 0.28, 0.69, 0.33, 1.00 },
            info = { 0.30, 0.56, 0.85, 1.00 },
            row = { 0.09, 0.15, 0.10, 0.95 },
            rowAlt = { 0.14, 0.22, 0.15, 0.95 },
            rowHover = { 0.15, 0.23, 0.16, 0.96 },
            inputBg = { 0.03, 0.06, 0.04, 0.98 },
            inputBorder = { 0.37, 0.59, 0.39, 0.92 },
            modalBg = { 0.07, 0.11, 0.08, 0.98 },
            modalBorder = { 0.72, 0.63, 0.29, 0.94 },
            shadow = { 0.00, 0.00, 0.00, 0.70 },
        },
    },
    void = {
        key = "void",
        label = "Void",
        logoTexture = ART_ROOT .. "GBM_Logo_Void.png",
        logoTexCoord = { 0.0420, 0.0361, 0.9561, 0.8721 },
        tokens = {
            bg = { 0.05, 0.04, 0.10, 0.96 },
            bgAlt = { 0.08, 0.06, 0.15, 0.96 },
            panel = { 0.10, 0.07, 0.18, 0.98 },
            panelAlt = { 0.14, 0.10, 0.25, 0.98 },
            border = { 0.76, 0.61, 0.91, 0.92 },
            borderSoft = { 0.34, 0.25, 0.55, 0.82 },
            accent = { 0.62, 0.35, 0.91, 1.00 },
            accentHover = { 0.75, 0.49, 0.98, 1.00 },
            accentMuted = { 0.45, 0.27, 0.67, 1.00 },
            text = { 0.92, 0.89, 0.98, 1.00 },
            textMuted = { 0.68, 0.63, 0.83, 1.00 },
            textStrong = { 1.00, 0.97, 1.00, 1.00 },
            header = { 0.95, 0.78, 1.00, 1.00 },
            button = { 0.12, 0.08, 0.21, 0.98 },
            buttonHover = { 0.17, 0.11, 0.29, 0.98 },
            buttonText = { 0.98, 0.92, 1.00, 1.00 },
            danger = { 0.80, 0.21, 0.18, 1.00 },
            warning = { 0.90, 0.66, 0.18, 1.00 },
            success = { 0.28, 0.69, 0.33, 1.00 },
            info = { 0.30, 0.56, 0.85, 1.00 },
            row = { 0.10, 0.08, 0.17, 0.95 },
            rowAlt = { 0.16, 0.12, 0.27, 0.95 },
            rowHover = { 0.17, 0.12, 0.29, 0.96 },
            inputBg = { 0.03, 0.025, 0.07, 0.98 },
            inputBorder = { 0.52, 0.37, 0.76, 0.92 },
            modalBg = { 0.07, 0.05, 0.14, 0.98 },
            modalBorder = { 0.79, 0.62, 0.97, 0.94 },
            shadow = { 0.00, 0.00, 0.00, 0.74 },
        },
    },
    legion = {
        key = "legion",
        label = "Legion",
        logoTexture = ART_ROOT .. "GBM_Logo_Fel.png",
        logoTexCoord = { 0.0420, 0.0156, 0.9297, 0.9775 },
        tokens = {
            bg = { 0.03, 0.06, 0.04, 0.96 },
            bgAlt = { 0.05, 0.09, 0.06, 0.96 },
            panel = { 0.06, 0.11, 0.07, 0.98 },
            panelAlt = { 0.08, 0.15, 0.09, 0.98 },
            border = { 0.41, 0.88, 0.35, 0.92 },
            borderSoft = { 0.16, 0.34, 0.14, 0.84 },
            accent = { 0.33, 0.98, 0.30, 1.00 },
            accentHover = { 0.53, 1.00, 0.47, 1.00 },
            accentMuted = { 0.18, 0.54, 0.16, 1.00 },
            text = { 0.88, 0.96, 0.88, 1.00 },
            textMuted = { 0.61, 0.79, 0.61, 1.00 },
            textStrong = { 0.96, 1.00, 0.94, 1.00 },
            header = { 0.55, 1.00, 0.42, 1.00 },
            button = { 0.07, 0.13, 0.08, 0.98 },
            buttonHover = { 0.10, 0.19, 0.12, 0.98 },
            buttonText = { 0.89, 0.99, 0.87, 1.00 },
            danger = { 0.82, 0.24, 0.20, 1.00 },
            warning = { 0.90, 0.70, 0.22, 1.00 },
            success = { 0.33, 0.83, 0.40, 1.00 },
            info = { 0.28, 0.72, 0.63, 1.00 },
            row = { 0.06, 0.11, 0.07, 0.95 },
            rowAlt = { 0.10, 0.17, 0.10, 0.95 },
            rowHover = { 0.11, 0.20, 0.12, 0.96 },
            inputBg = { 0.02, 0.05, 0.03, 0.98 },
            inputBorder = { 0.31, 0.89, 0.30, 0.92 },
            modalBg = { 0.04, 0.08, 0.05, 0.98 },
            modalBorder = { 0.45, 0.92, 0.39, 0.95 },
            shadow = { 0.00, 0.00, 0.00, 0.74 },
        },
    },
    pride = {
        key = "pride",
        label = "Pride",
        logoTexture = ART_ROOT .. "GBM_Logo_Pride.png",
        logoTexCoord = { 0.0840, 0.0977, 0.9102, 0.8311 },
        tokens = {
            bg = { 0.11, 0.05, 0.12, 0.96 },
            bgAlt = { 0.17, 0.08, 0.18, 0.96 },
            panel = { 0.22, 0.10, 0.24, 0.98 },
            panelAlt = { 0.30, 0.13, 0.31, 0.98 },
            border = { 1.00, 0.56, 0.82, 0.94 },
            borderSoft = { 0.58, 0.22, 0.40, 0.86 },
            accent = { 1.00, 0.42, 0.86, 1.00 },
            accentHover = { 1.00, 0.62, 0.91, 1.00 },
            accentMuted = { 0.92, 0.29, 0.66, 1.00 },
            text = { 0.99, 0.94, 0.99, 1.00 },
            textMuted = { 0.89, 0.74, 0.86, 1.00 },
            textStrong = { 1.00, 0.98, 1.00, 1.00 },
            header = { 1.00, 0.50, 0.86, 1.00 },
            button = { 0.28, 0.12, 0.27, 0.98 },
            buttonHover = { 0.38, 0.16, 0.35, 0.98 },
            buttonText = { 1.00, 0.94, 0.98, 1.00 },
            danger = { 0.85, 0.24, 0.29, 1.00 },
            warning = { 0.94, 0.72, 0.21, 1.00 },
            success = { 0.30, 0.82, 0.50, 1.00 },
            info = { 1.00, 0.54, 0.90, 1.00 },
            row = { 0.20, 0.09, 0.22, 0.95 },
            rowAlt = { 0.28, 0.12, 0.30, 0.95 },
            rowHover = { 0.36, 0.16, 0.36, 0.96 },
            inputBg = { 0.10, 0.04, 0.10, 0.98 },
            inputBorder = { 1.00, 0.50, 0.86, 0.92 },
            modalBg = { 0.14, 0.06, 0.15, 0.98 },
            modalBorder = { 1.00, 0.64, 0.87, 0.95 },
            shadow = { 0.00, 0.00, 0.00, 0.74 },
        },
    },
    high_contrast = {
        key = "high_contrast",
        label = "High Contrast",
        logoTexture = ART_ROOT .. "GBM_Logo_HighContrast.png",
        logoTexCoord = { 0.0928, 0.0977, 0.9092, 0.8516 },
        tokens = {
            bg = { 0.02, 0.02, 0.02, 0.98 },
            bgAlt = { 0.06, 0.06, 0.06, 0.98 },
            panel = { 0.07, 0.07, 0.07, 0.98 },
            panelAlt = { 0.12, 0.12, 0.12, 0.98 },
            border = { 0.83, 0.85, 0.89, 1.00 },
            borderSoft = { 0.52, 0.54, 0.58, 0.92 },
            accent = { 0.92, 0.94, 0.97, 1.00 },
            accentHover = { 1.00, 1.00, 1.00, 1.00 },
            accentMuted = { 0.64, 0.67, 0.72, 1.00 },
            text = { 0.98, 0.98, 0.98, 1.00 },
            textMuted = { 0.82, 0.82, 0.82, 1.00 },
            textStrong = { 1.00, 1.00, 1.00, 1.00 },
            header = { 0.94, 0.96, 0.99, 1.00 },
            button = { 0.10, 0.10, 0.10, 0.98 },
            buttonHover = { 0.18, 0.18, 0.18, 0.98 },
            buttonText = { 1.00, 1.00, 1.00, 1.00 },
            danger = { 0.90, 0.26, 0.22, 1.00 },
            warning = { 0.95, 0.73, 0.19, 1.00 },
            success = { 0.36, 0.83, 0.40, 1.00 },
            info = { 0.36, 0.67, 0.97, 1.00 },
            row = { 0.06, 0.06, 0.06, 0.98 },
            rowAlt = { 0.11, 0.11, 0.11, 0.98 },
            rowHover = { 0.18, 0.18, 0.18, 0.98 },
            inputBg = { 0.02, 0.02, 0.02, 0.98 },
            inputBorder = { 0.88, 0.90, 0.94, 1.00 },
            modalBg = { 0.04, 0.04, 0.04, 0.98 },
            modalBorder = { 0.90, 0.92, 0.96, 1.00 },
            shadow = { 0.00, 0.00, 0.00, 0.78 },
        },
    },
}

local function copy_table(source)
    local out = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            out[key] = copy_table(value)
        else
            out[key] = value
        end
    end
    return out
end

function styleTokens.NormalizePresetKey(presetKey)
    local key = string.lower(tostring(presetKey or "generic_wow"))
    key = key:gsub("%s+", "_")
    return PRESET_ALIASES[key] or (THEMES[key] and key) or "generic_wow"
end

function styleTokens.GetTheme(presetKey)
    return THEMES[styleTokens.NormalizePresetKey(presetKey)]
end

function styleTokens.GetThemeLogoTexCoord(presetKey)
    local definition = THEMES[styleTokens.NormalizePresetKey(presetKey)]
    local texCoord = definition and definition.logoTexCoord
    if type(texCoord) == "table" then
        return { unpack(texCoord) }
    end
    return { 0, 0, 1, 1 }
end

function styleTokens.GetThemeOrder()
    local order = {}
    for index, key in ipairs(PRESET_ORDER) do
        order[index] = key
    end
    return order
end

function styleTokens.GetThemes()
    local out = {}
    for key, value in pairs(THEMES) do
        out[key] = copy_table(value)
    end
    return out
end

function styleTokens.GetMinimapButtonTexture()
    return MINIMAP_BUTTON_TEXTURE
end

function styleTokens.GetBaseSpacing()
    return copy_table(BASE_SPACING)
end

function styleTokens.GetDensityOptions()
    return copy_table(DENSITY)
end

ns.modules.styleTokens = styleTokens

return styleTokens
