local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local minimumsSync = ns.modules.minimumsSync or {}

local function clone_record(record)
    local copy = {}
    for key, value in pairs(record or {}) do
        copy[key] = value
    end
    return copy
end

function minimumsSync.RuleKey(record)
    record = type(record) == "table" and record or {}
    local itemID = tostring(tonumber(record.itemID or record.originalItemID or 0) or 0)
    local scope = tostring(record.scope or record.originalScope or "GLOBAL")
    local tabName = tostring(record.tabName or record.originalTabName or "")
    return table.concat({ itemID, scope, tabName }, "|")
end

local function valid_rule_key(key)
    return type(key) == "string" and key ~= "" and not string.find(key, "^0|")
end

local function rule_updated_at(rule)
    rule = type(rule) == "table" and rule or {}
    return tonumber(rule.updatedAt or rule.createdAt or 0) or 0
end

local function normalize_tombstone(tombstone, fallbackKey)
    tombstone = type(tombstone) == "table" and tombstone or {}
    local normalized = clone_record(tombstone)
    local key = tostring(normalized.ruleKey or fallbackKey or minimumsSync.RuleKey(normalized))
    if not valid_rule_key(key) then
        return nil, nil
    end

    normalized.ruleKey = key
    normalized.deletedAt = tonumber(normalized.deletedAt or normalized.updatedAt or 0) or 0
    normalized.updatedAt = nil
    return key, normalized
end

local function tombstones_to_map(records)
    local out = {}
    for key, tombstone in pairs(type(records) == "table" and records or {}) do
        local normalizedKey, normalized = normalize_tombstone(tombstone, type(key) == "string" and key or nil)
        if normalizedKey and (out[normalizedKey] == nil or normalized.deletedAt >= out[normalizedKey].deletedAt) then
            out[normalizedKey] = normalized
        end
    end
    return out
end

function minimumsSync.EnsureTombstones(db)
    db = type(db) == "table" and db or {}
    db.minimumTombstones = tombstones_to_map(db.minimumTombstones)
    return db.minimumTombstones
end

function minimumsSync.RecordDeletion(db, rule, metadata)
    db = type(db) == "table" and db or {}
    rule = type(rule) == "table" and rule or {}
    metadata = type(metadata) == "table" and metadata or {}
    local key = minimumsSync.RuleKey(rule)
    if not valid_rule_key(key) then
        return nil
    end

    local tombstones = minimumsSync.EnsureTombstones(db)
    local deletedAt = math.max(
        tonumber(metadata.timestamp or 0) or 0,
        rule_updated_at(rule)
    )
    local previous = tombstones[key]
    if previous and tonumber(previous.deletedAt or 0) > deletedAt then
        return previous
    end

    local tombstone = {
        ruleKey = key,
        itemID = tonumber(rule.itemID),
        itemName = tostring(rule.itemName or "Unknown"),
        scope = tostring(rule.scope or "GLOBAL"),
        tabName = rule.tabName,
        deletedAt = deletedAt,
        deletedBy = tostring(metadata.actorCharacterKey or metadata.actor or "Unknown"),
        deletedByRankIndex = metadata.actorRankIndex,
    }
    tombstones[key] = tombstone
    return tombstone
end

function minimumsSync.ClearDeletion(db, rule)
    local tombstones = minimumsSync.EnsureTombstones(db)
    local key = minimumsSync.RuleKey(rule)
    local previous = tombstones[key]
    tombstones[key] = nil
    return previous
end

function minimumsSync.BuildTombstoneSnapshot(dbOrRecords)
    local records = dbOrRecords
    if type(dbOrRecords) == "table"
        and (dbOrRecords.minimumTombstones ~= nil or dbOrRecords.minimums ~= nil or dbOrRecords.meta ~= nil) then
        records = minimumsSync.EnsureTombstones(dbOrRecords)
    end

    local tombstones = tombstones_to_map(records)
    local keys = {}
    for key in pairs(tombstones) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local out = {}
    for _, key in ipairs(keys) do
        out[#out + 1] = clone_record(tombstones[key])
    end
    return out
end

local function state_for_snapshot(rows, tombstones)
    local state = {}
    local order = {}
    local seen = {}

    local function remember_key(key)
        if not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end

    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        if type(row) == "table" then
            local key = minimumsSync.RuleKey(row)
            if valid_rule_key(key) then
                remember_key(key)
                local updatedAt = rule_updated_at(row)
                local current = state[key]
                if current == nil or updatedAt >= current.updatedAt then
                    state[key] = {
                        kind = "rule",
                        updatedAt = updatedAt,
                        record = clone_record(row),
                    }
                end
            end
        end
    end

    local normalizedTombstones = tombstones_to_map(tombstones)
    local tombstoneKeys = {}
    for key in pairs(normalizedTombstones) do
        tombstoneKeys[#tombstoneKeys + 1] = key
    end
    table.sort(tombstoneKeys)
    for _, key in ipairs(tombstoneKeys) do
        remember_key(key)
        local tombstone = normalizedTombstones[key]
        local deletedAt = tonumber(tombstone.deletedAt or 0) or 0
        local current = state[key]
        if current == nil or deletedAt >= current.updatedAt then
            state[key] = {
                kind = "tombstone",
                updatedAt = deletedAt,
                record = clone_record(tombstone),
            }
        end
    end

    return state, order
end

local function choose_state(localState, incomingState)
    if localState == nil then
        return incomingState, false
    end
    if incomingState == nil then
        return localState, true
    end
    if localState.updatedAt > incomingState.updatedAt then
        return localState, true
    end
    if incomingState.updatedAt > localState.updatedAt then
        return incomingState, false
    end
    if localState.kind == "tombstone" and incomingState.kind ~= "tombstone" then
        return localState, true
    end
    return incomingState, false
end

function minimumsSync.MergeSnapshot(localRows, localTombstones, incomingRows, incomingTombstones)
    local localState, localOrder = state_for_snapshot(localRows, localTombstones)
    local incomingState, incomingOrder = state_for_snapshot(incomingRows, incomingTombstones)
    local orderedKeys = {}
    local seen = {}
    for _, source in ipairs({ incomingOrder, localOrder }) do
        for _, key in ipairs(source) do
            if not seen[key] then
                seen[key] = true
                orderedKeys[#orderedKeys + 1] = key
            end
        end
    end

    local mergedRows = {}
    local mergedTombstones = {}
    local shouldReply = false
    for _, key in ipairs(orderedKeys) do
        local winner, localWon = choose_state(localState[key], incomingState[key])
        shouldReply = shouldReply or localWon
        if winner then
            if winner.kind == "tombstone" then
                mergedTombstones[key] = clone_record(winner.record)
            else
                mergedRows[#mergedRows + 1] = clone_record(winner.record)
            end
        end
    end

    return mergedRows, mergedTombstones, shouldReply
end

function minimumsSync.TombstonesEqual(left, right)
    left = tombstones_to_map(left)
    right = tombstones_to_map(right)
    for key, tombstone in pairs(left) do
        local other = right[key]
        if other == nil
            or tonumber(other.deletedAt or 0) ~= tonumber(tombstone.deletedAt or 0)
            or tostring(other.deletedBy or "") ~= tostring(tombstone.deletedBy or "") then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end

ns.modules.minimumsSync = minimumsSync

return minimumsSync
