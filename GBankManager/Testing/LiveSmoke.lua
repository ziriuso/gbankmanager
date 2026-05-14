local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}
ns.data = ns.data or {}

local liveSmoke = ns.modules.liveSmoke or {}

local function current_db()
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    local runtime = _G.GBankManagerDB or ns.state.db or {}
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function current_time()
    local provider = _G.time or os.time
    if type(provider) == "function" then
        return provider()
    end

    return 0
end

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(message)
        return
    end

    if type(_G.print) == "function" then
        _G.print(message)
    end
end

local function smoke_result(id, ok, detail)
    return {
        id = id,
        passed = ok == true,
        detail = detail or "",
    }
end

local function persist_result(db, result)
    db.testing = db.testing or {}
    db.testing.liveSmoke = db.testing.liveSmoke or {}
    db.testing.liveSmoke.runAt = result.runAt or 0
    db.testing.liveSmoke.status = result.status or "FAIL"
    db.testing.liveSmoke.summary = result.summary or ""
    db.testing.liveSmoke.results = result.results or {}
    return db.testing.liveSmoke
end

local function with_guild_rank(name, zeroBasedIndex, callback)
    local originalGetGuildInfo = _G.GetGuildInfo
    _G.GetGuildInfo = function()
        return "Guild Testers", name, zeroBasedIndex
    end

    local ok, value = pcall(callback)
    _G.GetGuildInfo = originalGetGuildInfo
    if not ok then
        error(value)
    end

    return value
end

local function run_shell_open_close(mainFrame)
    local slash = ns.modules.slash or {}
    local closeScript = mainFrame and mainFrame.closeButton and mainFrame.closeButton:GetScript("OnClick") or nil
    if type(slash.command) ~= "function" or type(closeScript) ~= "function" then
        return smoke_result("shell_open_close", false, "missing slash command or close button handler")
    end

    slash.command("ui")
    if not mainFrame:IsShown() then
        return smoke_result("shell_open_close", false, "slash ui did not show the shell")
    end

    closeScript(mainFrame.closeButton)
    if mainFrame:IsShown() then
        return smoke_result("shell_open_close", false, "close button did not hide the shell")
    end

    return smoke_result("shell_open_close", true, "shell opened through slash and closed through the shell button")
end

local function run_options_render_scroll(mainFrame)
    if not mainFrame or type(mainFrame.SelectView) ~= "function" then
        return smoke_result("options_render_scroll", false, "missing main frame options view")
    end

    mainFrame:ShowDashboard()
    mainFrame:SelectView("OPTIONS")
    mainFrame:UpdateOptionsCanvasHeight()
    local beforeOffset = mainFrame.optionsScrollFrame and (mainFrame.optionsScrollFrame.verticalScroll or 0) or 0
    mainFrame:SetOptionsScrollProgress(1)
    local afterOffset = mainFrame.optionsScrollFrame and (mainFrame.optionsScrollFrame.verticalScroll or 0) or 0
    local range = mainFrame.optionsScrollFrame and (mainFrame.optionsScrollFrame.verticalScrollRange or 0) or 0

    if not (mainFrame.optionsViewportFrame and mainFrame.optionsViewportFrame:IsShown()) then
        return smoke_result("options_render_scroll", false, "options viewport did not render")
    end

    if type(mainFrame.optionsScrollController) ~= "table" then
        return smoke_result("options_render_scroll", false, "options scroll controller missing")
    end

    if range <= 0 then
        return smoke_result("options_render_scroll", false, "options view did not report overflow range")
    end

    if afterOffset <= beforeOffset then
        return smoke_result("options_render_scroll", false, "options scroll offset did not advance")
    end

    if not (mainFrame.optionsScrollBar and mainFrame.optionsScrollBar:IsShown()) then
        return smoke_result("options_render_scroll", false, "options scrollbar was not visible during overflow")
    end

    return smoke_result("options_render_scroll", true, "options view rendered and advanced its shared scrollbar")
end

local function run_opacity_controls(mainFrame)
    local decrease = mainFrame and mainFrame.transparencyDecreaseButton and mainFrame.transparencyDecreaseButton:GetScript("OnClick") or nil
    local increase = mainFrame and mainFrame.transparencyIncreaseButton and mainFrame.transparencyIncreaseButton:GetScript("OnClick") or nil
    if type(decrease) ~= "function" or type(increase) ~= "function" then
        return smoke_result("opacity_controls", false, "opacity controls were not fully wired")
    end

    local baseline = mainFrame.currentAlpha or mainFrame:GetAlpha() or 1
    decrease(mainFrame.transparencyDecreaseButton)
    local lowered = mainFrame.currentAlpha or mainFrame:GetAlpha() or 1
    increase(mainFrame.transparencyIncreaseButton)
    local restored = mainFrame.currentAlpha or mainFrame:GetAlpha() or 1

    if lowered >= baseline then
        return smoke_result("opacity_controls", false, "opacity decrement did not lower shell alpha")
    end

    if restored < lowered then
        return smoke_result("opacity_controls", false, "opacity increment did not raise shell alpha")
    end

    return smoke_result("opacity_controls", true, "opacity controls changed shell alpha in both directions")
end

