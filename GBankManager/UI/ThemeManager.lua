local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local themeManager = ns.modules.themeManager or {}
local styleTokens = ns.modules.styleTokens or {}

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

local function clamp_scale(value)
    value = tonumber(value or 1) or 1
    return math.max(0.85, math.min(1.2, value))
end

local function legacy_colors_from_tokens(tokens)
    tokens = tokens or {}
    return {
        background = copy_table(tokens.bg or { 0.06, 0.06, 0.07, 0.96 }),
        panel = copy_table(tokens.panel or { 0.11, 0.10, 0.08, 0.98 }),
        panelAlt = copy_table(tokens.panelAlt or { 0.15, 0.13, 0.09, 0.98 }),
        border = copy_table(tokens.border or { 0.58, 0.47, 0.21, 0.92 }),
        accent = copy_table(tokens.accent or { 0.82, 0.68, 0.26, 1.00 }),
        accentStrong = copy_table(tokens.textStrong or { 0.99, 0.95, 0.80, 1.00 }),
        muted = copy_table(tokens.textMuted or { 0.64, 0.63, 0.58, 1.00 }),
    }
end

local function spacing_for_scale(scale)
    local baseSpacing = type(styleTokens.GetBaseSpacing) == "function" and styleTokens.GetBaseSpacing() or {}
    local clamped = clamp_scale(scale)

    return {
        spacingXS = baseSpacing.spacingXS,
        spacingSM = baseSpacing.spacingSM,
        spacingMD = baseSpacing.spacingMD,
        spacingLG = baseSpacing.spacingLG,
        spacingXL = baseSpacing.spacingXL,
        rowHeightCompact = baseSpacing.rowHeightCompact,
        rowHeightComfortable = baseSpacing.rowHeightComfortable,
        rowHeightWide = baseSpacing.rowHeightWide,
        sidebarExpanded = math.max(1, math.floor((tonumber(baseSpacing.sidebarExpanded or 212) * clamped) + 0.5)),
        sidebarCollapsed = math.max(1, math.floor((tonumber(baseSpacing.sidebarCollapsed or 72) * clamped) + 0.5)),
        frameWidth = math.max(1, math.floor((tonumber(baseSpacing.frameWidth or 1040) * clamped) + 0.5)),
        frameHeight = math.max(1, math.floor((tonumber(baseSpacing.frameHeight or 640) * clamped) + 0.5)),
        topBarHeight = math.max(1, math.floor((tonumber(baseSpacing.topBarHeight or 64) * clamped) + 0.5)),
    }
end

local function rebuild_theme_state(themeState)
    local presetKey = type(styleTokens.NormalizePresetKey) == "function" and styleTokens.NormalizePresetKey(themeState.themePreset) or "generic_wow"
    local definition = type(styleTokens.GetTheme) == "function" and styleTokens.GetTheme(presetKey) or nil
    local tokens = copy_table((definition or {}).tokens or {})
    local shellScale = clamp_scale(themeState.shellScale or 1)

    themeState.themePreset = presetKey
    themeState.shellScale = shellScale
    themeState.definition = definition
    themeState.tokens = tokens
    themeState.colors = legacy_colors_from_tokens(tokens)
    themeState.spacing = spacing_for_scale(shellScale)

    return themeState
end

function themeManager.EnsureState(themeState)
    themeState = type(themeState) == "table" and themeState or {}
    return rebuild_theme_state(themeState)
end

function themeManager.NormalizePresetKey(presetKey)
    if type(styleTokens.NormalizePresetKey) == "function" then
        return styleTokens.NormalizePresetKey(presetKey)
    end
    return "generic_wow"
end

function themeManager.GetTheme(presetKey)
    if type(styleTokens.GetTheme) == "function" then
        return copy_table(styleTokens.GetTheme(presetKey))
    end
    return nil
end

function themeManager.GetThemes()
    if type(styleTokens.GetThemes) == "function" then
        return styleTokens.GetThemes()
    end
    return {}
end

function themeManager.GetThemePresetOrder()
    if type(styleTokens.GetThemeOrder) == "function" then
        return styleTokens.GetThemeOrder()
    end
    return { "generic_wow" }
end

function themeManager.ApplyThemePreset(themeState, presetKey)
    themeState = themeManager.EnsureState(themeState)
    themeState.themePreset = themeManager.NormalizePresetKey(presetKey)
    return rebuild_theme_state(themeState)
end

function themeManager.ApplyShellScale(themeState, scale)
    themeState = themeManager.EnsureState(themeState)
    themeState.shellScale = clamp_scale(scale)
    return rebuild_theme_state(themeState)
end

function themeManager.GetRegisteredFrames()
    ns.ui.themeRegisteredFrames = ns.ui.themeRegisteredFrames or {}
    return ns.ui.themeRegisteredFrames
end

function themeManager.RegisterFrame(frame, callback)
    if not frame then
        return
    end

    local frames = themeManager.GetRegisteredFrames()
    frames[frame] = callback or true
end

function themeManager.RepaintRegisteredFrames()
    for frame, callback in pairs(themeManager.GetRegisteredFrames()) do
        if callback == true then
            if type(frame.ApplyTheme) == "function" then
                frame:ApplyTheme()
            end
        elseif type(callback) == "function" then
            callback(frame)
        end
    end
end

ns.modules.themeManager = themeManager

return themeManager
