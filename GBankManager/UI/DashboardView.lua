local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local dashboard = ns.modules.dashboardView or {}

local function normalize_timestamp(timestamp)
    local numeric = tonumber(timestamp)
    if numeric ~= nil then
        return numeric
    end

    return 0
end

local function abbreviate_timezone_name(displayText)
    local prefix, timezoneName = string.match(tostring(displayText or ""), "^(.-)([A-Za-z][A-Za-z%s]+)$")
    if not timezoneName or string.find(timezoneName, " ", 1, true) == nil then
        return tostring(displayText or "")
    end

    local known = {
        ["Eastern Daylight Time"] = "EDT",
        ["Eastern Standard Time"] = "EST",
        ["Central Daylight Time"] = "CDT",
        ["Central Standard Time"] = "CST",
        ["Mountain Daylight Time"] = "MDT",
        ["Mountain Standard Time"] = "MST",
        ["Pacific Daylight Time"] = "PDT",
        ["Pacific Standard Time"] = "PST",
        ["Greenwich Mean Time"] = "GMT",
        ["Coordinated Universal Time"] = "UTC",
    }

    local abbreviation = known[timezoneName]
    if not abbreviation then
        abbreviation = timezoneName:gsub("(%a)[%a']*", "%1"):gsub("%s+", ""):upper()
    end

    return string.format("%s%s", prefix or "", abbreviation)
end

local function format_timestamp(timestamp)
    timestamp = normalize_timestamp(timestamp)
    if timestamp == 0 then
        return "No scan yet"
    end

    local formatter = _G.date or os.date
    if type(formatter) == "function" then
        return abbreviate_timezone_name(formatter("%Y-%m-%d %H:%M %Z", timestamp))
    end

    return tostring(timestamp)
end

local function current_count_for_rule(snapshotItem, rule)
    if type(snapshotItem) ~= "table" then
        return 0
    end

    local tabName = tostring((rule or {}).tabName or "")
    if tabName ~= "" then
        return tonumber(((snapshotItem.tabs or {})[tabName]) or 0) or 0
    end

    return tonumber(snapshotItem.totalCount or 0) or 0
end

local function sorted_snapshots(db)
    local ordered = {}

    for scanId, snapshot in pairs((db or {}).snapshots or {}) do
        if type(snapshot) == "table" then
            snapshot.scanId = snapshot.scanId or scanId
            table.insert(ordered, snapshot)
        end
    end

    table.sort(ordered, function(left, right)
        local leftAt = normalize_timestamp(left.scannedAt)
        local rightAt = normalize_timestamp(right.scannedAt)
        if leftAt == rightAt then
            return tostring(left.scanId or "") < tostring(right.scanId or "")
        end
        return leftAt < rightAt
    end)

    return ordered
end