local function run_request_access_modes(mainFrame)
    local slash = ns.modules.slash or {}
    if type(slash.command) ~= "function" then
        return smoke_result("request_access_modes", false, "slash command missing for access smoke")
    end

    local fullShellCheck = with_guild_rank("Guild Master", 0, function()
        slash.command("ui")
        return mainFrame.activeView == "DASHBOARD" and mainFrame.requestOnlyMode ~= true and mainFrame:IsShown()
    end)

    if not fullShellCheck then
        return smoke_result("request_access_modes", false, "guildmaster access did not open the full shell")
    end

    local requestOnlyCheck = with_guild_rank("Raider", 2, function()
        slash.command("ui")
        return mainFrame.activeView == "REQUESTS" and mainFrame.requestOnlyMode == true and mainFrame:IsShown()
    end)

    if not requestOnlyCheck then
        return smoke_result("request_access_modes", false, "member access did not fall back to request-only mode")
    end

    return smoke_result("request_access_modes", true, "slash ui respected both full-shell and request-only access modes")
end

local function seed_minimums_smoke_db(db)
    db.currentSnapshotId = "smoke-snapshot"
    db.snapshots = db.snapshots or {}
    db.snapshots["smoke-snapshot"] = {
        items = {
            [7007] = {
                itemID = 7007,
                name = "Algari Mana Oil",
                totalCount = 4,
                tabs = {
                    Alchemy = 4,
                },
            },
        },
    }
    db.minimums = db.minimums or {}
    db.auditLog = db.auditLog or {}
    db.ui = db.ui or {}
    db.ui.minimumSettings = db.ui.minimumSettings or {}
    db.ui.minimumSettings.defaultQuantity = 250
end

local function run_minimums_render(mainFrame, db)
    seed_minimums_smoke_db(db)
    mainFrame:SelectView("MINIMUMS")
    mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
    mainFrame.minimumAddItemIDInput:SetText("7007")
    mainFrame.minimumAddItemNameInput:SetText("Algari Mana Oil")
    mainFrame.minimumAddQuantityInput:SetText("250")
    local rule = mainFrame:CreateMinimumFromAddRow()
    if type(rule) ~= "table" then
        return smoke_result("minimums_render", false, "minimum add flow did not stage a draft rule")
    end

    local pending = mainFrame.minimumPendingRules and mainFrame.minimumPendingRules[rule.draftKey] or nil
    if type(pending) ~= "table" then
        return smoke_result("minimums_render", false, "minimum draft was not tracked after staging")
    end

    pending.tabName = "Alchemy"
    local changed = mainFrame:SaveAllMinimumChanges()
    if changed ~= true then
        return smoke_result("minimums_render", false, "minimum save did not commit the staged draft")
    end

    if type(db.minimums) ~= "table" or #(db.minimums) < 1 then
        return smoke_result("minimums_render", false, "minimum save did not persist any rules")
    end

    return smoke_result("minimums_render", true, "minimums view staged and saved a draft rule")
end

local function run_scan_access_gating(db)
    local scanner = ns.modules.scanner or {}
    if type(scanner.BeginScan) ~= "function" then
        return smoke_result("scan_access_gating", false, "scanner module missing")
    end

    local originalGetNumGuildBankTabs = _G.GetNumGuildBankTabs
    local originalGetGuildBankTabInfo = _G.GetGuildBankTabInfo
    local originalQueryGuildBankTab = _G.QueryGuildBankTab
    _G.GetNumGuildBankTabs = function()
        return 0
    end
    _G.GetGuildBankTabInfo = function()
        return nil, nil, false
    end
    _G.QueryGuildBankTab = nil

    local denied = with_guild_rank("Raider", 2, function()
        return scanner.BeginScan()
    end)
    if denied ~= "Permission denied" then
        _G.GetNumGuildBankTabs = originalGetNumGuildBankTabs
        _G.GetGuildBankTabInfo = originalGetGuildBankTabInfo
        _G.QueryGuildBankTab = originalQueryGuildBankTab
        return smoke_result("scan_access_gating", false, "member scan attempt did not report permission denied")
    end

    local officer = with_guild_rank("Guild Master", 0, function()
        return scanner.BeginScan()
    end)
    if officer ~= "Open guild bank to scan" then
        _G.GetNumGuildBankTabs = originalGetNumGuildBankTabs
        _G.GetGuildBankTabInfo = originalGetGuildBankTabInfo
        _G.QueryGuildBankTab = originalQueryGuildBankTab
        return smoke_result("scan_access_gating", false, "officer scan attempt did not reach the guild-bank gate")
    end

    _G.GetNumGuildBankTabs = originalGetNumGuildBankTabs
    _G.GetGuildBankTabInfo = originalGetGuildBankTabInfo
    _G.QueryGuildBankTab = originalQueryGuildBankTab

    return smoke_result("scan_access_gating", true, "scan flow differentiated member denial from officer bank-access gating")
end

function liveSmoke.Run()
    local db = current_db()
    local mainFrame = ns.modules.mainFrame
    local results = {
        run_shell_open_close(mainFrame),
        run_options_render_scroll(mainFrame),
        run_opacity_controls(mainFrame),
        run_request_access_modes(mainFrame),
        run_minimums_render(mainFrame, db),
        run_scan_access_gating(db),
    }

    local passed = true
    for _, result in ipairs(results) do
        if result.passed ~= true then
            passed = false
            break
        end
    end

    local status = passed and "PASS" or "FAIL"
    local summary = string.format("%s /gbm test smoke (%d checks)", status, #results)
    local persisted = {
        runAt = current_time(),
        status = status,
        summary = summary,
        results = results,
    }

    persist_result(db, persisted)
    push_chat_line(summary)
    for _, result in ipairs(results) do
        push_chat_line(string.format("%s %s: %s", result.passed and "PASS" or "FAIL", result.id, result.detail))
    end

    return summary, persisted
end

ns.modules.liveSmoke = liveSmoke

return liveSmoke
