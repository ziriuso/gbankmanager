local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local planning = ns.modules.planning or {}

local function ensure_row(plan, itemID, itemName)
    if plan[itemID] == nil then
        plan[itemID] = {
            itemID = itemID,
            itemName = itemName,
            totalToBuy = 0,
            sources = {
                RESTOCK = 0,
                ONE_TIME_TARGET = 0,
                REQUEST = 0,
            },
        }
    end

    return plan[itemID]
end

local function current_count(snapshot, itemID)
    local item = snapshot.items[itemID]
    if item == nil then
        return 0
    end

    return item.totalCount or 0
end

function planning.BuildDemandPlan(input)
    input = input or {}

    local plan = {}
    local snapshot = input.snapshot or {}
    snapshot.items = snapshot.items or {}

    for _, minimum in ipairs(input.minimums or {}) do
        local shortage = math.max(0, (minimum.quantity or 0) - current_count(snapshot, minimum.itemID))
        local row = ensure_row(plan, minimum.itemID, minimum.itemName)
        row.sources.RESTOCK = row.sources.RESTOCK + shortage
        row.totalToBuy = row.totalToBuy + shortage
    end

    for _, target in ipairs(input.oneTimeTargets or {}) do
        if target.status == "OPEN" then
            local shortage = math.max(0, (target.quantity or 0) - current_count(snapshot, target.itemID))
            local row = ensure_row(plan, target.itemID, target.itemName)
            row.sources.ONE_TIME_TARGET = row.sources.ONE_TIME_TARGET + shortage
            row.totalToBuy = row.totalToBuy + shortage
        end
    end

    for _, request in ipairs(input.requests or {}) do
        if request.approval == "APPROVED" and request.fulfillment == "OPEN" then
            local row = ensure_row(plan, request.itemID, request.itemName)
            row.sources.REQUEST = row.sources.REQUEST + (request.quantity or 0)
            row.totalToBuy = row.totalToBuy + (request.quantity or 0)
        end
    end

    return plan
end

ns.modules.planning = planning

return planning
