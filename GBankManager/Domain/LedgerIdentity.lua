local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local identity = {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stable_join(parts)
    local out = {}
    for index, value in ipairs(parts or {}) do
        out[index] = trim(value):gsub("|", "/")
    end
    return table.concat(out, "|")
end

function identity.HourSlotFromTimestamp(timestamp)
    return math.floor((tonumber(timestamp or 0) or 0) / 3600)
end

function identity.ItemBase(row)
    row = type(row) == "table" and row or {}
    return stable_join({
        "item",
        row.action or row.type,
        row.who,
        tonumber(row.itemID or 0) or 0,
        tonumber(row.quantity or row.count or 0) or 0,
        row.tabName or row.sourceTabName or ("Tab " .. tostring(row.tabIndex or row.sourceTabIndex or 0)),
        row.fromTabName or "-",
        identity.HourSlotFromTimestamp(row.timestamp or row.when),
    })
end

function identity.MoneyBase(row)
    row = type(row) == "table" and row or {}
    return stable_join({
        "money",
        row.action or row.type,
        row.who,
        tonumber(row.amountCopper or row.amount or 0) or 0,
        identity.HourSlotFromTimestamp(row.timestamp or row.when),
    })
end

function identity.WithOccurrence(base, occurrence)
    return tostring(base or "") .. ":" .. tostring(tonumber(occurrence or 0) or 0)
end

function identity.CountRowsByBase(rows, baseBuilder)
    local counts = {}
    local groups = {}
    local order = {}
    for _, row in ipairs(rows or {}) do
        local base = tostring(baseBuilder(row) or "")
        if base ~= "" then
            if counts[base] == nil then
                counts[base] = 0
                groups[base] = {}
                order[#order + 1] = base
            end
            counts[base] = counts[base] + 1
            groups[base][#groups[base] + 1] = row
        end
    end
    return counts, groups, order
end

ns.modules.ledgerIdentity = identity
return identity
