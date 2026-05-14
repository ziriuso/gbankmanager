local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local snapshots = ns.modules.snapshots or {}

local function item_name(slot)
    return slot.name or slot.itemName or slot.itemLink
end

local function normalize_utc_timestamp(value)
    local numeric = tonumber(value)
    if numeric ~= nil then
        return numeric
    end

    return _G.time()
end

function snapshots.FromTabScan(raw)
    raw = raw or {}

    local items = {}

    for _, tab in ipairs(raw.scannedTabs or {}) do
        local tabName = tab.name or tostring(tab.index or "Unknown")

        for _, slot in ipairs(tab.slots or {}) do
            local itemID = slot.itemID or slot.itemId
            local count = slot.count or slot.quantity or 0

            if itemID ~= nil and count > 0 then
                local entry = items[itemID] or {
                    itemID = itemID,
                    name = item_name(slot),
                    quality = slot.quality,
                    craftedQuality = slot.craftedQuality,
                    craftedQualityIcon = slot.craftedQualityIcon,
                    totalCount = 0,
                    tabs = {},
                }

                entry.totalCount = entry.totalCount + count
                entry.quality = entry.quality or slot.quality
                entry.craftedQuality = entry.craftedQuality or slot.craftedQuality
                entry.craftedQualityIcon = entry.craftedQualityIcon or slot.craftedQualityIcon
                entry.tabs[tabName] = (entry.tabs[tabName] or 0) + count
                items[itemID] = entry
            end
        end
    end

    return {
        scanId = raw.scanId,
        guildName = raw.guildName,
        actor = raw.actor,
        scannedTabs = raw.scannedTabs or {},
        scannedAt = normalize_utc_timestamp(raw.scannedAt),
        items = items,
    }
end

ns.modules.snapshots = snapshots

return snapshots
