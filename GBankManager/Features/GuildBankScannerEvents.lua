local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local scannerEvents = ns.modules.guildBankScannerEvents or {}

local REGISTERED_EVENTS = {
    "GUILDBANKFRAME_OPENED",
    "GUILDBANKFRAME_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "GUILDBANK_UPDATE_TABS",
    "GUILDBANKBAGSLOTS_CHANGED",
    "GUILDBANKLOG_UPDATE",
}

function scannerEvents.GetRegisteredEvents()
    return REGISTERED_EVENTS
end

function scannerEvents.HandleEvent(event, ...)
    local scanner = ns.modules.scanner
    if type(scanner) ~= "table" then
        return false
    end

    local guildBankerInteractionType = (((_G.Enum or {}).PlayerInteractionType or {}).GuildBanker)

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if guildBankerInteractionType == nil or select(1, ...) ~= guildBankerInteractionType then
            return false
        end

        if scanner.guildBankOpen == true then
            return true
        end

        if type(scanner.OnGuildBankOpened) ~= "function" then
            return false
        end

        scanner.OnGuildBankOpened(...)
        return true
    end

    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if guildBankerInteractionType == nil or select(1, ...) ~= guildBankerInteractionType then
            return false
        end

        if type(scanner.OnGuildBankClosed) ~= "function" then
            return false
        end

        scanner.OnGuildBankClosed(...)
        return true
    end

    if event == "GUILDBANKFRAME_OPENED" then
        if scanner.guildBankOpen == true then
            return true
        end

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

    if event == "GUILDBANKFRAME_CLOSED" then
        if type(scanner.OnGuildBankClosed) ~= "function" then
            return false
        end

        scanner.OnGuildBankClosed(...)
        return true
    end

    if event == "GUILDBANKBAGSLOTS_CHANGED" then
        if type(scanner.OnGuildBankSlotsChanged) ~= "function" then
            return false
        end

        scanner.OnGuildBankSlotsChanged(...)
        return true
    end

    if event == "GUILDBANKLOG_UPDATE" then
        if type(scanner.OnGuildBankLogUpdated) ~= "function" then
            return false
        end

        scanner.OnGuildBankLogUpdated(...)
        return true
    end

    return false
end

ns.modules.guildBankScannerEvents = scannerEvents

return scannerEvents
