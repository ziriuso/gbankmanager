local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local snapshots = ns.modules.snapshots or {}
local diff = ns.modules.diff or {}

local scanner = ns.modules.scanner or {
    scanInProgress = false,
    tabsToScan = {},
    rawTabs = {},
    waitingForTab = nil,
}

local function current_db()
    ns.state.db = ns.state.db or _G.GBankManagerDB or {}
    ns.state.db.snapshots = ns.state.db.snapshots or {}
    ns.state.db.changeLog = ns.state.db.changeLog or {}
    return ns.state.db
end

function scanner.BeginScan()
    scanner.scanInProgress = true
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
    scanner.waitingForTab = nil
end

function scanner.RecordTabScan(tabData)
    scanner.rawTabs = scanner.rawTabs or {}
    table.insert(scanner.rawTabs, tabData)
end

function scanner.OnGuildBankSlotsChanged(tabIndex)
    scanner.waitingForTab = tabIndex
    return tabIndex
end

function scanner.FinishScan(actor, guildName, previousSnapshot)
    local db = current_db()
    local baseline = previousSnapshot

    if baseline == nil and db.currentSnapshotId ~= nil then
        baseline = db.snapshots[db.currentSnapshotId]
    end

    local currentSnapshot = snapshots.FromTabScan({
        scanId = tostring(_G.time()),
        actor = actor,
        guildName = guildName,
        scannedTabs = scanner.rawTabs,
    })
    local changes = diff.BuildChangeLog(baseline, currentSnapshot)

    db.snapshots[currentSnapshot.scanId] = currentSnapshot
    db.currentSnapshotId = currentSnapshot.scanId

    for _, change in ipairs(changes) do
        change.scanId = currentSnapshot.scanId
        change.scannedAt = currentSnapshot.scannedAt
        table.insert(db.changeLog, change)
    end

    scanner.scanInProgress = false
    scanner.waitingForTab = nil

    return currentSnapshot, changes
end

ns.modules.scanner = scanner
ns.modules.guildBankScanner = scanner

return scanner
