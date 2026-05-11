local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsView = ns.modules.minimumsView or {}

function minimumsView.Upsert(list, rule)
    list = list or {}
    rule = rule or {}

    local updated = false
    for index, existing in ipairs(list) do
        if existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName then
            list[index] = rule
            updated = true
            break
        end
    end

    if not updated then
        table.insert(list, rule)
    end

    return list
end

ns.modules.minimumsView = minimumsView

return minimumsView
