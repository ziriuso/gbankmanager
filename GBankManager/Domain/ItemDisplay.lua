local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local itemDisplay = ns.modules.itemDisplay or {}

local function current_item_catalog()
    return ns.modules.itemCatalog or {}
end

local function normalize_item_name(item)
    local itemCatalog = current_item_catalog()
    local rawName = (item or {}).name or (item or {}).itemName or "Unknown"
    if type(itemCatalog.StripLegacyTierPrefix) == "function" then
        return itemCatalog.StripLegacyTierPrefix(rawName)
    end

    return tostring(rawName or "")
end

function itemDisplay.BuildDisplayPayload(item)
    item = type(item) == "table" and item or {}

    local plainTextName = normalize_item_name(item)
    local itemLink = tostring(item.itemLink or "")
    local itemString = tostring(item.itemString or "")
    local visibleText = itemLink
    local tierValue = tonumber(item.craftedQuality or item.qualityTier or 0) or 0

    if visibleText == "" then
        visibleText = plainTextName
    end

    return {
        visibleText = visibleText,
        plainTextName = plainTextName,
        tierValue = tierValue,
        itemID = tonumber(item.itemID),
        itemLink = itemLink ~= "" and itemLink or nil,
        itemString = itemString ~= "" and itemString or nil,
    }
end

ns.modules.itemDisplay = itemDisplay

return itemDisplay
