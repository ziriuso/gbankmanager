local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local officerNoteBlacklist = ns.modules.officerNoteBlacklist or {}
local permissions = ns.modules.permissions or ns.modules.auth or {}

officerNoteBlacklist.TAG = "[GBMBL]"
officerNoteBlacklist.MAX_NOTE_LENGTH = 31

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copy_table(source)
    local target = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            target[key] = nested
        else
            target[key] = value
        end
    end
    return target
end

local function by_hash(policy)
    local mapped = {}
    for characterKey, entry in pairs((policy or {}).blacklist or {}) do
        local hash = type(permissions.HashCharacterKey) == "function" and permissions.HashCharacterKey(characterKey) or nil
        if hash and hash ~= "" then
            mapped[hash] = {
                characterKey = characterKey,
                entry = entry,
            }
        end
    end
    return mapped
end

local function find_roster_entry_by_hash(rosterDirectory, hash)
    for characterKey, entry in pairs(rosterDirectory or {}) do
        local existingHash = type(permissions.HashCharacterKey) == "function" and permissions.HashCharacterKey(characterKey) or nil
        if existingHash == hash then
            return characterKey, entry
        end
    end
    return nil, nil
end

function officerNoteBlacklist.CanViewOfficerNotes()
    return _G.C_GuildInfo and type(_G.C_GuildInfo.CanViewOfficerNote) == "function" and _G.C_GuildInfo.CanViewOfficerNote() == true
end

function officerNoteBlacklist.CanEditOfficerNotes()
    return _G.C_GuildInfo and type(_G.C_GuildInfo.CanEditOfficerNote) == "function" and _G.C_GuildInfo.CanEditOfficerNote() == true
end

function officerNoteBlacklist.HasBuildRestrictions()
    return _G.C_Secrets and type(_G.C_Secrets.HasSecretRestrictions) == "function" and _G.C_Secrets.HasSecretRestrictions() == true
end

function officerNoteBlacklist.HasTag(noteText)
    return string.find(tostring(noteText or ""), "%[GBMBL%]") ~= nil
end

function officerNoteBlacklist.AppendTag(noteText)
    local normalized = trim(noteText)
    if officerNoteBlacklist.HasTag(normalized) then
        return normalized, "already_tagged"
    end

    local nextNote = officerNoteBlacklist.TAG
    if normalized ~= "" then
        nextNote = string.format("%s %s", normalized, officerNoteBlacklist.TAG)
    end

    if string.len(nextNote) > officerNoteBlacklist.MAX_NOTE_LENGTH then
        return nil, "note_too_long"
    end

    return nextNote, "tagged"
end

function officerNoteBlacklist.RemoveTag(noteText)
    local normalized = tostring(noteText or "")
    normalized = normalized:gsub("%s*%[GBMBL%]%s*", " ")
    normalized = normalized:gsub("%s+", " ")
    return trim(normalized)
end

function officerNoteBlacklist.BuildCharacterKeyFromRosterName(rosterName, currentRealm)
    local normalized = trim(rosterName)
    if normalized == "" then
        return ""
    end

    local characterName, realmName = string.match(normalized, "^([^%-]+)%-(.+)$")
    if characterName and realmName and characterName ~= "" and realmName ~= "" then
        if type(permissions.NormalizeEnteredCharacterKey) == "function" then
            return permissions.NormalizeEnteredCharacterKey(string.format("%s-%s", characterName, realmName), currentRealm)
        end
        return string.format("%s-%s", characterName, realmName)
    end

    if type(permissions.NormalizeEnteredCharacterKey) == "function" then
        return permissions.NormalizeEnteredCharacterKey(normalized, currentRealm)
    end
    return string.format("%s-%s", normalized, tostring(currentRealm or ""))
end

