local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.syncCodec or {}

function codec.EncodeTable(message)
    message = message or {}
    return table.concat({
        tostring(message.type or ""),
        tostring(message.updatedAt or 0),
        tostring(message.payload or ""),
    }, "|")
end

function codec.DecodeTable(text)
    local messageType, updatedAt, payload = string.match(tostring(text or ""), "([^|]*)|([^|]*)|(.*)")
    return {
        type = messageType,
        updatedAt = tonumber(updatedAt) or 0,
        payload = payload or "",
    }
end

ns.modules.syncCodec = codec

return codec
