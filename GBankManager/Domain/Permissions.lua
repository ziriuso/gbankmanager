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
    "request_delete",
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
    request_delete = true,
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

local function current_realm_name()
    return trim(type(_G.GetRealmName) == "function" and _G.GetRealmName() or "")
end

local function canonical_character_parts(value, realmName, nameHint)
    local normalized = trim(value)
    if normalized == "" then
        return "", ""
    end

    local left, right = string.match(normalized, "^([^%-]+)%-(.+)$")
    if not left or not right or left == "" or right == "" then
        return normalized, trim(realmName)
    end

    local normalizedNameHint = trim(nameHint)
    if normalizedNameHint ~= "" then
        if left == normalizedNameHint then
            return left, right
        end
        if right == normalizedNameHint then
            return right, left
        end
    end

    local normalizedRealm = trim(realmName)
    if normalizedRealm ~= "" then
        if right == normalizedRealm then
            return left, right
        end
        if left == normalizedRealm then
            return right, left
        end
    end

    local currentRealm = current_realm_name()
    if currentRealm ~= "" then
        if right == currentRealm then
            return left, right
        end
        if left == currentRealm then
            return right, left
        end
    end

    return left, right
end

local function build_blacklist_directory_entry(characterKey, entry, fallbackUpdatedAt)
    local normalizedCharacterKey = trim(characterKey)
    if normalizedCharacterKey == "" then
        return nil, nil
    end

    local hash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(normalizedCharacterKey) or nil
    if not hash or hash == "" then
        return nil, nil
    end

    entry = type(entry) == "table" and entry or {}
    return hash, {
        characterKey = normalizedCharacterKey,
        name = trim(entry.name or "") ~= "" and entry.name or normalizedCharacterKey,
        reason = entry.reason or "",
        updatedAt = tonumber(entry.updatedAt or fallbackUpdatedAt or 0) or 0,
        hash = hash,
    }
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

    return string.format("%s-%s", normalizedName, normalizedRealm)
end

function permissions.HashCharacterKey(characterKey)
    return type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(characterKey) or ""
end

function permissions.NormalizeCharacterKey(value, realmName, nameHint)
    local normalized = trim(value)
    if normalized == "" then
        return ""
    end

    if string.find(normalized, "-", 1, true) then
        local name, resolvedRealm = canonical_character_parts(normalized, realmName, nameHint)
        if name == "" then
            return ""
        end
        if resolvedRealm == "" then
            return name
        end
        return string.format("%s-%s", name, resolvedRealm)
    end

    return permissions.BuildCharacterKey(normalized, realmName)
end

function permissions.NormalizeEnteredCharacterKey(value, realmName)
    local normalized = trim(value)
    if normalized == "" then
        return ""
    end

    if string.find(normalized, "-", 1, true) then
        return permissions.NormalizeCharacterKey(normalized, realmName)
    end

    local normalizedRealm = trim(realmName)
    if normalizedRealm == "" then
        return normalized
    end

    return string.format("%s-%s", normalized, normalizedRealm)
end

function permissions.DisplayCharacterKey(characterKey)
    local normalized = trim(characterKey)
    if normalized == "" then
        return ""
    end

    return permissions.NormalizeCharacterKey(normalized)
end

function permissions.GetCharacterNameFromKey(characterKey, realmName, nameHint)
    local name = canonical_character_parts(characterKey, realmName, nameHint)
    return name
end

function permissions.GetRealmNameFromKey(characterKey, realmName, nameHint)
    local _, resolvedRealm = canonical_character_parts(characterKey, realmName, nameHint)
    return resolvedRealm
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
        updatedByHash = nil,
        updatedByRankIndex = nil,
        restockDefault = nil,
        criticalThresholdPercent = 50,
        guildPolicyString = "",
        guildPolicySource = "local",
        rankMetadata = {},
        capabilities = ensure_capabilities({}),
        blacklist = {},
        blacklistHashes = {},
        blacklistDirectory = {},
        blacklistRosterDirectory = {},
    }
end

