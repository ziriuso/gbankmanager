local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.syncCodec or {}

local function encode_value(value)
    local valueType = type(value)

    if value == nil then
        return "N"
    end

    if valueType == "boolean" then
        return value and "B1" or "B0"
    end

    if valueType == "number" then
        return "D" .. tostring(value) .. ";"
    end

    if valueType == "string" then
        return "S" .. tostring(#value) .. ":" .. value
    end

    if valueType == "table" then
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end

        table.sort(keys, function(left, right)
            return tostring(left) < tostring(right)
        end)

        local parts = { "T", tostring(#keys), ":" }
        for _, key in ipairs(keys) do
            parts[#parts + 1] = encode_value(key)
            parts[#parts + 1] = encode_value(value[key])
        end

        return table.concat(parts)
    end

    return encode_value(tostring(value))
end

local function decode_value(text, startIndex)
    local tag = string.sub(text, startIndex, startIndex)

    if tag == "N" then
        return nil, startIndex + 1
    end

    if tag == "B" then
        return string.sub(text, startIndex + 1, startIndex + 1) == "1", startIndex + 2
    end

    if tag == "D" then
        local terminator = string.find(text, ";", startIndex + 1, true)
        local numberText = string.sub(text, startIndex + 1, (terminator or startIndex + 1) - 1)
        return tonumber(numberText) or 0, (terminator or startIndex) + 1
    end

    if tag == "S" then
        local separator = string.find(text, ":", startIndex + 1, true)
        local length = tonumber(string.sub(text, startIndex + 1, (separator or startIndex + 1) - 1)) or 0
        local valueStart = (separator or startIndex) + 1
        local valueEnd = valueStart + length - 1
        return string.sub(text, valueStart, valueEnd), valueEnd + 1
    end

    if tag == "T" then
        local separator = string.find(text, ":", startIndex + 1, true)
        local count = tonumber(string.sub(text, startIndex + 1, (separator or startIndex + 1) - 1)) or 0
        local nextIndex = (separator or startIndex) + 1
        local output = {}

        for _ = 1, count do
            local key
            local value
            key, nextIndex = decode_value(text, nextIndex)
            value, nextIndex = decode_value(text, nextIndex)
            output[key] = value
        end

        return output, nextIndex
    end

    return "", #text + 1
end

function codec.EncodeTable(message)
    message = message or {}
    local payload = message.payload

    if type(payload) == "table" then
        payload = "@" .. encode_value(payload)
    elseif payload == nil then
        payload = ""
    else
        payload = tostring(payload)
    end

    return table.concat({
        tostring(message.type or ""),
        tostring(message.updatedAt or 0),
        payload,
    }, "|")
end

function codec.DecodeTable(text)
    local messageType, updatedAt, payload = string.match(tostring(text or ""), "([^|]*)|([^|]*)|(.*)")
    if string.sub(payload or "", 1, 1) == "@" then
        payload = select(1, decode_value(string.sub(payload, 2), 1))
    else
        payload = payload or ""
    end

    return {
        type = messageType,
        updatedAt = tonumber(updatedAt) or 0,
        payload = payload,
    }
end

ns.modules.syncCodec = codec

return codec
