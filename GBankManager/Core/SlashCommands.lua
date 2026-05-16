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

_G.SLASH_GBANKMANAGER1 = "/gbm"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.GBANKMANAGER = function(msg)
    local scanner = ns.modules.scanner
    local mainFrame = ns.modules.mainFrame
    local auth = ns.modules.auth or ns.modules.permissions
    local authPolicySource = ns.modules.authPolicySource
    local liveSmoke = ns.modules.liveSmoke
    local store = ns.modules.store or ns.data.store
    local command, remainder = split_command(msg)
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    local context = auth and type(auth.GetLivePlayerContext) == "function" and auth.GetLivePlayerContext(db) or {}
    local policy = store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or db.auth
    local accessProfile = auth and type(auth.GetEffectiveAccessProfile) == "function" and auth.GetEffectiveAccessProfile(context, policy) or "full_shell"

    if command == "auth" and type(authPolicySource) == "table" then
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
        end

        push_chat_line("GBankManager unknown test command.")
        return "unknown_test_command"
    elseif command == "ui" and mainFrame then
        if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
            mainFrame:ShowBlockedAccess("Access blocked")
        elseif accessProfile == "full_shell" and type(mainFrame.ShowDashboard) == "function" then
            mainFrame:ShowDashboard()
        elseif type(mainFrame.ShowRequestOnly) == "function" then
            mainFrame:ShowRequestOnly()
        end
    elseif command == "request" and mainFrame then
        if accessProfile == "blocked" and type(mainFrame.ShowBlockedAccess) == "function" then
            mainFrame:ShowBlockedAccess("Access blocked")
        elseif type(mainFrame.ShowRequestOnly) == "function" then
            mainFrame:ShowRequestOnly()
        end
    elseif (command == "" or command == "scan") and type(scanner) == "table" then
        scanner.BeginScan()
    end
end

slash.command = _G.SlashCmdList.GBANKMANAGER
slash.alias = _G.SLASH_GBANKMANAGER1
slash.StartScan = slash.command

ns.modules.slash = slash

return slash
