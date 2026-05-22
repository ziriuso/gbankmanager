local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local scannerEvents = ns.modules.guildBankScannerEvents or {}

local REGISTERED_EVENTS = {
    "GUILDBANKFRAME_OPENED",
    "GUILDBANK_UPDATE_TABS",
    "GUILDBANKBAGSLOTS_CHANGED",
}

function scannerEvents.GetRegisteredEvents()
    return REGISTERED_EVENTS
end

function scannerEvents.HandleEvent(event, ...)
    local scanner = ns.modules.scanner
    if type(scanner) ~= "table" then
        return false
    end

    if event == "GUILDBANKFRAME_OPENED" then
        if type(scanner.OnGuildBankOpened) ~= "function" then
            return false
        end

        scanner.OnGuildBankOpened(...)
        return true
    end

    if event == "GUILDBANK_UPDATE_TABS" then
        if type(scanner.OnGuildBankTabsUpdated) ~= "function" then
            return false
        end

        scanner.OnGuildBankTabsUpdated(...)
        return true
    end

    if event == "GUILDBANKBAGSLOTS_CHANGED" then
        if type(scanner.OnGuildBankSlotsChanged) ~= "function" then
            return false
        end

        scanner.OnGuildBankSlotsChanged(...)
        return true
    end

    return false
end

ns.modules.guildBankScannerEvents = scannerEvents

return scannerEvents
