local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local snapshots = ns.modules.snapshots or {}
local diff = ns.modules.diff or {}
local requests = ns.modules.requests or {}

local scanner = ns.modules.scanner or {
    scanInProgress = false,
    tabsToScan = {},
    rawTabs = {},
    waitingForTab = nil,
    totalTabs = 0,
    completedTabs = 0,
    statusText = "No scan yet",
    pendingAutoScan = false,
    autoScanRetryCount = 0,
    waitToken = 0,
}

local AUTO_SCAN_THROTTLE_SECONDS = 600
local AUTO_SCAN_RETRY_DELAY_SECONDS = 0.25
local MAX_AUTO_SCAN_RETRIES = 3
local TAB_SCAN_TIMEOUT_SECONDS = 1.5

local function current_context(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetLivePlayerContext) == "function" then
        return auth.GetLivePlayerContext(db)
    end

    return {}
end

local function current_db()
    local store = ns.data.store or ns.modules.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    local runtime = _G.GBankManagerDB or ns.state.db or {}
    runtime.snapshots = runtime.snapshots or {}
    runtime.changeLog = runtime.changeLog or {}
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function auto_scan_allowed(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if scanner.scanInProgress then
        return false
    end

    if auth and type(auth.Can) == "function" and not auth.Can(current_context(db), "full_ui", db.auth) then
        return false
    end

    local lastScanAt = tonumber((((db or {}).meta or {}).updatedAt) or 0) or 0
    local now = type(_G.time) == "function" and (_G.time() or 0) or 0
    if lastScanAt > 0 and (now - lastScanAt) < AUTO_SCAN_THROTTLE_SECONDS then
        return false
    end

    return true
end

local function report_status(message)
    local syncTransport = ns.modules.syncTransport or {}
    if type(syncTransport.ReportStatus) == "function" then
        return syncTransport.ReportStatus(message)
    end

    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(string.format("GBankManager: %s", tostring(message or "")))
        return true
    end

    if type(_G.print) == "function" then
        _G.print(string.format("GBankManager: %s", tostring(message or "")))
        return true
    end

    return false
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

local function schedule_after(delaySeconds, callback)
    local timer = _G.C_Timer
    if timer and type(timer.After) == "function" then
        timer.After(delaySeconds, callback)
        return true
    end

    if type(callback) == "function" then
        callback()
    end

    return false
end

local function next_scan_id(db, scannedAtUtc)
    db.meta = db.meta or {}
    db.meta.lastScanSequence = (tonumber(db.meta.lastScanSequence or 0) or 0) + 1
    return string.format("%s-%d", tostring(scannedAtUtc or 0), db.meta.lastScanSequence)
end

local function clear_wait_state()
    scanner.waitingForTab = nil
    scanner.waitToken = (tonumber(scanner.waitToken or 0) or 0) + 1
end

local function begin_tab_wait(tabIndex)
    scanner.waitingForTab = tabIndex
    scanner.waitToken = (tonumber(scanner.waitToken or 0) or 0) + 1
    local waitToken = scanner.waitToken

    schedule_after(TAB_SCAN_TIMEOUT_SECONDS, function()
        if not scanner.scanInProgress or scanner.waitingForTab ~= tabIndex or scanner.waitToken ~= waitToken then
            return
        end

        report_status(string.format("Guild bank scan timed out waiting for tab %d. Capturing current tab contents.", tabIndex))
        scanner.OnGuildBankSlotsChanged(tabIndex, "timeout")
    end)
end

local function finish_auto_scan_setup()
    scanner.pendingAutoScan = false
    scanner.autoScanRetryCount = 0
end

local function schedule_auto_scan_retry()
    if scanner.scanInProgress or not scanner.pendingAutoScan then
        return false
    end

    if scanner.autoScanRetryCount >= MAX_AUTO_SCAN_RETRIES then
        scanner.pendingAutoScan = false
        return false
    end

    scanner.autoScanRetryCount = scanner.autoScanRetryCount + 1
    schedule_after(AUTO_SCAN_RETRY_DELAY_SECONDS, function()
        if type(scanner.RetryPendingAutoScan) == "function" then
            scanner.RetryPendingAutoScan()
        end
    end)
    return true
end

local function get_crafted_quality_info(itemInfo)
    local tradeSkillUI = _G.C_TradeSkillUI
    if type(itemInfo) ~= "string" or tradeSkillUI == nil then
        return nil, nil
    end

    local info = nil
    if type(tradeSkillUI.GetItemReagentQualityInfo) == "function" then
        info = tradeSkillUI.GetItemReagentQualityInfo(itemInfo) or info
    end

    if info == nil and type(tradeSkillUI.GetItemCraftedQualityInfo) == "function" then
        info = tradeSkillUI.GetItemCraftedQualityInfo(itemInfo)
    end

    if type(info) == "table" then
        return info.quality, info.iconInventory or info.iconMixed or info.iconChat or info.iconSmall or info.icon
    end

    local quality = nil
    if type(tradeSkillUI.GetItemReagentQualityByItemInfo) == "function" then
        quality = tradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo) or quality
    end

    if quality == nil and type(tradeSkillUI.GetItemCraftedQualityByItemInfo) == "function" then
        quality = tradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo)
    end

    return quality, nil