local function build_stocking_history_rankings(db)
    local rankingsByItem = {}
    local snapshots = sorted_snapshots(db)
    if #snapshots == 0 then
        return {}
    end

    for _, rule in ipairs((db or {}).minimums or {}) do
        local itemID = tonumber((rule or {}).itemID)
        local minimumQuantity = tonumber((rule or {}).quantity or 0) or 0
        if itemID and minimumQuantity > 0 and rule.enabled ~= false then
            local itemKey = tostring(itemID)
            local metric = rankingsByItem[itemKey] or {
                itemID = itemID,
                itemName = tostring(rule.itemName or ("Item " .. itemKey)),
                restockCount = 0,
                totalShortage = 0,
                maxShortage = 0,
                lastShortageAt = 0,
            }

            local episodeMaxShortage = 0
            local episodeLastAt = 0
            local inShortage = false

            for _, snapshot in ipairs(snapshots) do
                local snapshotItem = ((snapshot or {}).items or {})[itemID]
                local shortage = math.max(0, minimumQuantity - current_count_for_rule(snapshotItem, rule))
                if shortage > 0 then
                    inShortage = true
                    episodeMaxShortage = math.max(episodeMaxShortage, shortage)
                    episodeLastAt = math.max(episodeLastAt, normalize_timestamp(snapshot.scannedAt))
                    if metric.itemName == "" and snapshotItem and snapshotItem.name then
                        metric.itemName = tostring(snapshotItem.name)
                    end
                elseif inShortage then
                    metric.restockCount = metric.restockCount + 1
                    metric.totalShortage = metric.totalShortage + episodeMaxShortage
                    metric.maxShortage = math.max(metric.maxShortage, episodeMaxShortage)
                    metric.lastShortageAt = math.max(metric.lastShortageAt, episodeLastAt)
                    inShortage = false
                    episodeMaxShortage = 0
                    episodeLastAt = 0
                end
            end

            if inShortage then
                metric.restockCount = metric.restockCount + 1
                metric.totalShortage = metric.totalShortage + episodeMaxShortage
                metric.maxShortage = math.max(metric.maxShortage, episodeMaxShortage)
                metric.lastShortageAt = math.max(metric.lastShortageAt, episodeLastAt)
            end

            if metric.restockCount > 0 then
                rankingsByItem[itemKey] = metric
            end
        end
    end

    local ranked = {}
    for _, metric in pairs(rankingsByItem) do
        table.insert(ranked, metric)
    end

    table.sort(ranked, function(left, right)
        if left.restockCount ~= right.restockCount then
            return left.restockCount > right.restockCount
        end
        if left.totalShortage ~= right.totalShortage then
            return left.totalShortage > right.totalShortage
        end
        if left.lastShortageAt ~= right.lastShortageAt then
            return left.lastShortageAt > right.lastShortageAt
        end
        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    return ranked
end

local function build_withdrawal_rankings(db)
    local withdrawals = {}

    for _, entry in ipairs((db or {}).changeLog or {}) do
        if entry.type == "QUANTITY_DECREASED" or entry.type == "ITEM_REMOVED" then
            local key = tostring(entry.name or "Unknown")
            local current = withdrawals[key] or {
                itemName = key,
                quantity = 0,
            }
            current.quantity = current.quantity + tonumber(entry.delta or 0)
            withdrawals[key] = current
        end
    end

    local ranked = {}
    for _, item in pairs(withdrawals) do
        table.insert(ranked, item)
    end

    table.sort(ranked, function(left, right)
        if left.quantity == right.quantity then
            return left.itemName < right.itemName
        end
        return left.quantity > right.quantity
    end)

    return ranked
end

function dashboard.BuildSummary(db, planRows)
    db = db or {}
    db.meta = db.meta or {}

    local pending = 0
    local suggested = 0
    for _, request in ipairs(db.requests or {}) do
        if request.approval == "PENDING" then
            pending = pending + 1
        end

        if request.fulfillment == "SUGGESTED_FULFILLED" then
            suggested = suggested + 1
        end
    end

    local exportReadyCount = 0
    local totalPurchaseQuantity = 0
    for _, row in pairs(planRows or {}) do
        local totalToBuy = tonumber((row or {}).totalToBuy or 0) or 0
        if totalToBuy > 0 then
            exportReadyCount = exportReadyCount + 1
            totalPurchaseQuantity = totalPurchaseQuantity + totalToBuy
        end
    end

    return {
        lastScanAt = db.meta.updatedAt or 0,
        pendingRequestCount = pending,
        suggestedFulfillmentCount = suggested,
        exportReadyCount = exportReadyCount,
        totalPurchaseQuantity = totalPurchaseQuantity,
    }
end

function dashboard.BuildLines(db, planRows)
    local summary = dashboard.BuildSummary(db, planRows)

    return {
        string.format("Last scan: %s", format_timestamp(summary.lastScanAt)),
        string.format("Pending requests: %d", summary.pendingRequestCount),
        string.format("Suggested fulfillments: %d", summary.suggestedFulfillmentCount),
        string.format("Export rows ready: %d", summary.exportReadyCount),
        string.format("Total purchase quantity: %d", summary.totalPurchaseQuantity),
    }
end

function dashboard.BuildCards(db, planRows)
    local summary = dashboard.BuildSummary(db, planRows)
    local topItems = build_stocking_history_rankings(db)
    local usesStockingHistory = #topItems > 0
    if not usesStockingHistory then
        topItems = build_withdrawal_rankings(db)
    end

    local ranked = {}
    for index = 1, math.min(5, #topItems) do
        if usesStockingHistory then
            local item = topItems[index]
            local restockLabel = item.restockCount == 1 and "restock" or "restocks"
            table.insert(ranked, string.format("%d. %s - %d %s", index, item.itemName, item.restockCount, restockLabel))
        else
            table.insert(ranked, string.format("%d. %s x%d", index, topItems[index].itemName, topItems[index].quantity))
        end
    end

    if #ranked == 0 then
        table.insert(ranked, "No stocking history yet.")
    end

    local snapshot = nil
    if db and db.currentSnapshotId then
        snapshot = (db.snapshots or {})[db.currentSnapshotId]
    end

    local trackedItems = 0
    for _ in pairs((snapshot or {}).items or {}) do
        trackedItems = trackedItems + 1
    end

    return {
        {
            title = "Last Scan",
            value = format_timestamp(summary.lastScanAt),
            note = string.format("%d tracked items", trackedItems),
        },
        {
            title = "Pending Requests",
            value = tostring(summary.pendingRequestCount),
            note = string.format("%d suggested fulfillments", summary.suggestedFulfillmentCount),
        },
        {
            title = "Ready To Buy",
            value = tostring(summary.totalPurchaseQuantity),
            note = string.format("%d export rows", summary.exportReadyCount),
        },
        {
            title = "Top 5 Most Used",
            lines = ranked,
        },
    }
end

ns.modules.dashboardView = dashboard

return dashboard
