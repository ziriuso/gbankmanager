local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local portability = ns.modules.minimumsPortability or {}

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

local function escape_json_string(value)
    return tostring(value or ""):gsub("[\\\"\b\f\n\r\t]", {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    })
end

local function encode_json(value)
    local valueType = type(value)

    if value == nil then
        return "null"
    end

    if valueType == "boolean" then
        return value and "true" or "false"
    end

    if valueType == "number" then
        return tostring(value)
    end

    if valueType == "string" then
        return string.format("\"%s\"", escape_json_string(value))
    end

    if valueType ~= "table" then
        return string.format("\"%s\"", escape_json_string(tostring(value)))
    end

    if is_array(value) then
        local parts = {}
        for index = 1, #value do
            parts[#parts + 1] = encode_json(value[index])
        end
        return string.format("[%s]", table.concat(parts, ","))
    end

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = string.format("\"%s\":%s", escape_json_string(key), encode_json(value[key]))
    end
    return string.format("{%s}", table.concat(parts, ","))
end

local function skip_whitespace(text, index)
    while index <= #text do
        local character = string.sub(text, index, index)
        if character ~= " " and character ~= "\n" and character ~= "\r" and character ~= "\t" then
            break
        end
        index = index + 1
    end
    return index
end

local function decode_json_string(text, index)
    index = index + 1
    local parts = {}

    while index <= #text do
        local character = string.sub(text, index, index)
        if character == "\"" then
            return table.concat(parts), index + 1
        end
        if character == "\\" then
            local escaped = string.sub(text, index + 1, index + 1)
            local mapped = ({
                ["\\"] = "\\",
                ["\""] = "\"",
                ["/"] = "/",
                b = "\b",
                f = "\f",
                n = "\n",
                r = "\r",
                t = "\t",
            })[escaped]
            if mapped == nil then
                error("unsupported JSON escape sequence")
            end
            parts[#parts + 1] = mapped
            index = index + 2
        else
            parts[#parts + 1] = character
            index = index + 1
        end
    end

    error("unterminated JSON string")
end

local decode_json_value

local function decode_json_number(text, index)
    local startIndex = index
    while index <= #text do
        local character = string.sub(text, index, index)
        if not string.find("0123456789+-.eE", character, 1, true) then
            break
        end
        index = index + 1
    end

    local numberText = string.sub(text, startIndex, index - 1)
    local numberValue = tonumber(numberText)
    if numberValue == nil then
        error("invalid JSON number")
    end
    return numberValue, index
end

local function decode_json_array(text, index)
    index = index + 1
    local output = {}
    index = skip_whitespace(text, index)
    if string.sub(text, index, index) == "]" then
        return output, index + 1
    end

    while index <= #text do
        local value
        value, index = decode_json_value(text, index)
        output[#output + 1] = value
        index = skip_whitespace(text, index)
        local character = string.sub(text, index, index)
        if character == "]" then
            return output, index + 1
        end
        if character ~= "," then
            error("expected JSON array separator")
        end
        index = skip_whitespace(text, index + 1)
    end

    error("unterminated JSON array")
end

local function decode_json_object(text, index)
    index = index + 1
    local output = {}
    index = skip_whitespace(text, index)
    if string.sub(text, index, index) == "}" then
        return output, index + 1
    end

    while index <= #text do
        if string.sub(text, index, index) ~= "\"" then
            error("expected JSON object key")
        end

        local key
        key, index = decode_json_string(text, index)
        index = skip_whitespace(text, index)
        if string.sub(text, index, index) ~= ":" then
            error("expected JSON key separator")
        end

        local value
        value, index = decode_json_value(text, skip_whitespace(text, index + 1))
        output[key] = value
        index = skip_whitespace(text, index)

        local character = string.sub(text, index, index)
        if character == "}" then
            return output, index + 1
        end
        if character ~= "," then
            error("expected JSON object separator")
        end
        index = skip_whitespace(text, index + 1)
    end

    error("unterminated JSON object")
end

decode_json_value = function(text, index)
    index = skip_whitespace(text, index or 1)
    local character = string.sub(text, index, index)

    if character == "\"" then
        return decode_json_string(text, index)
    end
    if character == "{" then
        return decode_json_object(text, index)
    end
    if character == "[" then
        return decode_json_array(text, index)
    end
    if character == "-" or character:match("%d") then
        return decode_json_number(text, index)
    end
    if string.sub(text, index, index + 3) == "true" then
        return true, index + 4
    end
    if string.sub(text, index, index + 4) == "false" then
        return false, index + 5
    end
    if string.sub(text, index, index + 3) == "null" then
        return nil, index + 4
    end

    error("unexpected JSON token")
end

local function decode_json(text)
    local value, nextIndex = decode_json_value(tostring(text or ""), 1)
    nextIndex = skip_whitespace(tostring(text or ""), nextIndex or 1)
    if nextIndex <= #tostring(text or "") then
        error("unexpected trailing JSON content")
    end
    return value
end

local function sanitize_parse_error(message)
    local normalized = tostring(message or "invalid JSON payload")
    local trimmed = normalized:match(":%d+:%s*(.+)$")
    if trimmed and trimmed ~= "" then
        return trimmed
    end
    return normalized
end

local function normalize_scope(value)
    local scope = tostring(value or "TAB")
    if scope == "" then
        return "TAB"
    end
    return scope
end

local function available_tab_set(availableTabs)
    local output = {}
    for _, tabName in ipairs(availableTabs or {}) do
        local normalized = tostring(tabName or "")
        if normalized ~= "" then
            output[normalized] = true
        end
    end
    return output
end

local function build_review_row(rule, tabLookup)
    rule = type(rule) == "table" and rule or {}

    local itemID = tonumber(rule.itemID)
    local itemName = tostring(rule.itemName or "")
    local scope = normalize_scope(rule.scope)
    local importedTabName = tostring(rule.tabName or "")
    local quantity = tonumber(rule.quantity)
    local enabled = rule.enabled

    local row = {
        itemID = itemID,
        itemName = itemName,
        scope = scope,
        importedTabName = importedTabName,
        resolvedTabName = "",
        quantity = quantity,
        enabled = enabled == true,
        itemLink = tostring(rule.itemLink or ""),
        itemString = tostring(rule.itemString or ""),
        craftedQuality = tonumber(rule.craftedQuality),
        craftedQualityIcon = tostring(rule.craftedQualityIcon or ""),
        craftedQualityDisplayAtlas = tostring(rule.craftedQualityDisplayAtlas or ""),
        craftedQualityPreferredAtlas = tostring(rule.craftedQualityPreferredAtlas or ""),
        craftedQualityMax = tonumber(rule.craftedQualityMax),
        status = "ready",
    }

    if not itemID or itemName == "" or quantity == nil or type(enabled) ~= "boolean" then
        row.status = "invalid"
        return row
    end

    if scope == "TAB" then
        if importedTabName == "" then
            row.status = "invalid"
            return row
        end
        if tabLookup[importedTabName] == true then
            row.resolvedTabName = importedTabName
        else
            row.status = "needs_tab"
        end
        return row
    end

    row.resolvedTabName = importedTabName
    return row
end

function portability.Export(context)
    context = type(context) == "table" and context or {}

    local rules = {}
    for _, minimum in ipairs(context.minimums or {}) do
        rules[#rules + 1] = {
            itemID = tonumber(minimum.itemID),
            itemName = tostring(minimum.itemName or ""),
            scope = normalize_scope(minimum.scope),
            tabName = tostring(minimum.tabName or ""),
            quantity = tonumber(minimum.quantity),
            enabled = minimum.enabled ~= false,
            itemLink = tostring(minimum.itemLink or ""),
            itemString = tostring(minimum.itemString or ""),
            craftedQuality = tonumber(minimum.craftedQuality),
            craftedQualityIcon = tostring(minimum.craftedQualityIcon or ""),
            craftedQualityDisplayAtlas = tostring(minimum.craftedQualityDisplayAtlas or ""),
            craftedQualityPreferredAtlas = tostring(minimum.craftedQualityPreferredAtlas or ""),
            craftedQualityMax = tonumber(minimum.craftedQualityMax),
        }
    end

    return encode_json({
        schema = "gbankmanager.minimums",
        version = 1,
        exportedAt = tonumber(context.exportedAt) or 0,
        sourceGuild = tostring(context.guildName or ""),
        rules = rules,
    })
end

function portability.Parse(payloadText, availableTabs)
    local ok, decoded = pcall(decode_json, payloadText)
    if not ok then
        return {
            ok = false,
            error = sanitize_parse_error(decoded),
            rows = {},
        }
    end

    if type(decoded) ~= "table" then
        return {
            ok = false,
            error = "import payload must decode into an object",
            rows = {},
        }
    end

    if tostring(decoded.schema or "") ~= "gbankmanager.minimums" then
        return {
            ok = false,
            error = "unsupported portability schema",
            rows = {},
        }
    end

    if tonumber(decoded.version) ~= 1 then
        return {
            ok = false,
            error = "unsupported portability version",
            rows = {},
        }
    end

    if type(decoded.rules) ~= "table" or not is_array(decoded.rules) then
        return {
            ok = false,
            error = "import payload rules must be an array",
            rows = {},
        }
    end

    local tabLookup = available_tab_set(availableTabs)
    local rows = {}
    for _, rule in ipairs(decoded.rules) do
        rows[#rows + 1] = build_review_row(rule, tabLookup)
    end

    return {
        ok = true,
        schema = decoded.schema,
        version = tonumber(decoded.version) or 0,
        sourceGuild = tostring(decoded.sourceGuild or ""),
        exportedAt = tonumber(decoded.exportedAt) or 0,
        rows = rows,
    }
end

ns.modules.minimumsPortability = portability

return portability
