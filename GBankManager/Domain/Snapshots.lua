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
    local itemRows = {}
    local itemRowsByKey = {}
    local useQuality = not (type(ns.IsForever) == "function" and ns.IsForever())

    for _, tab in ipairs(raw.scannedTabs or {}) do
        local tabName = tab.name or tostring(tab.index or "Unknown")

        for _, slot in ipairs(tab.slots or {}) do
            local itemID = slot.itemID or slot.itemId
            local count = slot.count or slot.quantity or 0
            local quality = useQuality and slot.quality or nil
            local craftedQuality = useQuality and slot.craftedQuality or nil
            local craftedQualityIcon = useQuality and slot.craftedQualityIcon or nil

            if itemID ~= nil and count > 0 then
                local entry = items[itemID] or {
                    itemID = itemID,
                    name = item_name(slot),
                    quality = quality,
                    craftedQuality = craftedQuality,
                    craftedQualityIcon = craftedQualityIcon,
                    totalCount = 0,
                    tabs = {},
                }

                entry.totalCount = entry.totalCount + count
                entry.quality = entry.quality or quality
                entry.craftedQuality = entry.craftedQuality or craftedQuality
                entry.craftedQualityIcon = entry.craftedQualityIcon or craftedQualityIcon
                entry.tabs[tabName] = (entry.tabs[tabName] or 0) + count
                items[itemID] = entry

                local rowKey = table.concat({ tostring(itemID), "TAB", tostring(tabName) }, "|")
                local itemRow = itemRowsByKey[rowKey]
                if itemRow == nil then
                    itemRow = {
                        rowKey = rowKey,
                        itemID = itemID,
                        name = item_name(slot),
                        quality = quality,
                        craftedQuality = craftedQuality,
                        craftedQualityIcon = craftedQualityIcon,
                        tabName = tabName,
                        quantity = 0,
                    }
                    itemRowsByKey[rowKey] = itemRow
                    table.insert(itemRows, itemRow)
                end

                itemRow.quantity = itemRow.quantity + count
                itemRow.quality = itemRow.quality or quality
                itemRow.craftedQuality = itemRow.craftedQuality or craftedQuality
                itemRow.craftedQualityIcon = itemRow.craftedQualityIcon or craftedQualityIcon
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
        itemRows = itemRows,
    }
end

ns.modules.snapshots = snapshots

return snapshots
