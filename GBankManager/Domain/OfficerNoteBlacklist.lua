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

function officerNoteBlacklist.ApplyDesiredBlacklistChanges(policy, desiredPolicy)
    local rankMetadata = permissions.GetGuildRankMetadata and permissions.GetGuildRankMetadata() or {}
    policy = type(permissions.NormalizePolicy) == "function" and permissions.NormalizePolicy(policy, rankMetadata) or (policy or {})
    desiredPolicy = type(permissions.NormalizePolicy) == "function" and permissions.NormalizePolicy(desiredPolicy, rankMetadata) or (desiredPolicy or {})

    local currentByHash = by_hash(policy)
    local desiredByHash = by_hash(desiredPolicy)
    local rosterDirectory = copy_table(policy.blacklistRosterDirectory or desiredPolicy.blacklistRosterDirectory or {})
    local blacklistDirectory = copy_table(policy.blacklistDirectory or {})
    local membershipChanged = false
    local writes = 0

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
        desiredPolicy.blacklistDirectory = blacklistDirectory
        desiredPolicy.blacklistRosterDirectory = rosterDirectory
        return true, "unchanged", desiredPolicy, writes
    end

    if not officerNoteBlacklist.CanEditOfficerNotes() then
        return false, "cannot_edit", desiredPolicy, writes
    end

    if not (_G.C_GuildInfo and type(_G.C_GuildInfo.SetNote) == "function") then
        return false, "write_unavailable", desiredPolicy, writes
    end

    for hash, desired in pairs(desiredByHash) do
        if not currentByHash[hash] then
            local rosterKey, rosterEntry = find_roster_entry_by_hash(rosterDirectory, hash)
            if not rosterEntry or trim(rosterEntry.guid or "") == "" then
                return false, "missing_roster_entry", desiredPolicy, writes
            end

            local nextNote, appendReason = officerNoteBlacklist.AppendTag(rosterEntry.officerNote or "")
            if not nextNote then
                return false, appendReason, desiredPolicy, writes
            end

            _G.C_GuildInfo.SetNote(rosterEntry.guid, nextNote, false)
            rosterEntry.officerNote = nextNote
            rosterEntry.isBlacklisted = true
            rosterDirectory[rosterKey] = rosterEntry
            writes = writes + 1
        end
    end

    for hash in pairs(currentByHash) do
        if not desiredByHash[hash] then
            local rosterKey, rosterEntry = find_roster_entry_by_hash(rosterDirectory, hash)
            if not rosterEntry or trim(rosterEntry.guid or "") == "" then
                return false, "missing_roster_entry", desiredPolicy, writes
            end

            local nextNote = officerNoteBlacklist.RemoveTag(rosterEntry.officerNote or "")
            _G.C_GuildInfo.SetNote(rosterEntry.guid, nextNote, false)
            rosterEntry.officerNote = nextNote
            rosterEntry.isBlacklisted = false
            rosterDirectory[rosterKey] = rosterEntry
            writes = writes + 1
        end
    end

    desiredPolicy.blacklistDirectory = blacklistDirectory
    desiredPolicy.blacklistRosterDirectory = rosterDirectory
    desiredPolicy.blacklist = desiredPolicy.blacklist or {}
    desiredPolicy.blacklistHashes = {}
    for hash in pairs(desiredByHash) do
        desiredPolicy.blacklistHashes[hash] = true
    end

    if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
        _G.C_GuildInfo.GuildRoster()
    end

    return true, "written", desiredPolicy, writes
end

ns.modules.officerNoteBlacklist = officerNoteBlacklist

return officerNoteBlacklist