end

local function finish_if_complete()
    if scanner.completedTabs >= scanner.totalTabs and scanner.totalTabs > 0 then
        scanner.FinishScan(_G.UnitName and _G.UnitName("player") or "Unknown", "Unknown Guild")
        push_status(string.format("Scan complete: %d/%d tabs", scanner.completedTabs, scanner.totalTabs))
        report_status(string.format("Guild bank scan finished (%d/%d tabs).", scanner.completedTabs, scanner.totalTabs))
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

    begin_tab_wait(nextTab)
    push_status(string.format("Scanning %d/%d tabs", scanner.completedTabs, scanner.totalTabs))

    if type(_G.QueryGuildBankTab) == "function" then
        _G.QueryGuildBankTab(nextTab)
    else
        scanner.ReadCurrentTab(nextTab)
        scanner.completedTabs = scanner.completedTabs + 1
        clear_wait_state()
        if not finish_if_complete() then
            advance_scan()
        end
    end
end

function scanner.GetStatusText()
    return scanner.statusText or "No scan yet"
end

function scanner.BeginScan(options)
    local db = current_db()
    local auth = ns.modules.auth or ns.modules.permissions
    options = type(options) == "table" and options or {}
    local manualStart = options.auto ~= true
    if scanner.scanInProgress then
        return scanner:GetStatusText()
    end

    if auth and type(auth.Can) == "function" and not auth.Can(current_context(db), "full_ui", db.auth) then
        scanner.scanInProgress = false
        push_status("Permission denied")
        return scanner:GetStatusText()
    end

    scanner.scanInProgress = true
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
    clear_wait_state()
    scanner.totalTabs = 0
    scanner.completedTabs = 0

    scanner.QueueAccessibleTabs()
    scanner.totalTabs = #scanner.tabsToScan

    if scanner.totalTabs == 0 then
        scanner.scanInProgress = false
        push_status("Open guild bank to scan")
        if not manualStart then
            scanner.pendingAutoScan = true
            schedule_auto_scan_retry()
        end
        return scanner:GetStatusText()
    end

    finish_auto_scan_setup()
    report_status(string.format("Guild bank scan started (%d tabs).", scanner.totalTabs))
    advance_scan()
    return scanner:GetStatusText()
end

function scanner.OnGuildBankOpened()
    local db = current_db()
    if not auto_scan_allowed(db) then
        return false
    end

    scanner.pendingAutoScan = true
    scanner.autoScanRetryCount = 0
    scanner.BeginScan({ auto = true, manual = false })
    return true
end

function scanner.RetryPendingAutoScan()
    if scanner.scanInProgress or not scanner.pendingAutoScan then
        return false
    end

    scanner.BeginScan({ auto = true, manual = false })
    return scanner.scanInProgress
end

function scanner.OnGuildBankTabsUpdated()
    local db = current_db()
    if (not scanner.scanInProgress or scanner.waitingForTab == nil) and scanner.pendingAutoScan then
        return scanner.RetryPendingAutoScan()
    end

    if auto_scan_allowed(db) then
        scanner.pendingAutoScan = true
        scanner.autoScanRetryCount = 0
        return scanner.RetryPendingAutoScan()
    end

    return false
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

                local craftedQuality, craftedQualityIcon = get_crafted_quality_info(link)

                table.insert(tabData.slots, {
                    itemID = itemID,
                    name = itemName,
                    quality = _G.C_Item and type(_G.C_Item.GetItemQualityByID) == "function" and _G.C_Item.GetItemQualityByID(itemID) or nil,
                    craftedQuality = craftedQuality,
                    craftedQualityIcon = craftedQualityIcon,
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
        if scanner.pendingAutoScan then
            scanner.RetryPendingAutoScan()
        end
        return tabIndex
    end

    if tonumber(tabIndex) ~= nil and tonumber(tabIndex) ~= tonumber(scanner.waitingForTab) then
        return tabIndex
    end

    local loadedTab = scanner.waitingForTab
    scanner.ReadCurrentTab(loadedTab)
    scanner.completedTabs = scanner.completedTabs + 1
    clear_wait_state()

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
    local scannedAtUtc = _G.time()

    db.meta = db.meta or {}

    if baseline == nil and db.currentSnapshotId ~= nil then
        baseline = db.snapshots[db.currentSnapshotId]
    end

    local currentSnapshot = snapshots.FromTabScan({
        scanId = next_scan_id(db, scannedAtUtc),
        actor = actor,
        guildName = guildName,
        scannedTabs = scanner.rawTabs,
        scannedAt = scannedAtUtc,
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

    if requests and type(requests.AutoFulfillApprovedFromSnapshot) == "function" then
        requests.AutoFulfillApprovedFromSnapshot(db, currentSnapshot, "Bank Scan", currentSnapshot.scannedAt)
    end

    scanner.scanInProgress = false
    clear_wait_state()
    scanner.tabsToScan = {}
    finish_auto_scan_setup()

    return currentSnapshot, changes
end

ns.modules.scanner = scanner
ns.modules.guildBankScanner = scanner

return scanner
