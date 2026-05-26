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
    local bankLedger = ns.modules.bankLedger
    if bankLedger and type(bankLedger.PruneRetention) == "function" then
        local logsHistory = (((runtime or {}).ui or {}).logsHistorySettings or {})
        local shouldPruneLedger = tostring(logsHistory.ledgerRetention or "indefinite") ~= "indefinite"
        local shouldPruneHistory = tostring(logsHistory.historyRetention or "indefinite") ~= "indefinite"
        if shouldPruneLedger or shouldPruneHistory then
            local now = type(_G.time) == "function" and (_G.time() or 0) or 0
            bankLedger.PruneRetention(runtime, now)
        end
    end
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

function store.ClearGuildBankLogData(db)
    db = store.Normalize(db or store.GetDatabase())
    local guildName = (((db or {}).meta or {}).guildName) or "Unknown"
    local freshLedger = (((defaults or {}).CreateDatabase and defaults.CreateDatabase(guildName) or {}).bankLedger) or {}
    db.bankLedger = migrations.Apply({
        bankLedger = freshLedger,
    }).bankLedger or freshLedger
    return db.bankLedger
end

function store.ClearGuildBankInventoryData(db)
    db = store.Normalize(db or store.GetDatabase())
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
    db = store.Normalize(db or store.GetDatabase())
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
