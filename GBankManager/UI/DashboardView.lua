local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local dashboard = ns.modules.dashboardView or {}

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
    for _, row in ipairs(planRows or {}) do
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

ns.modules.dashboardView = dashboard

return dashboard
