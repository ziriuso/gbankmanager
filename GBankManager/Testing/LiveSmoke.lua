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

local function deep_copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local clone = {}
    seen[value] = clone
    for key, nestedValue in pairs(value) do
        clone[deep_copy(key, seen)] = deep_copy(nestedValue, seen)
    end

    return clone
end

local function deterministic_request_access_auth()
    local permissions = ns.modules.permissions or {}
    local auth = type(permissions.CreateDefaultPolicy) == "function" and permissions.CreateDefaultPolicy() or {
        capabilities = {},
        blacklist = {},
        blacklistHashes = {},
    }

    auth.capabilities = auth.capabilities or {}
    auth.capabilities.full_ui = auth.capabilities.full_ui or {}
    auth.capabilities.request_submit = {}
    auth.blacklist = auth.blacklist or {}
    auth.blacklistHashes = auth.blacklistHashes or {}
    return auth
end

local function with_temporary_auth(db, auth, callback)
    local original = deep_copy((db or {}).auth)
    db.auth = deep_copy(auth)

    local ok, value = pcall(callback)
    db.auth = original
    if not ok then
        error(value)
    end

    return value
end

local function reset_request_editor_state(mainFrame)
    if not mainFrame then
        return
    end

    mainFrame.requestOnlyMode = false
    mainFrame.selectedRequestId = nil
    mainFrame.requestCreateSelectedCatalogItem = nil
    mainFrame.requestCreateUserMessage = nil
    mainFrame.requestSearchSession = nil

    if mainFrame.requestDetailsModal then
        mainFrame.requestDetailsModal:Hide()
    end
    if mainFrame.requestWizardModal then
        mainFrame.requestWizardModal:Hide()
    end

    if mainFrame.requestCreateSearchSelector then
        mainFrame.requestCreateSearchSelector.pendingProgrammaticInputs = {}
        mainFrame.requestCreateSearchSelector.selectedItem = nil
        mainFrame.requestCreateSearchSelector.isResolving = true
        mainFrame.requestCreateItemIDInput:SetText("")
        mainFrame.requestCreateItemNameInput:SetText("")
        mainFrame.requestCreateSearchSelector.isResolving = false
        mainFrame.requestCreateSearchSelector:ClearSelection()
    else
        if mainFrame.requestCreateItemIDInput then
            mainFrame.requestCreateItemIDInput:SetText("")
        end
        if mainFrame.requestCreateItemNameInput then
            mainFrame.requestCreateItemNameInput:SetText("")
        end
    end

    if mainFrame.requestCreateQuantityInput then
        mainFrame.requestCreateQuantityInput:SetText("")
    end
    if mainFrame.requestCreateNoteInput then
        mainFrame.requestCreateNoteInput:SetText("")
    end
    if mainFrame.requestActionNoteInput then
        mainFrame.requestActionNoteInput:SetText("")
    end
    if mainFrame.requestDetailsActionNoteInput then
        mainFrame.requestDetailsActionNoteInput:SetText("")
    end

    if type(mainFrame.RefreshRequestEditorState) == "function" then
        mainFrame:RefreshRequestEditorState()
    end
end

