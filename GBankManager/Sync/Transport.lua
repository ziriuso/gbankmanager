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
local CHUNK_START = string.char(1)
local CHUNK_CONTINUE = string.char(2)
local CHUNK_END = string.char(3)

local function current_ace_comm()
    local libStub = _G.LibStub
    if libStub == nil then
        return nil
    end

    return libStub("AceComm-3.0", true)
end

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

local function queue_received_message(message, distribution, sender)
    transport.pendingReceivedMessages = transport.pendingReceivedMessages or {}
    transport.pendingReceivedMessages[#transport.pendingReceivedMessages + 1] = {
        message = message,
        distribution = distribution,
        sender = sender,
    }
end

local function pop_received_message()
    if type(transport.pendingReceivedMessages) ~= "table" or #transport.pendingReceivedMessages == 0 then
        return nil
    end

    return table.remove(transport.pendingReceivedMessages, 1)
end

local function chunk_buffer_key(distribution, sender)
    return table.concat({
        tostring(distribution or ""),
        tostring(sender or ""),
    }, "|")
end

local function receive_chunked_payload(payload, distribution, sender)
    payload = tostring(payload or "")
    local marker = payload:sub(1, 1)
    if marker ~= CHUNK_START and marker ~= CHUNK_CONTINUE and marker ~= CHUNK_END then
        return nil, nil
    end

    transport.chunkBuffers = transport.chunkBuffers or {}
    local key = chunk_buffer_key(distribution, sender)
    local body = payload:sub(2)
    if marker == CHUNK_START then
        transport.chunkBuffers[key] = body
        return nil, "partial"
    end

    local buffer = tostring(transport.chunkBuffers[key] or "")
    if buffer == "" then
        transport.chunkBuffers[key] = nil
        return nil, "invalid"
    end

    buffer = buffer .. body
    if marker == CHUNK_CONTINUE then
        transport.chunkBuffers[key] = buffer
        return nil, "partial"
    end

    transport.chunkBuffers[key] = nil
    return codec.DecodeTable(buffer), "complete"
end

local function normalize_target(distribution, target)
    local distributionName = tostring(distribution or "")
    if distributionName == "WHISPER" or distributionName == "CHANNEL" then
        return target
    end

    return nil
end

function transport.Initialize(receiver)
    if type(receiver) == "function" then
        transport.receiver = receiver
    end

    if transport.initialized == true then
        return true
    end

    local aceComm = current_ace_comm()
    if not aceComm then
        return false
    end

    transport.comm = transport.comm or {}
    aceComm:Embed(transport.comm)
    transport.comm:RegisterComm(SYNC_PREFIX, function(_, message, distribution, sender)
        queue_received_message(message, distribution, sender)
        if type(transport.receiver) == "function" then
            transport.receiver(message, distribution, sender)
        end
    end)
    transport.initialized = true
    return true
end

function transport.SetReceiver(receiver)
    transport.receiver = receiver
    transport.Initialize(receiver)
    return transport.receiver
end

function transport.Send(distribution, target, message)
    local payload = codec.EncodeTable(message or {})
    if transport.Initialize() and transport.comm and type(transport.comm.SendCommMessage) == "function" then
        transport.comm:SendCommMessage(
            SYNC_PREFIX,
            payload,
            tostring(distribution or ""),
            normalize_target(distribution, target)
        )
        return payload
    end

    if _G.C_ChatInfo and type(_G.C_ChatInfo.SendAddonMessage) == "function" then
        _G.C_ChatInfo.SendAddonMessage(SYNC_PREFIX, payload, distribution, target)
    end

    return payload
end

function transport.Receive(payload, distribution, sender)
    local chunkedMessage, chunkedState = receive_chunked_payload(payload, distribution, sender)
    if chunkedState ~= nil then
        return chunkedMessage, chunkedState
    end

    local decodedPayload = codec.DecodeTable(payload)
    if decodedPayload then
        return decodedPayload, "complete"
    end

    if transport.Initialize() then
        local received = pop_received_message()
        if received ~= nil then
            return codec.DecodeTable(received.message), "complete"
        end
        return nil, "partial"
    end

    return nil, "invalid"
end

function transport.ReportStatus(message)
    return push_chat_line(string.format("%s: %s", SYNC_PREFIX, tostring(message or "")))
end

ns.modules.syncTransport = transport

return transport
