local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local bankLedger = ns.modules.bankLedger or {}

local RETENTION_WINDOWS = {
    ["1_week"] = 7 * 24 * 60 * 60,
    ["1_month"] = 30 * 24 * 60 * 60,
    ["3_months"] = 90 * 24 * 60 * 60,
    ["6_months"] = 180 * 24 * 60 * 60,
    ["1_year"] = 365 * 24 * 60 * 60,
    indefinite = nil,
}

local SCAN_INTERVAL_OPTIONS = {
    300,
    600,
    900,
    1800,
    3600,
}

local SCAN_INTERVAL_LABELS = {
    [300] = "5 Minutes",
    [600] = "10 Minutes",
    [900] = "15 Minutes",
    [1800] = "30 Minutes",
    [3600] = "1 Hour",
}

local RETENTION_LABELS = {
    ["1_week"] = "1 Week",
    ["1_month"] = "1 Month",
    ["3_months"] = "3 Months",
    ["6_months"] = "6 Months",
    ["1_year"] = "1 Year",
    indefinite = "Indefinite",
}

local ABBREVIATED_TIMEZONES = {
    ["Eastern Daylight Time"] = "EDT",
    ["Eastern Standard Time"] = "EST",
    ["Central Daylight Time"] = "CDT",
    ["Central Standard Time"] = "CST",
    ["Mountain Daylight Time"] = "MDT",
    ["Mountain Standard Time"] = "MST",
    ["Pacific Daylight Time"] = "PDT",
    ["Pacific Standard Time"] = "PST",
    ["Greenwich Mean Time"] = "GMT",
    ["Coordinated Universal Time"] = "UTC",
}

local SESSION_BATCH_COUNTS = setmetatable({}, {
    __mode = "k",
})

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function clamp_percent(value)
    return math.max(0, math.min(100, tonumber(value or 0) or 0))
end

local function server_timestamp_now()
    if type(_G.GetServerTime) == "function" then
        local ok, stamp = pcall(_G.GetServerTime)
        if ok and stamp then
            return tonumber(stamp) or 0
        end
    end

    if type(_G.time) == "function" then
        local ok, stamp = pcall(_G.time)
        if ok and stamp then
            return tonumber(stamp) or 0
        end
    end

    if type(os) == "table" and type(os.time) == "function" then
        local ok, stamp = pcall(os.time)
        if ok and stamp then
            return tonumber(stamp) or 0
        end
    end

    return 0
end

local function timestamp_from_parts(year, month, day, hour, minute, fallback)
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour)
    minute = tonumber(minute)

    if year and year >= 1000 and month and day then
        local dateTable = {
            year = year,
            month = month,
            day = day,
            hour = hour or 0,
            min = minute or 0,
            sec = 0,
            isdst = false,
        }

        if type(_G.time) == "function" then
            local ok, stamp = pcall(_G.time, dateTable)
            if ok and stamp then
                return tonumber(stamp) or tonumber(fallback or 0) or 0
            end
        end

        if type(os) == "table" and type(os.time) == "function" then
            local ok, stamp = pcall(os.time, dateTable)
            if ok and stamp then
                return tonumber(stamp) or tonumber(fallback or 0) or 0
            end
        end
    end

    if year or month or day or hour or minute then
        local now = server_timestamp_now()
        local offset = ((year or 0) * 31536000)
            + ((month or 0) * 2592000)
            + ((day or 0) * 86400)
            + ((hour or 0) * 3600)
            + ((minute or 0) * 60)
        if now > 0 then
            return math.max(0, now - offset)
        end
    end

    return tonumber(fallback or 0) or 0
end

local function raw_time_key(year, month, day, hour, minute)
    local values = {
        trim(year),
        trim(month),
        trim(day),
        trim(hour),
        trim(minute),
    }

    for _, value in ipairs(values) do
        if value ~= "" then
            return table.concat(values, "|")
        end
    end

    return "unknown"
end

local function has_time_parts(year, month, day, hour, minute)
    return year ~= nil or month ~= nil or day ~= nil or hour ~= nil or minute ~= nil
end

local function format_export_timestamp(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    if timestamp <= 0 then
        return "0"
    end

    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) ~= "function" then
        return tostring(timestamp)
    end

    local baseText = formatter("%Y-%m-%d %H:%M", timestamp)
    local zoneText = tostring(formatter("%Z", timestamp) or ""):gsub("^%s+", ""):gsub("%s+$", "")
    zoneText = ABBREVIATED_TIMEZONES[zoneText] or zoneText
    if zoneText ~= "" then
        return string.format("%s %s", tostring(baseText or ""), zoneText)
    end

    return tostring(baseText or timestamp)
end

local function format_copper(amount)
    amount = tonumber(amount or 0) or 0
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100

    if gold > 0 then
        return string.format("%dg %02ds %02dc", gold, silver, copper)
    end
    if silver > 0 then
        return string.format("%ds %02dc", silver, copper)
    end
    return string.format("%dc", copper)
end

local function contains_text(haystack, needle)
    haystack = string.lower(tostring(haystack or ""))
    needle = string.lower(trim(needle))
    if needle == "" then
        return true
    end

    return string.find(haystack, needle, 1, true) ~= nil
end

local function passes_date_range(timestamp, filters)
    filters = filters or {}
    timestamp = tonumber(timestamp or 0) or 0
    local dateFrom = tonumber(filters.dateFrom or 0) or 0
    local dateTo = tonumber(filters.dateTo or 0) or 0

    if dateFrom > 0 and timestamp < dateFrom then
        return false
    end

    if dateTo > 0 and timestamp > dateTo then
        return false
    end

    return true
end

local function make_fingerprint(parts)
    local encoded = {}
    for index, part in ipairs(parts or {}) do
        encoded[index] = tostring(part or "")
    end
    return table.concat(encoded, "|")
end

local function make_occurrence_fingerprint(base, occurrence)
    return make_fingerprint({
        tostring(base or ""),
        tonumber(occurrence or 0) or 0,
    })
end

local function fingerprint_base(fingerprint)
    fingerprint = trim(fingerprint)
    if fingerprint == "" then
        return ""
    end

    return string.match(fingerprint, "^(.*)|%-?%d+$") or fingerprint
end

local function session_batch_counts(ledger)
    if type(ledger) ~= "table" then
        return {
            item = {},
            money = {},
        }
    end

    local counts = SESSION_BATCH_COUNTS[ledger]
    if type(counts) ~= "table" then
        counts = {
            item = {},
            money = {},
        }
        SESSION_BATCH_COUNTS[ledger] = counts
    end

    counts.item = ensure_table(counts.item)
    counts.money = ensure_table(counts.money)
    return counts
end

