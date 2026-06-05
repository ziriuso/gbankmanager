local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local store = ns.data.store or ns.modules.store or {}

local defaults = ns.data.defaults or ns.modules.defaults
local migrations = ns.data.migrations or ns.modules.migrations
local constants = ns.constants or {}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function is_placeholder_guild_name(guildName)
    local resolvedGuild = trim(guildName)
    return resolvedGuild == ""
        or resolvedGuild == "Unknown"
        or resolvedGuild == "Unknown Guild"
end

local function normalize_guild_name(guildName)
    local resolvedGuild = trim(guildName)
    if is_placeholder_guild_name(resolvedGuild) then
        return "Unknown"
    end

    return resolvedGuild
end

local function live_guild_name()
    if type(_G.GetGuildInfo) ~= "function" then
        return nil
    end

    local guildName = _G.GetGuildInfo("player")
    if type(guildName) == "string" and guildName ~= "" then
        return guildName
    end

    return nil
end

local function looks_like_root(db)
    return type(db) == "table" and type(db.guilds) == "table"
end

local function looks_like_database(db)
    if type(db) ~= "table" then
        return false
    end

    return type(db.meta) == "table"
        or db.currentSnapshotId ~= nil
        or type(db.snapshots) == "table"
        or type(db.requests) == "table"
        or type(db.minimums) == "table"
        or type(db.oneTimeTargets) == "table"
        or type(db.ui) == "table"
        or type(db.bankLedger) == "table"
end

local function resolve_guild_name(guildName, source)
    if not is_placeholder_guild_name(guildName) then
        return trim(guildName)
    end

    if looks_like_root(source) then
        local activeGuildKey = source.activeGuildKey
        if not is_placeholder_guild_name(activeGuildKey) then
            return activeGuildKey
        end
    end

    local persistedGuild = (((source or {}).meta or {}).guildName)
    if not is_placeholder_guild_name(persistedGuild) then
        return persistedGuild
    end

    local runtimeGuild = (((ns.state or {}).db or {}).meta or {}).guildName
    if not is_placeholder_guild_name(runtimeGuild) then
        return runtimeGuild
    end

    local liveGuild = live_guild_name()
    if type(liveGuild) == "string" and liveGuild ~= "" then
        return liveGuild
    end

    if looks_like_root(source) then
        local firstGuildKey = next(source.guilds or {})
        if firstGuildKey ~= nil then
            return tostring(firstGuildKey)
        end
    end

    return "Unknown"
end

local function resolve_active_database(db, guildName)
    if looks_like_root(db) then
        local resolvedGuild = normalize_guild_name(resolve_guild_name(guildName, db))
        local root = migrations.Apply(db, resolvedGuild)
        return root.guilds[resolvedGuild], root
    end

    local resolvedGuild = normalize_guild_name(resolve_guild_name(guildName, db))
    if migrations and type(migrations.ApplyDatabase) == "function" then
        return migrations.ApplyDatabase(db, resolvedGuild), nil
    end

    return db, nil
end

local function fresh_bank_ledger(guildName)
    local freshLedger = (((defaults or {}).CreateDatabase and defaults.CreateDatabase(guildName) or {}).bankLedger) or {}
    if migrations and type(migrations.ApplyDatabase) == "function" then
        local normalizedLedgerDb = migrations.ApplyDatabase({
            meta = {
                guildName = guildName,
            },
            bankLedger = freshLedger,
        }, guildName)
        return normalizedLedgerDb.bankLedger or freshLedger
    end

    return freshLedger
end

local function parse_version(value)
    local major, minor, patch = string.match(trim(value), "^(%d+)%.(%d+)%.(%d+)")
    return tonumber(major), tonumber(minor), tonumber(patch)
end

local function version_at_least(addonVersion, targetVersion)
    local targetMajor, targetMinor, targetPatch = parse_version(targetVersion)
    local addonMajor, addonMinor, addonPatch = parse_version(addonVersion)
    if not targetMajor or not addonMajor then
        return addonVersion == targetVersion
    end
    if addonMajor ~= targetMajor then
        return addonMajor > targetMajor
    end
    if addonMinor ~= targetMinor then
        return addonMinor > targetMinor
    end
    return addonPatch >= targetPatch
end

local function versioned_token(configuredVersion)
    local tokenVersion = trim(configuredVersion)
    local addonVersion = trim(constants.ADDON_VERSION)
    if tokenVersion == "" then
        return nil
    end

    return version_at_least(addonVersion, tokenVersion) and tokenVersion or nil
end

local function versioned_ledger_reset_token()
    return versioned_token(constants.LEDGER_FORCE_CLEAR_VERSION)
end

local function versioned_money_ledger_dedupe_token()
    return versioned_token(constants.MONEY_LEDGER_DEDUPE_VERSION)
