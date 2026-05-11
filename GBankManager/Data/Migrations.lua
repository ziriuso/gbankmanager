local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.constants = ns.constants or {}
ns.data = ns.data or {}

local migrations = ns.data.migrations or ns.modules.migrations or {}
local latestSchemaVersion = ns.constants.SCHEMA_VERSION or 1

local function ensure_v1_shape(db)
    db.meta = db.meta or {}
    db.meta.schemaVersion = latestSchemaVersion
    db.meta.guildName = db.meta.guildName or "Unknown"
    db.meta.createdAt = db.meta.createdAt or 0
    db.meta.updatedAt = db.meta.updatedAt or 0
    db.snapshots = db.snapshots or {}
    db.currentSnapshotId = db.currentSnapshotId
    db.changeLog = db.changeLog or {}
    db.minimums = db.minimums or {}
    db.oneTimeTargets = db.oneTimeTargets or {}
    db.requests = db.requests or {}
    db.exportTemplates = db.exportTemplates or {}
    db.syncState = db.syncState or {}
    db.syncState.lastSyncAt = db.syncState.lastSyncAt or 0
    return db
end

function migrations.Apply(db)
    db = db or {}
    local schemaVersion = 0

    if db.meta and type(db.meta.schemaVersion) == "number" then
        schemaVersion = db.meta.schemaVersion
    end

    if schemaVersion < 1 then
        ensure_v1_shape(db)
    else
        ensure_v1_shape(db)
    end

    return db
end

ns.data.migrations = migrations
ns.modules.migrations = migrations

return migrations
