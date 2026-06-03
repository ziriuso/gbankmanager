local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local snapshots = ns.modules.snapshots or {}
local diff = ns.modules.diff or {}
local requests = ns.modules.requests or {}
local bankLedger = ns.modules.bankLedger or {}

local scanner = ns.modules.scanner or {
    scanInProgress = false,
    tabsToScan = {},
    rawTabs = {},
    waitingForTab = nil,
    totalTabs = 0,
    completedTabs = 0,
    statusText = "No scan yet",
    pendingAutoScan = false,
    inventoryScanAuto = false,
    autoScanRetryCount = 0,
    inventoryScanCanceled = false,
    waitToken = 0,
    ledgerScanInProgress = false,
    ledgerTargets = {},
    ledgerScanStartedAt = 0,
    pendingLedgerScanAfterInventory = false,
    pendingLedgerScanOptions = nil,
    pendingLedgerAutoScan = false,
    ledgerMergedItemRows = 0,
    ledgerMergedMoneyRows = 0,
    pendingLedgerSyncPayloads = {},
    ledgerScanToken = 0,
    ledgerFinalizeToken = 0,
    guildBankOpen = false,
    passiveLedgerRefreshToken = 0,
    passiveLedgerRefreshActive = false,
    ledgerScanSilent = false,
}

local AUTO_SCAN_RETRY_DELAY_SECONDS = 0.25
local MAX_AUTO_SCAN_RETRIES = 20
local TAB_SCAN_TIMEOUT_SECONDS = 3.0
local TAB_SCAN_ADVANCE_DELAY_SECONDS = 0.5
local LEDGER_QUERY_SETTLE_DELAY_SECONDS = 0.5
local LEDGER_QUERY_SETTLE_PASSES = 3
local LEDGER_TARGET_TIMEOUT_SECONDS = 2.0
local PASSIVE_LEDGER_RESCAN_SECONDS = 3.0

local finish_ledger_scan
local cancel_ledger_scan
local current_tab_name
local capture_all_ledger_targets
local query_ledger_target
local schedule_ledger_scan_finalize
local schedule_passive_ledger_refresh
local refresh_ledger_view_if_visible
local advance_scan

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function current_context(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetLivePlayerContext) == "function" then
        return auth.GetLivePlayerContext(db)
    end

    return {}
end

local function current_guild_key(db)
    local store = ns.modules.store or ns.data.store
    local root = (ns.state or {}).dbRoot
    local rootGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if rootGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(rootGuildKey)) then
        return rootGuildKey
    end

    local dbGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    if dbGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(dbGuildKey)) then
        return dbGuildKey
    end

    local context = current_context(db)
    return tostring(context.guildName or "Unknown")
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

local function is_guild_bank_open_now()
    if scanner.guildBankOpen == true then
        return true
    end

    local interactionType = (((_G.Enum or {}).PlayerInteractionType or {}).GuildBanker)
    local interactionManager = _G.C_PlayerInteractionManager
    local isInteracting = type(interactionManager) == "table" and interactionManager.IsInteractingWithNpcOfType or nil
    if interactionType ~= nil and type(isInteracting) == "function" then
        local ok, active = pcall(isInteracting, interactionType)
        if ok and active == true then
            return true
        end
    end

    local guildBankFrame = _G.GuildBankFrame
    if type(guildBankFrame) == "table" and type(guildBankFrame.IsShown) == "function" then
        local ok, shown = pcall(guildBankFrame.IsShown, guildBankFrame)
        if ok and shown == true then
            return true
        end
    end

    return false
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
    local intervalSeconds = 300
    if bankLedger and type(bankLedger.GetSettings) == "function" then
        local settings = bankLedger.GetSettings(db)
        intervalSeconds = math.max(300, tonumber((settings or {}).ledgerScanIntervalSeconds or 300) or 300)
    end
    if lastScanAt > 0 and (now - lastScanAt) < intervalSeconds then
        return false
    end

    return true
end

