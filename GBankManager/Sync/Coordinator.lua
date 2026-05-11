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

ns.modules.syncCoordinator = coordinator

return coordinator
