local addonName, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local craftedQuality = ns.modules.craftedQuality or {}

local function current_item_catalog()
    local itemCatalog = ns.modules.itemCatalog or {}
    if itemCatalog.GetBundledItemByID == nil and type(_G.dofile) == "function" then
        itemCatalog = _G.dofile("GBankManager/Domain/ItemCatalog.lua")
    end

    return itemCatalog
end

local function current_quality_entry(itemID)
    local itemCatalog = current_item_catalog()
    if type(itemCatalog.EnsureBundledDataLoaded) == "function" then
        itemCatalog.EnsureBundledDataLoaded()
    end

    local numericItemID = tonumber(itemID)
    if not numericItemID then
        return nil
    end

    for _, source in ipairs({
        ns.data.staticCraftedQualityByItemID,
        ns.modules.staticCraftedQualityByItemID,
        _G.GBankManagerItemQualityByID,
    }) do
        if type(source) == "table" and type(source[numericItemID]) == "table" then
            return source[numericItemID]
        end
    end

    return nil
end

local function current_live_quality_info(itemID)
    local tradeSkillUI = _G.C_TradeSkillUI
    local getter = type(tradeSkillUI) == "table" and tradeSkillUI.GetItemReagentQualityInfo or nil
    if type(getter) ~= "function" then
        return nil
    end

    local ok, info = pcall(getter, itemID)
    if not ok or type(info) ~= "table" then
        return nil
    end

    return info
end

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

local function resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    local resolvedIcon = icon
    local resolvedQuality = tonumber(fallbackQuality or 0) or 0
    local resolvedMaxQuality = tonumber(maxQuality or 0) or 0
    local resolvedDisplayAtlas = ""
    local hasBundledAuthority = false

    local itemCatalog = current_item_catalog()
    local bundledQualityEntry = current_quality_entry(itemID)

    if type(bundledQualityEntry) == "table" then
        if (tonumber(bundledQualityEntry.craftedQuality or 0) or 0) > 0
            or (tonumber(bundledQualityEntry.craftedQualityFamilySize or bundledQualityEntry.craftedQualityMax or 0) or 0) > 0
            or tostring(bundledQualityEntry.craftedQualityPreferredAtlas or bundledQualityEntry.craftedQualityDisplayAtlas or "") ~= "" then
            hasBundledAuthority = true
        end
        local bundledQuality = tonumber(bundledQualityEntry.craftedQuality or 0) or 0
        if bundledQuality > 0 then
            resolvedQuality = bundledQuality
        end
        if tostring(bundledQualityEntry.craftedQualityIcon or "") ~= "" then
            resolvedIcon = bundledQualityEntry.craftedQualityIcon or resolvedIcon
        end
        local bundledMaxQuality = tonumber(bundledQualityEntry.craftedQualityFamilySize or bundledQualityEntry.craftedQualityMax or 0) or 0
        if bundledMaxQuality > 0 then
            resolvedMaxQuality = bundledMaxQuality
        end
        local preferredAtlas = tostring(bundledQualityEntry.craftedQualityPreferredAtlas or bundledQualityEntry.craftedQualityDisplayAtlas or "")
        if preferredAtlas ~= "" then
            resolvedDisplayAtlas = preferredAtlas
        end
    end

    if (resolvedDisplayAtlas == "" or resolvedMaxQuality <= 0 or resolvedQuality <= 0) and type(itemCatalog.GetBundledItemByID) == "function" then
        local bundledItem = itemCatalog.GetBundledItemByID(itemID)
        if type(bundledItem) == "table" then
            if (tonumber(bundledItem.craftedQuality or 0) or 0) > 0
                or (tonumber(bundledItem.craftedQualityFamilySize or bundledItem.craftedQualityMax or 0) or 0) > 0
                or tostring(bundledItem.craftedQualityPreferredAtlas or bundledItem.craftedQualityDisplayAtlas or "") ~= "" then
                hasBundledAuthority = true
            end
            local bundledQuality = tonumber(bundledItem.craftedQuality or 0) or 0
            if bundledQuality > 0 then
                resolvedQuality = bundledQuality
            end
            local preferredIcon = tostring(bundledItem.craftedQualityPreferredAtlas or bundledItem.craftedQualityDisplayAtlas or bundledItem.craftedQualityIcon or "")
            if preferredIcon ~= "" then
                resolvedIcon = bundledItem.craftedQualityIcon or preferredIcon or resolvedIcon
            end
            local bundledMaxQuality = tonumber(bundledItem.craftedQualityFamilySize or bundledItem.craftedQualityMax or 0) or 0
            if bundledMaxQuality > 0 then
                resolvedMaxQuality = bundledMaxQuality
            end
            local preferredAtlas = tostring(bundledItem.craftedQualityPreferredAtlas or bundledItem.craftedQualityDisplayAtlas or "")
            if preferredAtlas ~= "" then
                resolvedDisplayAtlas = preferredAtlas
            end
        end
    end

    return resolvedIcon, resolvedQuality, resolvedMaxQuality, resolvedDisplayAtlas, hasBundledAuthority
