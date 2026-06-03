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

local function versioned_ledger_reset_token()
    local resetVersion = trim(constants.LEDGER_FORCE_CLEAR_VERSION)
    local addonVersion = trim(constants.ADDON_VERSION)
    if resetVersion == "" then
        return nil
    end

    local function parse_version(value)
        local major, minor, patch = string.match(trim(value), "^(%d+)%.(%d+)%.(%d+)")
        return tonumber(major), tonumber(minor), tonumber(patch)
    end

    local resetMajor, resetMinor, resetPatch = parse_version(resetVersion)
    local addonMajor, addonMinor, addonPatch = parse_version(addonVersion)
    if not resetMajor or not addonMajor then
        return addonVersion == resetVersion and resetVersion or nil
    end
    if addonMajor < resetMajor then
        return nil
    end
    if addonMajor == resetMajor and addonMinor < resetMinor then
        return nil
    end
    if addonMajor == resetMajor and addonMinor == resetMinor and addonPatch < resetPatch then
        return nil
    end
    return resetVersion
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
            end
        end
        return db
    end

    return apply_versioned_ledger_reset_to_database(db)
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