end

local function versioned_saved_variables_compact_token()
    return versioned_token(constants.SAVED_VARIABLES_COMPACT_VERSION)
end

local function clear_ledger_sync_state(db)
    db.syncState = type(db.syncState) == "table" and db.syncState or {}
    db.syncState.ledgerDigest = nil
    db.syncState.ledgerPeerDigests = nil
    db.syncState.ledgerBucketManifests = nil
    db.syncState.ledgerPendingBucketRequests = nil
    db.syncState.ledgerLastManifest = nil
    db.syncState.ledgerLastBucketRequest = nil
    db.syncState.ledgerLastBucketReply = nil
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

local function has_time_parts(row)
    row = type(row) == "table" and row or {}
    return row.year ~= nil or row.month ~= nil or row.day ~= nil or row.hour ~= nil or row.minute ~= nil
end

local function has_relative_time_parts(row)
    row = type(row) == "table" and row or {}
    if not has_time_parts(row) then
        return false
    end

    local year = tonumber(row.year)
    local month = tonumber(row.month)
    local day = tonumber(row.day)
    return not (year and year >= 1000 and month and day)
end

local function money_cleanup_time_key(row)
    row = type(row) == "table" and row or {}
    local year = tonumber(row.year)
    local month = tonumber(row.month)
    local day = tonumber(row.day)
    local hour = tonumber(row.hour)
    if has_relative_time_parts(row) then
        return raw_time_key(year, month, day, hour, nil)
    end

    return ""
end

local function visible_money_action(row)
    local rawAction = string.lower(trim((row or {}).action or (row or {}).type or (row or {}).rawType))
    if rawAction == "deposit" then
        return "Deposit"
    end
    if rawAction == "repair" then
        return "Repair"
    end
    if rawAction == "withdraw" or rawAction == "withdrawal" then
        return "Withdrawal"
    end

    return trim((row or {}).action) ~= "" and trim((row or {}).action) or "Withdrawal"
end

local function money_cleanup_key(row)
    row = type(row) == "table" and row or {}
    local timeKey = money_cleanup_time_key(row)
    if timeKey == "" then
        return ""
    end

    local legacyFingerprint = trim(row.legacyFingerprint)
    if legacyFingerprint:match("^unknown|") then
        return table.concat({ "legacy", legacyFingerprint }, "|")
    end

    return table.concat({
        timeKey,
        trim(row.who or "Unknown"),
        visible_money_action(row),
        tostring(tonumber(row.amountCopper or row.amount or 0) or 0),
    }, "|")
end