end

local function unwrap_markup_atlas(atlasName)
    atlasName = tostring(atlasName or "")
    if string.sub(atlasName, 1, 3) == "|A:" then
        local atlas = string.match(atlasName, "^|A:([^:]+):")
        if atlas and atlas ~= "" then
            return atlas
        end
    end

    if string.sub(atlasName, 1, 2) == "|T" then
        local texture = string.match(atlasName, "^|T([^:]+):")
        if texture and texture ~= "" then
            return texture
        end
    end

    return atlasName
end

local function normalized_max_quality(maxQuality, parsedTier)
    local resolved = tonumber(maxQuality or 0) or 0
    if resolved >= 3 and resolved <= 5 then
        return resolved
    end

    if resolved == 2 then
        return 2
    end

    if parsedTier >= 3 and parsedTier <= 5 then
        return 5
    end

    return 0
end

local function display_atlas_for_tier(parsedTier, style, maxQuality)
    local resolvedMaxQuality = normalized_max_quality(maxQuality, parsedTier)
    if resolvedMaxQuality == 2 then
        if parsedTier == 1 then
            return "Professions-Icon-Quality-12-Tier1-Inv"
        end
        if parsedTier == 2 then
            return "Professions-Icon-Quality-12-Tier2-Inv"
        end
    end

    if resolvedMaxQuality >= 3 and parsedTier >= 1 and parsedTier <= 5 then
        return string.format("Professions-ChatIcon-Quality-Tier%d", parsedTier)
    end

    if parsedTier >= 1 and parsedTier <= 2 then
        return string.format("Professions-ChatIcon-Quality-Tier%d", parsedTier)
    end

    return nil
end

local function item_display_atlas_for_tier(parsedTier, style, maxQuality)
    return display_atlas_for_tier(parsedTier, style, maxQuality)
end

local function non_inventory_display_atlas_for_tier(parsedTier, maxQuality)
    local resolvedMaxQuality = normalized_max_quality(maxQuality, parsedTier)
    if resolvedMaxQuality == 2 and parsedTier >= 1 and parsedTier <= 2 then
        return string.format("Interface-Crafting-ReagentQuality-%d-Med", parsedTier)
    end

    return nil
end

local function live_non_inventory_atlas(liveQualityInfo)
    liveQualityInfo = type(liveQualityInfo) == "table" and liveQualityInfo or {}

    for _, key in ipairs({ "iconInventory", "iconMixed", "iconSmall", "iconChat" }) do
        local atlasName = tostring(liveQualityInfo[key] or "")
        if atlasName ~= "" then
            return atlasName
        end
    end

    return ""
end

local function normalize_preferred_item_atlas(atlasName, quality, maxQuality, style)
    local parsedTier = craftedQuality.ParseTier(atlasName, quality or 0)
    local resolvedMaxQuality = normalized_max_quality(maxQuality, parsedTier)
    if resolvedMaxQuality ~= 2 or parsedTier < 1 or parsedTier > 2 then
        return tostring(atlasName or "")
    end

    local text = unwrap_markup_atlas(atlasName)
    if text == "" then
        return item_display_atlas_for_tier(parsedTier, style, resolvedMaxQuality) or ""
    end

    if parsedTier == 1 or parsedTier == 2 then
        return item_display_atlas_for_tier(parsedTier, style, resolvedMaxQuality) or text
    end

    return text
end

local function generic_reagent_inventory_atlas(parsedTier, style, maxQuality, hasBundledAuthority)
    if hasBundledAuthority then
        return nil
    end

    if tostring(style or "") ~= "reagent" then
        return nil
    end

    if parsedTier ~= 2 then
        return nil
    end

    local resolvedMaxQuality = tonumber(maxQuality or 0) or 0
    if resolvedMaxQuality > 0 then
        return nil
    end

    return "Interface-Crafting-ReagentQuality-2-Med"
