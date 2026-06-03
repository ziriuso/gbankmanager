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

ns.constants.ADDON_VERSION = ns.constants.ADDON_VERSION or addon_metadata("Version") or "1.1.1"
ns.constants.LEDGER_FORCE_CLEAR_VERSION = ns.constants.LEDGER_FORCE_CLEAR_VERSION or "1.1.1"

return ns.constants
