local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.constants = ns.constants or {}
ns.data = ns.data or {}

local migrations = ns.data.migrations or ns.modules.migrations or {}
local latestSchemaVersion = ns.constants.SCHEMA_VERSION or 1

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function ensure_v1_shape(db)
    db = ensure_table(db)
    db.meta = ensure_table(db.meta)
    db.meta.schemaVersion = latestSchemaVersion
    db.meta.guildName = db.meta.guildName or "Unknown"
    db.meta.createdAt = db.meta.createdAt or 0
    db.meta.updatedAt = db.meta.updatedAt or 0
    db.snapshots = ensure_table(db.snapshots)
    db.currentSnapshotId = db.currentSnapshotId
    db.changeLog = ensure_table(db.changeLog)
    db.minimums = ensure_table(db.minimums)
    db.oneTimeTargets = ensure_table(db.oneTimeTargets)
    db.requests = ensure_table(db.requests)
    db.exportTemplates = ensure_table(db.exportTemplates)
    db.syncState = ensure_table(db.syncState)
    db.syncState.lastSyncAt = db.syncState.lastSyncAt or 0
    return db
end

function migrations.Apply(db)
    db = ensure_table(db)
    local schemaVersion = 0

    if type(db.meta) == "table" and type(db.meta.schemaVersion) == "number" then
        schemaVersion = db.meta.schemaVersion
    end

    if schemaVersion < 1 then
        return ensure_v1_shape(db)
    end

    if schemaVersion > latestSchemaVersion then
        return db
    end

    return ensure_v1_shape(db)
end

ns.data.migrations = migrations
ns.modules.migrations = migrations

return migrations
