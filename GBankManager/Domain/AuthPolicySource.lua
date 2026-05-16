local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local source = ns.modules.authPolicySource or {}
local codec = ns.modules.authPolicyCodec or {}
local permissions = ns.modules.permissions or ns.modules.auth or {}

local function read_guild_info_text()
    if _G.C_GuildInfo and type(_G.C_GuildInfo.GetInfoText) == "function" then
        return _G.C_GuildInfo.GetInfoText()
    end

    if type(_G.GetGuildInfoText) == "function" then
        return _G.GetGuildInfoText()
    end

    return ""
end

local function write_guild_info_text(text)
    local wrote = false

    if _G.C_GuildInfo and type(_G.C_GuildInfo.SetInfoText) == "function" then
        _G.C_GuildInfo.SetInfoText(text)
        wrote = true
    end

    if type(_G.SetGuildInfoText) == "function" then
        local result = _G.SetGuildInfoText(text)
        wrote = result ~= false or wrote
    end

    return wrote
end

local function guild_info_contains_policy(text, policyString)
    text = tostring(text or "")
    policyString = tostring(policyString or "")
    return policyString ~= "" and string.find(text, policyString, 1, true) ~= nil
end

local function rehydrate_blacklist_details(localPolicy, nextPolicy)
    local knownEntriesByHash = {}

    localPolicy = permissions.NormalizePolicy(localPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    nextPolicy = permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    nextPolicy.blacklist = {}

    for characterKey, entry in pairs(localPolicy.blacklist or {}) do
        local hash = (entry and entry.hash) or (type(codec.HashCharacterKey) == "function" and codec.HashCharacterKey(characterKey) or nil)
        if hash then
            knownEntriesByHash[hash] = {
                characterKey = characterKey,
                entry = entry,
            }
        end
    end

    for hash in pairs(nextPolicy.blacklistHashes or {}) do
        local known = knownEntriesByHash[hash]
        if known then
            nextPolicy.blacklist[known.characterKey] = {
                name = known.entry.name or known.characterKey,
                reason = known.entry.reason or "",
                updatedAt = known.entry.updatedAt or nextPolicy.updatedAt or 0,
                hash = hash,
            }
        else
            nextPolicy.blacklist["#" .. hash] = {
                name = "#" .. hash,
                reason = "Synced blacklist",
                updatedAt = nextPolicy.updatedAt or 0,
                hash = hash,
            }
        end
    end

    return permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
end

function source.ExportPolicyString(policy)
    return codec.EncodePolicy(permissions.NormalizePolicy(policy or {}, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {}))
end

function source.DecodePolicyString(policyString)
    local rankMetadata = type(permissions.GetGuildRankMetadata) == "function" and permissions.GetGuildRankMetadata() or {}
    local decoded = codec.DecodePolicyString(policyString, rankMetadata)
    if not decoded then
        return nil, "missing_snippet"
    end

    return permissions.NormalizePolicy(decoded, rankMetadata), "ok"
end

function source.ApplyPolicyString(db, policyString, options)
    db = db or {}
    options = options or {}

    local decoded, reason = source.DecodePolicyString(policyString)
    if not decoded then
        return false, reason
    end

    local currentPolicy = permissions.NormalizePolicy((db.auth or {}), permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    local currentRevision = tonumber(currentPolicy.revision or 0) or 0
    local nextRevision = tonumber(decoded.revision or 0) or 0
    if not options.force and nextRevision < currentRevision then
        return false, "stale_revision"
    end

    if not options.force and nextRevision == currentRevision then
        return false, "same_revision"
    end

    decoded = rehydrate_blacklist_details(currentPolicy, decoded)
    decoded.guildPolicyString = source.ExportPolicyString(decoded)
    decoded.guildPolicySource = "guild_info"
    db.auth = decoded
    return true, "applied", decoded
end

function source.PullPolicyFromGuildInfo(db, options)
    local policyString = codec.ExtractPolicyString(read_guild_info_text())
    if not policyString then
        return false, "missing_snippet"
    end

    return source.ApplyPolicyString(db, policyString, options)
end

function source.PushPolicyToGuildInfo(db, options)
    db = db or {}
    options = options or {}

    local policy = permissions.NormalizePolicy(db.auth or {}, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    local policyString = source.ExportPolicyString(policy)
    policy.guildPolicyString = policyString

    if options.manualOnly then
        policy.guildPolicySource = "local"
        db.auth = policy
        return false, "manual_only", policyString
    end

    local nextText = codec.InjectPolicyString(read_guild_info_text(), policyString)
    if string.len(nextText or "") > 499 then
        policy.guildPolicySource = "local"
        db.auth = policy
        return false, "write_failed", policyString
    end

    local wrote = write_guild_info_text(nextText)
    if not wrote then
        policy.guildPolicySource = "local"
        db.auth = policy
        return false, "write_failed", policyString
    end

    local confirmedText = read_guild_info_text()
    if not guild_info_contains_policy(confirmedText, policyString) then
        policy.guildPolicySource = "local"
        db.auth = policy
        return false, "write_failed", policyString
    end

    policy.guildPolicySource = "guild_info"
    db.auth = policy
    return true, "written", policyString
end

ns.modules.authPolicySource = source

return source