local function reset_minimum_editor_state(mainFrame)
    if not mainFrame then
        return
    end

    mainFrame.requestOnlyMode = false
    mainFrame.minimumPendingRules = {}
    mainFrame.minimumPendingDirty = {}
    mainFrame.minimumPendingDeleted = {}
    mainFrame.selectedMinimumKey = nil
    mainFrame.minimumDetailsSourceRow = nil
    mainFrame.minimumDetailsWorkingState = nil
    mainFrame.minimumSearchSession = nil

    if mainFrame.minimumDetailsModal then
        mainFrame.minimumDetailsModal:Hide()
    end

    if type(mainFrame.ResetMinimumAddRow) == "function" then
        if mainFrame.minimumAddSearchSelector then
            mainFrame.minimumAddSearchSelector.pendingProgrammaticInputs = {}
            mainFrame.minimumAddSearchSelector.selectedItem = nil
        end
        mainFrame:ResetMinimumAddRow()
    elseif mainFrame.minimumAddSearchSelector then
        mainFrame.minimumAddSearchSelector.pendingProgrammaticInputs = {}
        mainFrame.minimumAddSearchSelector.selectedItem = nil
        mainFrame.minimumAddSearchSelector:ClearSelection()
    end
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
    if not mainFrame or type(mainFrame.SelectView) ~= "function" then
        return smoke_result("opacity_controls", false, "main frame appearance controls were unavailable")
    end

    mainFrame:ShowDashboard()
    mainFrame:SelectView("OPTIONS")

    local shellDecrease = mainFrame.optionsShellOpacityDecreaseButton and mainFrame.optionsShellOpacityDecreaseButton:GetScript("OnClick") or nil
    local shellIncrease = mainFrame.optionsShellOpacityIncreaseButton and mainFrame.optionsShellOpacityIncreaseButton:GetScript("OnClick") or nil
    local modalDecrease = mainFrame.optionsModalOpacityDecreaseButton and mainFrame.optionsModalOpacityDecreaseButton:GetScript("OnClick") or nil
    local modalIncrease = mainFrame.optionsModalOpacityIncreaseButton and mainFrame.optionsModalOpacityIncreaseButton:GetScript("OnClick") or nil
    if type(shellDecrease) ~= "function"
        or type(shellIncrease) ~= "function"
        or type(modalDecrease) ~= "function"
        or type(modalIncrease) ~= "function" then
        return smoke_result("opacity_controls", false, "shell or modal opacity controls were not fully wired")
    end

    local function surface_alpha(frame)
        frame = frame or {}
        local backdropAlpha = (((frame.backdropColor or {})[4]) or nil)
        if backdropAlpha ~= nil and backdropAlpha > 0 then
            return backdropAlpha
        end

        local art = frame.gbmArt or {}
        local innerFillAlpha = (((art.innerFill or {}).color or {})[4]) or nil
        if innerFillAlpha ~= nil then
            return innerFillAlpha
        end

        local backgroundAlpha = (((art.background or {}).color or {})[4]) or nil
        if backgroundAlpha ~= nil then
            return backgroundAlpha
        end

        return 1
    end

    local baselineShellAlpha = surface_alpha(mainFrame.content)
    local baselineModalAlpha = mainFrame.requestDetailsModal and surface_alpha(mainFrame.requestDetailsModal) or 1

    shellDecrease(mainFrame.optionsShellOpacityDecreaseButton)
    local loweredShellAlpha = surface_alpha(mainFrame.content)
    shellIncrease(mainFrame.optionsShellOpacityIncreaseButton)
    local restoredShellAlpha = surface_alpha(mainFrame.content)

    modalDecrease(mainFrame.optionsModalOpacityDecreaseButton)
    local loweredModalAlpha = mainFrame.requestDetailsModal and surface_alpha(mainFrame.requestDetailsModal) or 1
    modalIncrease(mainFrame.optionsModalOpacityIncreaseButton)
    local restoredModalAlpha = mainFrame.requestDetailsModal and surface_alpha(mainFrame.requestDetailsModal) or 1

    if loweredShellAlpha >= baselineShellAlpha then
        return smoke_result("opacity_controls", false, "shell opacity decrement did not lower shell alpha")
    end

    if restoredShellAlpha < loweredShellAlpha then
        return smoke_result("opacity_controls", false, "shell opacity increment did not raise shell alpha")
    end

    if loweredModalAlpha >= baselineModalAlpha then
        return smoke_result("opacity_controls", false, "modal opacity decrement did not lower modal alpha")
    end

    if restoredModalAlpha < loweredModalAlpha then
        return smoke_result("opacity_controls", false, "modal opacity increment did not raise modal alpha")
    end

    return smoke_result("opacity_controls", true, "shell and modal opacity controls changed backdrop alpha in both directions")
end

local function run_request_access_modes(mainFrame)
    local slash = ns.modules.slash or {}
    if type(slash.command) ~= "function" then
        return smoke_result("request_access_modes", false, "slash command missing for access smoke")
    end

    local db = current_db()
    return with_temporary_auth(db, deterministic_request_access_auth(), function()
        reset_request_editor_state(mainFrame)

        local fullShellCheck = with_guild_rank("Guild Master", 0, function()
            slash.command("ui")
            return mainFrame.activeView == "DASHBOARD" and mainFrame.requestOnlyMode ~= true and mainFrame:IsShown()
        end)

        if not fullShellCheck then
            return smoke_result("request_access_modes", false, "guildmaster access did not open the full shell")
        end

        reset_request_editor_state(mainFrame)
        local requestOnlyCheck = with_guild_rank("Raider", 2, function()
            slash.command("ui")
            return mainFrame.activeView == "REQUESTS"
                and mainFrame.requestOnlyMode == true
                and mainFrame:IsShown()
                and mainFrame.requestWorkflowCreateButton
                and mainFrame.requestWorkflowCreateButton.enabled ~= false
        end)

        if not requestOnlyCheck then
            return smoke_result("request_access_modes", false, "member access did not fall back to request-only mode with the lightweight create affordance")
        end

        return smoke_result("request_access_modes", true, "slash ui respected both full-shell access and lightweight request-only access")
    end)
end

