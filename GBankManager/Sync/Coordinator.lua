local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local coordinator = ns.modules.syncCoordinator or {}

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
