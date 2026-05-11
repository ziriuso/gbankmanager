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

function exports.BuildAuctionator(rows)
    local values = {}

    for _, row in ipairs(rows or {}) do
        table.insert(values, string.format("%s x%d", row.itemName, row.totalToBuy))
    end

    return table.concat(values, "; ")
end

function exports.MaterializePlanRows(plan)
    local rows = {}

    for _, row in pairs(plan or {}) do
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
            totalToBuy = row.totalToBuy,
            reason = table.concat(reasons, "|"),
        })
    end

    table.sort(rows, function(left, right)
        return tostring(left.itemName) < tostring(right.itemName)
    end)

    return rows
end

ns.modules.exports = exports

return exports
