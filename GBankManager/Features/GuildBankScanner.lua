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
    totalTabs = 0,
    completedTabs = 0,
    statusText = "No scan yet",
}

local function current_db()
    ns.state.db = ns.state.db or _G.GBankManagerDB or {}
    _G.GBankManagerDB = ns.state.db
    ns.state.db.snapshots = ns.state.db.snapshots or {}
    ns.state.db.changeLog = ns.state.db.changeLog or {}
    return ns.state.db
end

local function push_status(text)
    scanner.statusText = text

    local mainFrame = ns.modules.mainFrame
    if mainFrame and type(mainFrame.SetScanStatus) == "function" then
        mainFrame:SetScanStatus(text)
    elseif mainFrame and mainFrame.statusText and type(mainFrame.statusText.SetText) == "function" then
        mainFrame.statusText:SetText(text)
    end
end

local function finish_if_complete()
    if scanner.completedTabs >= scanner.totalTabs and scanner.totalTabs > 0 then
        scanner.FinishScan(_G.UnitName and _G.UnitName("player") or "Unknown", "Unknown Guild")
        push_status(string.format("Scan complete: %d/%d tabs", scanner.completedTabs, scanner.totalTabs))
        return true
    end

    return false
end

local function advance_scan()
    if not scanner.scanInProgress or scanner.waitingForTab ~= nil then
        return
    end

    local nextTab = table.remove(scanner.tabsToScan, 1)
    if nextTab == nil then
        finish_if_complete()
        return
    end

    scanner.waitingForTab = nextTab
    push_status(string.format("Scanning %d/%d tabs", scanner.completedTabs, scanner.totalTabs))

    if type(_G.QueryGuildBankTab) == "function" then
        _G.QueryGuildBankTab(nextTab)
    else
        scanner.ReadCurrentTab(nextTab)
        scanner.completedTabs = scanner.completedTabs + 1
        scanner.waitingForTab = nil
        if not finish_if_complete() then
            advance_scan()
        end
    end
end

function scanner.GetStatusText()
    return scanner.statusText or "No scan yet"
end

function scanner.BeginScan()
    scanner.scanInProgress = true
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
    scanner.waitingForTab = nil
    scanner.totalTabs = 0
    scanner.completedTabs = 0

    scanner.QueueAccessibleTabs()
    scanner.totalTabs = #scanner.tabsToScan

    if scanner.totalTabs == 0 then
        scanner.scanInProgress = false
        push_status("Open guild bank to scan")
        return scanner:GetStatusText()
    end

    advance_scan()
    return scanner:GetStatusText()
end

function scanner.QueueAccessibleTabs()
    scanner.tabsToScan = {}

    local tabCount = 0
    if type(_G.GetNumGuildBankTabs) == "function" then
        tabCount = _G.GetNumGuildBankTabs() or 0
    end

    for tabIndex = 1, tabCount do
        local _, _, isViewable = _G.GetGuildBankTabInfo(tabIndex)
        if isViewable then
            table.insert(scanner.tabsToScan, tabIndex)
        end
    end

    return scanner.tabsToScan
end

function scanner.ReadCurrentTab(tabIndex)
    local tabName = "Tab " .. tostring(tabIndex)
    if type(_G.GetGuildBankTabInfo) == "function" then
        tabName = (_G.GetGuildBankTabInfo(tabIndex)) or tabName
    end

    local tabData = {
        index = tabIndex,
        name = tabName,
        slots = {},
    }

    for slot = 1, 98 do
        local _, count = _G.GetGuildBankItemInfo(tabIndex, slot)
        if (count or 0) > 0 then
            local link = _G.GetGuildBankItemLink(tabIndex, slot)
            local itemID = tonumber(string.match(tostring(link or ""), "item:(%d+)"))

            if itemID ~= nil then
                local itemName = "Item:" .. tostring(itemID)
                if _G.C_Item and type(_G.C_Item.GetItemNameByID) == "function" then
                    itemName = _G.C_Item.GetItemNameByID(itemID) or itemName
                end

                table.insert(tabData.slots, {
                    itemID = itemID,
                    name = itemName,
                    quality = _G.C_Item and type(_G.C_Item.GetItemQualityByID) == "function" and _G.C_Item.GetItemQualityByID(itemID) or nil,
                    count = count,
                })
            end
        end
    end

    scanner.RecordTabScan(tabData)
    return tabData
end

function scanner.RecordTabScan(tabData)
    scanner.rawTabs = scanner.rawTabs or {}
    table.insert(scanner.rawTabs, tabData)
end

function scanner.OnGuildBankSlotsChanged(tabIndex)
    if not scanner.scanInProgress or scanner.waitingForTab == nil then
        return tabIndex
    end

    local loadedTab = scanner.waitingForTab
    scanner.ReadCurrentTab(loadedTab)
    scanner.completedTabs = scanner.completedTabs + 1
    scanner.waitingForTab = nil

    if finish_if_complete() then
        return loadedTab
    end

    push_status(string.format("Scanning %d/%d tabs", scanner.completedTabs, scanner.totalTabs))
    advance_scan()
    return loadedTab
end

function scanner.FinishScan(actor, guildName, previousSnapshot)
    local db = current_db()
    local baseline = previousSnapshot

    db.meta = db.meta or {}

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
    db.meta.updatedAt = currentSnapshot.scannedAt
    db.meta.guildName = guildName or db.meta.guildName or "Unknown Guild"

    for _, change in ipairs(changes) do
        change.scanId = currentSnapshot.scanId
        change.scannedAt = currentSnapshot.scannedAt
        table.insert(db.changeLog, change)
    end

    scanner.scanInProgress = false
    scanner.waitingForTab = nil
    scanner.tabsToScan = {}

    return currentSnapshot, changes
end

ns.modules.scanner = scanner
ns.modules.guildBankScanner = scanner

return scanner