function permissions.NormalizePolicy(policy, liveRankMetadata)
    local normalized = ensure_table(policy)
    local defaults = permissions.CreateDefaultPolicy()

    normalized.version = tonumber(normalized.version or defaults.version) or defaults.version
    normalized.revision = tonumber(normalized.revision or defaults.revision) or defaults.revision
    normalized.updatedAt = tonumber(normalized.updatedAt or defaults.updatedAt) or defaults.updatedAt
    normalized.updatedBy = normalized.updatedBy or defaults.updatedBy
    normalized.updatedByHash = normalized.updatedByHash or defaults.updatedByHash
    normalized.updatedByRankIndex = normalized.updatedByRankIndex
    normalized.restockDefault = normalized.restockDefault ~= nil and (tonumber(normalized.restockDefault) or nil) or defaults.restockDefault
    normalized.criticalThresholdPercent = math.max(0, math.min(100, tonumber(normalized.criticalThresholdPercent or defaults.criticalThresholdPercent) or defaults.criticalThresholdPercent))
    normalized.guildPolicyString = normalized.guildPolicyString or defaults.guildPolicyString
    normalized.guildPolicySource = normalized.guildPolicySource or defaults.guildPolicySource
    normalized.rankMetadata = ensure_table(normalized.rankMetadata)
    normalized.capabilities = ensure_capabilities(normalized.capabilities)
    normalized.blacklist = ensure_table(normalized.blacklist)
    normalized.blacklistHashes = ensure_table(normalized.blacklistHashes)
    normalized.blacklistDirectory = ensure_table(normalized.blacklistDirectory)
    normalized.blacklistRosterDirectory = ensure_table(normalized.blacklistRosterDirectory)

    local migratedBlacklist = {}
    for characterKey, entry in pairs(normalized.blacklist) do
        local finalCharacterKey = permissions.NormalizeCharacterKey(characterKey, nil, type(entry) == "table" and entry.name or nil)
        migratedBlacklist[finalCharacterKey] = entry
        if type(authPolicyCodec.HashCharacterKey) == "function" then
            normalized.blacklistHashes[authPolicyCodec.HashCharacterKey(characterKey)] = true
            normalized.blacklistHashes[authPolicyCodec.HashCharacterKey(finalCharacterKey)] = true
        end
        local hash, directoryEntry = build_blacklist_directory_entry(finalCharacterKey, entry, normalized.updatedAt)
        if hash and directoryEntry then
            normalized.blacklistDirectory[hash] = directoryEntry
        end
    end
    normalized.blacklist = migratedBlacklist

    local normalizedDirectory = {}
    for hash, entry in pairs(normalized.blacklistDirectory) do
        local actualHash = tostring((type(entry) == "table" and entry.hash) or hash or "")
        local characterKey = type(entry) == "table" and entry.characterKey or nil
        local directoryHash, directoryEntry = build_blacklist_directory_entry(characterKey, entry, normalized.updatedAt)
        if directoryHash and directoryEntry then
            normalizedDirectory[directoryHash] = directoryEntry
            if normalized.blacklistHashes[directoryHash] ~= true then
                normalized.blacklistHashes[directoryHash] = nil
            end
        elseif actualHash ~= "" and type(entry) == "table" then
            normalizedDirectory[actualHash] = {
                characterKey = tostring(entry.characterKey or "#" .. actualHash),
                name = tostring(entry.name or entry.characterKey or "#" .. actualHash),
                reason = tostring(entry.reason or ""),
                updatedAt = tonumber(entry.updatedAt or normalized.updatedAt or 0) or 0,
                hash = actualHash,
            }
        end
    end
    normalized.blacklistDirectory = normalizedDirectory

    if normalized.updatedByHash == nil and trim(normalized.updatedBy) ~= "" and type(authPolicyCodec.HashCharacterKey) == "function" then
        normalized.updatedByHash = authPolicyCodec.HashCharacterKey(normalized.updatedBy)
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

function permissions.GetGuildRosterContextBySender(sender, actorContext)
    actorContext = type(actorContext) == "table" and actorContext or {}
    sender = trim(sender)
    local realmName = trim(actorContext.realmName)
    if realmName == "" then
        realmName = permissions.GetRealmNameFromKey(actorContext.characterKey, nil, actorContext.name)
    end
    if realmName == "" then
        realmName = current_realm_name()
    end

    local senderKey = permissions.NormalizeCharacterKey(sender, realmName, actorContext.name)
    local senderName = permissions.GetCharacterNameFromKey(senderKey, realmName, actorContext.name)
    if senderName == "" then
        senderName = sender:match("^([^%-]+)") or sender
    end

    local count = type(_G.GetNumGuildMembers) == "function" and tonumber(_G.GetNumGuildMembers() or 0) or 0
    if type(_G.GetGuildRosterInfo) ~= "function" then
        count = 0
    end
    for index = 1, math.max(0, count) do
        local name, rankName, rankIndex = _G.GetGuildRosterInfo(index)
        local rosterKey = permissions.NormalizeCharacterKey(name, realmName, actorContext.name)
        local rosterName = permissions.GetCharacterNameFromKey(rosterKey, realmName, actorContext.name)
        local normalizedRankIndex = tonumber(rankIndex)
        if rosterKey ~= "" and (rosterKey == senderKey or rosterName == senderName) then
            return {
                name = rosterName ~= "" and rosterName or senderName,
                realmName = permissions.GetRealmNameFromKey(rosterKey, realmName, rosterName),
                characterKey = rosterKey,
                guildRankName = rankName or "",
                guildRankIndex = normalizedRankIndex,
                isGuildMaster = normalizedRankIndex == 0,
                inGuild = true,
            }
        end
    end

    return {
        name = senderName,
        realmName = realmName,
        characterKey = senderKey,
        guildRankName = "",
        guildRankIndex = nil,
        isGuildMaster = false,
        inGuild = false,
    }
