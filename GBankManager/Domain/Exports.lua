local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports or {}

local function render_field(row, field)
    return tostring(row[field] or "")
end

function exports.BuildDelimited(rows, template)
    local lines = {}
    template = template or {}

    if template.includeHeader then
        table.insert(lines, table.concat(template.fields or {}, template.delimiter or ","))
    end

    for _, row in ipairs(rows or {}) do
        local values = {}
        for _, field in ipairs(template.fields or {}) do
            table.insert(values, render_field(row, field))
        end
        table.insert(lines, table.concat(values, template.delimiter or ","))
    end

    return table.concat(lines, "\n")
end

function exports.BuildAuctionator(rows, shoppingListName)
    local values = {}

    shoppingListName = tostring(shoppingListName or "GBankManager")
    rows = type(rows) == "table" and rows or {}

    for _, row in ipairs(rows) do
        local itemName = tostring(row.itemName or "")
        local totalToBuy = tonumber(row.totalToBuy or 0) or 0
        local quality = math.max(0, math.floor(tonumber(row.quality or row.craftedQuality or 0) or 0))

        if itemName ~= "" and totalToBuy > 0 then
            table.insert(values, string.format('"%s";0;0;0;0;0;0;0;%d;%d', itemName, quality, totalToBuy))
        end
    end

    return shoppingListName .. "^" .. table.concat(values, "^")
end

local function current_total(snapshot, itemID)
    local item = snapshot and snapshot.items and snapshot.items[itemID]
    if item == nil then
        return 0
    end

    return item.totalCount or 0
end

local function summarize_scopes(details)
    local scopes = {}
    local seen = {}

    for _, detail in ipairs(details or {}) do
        local label = detail.scope or "GLOBAL"
        if detail.scope == "TAB" and detail.tabName and detail.tabName ~= "" then
            label = detail.tabName
        end

        if not seen[label] then
            seen[label] = true
            table.insert(scopes, label)
        end
    end

    table.sort(scopes)
    return #scopes > 0 and table.concat(scopes, "|") or "GLOBAL"
end

local function quality_for_item(db, snapshot, itemID)
    db = db or {}
    snapshot = snapshot or { items = {} }

    local snapshotItem = snapshot.items and snapshot.items[itemID]
    if snapshotItem then
        local snapshotQuality = tonumber(snapshotItem.craftedQuality or 0) or 0
        if snapshotQuality > 0 then
            return snapshotQuality
        end
    end

    for _, source in ipairs({
        db.minimums,
        db.oneTimeTargets,
        db.requests,
    }) do
        for _, entry in ipairs(source or {}) do
            if entry.itemID == itemID then
                local quality = tonumber(entry.quality or entry.craftedQuality or 0) or 0
                if quality > 0 then
                    return quality
                end
            end
        end
    end

    return 0
end

function exports.MaterializePlanRows(plan, snapshot)
    local rows = {}
    snapshot = snapshot or { items = {} }

    for _, row in pairs(plan or {}) do
        if (row.totalToBuy or 0) > 0 then
            local currentItem = snapshot.items and snapshot.items[row.itemID]
            local reasons = {}

            for reason, quantity in pairs(row.sources or {}) do
                if quantity > 0 then
                    table.insert(reasons, string.format("%s:%d", reason, quantity))
                end
            end

            table.sort(reasons)
            table.insert(rows, {
                itemID = row.itemID,
                itemName = row.itemName,
                currentQuantity = current_total(snapshot, row.itemID),
                restockQuantity = (row.sources and row.sources.RESTOCK) or 0,
                targetQuantity = (row.sources and row.sources.ONE_TIME_TARGET) or 0,
                requestQuantity = (row.sources and row.sources.REQUEST) or 0,
                totalToBuy = row.totalToBuy,
                quality = tonumber(row.quality or row.craftedQuality or (currentItem and currentItem.craftedQuality) or 0) or 0,
                scopeSummary = summarize_scopes(row.details or {}),
                reason = table.concat(reasons, "|"),
            })
        end
    end

    table.sort(rows, function(left, right)
        return tostring(left.itemName) < tostring(right.itemName)
    end)

    return rows
end

function exports.BuildRowsFromDatabase(db)
    db = db or {}

    local planning = ns.modules.planning
    if planning == nil and type(_G.dofile) == "function" then
        planning = _G.dofile("GBankManager/Domain/Planning.lua")
    end

    local demandPlan = {}
    local snapshot = { items = {} }

    if planning and type(planning.BuildDemandPlanFromDatabase) == "function" then
        demandPlan, snapshot = planning.BuildDemandPlanFromDatabase(db)
    end

    local rows = exports.MaterializePlanRows(demandPlan, snapshot)

    for _, row in ipairs(rows) do
        if (tonumber(row.quality or 0) or 0) <= 0 then
            row.quality = quality_for_item(db, snapshot, row.itemID)
        end
    end

    return rows, snapshot
end

ns.modules.exports = exports

return exports
