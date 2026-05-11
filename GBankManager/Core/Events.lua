local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.modules.events = ns.modules.events or {}
ns.state = ns.state or {}

local events = ns.modules.events
local transport = ns.modules.syncTransport or {}
local codec = ns.modules.syncCodec or {}

if type(_G.CreateFrame) == "function" and type(events.RegisterEvent) ~= "function" then
    events = _G.CreateFrame("Frame")
    events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:SetScript("OnEvent", function(_, event, ...)
        local scanner = ns.modules.scanner

        if event == "GUILDBANKBAGSLOTS_CHANGED" and type(scanner) == "table" and scanner.scanInProgress then
            scanner.OnGuildBankSlotsChanged(...)
        elseif event == "PLAYER_LOGIN" then
            _G.C_ChatInfo.RegisterAddonMessagePrefix("GBankManager")
            transport.Send("GUILD", "GUILD", {
                type = "SYNC_HELLO",
                updatedAt = _G.time(),
                payload = _G.UnitName("player"),
            })
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, payload, distribution, sender = ...
            if prefix == "GBankManager" then
                ns.state.lastSyncMessage = codec.DecodeTable(payload)
                ns.state.lastSyncMessage.distribution = distribution
                ns.state.lastSyncMessage.sender = sender
            end
        end
    end)
end

ns.modules.events = events

return events
