local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.syncCodec
if codec == nil and type(_G.dofile) == "function" then
    codec = _G.dofile("GBankManager/Sync/Codec.lua")
end

codec = codec or {}
local transport = ns.modules.syncTransport or {}

function transport.Send(channel, distribution, message)
    local payload = codec.EncodeTable(message or {})
    _G.C_ChatInfo.SendAddonMessage("GBankManager", payload, distribution, channel)
    return payload
end

ns.modules.syncTransport = transport

return transport
