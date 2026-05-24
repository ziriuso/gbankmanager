local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.constants = ns.constants or {}
ns.data = ns.data or {}

local migrations = ns.data.migrations or ns.modules.migrations or {}
local latestSchemaVersion = ns.constants.SCHEMA_VERSION or 1
local defaults = ns.data.defaults or ns.modules.defaults or {}
local styleTokens = ns.modules.styleTokens or {}

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
    db.meta.lastScanSequence = tonumber(db.meta.lastScanSequence or 0) or 0
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
    db.auth.updatedByHash = db.auth.updatedByHash or nil
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
        "request_delete",
    }) do
        db.auth.capabilities[capability] = ensure_table(db.auth.capabilities[capability])
    end
    db.auth.blacklist = ensure_table(db.auth.blacklist)
    db.auth.blacklistHashes = ensure_table(db.auth.blacklistHashes)
    db.auth.blacklistDirectory = ensure_table(db.auth.blacklistDirectory)
    db.auth.blacklistRosterDirectory = ensure_table(db.auth.blacklistRosterDirectory)
    db.ui = ensure_table(db.ui)
    db.ui.inventoryColumnWidths = ensure_table(db.ui.inventoryColumnWidths)
    db.ui.appearance = ensure_table(db.ui.appearance)
    if type(styleTokens.NormalizePresetKey) == "function" then
        db.ui.appearance.themePreset = styleTokens.NormalizePresetKey(db.ui.appearance.themePreset or "generic_wow")
    else
        db.ui.appearance.themePreset = db.ui.appearance.themePreset or "generic_wow"
    end
    db.ui.appearance.shellScale = tonumber(db.ui.appearance.shellScale or 1) or 1
    db.ui.appearance.tableDensity = tonumber(db.ui.appearance.tableDensity or 1) or 1
    db.ui.appearance.shellOpacity = tonumber(db.ui.appearance.shellOpacity or 0.96) or 0.96
    db.ui.appearance.modalOpacity = tonumber(db.ui.appearance.modalOpacity or 1) or 1
    if db.ui.appearance.showMinimapButton == nil then
        db.ui.appearance.showMinimapButton = true
    else
        db.ui.appearance.showMinimapButton = db.ui.appearance.showMinimapButton == true
    end
    db.ui.appearance.minimapAngle = tonumber(db.ui.appearance.minimapAngle or 315) or 315
    db.ui.minimumSettings = ensure_table(db.ui.minimumSettings)
    db.ui.minimumSettings.defaultQuantity = tonumber(db.ui.minimumSettings.defaultQuantity or 100) or 100
    db.ui.minimumSettings.criticalThresholdPercent = tonumber(db.ui.minimumSettings.criticalThresholdPercent or 50) or 50
    db.ui.minimumItemCatalog = ensure_table(db.ui.minimumItemCatalog)
    db.ui.exportSettings = ensure_table(db.ui.exportSettings)
    db.ui.exportSettings.selectedPreset = db.ui.exportSettings.selectedPreset or "Spreadsheet"
    db.ui.exportSettings.shoppingListName = db.ui.exportSettings.shoppingListName or "GBankManager"
    if type(db.ui.exportSettings.manualShoppingListPosition) ~= "table" then
        db.ui.exportSettings.manualShoppingListPosition = nil
    end
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
    db.testing = ensure_table(db.testing)
    db.testing.liveSmoke = ensure_table(db.testing.liveSmoke)
    db.testing.liveSmoke.runAt = tonumber(db.testing.liveSmoke.runAt or 0) or 0
    db.testing.liveSmoke.status = db.testing.liveSmoke.status or "NEVER"
    db.testing.liveSmoke.summary = db.testing.liveSmoke.summary or ""
    db.testing.liveSmoke.results = ensure_table(db.testing.liveSmoke.results)
    db.testing.inGameUnit = ensure_table(db.testing.inGameUnit)
    db.testing.inGameUnit.runAt = tonumber(db.testing.inGameUnit.runAt or 0) or 0
    db.testing.inGameUnit.status = db.testing.inGameUnit.status or "NEVER"
    db.testing.inGameUnit.summary = db.testing.inGameUnit.summary or ""
    db.testing.inGameUnit.results = ensure_table(db.testing.inGameUnit.results)
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