function officerNoteBlacklist.GetRosterMembers(currentRealm)
    local members = {}

    if type(_G.GetNumGuildMembers) == "function" and type(_G.GetGuildRosterInfo) == "function" then
        local count = tonumber(_G.GetNumGuildMembers() or 0) or 0
        for index = 1, count do
            local values = { _G.GetGuildRosterInfo(index) }
            local rosterName = values[1]
            local officerNote = values[8] or ""
            local guid = values[17] or values[#values]
            local characterKey = officerNoteBlacklist.BuildCharacterKeyFromRosterName(rosterName, currentRealm)
            if characterKey ~= "" then
                local displayName = tostring(rosterName or "")
                local characterName = displayName:match("^([^%-]+)")
                members[#members + 1] = {
                    characterKey = characterKey,
                    rosterIndex = index,
                    displayName = displayName,
                    name = trim(characterName or displayName),
                    officerNote = tostring(officerNote or ""),
                    guid = type(guid) == "string" and guid or nil,
                }
            end
        end
    end

    return members
end

local function merge_roster_directory(baseDirectory, rosterMembers, updatedAt)
    local nextRosterDirectory = copy_table(baseDirectory or {})

    for _, member in ipairs(rosterMembers or {}) do
        nextRosterDirectory[member.characterKey] = {
            guid = member.guid,
            rosterIndex = member.rosterIndex,
            officerNote = member.officerNote,
            isBlacklisted = officerNoteBlacklist.HasTag(member.officerNote),
            updatedAt = tonumber(updatedAt or 0) or 0,
        }
    end

    return nextRosterDirectory
end

local function refresh_roster_directory(policy, desiredPolicy)
    local currentRealm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or ""
    local rosterMembers = officerNoteBlacklist.GetRosterMembers(currentRealm)
    if #rosterMembers == 0 then
        return copy_table((policy or {}).blacklistRosterDirectory or (desiredPolicy or {}).blacklistRosterDirectory or {}), false
    end

    local updatedAt = tonumber(((desiredPolicy or {}).updatedAt or (policy or {}).updatedAt or 0)) or 0
    return merge_roster_directory((policy or {}).blacklistRosterDirectory or (desiredPolicy or {}).blacklistRosterDirectory or {}, rosterMembers, updatedAt), true
end

local function finalize_desired_policy_state(desiredPolicy, blacklistDirectory, rosterDirectory, desiredByHash)
    desiredPolicy.blacklistDirectory = blacklistDirectory
    desiredPolicy.blacklistRosterDirectory = rosterDirectory
    desiredPolicy.blacklist = desiredPolicy.blacklist or {}
    desiredPolicy.blacklistHashes = {}
    for hash in pairs(desiredByHash or {}) do
        desiredPolicy.blacklistHashes[hash] = true
    end
    return desiredPolicy
end

function officerNoteBlacklist.BuildDesiredBlacklistWritePlan(policy, desiredPolicy, options)
    options = options or {}
    local rankMetadata = permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {}
    policy = type(permissions.NormalizePolicy) == "function" and permissions.NormalizePolicy(policy, rankMetadata) or (policy or {})
    desiredPolicy = type(permissions.NormalizePolicy) == "function" and permissions.NormalizePolicy(desiredPolicy, rankMetadata) or (desiredPolicy or {})

    local currentByHash = by_hash(policy)
    local desiredByHash = by_hash(desiredPolicy)
    local rosterDirectory = copy_table(policy.blacklistRosterDirectory or desiredPolicy.blacklistRosterDirectory or {})
    local blacklistDirectory = copy_table(policy.blacklistDirectory or {})
    local membershipChanged = false

    for hash, desired in pairs(desiredByHash) do
        local desiredEntry = type(desired.entry) == "table" and desired.entry or {}
        blacklistDirectory[hash] = {
            characterKey = desired.characterKey,
            name = tostring(desiredEntry.name or desired.characterKey or ""),
            reason = tostring(desiredEntry.reason or ""),
            updatedAt = tonumber(desiredEntry.updatedAt or desiredPolicy.updatedAt or 0) or 0,
            hash = hash,
        }
        if not currentByHash[hash] then
            membershipChanged = true
        end
    end

    for hash in pairs(currentByHash) do
        if not desiredByHash[hash] then
            membershipChanged = true
        end
    end

    if not membershipChanged then
        desiredPolicy = finalize_desired_policy_state(desiredPolicy, blacklistDirectory, rosterDirectory, desiredByHash)
        return true, "unchanged", {
            writes = {},
            rosterDirectory = rosterDirectory,
            hadLiveRoster = false,
            desiredByHash = desiredByHash,
        }, desiredPolicy
    end

    if not officerNoteBlacklist.CanEditOfficerNotes() then
        return false, "cannot_edit", nil, desiredPolicy
    end

    local hadLiveRoster = false
    rosterDirectory, hadLiveRoster = refresh_roster_directory(policy, desiredPolicy)

    local writes = {}

    for hash, desired in pairs(desiredByHash) do
        if not currentByHash[hash] then
            local rosterKey, rosterEntry = find_roster_entry_by_hash(rosterDirectory, hash)
            if not rosterEntry then
                if not options.retryAfterRoster and _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
                    _G.C_GuildInfo.GuildRoster()
                    return false, "refresh_pending", nil, desiredPolicy
                end
                return false, "missing_roster_entry", nil, desiredPolicy
            end

            local nextNote, appendReason = officerNoteBlacklist.AppendTag(rosterEntry.officerNote or "")
            if not nextNote then
                return false, appendReason, nil, desiredPolicy
            end

            writes[#writes + 1] = {
                action = "add",
                hash = hash,
                characterKey = rosterKey,
                guid = trim(rosterEntry.guid or ""),
                rosterIndex = tonumber(rosterEntry.rosterIndex or 0) or 0,
                currentNote = tostring(rosterEntry.officerNote or ""),
                nextNote = nextNote,
                expectedBlacklisted = true,
            }
        end
    end

    for hash in pairs(currentByHash) do
        if not desiredByHash[hash] then
            local rosterKey, rosterEntry = find_roster_entry_by_hash(rosterDirectory, hash)
            if not rosterEntry then
                if not options.retryAfterRoster and _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
                    _G.C_GuildInfo.GuildRoster()
                    return false, "refresh_pending", nil, desiredPolicy
                end
                return false, "missing_roster_entry", nil, desiredPolicy
            end

            writes[#writes + 1] = {
                action = "remove",
                hash = hash,
                characterKey = rosterKey,
                guid = trim(rosterEntry.guid or ""),
                rosterIndex = tonumber(rosterEntry.rosterIndex or 0) or 0,
                currentNote = tostring(rosterEntry.officerNote or ""),
                nextNote = officerNoteBlacklist.RemoveTag(rosterEntry.officerNote or ""),
                expectedBlacklisted = false,
            }
        end
    end

    desiredPolicy = finalize_desired_policy_state(desiredPolicy, blacklistDirectory, rosterDirectory, desiredByHash)

    return true, "plan_ready", {
        writes = writes,
        rosterDirectory = rosterDirectory,
        hadLiveRoster = hadLiveRoster,
        desiredByHash = desiredByHash,
    }, desiredPolicy
end

function officerNoteBlacklist.RefreshPolicyFromRoster(policy)
    if not officerNoteBlacklist.CanViewOfficerNotes() then
        return policy
    end

    local rankMetadata = permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {}
    policy = type(permissions.NormalizePolicy) == "function" and permissions.NormalizePolicy(policy, rankMetadata) or (policy or {})

    local currentRealm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or ""
    local rosterMembers = officerNoteBlacklist.GetRosterMembers(currentRealm)
    if #rosterMembers == 0 then
        if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
            _G.C_GuildInfo.GuildRoster()
        end
        return policy
    end

    local existingDirectory = copy_table(policy.blacklistDirectory or {})
    local nextBlacklist = {}
    local nextHashes = {}
    local nextRosterDirectory = {}

    for _, member in ipairs(rosterMembers) do
        local hash = type(permissions.HashCharacterKey) == "function" and permissions.HashCharacterKey(member.characterKey) or nil
        local tagged = officerNoteBlacklist.HasTag(member.officerNote)
        nextRosterDirectory[member.characterKey] = {
            guid = member.guid,
            rosterIndex = member.rosterIndex,
            officerNote = member.officerNote,
            isBlacklisted = tagged,
            updatedAt = tonumber(policy.updatedAt or 0) or 0,
        }

        if hash and hash ~= "" and tagged then
            local learned = existingDirectory[hash] or (policy.blacklist or {})[member.characterKey] or {}
            existingDirectory[hash] = {
                characterKey = member.characterKey,
                name = trim((learned or {}).name or member.name or member.displayName),
                reason = tostring((learned or {}).reason or ""),
                updatedAt = tonumber((learned or {}).updatedAt or policy.updatedAt or 0) or 0,
                hash = hash,
            }
            nextBlacklist[member.characterKey] = {
                name = existingDirectory[hash].name ~= "" and existingDirectory[hash].name or member.characterKey,
                reason = existingDirectory[hash].reason or "",
                updatedAt = existingDirectory[hash].updatedAt or 0,
                hash = hash,
            }
            nextHashes[hash] = true
        end
    end

    policy.blacklist = nextBlacklist
    policy.blacklistHashes = nextHashes
    policy.blacklistDirectory = existingDirectory
    policy.blacklistRosterDirectory = nextRosterDirectory

    if type(permissions.NormalizePolicy) == "function" then
        policy = permissions.NormalizePolicy(policy, rankMetadata)
    end

    return policy
end

function officerNoteBlacklist.ApplyDesiredBlacklistChanges(policy, desiredPolicy, options)
    options = options or {}
    local writes = 0
    local planned, reason, plan, updatedPolicy = officerNoteBlacklist.BuildDesiredBlacklistWritePlan(policy, desiredPolicy, options)
    if not planned then
        return false, reason, updatedPolicy or desiredPolicy, writes
    end
    desiredPolicy = updatedPolicy or desiredPolicy

    if officerNoteBlacklist.HasBuildRestrictions() then
        return false, "build_restricted", desiredPolicy, writes, plan
    end

    if type(_G.GuildRosterSetOfficerNote) ~= "function" and not (_G.C_GuildInfo and type(_G.C_GuildInfo.SetNote) == "function") then
        return false, "write_unavailable", desiredPolicy, writes, plan
    end

    for _, write in ipairs(plan.writes or {}) do
        if type(_G.GuildRosterSetOfficerNote) == "function" and tonumber(write.rosterIndex or 0) > 0 then
            _G.GuildRosterSetOfficerNote(tonumber(write.rosterIndex), write.nextNote)
        elseif type(_G.GuildRosterSetOfficerNote) == "function" then
            if not options.retryAfterRoster and _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
                _G.C_GuildInfo.GuildRoster()
                return false, "refresh_pending", desiredPolicy, writes, plan
            end
            return false, "missing_roster_entry", desiredPolicy, writes, plan
        elseif trim(write.guid or "") ~= "" and _G.C_GuildInfo and type(_G.C_GuildInfo.SetNote) == "function" then
            _G.C_GuildInfo.SetNote(write.guid, write.nextNote, false)
        else
            return false, "write_unavailable", desiredPolicy, writes, plan
        end
        writes = writes + 1
    end

    if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
        _G.C_GuildInfo.GuildRoster()
    end

    return true, "written", desiredPolicy, writes, plan
end

ns.modules.officerNoteBlacklist = officerNoteBlacklist

return officerNoteBlacklist
