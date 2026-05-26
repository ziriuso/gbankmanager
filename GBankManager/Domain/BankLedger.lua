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

local function timestamp_from_parts(year, month, day, hour, minute, fallback)
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour)
    minute = tonumber(minute)

    if year and month and day then
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

local function money_action_label(rawType, amountCopper)
    rawType = string.lower(trim(rawType))
    amountCopper = tonumber(amountCopper or 0) or 0
    if rawType == "deposit" then
        return "Deposit"
    end

    if rawType == "repair" then
        return "Repair"
    end

    local repairThreshold = 5000 * 10000
    if amountCopper > 0 and amountCopper < repairThreshold and (amountCopper % 10000) ~= 0 then
        return "Repair"
    end

    return "Withdrawal"
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
    return settings
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
        currentFingerprints[index] = tostring(row.fingerprintBase or "")
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

local function append_delta_rows(ledger, entries, fingerprintIndex, sourceSnapshots, sourceKey, normalizedRows, mergedCount, entryPrefix)
    local delta = describe_source_delta(sourceSnapshots, sourceKey, normalizedRows)
    local currentFingerprints = delta.currentFingerprints
    local previousFingerprints = delta.previousFingerprints
    local newRowCount = delta.newRowCount

    if delta.emptyAfterKnown then
        return mergedCount
    end

    if delta.suspiciousNoOverlap then
        return mergedCount
    end

    local startIndex = 1
    local endIndex = newRowCount
    if delta.appendMode == "back" then
        startIndex = math.max(1, (#normalizedRows - newRowCount) + 1)
        endIndex = #normalizedRows
    end

    for index = startIndex, endIndex do
        local row = normalizedRows[index]
        row.entryId = next_entry_id(ledger, entryPrefix)
        row.fingerprintBase = nil
        row.sourceIndex = nil
        fingerprintIndex[row.entryId] = true
        entries[#entries + 1] = row
        mergedCount = mergedCount + 1
    end

    sourceSnapshots[sourceKey] = currentFingerprints
    return mergedCount
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
            fingerprintBase = make_fingerprint({
                raw_time_key(raw.year, raw.month, raw.day, raw.hour, raw.minute),
                trim(raw.who or "Unknown"),
                action,
                itemID,
                tonumber(raw.quantity or raw.count or 0) or 0,
                sourceTabName,
                fromTabName,
            }),
            sourceIndex = index,
        }
    end

    return sourceKey, normalizedRows
end

local function normalize_money_rows(payload)
    payload = type(payload) == "table" and payload or {}
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceKey = "money"
    local normalizedRows = {}

    for index, raw in ipairs(payload.transactions or {}) do
        local amountCopper = tonumber(raw.amountCopper or raw.amount or 0) or 0
        local timestamp = timestamp_from_parts(raw.year, raw.month, raw.day, raw.hour, raw.minute, scanStartedAt)
        local action = money_action_label(raw.type, amountCopper)
        normalizedRows[#normalizedRows + 1] = {
            timestamp = timestamp,
            when = timestamp,
            who = trim(raw.who or "Unknown"),
            action = action,
            amountCopper = amountCopper,
            amount = amountCopper,
            fingerprintBase = make_fingerprint({
                raw_time_key(raw.year, raw.month, raw.day, raw.hour, raw.minute),
                trim(raw.who or "Unknown"),
                action,
                amountCopper,
            }),
            sourceIndex = index,
        }
    end

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
    local sourceKey, normalizedRows = normalize_money_rows(payload)
    return describe_source_delta(ledger.moneySourceSnapshots, sourceKey, normalizedRows)
end

function bankLedger.MergeItemTransactions(db, payload)
    db = db or {}
    payload = type(payload) == "table" and payload or {}
    local ledger = bankLedger.EnsureState(db)
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceKey, normalizedRows = normalize_item_rows(payload)

    local mergedCount = append_delta_rows(
        ledger,
        ledger.itemLogs,
        ledger.itemFingerprints,
        ledger.itemSourceSnapshots,
        sourceKey,
        normalizedRows,
        0,
        "item"
    )
    bankLedger.MarkScanned(db, scanStartedAt, "item")
    return mergedCount
end

function bankLedger.MergeMoneyTransactions(db, payload)
    db = db or {}
    payload = type(payload) == "table" and payload or {}
    local ledger = bankLedger.EnsureState(db)
    local scanStartedAt = tonumber(payload.scanStartedAt or 0) or 0
    local sourceKey, normalizedRows = normalize_money_rows(payload)

    local mergedCount = append_delta_rows(
        ledger,
        ledger.moneyLogs,
        ledger.moneyFingerprints,
        ledger.moneySourceSnapshots,
        sourceKey,
        normalizedRows,
        0,
        "money"
    )
    bankLedger.MarkScanned(db, scanStartedAt, "money")
    return mergedCount
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
            fingerprintIndex[tostring(entry.entryId or "")] = nil
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
                tostring(row.timestamp or 0),
                tostring(row.who or ""),
                tostring(row.action or ""),
                tostring(row.amountCopper or 0)
            )
        end
    else
        lines[#lines + 1] = "Date/Time,Who,Action,Item ID,Quality Tier,Item,Quantity,Tab,Moved From"
        for _, row in ipairs(rows) do
            lines[#lines + 1] = string.format("%s,%s,%s,%s,%s,%s,%s,%s,%s",
                tostring(row.timestamp or 0),
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