local function seed_request_sync_smoke_db(db)
    db.requests = {}
    db.auth = db.auth or {}
    db.auth.capabilities = db.auth.capabilities or {}
    db.auth.blacklist = db.auth.blacklist or {}
    db.auth.blacklistHashes = db.auth.blacklistHashes or {}
    db.auth.capabilities.request_submit = {}
    db.auth.capabilities.request_approve = { [0] = true, [1] = true }
    db.auth.capabilities.request_reject = { [0] = true, [1] = true }
    db.auth.capabilities.request_edit = { [0] = true, [1] = true }
    db.auth.capabilities.request_fulfill = { [0] = true, [1] = true }
    db.auth.capabilities.request_reopen = { [0] = true, [1] = true }
    db.auth.capabilities.full_ui = { [0] = true, [1] = true }
    db.auth.capabilities.minimum_add = { [0] = true, [1] = true }
    db.auth.capabilities.minimum_edit = { [0] = true, [1] = true }
    db.auth.capabilities.minimum_delete = { [0] = true, [1] = true }
    db.auth.capabilities.auth_manage = { [0] = true, [1] = true }
end

local function run_request_sync_contract(db)
    local syncEvents = ns.modules.syncEvents or {}
    local codec = ns.modules.syncCodec or {}
    if type(syncEvents.HandleEvent) ~= "function" or type(codec.EncodeTable) ~= "function" then
        return smoke_result("request_sync_contract", false, "sync events or codec module missing")
    end

    seed_request_sync_smoke_db(db)

    local createPayload = codec.EncodeTable({
        type = "REQUEST_CREATED",
        updatedAt = 301,
        payload = {
            guildKey = tostring((((db or {}).meta or {}).guildName) or "Guild Testers"),
            actorContext = {
                characterKey = "MemberOne-Stormrage",
                guildRankIndex = 2,
                guildRankName = "Raider",
                inGuild = true,
                isGuildMaster = false,
                name = "MemberOne",
            },
            request = {
                requestId = "req-live-sync-1",
                requester = "MemberOne",
                requesterCharacterKey = "MemberOne-Stormrage",
                itemID = 4004,
                itemName = "Sync Smoke Flask",
                quantity = 2,
                approval = "PENDING",
                fulfillment = "OPEN",
                createdAt = 301,
                createdBy = "MemberOne-Stormrage",
                updatedAt = 301,
            },
        },
    })

    local created = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", createPayload, "GUILD", "MemberOne")
    if created ~= true or type(db.requests) ~= "table" or #db.requests ~= 1 then
        return smoke_result("request_sync_contract", false, "valid request-created sync payload did not apply cleanly")
    end

    local forgedUpdatePayload = codec.EncodeTable({
        type = "REQUEST_UPDATED",
        updatedAt = 302,
        payload = {
            action = "APPROVE",
            guildKey = tostring((((db or {}).meta or {}).guildName) or "Guild Testers"),
            actorContext = {
                characterKey = "OfficerOne-Stormrage",
                guildRankIndex = 1,
                guildRankName = "Officer",
                inGuild = true,
                isGuildMaster = false,
                name = "OfficerOne",
            },
            request = {
                requestId = "req-live-sync-1",
                requester = "DifferentRequester",
                requesterCharacterKey = "DifferentRequester-Stormrage",
                itemID = 9999,
                itemName = "Forged Sync Smoke",
                quantity = 2,
                approval = "APPROVED",
                fulfillment = "OPEN",
                createdAt = 301,
                createdBy = "MemberOne-Stormrage",
                updatedAt = 302,
            },
        },
    })

    local forgedAccepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", forgedUpdatePayload, "GUILD", "OfficerOne")
    if forgedAccepted then
        return smoke_result("request_sync_contract", false, "forged request update payload unexpectedly applied")
    end

    local request = db.requests[1]
    if request.requester ~= "MemberOne" or request.requesterCharacterKey ~= "MemberOne-Stormrage" or request.itemID ~= 4004 then
        return smoke_result("request_sync_contract", false, "forged request update mutated immutable request identity fields")
    end

    return smoke_result("request_sync_contract", true, "request sync accepted valid creates and rejected forged immutable-field updates")
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
    reset_minimum_editor_state(mainFrame)
    mainFrame:SelectView("MINIMUMS")
    mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
    mainFrame.minimumAddItemIDInput:SetText("7007")
    local resolveByItemID = mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")
    if type(resolveByItemID) == "function" then
        resolveByItemID(mainFrame.minimumAddItemIDInput)
    end
    if mainFrame:GetConfirmedMinimumAddItem() == nil then
        return smoke_result("minimums_render", false, "minimum add flow did not promote the resolved item into confirmed selection state")
    end

    mainFrame.minimumAddSearchSelector:ClearSelection()
    if mainFrame:BeginMinimumDraftFromSelectedItem() ~= nil then
        return smoke_result("minimums_render", false, "minimum add flow accepted raw text without a confirmed selected item")
    end
    if mainFrame.minimumPendingRules and next(mainFrame.minimumPendingRules) ~= nil then
        return smoke_result("minimums_render", false, "minimum add flow staged a draft before a confirmed selection existed")
    end

    if type(resolveByItemID) == "function" then
        resolveByItemID(mainFrame.minimumAddItemIDInput)
    end
    local modal = mainFrame:BeginMinimumDraftFromSelectedItem()
    if type(modal) ~= "table" or not modal:IsShown() then
        return smoke_result("minimums_render", false, "minimum add flow did not open the details modal for a confirmed item")
    end

    mainFrame.minimumDetailsWorkingState = mainFrame.minimumDetailsWorkingState or {}
    mainFrame.minimumDetailsWorkingState.tabName = "Alchemy"
    if mainFrame.minimumDetailsQuantityInput then
        mainFrame.minimumDetailsQuantityInput:SetText("250")
        local onQuantityChanged = mainFrame.minimumDetailsQuantityInput:GetScript("OnTextChanged")
        if type(onQuantityChanged) == "function" then
            onQuantityChanged(mainFrame.minimumDetailsQuantityInput)
        end
    end

    local rule = mainFrame:ConfirmMinimumDetailsModal()
    if type(rule) ~= "table" then
        return smoke_result("minimums_render", false, "minimum add flow did not stage a draft rule")
    end

    local pending = mainFrame.minimumPendingRules and mainFrame.minimumPendingRules[rule.draftKey] or nil
    if type(pending) ~= "table" then
        return smoke_result("minimums_render", false, "minimum draft was not tracked after staging")
    end

    local changed = mainFrame:SaveAllMinimumChanges()
    if changed ~= true then
        return smoke_result("minimums_render", false, "minimum save did not commit the staged draft")
    end

    if type(db.minimums) ~= "table" or #(db.minimums) < 1 then
        return smoke_result("minimums_render", false, "minimum save did not persist any rules")
    end

    return smoke_result("minimums_render", true, "minimums view staged and saved a draft rule")
