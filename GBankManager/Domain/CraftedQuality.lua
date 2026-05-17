local addonName, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.modules = ns.modules or {}

local craftedQuality = ns.modules.craftedQuality or {}

local function icon_text(icon)
    if type(icon) == "table" then
        for _, key in ipairs({ "atlas", "iconInventory", "iconMixed", "iconChat", "iconSmall", "icon", "texture", "markup" }) do
            local nested = icon_text(icon[key])
            if nested ~= "" then
                return nested
            end
        end

        return ""
    end

    if icon == nil then
        return ""
    end

    return tostring(icon)
end

function craftedQuality.GetIconText(icon)
    return icon_text(icon)
end

function craftedQuality.NormalizeDisplayAtlas(icon)
    local atlasName = icon_text(icon)
    if atlasName == "" then
        return ""
    end

    if string.sub(atlasName, 1, 3) == "|A:" or string.sub(atlasName, 1, 2) == "|T" then
        return atlasName
    end

    local parsedTier = craftedQuality.ParseTier(atlasName, 0)
    if parsedTier >= 1 and parsedTier <= 2 then
        return string.format("Professions-ChatIcon-Quality-Tier%d", parsedTier)
    end

    return atlasName
end

function craftedQuality.ToMarkup(icon, size)
    local atlasName = craftedQuality.NormalizeDisplayAtlas(icon)
    if atlasName == "" then
        return ""
    end

    if string.sub(atlasName, 1, 3) == "|A:" or string.sub(atlasName, 1, 2) == "|T" then
        return atlasName
    end

    local iconSize = math.max(1, math.floor(tonumber(size or 22) or 22))
    return string.format("|A:%s:%d:%d|a", tostring(atlasName), iconSize, iconSize)
end

function craftedQuality.ParseTier(icon, fallbackQuality)
    local atlasName = icon_text(icon)
    local tierText = string.match(atlasName, "[Tt]ier%s*[_%-]?(%d+)")
    if tierText == nil then
        tierText = string.match(atlasName, "[Qq]uality%s*[_%-]?(%d+)")
    end
    if tierText == nil then
        tierText = string.match(atlasName, "[Rr]ank%s*[_%-]?(%d+)")
    end

    local parsedTier = tonumber(tierText or "")
    if parsedTier and parsedTier >= 1 and parsedTier <= 5 then
        return parsedTier
    end

    local quality = tonumber(fallbackQuality or 0) or 0
    if quality >= 1 and quality <= 5 then
        return quality
    end

    return 0
end

ns.modules.craftedQuality = craftedQuality

return craftedQuality
