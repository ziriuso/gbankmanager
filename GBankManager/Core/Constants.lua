local _, ns = ...

ns = ns or {}
ns.constants = ns.constants or {}

ns.constants.SCHEMA_VERSION = 1
ns.constants.ADDON_PREFIX = "GBankManager"
ns.constants.INTERACTION_TYPE = 10
ns.constants.SLOTS_PER_TAB = 98

local function addon_metadata(fieldName)
    local getter = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getter) ~= "function" then
        return nil
    end

    local ok, value = pcall(getter, ns.addonName or "GBankManager", fieldName)
    if ok and tostring(value or "") ~= "" then
        return tostring(value)
    end

    return nil
end

ns.constants.ADDON_VERSION = ns.constants.ADDON_VERSION or addon_metadata("Version") or "1.3.1"
ns.constants.LEDGER_FORCE_CLEAR_VERSION = ns.constants.LEDGER_FORCE_CLEAR_VERSION or "1.2.0"
ns.constants.MONEY_LEDGER_DEDUPE_VERSION = ns.constants.MONEY_LEDGER_DEDUPE_VERSION or "1.2.3-money-v7"
ns.constants.SAVED_VARIABLES_COMPACT_VERSION = ns.constants.SAVED_VARIABLES_COMPACT_VERSION or "1.2.3-snapshot-v3"
ns.constants.INVENTORY_SNAPSHOT_RETENTION_LIMIT = ns.constants.INVENTORY_SNAPSHOT_RETENTION_LIMIT or 3
ns.constants.INVENTORY_CHANGELOG_RETENTION_LIMIT = ns.constants.INVENTORY_CHANGELOG_RETENTION_LIMIT or 500
ns.constants.LEDGER_PROTOCOL_VERSION = ns.constants.LEDGER_PROTOCOL_VERSION or 3

return ns.constants
