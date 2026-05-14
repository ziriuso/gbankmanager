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
        exportReadyCount = exportReadyCount + 1
        totalPurchaseQuantity = totalPurchaseQuantity + (row.totalToBuy or 0)
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

    local topItems = {}
    for _, item in pairs(withdrawals) do
        table.insert(topItems, item)
    end

    table.sort(topItems, function(left, right)
        if left.quantity == right.quantity then
            return left.itemName < right.itemName
        end
        return left.quantity > right.quantity
    end)

    local ranked = {}
    for index = 1, math.min(5, #topItems) do
        table.insert(ranked, string.format("%d. %s x%d", index, topItems[index].itemName, topItems[index].quantity))
    end

    if #ranked == 0 then
        table.insert(ranked, "No withdrawal data yet.")
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
