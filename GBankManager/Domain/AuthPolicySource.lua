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
    local function remember_entry(characterKey, entry)
        local hash = (type(entry) == "table" and entry.hash) or (type(codec.HashCharacterKey) == "function" and codec.HashCharacterKey(characterKey) or nil)
        if hash and hash ~= "" then
            knownEntriesByHash[hash] = {
                characterKey = tostring((type(entry) == "table" and entry.characterKey) or characterKey or ""),
                entry = entry,
            }
        end
    end

    localPolicy = permissions.NormalizePolicy(localPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    nextPolicy = permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    if next(nextPolicy.blacklistHashes or {}) == nil and next(nextPolicy.blacklist or {}) == nil then
        nextPolicy.blacklist = localPolicy.blacklist or {}
        nextPolicy.blacklistHashes = localPolicy.blacklistHashes or {}
        nextPolicy.blacklistDirectory = localPolicy.blacklistDirectory or {}
        nextPolicy.blacklistRosterDirectory = localPolicy.blacklistRosterDirectory or {}
        return permissions.NormalizePolicy(nextPolicy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    end
    nextPolicy.blacklist = {}

    for hash, entry in pairs(localPolicy.blacklistDirectory or {}) do
        if type(entry) == "table" then
            local characterKey = entry.characterKey or ("#" .. tostring(hash))
            remember_entry(characterKey, entry)
        end
    end

    for characterKey, entry in pairs(localPolicy.blacklist or {}) do
        remember_entry(characterKey, entry)
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

local function rehydrate_updated_by(localPolicy, nextPolicy)
    local nextHash = tostring((nextPolicy or {}).updatedByHash or "")
    local nextUpdatedBy = tostring((nextPolicy or {}).updatedBy or "")
    if nextUpdatedBy ~= "" then
        if nextHash == "" and type(codec.HashCharacterKey) == "function" then
            nextPolicy.updatedByHash = codec.HashCharacterKey(nextUpdatedBy)
        end
        return nextPolicy
    end

    if nextHash == "" then
        return nextPolicy
    end

    local currentUpdatedBy = tostring((localPolicy or {}).updatedBy or "")
    local currentHash = tostring((localPolicy or {}).updatedByHash or "")
    if currentUpdatedBy ~= "" and (currentHash == nextHash or (type(codec.HashCharacterKey) == "function" and codec.HashCharacterKey(currentUpdatedBy) == nextHash)) then
        nextPolicy.updatedBy = currentUpdatedBy
        nextPolicy.updatedByHash = nextHash
        return nextPolicy
    end

    if type(permissions.GetLivePlayerContext) == "function" then
        local liveContext = permissions.GetLivePlayerContext({})
        local liveCharacterKey = tostring((liveContext or {}).characterKey or "")
        if liveCharacterKey ~= "" and type(codec.HashCharacterKey) == "function" and codec.HashCharacterKey(liveCharacterKey) == nextHash then
            nextPolicy.updatedBy = liveCharacterKey
            nextPolicy.updatedByHash = nextHash
            return nextPolicy
        end
    end

    nextPolicy.updatedBy = "#" .. nextHash
    nextPolicy.updatedByHash = nextHash
    return nextPolicy
end

local function ensure_minimum_settings(db)
    db.ui = type(db.ui) == "table" and db.ui or {}
    db.ui.minimumSettings = type(db.ui.minimumSettings) == "table" and db.ui.minimumSettings or {}
    db.ui.minimumSettings.defaultQuantity = tonumber(db.ui.minimumSettings.defaultQuantity or 100) or 100
    return db.ui.minimumSettings
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

function source.ApplyPolicy(db, policy, options)
    db = db or {}
    options = options or {}
    policy = type(policy) == "table" and policy or {}

    local currentPolicy = permissions.NormalizePolicy((db.auth or {}), permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    local currentRevision = tonumber(currentPolicy.revision or 0) or 0
    local decoded = permissions.NormalizePolicy(policy, permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {})
    local nextRevision = tonumber(decoded.revision or 0) or 0
    if not options.force and nextRevision < currentRevision then
        return false, "stale_revision"
    end

    if not options.force and nextRevision == currentRevision then
        return false, "same_revision"
    end

    decoded = rehydrate_blacklist_details(currentPolicy, decoded)
    decoded = rehydrate_updated_by(currentPolicy, decoded)
    if decoded.restockDefault == nil then
        decoded.restockDefault = currentPolicy.restockDefault
    end
    decoded.guildPolicyString = source.ExportPolicyString(decoded)
    decoded.guildPolicySource = tostring(options.source or decoded.guildPolicySource or "guild_info")
    db.auth = decoded
    local minimumSettings = ensure_minimum_settings(db)
    if decoded.restockDefault ~= nil then
        minimumSettings.defaultQuantity = tonumber(decoded.restockDefault) or minimumSettings.defaultQuantity
    end
    if type(permissions.AppendPolicyAudit) == "function" then
        permissions.AppendPolicyAudit(db, currentPolicy, decoded, decoded.guildPolicySource)
    end
    return true, "applied", decoded
end

function source.ApplyPolicyString(db, policyString, options)
    db = db or {}
    options = options or {}

    local decoded, reason = source.DecodePolicyString(policyString)
    if not decoded then
        return false, reason
    end

    options.source = options.source or "guild_info"
    return source.ApplyPolicy(db, decoded, options)
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
    policy.restockDefault = tonumber((ensure_minimum_settings(db) or {}).defaultQuantity) or policy.restockDefault
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
