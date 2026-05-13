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
        updatedByRankIndex = nil,
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
        },
        blacklist = {},
        blacklistHashes = {},
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
        auth = defaults.CreateDefaultAuthPolicy(),
        ui = {
            inventoryColumnWidths = {},
            minimumSettings = {
                defaultQuantity = 100,
            },
            minimumItemCatalog = {},
            exportSettings = {
                selectedPreset = "Spreadsheet",
                shoppingListName = "GBankManager",
                customTemplate = defaults.CreateDefaultExportTemplate(),
            },
        },
        syncState = {
            lastSyncAt = 0,
        },
    }
end

ns.data.defaults = defaults
ns.modules.defaults = defaults

return defaults
