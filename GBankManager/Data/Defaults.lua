local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local defaults = ns.data.defaults or ns.modules.defaults or {}

function defaults.CreateDefaultExportTemplate()
    return {
        delimiter = "|",
        includeHeader = true,
        fields = { "itemID", "itemName", "totalToBuy" },
    }
end

function defaults.CreateDefaultAuthPolicy()
    return {
        version = 1,
        revision = 0,
        updatedAt = 0,
        updatedBy = "",
        updatedByHash = nil,
        updatedByRankIndex = nil,
        restockDefault = nil,
        guildPolicyString = "",
        guildPolicySource = "local",
        rankMetadata = {},
        capabilities = {
            full_ui = {},
            request_submit = {},
            request_approve = {},
            request_reject = {},
            request_edit = {},
            request_fulfill = {},
            request_reopen = {},
            minimum_add = {},
            minimum_edit = {},
            minimum_delete = {},
            auth_manage = {},
            request_delete = {},
        },
        blacklist = {},
        blacklistHashes = {},
        blacklistDirectory = {},
        blacklistRosterDirectory = {},
    }
end

function defaults.CreateDatabase(guildName)
    return {
        meta = {
            schemaVersion = 1,
            guildName = guildName or "Unknown",
            createdAt = 0,
            updatedAt = 0,
        },
        snapshots = {},
        currentSnapshotId = nil,
        changeLog = {},
        auditLog = {},
        minimums = {},
        oneTimeTargets = {},
        requests = {},
        exportTemplates = {},
        bankLedger = {
            itemLogs = {},
            moneyLogs = {},
            itemFingerprints = {},
            moneyFingerprints = {},
            itemSourceSnapshots = {},
            moneySourceSnapshots = {},
            nextEntrySequence = 0,
            lastScanAt = 0,
            lastItemScanAt = 0,
            lastMoneyScanAt = 0,
        },
        auth = defaults.CreateDefaultAuthPolicy(),
        ui = {
            inventoryColumnWidths = {},
            appearance = {
                themePreset = "generic_wow",
                shellScale = 1,
                tableDensity = 1,
                shellOpacity = 0.96,
                modalOpacity = 1,
                showMinimapButton = true,
                minimapAngle = 315,
            },
            minimumSettings = {
                defaultQuantity = 100,
                criticalThresholdPercent = 50,
            },
            logsHistorySettings = {
                ledgerRetention = "indefinite",
                historyRetention = "indefinite",
                ledgerScanIntervalSeconds = 300,
                repairThresholdGold = 5000,
                muteSilvermoonCitizen = false,
            },
            minimumItemCatalog = {},
            exportSettings = {
                selectedPreset = "Spreadsheet",
                shoppingListName = "GBankManager",
                customTemplate = defaults.CreateDefaultExportTemplate(),
                manualShoppingListPosition = nil,
            },
        },
        syncState = {
            lastSyncAt = 0,
        },
        testing = {
            liveSmoke = {
                runAt = 0,
                status = "NEVER",
                summary = "",
                results = {},
            },
            inGameUnit = {
                runAt = 0,
                status = "NEVER",
                summary = "",
                results = {},
            },
        },
    }
end

ns.data.defaults = defaults
ns.modules.defaults = defaults

return defaults
