local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local coordinator = ns.modules.syncCoordinator or {}
local permissions = ns.modules.auth or ns.modules.permissions or {}

local rank = {
    MEMBER = 1,
    OFFICER = 2,
    GUILDMASTER = 3,
}

function coordinator.ResolveConflict(localRecord, remoteRecord)
    localRecord = localRecord or {}
    remoteRecord = remoteRecord or {}

    local localRank = rank[localRecord.role] or 0
    local remoteRank = rank[remoteRecord.role] or 0

    if remoteRank > localRank then
        return remoteRecord
    end

    if remoteRank < localRank then
        return localRecord
    end

    if (remoteRecord.updatedAt or 0) > (localRecord.updatedAt or 0) then
        return remoteRecord
    end

    return localRecord
end

local function auth_policy_authority_rank(record)
    record = record or {}
    if tonumber(record.updatedByRankIndex) == 0 then
        return 2
    end

    local authManage = ((record.capabilities or {}).auth_manage) or {}
    if next(authManage) ~= nil then
        return 1
    end

    return 0
end

local function workflow_authority_rank(record)
    record = record or {}
    local rankIndex = tonumber(record.updatedByRankIndex)
    if rankIndex == 0 then
        return 2
    end

    if rankIndex ~= nil and rankIndex <= 1 then
        return 1
    end

    return 0
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function build_character_key(name, realmName)
    if type(permissions.BuildCharacterKey) == "function" then
        return permissions.BuildCharacterKey(name, realmName)
    end

    local resolvedName = trim(name)
    local resolvedRealm = trim(realmName)
    if resolvedName == "" then
        return ""
    end

    if resolvedRealm == "" then
        return resolvedName
    end

    return string.format("%s-%s", resolvedName, resolvedRealm)
end

local function append_unique_recipient(recipients, seenKeys, recipient)
    recipient = type(recipient) == "table" and recipient or {}
    local dedupeKey = trim(recipient.characterKey)
    if dedupeKey == "" then
        dedupeKey = trim(recipient.target or recipient.name)
    end
    if dedupeKey == "" or seenKeys[dedupeKey] == true then
        return
    end

    seenKeys[dedupeKey] = true
    recipients[#recipients + 1] = recipient
end

local function roster_context(values, guildName)
    local rosterName = trim(values[1])
    if rosterName == "" then
        return nil
    end

    local name, realmName = rosterName:match("^([^%-]+)%-(.+)$")
    if not name then
        name = rosterName
        realmName = trim(type(_G.GetRealmName) == "function" and _G.GetRealmName() or "")
    end

    local rankIndex = tonumber(values[3])
    local context = {
        target = rosterName,
        name = trim(name),
        realmName = trim(realmName),
        characterKey = build_character_key(name, realmName),
        guildName = guildName,
        guildRankName = trim(values[2]),
        guildRankIndex = rankIndex,
        isGuildMaster = rankIndex == 0,
        inGuild = true,
    }

    return context
end

function coordinator.ResolveRequestRecipients(db, request, actorContext, policy)
    db = db or {}
    request = type(request) == "table" and request or {}
    actorContext = type(actorContext) == "table" and actorContext or {}
    policy = type(policy) == "table" and policy or ((db or {}).auth or {})

    local recipients = {}
    local seenKeys = {}
    local guildName = trim((((db or {}).meta or {}).guildName) or actorContext.guildName)

    if type(_G.GetNumGuildMembers) == "function" and type(_G.GetGuildRosterInfo) == "function" then
        local memberCount = tonumber(_G.GetNumGuildMembers() or 0) or 0
        for index = 1, memberCount do
            local context = roster_context({ _G.GetGuildRosterInfo(index) }, guildName)
            if context and type(permissions.GetEffectiveAccessProfile) == "function" and permissions.GetEffectiveAccessProfile(context, policy) == "full_shell" then
                append_unique_recipient(recipients, seenKeys, context)
            end
        end
    end

    local submitterName = trim(actorContext.name or request.requester)
    local submitterTarget = submitterName
    local submitterCharacterKey = trim(actorContext.characterKey or request.requesterCharacterKey)
    if submitterTarget ~= "" then
        append_unique_recipient(recipients, seenKeys, {
            target = submitterTarget,
            name = submitterName,
            characterKey = submitterCharacterKey,
        })
    end

    return recipients
end

function coordinator.ResolveRequestConflict(localRequest, remoteRequest)
    localRequest = localRequest or {}
    remoteRequest = remoteRequest or {}

    local localAuthority = workflow_authority_rank(localRequest)
    local remoteAuthority = workflow_authority_rank(remoteRequest)
    if remoteAuthority > localAuthority then
        return remoteRequest
    end

    if remoteAuthority < localAuthority then
        return localRequest
    end

    if (remoteRequest.updatedAt or 0) > (localRequest.updatedAt or 0) then
        return remoteRequest
    end

    if (remoteRequest.updatedAt or 0) < (localRequest.updatedAt or 0) then
        return localRequest
    end

    if tostring(remoteRequest.updatedBy or "") > tostring(localRequest.updatedBy or "") then
        return remoteRequest
    end

    return localRequest
end

function coordinator.ResolveAuthConflict(localPolicy, remotePolicy)
    localPolicy = localPolicy or {}
    remotePolicy = remotePolicy or {}

    local localRevision = tonumber(localPolicy.revision or 0) or 0
    local remoteRevision = tonumber(remotePolicy.revision or 0) or 0
    if remoteRevision > localRevision then
        return remotePolicy
    end

    if remoteRevision < localRevision then
        return localPolicy
    end

    local localAuthority = auth_policy_authority_rank(localPolicy)
    local remoteAuthority = auth_policy_authority_rank(remotePolicy)

    if remoteAuthority > localAuthority then
        return remotePolicy
    end

    if remoteAuthority < localAuthority then
        return localPolicy
    end

    if (remotePolicy.updatedAt or 0) > (localPolicy.updatedAt or 0) then
        return remotePolicy
    end

    if (remotePolicy.updatedAt or 0) < (localPolicy.updatedAt or 0) then
        return localPolicy
    end

    if tostring(remotePolicy.updatedBy or "") > tostring(localPolicy.updatedBy or "") then
        return remotePolicy
    end

    return localPolicy
end

ns.modules.syncCoordinator = coordinator

return coordinator
