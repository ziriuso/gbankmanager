local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.constants = ns.constants or {}
ns.data = ns.data or {}

local migrations = ns.data.migrations or ns.modules.migrations or {}
local latestSchemaVersion = ns.constants.SCHEMA_VERSION or 1
local defaults = ns.data.defaults or ns.modules.defaults or {}

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
    db.auditLog = ensure_table(db.auditLog)
    db.minimums = ensure_table(db.minimums)
    db.oneTimeTargets = ensure_table(db.oneTimeTargets)
    db.requests = ensure_table(db.requests)
    db.exportTemplates = ensure_table(db.exportTemplates)
    db.auth = ensure_table(db.auth)
    db.auth.version = tonumber(db.auth.version or 1) or 1
    db.auth.revision = tonumber(db.auth.revision or 0) or 0
    db.auth.updatedAt = tonumber(db.auth.updatedAt or 0) or 0
    db.auth.updatedBy = db.auth.updatedBy or ""
    db.auth.updatedByRankIndex = db.auth.updatedByRankIndex
    db.auth.guildPolicyString = db.auth.guildPolicyString or ""
    db.auth.guildPolicySource = db.auth.guildPolicySource or "local"
    db.auth.rankMetadata = ensure_table(db.auth.rankMetadata)
    db.auth.capabilities = ensure_table(db.auth.capabilities)
    for _, capability in ipairs({
        "full_ui",
        "request_submit",
        "request_approve",
        "request_reject",
        "request_edit",
        "request_fulfill",
        "request_reopen",
        "minimum_add",
        "minimum_edit",
        "minimum_delete",
        "auth_manage",
    }) do
        db.auth.capabilities[capability] = ensure_table(db.auth.capabilities[capability])
    end
    db.auth.blacklist = ensure_table(db.auth.blacklist)
    db.auth.blacklistHashes = ensure_table(db.auth.blacklistHashes)
    db.ui = ensure_table(db.ui)
    db.ui.inventoryColumnWidths = ensure_table(db.ui.inventoryColumnWidths)
    db.ui.minimumSettings = ensure_table(db.ui.minimumSettings)
    db.ui.minimumSettings.defaultQuantity = tonumber(db.ui.minimumSettings.defaultQuantity or 100) or 100
    db.ui.minimumItemCatalog = ensure_table(db.ui.minimumItemCatalog)
    db.ui.exportSettings = ensure_table(db.ui.exportSettings)
    db.ui.exportSettings.selectedPreset = db.ui.exportSettings.selectedPreset or "Spreadsheet"
    db.ui.exportSettings.shoppingListName = db.ui.exportSettings.shoppingListName or "GBankManager"
    db.ui.exportSettings.customTemplate = ensure_table(db.ui.exportSettings.customTemplate)
    db.ui.exportSettings.customTemplate.delimiter = db.ui.exportSettings.customTemplate.delimiter or "|"
    if db.ui.exportSettings.customTemplate.includeHeader == nil then
        db.ui.exportSettings.customTemplate.includeHeader = true
    end
    if type(db.ui.exportSettings.customTemplate.fields) ~= "table" or #db.ui.exportSettings.customTemplate.fields == 0 then
        local template = type(defaults.CreateDefaultExportTemplate) == "function" and defaults.CreateDefaultExportTemplate() or {
            fields = { "itemID", "itemName", "totalToBuy" },
        }
        db.ui.exportSettings.customTemplate.fields = template.fields
    end
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
