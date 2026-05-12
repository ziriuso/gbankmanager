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
        ui = {
            inventoryColumnWidths = {},
            exportSettings = {
                selectedPreset = "Spreadsheet",
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