end

local function markup_atlas_for_tier(parsedTier)
    if parsedTier >= 1 and parsedTier <= 5 then
        return string.format("Professions-ChatIcon-Quality-Tier%d", parsedTier)
    end

    return nil
end

local function markup_string_for_atlas(atlasName, size)
    atlasName = tostring(atlasName or "")
    if atlasName == "" then
        return ""
    end

    local iconSize = math.max(1, math.floor(tonumber(size or 22) or 22))
    return string.format("|A:%s:%d:%d|a", atlasName, iconSize, iconSize)
end

function craftedQuality.NormalizeDisplayAtlas(icon, fallbackQuality, style, maxQuality)
    local atlasName = unwrap_markup_atlas(icon_text(icon))
    if atlasName == "" then
        return ""
    end

    local parsedTier = craftedQuality.ParseTier(atlasName, fallbackQuality or 0)
    local displayAtlas = display_atlas_for_tier(parsedTier, style, maxQuality)
    if displayAtlas ~= nil then
        return displayAtlas
    end

    return atlasName
end

function craftedQuality.GetDisplayAtlas(icon, fallbackQuality, style, maxQuality)
    local parsedTier = craftedQuality.ParseTier(icon, fallbackQuality or 0)
    if parsedTier >= 1 and parsedTier <= 5 then
        local displayAtlas = display_atlas_for_tier(parsedTier, style, maxQuality)
        if displayAtlas ~= nil and displayAtlas ~= "" then
            return displayAtlas
        end

        return string.format("Professions-ChatIcon-Quality-Tier%d", parsedTier)
    end

    return craftedQuality.NormalizeDisplayAtlas(icon, fallbackQuality, style, maxQuality)
end

function craftedQuality.GetDisplayAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    local resolvedIcon, resolvedQuality, resolvedMaxQuality, resolvedDisplayAtlas, hasBundledAuthority = resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    local liveQualityInfo = current_live_quality_info(itemID)
    local parsedTier = craftedQuality.ParseTier(resolvedIcon, resolvedQuality or 0)
    local resolvedFamily = normalized_max_quality(resolvedMaxQuality, parsedTier)

    if resolvedDisplayAtlas ~= "" then
        return normalize_preferred_item_atlas(resolvedDisplayAtlas, resolvedQuality, resolvedMaxQuality, style)
    end

    if resolvedFamily == 2 and type(liveQualityInfo) == "table" then
        local liveInventoryAtlas = tostring(liveQualityInfo.iconInventory or "")
        if liveInventoryAtlas ~= "" then
            return liveInventoryAtlas
        end
    end

    local genericInventoryAtlas = generic_reagent_inventory_atlas(parsedTier, style, resolvedMaxQuality, hasBundledAuthority)
    if genericInventoryAtlas ~= nil and genericInventoryAtlas ~= "" then
        return genericInventoryAtlas
    end

    local itemAwareAtlas = item_display_atlas_for_tier(parsedTier, style, resolvedMaxQuality)
    if itemAwareAtlas ~= nil and itemAwareAtlas ~= "" then
        return itemAwareAtlas
    end

    return craftedQuality.GetDisplayAtlas(resolvedIcon, resolvedQuality, style, resolvedMaxQuality)
end

function craftedQuality.GetNonInventoryPresentationForItem(itemID, icon, fallbackQuality, style, maxQuality)
    local resolvedIcon, resolvedQuality, resolvedMaxQuality, resolvedDisplayAtlas = resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    local resolvedStyle = tostring(style or "")
    if resolvedStyle == "" then
        resolvedStyle = "reagent"
    end

    local parsedTier = craftedQuality.ParseTier(resolvedIcon, resolvedQuality or 0)
    local resolvedFamily = normalized_max_quality(resolvedMaxQuality, parsedTier)
    local liveQualityInfo = current_live_quality_info(itemID)
    local atlasName = ""

    if resolvedFamily == 2 and tostring(resolvedDisplayAtlas or "") ~= "" then
        atlasName = normalize_preferred_item_atlas(resolvedDisplayAtlas, resolvedQuality, resolvedMaxQuality, resolvedStyle)
    end
    if tostring(atlasName or "") == "" then
        atlasName = craftedQuality.GetDisplayAtlasForItem(itemID, resolvedIcon, resolvedQuality, resolvedStyle, resolvedMaxQuality)
    end
    if tostring(atlasName or "") == "" then
        if resolvedFamily == 2 and type(liveQualityInfo) == "table" then
            atlasName = live_non_inventory_atlas(liveQualityInfo)
        end
    end
    if tostring(atlasName or "") == "" then
        atlasName = non_inventory_display_atlas_for_tier(parsedTier, resolvedMaxQuality)
    end
    if tostring(atlasName or "") == "" then
        atlasName = craftedQuality.GetDisplayAtlas(resolvedIcon, resolvedQuality, resolvedStyle, resolvedMaxQuality)
    end

    atlasName = tostring(atlasName or "")
    return {
        atlas = atlasName,
        markupAtlas = atlasName,
        markup = markup_string_for_atlas(atlasName, 22),
        icon = icon_text(resolvedIcon),
        quality = tonumber(resolvedQuality or 0) or 0,
        maxQuality = tonumber(resolvedMaxQuality or 0) or 0,
        preferredAtlas = tostring(resolvedDisplayAtlas or ""),
        style = resolvedStyle,
    }
