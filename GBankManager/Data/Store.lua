local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local store = ns.data.store or ns.modules.store or {}

local defaults = ns.data.defaults or ns.modules.defaults
local migrations = ns.data.migrations or ns.modules.migrations

local function is_db_empty(db)
    db = db or {}

    if db.currentSnapshotId ~= nil then
        return false
    end

    if next(db.snapshots or {}) ~= nil then
        return false
    end

    if next(db.requests or {}) ~= nil then
        return false
    end

    if next(db.minimums or {}) ~= nil then
        return false
    end

    if next(db.oneTimeTargets or {}) ~= nil then
        return false
    end

    return true
end

function store.CreateFreshDatabase(guildName)
    return migrations.Apply(defaults.CreateDatabase(guildName))
end

function store.Normalize(db, guildName)
    if db == nil then
        return store.CreateFreshDatabase(guildName)
    end

    if guildName ~= nil then
        db.meta = db.meta or {}
        db.meta.guildName = db.meta.guildName or guildName
    end

    return migrations.Apply(db)
end

function store.GetDatabase(guildName)
    local runtime = _G.GBankManagerDB or {}
    local stateDb = ns.state.db or {}

    if runtime ~= stateDb and (is_db_empty(runtime) and not is_db_empty(stateDb)) then
        runtime = stateDb
    elseif runtime == nil or next(runtime) == nil then
        runtime = stateDb
    end

    runtime = store.Normalize(runtime, guildName)
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

function store.GetUiState(db)
    db = store.Normalize(db or store.GetDatabase())
    return db.ui
end

function store.GetInventoryColumnWidths(db)
    return store.GetUiState(db).inventoryColumnWidths
end

function store.GetMinimumSettings(db)
    return store.GetUiState(db).minimumSettings
end

function store.GetMinimumItemCatalog(db)
    return store.GetUiState(db).minimumItemCatalog
end

function store.GetExportSettings(db)
    return store.GetUiState(db).exportSettings
end

function store.GetCurrentSnapshot(db)
    db = store.Normalize(db or store.GetDatabase())
    if db.currentSnapshotId ~= nil then
        return (db.snapshots or {})[db.currentSnapshotId] or { items = {} }
    end

    return { items = {} }
end

function store.GetAuthPolicy(db)
    db = store.Normalize(db or store.GetDatabase())
    return db.auth
end

ns.data.store = store
ns.modules.store = store

return store