local function timestamp_time_key(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    if timestamp <= 0 then
        return nil
    end

    local dateProvider = nil
    if type(_G.date) == "function" then
        dateProvider = _G.date
    elseif type(os) == "table" and type(os.date) == "function" then
        dateProvider = os.date
    end

    if not dateProvider then
        return nil
    end

    local ok, dateTable = pcall(dateProvider, "*t", timestamp)
    if not ok or type(dateTable) ~= "table" then
        return nil
    end

    return make_fingerprint({
        tonumber(dateTable.year or 0) or 0,
        tonumber(dateTable.month or 0) or 0,
        tonumber(dateTable.day or 0) or 0,
        tonumber(dateTable.hour or 0) or 0,
        tonumber(dateTable.min or 0) or 0,
    })
end

local function stable_time_key(values, forceUnknownTimeKey)
    values = type(values) == "table" and values or {}
    if forceUnknownTimeKey then
        return "unknown"
    end

    local year = tonumber(values.year)
    local month = tonumber(values.month)
    local day = tonumber(values.day)
    local hour = tonumber(values.hour)
    local minute = tonumber(values.minute)

    if year and year >= 1000 and month and day then
        return raw_time_key(year, month, day, hour, minute)
    end

    local persistedTimeKey = timestamp_time_key(values.timestamp or values.when)
    if persistedTimeKey then
        return persistedTimeKey
    end

    if year or month or day or hour or minute then
        return raw_time_key(year, month, day, hour, minute)
    end

    return "unknown"
end

local function timestamp_hour_key(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    if timestamp <= 0 then
        return nil
    end

    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) ~= "function" then
        return nil
    end

    local dateTable = formatter("*t", timestamp)
    if type(dateTable) ~= "table" then
        return nil
    end

    return raw_time_key(dateTable.year, dateTable.month, dateTable.day, dateTable.hour, nil)
end

local function timestamp_date_key(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    if timestamp <= 0 then
        return nil
    end

    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) ~= "function" then
        return nil
    end

    local dateTable = formatter("*t", timestamp)
    if type(dateTable) ~= "table" then
        return nil
    end

    return raw_time_key(dateTable.year, dateTable.month, dateTable.day, nil, nil)
end

local function item_action_label(rawType)
    rawType = string.lower(trim(rawType))
    if rawType == "deposit" then
        return "Deposit"
    end
    if rawType == "move" or rawType == "moved" then
        return "Moved"
    end

    return "Withdrawal"
end

local function visible_money_action_label(values)
    values = type(values) == "table" and values or {}
    local action = string.lower(trim(values.action))
    if action == "deposit" then
        return "Deposit"
    end
    if action == "repair" then
        return "Repair"
    end
    if action == "withdrawal" or action == "withdraw" then
        return "Withdrawal"
    end

    local rawType = string.lower(trim(values.type or values.rawType))
    if rawType == "deposit" then
        return "Deposit"
    end
    if rawType == "repair" then
        return "Repair"
    end
    if rawType == "withdrawal" or rawType == "withdraw" then
        return "Withdrawal"
    end

    return trim(values.action) ~= "" and trim(values.action) or "Withdrawal"
end

local function money_action_label(rawType, amountCopper, repairThresholdGold)
    rawType = string.lower(trim(rawType))
    amountCopper = tonumber(amountCopper or 0) or 0
    if rawType == "deposit" then
        return "Deposit"
    end

    if rawType == "repair" then
        return "Repair"
    end

    local repairThresholdCopper = math.max(0, tonumber(repairThresholdGold or 0) or 0) * 10000
    if amountCopper > 0 and repairThresholdCopper > 0 and amountCopper <= repairThresholdCopper then
        return "Repair"
    end

    return "Withdrawal"
end

local function money_identity_type(rawType)
    rawType = string.lower(trim(rawType))
    if rawType == "deposit" then
        return "deposit"
    end
    if rawType == "repair" or rawType == "withdrawal" or rawType == "withdraw" then
        return "withdraw"
    end
    if rawType ~= "" then
        return rawType
    end
    return "withdraw"
end

local function money_visible_hour_key(values)
    values = type(values) == "table" and values or {}
    local year = tonumber(values.year)
    local month = tonumber(values.month)
    local day = tonumber(values.day)
    local hour = tonumber(values.hour)

    if year and year >= 1000 and month and day then
        return raw_time_key(year, month, day, hour, nil)
    end

    local persistedTimeKey = timestamp_hour_key(values.timestamp or values.when)
    if persistedTimeKey then
        return persistedTimeKey
    end

    if year or month or day or hour then
        return raw_time_key(year, month, day, hour, nil)
    end

    return "unknown"
end

local function money_visible_date_key(values)
    values = type(values) == "table" and values or {}
    local year = tonumber(values.year)
    local month = tonumber(values.month)
    local day = tonumber(values.day)

    if year and year >= 1000 and month and day then
        return raw_time_key(year, month, day, nil, nil)
    end

    local persistedTimeKey = timestamp_date_key(values.timestamp or values.when)
    if persistedTimeKey then
        return persistedTimeKey
    end

    if year or month or day then
        return raw_time_key(year, month, day, nil, nil)
    end

    return "unknown"
end

local function ensure_settings(db)
    db.ui = ensure_table(db.ui)
    db.ui.logsHistorySettings = ensure_table(db.ui.logsHistorySettings)
    local settings = db.ui.logsHistorySettings
    settings.ledgerRetention = RETENTION_WINDOWS[settings.ledgerRetention] == nil and settings.ledgerRetention == "indefinite" and "indefinite" or settings.ledgerRetention
    if RETENTION_WINDOWS[settings.ledgerRetention] == nil and settings.ledgerRetention ~= "indefinite" then
        settings.ledgerRetention = "indefinite"
    end
    settings.historyRetention = RETENTION_WINDOWS[settings.historyRetention] == nil and settings.historyRetention == "indefinite" and "indefinite" or settings.historyRetention
    if RETENTION_WINDOWS[settings.historyRetention] == nil and settings.historyRetention ~= "indefinite" then
        settings.historyRetention = "indefinite"
    end
    local scanSeconds = tonumber(settings.ledgerScanIntervalSeconds or 300) or 300
    if scanSeconds < 300 then
        scanSeconds = 300
    end
    settings.ledgerScanIntervalSeconds = scanSeconds
    settings.repairThresholdGold = math.max(0, tonumber(settings.repairThresholdGold or 5000) or 5000)
    settings.muteSilvermoonCitizen = settings.muteSilvermoonCitizen == true
    return settings
end

local function item_fingerprint_bases(values, forceUnknownTimeKey)
    values = type(values) == "table" and values or {}
    local timeKey = stable_time_key(values, forceUnknownTimeKey)
    return make_fingerprint({
        timeKey,
        trim(values.who or "Unknown"),
        item_action_label(values.action or values.type),
        tonumber(values.itemID or 0) or 0,
        tonumber(values.quantity or values.count or 0) or 0,
        trim(values.tabName or values.sourceTabName or ("Tab " .. tostring(tonumber(values.tabIndex or values.sourceTabIndex or 0) or 0))),
        trim(values.fromTabName) ~= "" and trim(values.fromTabName) or "-",
    })
end

local function money_fingerprint_bases(values, repairThresholdGold, forceUnknownTimeKey)
    values = type(values) == "table" and values or {}
    local timeKey = stable_time_key(values, forceUnknownTimeKey)
    local amountCopper = tonumber(values.amountCopper or values.amount or 0) or 0
    return make_fingerprint({
        timeKey,
        trim(values.who or "Unknown"),
        money_identity_type(values.type or values.rawType or values.action),
        amountCopper,
    })
end

local function money_replay_bridge_base(values)
    values = type(values) == "table" and values or {}
    local amountCopper = tonumber(values.amountCopper or values.amount or 0) or 0
    return make_fingerprint({
        money_visible_hour_key(values),
        trim(values.who or "Unknown"),
        money_identity_type(values.type or values.rawType or values.action),
        amountCopper,
    })
end

local function split_fingerprint(fingerprint)
    local parts = {}
    for part in string.gmatch(tostring(fingerprint or ""), "([^|]+)") do
        parts[#parts + 1] = part
    end
    return parts
end

local function money_replay_bridge_base_from_fingerprint(fingerprint)
    local parts = split_fingerprint(fingerprint_base(fingerprint))
    local actorIndex = #parts - 2
    local year = tonumber(parts[1])
    local month = tonumber(parts[2])
    local day = tonumber(parts[3])
    local hour = tonumber(parts[4])
    if not (year and year >= 1000 and month and day and actorIndex > 4) then
        return ""
    end

    return make_fingerprint({
        raw_time_key(year, month, day, hour, nil),
        parts[actorIndex],
        parts[actorIndex + 1],
        parts[actorIndex + 2],
    })
end

local function money_source_bridge_bases(sourceSnapshots)
    local bridgeBases = {}
    for _, fingerprints in pairs(sourceSnapshots or {}) do
        for _, fingerprint in ipairs(fingerprints or {}) do
            local bridgeBase = money_replay_bridge_base_from_fingerprint(fingerprint)
            if bridgeBase ~= "" then
                bridgeBases[bridgeBase] = true
            end
        end
    end
    return bridgeBases
end

local function assign_occurrence_fingerprints(rows)
    local exactCounts = {}
    local legacyCounts = {}

    for index = #rows, 1, -1 do
        local row = rows[index]
        local exactBase = tostring(row.fingerprintBase or "")
        exactCounts[exactBase] = (tonumber(exactCounts[exactBase] or 0) or 0) + 1
        row.fingerprint = make_occurrence_fingerprint(exactBase, exactCounts[exactBase])

        local legacyBase = tostring(row.legacyFingerprintBase or exactBase)
        legacyCounts[legacyBase] = (tonumber(legacyCounts[legacyBase] or 0) or 0) + 1
        local legacyFingerprint = make_occurrence_fingerprint(legacyBase, legacyCounts[legacyBase])
        row.legacyFingerprint = legacyFingerprint ~= row.fingerprint and legacyFingerprint or nil
    end
end

local function legacy_index_requires_rebuild(entries, fingerprintIndex)
    if next(fingerprintIndex or {}) == nil then
        return true
    end

    local entryIdSet = {}
    for _, entry in ipairs(entries or {}) do
        entryIdSet[tostring(entry.entryId or "")] = true
    end

    for key in pairs(fingerprintIndex or {}) do
        if entryIdSet[tostring(key)] then
            return true
        end
    end

    return false
end

local function add_index_keys(fingerprintIndex, row)
    local fingerprint = trim((row or {}).fingerprint)
    if fingerprint ~= "" then
        fingerprintIndex[fingerprint] = true
    end

    local legacyFingerprint = trim((row or {}).legacyFingerprint)
    if legacyFingerprint ~= "" then
        fingerprintIndex[legacyFingerprint] = true
    end
end

local function legacy_item_row_bases(entry)
    entry = type(entry) == "table" and entry or {}
    local unknownBase = item_fingerprint_bases({
        who = entry.who,
        action = entry.action,
        itemID = entry.itemID,
        quantity = entry.quantity,
        tabName = entry.tabName,
        tabIndex = entry.tabIndex,
        fromTabName = entry.fromTabName,
    }, true)

    local reconstructedBase = item_fingerprint_bases({
        year = entry.year,
        month = entry.month,
        day = entry.day,
        hour = entry.hour,
        minute = entry.minute,
        timestamp = entry.timestamp,
        when = entry.when,
        who = entry.who,
        action = entry.action,
        itemID = entry.itemID,
        quantity = entry.quantity,
        tabName = entry.tabName,
        tabIndex = entry.tabIndex,
        fromTabName = entry.fromTabName,
    }, false)

    return reconstructedBase, unknownBase
end

local function legacy_money_row_bases(entry, repairThresholdGold)
    entry = type(entry) == "table" and entry or {}
    local unknownBase = money_fingerprint_bases({
        who = entry.who,
        action = entry.action,
        amountCopper = entry.amountCopper or entry.amount,
    }, repairThresholdGold, true)

    local reconstructedBase = money_fingerprint_bases({
        year = entry.year,
        month = entry.month,
        day = entry.day,
        hour = entry.hour,
        minute = entry.minute,
        timestamp = entry.timestamp,
        when = entry.when,
        who = entry.who,
        action = entry.action,
        amountCopper = entry.amountCopper or entry.amount,
    }, repairThresholdGold, false)

    return reconstructedBase, unknownBase
end

local function rebuild_fingerprint_index(entries, fingerprintIndex, baseBuilder)
    for key in pairs(fingerprintIndex or {}) do
        fingerprintIndex[key] = nil
    end

    local exactCounts = {}
    local legacyCounts = {}
    for _, entry in ipairs(entries or {}) do
        if trim(entry.fingerprint) == "" then
            local exactBase, legacyBase = baseBuilder(entry)
            exactCounts[exactBase] = (tonumber(exactCounts[exactBase] or 0) or 0) + 1
            entry.fingerprint = make_occurrence_fingerprint(exactBase, exactCounts[exactBase])

            legacyCounts[legacyBase] = (tonumber(legacyCounts[legacyBase] or 0) or 0) + 1
            local legacyFingerprint = make_occurrence_fingerprint(legacyBase, legacyCounts[legacyBase])
            entry.legacyFingerprint = legacyFingerprint ~= entry.fingerprint and legacyFingerprint or nil
        end

        add_index_keys(fingerprintIndex, entry)
    end
end

function bankLedger.EnsureState(db)
    db.bankLedger = ensure_table(db.bankLedger)
    db.bankLedger.itemLogs = ensure_table(db.bankLedger.itemLogs)
    db.bankLedger.moneyLogs = ensure_table(db.bankLedger.moneyLogs)
    db.bankLedger.itemFingerprints = ensure_table(db.bankLedger.itemFingerprints)
    db.bankLedger.moneyFingerprints = ensure_table(db.bankLedger.moneyFingerprints)
    db.bankLedger.itemSourceSnapshots = ensure_table(db.bankLedger.itemSourceSnapshots)
    db.bankLedger.moneySourceSnapshots = ensure_table(db.bankLedger.moneySourceSnapshots)
    db.bankLedger.nextEntrySequence = tonumber(db.bankLedger.nextEntrySequence or 0) or 0
    db.bankLedger.lastScanAt = tonumber(db.bankLedger.lastScanAt or 0) or 0
    db.bankLedger.lastItemScanAt = tonumber(db.bankLedger.lastItemScanAt or 0) or 0
    db.bankLedger.lastMoneyScanAt = tonumber(db.bankLedger.lastMoneyScanAt or 0) or 0
    ensure_settings(db)

    rebuild_fingerprint_index(db.bankLedger.itemLogs, db.bankLedger.itemFingerprints, legacy_item_row_bases)
    rebuild_fingerprint_index(db.bankLedger.moneyLogs, db.bankLedger.moneyFingerprints, function(entry)
        return legacy_money_row_bases(entry, ensure_settings(db).repairThresholdGold)
    end)

    return db.bankLedger
end

function bankLedger.GetRetentionChoices()
    return {
        { value = "1_week", label = RETENTION_LABELS["1_week"] },
        { value = "1_month", label = RETENTION_LABELS["1_month"] },
        { value = "3_months", label = RETENTION_LABELS["3_months"] },
        { value = "6_months", label = RETENTION_LABELS["6_months"] },
        { value = "1_year", label = RETENTION_LABELS["1_year"] },
        { value = "indefinite", label = RETENTION_LABELS.indefinite },
    }
end

function bankLedger.GetScanIntervalChoices()
    local choices = {}
    for _, seconds in ipairs(SCAN_INTERVAL_OPTIONS) do
        choices[#choices + 1] = {
            value = seconds,
            label = SCAN_INTERVAL_LABELS[seconds] or tostring(seconds),
        }
    end
    return choices
end

function bankLedger.GetRetentionLabel(value)
    return RETENTION_LABELS[value] or RETENTION_LABELS.indefinite
end

function bankLedger.GetScanIntervalLabel(seconds)
    seconds = tonumber(seconds or 300) or 300
    if seconds < 300 then
        seconds = 300
    end
    return SCAN_INTERVAL_LABELS[seconds] or string.format("%d Minutes", math.floor(seconds / 60))
end

function bankLedger.GetSettings(db)
    return ensure_settings(db or {})
end

function bankLedger.ShouldScan(db, now)
    local ledger = bankLedger.EnsureState(db or {})
    local settings = ensure_settings(db or {})
    now = tonumber(now or 0) or 0
    local lastScanAt = tonumber(ledger.lastScanAt or 0) or 0
    if lastScanAt <= 0 then
        return true
    end

    return (now - lastScanAt) >= math.max(300, tonumber(settings.ledgerScanIntervalSeconds or 300) or 300)
end

function bankLedger.MarkScanned(db, now, kind)
    local ledger = bankLedger.EnsureState(db or {})
    now = tonumber(now or 0) or 0
    ledger.lastScanAt = math.max(ledger.lastScanAt or 0, now)
    if kind == "item" then
        ledger.lastItemScanAt = now
    elseif kind == "money" then
        ledger.lastMoneyScanAt = now
    else
        ledger.lastItemScanAt = now
        ledger.lastMoneyScanAt = now
    end
    return ledger.lastScanAt
end

local function next_entry_id(ledger, prefix)
    ledger.nextEntrySequence = (tonumber(ledger.nextEntrySequence or 0) or 0) + 1
    return string.format("%s-%d", tostring(prefix or "ledger"), ledger.nextEntrySequence)
end

local function overlap_new_row_delta(currentFingerprints, previousFingerprints)
    currentFingerprints = currentFingerprints or {}
    previousFingerprints = previousFingerprints or {}

    if #currentFingerprints == 0 then
        return {
            count = 0,
            mode = "front",
        }
    end

    if #previousFingerprints == 0 then
        return {
            count = #currentFingerprints,
            mode = "front",
        }
    end

    local minimumReliableOverlap = math.min(1, #currentFingerprints, #previousFingerprints)
    local bestFrontStart = nil
    local bestFrontOverlap = 0

    for startIndex = 1, #currentFingerprints do
        local overlapLength = math.min(#currentFingerprints - startIndex + 1, #previousFingerprints)
        local matches = overlapLength > 0
        for offset = 1, overlapLength do
            if currentFingerprints[startIndex + offset - 1] ~= previousFingerprints[offset] then
                matches = false
                break
            end
        end

        if matches and (overlapLength > bestFrontOverlap or (overlapLength == bestFrontOverlap and (bestFrontStart == nil or startIndex > bestFrontStart))) then
            bestFrontOverlap = overlapLength
            bestFrontStart = startIndex
        end
    end

    local bestBackOverlap = 0
    local maxBackOverlap = math.min(#currentFingerprints, #previousFingerprints)
    for overlapLength = maxBackOverlap, 1, -1 do
        local matches = true
        for offset = 1, overlapLength do
            if currentFingerprints[offset] ~= previousFingerprints[#previousFingerprints - overlapLength + offset] then
                matches = false
                break
            end
        end

        if matches then
            bestBackOverlap = overlapLength
            break
        end
    end

    local best = nil

    if bestFrontStart ~= nil and bestFrontOverlap >= minimumReliableOverlap then
        best = {
            count = bestFrontStart - 1,
            mode = "front",
            overlap = bestFrontOverlap,
        }
    end

    if bestBackOverlap >= minimumReliableOverlap then
        local candidate = {
            count = #currentFingerprints - bestBackOverlap,
            mode = "back",
            overlap = bestBackOverlap,
        }
        if best == nil or candidate.count < best.count or (candidate.count == best.count and candidate.overlap > best.overlap) then
            best = candidate
        end
    end

    if best ~= nil then
        return best
    end

    return {
        count = #currentFingerprints,
        mode = "front",
    }
end

local function describe_source_delta(sourceSnapshots, sourceKey, normalizedRows)
    local currentFingerprints = {}
    for index, row in ipairs(normalizedRows or {}) do
        currentFingerprints[index] = tostring(row.fingerprint or "")
    end

    local previousFingerprints = sourceSnapshots[sourceKey] or {}
    local overlap = overlap_new_row_delta(currentFingerprints, previousFingerprints)
    local newRowCount = tonumber((overlap or {}).count or 0) or 0
    local currentCount = #currentFingerprints
    local previousCount = #previousFingerprints
    local exactMatch = currentCount > 0 and currentCount == previousCount and newRowCount == 0
    local emptyAfterKnown = previousCount > 0 and currentCount == 0
    local suspiciousNoOverlap = previousCount > 0
        and currentCount > 1
        and newRowCount == currentCount
        and currentCount <= previousCount

    return {
        currentFingerprints = currentFingerprints,
        previousFingerprints = previousFingerprints,
        currentCount = currentCount,
        previousCount = previousCount,
        newRowCount = newRowCount,
        appendMode = (overlap or {}).mode or "front",
        exactMatch = exactMatch,
        emptyAfterKnown = emptyAfterKnown,
        suspiciousNoOverlap = suspiciousNoOverlap,
    }
end

local function count_snapshot_bases(fingerprints)
    local counts = {}
    for _, fingerprint in ipairs(fingerprints or {}) do
        local base = fingerprint_base(fingerprint)
        if base ~= "" then
            counts[base] = (tonumber(counts[base] or 0) or 0) + 1
        end
    end
    return counts
end

local function count_normalized_bases(rows)
    local counts = {}
    for _, row in ipairs(rows or {}) do
        local base = tostring(row.fingerprintBase or fingerprint_base(row.fingerprint) or "")
        if base ~= "" then
            counts[base] = (tonumber(counts[base] or 0) or 0) + 1
        end
    end
    return counts
end

local function reconcile_remote_batch_counts(ledger, kind, sourceKey, sourceSnapshots, normalizedRows)
    local snapshotBaseCounts = count_snapshot_bases((sourceSnapshots or {})[sourceKey] or {})
    if next(snapshotBaseCounts) == nil then
        return
    end

    local batchCounts = session_batch_counts(ledger)[kind]
    batchCounts[sourceKey] = ensure_table(batchCounts[sourceKey])
    local currentBatchCounts = batchCounts[sourceKey]
    local normalizedBaseCounts = count_normalized_bases(normalizedRows)

    for base in pairs(snapshotBaseCounts) do
        local normalizedCount = tonumber(normalizedBaseCounts[base] or 0) or 0
        if normalizedCount > (tonumber(currentBatchCounts[base] or 0) or 0) then
            currentBatchCounts[base] = normalizedCount
        end
    end
end

local function append_delta_rows(ledger, entries, fingerprintIndex, sourceSnapshots, sourceKey, normalizedRows, mergedCount, entryPrefix, options)
    options = type(options) == "table" and options or {}
    local delta = describe_source_delta(sourceSnapshots, sourceKey, normalizedRows)
    local currentFingerprints = delta.currentFingerprints
    local currentCounts = {}
    local knownFingerprintCount = 0
    local storedCounts = {}
    local groups = {}
    local groupOrder = {}
    local previousBatchCounts = type(options.previousBatchCounts) == "table" and options.previousBatchCounts or nil
    local nextOccurrences = {}
    local replayBridgeBaseBuilder = type(options.replayBridgeBaseBuilder) == "function" and options.replayBridgeBaseBuilder or nil
    local replayBridgeStoredCounts = {}
    local replayBridgeLegacyKnownCounts = {}

    local function is_known_row(row, includeLegacy)
        if fingerprintIndex[tostring((row or {}).fingerprint or "")] then
            return true
        end

        return includeLegacy == true and fingerprintIndex[tostring((row or {}).legacyFingerprint or "")] == true
    end

    for _, entry in ipairs(entries or {}) do
        local base = fingerprint_base(entry and entry.fingerprint)
        if base ~= "" then
            storedCounts[base] = (tonumber(storedCounts[base] or 0) or 0) + 1
        end

        if replayBridgeBaseBuilder ~= nil then
            local replayBase = tostring(replayBridgeBaseBuilder(entry) or "")
            if replayBase ~= "" then
                replayBridgeStoredCounts[replayBase] = (tonumber(replayBridgeStoredCounts[replayBase] or 0) or 0) + 1
            end
        end
    end

    for _, row in ipairs(normalizedRows or {}) do
        local exactKnown = fingerprintIndex[tostring((row or {}).fingerprint or "")] == true
        local legacyKnown = fingerprintIndex[tostring((row or {}).legacyFingerprint or "")] == true
        if exactKnown or legacyKnown then
            knownFingerprintCount = knownFingerprintCount + 1
        end

        local base = tostring(row.fingerprintBase or fingerprint_base(row.fingerprint) or "")
        if base ~= "" then
            if not groups[base] then
                groups[base] = {}
                groupOrder[#groupOrder + 1] = base
            end
            groups[base][#groups[base] + 1] = row
            currentCounts[base] = (tonumber(currentCounts[base] or 0) or 0) + 1

            if replayBridgeBaseBuilder ~= nil and exactKnown ~= true and legacyKnown == true then
                local replayBase = tostring(row.replayBridgeBase or replayBridgeBaseBuilder(row) or "")
                if replayBase ~= "" then
                    replayBridgeLegacyKnownCounts[base] = tonumber(replayBridgeStoredCounts[replayBase] or 0) or 0
                end
            end
        end
    end

    local function finish()
        if type(options.currentBatchCounts) == "table" then
            for key in pairs(options.currentBatchCounts) do
                options.currentBatchCounts[key] = nil
            end
            for key, count in pairs(currentCounts) do
                options.currentBatchCounts[key] = count
            end
        end

        if options.skipSourceSnapshotUpdate ~= true then
            sourceSnapshots[sourceKey] = currentFingerprints
        end
        return mergedCount
    end

    if delta.emptyAfterKnown then
        return mergedCount
    end

    if delta.suspiciousNoOverlap and knownFingerprintCount == 0 and options.allowSuspiciousUnknownAppend ~= true then
        return mergedCount
    end

    local function append_row(row, base, alreadyKnown)
        local nextOccurrence = nextOccurrences[base]
        if nextOccurrence == nil then
            nextOccurrence = math.max(
                tonumber(storedCounts[base] or 0) or 0,
                tonumber(alreadyKnown or 0) or 0
            )
        end

        row.entryId = next_entry_id(ledger, entryPrefix)
        row.fingerprint = make_occurrence_fingerprint(base, nextOccurrence + 1)
        row.fingerprintBase = nil
        row.legacyFingerprintBase = nil
        row.sourceIndex = nil
        add_index_keys(fingerprintIndex, row)
        entries[#entries + 1] = row
        mergedCount = mergedCount + 1
        nextOccurrences[base] = nextOccurrence + 1
    end

    if delta.suspiciousNoOverlap and knownFingerprintCount > 0 then
        for _, row in ipairs(normalizedRows or {}) do
            if not is_known_row(row, true) then
                local base = tostring(row.fingerprintBase or fingerprint_base(row.fingerprint) or "")
                if base ~= "" then
                    append_row(row, base, storedCounts[base])
                end
            end
        end
        return finish()
    end

    for _, base in ipairs(groupOrder) do
        local group = groups[base] or {}
        local alreadyKnown = 0
        if previousBatchCounts ~= nil and previousBatchCounts[base] ~= nil then
            alreadyKnown = tonumber(previousBatchCounts[base] or 0) or 0
        else
            alreadyKnown = tonumber(storedCounts[base] or 0) or 0
        end
        if alreadyKnown == 0 and replayBridgeBaseBuilder ~= nil then
            alreadyKnown = tonumber(replayBridgeLegacyKnownCounts[base] or 0) or 0
        end
        local newCount = math.max(0, #group - alreadyKnown)

        for index = 1, newCount do
            local row = group[index]
            append_row(row, base, alreadyKnown)
        end
    end

    return finish()
end

local function normalize_item_rows(payload)
    payload = type(payload) == "table" and payload or {}
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceTabIndex = tonumber(payload.sourceTabIndex or 0) or 0
    local sourceTabName = tostring(payload.sourceTabName or ("Tab " .. tostring(sourceTabIndex)))
    local sourceKey = string.format("item:%d", sourceTabIndex)
    local normalizedRows = {}

    for index, raw in ipairs(payload.transactions or {}) do
        local itemID = tonumber(raw.itemID or 0) or 0
        local itemName = trim(raw.itemName or raw.item or ("Item " .. tostring(itemID)))
        local timestamp = timestamp_from_parts(raw.year, raw.month, raw.day, raw.hour, raw.minute, scanStartedAt)
        local action = item_action_label(raw.type)
        local fromTabName = trim(raw.fromTabName)
        local rowHasTimeParts = has_time_parts(raw.year, raw.month, raw.day, raw.hour, raw.minute)
        local fingerprintBase = item_fingerprint_bases({
            timestamp = timestamp,
            year = raw.year,
            month = raw.month,
            day = raw.day,
            hour = raw.hour,
            minute = raw.minute,
            who = raw.who,
            action = action,
            itemID = itemID,
            quantity = raw.quantity or raw.count,
            tabName = sourceTabName,
            fromTabName = fromTabName,
        }, not rowHasTimeParts)
        local legacyFingerprintBase = item_fingerprint_bases({
            timestamp = timestamp,
            who = raw.who,
            action = action,
            itemID = itemID,
            quantity = raw.quantity or raw.count,
            tabName = sourceTabName,
            fromTabName = fromTabName,
        }, true)
        normalizedRows[#normalizedRows + 1] = {
            timestamp = timestamp,
            when = timestamp,
            who = trim(raw.who or "Unknown"),
            action = action,
            itemID = itemID,
            qualityTier = tonumber(raw.craftedQuality or raw.qualityTier or 0) or 0,
            item = itemName,
            quantity = tonumber(raw.quantity or raw.count or 0) or 0,
            tabName = sourceTabName,
            tabIndex = sourceTabIndex,
            fromTabName = fromTabName ~= "" and fromTabName or "-",
            craftedQuality = tonumber(raw.craftedQuality or raw.qualityTier or 0) or 0,
            craftedQualityIcon = raw.craftedQualityIcon or raw.qualityTierIcon,
            fingerprintBase = fingerprintBase,
            legacyFingerprintBase = legacyFingerprintBase,
            sourceIndex = index,
        }
    end

    assign_occurrence_fingerprints(normalizedRows)

    return sourceKey, normalizedRows
end

local function normalize_money_rows(payload)
    payload = type(payload) == "table" and payload or {}
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceKey = "money"
    local normalizedRows = {}
    local repairThresholdGold = tonumber(payload.repairThresholdGold or payload.settingsRepairThresholdGold or 5000) or 5000

    for index, raw in ipairs(payload.transactions or {}) do
        local amountCopper = tonumber(raw.amountCopper or raw.amount or 0) or 0
        local timestamp = timestamp_from_parts(raw.year, raw.month, raw.day, raw.hour, raw.minute, scanStartedAt)
        local action = money_action_label(raw.type, amountCopper, repairThresholdGold)
        local rowHasTimeParts = has_time_parts(raw.year, raw.month, raw.day, raw.hour, raw.minute)
        local fingerprintBase = money_fingerprint_bases({
            timestamp = timestamp,
            year = raw.year,
            month = raw.month,
            day = raw.day,
            hour = raw.hour,
            minute = raw.minute,
            who = raw.who,
            action = action,
            amountCopper = amountCopper,
        }, repairThresholdGold, not rowHasTimeParts)
        local legacyFingerprintBase = money_fingerprint_bases({
            timestamp = timestamp,
            who = raw.who,
            action = action,
            amountCopper = amountCopper,
        }, repairThresholdGold, true)
        normalizedRows[#normalizedRows + 1] = {
            timestamp = timestamp,
            when = timestamp,
            year = raw.year,
            month = raw.month,
            day = raw.day,
            hour = raw.hour,
            minute = raw.minute,
            who = trim(raw.who or "Unknown"),
            action = action,
            amountCopper = amountCopper,
            amount = amountCopper,
            fingerprintBase = fingerprintBase,
            legacyFingerprintBase = legacyFingerprintBase,
            replayBridgeBase = money_replay_bridge_base({
                timestamp = timestamp,
                year = raw.year,
                month = raw.month,
                day = raw.day,
                hour = raw.hour,
                minute = raw.minute,
                who = raw.who,
                action = action,
                amountCopper = amountCopper,
            }),
            sourceIndex = index,
        }
    end

    assign_occurrence_fingerprints(normalizedRows)

    return sourceKey, normalizedRows
end

function bankLedger.DescribeItemDelta(db, payload)
    db = db or {}
    local ledger = bankLedger.EnsureState(db)
    local sourceKey, normalizedRows = normalize_item_rows(payload)
    return describe_source_delta(ledger.itemSourceSnapshots, sourceKey, normalizedRows)
end

function bankLedger.DescribeMoneyDelta(db, payload)
    db = db or {}
    local ledger = bankLedger.EnsureState(db)
    payload = type(payload) == "table" and payload or {}
    payload.repairThresholdGold = tonumber(payload.repairThresholdGold or bankLedger.GetSettings(db).repairThresholdGold or 5000) or 5000
    local sourceKey, normalizedRows = normalize_money_rows(payload)
    return describe_source_delta(ledger.moneySourceSnapshots, sourceKey, normalizedRows)
end

function bankLedger.MergeItemTransactions(db, payload)
    db = db or {}
    payload = type(payload) == "table" and payload or {}
    local ledger = bankLedger.EnsureState(db)
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceKey, normalizedRows = normalize_item_rows(payload)
    local batchCounts = session_batch_counts(ledger).item
    local currentBatchCounts = {}

    local mergedCount = append_delta_rows(
        ledger,
        ledger.itemLogs,
        ledger.itemFingerprints,
        ledger.itemSourceSnapshots,
        sourceKey,
        normalizedRows,
        0,
        "item",
        {
            allowSuspiciousUnknownAppend = payload.allowSuspiciousUnknownAppend == true,
            previousBatchCounts = batchCounts[sourceKey],
            currentBatchCounts = currentBatchCounts,
        }
    )
    batchCounts[sourceKey] = currentBatchCounts
    bankLedger.MarkScanned(db, scanStartedAt, "item")
    return mergedCount
end

function bankLedger.MergeMoneyTransactions(db, payload)
    db = db or {}
    payload = type(payload) == "table" and payload or {}
    local ledger = bankLedger.EnsureState(db)
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    payload.repairThresholdGold = tonumber(payload.repairThresholdGold or bankLedger.GetSettings(db).repairThresholdGold or 5000) or 5000
    local sourceKey, normalizedRows = normalize_money_rows(payload)
    local batchCounts = session_batch_counts(ledger).money
    local currentBatchCounts = {}

    local mergedCount = append_delta_rows(
        ledger,
        ledger.moneyLogs,
        ledger.moneyFingerprints,
        ledger.moneySourceSnapshots,
        sourceKey,
        normalizedRows,
        0,
        "money",
        {
            allowSuspiciousUnknownAppend = true,
            previousBatchCounts = batchCounts[sourceKey],
            currentBatchCounts = currentBatchCounts,
            replayBridgeBaseBuilder = money_replay_bridge_base,
        }
    )
    batchCounts[sourceKey] = currentBatchCounts
    bankLedger.MarkScanned(db, scanStartedAt, "money")
    return mergedCount
end

function bankLedger.MergeRemoteDelta(db, payload)
    db = db or {}
    payload = type(payload) == "table" and payload or {}

    local ledger = bankLedger.EnsureState(db)
    local kind = tostring(payload.kind or "")
    if kind == "item" then
        local sourceKey, normalizedRows = normalize_item_rows(payload)
        local mergedCount = append_delta_rows(
            ledger,
            ledger.itemLogs,
            ledger.itemFingerprints,
            ledger.itemSourceSnapshots,
            sourceKey,
            normalizedRows,
            0,
            "item",
            {
                allowSuspiciousUnknownAppend = true,
                skipSourceSnapshotUpdate = true,
                replayBridgeBaseBuilder = money_replay_bridge_base,
            }
        )
        reconcile_remote_batch_counts(ledger, "item", sourceKey, ledger.itemSourceSnapshots, normalizedRows)
        return mergedCount
    end

    if kind == "money" then
        payload.repairThresholdGold = tonumber(payload.repairThresholdGold or bankLedger.GetSettings(db).repairThresholdGold or 5000) or 5000
        local sourceKey, normalizedRows = normalize_money_rows(payload)
        local mergedCount = append_delta_rows(
            ledger,
            ledger.moneyLogs,
            ledger.moneyFingerprints,
            ledger.moneySourceSnapshots,
            sourceKey,
            normalizedRows,
            0,
            "money",
            {
                allowSuspiciousUnknownAppend = true,
                skipSourceSnapshotUpdate = true,
            }
        )
        reconcile_remote_batch_counts(ledger, "money", sourceKey, ledger.moneySourceSnapshots, normalizedRows)
        return mergedCount
    end

    return 0
end

local function dedupe_bucket(timestamp)
    timestamp = tonumber(timestamp or 0) or 0
    if timestamp <= 0 then
        return 0
    end
    return math.floor(timestamp / 60)
end

local function item_dedupe_key(entry)
    entry = type(entry) == "table" and entry or {}
    return make_fingerprint({
        dedupe_bucket(entry.timestamp or entry.when),
        trim(entry.who or "Unknown"),
        item_action_label(entry.action),
        tonumber(entry.itemID or 0) or 0,
        tonumber(entry.quantity or 0) or 0,
        trim(entry.tabName or "-"),
        trim(entry.fromTabName or "-"),
    })
end

local function money_dedupe_key(entry)
    entry = type(entry) == "table" and entry or {}
    return make_fingerprint({
        money_visible_date_key(entry),
        trim(entry.who or "Unknown"),
        visible_money_action_label(entry),
        tonumber(entry.amountCopper or entry.amount or 0) or 0,
    })
end

local function build_dedupe_review_row(kind, entry)
    entry = type(entry) == "table" and entry or {}
    local timestamp = tonumber(entry.timestamp or entry.when or 0) or 0
    if kind == "money" then
        return {
            kind = "money",
            timestamp = timestamp,
            entryId = tostring(entry.entryId or ""),
            summary = string.format(
                "%s | Money | %s | %s | %s",
                format_export_timestamp(timestamp),
                trim(entry.who or "Unknown"),
                trim(entry.action or "Unknown"),
                format_copper(entry.amountCopper or entry.amount or 0)
            ),
        }
    end

    return {
        kind = "item",
        timestamp = timestamp,
        entryId = tostring(entry.entryId or ""),
        summary = string.format(
            "%s | Item | %s | %s | %s x%d | %s",
            format_export_timestamp(timestamp),
            trim(entry.who or "Unknown"),
            trim(entry.action or "Unknown"),
            trim(entry.item or entry.itemName or "Unknown"),
            tonumber(entry.quantity or 0) or 0,
            trim(entry.tabName or "-")
        ),
    }
end

local function dedupe_keep_index(group, kind, options)
    if kind ~= "money" then
        return 1
    end

    options = type(options) == "table" and options or {}
    local sourceBridgeBases = type(options.sourceBridgeBases) == "table" and options.sourceBridgeBases or {}
    local bestIndex = 1
    local bestScore = 0
    for index, entry in ipairs(group or {}) do
        local score = 0
        local bridgeBase = money_replay_bridge_base(entry)
        if bridgeBase ~= "" and sourceBridgeBases[bridgeBase] == true then
            score = 1
        end
        if score > bestScore then
            bestScore = score
            bestIndex = index
        end
    end
    return bestIndex
end

local function build_dedupe_plan_for_entries(entries, kind, options)
    local groups = {}
    local groupOrder = {}

    for _, entry in ipairs(entries or {}) do
        local key = kind == "money" and money_dedupe_key(entry) or item_dedupe_key(entry)
        if key ~= "" then
            if not groups[key] then
                groups[key] = {}
                groupOrder[#groupOrder + 1] = key
            end
            groups[key][#groups[key] + 1] = entry
        end
    end

    local removableEntryIds = {}
    local reviewRows = {}
    local duplicateGroupCount = 0
    local duplicateRowCount = 0

    for _, key in ipairs(groupOrder) do
        local group = groups[key] or {}
        if #group > 1 then
            duplicateGroupCount = duplicateGroupCount + 1
            local keepIndex = dedupe_keep_index(group, kind, options)
            for index = 1, #group do
                local entry = group[index]
                if index ~= keepIndex then
                    local entryId = tostring(entry.entryId or "")
                    removableEntryIds[entryId] = true
                    reviewRows[#reviewRows + 1] = build_dedupe_review_row(kind, entry)
                    duplicateRowCount = duplicateRowCount + 1
                end
            end
        end
    end

    return {
        duplicateGroupCount = duplicateGroupCount,
        duplicateRowCount = duplicateRowCount,
        removableEntryIds = removableEntryIds,
        reviewRows = reviewRows,
    }
end

function bankLedger.BuildDedupePlan(db)
    db = db or {}
    local ledger = bankLedger.EnsureState(db)
    local itemPlan = build_dedupe_plan_for_entries(ledger.itemLogs, "item")
    local moneyPlan = build_dedupe_plan_for_entries(ledger.moneyLogs, "money", {
        sourceBridgeBases = money_source_bridge_bases(ledger.moneySourceSnapshots),
    })
    local reviewRows = {}

    for _, row in ipairs(itemPlan.reviewRows or {}) do
        reviewRows[#reviewRows + 1] = row
    end
    for _, row in ipairs(moneyPlan.reviewRows or {}) do
        reviewRows[#reviewRows + 1] = row
    end

    table.sort(reviewRows, function(left, right)
        local leftStamp = tonumber(left.timestamp or 0) or 0
        local rightStamp = tonumber(right.timestamp or 0) or 0
        if leftStamp == rightStamp then
            return tostring(left.summary or "") < tostring(right.summary or "")
        end
        return leftStamp > rightStamp
    end)

    return {
        itemDuplicateGroupCount = tonumber(itemPlan.duplicateGroupCount or 0) or 0,
        itemDuplicateRowCount = tonumber(itemPlan.duplicateRowCount or 0) or 0,
        moneyDuplicateGroupCount = tonumber(moneyPlan.duplicateGroupCount or 0) or 0,
        moneyDuplicateRowCount = tonumber(moneyPlan.duplicateRowCount or 0) or 0,
        totalDuplicateGroupCount = (tonumber(itemPlan.duplicateGroupCount or 0) or 0) + (tonumber(moneyPlan.duplicateGroupCount or 0) or 0),
        totalDuplicateRowCount = (tonumber(itemPlan.duplicateRowCount or 0) or 0) + (tonumber(moneyPlan.duplicateRowCount or 0) or 0),
        itemRemovableEntryIds = itemPlan.removableEntryIds,
        moneyRemovableEntryIds = moneyPlan.removableEntryIds,
        reviewRows = reviewRows,
    }
end

local function remove_entries_by_id(entries, removableEntryIds)
    local kept = {}
    local removed = 0
    removableEntryIds = type(removableEntryIds) == "table" and removableEntryIds or {}
    for _, entry in ipairs(entries or {}) do
        if removableEntryIds[tostring(entry.entryId or "")] == true then
            removed = removed + 1
        else
            kept[#kept + 1] = entry
        end
    end
    return kept, removed
end

function bankLedger.ApplyDedupePlan(db, plan)
    db = db or {}
    local ledger = bankLedger.EnsureState(db)
    plan = type(plan) == "table" and plan or bankLedger.BuildDedupePlan(db)

    local itemLogs, itemRemoved = remove_entries_by_id(ledger.itemLogs, plan.itemRemovableEntryIds)
    local moneyLogs, moneyRemoved = remove_entries_by_id(ledger.moneyLogs, plan.moneyRemovableEntryIds)
    ledger.itemLogs = itemLogs
    ledger.moneyLogs = moneyLogs
    ledger.itemSourceSnapshots = {}
    ledger.moneySourceSnapshots = {}

    local batchCounts = session_batch_counts(ledger)
    batchCounts.item = {}
    batchCounts.money = {}

    rebuild_fingerprint_index(ledger.itemLogs, ledger.itemFingerprints, legacy_item_row_bases)
    rebuild_fingerprint_index(ledger.moneyLogs, ledger.moneyFingerprints, function(entry)
        return legacy_money_row_bases(entry, ensure_settings(db).repairThresholdGold)
    end)

    return {
        itemRemoved = itemRemoved,
        moneyRemoved = moneyRemoved,
        totalRemoved = itemRemoved + moneyRemoved,
    }
end

local function filtered_item_logs(db, filters)
    local ledger = bankLedger.EnsureState(db or {})
    local rows = {}
    filters = filters or {}

    for _, entry in ipairs(ledger.itemLogs or {}) do
        if passes_date_range(entry.timestamp, filters)
            and contains_text(entry.action, filters.action)
            and contains_text(entry.who, filters.who)
            and contains_text(entry.item, filters.item)
            and contains_text(entry.tabName, filters.bankTab) then
            rows[#rows + 1] = entry
        end
    end

    table.sort(rows, function(left, right)
        local leftStamp = tonumber(left.timestamp or 0) or 0
        local rightStamp = tonumber(right.timestamp or 0) or 0
        if leftStamp == rightStamp then
            return tostring(left.entryId or "") > tostring(right.entryId or "")
        end
        return leftStamp > rightStamp
    end)
    return rows
end

local function item_label(entry)
    return trim((entry or {}).item or (entry or {}).itemName or "Unknown")
end

local function filtered_money_logs(db, filters)
    local ledger = bankLedger.EnsureState(db or {})
    local rows = {}
    filters = filters or {}

    for _, entry in ipairs(ledger.moneyLogs or {}) do
        if passes_date_range(entry.timestamp, filters)
            and contains_text(entry.action, filters.action)
            and contains_text(entry.who, filters.who) then
            rows[#rows + 1] = entry
        end
    end

    table.sort(rows, function(left, right)
        local leftStamp = tonumber(left.timestamp or 0) or 0
        local rightStamp = tonumber(right.timestamp or 0) or 0
        if leftStamp == rightStamp then
            return tostring(left.entryId or "") > tostring(right.entryId or "")
        end
        return leftStamp > rightStamp
    end)
    return rows
end

function bankLedger.BuildTableRows(db, mode, filters)
    mode = tostring(mode or "ITEM")
    if mode == "MONEY" then
        return filtered_money_logs(db, filters)
    end
    return filtered_item_logs(db, filters)
end

function bankLedger.BuildItemSummary(db, filters)
    local summary = {
        byItem = {},
    }

    for _, entry in ipairs(filtered_item_logs(db, filters)) do
        local itemName = item_label(entry)
        local current = summary.byItem[itemName] or {
            itemName = itemName,
            itemID = entry.itemID,
            deposited = 0,
            withdrawn = 0,
            moved = 0,
        }
        if entry.action == "Deposit" then
            current.deposited = current.deposited + (tonumber(entry.quantity or 0) or 0)
        elseif entry.action == "Withdrawal" then
            current.withdrawn = current.withdrawn + (tonumber(entry.quantity or 0) or 0)
        elseif entry.action == "Moved" then
            current.moved = current.moved + (tonumber(entry.quantity or 0) or 0)
        end
        summary.byItem[itemName] = current
    end

    return summary
end

function bankLedger.BuildMoneySummary(db, filters)
    local summary = {
        repairs = 0,
        withdrawals = 0,
        deposits = 0,
    }

    for _, entry in ipairs(filtered_money_logs(db, filters)) do
        local amount = tonumber(entry.amountCopper or entry.amount or 0) or 0
        if entry.action == "Repair" then
            summary.repairs = summary.repairs + amount
        elseif entry.action == "Deposit" then
            summary.deposits = summary.deposits + amount
        else
            summary.withdrawals = summary.withdrawals + amount
        end
    end

    return summary
end

function bankLedger.BuildUsageRows(db, filters)
    local usageByActor = {}

    for _, entry in ipairs(filtered_item_logs(db, filters)) do
        local actor = entry.who or "Unknown"
        local current = usageByActor[actor] or {
            who = actor,
            itemQuantityOut = 0,
            itemQuantityIn = 0,
            goldOut = 0,
            repairGold = 0,
            goldIn = 0,
        }
        if entry.action == "Withdrawal" then
            current.itemQuantityOut = current.itemQuantityOut + (tonumber(entry.quantity or 0) or 0)
        elseif entry.action == "Deposit" then
            current.itemQuantityIn = current.itemQuantityIn + (tonumber(entry.quantity or 0) or 0)
        end
        usageByActor[actor] = current
    end

    for _, entry in ipairs(filtered_money_logs(db, filters)) do
        local actor = entry.who or "Unknown"
        local current = usageByActor[actor] or {
            who = actor,
            itemQuantityOut = 0,
            itemQuantityIn = 0,
            goldOut = 0,
            repairGold = 0,
            goldIn = 0,
        }
        local amount = tonumber(entry.amountCopper or entry.amount or 0) or 0
        if entry.action == "Deposit" then
            current.goldIn = current.goldIn + amount
        elseif entry.action == "Repair" then
            current.repairGold = current.repairGold + amount
        else
            current.goldOut = current.goldOut + amount
        end
        usageByActor[actor] = current
    end

    local rows = {}
    for _, row in pairs(usageByActor) do
        row.totalItemActivity = (tonumber(row.itemQuantityOut or 0) or 0) + (tonumber(row.itemQuantityIn or 0) or 0)
        row.totalGoldActivity = (tonumber(row.goldOut or 0) or 0) + (tonumber(row.repairGold or 0) or 0) + (tonumber(row.goldIn or 0) or 0)
        rows[#rows + 1] = row
    end

    table.sort(rows, function(left, right)
        if left.totalGoldActivity ~= right.totalGoldActivity then
            return left.totalGoldActivity > right.totalGoldActivity
        end
        if left.totalItemActivity ~= right.totalItemActivity then
            return left.totalItemActivity > right.totalItemActivity
        end
        if left.goldOut ~= right.goldOut then
            return left.goldOut > right.goldOut
        end
        if left.repairGold ~= right.repairGold then
            return left.repairGold > right.repairGold
        end
        return tostring(left.who or "") < tostring(right.who or "")
    end)

    return rows
end

function bankLedger.BuildWithdrawalRankings(db, options)
    options = type(options) == "table" and options or {}
    local limit = tonumber(options.limit or 10) or 10
    local byItem = {}

    for _, entry in ipairs(filtered_item_logs(db, options)) do
        if entry.action == "Withdrawal" then
            local itemName = item_label(entry)
            local current = byItem[itemName] or {
                itemName = itemName,
                itemID = entry.itemID,
                quantity = 0,
            }
            current.quantity = current.quantity + (tonumber(entry.quantity or 0) or 0)
            byItem[itemName] = current
        end
    end

    local rows = {}
    for _, row in pairs(byItem) do
        rows[#rows + 1] = row
    end

    table.sort(rows, function(left, right)
        if left.quantity ~= right.quantity then
            return left.quantity > right.quantity
        end
        return tostring(left.itemName or "") < tostring(right.itemName or "")
    end)

    local limited = {}
    for index = 1, math.min(limit, #rows) do
        limited[index] = rows[index]
    end
    return limited
end

local function retention_cutoff(policyKey, now)
    local seconds = RETENTION_WINDOWS[policyKey]
    if not seconds then
        return nil
    end
    return (tonumber(now or 0) or 0) - seconds
end

local function prune_list(entries, fingerprintIndex, cutoff)
    if cutoff == nil then
        return entries
    end

    local kept = {}
    for _, entry in ipairs(entries or {}) do
        if (tonumber(entry.timestamp or 0) or 0) >= cutoff then
            kept[#kept + 1] = entry
        else
            fingerprintIndex[tostring(entry.fingerprint or "")] = nil
            fingerprintIndex[tostring(entry.legacyFingerprint or "")] = nil
        end
    end
    return kept
end

function bankLedger.PruneRetention(db, now)
    db = db or {}
    local ledger = bankLedger.EnsureState(db)
    local settings = ensure_settings(db)
    now = tonumber(now or 0) or 0

    ledger.itemLogs = prune_list(ledger.itemLogs, ledger.itemFingerprints, retention_cutoff(settings.ledgerRetention, now))
    ledger.moneyLogs = prune_list(ledger.moneyLogs, ledger.moneyFingerprints, retention_cutoff(settings.ledgerRetention, now))

    local historyCutoff = retention_cutoff(settings.historyRetention, now)
    if historyCutoff ~= nil then
        local keptHistory = {}
        for _, entry in ipairs(db.auditLog or {}) do
            if (tonumber(entry.timestamp or entry.scannedAt or 0) or 0) >= historyCutoff then
                keptHistory[#keptHistory + 1] = entry
            end
        end
        db.auditLog = keptHistory
    end

    return db
end

function bankLedger.ExportRowsToCsv(db, mode, filters)
    local rows = bankLedger.BuildTableRows(db, mode, filters)
    local lines = {}

    if tostring(mode or "ITEM") == "MONEY" then
        lines[#lines + 1] = "Date/Time,Who,Action,Amount"
        for _, row in ipairs(rows) do
            lines[#lines + 1] = string.format("%s,%s,%s,%s",
                format_export_timestamp(row.timestamp),
                tostring(row.who or ""),
                tostring(row.action or ""),
                tostring(row.amountCopper or 0)
            )
        end
    else
        lines[#lines + 1] = "Date/Time,Who,Action,Item ID,Quality Tier,Item,Quantity,Tab,Moved From"
        for _, row in ipairs(rows) do
            lines[#lines + 1] = string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s",
                format_export_timestamp(row.timestamp),
                tostring(row.who or ""),
                tostring(row.action or ""),
                tostring(row.itemID or ""),
                tostring(row.qualityTier or ""),
                tostring(row.item or ""),
                tostring(row.quantity or 0),
                tostring(row.tabName or "-"),
                tostring(row.fromTabName or "-")
            )
        end
    end

    return table.concat(lines, "\n")
end

ns.modules.bankLedger = bankLedger

return bankLedger
