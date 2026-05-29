local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local peerState = ns.modules.syncPeerState or {}

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function peerState.EnsureState(db)
    db = type(db) == "table" and db or {}
    db.syncState = ensure_table(db.syncState)
    db.syncState.peers = ensure_table(db.syncState.peers)
    return db.syncState
end

function peerState.TouchPeer(db, details)
    db = type(db) == "table" and db or {}
    details = type(details) == "table" and details or {}

    local syncState = peerState.EnsureState(db)
    local guildKey = trim(details.guildKey or (((db.meta or {}).guildName) or "Unknown"))
    local characterKey = trim(details.characterKey)
    if guildKey == "" or characterKey == "" then
        return nil
    end

    syncState.peers[guildKey] = ensure_table(syncState.peers[guildKey])
    local entry = ensure_table(syncState.peers[guildKey][characterKey])
    local seenAt = tonumber(details.seenAt or 0) or 0
    local version = trim(details.version)

    entry.guildKey = guildKey
    entry.characterKey = characterKey
    entry.lastSeen = math.max(tonumber(entry.lastSeen or 0) or 0, seenAt)
    entry.lastMessageType = trim(details.messageType or entry.lastMessageType or "")
    if version ~= "" then
        entry.version = version
    else
        entry.version = entry.version or ""
    end

    syncState.peers[guildKey][characterKey] = entry
    return entry
end

function peerState.GetPeers(db, guildKey)
    db = type(db) == "table" and db or {}
    local syncState = peerState.EnsureState(db)
    guildKey = trim(guildKey or (((db.meta or {}).guildName) or "Unknown"))
    local peers = {}

    for _, entry in pairs(syncState.peers[guildKey] or {}) do
        peers[#peers + 1] = entry
    end

    table.sort(peers, function(left, right)
        local leftSeen = tonumber((left or {}).lastSeen or 0) or 0
        local rightSeen = tonumber((right or {}).lastSeen or 0) or 0
        if leftSeen == rightSeen then
            return tostring((left or {}).characterKey or "") < tostring((right or {}).characterKey or "")
        end
        return leftSeen > rightSeen
    end)

    return peers
end

ns.modules.syncPeerState = peerState

return peerState