end

local function run_request_selection_gating(mainFrame, db)
    return with_guild_rank("Guild Master", 0, function()
        seed_request_sync_smoke_db(db)
        return with_temporary_auth(db, db.auth, function()
            reset_request_editor_state(mainFrame)
            mainFrame:SelectView("REQUESTS")
            if type(mainFrame.RefreshRequestEditorState) == "function" then
                mainFrame:RefreshRequestEditorState()
            end
            if mainFrame.requestCreateButton and mainFrame.requestCreateButton.enabled ~= false then
                return smoke_result("request_selection_gating", false, "request create button started enabled before any confirmed item selection existed")
            end

            mainFrame.requestCreateItemIDInput:SetText("7007")
            mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
            if mainFrame:GetConfirmedRequestCreateItem() == nil then
                return smoke_result("request_selection_gating", false, "request create did not promote an exact item-id match into confirmed selection state")
            end
            if mainFrame.requestCreateButton and mainFrame.requestCreateButton.enabled == false then
                return smoke_result("request_selection_gating", false, "request create button did not enable after confirmed selection was established")
            end

            mainFrame.requestCreateSearchSelector:ClearSelection()
            if mainFrame.requestCreateButton and mainFrame.requestCreateButton.enabled ~= false then
                return smoke_result("request_selection_gating", false, "request create button did not disable after confirmed selection was cleared")
            end
            mainFrame.requestCreateQuantityInput:SetText("3")
            mainFrame.requestCreateNoteInput:SetText("Smoke gating check")
            local rawTextAttempt = mainFrame:CreateRequestFromEditor()
            if rawTextAttempt ~= nil then
                return smoke_result("request_selection_gating", false, "request create accepted raw text fields without a confirmed selected item")
            end

            if type(mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")) == "function" then
                mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
            end
            if mainFrame:GetConfirmedRequestCreateItem() == nil then
                return smoke_result("request_selection_gating", false, "request create did not restore confirmed selection after re-resolving the exact item id")
            end
            if mainFrame.requestCreateStatusText and mainFrame.requestCreateStatusText:GetText() == "Select an item from the catalog first." then
                return smoke_result("request_selection_gating", false, "request create left a stale selection error visible after a valid catalog item was reselected")
            end
            if mainFrame.requestCreateButton and mainFrame.requestCreateButton.enabled == false then
                return smoke_result("request_selection_gating", false, "request create button did not re-enable after confirmed selection was restored")
            end

            local request = mainFrame:CreateRequestFromEditor()
            if type(request) ~= "table" then
                return smoke_result("request_selection_gating", false, "request create did not succeed after confirmed selection was established")
            end

            return smoke_result("request_selection_gating", true, "request create required confirmed selection before submission and still succeeded after exact resolution")
        end)
    end)
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
        run_request_sync_contract(db),
        run_minimums_render(mainFrame, db),
        run_request_selection_gating(mainFrame, db),
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