end

function permissions.RefreshPolicyFromGuild(db)
    db = db or {}
    db.auth = permissions.NormalizePolicy(db.auth, permissions.GetGuildRankMetadata())
    local officerNoteBlacklist = ns.modules.officerNoteBlacklist or {}
    if type(officerNoteBlacklist.RefreshPolicyFromRoster) == "function" then
        db.auth = officerNoteBlacklist.RefreshPolicyFromRoster(db.auth) or db.auth
    end
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

local function policy_audit_actor(updatedBy)
    local actor = permissions.DisplayCharacterKey(updatedBy)
    if actor == "" then
        return "Unknown"
    end

    return actor
end

local function policy_audit_summary(policy)
    policy = permissions.NormalizePolicy(policy)
    local revision = tonumber(policy.revision or 0) or 0
    local restockDefault = tonumber(policy.restockDefault)
    if restockDefault == nil then
        return string.format("Revision %d", revision)
    end

    return string.format("Revision %d | Restock %d", revision, restockDefault)
end

function permissions.BuildPolicyAuditEntry(previousPolicy, nextPolicy, source)
    previousPolicy = permissions.NormalizePolicy(previousPolicy)
    nextPolicy = permissions.NormalizePolicy(nextPolicy)

    return {
        category = "OPTIONS",
        type = "AUTH_POLICY_UPDATED",
        itemName = "Guild Permissions",
        actor = policy_audit_actor(nextPolicy.updatedBy),
        oldValue = policy_audit_summary(previousPolicy),
        newValue = policy_audit_summary(nextPolicy),
        timestamp = tonumber(nextPolicy.updatedAt or 0) or 0,
        revision = tonumber(nextPolicy.revision or 0) or 0,
        source = tostring(source or nextPolicy.guildPolicySource or "local"),
        updatedBy = tostring(nextPolicy.updatedBy or ""),
    }
end

function permissions.AppendPolicyAudit(db, previousPolicy, nextPolicy, source)
    db = db or {}
    db.auditLog = ensure_table(db.auditLog)

    local nextRevision = tonumber((nextPolicy or {}).revision or 0) or 0
    local nextUpdatedBy = tostring((nextPolicy or {}).updatedBy or "")
    local nextTimestamp = tonumber((nextPolicy or {}).updatedAt or 0) or 0
    for _, entry in ipairs(db.auditLog) do
        if entry.type == "AUTH_POLICY_UPDATED"
            and (tonumber(entry.revision or 0) or 0) == nextRevision
            and tostring(entry.updatedBy or "") == nextUpdatedBy
            and (tonumber(entry.timestamp or 0) or 0) == nextTimestamp then
            return false, entry
        end
    end

    local entry = permissions.BuildPolicyAuditEntry(previousPolicy, nextPolicy, source)
    table.insert(db.auditLog, entry)
    return true, entry
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
        policy.blacklistDirectory[hash] = {
            characterKey = characterKey,
            name = name or characterKey,
            reason = reason or "",
            updatedAt = updatedAt or 0,
            hash = hash,
        }
    end

    return policy.blacklist[characterKey]
end

function permissions.RemoveBlacklist(policy, characterKey)
    policy = permissions.NormalizePolicy(policy)
    local removed = policy.blacklist[characterKey]
    local hash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(characterKey) or nil
    if removed ~= nil then
        policy.blacklist[characterKey] = nil
    elseif hash ~= nil then
        for existingKey, entry in pairs(policy.blacklist) do
            local existingHash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(existingKey) or nil
            if existingHash == hash then
                removed = entry
                policy.blacklist[existingKey] = nil
            end
        end
    end
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
    policy.updatedByHash = type(authPolicyCodec.HashCharacterKey) == "function" and authPolicyCodec.HashCharacterKey(policy.updatedBy) or nil
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