end

function craftedQuality.GetNonInventoryDisplayAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    return tostring((craftedQuality.GetNonInventoryPresentationForItem(itemID, icon, fallbackQuality, style, maxQuality) or {}).atlas or "")
end

function craftedQuality.GetNonInventoryMarkupAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    return tostring((craftedQuality.GetNonInventoryPresentationForItem(itemID, icon, fallbackQuality, style, maxQuality) or {}).markupAtlas or "")
end

function craftedQuality.GetMarkupAtlas(icon, fallbackQuality, style, maxQuality)
    local parsedTier = craftedQuality.ParseTier(icon, fallbackQuality or 0)
    local markupAtlas = display_atlas_for_tier(parsedTier, style, maxQuality)
    if markupAtlas == nil or markupAtlas == "" then
        markupAtlas = markup_atlas_for_tier(parsedTier)
    end
    if markupAtlas ~= nil and markupAtlas ~= "" then
        return markupAtlas
    end

    return craftedQuality.NormalizeDisplayAtlas(icon, fallbackQuality, style, maxQuality)
end

function craftedQuality.GetMarkupAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    local displayAtlas = craftedQuality.GetDisplayAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    if tostring(displayAtlas or "") ~= "" then
        return tostring(displayAtlas)
    end

    local resolvedIcon, resolvedQuality, resolvedMaxQuality = resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    return craftedQuality.GetMarkupAtlas(resolvedIcon, resolvedQuality, style, resolvedMaxQuality)
end

function craftedQuality.ResolveItemFields(itemID, icon, fallbackQuality, maxQuality)
    return resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
end

function craftedQuality.DebugItemResolution(itemID, icon, fallbackQuality, maxQuality, style)
    local bundledQualityEntry = current_quality_entry(itemID)
    local itemCatalog = current_item_catalog()
    local bundledItem = type(itemCatalog.GetBundledItemByID) == "function" and itemCatalog.GetBundledItemByID(itemID) or nil
    local resolvedIcon, resolvedQuality, resolvedMaxQuality, resolvedDisplayAtlas, hasBundledAuthority = resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    local finalDisplayAtlas = normalize_preferred_item_atlas(resolvedDisplayAtlas, resolvedQuality, resolvedMaxQuality, style)
    if finalDisplayAtlas == "" then
        finalDisplayAtlas = craftedQuality.GetDisplayAtlasForItem(itemID, resolvedIcon, resolvedQuality, style, resolvedMaxQuality)
    end
    local finalMarkupAtlas = craftedQuality.GetMarkupAtlasForItem(itemID, resolvedIcon, resolvedQuality, style, resolvedMaxQuality)
    local nonInventoryPresentation = craftedQuality.GetNonInventoryPresentationForItem(itemID, resolvedIcon, resolvedQuality, style, resolvedMaxQuality)

    return {
        itemID = tonumber(itemID),
        inputIcon = icon_text(icon),
        inputQuality = tonumber(fallbackQuality or 0) or 0,
        inputMaxQuality = tonumber(maxQuality or 0) or 0,
        bundledCraftedQuality = tonumber(((bundledQualityEntry or bundledItem or {}).craftedQuality) or 0) or 0,
        bundledCraftedQualityMax = tonumber(((bundledQualityEntry or bundledItem or {}).craftedQualityMax) or 0) or 0,
        bundledCraftedQualityFamilySize = tonumber(((bundledQualityEntry or bundledItem or {}).craftedQualityFamilySize) or 0) or 0,
        bundledCraftedQualityDisplayAtlas = tostring(((bundledQualityEntry or bundledItem or {}).craftedQualityDisplayAtlas) or ""),
        bundledCraftedQualityPreferredAtlas = tostring(((bundledQualityEntry or bundledItem or {}).craftedQualityPreferredAtlas) or ""),
        liveQualityInfo = current_live_quality_info(itemID),
        resolvedIcon = icon_text(resolvedIcon),
        resolvedQuality = resolvedQuality,
        resolvedMaxQuality = resolvedMaxQuality,
        resolvedDisplayAtlas = resolvedDisplayAtlas,
        hasBundledAuthority = hasBundledAuthority,
        finalDisplayAtlas = tostring(finalDisplayAtlas or ""),
        finalMarkupAtlas = tostring(finalMarkupAtlas or ""),
        finalNonInventoryAtlas = tostring((nonInventoryPresentation or {}).atlas or ""),
        finalNonInventoryMarkupAtlas = tostring((nonInventoryPresentation or {}).markupAtlas or ""),
        finalAtlas = tostring(finalMarkupAtlas or finalDisplayAtlas or ""),
    }
