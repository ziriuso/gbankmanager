local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.constants = ns.constants or {}
ns.data = ns.data or {}

local migrations = ns.data.migrations or ns.modules.migrations or {}
local latestSchemaVersion = ns.constants.SCHEMA_VERSION or 1
local defaults = ns.data.defaults or ns.modules.defaults or {}
local styleTokens = ns.modules.styleTokens or {}

local function normalize_guild_name(guildName)
    local resolvedGuild = tostring(guildName or "")
    if resolvedGuild == "" then
        return "Unknown"
    end

    return resolvedGuild
end

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function ensure_v1_shape(db, guildName)
    db = ensure_table(db)
    db.meta = ensure_table(db.meta)
    db.meta.schemaVersion = latestSchemaVersion
    db.meta.guildName = normalize_guild_name(db.meta.guildName or guildName)
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
    db.ui.logsHistorySettings = ensure_table(db.ui.logsHistorySettings)
    db.ui.logsHistorySettings.ledgerRetention = db.ui.logsHistorySettings.ledgerRetention or "indefinite"
    db.ui.logsHistorySettings.historyRetention = db.ui.logsHistorySettings.historyRetention or "indefinite"
    db.ui.logsHistorySettings.ledgerScanIntervalSeconds = math.max(300, tonumber(db.ui.logsHistorySettings.ledgerScanIntervalSeconds or 300) or 300)
    db.ui.logsHistorySettings.repairThresholdGold = math.max(0, tonumber(db.ui.logsHistorySettings.repairThresholdGold or 5000) or 5000)
    db.ui.logsHistorySettings.muteSilvermoonCitizen = db.ui.logsHistorySettings.muteSilvermoonCitizen == true
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

local function current_schema_version(db)
    if type(db.meta) == "table" and type(db.meta.schemaVersion) == "number" then
        return db.meta.schemaVersion
    end

    return 0
end

local function apply_database(db, guildName)
    db = ensure_table(db)
    local schemaVersion = current_schema_version(db)

    if schemaVersion > latestSchemaVersion then
        return db
    end

    return ensure_v1_shape(db, guildName)
end

local function resolve_root_guild_key(root, guildName)
    local resolvedGuild = normalize_guild_name(guildName or root.activeGuildKey)
    if resolvedGuild ~= "Unknown" then
        return resolvedGuild
    end

    local firstGuildKey = next(root.guilds or {})
    if firstGuildKey ~= nil then
        return normalize_guild_name(firstGuildKey)
    end

    return resolvedGuild
end

local function wrap_legacy_database(db, guildName)
    local resolvedGuild = normalize_guild_name(guildName or ((type(db.meta) == "table" and db.meta.guildName) or nil))
    local legacyDb = apply_database(db, resolvedGuild)
    legacyDb.meta.guildName = resolvedGuild
    return {
        activeGuildKey = resolvedGuild,
        guilds = {
            [resolvedGuild] = legacyDb,
        },
    }
end

function migrations.ApplyDatabase(db, guildName)
    return apply_database(db, guildName)
end

function migrations.Apply(db, guildName)
    db = ensure_table(db)
    if type(db.guilds) ~= "table" then
        local schemaVersion = current_schema_version(db)
        if schemaVersion > latestSchemaVersion then
            return db
        end

        return wrap_legacy_database(db, guildName)
    end

    local resolvedGuild = resolve_root_guild_key(db, guildName)
    local normalizedGuilds = {}

    for key, guildDb in pairs(db.guilds) do
        local normalizedKey = normalize_guild_name(key)
        normalizedGuilds[normalizedKey] = apply_database(guildDb, normalizedKey)
    end

    if normalizedGuilds[resolvedGuild] == nil then
        local freshDb = type(defaults.CreateDatabase) == "function" and defaults.CreateDatabase(resolvedGuild) or {}
        normalizedGuilds[resolvedGuild] = apply_database(freshDb, resolvedGuild)
    end

    if next(normalizedGuilds) == nil then
        return db
    end

    db.activeGuildKey = resolvedGuild
    db.guilds = normalizedGuilds
    return db
end

ns.data.migrations = migrations
ns.modules.migrations = migrations

return migrations
