local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local targetsView = ns.modules.targetsView or {}

function targetsView.MarkSuggestedFulfilled(target, currentCount)
    target = target or {}

    if (currentCount or 0) >= (target.quantity or 0) then
        target.status = "SUGGESTED_FULFILLED"
    end

    return target
end

ns.modules.targetsView = targetsView

return targetsView
