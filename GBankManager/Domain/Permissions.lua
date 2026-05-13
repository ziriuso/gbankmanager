local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.domain = ns.domain or {}

local permissions = ns.domain.permissions or ns.modules.permissions or {}
local authPolicyCodec = ns.modules.authPolicyCodec or {}

local CAPABILITIES = {
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

local OFFICER_FALLBACK_CAPABILITIES = {
    full_ui = true,
    request_approve = true,
    request_reject = true,
    request_edit = true,
    request_fulfill = true,
    request_reopen = true,
    minimum_add = true,
    minimum_edit = true,
    minimum_delete = true,
}

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function default_rank_name(rankIndex)
    if tonumber(rankIndex) == 0 then
        return "Guild Master"
    end

    return string.format("Rank %d", tonumber(rankIndex) or 0)
end

function permissions.GetCapabilityList()
    local capabilities = {}

    for index, capability in ipairs(CAPABILITIES) do
        capabilities[index] = capability
    end

    return capabilities
end

local function ensure_capabilities(capabilities)
    capabilities = ensure_table(capabilities)

    for _, capability in ipairs(CAPABILITIES) do
        capabilities[capability] = ensure_table(capabilities[capability])
    end

    return capabilities
end

function permissions.BuildCharacterKey(name, realmName)
    local normalizedName = trim(name)
    local normalizedRealm = trim(realmName)

    if normalizedName == "" then
        normalizedName = "Unknown"
    end

    if normalizedRealm == "" then
        return normalizedName
    end

    return string.format("%s-%s", normalizedRealm, normalizedName)
end

function permissions.HashCharacterKey(characterKey)
    return type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(characterKey) or ""
end

function permissions.NormalizeCharacterKey(value, realmName)
    local normalized = trim(value)
    if normalized == "" then
        return ""
    end

    if string.find(normalized, "-", 1, true) then
        return normalized
    end

    return permissions.BuildCharacterKey(normalized, realmName)
end

function permissions.DisplayCharacterKey(characterKey)
    local normalized = trim(characterKey)
    if normalized == "" then
        return ""
    end

    local delimiterIndex = string.find(normalized, "-", 1, true)
    if not delimiterIndex then
        return normalized
    end

    local realmName = string.sub(normalized, 1, delimiterIndex - 1)
    local characterName = string.sub(normalized, delimiterIndex + 1)
    if characterName == "" or realmName == "" then
        return normalized
    end

    return string.format("%s-%s", characterName, realmName)
end

function permissions.GetGuildRankMetadata()
    local metadata = {}
    local count = type(_G.GuildControlGetNumRanks) == "function" and (_G.GuildControlGetNumRanks() or 0) or 0

    for zeroBasedIndex = 0, math.max(0, count - 1) do
        local displayName = type(_G.GuildControlGetRankName) == "function" and _G.GuildControlGetRankName(zeroBasedIndex + 1) or nil
        metadata[zeroBasedIndex] = {
            name = trim(displayName) ~= "" and trim(displayName) or default_rank_name(zeroBasedIndex),
            order = zeroBasedIndex,
        }
    end

    return metadata
end

function permissions.CreateDefaultPolicy()
    return {
        version = 1,
        revision = 0,
        updatedAt = 0,
        updatedBy = "",
        updatedByRankIndex = nil,
        guildPolicyString = "",
        guildPolicySource = "local",
        rankMetadata = {},
        capabilities = ensure_capabilities({}),
        blacklist = {},
        blacklistHashes = {},
    }
end

function permissions.NormalizePolicy(policy, liveRankMetadata)
    local normalized = ensure_table(policy)
    local defaults = permissions.CreateDefaultPolicy()

    normalized.version = tonumber(normalized.version or defaults.version) or defaults.version
    normalized.revision = tonumber(normalized.revision or defaults.revision) or defaults.revision
    normalized.updatedAt = tonumber(normalized.updatedAt or defaults.updatedAt) or defaults.updatedAt
    normalized.updatedBy = normalized.updatedBy or defaults.updatedBy
    normalized.updatedByRankIndex = normalized.updatedByRankIndex
    normalized.guildPolicyString = normalized.guildPolicyString or defaults.guildPolicyString
    normalized.guildPolicySource = normalized.guildPolicySource or defaults.guildPolicySource
    normalized.rankMetadata = ensure_table(normalized.rankMetadata)
    normalized.capabilities = ensure_capabilities(normalized.capabilities)
    normalized.blacklist = ensure_table(normalized.blacklist)
    normalized.blacklistHashes = ensure_table(normalized.blacklistHashes)

    for characterKey in pairs(normalized.blacklist) do
        if type(authPolicyCodec.HashCharacterKey) == "function" then
            normalized.blacklistHashes[authPolicyCodec.HashCharacterKey(characterKey)] = true
        end
    end

    for rankIndex, metadata in pairs(liveRankMetadata or {}) do
        normalized.rankMetadata[rankIndex] = normalized.rankMetadata[rankIndex] or {}
        normalized.rankMetadata[rankIndex].name = metadata.name or normalized.rankMetadata[rankIndex].name or default_rank_name(rankIndex)
        normalized.rankMetadata[rankIndex].order = metadata.order or normalized.rankMetadata[rankIndex].order or rankIndex
    end

    return normalized
end

function permissions.GetLivePlayerContext(db)
    local guildName, guildRankName, guildRankIndex = nil, nil, nil
    if type(_G.GetGuildInfo) == "function" then
        guildName, guildRankName, guildRankIndex = _G.GetGuildInfo("player")
    end

    local name = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown"
    local realmName = type(_G.GetRealmName) == "function" and _G.GetRealmName() or ""
    local characterKey = permissions.BuildCharacterKey(name, realmName)
    local normalizedRankIndex = tonumber(guildRankIndex)
    local inGuild = trim(guildName) ~= ""

    return {
        name = name or "Unknown",
        realmName = realmName,
        characterKey = characterKey,
        guildName = guildName,
        guildRankName = guildRankName or "",
        guildRankIndex = normalizedRankIndex,
        isGuildMaster = inGuild and normalizedRankIndex == 0,
        inGuild = inGuild,
    }
end

function permissions.RefreshPolicyFromGuild(db)
    db = db or {}
    db.auth = permissions.NormalizePolicy(db.auth, permissions.GetGuildRankMetadata())
    return db.auth
end

function permissions.GetSortedRankMetadata(policy)
    policy = permissions.NormalizePolicy(policy)
    local ranks = {}

    for rankIndex, metadata in pairs(policy.rankMetadata or {}) do
        table.insert(ranks, {
            rankIndex = rankIndex,
            name = metadata.name or default_rank_name(rankIndex),
            order = metadata.order or rankIndex,
        })
    end

    table.sort(ranks, function(left, right)
        return (left.order or left.rankIndex) < (right.order or right.rankIndex)
    end)

    return ranks
end

function permissions.IsBlacklisted(context, policy)
    context = context or {}
    if context.isGuildMaster then
        return false
    end

    policy = permissions.NormalizePolicy(policy)
    if policy.blacklist[context.characterKey] ~= nil then
        return true
    end

    local hash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(context.characterKey) or nil
    return hash ~= nil and policy.blacklistHashes[hash] == true
end

local function uses_fallback_for_capability(policy, capability)
    policy = permissions.NormalizePolicy(policy)
    local allowlist = policy.capabilities[capability] or {}
    return next(allowlist) == nil
end

function permissions.Can(context, capability, policy)
    context = context or {}
    policy = permissions.NormalizePolicy(policy)

    if capability == nil or capability == "" then
        return false
    end

    if permissions.IsBlacklisted(context, policy) then
        return false
    end

    if context.isGuildMaster then
        return true
    end

    if not context.inGuild then
        return false
    end

    local rankIndex = tonumber(context.guildRankIndex)
    if rankIndex == nil then
        return false
    end

    local allowlist = policy.capabilities[capability] or {}
    if next(allowlist) ~= nil then
        return allowlist[rankIndex] == true
    end

    if capability == "request_submit" then
        return true
    end

    if OFFICER_FALLBACK_CAPABILITIES[capability] then
        return rankIndex <= 1
    end

    return false
end

function permissions.GetEffectiveAccessProfile(context, policy)
    context = context or {}
    if permissions.IsBlacklisted(context, policy) then
        return "blocked"
    end

    if permissions.Can(context, "full_ui", policy) then
        return "full_shell"
    end

    if context.inGuild then
        return "request_only"
    end

    return "blocked"
end

function permissions.ToggleCapabilityRank(policy, capability, rankIndex)
    policy = permissions.NormalizePolicy(policy)
    policy.capabilities[capability] = policy.capabilities[capability] or {}
    if policy.capabilities[capability][rankIndex] then
        policy.capabilities[capability][rankIndex] = nil
    else
        policy.capabilities[capability][rankIndex] = true
    end

    return policy.capabilities[capability][rankIndex] == true
end

function permissions.SetCapabilityRank(policy, capability, rankIndex, isAllowed)
    policy = permissions.NormalizePolicy(policy)
    policy.capabilities[capability] = policy.capabilities[capability] or {}
    if isAllowed then
        policy.capabilities[capability][rankIndex] = true
    else
        policy.capabilities[capability][rankIndex] = nil
    end

    return policy.capabilities[capability][rankIndex] == true
end

function permissions.UpsertBlacklist(policy, characterKey, name, reason, updatedAt)
    policy = permissions.NormalizePolicy(policy)
    local hash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(characterKey) or nil
    policy.blacklist[characterKey] = {
        name = name or characterKey,
        reason = reason or "",
        updatedAt = updatedAt or 0,
    }
    if hash then
        policy.blacklistHashes[hash] = true
    end

    return policy.blacklist[characterKey]
end

function permissions.RemoveBlacklist(policy, characterKey)
    policy = permissions.NormalizePolicy(policy)
    local removed = policy.blacklist[characterKey]
    local hash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(characterKey) or nil
    policy.blacklist[characterKey] = nil
    if hash then
        policy.blacklistHashes[hash] = nil
    end
    return removed
end

function permissions.StampPolicy(policy, context, updatedAt)
    policy = permissions.NormalizePolicy(policy)
    context = context or {}
    policy.revision = (tonumber(policy.revision or 0) or 0) + 1
    policy.updatedAt = updatedAt or (_G.time and _G.time() or 0)
    policy.updatedBy = context.characterKey or context.name or ""
    policy.updatedByRankIndex = context.guildRankIndex
    if type(authPolicyCodec.EncodePolicy) == "function" then
        policy.guildPolicyString = authPolicyCodec.EncodePolicy(policy)
    end
    policy.guildPolicySource = "local"
    return policy
end

function permissions.CanApproveRequests(role)
    return role == "OFFICER" or role == "GUILDMASTER"
end

function permissions.CanViewInventory(role)
    return permissions.CanApproveRequests(role)
end

function permissions.AutoApprovesOwnRequests(role)
    return permissions.CanApproveRequests(role)
end

ns.domain.permissions = permissions
ns.modules.permissions = permissions
ns.modules.auth = permissions

return permissions
