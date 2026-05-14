local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local diff = ns.modules.diff or {}

function diff.BuildChangeLog(previous, current)
    previous = previous or {}
    current = current or {}
    previous.items = previous.items or {}
    current.items = current.items or {}

    local changes = {}
    local visited = {}

    for itemID, currentEntry in pairs(current.items) do
        local previousEntry = previous.items[itemID]
        visited[itemID] = true

        if previousEntry == nil then
            table.insert(changes, {
                type = "ITEM_ADDED",
                itemID = itemID,
                name = currentEntry.name,
                delta = currentEntry.totalCount,
            })
        elseif currentEntry.totalCount > previousEntry.totalCount then
            table.insert(changes, {
                type = "QUANTITY_INCREASED",
                itemID = itemID,
                name = currentEntry.name,
                delta = currentEntry.totalCount - previousEntry.totalCount,
            })
        elseif currentEntry.totalCount < previousEntry.totalCount then
            table.insert(changes, {
                type = "QUANTITY_DECREASED",
                itemID = itemID,
                name = currentEntry.name,
                delta = previousEntry.totalCount - currentEntry.totalCount,
            })
        end
    end

    for itemID, previousEntry in pairs(previous.items) do
        if not visited[itemID] then
            table.insert(changes, {
                type = "ITEM_REMOVED",
                itemID = itemID,
                name = previousEntry.name,
                delta = previousEntry.totalCount,
            })
        end
    end

    table.sort(changes, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return changes
end

ns.modules.diff = diff

return diff
