local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.syncCodec
if codec == nil and type(_G.dofile) == "function" then
    codec = _G.dofile("GBankManager/Sync/Codec.lua")
end

codec = codec or {}
local transport = ns.modules.syncTransport or {}
local SYNC_PREFIX = "GBankManager"

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
        return true
    end

    if type(_G.print) == "function" then
        _G.print(message)
        return true
    end

    return false
end

function transport.Send(channel, distribution, message)
    local payload = codec.EncodeTable(message or {})
    _G.C_ChatInfo.SendAddonMessage(SYNC_PREFIX, payload, distribution, channel)
    return payload
end

function transport.ReportStatus(message)
    return push_chat_line(string.format("%s: %s", SYNC_PREFIX, tostring(message or "")))
end

ns.modules.syncTransport = transport

return transport