local function apply_versioned_money_ledger_dedupe_to_database(db)
    if type(db) ~= "table" then
        return db
    end

    local cleanupVersion = versioned_money_ledger_dedupe_token()
    if not cleanupVersion then
        return db
    end

    db.meta = db.meta or {}
    local schemaVersion = tonumber(db.meta.schemaVersion or 0) or 0
    local currentSchemaVersion = tonumber(constants.SCHEMA_VERSION or 0) or 0
    if currentSchemaVersion > 0 and schemaVersion > currentSchemaVersion then
        return db
    end

    if tostring(db.meta.moneyLedgerDedupedForVersion or "") == cleanupVersion then
        return db
    end

    local ledger = type(db.bankLedger) == "table" and db.bankLedger or nil
    if ledger and type(ledger.moneyLogs) == "table" then
        local seen = {}
        local cleaned = {}
        local removed = 0
        for _, row in ipairs(ledger.moneyLogs or {}) do
            local key = money_cleanup_key(row)
            if key == "" or seen[key] ~= true then
                if key ~= "" then
                    seen[key] = true
                end
                cleaned[#cleaned + 1] = row
            else
                removed = removed + 1
            end
        end

        if removed > 0 then
            ledger.moneyLogs = cleaned
            ledger.moneyFingerprints = {}
            ledger.moneySourceSnapshots = {}
            ledger.eventCounts = type(ledger.eventCounts) == "table" and ledger.eventCounts or {}
            ledger.eventCounts.money = {}
            clear_ledger_sync_state(db)
        end
    end

    db.meta.moneyLedgerDedupedForVersion = cleanupVersion
    return db
end

local function snapshot_timestamp(snapshot, scanId)
    snapshot = type(snapshot) == "table" and snapshot or {}
    local timestamp = tonumber(snapshot.scannedAt or snapshot.timestamp or 0) or 0
    if timestamp > 0 then
        return timestamp
    end

    return tonumber(tostring(scanId or ""):match("^(%d+)") or 0) or 0
end

local function compact_inventory_snapshots(db, options)
    if type(db) ~= "table" or type(db.snapshots) ~= "table" then
        return db
    end

    options = type(options) == "table" and options or {}
    local retentionLimit = tonumber(options.retentionLimit or constants.INVENTORY_SNAPSHOT_RETENTION_LIMIT or 3) or 3
    if retentionLimit <= 0 then
        retentionLimit = 1
    end

    local keep = {}
    local kept = 0
    local currentSnapshotId = db.currentSnapshotId
    if currentSnapshotId ~= nil and type(db.snapshots[currentSnapshotId]) == "table" then
        keep[currentSnapshotId] = true
        kept = kept + 1
    end

    local ordered = {}
    for scanId, snapshot in pairs(db.snapshots or {}) do
        if type(snapshot) == "table" then
            snapshot.searchCatalog = nil
            if keep[scanId] ~= true then
                ordered[#ordered + 1] = {
                    scanId = scanId,
                    scannedAt = snapshot_timestamp(snapshot, scanId),
                }
            end
        end
    end

    table.sort(ordered, function(left, right)
        if left.scannedAt ~= right.scannedAt then
            return left.scannedAt > right.scannedAt
        end
        return tostring(left.scanId or "") > tostring(right.scanId or "")
    end)

    for _, entry in ipairs(ordered) do
        if kept >= retentionLimit then
            break
        end
        keep[entry.scanId] = true
        kept = kept + 1
    end

    for scanId in pairs(db.snapshots or {}) do
        if keep[scanId] ~= true then
            db.snapshots[scanId] = nil
        end
    end

    if currentSnapshotId ~= nil and db.snapshots[currentSnapshotId] == nil then
        local firstKept = next(db.snapshots or {})
        db.currentSnapshotId = firstKept
    end

    return db
end

function store.CompactInventorySnapshots(db, options)
    return compact_inventory_snapshots(resolve_active_database(db or store.GetDatabase()), options)
end

local function apply_versioned_saved_variables_compaction_to_database(db)
    if type(db) ~= "table" then
        return db
    end

    local compactVersion = versioned_saved_variables_compact_token()
    if not compactVersion then
        return db
    end

    db.meta = db.meta or {}
    local schemaVersion = tonumber(db.meta.schemaVersion or 0) or 0
    local currentSchemaVersion = tonumber(constants.SCHEMA_VERSION or 0) or 0
    if currentSchemaVersion > 0 and schemaVersion > currentSchemaVersion then
        return db
    end

    compact_inventory_snapshots(db)
    db.meta.savedVariablesCompactedForVersion = compactVersion
    return db
end

local function apply_versioned_ledger_reset_to_database(db)
    if type(db) ~= "table" then
        return db
    end

    local resetVersion = versioned_ledger_reset_token()
    if not resetVersion then
        return db
    end

    db.meta = db.meta or {}
    local schemaVersion = tonumber(db.meta.schemaVersion or 0) or 0
    local currentSchemaVersion = tonumber(constants.SCHEMA_VERSION or 0) or 0
    if currentSchemaVersion > 0 and schemaVersion > currentSchemaVersion then
        return db
    end

    if tostring(db.meta.ledgerClearedForVersion or "") == resetVersion then
        return db
    end

    db.bankLedger = fresh_bank_ledger(db.meta.guildName or "Unknown")
    clear_ledger_sync_state(db)
    db.meta.ledgerClearedForVersion = resetVersion
    return db
end

local function apply_versioned_ledger_reset(db)
    if looks_like_root(db) then
        for guildKey, guildDb in pairs(db.guilds or {}) do
            if type(guildDb) == "table" then
                guildDb.meta = guildDb.meta or {}
                guildDb.meta.guildName = guildDb.meta.guildName or tostring(guildKey)
                apply_versioned_ledger_reset_to_database(guildDb)
                apply_versioned_money_ledger_dedupe_to_database(guildDb)
                apply_versioned_saved_variables_compaction_to_database(guildDb)
            end
        end
        return db
    end

    apply_versioned_ledger_reset_to_database(db)
    apply_versioned_money_ledger_dedupe_to_database(db)
    return apply_versioned_saved_variables_compaction_to_database(db)
end

local function select_runtime_source(guildName)
    local runtime = _G.GBankManagerDB
    if type(runtime) == "table" and next(runtime) ~= nil then
        return runtime
    end

    local rootState = (ns.state or {}).dbRoot
    if type(rootState) == "table" and next(rootState) ~= nil then
        return rootState
    end

    local stateDb = (ns.state or {}).db
    if looks_like_database(stateDb) and next(stateDb) ~= nil then
        return stateDb
    end

    if defaults and type(defaults.CreateDatabaseRoot) == "function" then
        return defaults.CreateDatabaseRoot(resolve_guild_name(guildName))
    end

    return {}
end

function store.CreateFreshDatabase(guildName)
    local resolvedGuild = normalize_guild_name(resolve_guild_name(guildName))
    if migrations and type(migrations.ApplyDatabase) == "function" then
        return apply_versioned_ledger_reset(migrations.ApplyDatabase(defaults.CreateDatabase(resolvedGuild), resolvedGuild))
    end

    return apply_versioned_ledger_reset(defaults.CreateDatabase(resolvedGuild))
end

function store.IsPlaceholderGuildName(guildName)
    return is_placeholder_guild_name(guildName)
end

function store.Normalize(db, guildName)
    if db == nil then
        if defaults and type(defaults.CreateDatabaseRoot) == "function" then
            return apply_versioned_ledger_reset(migrations.Apply(defaults.CreateDatabaseRoot(resolve_guild_name(guildName)), guildName))
        end

        return apply_versioned_ledger_reset(migrations.Apply({}, guildName))
    end

    return apply_versioned_ledger_reset(migrations.Apply(db, resolve_guild_name(guildName, db)))
end

function store.GetDatabase(guildName)
    local runtime = store.Normalize(select_runtime_source(guildName), guildName)
    local activeDb = resolve_active_database(runtime, guildName)
    local bankLedger = ns.modules.bankLedger
    if bankLedger and type(bankLedger.PruneRetention) == "function" then
        local logsHistory = (((activeDb or {}).ui or {}).logsHistorySettings or {})
        local shouldPruneLedger = tostring(logsHistory.ledgerRetention or "indefinite") ~= "indefinite"
        local shouldPruneHistory = tostring(logsHistory.historyRetention or "indefinite") ~= "indefinite"
        if shouldPruneLedger or shouldPruneHistory then
            local now = type(_G.time) == "function" and (_G.time() or 0) or 0
            bankLedger.PruneRetention(activeDb, now)
        end
    end
    _G.GBankManagerDB = runtime
    ns.state.dbRoot = looks_like_root(runtime) and runtime or nil
    ns.state.db = activeDb
    return activeDb
end

function store.GetUiState(db)
    db = resolve_active_database(db or store.GetDatabase())
    return db.ui
end

function store.GetInventoryColumnWidths(db)
    return store.GetUiState(db).inventoryColumnWidths
end

function store.GetMinimumSettings(db)
    return store.GetUiState(db).minimumSettings
end

function store.GetAppearanceSettings(db)
    return store.GetUiState(db).appearance
end

function store.GetMinimumItemCatalog(db)
    return store.GetUiState(db).minimumItemCatalog
end

function store.GetExportSettings(db)
    return store.GetUiState(db).exportSettings
end

function store.GetCurrentSnapshot(db)
    db = resolve_active_database(db or store.GetDatabase())
    if db.currentSnapshotId ~= nil then
        return (db.snapshots or {})[db.currentSnapshotId] or { items = {} }
    end

    return { items = {} }
end

function store.GetAuthPolicy(db)
    db = resolve_active_database(db or store.GetDatabase())
    return db.auth
end

function store.ClearGuildBankLogData(db)
    db = resolve_active_database(db or store.GetDatabase())
    local guildName = (((db or {}).meta or {}).guildName) or "Unknown"
    db.bankLedger = fresh_bank_ledger(guildName)
    return db.bankLedger
end

function store.ClearGuildBankInventoryData(db)
    db = resolve_active_database(db or store.GetDatabase())
    db.snapshots = {}
    db.currentSnapshotId = nil
    db.changeLog = {}
    db.meta = db.meta or {}
    db.meta.updatedAt = 0
    db.meta.lastScanSequence = 0
    return db
end

local function request_is_completed(request)
    request = request or {}
    local approval = tostring(request.approval or "")
    local fulfillment = tostring(request.fulfillment or "")
    return approval == "REJECTED"
        or approval == "CANCELED"
        or (approval == "APPROVED" and fulfillment == "FULFILLED")
end

function store.ClearCompletedRequestHistory(db)
    db = resolve_active_database(db or store.GetDatabase())
    local clearedRequestIds = {}
    local keptRequests = {}
    for _, request in ipairs(db.requests or {}) do
        if request_is_completed(request) then
            clearedRequestIds[tostring(request.requestId or "")] = true
        else
            keptRequests[#keptRequests + 1] = request
        end
    end
    db.requests = keptRequests

    local keptAudit = {}
    for _, entry in ipairs(db.auditLog or {}) do
        local requestId = tostring(entry.requestId or "")
        if not (tostring(entry.category or "") == "REQUEST" and clearedRequestIds[requestId] == true) then
            keptAudit[#keptAudit + 1] = entry
        end
    end
    db.auditLog = keptAudit
    return db
end

ns.data.store = store
ns.modules.store = store

return store