end

function craftedQuality.DescribeItemResolution(itemID, icon, fallbackQuality, maxQuality, style)
    local debugInfo = craftedQuality.DebugItemResolution(itemID, icon, fallbackQuality, maxQuality, style)
    local liveInfo = debugInfo.liveQualityInfo or {}
    local liveSummary = "none"
    if next(liveInfo) ~= nil then
        liveSummary = string.format(
            "quality=%s, inventory=%s, mixed=%s, chat=%s, small=%s",
            tostring(liveInfo.quality or ""),
            tostring(liveInfo.iconInventory or ""),
            tostring(liveInfo.iconMixed or ""),
            tostring(liveInfo.iconChat or ""),
            tostring(liveInfo.iconSmall or "")
        )
    end

    return {
        string.format("Crafted quality debug for %s", tostring(debugInfo.itemID or itemID or "")),
        string.format(
            "bundled quality=%s, max=%s, family=%s",
            tostring(debugInfo.bundledCraftedQuality or 0),
            tostring(debugInfo.bundledCraftedQualityMax or 0),
            tostring(debugInfo.bundledCraftedQualityFamilySize or 0)
        ),
        string.format(
            "bundled display=%s, preferred=%s",
            tostring(debugInfo.bundledCraftedQualityDisplayAtlas or ""),
            tostring(debugInfo.bundledCraftedQualityPreferredAtlas or "")
        ),
        string.format("live reagent info=%s", liveSummary),
        string.format("final atlas=%s", tostring(debugInfo.finalAtlas or "")),
        string.format("final markup atlas=%s", tostring(debugInfo.finalMarkupAtlas or "")),
        string.format("final display atlas=%s", tostring(debugInfo.finalDisplayAtlas or "")),
        string.format("final non-inventory atlas=%s", tostring(debugInfo.finalNonInventoryAtlas or "")),
    }
end

function craftedQuality.ToMarkup(icon, size, style, fallbackQuality, maxQuality)
    local atlasName = craftedQuality.GetMarkupAtlas(icon, fallbackQuality, style, maxQuality)
    if atlasName == "" then
        return ""
    end

    local iconSize = math.max(1, math.floor(tonumber(size or 22) or 22))
    return string.format("|A:%s:%d:%d|a", tostring(atlasName), iconSize, iconSize)
end

function craftedQuality.ToMarkupForItem(itemID, icon, size, style, fallbackQuality, maxQuality)
    local atlasName = craftedQuality.GetMarkupAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    return markup_string_for_atlas(atlasName, size)
end

function craftedQuality.DisplayMarkup(icon, size, style, fallbackQuality, maxQuality)
    local atlasName = craftedQuality.GetMarkupAtlas(icon, fallbackQuality, style, maxQuality)
    return markup_string_for_atlas(atlasName, size)
end

function craftedQuality.DisplayMarkupForItem(itemID, icon, size, style, fallbackQuality, maxQuality)
    local atlasName = craftedQuality.GetMarkupAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    return markup_string_for_atlas(atlasName, size)
end

function craftedQuality.DisplayNonInventoryMarkupForItem(itemID, icon, size, style, fallbackQuality, maxQuality)
    local atlasName = craftedQuality.GetNonInventoryMarkupAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    return markup_string_for_atlas(atlasName, size)
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
