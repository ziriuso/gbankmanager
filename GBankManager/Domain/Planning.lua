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
            details = {},
        }
    end

    return plan[itemID]
end

local function current_total(snapshot, itemID)
    local item = snapshot.items[itemID]
    if item == nil then
        return 0
    end

    return item.totalCount or 0
end

local function current_scope_count(snapshot, itemID, rule)
    if rule.scope ~= "TAB" then
        return current_total(snapshot, itemID)
    end

    local item = snapshot.items[itemID]
    if item == nil then
        return 0
    end

    local tabs = item.tabs or {}
    return tabs[rule.tabName] or 0
end

local function current_snapshot_from_db(db)
    db = db or {}
    local snapshots = db.snapshots or {}

    if db.currentSnapshotId ~= nil then
        return snapshots[db.currentSnapshotId] or { items = {} }
    end

    return { items = {} }
end

local function add_detail(row, source, amount, input)
    if amount <= 0 then
        return
    end

    table.insert(row.details, {
        source = source,
        quantity = amount,
        scope = input.scope or "GLOBAL",
        tabName = input.tabName,
        note = input.note,
    })
end

function planning.BuildDemandPlan(input)
    input = input or {}

    local plan = {}
    local snapshot = input.snapshot or {}
    snapshot.items = snapshot.items or {}

    for _, minimum in ipairs(input.minimums or {}) do
        if minimum.enabled ~= false then
            local shortage = math.max(0, (minimum.quantity or 0) - current_scope_count(snapshot, minimum.itemID, minimum))
            local row = ensure_row(plan, minimum.itemID, minimum.itemName)
            row.sources.RESTOCK = row.sources.RESTOCK + shortage
            row.totalToBuy = row.totalToBuy + shortage
            add_detail(row, "RESTOCK", shortage, minimum)
        end
    end

    for _, target in ipairs(input.oneTimeTargets or {}) do
        if target.status == "OPEN" then
            local shortage = math.max(0, (target.quantity or 0) - current_scope_count(snapshot, target.itemID, target))
            local row = ensure_row(plan, target.itemID, target.itemName)
            row.sources.ONE_TIME_TARGET = row.sources.ONE_TIME_TARGET + shortage
            row.totalToBuy = row.totalToBuy + shortage
            add_detail(row, "ONE_TIME_TARGET", shortage, target)
        end
    end

    for _, request in ipairs(input.requests or {}) do
        if request.approval == "APPROVED" and request.fulfillment == "OPEN" and request.minimumRuleKey == nil then
            local row = ensure_row(plan, request.itemID, request.itemName)
            row.sources.REQUEST = row.sources.REQUEST + (request.quantity or 0)
            row.totalToBuy = row.totalToBuy + (request.quantity or 0)
            add_detail(row, "REQUEST", request.quantity or 0, request)
        end
    end

    return plan
end

function planning.BuildDemandPlanFromDatabase(db)
    db = db or {}
    local snapshot = current_snapshot_from_db(db)
    local plan = planning.BuildDemandPlan({
        snapshot = snapshot,
        minimums = db.minimums or {},
        oneTimeTargets = db.oneTimeTargets or {},
        requests = db.requests or {},
    })

    return plan, snapshot
end

ns.modules.planning = planning

return planning
