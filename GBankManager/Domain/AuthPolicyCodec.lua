local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local codec = ns.modules.authPolicyCodec or {}

local CAPABILITY_ORDER = {
    "full_ui",
    "request_submit",
    "request_approve",
    "request_reject",
    "request_edit",
    "request_fulfill",
    "request_reopen",
    "minimum_add",
    "minimum_edit",
    "minimum_delete",
    "auth_manage",
}

local HASH_MODULUS = 2147483647

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function to_base36(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value == 0 then
        return "0"
    end

    local digits = {}
    while value > 0 do
        local remainder = value % 36
        digits[#digits + 1] = string.sub("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", remainder + 1, remainder + 1)
        value = math.floor(value / 36)
    end

    local out = {}
    for index = #digits, 1, -1 do
        out[#out + 1] = digits[index]
    end

    return table.concat(out)
end

local function from_base36(text)
    text = trim(text):upper()
    local value = 0

    for index = 1, #text do
        local ch = string.byte(text, index)
        local digit
        if ch >= 48 and ch <= 57 then
            digit = ch - 48
        elseif ch >= 65 and ch <= 90 then
            digit = ch - 55
        else
            return 0
        end
        value = (value * 36) + digit
    end

    return value
end

local function split_csv(text)
    local out = {}
    text = tostring(text or "")
    if text == "" or text == "-" then
        return out
    end

    for token in string.gmatch(text, "([^,]+)") do
        out[#out + 1] = token
    end

    return out
end

function codec.HashCharacterKey(characterKey)
    characterKey = trim(characterKey):upper()
    local hash = 5381

    for index = 1, #characterKey do
        hash = ((hash * 33) + string.byte(characterKey, index)) % HASH_MODULUS
    end

    return to_base36(hash)
end

function codec.ExtractPolicyString(infoText)
    return string.match(tostring(infoText or ""), "(%[GBMAUTH:[^%]]+%])") or string.match(tostring(infoText or ""), "(gbm%^.-%^g)")
end

function codec.InjectPolicyString(infoText, policyString)
    infoText = tostring(infoText or "")
    policyString = trim(policyString)
    local existing = codec.ExtractPolicyString(infoText)

    if policyString == "" then
        if existing then
            local cleaned = infoText:gsub("%[GBMAUTH:[^%]]+%]", ""):gsub("gbm%^.-%^g", "")
            cleaned = cleaned:gsub("\n\n+", "\n")
            cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
            return cleaned
        end

        return infoText
    end

    if existing then
        local replaced, count = infoText:gsub("%[GBMAUTH:[^%]]+%]", policyString, 1)
        if count > 0 then
            return replaced
        end

        return infoText:gsub("gbm%^.-%^g", policyString, 1)
    end

    if infoText == "" then
        return policyString
    end

    return string.format("%s\n%s", infoText, policyString)
end

local function sorted_rank_indices(policy)
    local ranks = {}

    for rankIndex, metadata in pairs((policy or {}).rankMetadata or {}) do
        ranks[#ranks + 1] = {
            rankIndex = rankIndex,
            order = metadata.order or rankIndex,
        }
    end

    table.sort(ranks, function(left, right)
        return (left.order or left.rankIndex) < (right.order or right.rankIndex)
    end)

    return ranks
end

function codec.EncodePolicy(policy)
    policy = policy or {}
    local rankMasks = {}

    for _, rank in ipairs(sorted_rank_indices(policy)) do
        local mask = 0
        for bitIndex, capability in ipairs(CAPABILITY_ORDER) do
            if (((policy.capabilities or {})[capability] or {})[rank.rankIndex] == true) then
                mask = mask + (2 ^ (bitIndex - 1))
            end
        end
        rankMasks[#rankMasks + 1] = to_base36(mask)
    end

    if #rankMasks == 0 then
        rankMasks[1] = "0"
    end

    local blacklistHashes = {}
    local seen = {}
    for characterKey in pairs((policy.blacklist or {})) do
        local hash = codec.HashCharacterKey(characterKey)
        if not seen[hash] then
            seen[hash] = true
            blacklistHashes[#blacklistHashes + 1] = hash
        end
    end
    for hash in pairs((policy.blacklistHashes or {})) do
        if not seen[hash] then
            seen[hash] = true
            blacklistHashes[#blacklistHashes + 1] = hash
        end
    end
    table.sort(blacklistHashes)

    return string.format(
        "[GBMAUTH:%s;%s;%s;%s;%s]",
        1,
        to_base36(policy.revision or 0),
        to_base36(policy.updatedAt or 0),
        table.concat(rankMasks, ","),
        #blacklistHashes > 0 and table.concat(blacklistHashes, ",") or "-"
    )
end

function codec.DecodePolicyString(policyString, rankMetadata)
    policyString = codec.ExtractPolicyString(policyString or "") or trim(policyString)

    local version, revisionText, updatedAtText, masksText, blacklistText = string.match(trim(policyString), "^%[GBMAUTH:([^;]+);([^;]+);([^;]+);([^;]+);([^%]]*)%]$")
    if version ~= "1" then
        version, revisionText, masksText, blacklistText = string.match(trim(policyString), "^gbm%^([^;]+);([^;]+);([^;]+);([^%^]*)%^g$")
        updatedAtText = "0"
    end

    if version ~= "1" then
        return nil
    end

    local policy = {
        version = 1,
        revision = from_base36(revisionText),
        updatedAt = from_base36(updatedAtText),
        updatedBy = "",
        updatedByRankIndex = nil,
        rankMetadata = rankMetadata or {},
        capabilities = {},
        blacklist = {},
        blacklistHashes = {},
        guildPolicyString = policyString,
        guildPolicySource = "guild_info",
    }

    for _, capability in ipairs(CAPABILITY_ORDER) do
        policy.capabilities[capability] = {}
    end

    local ranks = sorted_rank_indices(policy)
    local masks = split_csv(masksText)
    for index, maskText in ipairs(masks) do
        local rank = ranks[index]
        local mask = from_base36(maskText)
        if rank then
            for bitIndex, capability in ipairs(CAPABILITY_ORDER) do
                local enabled = math.floor(mask / (2 ^ (bitIndex - 1))) % 2 == 1
                if enabled then
                    policy.capabilities[capability][rank.rankIndex] = true
                end
            end
        end
    end

    for _, hash in ipairs(split_csv(blacklistText)) do
        policy.blacklistHashes[hash] = true
    end

    return policy
end

function codec.PolicyStringFromGuildInfo()
    if type(_G.GetGuildInfoText) == "function" then
        return codec.ExtractPolicyString(_G.GetGuildInfoText())
    end

    if _G.C_GuildInfo and type(_G.C_GuildInfo.GetInfoText) == "function" then
        return codec.ExtractPolicyString(_G.C_GuildInfo.GetInfoText())
    end

    return nil
end

function codec.CanWriteGuildInfo()
    if type(_G.SetGuildInfoText) == "function" then
        return true
    end

    return _G.C_GuildInfo and type(_G.C_GuildInfo.CanEditGuildInfo) == "function" and _G.C_GuildInfo.CanEditGuildInfo() == true
end

function codec.WritePolicyStringToGuildInfo(policyString)
    if not codec.CanWriteGuildInfo() then
        return false
    end

    local currentText = ""
    if type(_G.GetGuildInfoText) == "function" then
        currentText = _G.GetGuildInfoText() or ""
    elseif _G.C_GuildInfo and type(_G.C_GuildInfo.GetInfoText) == "function" then
        currentText = _G.C_GuildInfo.GetInfoText() or ""
    end

    local nextText = codec.InjectPolicyString(currentText, policyString)

    if type(_G.SetGuildInfoText) == "function" then
        return _G.SetGuildInfoText(nextText) ~= false
    end

    if _G.C_GuildInfo and type(_G.C_GuildInfo.SetInfoText) == "function" then
        return _G.C_GuildInfo.SetInfoText(nextText) ~= false
    end

    return false
end

ns.modules.authPolicyCodec = codec

return codec
