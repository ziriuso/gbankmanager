local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.syncCodec or {}
local MAX_DECODE_DEPTH = 16
local MAX_TABLE_ENTRIES = 256
local MAX_STRING_LENGTH = 8192

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

local function decode_error(message)
    return nil, nil, message
end

local function decode_value(text, startIndex, depth)
    text = tostring(text or "")
    startIndex = tonumber(startIndex or 1) or 1
    depth = tonumber(depth or 0) or 0
    if startIndex > #text then
        return decode_error("unexpected_end")
    end

    local tag = string.sub(text, startIndex, startIndex)

    if tag == "N" then
        return nil, startIndex + 1, nil
    end

    if tag == "B" then
        local value = string.sub(text, startIndex + 1, startIndex + 1)
        if value ~= "0" and value ~= "1" then
            return decode_error("invalid_boolean")
        end
        return value == "1", startIndex + 2, nil
    end

    if tag == "D" then
        local terminator = string.find(text, ";", startIndex + 1, true)
        if not terminator then
            return decode_error("missing_number_terminator")
        end
        local numberText = string.sub(text, startIndex + 1, (terminator or startIndex + 1) - 1)
        local value = tonumber(numberText)
        if value == nil then
            return decode_error("invalid_number")
        end
        return value, terminator + 1, nil
    end

    if tag == "S" then
        local separator = string.find(text, ":", startIndex + 1, true)
        if not separator then
            return decode_error("missing_string_separator")
        end
        local length = tonumber(string.sub(text, startIndex + 1, separator - 1))
        if length == nil or length < 0 or length > MAX_STRING_LENGTH then
            return decode_error("invalid_string_length")
        end
        local valueStart = separator + 1
        local valueEnd = valueStart + length - 1
        if valueEnd > #text then
            return decode_error("truncated_string")
        end
        return string.sub(text, valueStart, valueEnd), valueEnd + 1, nil
    end

    if tag == "T" then
        if depth >= MAX_DECODE_DEPTH then
            return decode_error("max_depth_exceeded")
        end
        local separator = string.find(text, ":", startIndex + 1, true)
        if not separator then
            return decode_error("missing_table_separator")
        end
        local count = tonumber(string.sub(text, startIndex + 1, separator - 1))
        if count == nil or count < 0 or count > MAX_TABLE_ENTRIES or count ~= math.floor(count) then
            return decode_error("invalid_table_count")
        end
        local nextIndex = separator + 1
        local output = {}

        for _ = 1, count do
            local key
            local value
            local err
            key, nextIndex, err = decode_value(text, nextIndex, depth + 1)
            if err ~= nil then
                return decode_error(err)
            end
            if key == nil then
                return decode_error("nil_table_key")
            end
            value, nextIndex, err = decode_value(text, nextIndex, depth + 1)
            if err ~= nil then
                return decode_error(err)
            end
            output[key] = value
        end

        return output, nextIndex, nil
    end

    return decode_error("unknown_tag")
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
        local encodedPayload = string.sub(payload, 2)
        local ok, decodedPayload, nextIndex, err = pcall(decode_value, encodedPayload, 1, 0)
        if not ok then
            return nil, "decode_error"
        end
        if err ~= nil then
            return nil, err
        end
        if nextIndex ~= #encodedPayload + 1 then
            return nil, "trailing_payload"
        end
        payload = decodedPayload
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