local function ledger_scan_allowed(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if scanner.ledgerScanInProgress then
        return false
    end

    if auth and type(auth.Can) == "function" and not auth.Can(current_context(db), "full_ui", db.auth) then
        return false
    end

    if bankLedger and type(bankLedger.ShouldScan) == "function" then
        local now = type(_G.time) == "function" and (_G.time() or 0) or 0
        return bankLedger.ShouldScan(db, now)
    end

    return false
end

local function report_status(message)
    scanner.statusText = tostring(message or "")
    local mainFrame = ns.modules.mainFrame
    if mainFrame and type(mainFrame.SetScanStatus) == "function" then
        mainFrame:SetScanStatus(scanner.statusText)
    elseif mainFrame and mainFrame.statusText and type(mainFrame.statusText.SetText) == "function" then
        mainFrame.statusText:SetText(scanner.statusText)
    end

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
        timer.After(delaySeconds, function()
            local ok, err = xpcall(function()
                if type(callback) == "function" then
                    callback()
                end
            end, debugstack or function(problem)
                return tostring(problem)
            end)
            if not ok then
                report_status(string.format("Guild bank ledger scan failed: %s", tostring(err or "unknown error")))
            end
        end)
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

local function cancel_inventory_scan()
    if not scanner.scanInProgress then
        return false
    end

    scanner.scanInProgress = false
    scanner.inventoryScanCanceled = true
    scanner.inventoryScanAuto = false
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
    scanner.totalTabs = 0
    scanner.completedTabs = 0
    clear_wait_state()
    finish_auto_scan_setup()
    return true
end

local function clear_ledger_wait_state()
    scanner.ledgerFinalizeToken = (tonumber(scanner.ledgerFinalizeToken or 0) or 0) + 1
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
        local finishedSnapshot = scanner.FinishScan(_G.UnitName and _G.UnitName("player") or "Unknown", "Unknown Guild")
        if finishedSnapshot == nil then
            return true
        end

        push_status(string.format("Scan complete: %d/%d tabs", scanner.completedTabs, scanner.totalTabs))
        report_status(string.format("Guild bank scan finished (%d/%d tabs).", scanner.completedTabs, scanner.totalTabs))
        return true
    end

    return false
end

local function schedule_next_inventory_tab()
    schedule_after(TAB_SCAN_ADVANCE_DELAY_SECONDS, function()
        advance_scan()
    end)
end

advance_scan = function()
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
        scanner.ReadCurrentTab(nextTab, "direct")
        scanner.completedTabs = scanner.completedTabs + 1
        clear_wait_state()
        if not finish_if_complete() then
            schedule_next_inventory_tab()
        end
    end
end

function scanner.GetStatusText()
    return scanner.statusText or "No scan yet"
end

function scanner.BeginScan(options)
    if type(scanner.SyncGuildBankOpenState) == "function" then
        scanner.SyncGuildBankOpenState()
    end

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
    scanner.inventoryScanCanceled = false
    scanner.inventoryScanAuto = options.auto == true
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
    scanner.pendingLedgerScanAfterInventory = false
    scanner.pendingLedgerScanOptions = nil
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

    local shouldQueueLedgerScan = options.queueLedgerScan ~= false
        and (manualStart or options.forceLedgerScan == true or ledger_scan_allowed(db))
    if shouldQueueLedgerScan then
        scanner.pendingLedgerScanAfterInventory = true
        scanner.pendingLedgerScanOptions = {
            force = manualStart or options.forceLedgerScan == true,
        }
    end

    finish_auto_scan_setup()
    report_status(string.format("Guild bank scan started (%d tabs).", scanner.totalTabs))
    advance_scan()
    return scanner:GetStatusText()
end

local function list_equals(left, right)
    if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then
        return false
    end

    for index = 1, #left do
        if tostring(left[index] or "") ~= tostring(right[index] or "") then
            return false
        end
    end

    return true
end

function scanner.BeginLedgerScan(options)
    if type(scanner.SyncGuildBankOpenState) == "function" then
        scanner.SyncGuildBankOpenState()
    end

    local db = current_db()
    options = type(options) == "table" and options or {}
    if scanner.ledgerScanInProgress then
        return false
    end

    if scanner.scanInProgress then
        local existingOptions = scanner.pendingLedgerScanAfterInventory == true and scanner.pendingLedgerScanOptions or nil
        local hasExistingOptions = type(existingOptions) == "table"
        local queuedSilent = options.silent == true
        local queuedPassive = options.passive == true
        if hasExistingOptions then
            queuedSilent = existingOptions.silent == true and options.silent == true
            queuedPassive = existingOptions.passive == true and options.passive == true
        end
        scanner.pendingLedgerScanAfterInventory = true
        scanner.pendingLedgerScanOptions = {
            force = (hasExistingOptions and existingOptions.force == true) or options.force == true,
            silent = queuedSilent,
            passive = queuedPassive,
        }
        return true
    end

    if options.force ~= true and not ledger_scan_allowed(db) then
        return false
    end

    if options.force == true then
        local auth = ns.modules.auth or ns.modules.permissions
        if auth and type(auth.Can) == "function" and not auth.Can(current_context(db), "full_ui", db.auth) then
            return false
        end
    end

    local targets = {}
    local accessibleTabs = scanner.QueueAccessibleTabs() or {}
    if options.passive == true and #accessibleTabs == 0 then
        return false
    end

    for _, tabIndex in ipairs(accessibleTabs) do
        targets[#targets + 1] = {
            kind = "item",
            queryId = tabIndex,
            label = current_tab_name(tabIndex),
        }
    end
    local moneyLogQueryId = (tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1
    targets[#targets + 1] = {
        kind = "money",
        queryId = moneyLogQueryId,
        label = "Money Log",
    }

    scanner.ledgerTargets = targets
    scanner.ledgerScanInProgress = true
    scanner.ledgerScanToken = (tonumber(scanner.ledgerScanToken or 0) or 0) + 1
    scanner.ledgerScanStartedAt = type(_G.time) == "function" and (_G.time() or 0) or 0
    scanner.pendingLedgerAutoScan = false
    scanner.ledgerScanSilent = options.silent == true
    scanner.ledgerMergedItemRows = 0
    scanner.ledgerMergedMoneyRows = 0
    scanner.pendingLedgerSyncPayloads = {}
    clear_ledger_wait_state()
    if scanner.ledgerScanSilent ~= true then
        report_status("Guild bank ledger scan started.")
    end
    for _, target in ipairs(scanner.ledgerTargets or {}) do
        query_ledger_target(target)
    end
    schedule_ledger_scan_finalize(LEDGER_TARGET_TIMEOUT_SECONDS, {
        scanToken = scanner.ledgerScanToken,
        hardFallback = true,
        finalizeToken = scanner.ledgerFinalizeToken,
    })
    return true
end

function scanner.OnGuildBankOpened()
    local db = current_db()
    scanner.guildBankOpen = true
    local triggered = false
    if auto_scan_allowed(db) then
        scanner.pendingAutoScan = true
        scanner.autoScanRetryCount = 0
        scanner.pendingLedgerAutoScan = false
        scanner.BeginScan({ auto = true, manual = false, forceLedgerScan = true })
        triggered = true
    else
        scanner.pendingLedgerAutoScan = true
        triggered = scanner.BeginLedgerScan({
            force = true,
            passive = true,
        }) or triggered
    end

    schedule_passive_ledger_refresh()

    return triggered
end

function scanner.SyncGuildBankOpenState()
    if not is_guild_bank_open_now() then
        return false
    end

    scanner.guildBankOpen = true
    schedule_passive_ledger_refresh()
    return true
end

function scanner.OnGuildBankClosed()
    scanner.guildBankOpen = false
    scanner.pendingAutoScan = false
    scanner.pendingLedgerAutoScan = false
    scanner.pendingLedgerScanAfterInventory = false
    scanner.pendingLedgerScanOptions = nil
    scanner.passiveLedgerRefreshActive = false
    scanner.passiveLedgerRefreshToken = (tonumber(scanner.passiveLedgerRefreshToken or 0) or 0) + 1
    cancel_inventory_scan()
    cancel_ledger_scan(nil, {
        silent = true,
        schedulePassive = false,
    })
    return true
end

function scanner.RetryPendingAutoScan()
    if scanner.scanInProgress or not scanner.pendingAutoScan then
        return false
    end

    if not is_guild_bank_open_now() then
        scanner.pendingAutoScan = false
        return false
    end

    scanner.BeginScan({ auto = true, manual = false })
    return scanner.scanInProgress
end

local function transaction_item_id(itemLink)
    local itemID = tonumber(string.match(tostring(itemLink or ""), "item:(%d+)"))
    if itemID ~= nil then
        return itemID
    end
    return tonumber(itemLink)
end

current_tab_name = function(tabIndex)
    local tabName = "Tab " .. tostring(tabIndex or "?")
    if type(_G.GetGuildBankTabInfo) == "function" and tonumber(tabIndex) then
        tabName = (_G.GetGuildBankTabInfo(tabIndex)) or tabName
    end
    return tostring(tabName or ("Tab " .. tostring(tabIndex or "?")))
end

local function moved_from_tab(currentTabName, tabOne, tabTwo)
    tabOne = tonumber(tabOne) and current_tab_name(tabOne) or tostring(tabOne or "")
    tabTwo = tonumber(tabTwo) and current_tab_name(tabTwo) or tostring(tabTwo or "")
    currentTabName = tostring(currentTabName or "")
    if tabOne ~= "" and tabOne ~= currentTabName then
        return tabOne
    end
    if tabTwo ~= "" and tabTwo ~= currentTabName then
        return tabTwo
    end
    if tabOne ~= "" then
        return tabOne
    end
    if tabTwo ~= "" then
        return tabTwo
    end
    return "-"
end

local function split_timestamp(timestamp)
    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) ~= "function" then
        return {}
    end

    local ok, parts = pcall(formatter, "*t", tonumber(timestamp or 0) or 0)
    if not ok or type(parts) ~= "table" then
        return {}
    end

    return {
        year = parts.year,
        month = parts.month,
        day = parts.day,
        hour = parts.hour,
        minute = parts.min,
    }
end

local function item_row_type(action)
    action = trim(action):lower()
    if action == "deposit" then
        return "deposit"
    end
    if action == "moved" or action == "move" then
        return "move"
    end

    return "withdrawal"
end

local function money_row_type(action)
    action = trim(action):lower()
    if action == "deposit" then
        return "deposit"
    end
    if action == "repair" then
        return "repair"
    end

    return "withdrawal"
end

local function read_item_log_transactions(target)
    local transactions = {}
    if type(_G.GetNumGuildBankTransactions) ~= "function" or type(_G.GetGuildBankTransaction) ~= "function" then
        return transactions
    end

    local transactionCount = tonumber(_G.GetNumGuildBankTransactions(target.queryId) or 0) or 0

    for index = 1, transactionCount do
        local actionType, who, itemLink, count, tabOne, tabTwo, year, month, day, hour = _G.GetGuildBankTransaction(target.queryId, index)
        local itemID = transaction_item_id(itemLink)
        if itemID ~= nil then
            local itemName = tostring(itemID)
            if _G.C_Item and type(_G.C_Item.GetItemNameByID) == "function" then
                itemName = _G.C_Item.GetItemNameByID(itemID) or itemName
            end
            local craftedQuality, craftedQualityIcon = get_crafted_quality_info(itemLink)
            transactions[#transactions + 1] = {
                type = actionType,
                who = who,
                itemID = itemID,
                itemName = itemName,
                craftedQuality = craftedQuality,
                craftedQualityIcon = craftedQualityIcon,
                quantity = tonumber(count or 0) or 0,
                fromTabName = string.lower(tostring(actionType or "")) == "move" and moved_from_tab(target.label, tabOne, tabTwo) or nil,
                year = year,
                month = month,
                day = day,
                hour = hour,
            }
        end
    end

    return transactions
end

local function read_money_log_transactions()
    local transactions = {}
    if type(_G.GetNumGuildBankMoneyTransactions) ~= "function" or type(_G.GetGuildBankMoneyTransaction) ~= "function" then
        return transactions
    end

    local transactionCount = tonumber(_G.GetNumGuildBankMoneyTransactions() or 0) or 0
    for index = 1, transactionCount do
        local actionType, who, amount, year, month, day, hour = _G.GetGuildBankMoneyTransaction(index)
        transactions[#transactions + 1] = {
            type = actionType,
            who = who,
            amount = tonumber(amount or 0) or 0,
            year = year,
            month = month,
            day = day,
            hour = hour,
        }
    end

    return transactions
end

local function read_target_transactions(target)
    if not target then
        return {}
    end

    if target.kind == "money" then
        return read_money_log_transactions()
    end

    return read_item_log_transactions(target)
end

local function fingerprint_transactions(target, transactions)
    local out = {}
    for index, row in ipairs(transactions or {}) do
        if target and target.kind == "money" then
            out[index] = table.concat({
                tostring(row.type or ""),
                tostring(row.who or ""),
                tostring(row.amount or 0),
                tostring(row.year or ""),
                tostring(row.month or ""),
                tostring(row.day or ""),
                tostring(row.hour or ""),
            }, "|")
        else
            out[index] = table.concat({
                tostring(row.type or ""),
                tostring(row.who or ""),
                tostring(row.itemID or 0),
                tostring(row.quantity or 0),
                tostring(row.fromTabName or ""),
                tostring(row.year or ""),
                tostring(row.month or ""),
                tostring(row.day or ""),
                tostring(row.hour or ""),
            }, "|")
        end
    end
    return out
end

local function append_ledger_sync_payload(db, target, mergedRows)
    local transport = ns.modules.syncTransport or {}
    if not target or type(mergedRows) ~= "table" or #mergedRows == 0 or type(transport.Send) ~= "function" then
        return false
    end

    local payload = {
        guildKey = current_guild_key(db),
        actorContext = current_context(db),
        version = tostring(((ns.constants or {}).ADDON_VERSION) or ""),
        kind = target.kind,
        scanStartedAt = tonumber(scanner.ledgerScanStartedAt or 0) or 0,
        transactions = {},
    }

    if target.kind == "money" then
        payload.repairThresholdGold = tonumber((((bankLedger.GetSettings and bankLedger.GetSettings(db)) or {}).repairThresholdGold) or 5000) or 5000
        for _, row in ipairs(mergedRows) do
            local transaction = {
                type = money_row_type(row.action),
                who = row.who,
                amountCopper = row.amountCopper or row.amount,
            }
            for keyName, value in pairs(split_timestamp(row.timestamp or row.when)) do
                transaction[keyName] = value
            end
            payload.transactions[#payload.transactions + 1] = transaction
        end
    else
        payload.sourceTabIndex = target.queryId
        payload.sourceTabName = target.label
        for _, row in ipairs(mergedRows) do
            local transaction = {
                type = item_row_type(row.action),
                who = row.who,
                itemID = row.itemID,
                itemName = row.item,
                quantity = row.quantity,
                fromTabName = row.fromTabName ~= "-" and row.fromTabName or nil,
                craftedQuality = row.craftedQuality or row.qualityTier,
            }
            for keyName, value in pairs(split_timestamp(row.timestamp or row.when)) do
                transaction[keyName] = value
            end
            payload.transactions[#payload.transactions + 1] = transaction
        end
    end

    if #(payload.transactions or {}) == 0 then
        return false
    end

    if type(bankLedger.SanitizeRemoteDeltaPayload) == "function" then
        payload = bankLedger.SanitizeRemoteDeltaPayload(payload)
    end

    if #(payload.transactions or {}) == 0 then
        return false
    end

    scanner.pendingLedgerSyncPayloads = scanner.pendingLedgerSyncPayloads or {}
    scanner.pendingLedgerSyncPayloads[#scanner.pendingLedgerSyncPayloads + 1] = payload
    return true
end

local function publish_pending_ledger_sync_payloads(updatedAt)
    local transport = ns.modules.syncTransport or {}
    if type(transport.Send) ~= "function" then
        scanner.pendingLedgerSyncPayloads = {}
        return false
    end

    local published = false
    for _, payload in ipairs(scanner.pendingLedgerSyncPayloads or {}) do
        transport.Send("GUILD", "GUILD", {
            type = "LEDGER_DELTA",
            updatedAt = tonumber(updatedAt or 0) or 0,
            payload = payload,
        })
        published = true
    end

    scanner.pendingLedgerSyncPayloads = {}
    return published
end

local function merge_target_transactions(db, target, transactions)
    if not target or not bankLedger then
        return 0
    end

    if target.kind == "money" and type(bankLedger.MergeMoneyTransactions) == "function" then
        local ledger = type(bankLedger.EnsureState) == "function" and bankLedger.EnsureState(db) or nil
        local beforeCount = #(type(ledger) == "table" and ledger.moneyLogs or {})
        local merged = bankLedger.MergeMoneyTransactions(db, {
            scanStartedAt = scanner.ledgerScanStartedAt,
            transactions = transactions,
        })
        if (tonumber(merged or 0) or 0) > 0 and type(ledger) == "table" then
            local mergedRows = {}
            for index = beforeCount + 1, #(ledger.moneyLogs or {}) do
                mergedRows[#mergedRows + 1] = ledger.moneyLogs[index]
            end
            append_ledger_sync_payload(db, target, mergedRows)
        end
        scanner.ledgerMergedMoneyRows = (tonumber(scanner.ledgerMergedMoneyRows or 0) or 0) + (tonumber(merged or 0) or 0)
        return merged
    end

    if target.kind == "item" and type(bankLedger.MergeItemTransactions) == "function" then
        local ledger = type(bankLedger.EnsureState) == "function" and bankLedger.EnsureState(db) or nil
        local beforeCount = #(type(ledger) == "table" and ledger.itemLogs or {})
        local merged = bankLedger.MergeItemTransactions(db, {
            scanStartedAt = scanner.ledgerScanStartedAt,
            sourceTabIndex = target.queryId,
            sourceTabName = target.label,
            transactions = transactions,
            allowSuspiciousUnknownAppend = true,
        })
        if (tonumber(merged or 0) or 0) > 0 and type(ledger) == "table" then
            local mergedRows = {}
            for index = beforeCount + 1, #(ledger.itemLogs or {}) do
                mergedRows[#mergedRows + 1] = ledger.itemLogs[index]
            end
            append_ledger_sync_payload(db, target, mergedRows)
        end
        scanner.ledgerMergedItemRows = (tonumber(scanner.ledgerMergedItemRows or 0) or 0) + (tonumber(merged or 0) or 0)
        return merged
    end

    return 0
end

local function describe_target_delta(db, target, transactions)
    if not target or not bankLedger then
        return nil
    end

    if target.kind == "money" and type(bankLedger.DescribeMoneyDelta) == "function" then
        return bankLedger.DescribeMoneyDelta(db, {
            scanStartedAt = scanner.ledgerScanStartedAt,
            transactions = transactions,
        })
    end

    if target.kind == "item" and type(bankLedger.DescribeItemDelta) == "function" then
        return bankLedger.DescribeItemDelta(db, {
            scanStartedAt = scanner.ledgerScanStartedAt,
            sourceTabIndex = target.queryId,
            sourceTabName = target.label,
            transactions = transactions,
        })
    end

    return nil
end

capture_all_ledger_targets = function(db)
    for _, target in ipairs(scanner.ledgerTargets or {}) do
        merge_target_transactions(db, target, read_target_transactions(target))
    end
end

query_ledger_target = function(target)
    if not target then
        return
    end

    if type(_G.QueryGuildBankLog) == "function" then
        _G.QueryGuildBankLog(target.queryId)
    end
end

finish_ledger_scan = function(db)
    if not scanner.ledgerScanInProgress then
        return false
    end

    capture_all_ledger_targets(db)

    local mergedItemRows = tonumber(scanner.ledgerMergedItemRows or 0) or 0
    local mergedMoneyRows = tonumber(scanner.ledgerMergedMoneyRows or 0) or 0
    local publishedLedgerSyncAt = tonumber(scanner.ledgerScanStartedAt or 0) or 0
    scanner.ledgerScanInProgress = false
    scanner.ledgerTargets = {}
    scanner.ledgerScanStartedAt = 0
    local silentScan = scanner.ledgerScanSilent == true
    scanner.ledgerScanSilent = false
    scanner.ledgerMergedItemRows = 0
    scanner.ledgerMergedMoneyRows = 0
    clear_ledger_wait_state()
    if bankLedger and type(bankLedger.PruneRetention) == "function" then
        local now = type(_G.time) == "function" and (_G.time() or 0) or 0
        bankLedger.PruneRetention(db, now)
    end
    publish_pending_ledger_sync_payloads(publishedLedgerSyncAt)
    if silentScan then
        if mergedItemRows > 0 or mergedMoneyRows > 0 then
            report_status(string.format("Guild bank ledger auto-refresh found %d item rows and %d money rows.", mergedItemRows, mergedMoneyRows))
        end
    else
        report_status(string.format("Guild bank ledger scan finished (%d item rows, %d money rows).", mergedItemRows, mergedMoneyRows))
    end
    if mergedItemRows > 0 or mergedMoneyRows > 0 then
        refresh_ledger_view_if_visible()
    end
    schedule_passive_ledger_refresh()
    return true
end

cancel_ledger_scan = function(message, options)
    if not scanner.ledgerScanInProgress then
        return false
    end

    options = type(options) == "table" and options or {}
    local silent = options.silent == true or scanner.ledgerScanSilent == true
    scanner.ledgerScanInProgress = false
    scanner.ledgerTargets = {}
    scanner.ledgerScanToken = (tonumber(scanner.ledgerScanToken or 0) or 0) + 1
    scanner.ledgerScanStartedAt = 0
    scanner.ledgerScanSilent = false
    scanner.ledgerMergedItemRows = 0
    scanner.ledgerMergedMoneyRows = 0
    scanner.pendingLedgerSyncPayloads = {}
    clear_ledger_wait_state()

    if not silent and type(message) == "string" and message ~= "" then
        report_status(message)
    end

    if options.schedulePassive ~= false then
        schedule_passive_ledger_refresh()
    end

    return true
end

schedule_ledger_scan_finalize = function(delaySeconds, options)
    options = type(options) == "table" and options or {}
    local scanToken = tonumber(options.scanToken or scanner.ledgerScanToken or 0) or 0
    local hardFallback = options.hardFallback == true
    local quietPassesRemaining = tonumber(options.quietPassesRemaining or 1) or 1
    local finalizeToken = tonumber(options.finalizeToken or scanner.ledgerFinalizeToken or 0) or 0
    if not hardFallback then
        finalizeToken = (tonumber(scanner.ledgerFinalizeToken or 0) or 0) + 1
        scanner.ledgerFinalizeToken = finalizeToken
    end

    schedule_after(delaySeconds, function()
        if not scanner.ledgerScanInProgress or scanner.ledgerScanToken ~= scanToken then
            return
        end

        if scanner.ledgerFinalizeToken ~= finalizeToken then
            return
        end

        if hardFallback ~= true and quietPassesRemaining > 1 then
            schedule_ledger_scan_finalize(LEDGER_QUERY_SETTLE_DELAY_SECONDS, {
                scanToken = scanToken,
                quietPassesRemaining = quietPassesRemaining - 1,
            })
            return
        end

        finish_ledger_scan(current_db())
    end)
end

schedule_passive_ledger_refresh = function()
    if scanner.guildBankOpen ~= true then
        scanner.passiveLedgerRefreshActive = false
        return false
    end

    if scanner.passiveLedgerRefreshActive == true then
        return false
    end

    scanner.passiveLedgerRefreshActive = true
    scanner.passiveLedgerRefreshToken = (tonumber(scanner.passiveLedgerRefreshToken or 0) or 0) + 1
    local refreshToken = scanner.passiveLedgerRefreshToken

    schedule_after(PASSIVE_LEDGER_RESCAN_SECONDS, function()
        if scanner.passiveLedgerRefreshToken ~= refreshToken then
            return
        end

        scanner.passiveLedgerRefreshActive = false
        if scanner.guildBankOpen ~= true then
            return
        end

        local started = false
        if not scanner.scanInProgress and not scanner.ledgerScanInProgress then
            -- Passive refresh intentionally bypasses the usual stale-data throttle, but only
            -- through this single open-bank cadence gate so we can detect new live log rows
            -- without requiring a manual rescan while the bank remains open.
            started = scanner.BeginLedgerScan({
                force = true,
                silent = true,
                passive = true,
            })
        end

        if started ~= true then
            schedule_passive_ledger_refresh()
        end
    end)

    return true
end

function scanner.OnGuildBankTabsUpdated()
    if not scanner.scanInProgress and not is_guild_bank_open_now() then
        scanner.pendingAutoScan = false
        scanner.pendingLedgerAutoScan = false
        return false
    end

    local db = current_db()
    if (not scanner.scanInProgress or scanner.waitingForTab == nil) and scanner.pendingAutoScan then
        scanner.RetryPendingAutoScan()
    end

    if auto_scan_allowed(db) then
        scanner.pendingAutoScan = true
        scanner.autoScanRetryCount = 0
        scanner.RetryPendingAutoScan()
        return true
    end

    if scanner.pendingLedgerAutoScan and scanner.scanInProgress then
        return true
    end

    if scanner.pendingLedgerAutoScan then
        return scanner.BeginLedgerScan({
            force = true,
            passive = true,
        })
    end

    return false
end

refresh_ledger_view_if_visible = function()
    local mainFrame = ns.modules.mainFrame
    if type(mainFrame) ~= "table" then
        return false
    end

    if tostring(mainFrame.activeView or "") ~= "BANK_LEDGER" then
        return false
    end

    if type(mainFrame.RefreshBankLedgerTable) ~= "function" then
        return false
    end

    mainFrame:RefreshBankLedgerTable()
    return true
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

function scanner.ReadCurrentTab(tabIndex, scanSource)
    local tabName = "Tab " .. tostring(tabIndex)
    if type(_G.GetGuildBankTabInfo) == "function" then
        tabName = (_G.GetGuildBankTabInfo(tabIndex)) or tabName
    end

    local tabData = {
        index = tabIndex,
        name = tabName,
        scanSource = scanSource or "event",
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

function scanner.OnGuildBankSlotsChanged(tabIndex, scanSource)
    if not scanner.scanInProgress and not is_guild_bank_open_now() then
        scanner.pendingAutoScan = false
        return tabIndex
    end

    if not scanner.scanInProgress or scanner.waitingForTab == nil then
        if not scanner.scanInProgress and not scanner.pendingAutoScan then
            local db = current_db()
            if auto_scan_allowed(db) then
                scanner.pendingAutoScan = true
                scanner.autoScanRetryCount = 0
                scanner.RetryPendingAutoScan()
                return tabIndex
            end
        end
        if scanner.pendingAutoScan then
            scanner.RetryPendingAutoScan()
        end
        return tabIndex
    end

    if tonumber(tabIndex) ~= nil and tonumber(tabIndex) ~= tonumber(scanner.waitingForTab) then
        return tabIndex
    end

    local loadedTab = scanner.waitingForTab
    scanner.ReadCurrentTab(loadedTab, scanSource or "event")
    scanner.completedTabs = scanner.completedTabs + 1
    clear_wait_state()

    if finish_if_complete() then
        return loadedTab
    end

    push_status(string.format("Scanning %d/%d tabs", scanner.completedTabs, scanner.totalTabs))
    schedule_next_inventory_tab()
    return loadedTab
end

function scanner.OnGuildBankLogUpdated()
    if scanner.ledgerScanInProgress then
        schedule_ledger_scan_finalize(LEDGER_QUERY_SETTLE_DELAY_SECONDS, {
            quietPassesRemaining = LEDGER_QUERY_SETTLE_PASSES,
        })
        return true
    end

    if scanner.guildBankOpen ~= true then
        return true
    end

    if scanner.scanInProgress then
        scanner.pendingLedgerAutoScan = true
        return true
    end

    local started = scanner.BeginLedgerScan({
        force = true,
        silent = true,
        passive = true,
    })
    if not started then
        scanner.pendingLedgerAutoScan = true
        schedule_passive_ledger_refresh()
    end

    return true
end

local function snapshot_has_items_in_tab(snapshot, tabName)
    snapshot = type(snapshot) == "table" and snapshot or {}
    tabName = tostring(tabName or "")
    if tabName == "" then
        return false
    end

    for _, row in ipairs(snapshot.itemRows or {}) do
        if tostring(row.tabName or "") == tabName and (tonumber(row.quantity or 0) or 0) > 0 then
            return true
        end
    end

    for _, item in pairs(snapshot.items or {}) do
        local tabQuantity = tonumber(((item or {}).tabs or {})[tabName] or 0) or 0
        if tabQuantity > 0 then
            return true
        end
    end

    return false
end

local function is_suspicious_partial_auto_snapshot(baseline, currentSnapshot, rawTabs)
    if scanner.inventoryScanAuto ~= true or type(baseline) ~= "table" then
        return false
    end

    if type(currentSnapshot) ~= "table" then
        return false
    end

    for _, tab in ipairs(rawTabs or {}) do
        local slots = type(tab.slots) == "table" and tab.slots or {}
        local tabName = tostring(tab.name or tab.index or "")
        if #slots == 0 and snapshot_has_items_in_tab(baseline, tabName) then
            return true
        end
    end

    return false
end

function scanner.FinishScan(actor, guildName, previousSnapshot)
    if scanner.inventoryScanCanceled == true then
        scanner.inventoryScanCanceled = false
        scanner.inventoryScanAuto = false
        return nil, {}
    end

    local db = current_db()
    local baseline = previousSnapshot
    local scannedAtUtc = _G.time()

    db.meta = db.meta or {}
    local previousScanSequence = tonumber(db.meta.lastScanSequence or 0) or 0

    if baseline == nil and db.currentSnapshotId ~= nil then
        baseline = db.snapshots[db.currentSnapshotId]
    end

    local scanId = next_scan_id(db, scannedAtUtc)
    local currentSnapshot = snapshots.FromTabScan({
        scanId = scanId,
        actor = actor,
        guildName = guildName,
        scannedTabs = scanner.rawTabs,
        scannedAt = scannedAtUtc,
    })
    if is_suspicious_partial_auto_snapshot(baseline, currentSnapshot, scanner.rawTabs) then
        local shouldBeginLedgerScan = scanner.pendingLedgerScanAfterInventory == true
        local pendingLedgerScanOptions = scanner.pendingLedgerScanOptions

        db.meta.lastScanSequence = previousScanSequence
        scanner.scanInProgress = false
        scanner.inventoryScanCanceled = false
        scanner.inventoryScanAuto = false
        clear_wait_state()
        scanner.tabsToScan = {}
        scanner.rawTabs = {}
        scanner.totalTabs = 0
        scanner.completedTabs = 0
        scanner.pendingLedgerScanAfterInventory = false
        scanner.pendingLedgerScanOptions = nil
        finish_auto_scan_setup()
        report_status("Guild bank auto-scan ignored a partial snapshot; run Scan Bank to refresh.")
        if shouldBeginLedgerScan then
            scanner.BeginLedgerScan(pendingLedgerScanOptions)
        end
        return nil, {}
    end

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
    scanner.inventoryScanCanceled = false
    scanner.inventoryScanAuto = false
    clear_wait_state()
    scanner.tabsToScan = {}
    finish_auto_scan_setup()

    local shouldBeginLedgerScan = scanner.pendingLedgerScanAfterInventory == true
    local pendingLedgerScanOptions = scanner.pendingLedgerScanOptions
    scanner.pendingLedgerScanAfterInventory = false
    scanner.pendingLedgerScanOptions = nil
    if shouldBeginLedgerScan then
        scanner.BeginLedgerScan(pendingLedgerScanOptions)
    end

    return currentSnapshot, changes
end

ns.modules.scanner = scanner
ns.modules.guildBankScanner = scanner

return scanner
