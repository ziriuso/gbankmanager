local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.modules.slash = ns.modules.slash or {}

local slash = ns.modules.slash

local function trim(value)
    if type(_G.strtrim) == "function" then
        return _G.strtrim(value)
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_command(rawMessage)
    local trimmed = trim(rawMessage or "")
    if trimmed == "" then
        return "", ""
    end

    local command, rest = string.match(trimmed, "^(%S+)%s*(.*)$")
    return string.lower(command or ""), rest or ""
end

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
        return
    end

    if type(_G.print) == "function" then
        _G.print(message)
    end
end

local function open_request_wizard(mainFrame)
    if not mainFrame or type(mainFrame.OpenRequestWizard) ~= "function" then
        return
    end

    mainFrame:OpenRequestWizard()
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, function()
            if mainFrame.activeView == "REQUESTS" and type(mainFrame.OpenRequestWizard) == "function" then
                mainFrame:OpenRequestWizard()
            end
        end)
    end
end

local function open_access_ui(mainFrame, accessProfile, requestOnlyOpensWizard)
    if not mainFrame then
        return
    end

    if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
        mainFrame:ShowBlockedAccess("Access blocked")
        return
    end

    if accessProfile == "full_shell" and type(mainFrame.ShowDashboard) == "function" then
        mainFrame:ShowDashboard()
        return
    end

    if type(mainFrame.ShowRequestOnly) == "function" then
        mainFrame:ShowRequestOnly()
        if requestOnlyOpensWizard then
            open_request_wizard(mainFrame)
        end
    end
end

local function show_help()
    push_chat_line("GBankManager commands:")
    push_chat_line("/gbm - Open the UI you have access to.")
    push_chat_line("/gbm help - Show all available commands.")
    push_chat_line("/gbm ui - Open the main addon UI.")
    push_chat_line("/gbm request - Open the request workflow.")
    push_chat_line("/gbm scan - Scan the guild bank and ledger.")
    push_chat_line("/gbm debug quality <itemID> - Print bundled and live crafted-quality resolution details.")
    push_chat_line("/gbm test smoke - Run the in-game smoke test.")
    push_chat_line("/gbm test unit - Run the in-game unit checks.")
    push_chat_line("/gbm auth export|pull|push|apply - Manage the guild policy string.")
end

local function resolve_crafted_quality_module(existing)
    if type(existing) == "table" and type(existing.DescribeItemResolution) == "function" then
        return existing
    end

    local namespace = _G.GBankManagerNamespace
    local liveModule = namespace and namespace.modules and namespace.modules.craftedQuality or ns.modules.craftedQuality
    if type(liveModule) == "table" and type(liveModule.DescribeItemResolution) == "function" then
        ns.modules.craftedQuality = liveModule
        return liveModule
    end

    if type(_G.dofile) == "function" then
        local loaded = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
        if type(loaded) == "table" and type(loaded.DescribeItemResolution) == "function" then
            ns.modules.craftedQuality = loaded
            return loaded
        end
    end

    return existing
end

_G.SLASH_GBANKMANAGER1 = "/gbm"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.GBANKMANAGER = function(msg)
    local scanner = ns.modules.scanner
    local mainFrame = ns.modules.mainFrame
    local auth = ns.modules.auth or ns.modules.permissions
    local authPolicySource = ns.modules.authPolicySource
    local craftedQuality = ns.modules.craftedQuality
    local liveSmoke = ns.modules.liveSmoke
    local inGameUnit = ns.modules.inGameUnit
    local store = ns.modules.store or ns.data.store
    local command, remainder = split_command(msg)
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    local context = auth and type(auth.GetLivePlayerContext) == "function" and auth.GetLivePlayerContext(db) or {}
    local policy = store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or db.auth
    local accessProfile = auth and type(auth.GetEffectiveAccessProfile) == "function" and auth.GetEffectiveAccessProfile(context, policy) or "full_shell"

    if command == "help" then
        show_help()
        return "help"
    elseif command == "debug" then
        local subcommand, payload = split_command(remainder)
        if subcommand == "quality" then
            craftedQuality = resolve_crafted_quality_module(craftedQuality)
            local itemID = tonumber(trim(payload or ""))
            if not itemID then
                push_chat_line("GBankManager: Usage: /gbm debug quality <itemID>")
                return "debug_quality_usage"
            end

            if type(craftedQuality) ~= "table" or type(craftedQuality.DescribeItemResolution) ~= "function" then
                push_chat_line("GBankManager: Crafted-quality debug is unavailable right now.")
                return "debug_quality_unavailable"
            end

            local lines = craftedQuality.DescribeItemResolution(itemID, "", 0, 0, "reagent")
            for _, line in ipairs(lines or {}) do
                push_chat_line(string.format("GBankManager: %s", tostring(line or "")))
            end
            return lines
        end
    elseif command == "auth" and type(authPolicySource) == "table" then
        local subcommand, payload = split_command(remainder)
        if subcommand == "" or subcommand == "export" or subcommand == "show" then
            local exportString = authPolicySource.ExportPolicyString(policy)
            ns.state.lastAuthExportString = exportString
            return exportString
        elseif subcommand == "apply" then
            local _, reason = authPolicySource.ApplyPolicyString(db, payload)
            if mainFrame and type(mainFrame.RefreshView) == "function" then
                mainFrame:RefreshView()
            end
            return reason
        elseif subcommand == "pull" then
            local _, reason = authPolicySource.PullPolicyFromGuildInfo(db)
            if mainFrame and type(mainFrame.RefreshView) == "function" then
                mainFrame:RefreshView()
            end
            return reason
        elseif subcommand == "push" then
            local _, _, snippet = authPolicySource.PushPolicyToGuildInfo(db)
            return snippet
        end
    elseif command == "test" then
        local subcommand = split_command(remainder)
        if subcommand == "smoke" then
            if type(liveSmoke) == "table" and type(liveSmoke.Run) == "function" then
                return liveSmoke.Run()
            end

            push_chat_line("GBankManager smoke test unavailable.")
            return "smoke_test_unavailable"
        elseif subcommand == "unit" then
            if type(inGameUnit) == "table" and type(inGameUnit.Run) == "function" then
                return inGameUnit.Run()
            end

            push_chat_line("GBankManager in-game unit test unavailable.")
            return "unit_test_unavailable"
        end

        push_chat_line("GBankManager unknown test command.")
        return "unknown_test_command"
    elseif command == "ui" and mainFrame then
        open_access_ui(mainFrame, accessProfile, false)
    elseif command == "request" and mainFrame then
        if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
            mainFrame:ShowBlockedAccess("Access blocked")
        elseif accessProfile == "full_shell" then
            if type(mainFrame.ShowDashboard) == "function" then
                mainFrame:ShowDashboard()
            end
            if type(mainFrame.SelectView) == "function" then
                mainFrame:SelectView("REQUESTS")
            end
            open_request_wizard(mainFrame)
        elseif type(mainFrame.ShowRequestOnly) == "function" then
            mainFrame:ShowRequestOnly()
            open_request_wizard(mainFrame)
        end
    elseif command == "scan" and type(scanner) == "table" then
        scanner.BeginScan()
    elseif command == "" and mainFrame then
        open_access_ui(mainFrame, accessProfile, accessProfile ~= "full_shell")
    elseif command ~= "" then
        show_help()
        return "unknown_command"
    end
end

slash.command = _G.SlashCmdList.GBANKMANAGER
slash.alias = _G.SLASH_GBANKMANAGER1
slash.StartScan = slash.command

ns.modules.slash = slash

return slash
