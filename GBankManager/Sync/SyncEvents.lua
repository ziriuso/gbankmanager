local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local syncEvents = ns.modules.syncEvents or {}
local transport = ns.modules.syncTransport or {}
local codec = ns.modules.syncCodec or {}

local REGISTERED_EVENTS = {
    "PLAYER_LOGIN",
    "CHAT_MSG_ADDON",
}

function syncEvents.GetRegisteredEvents()
    return REGISTERED_EVENTS
end

function syncEvents.HandleEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        if _G.C_ChatInfo and type(_G.C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
            _G.C_ChatInfo.RegisterAddonMessagePrefix("GBankManager")
        end

        if type(transport.Send) == "function" then
            transport.Send("GUILD", "GUILD", {
                type = "SYNC_HELLO",
                updatedAt = _G.time(),
                payload = _G.UnitName("player"),
            })
        end

        return true
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, payload, distribution, sender = ...
        if prefix ~= "GBankManager" then
            return false
        end

        ns.state.lastSyncMessage = codec.DecodeTable(payload)
        ns.state.lastSyncMessage.distribution = distribution
        ns.state.lastSyncMessage.sender = sender
        return true
    end

    return false
end

ns.modules.syncEvents = syncEvents

return syncEvents
