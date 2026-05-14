local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local scannerEvents = ns.modules.guildBankScannerEvents or {}

local REGISTERED_EVENTS = {
    "GUILDBANKBAGSLOTS_CHANGED",
}

function scannerEvents.GetRegisteredEvents()
    return REGISTERED_EVENTS
end

function scannerEvents.HandleEvent(event, ...)
    if event ~= "GUILDBANKBAGSLOTS_CHANGED" then
        return false
    end

    local scanner = ns.modules.scanner
    if type(scanner) ~= "table" or not scanner.scanInProgress or type(scanner.OnGuildBankSlotsChanged) ~= "function" then
        return false
    end

    scanner.OnGuildBankSlotsChanged(...)
    return true
end

ns.modules.guildBankScannerEvents = scannerEvents

return scannerEvents
