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

ns.modules.exports = exports

return exports
