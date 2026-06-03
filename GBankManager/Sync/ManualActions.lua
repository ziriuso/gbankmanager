local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local manualActions = ns.modules.syncManualActions or {}
local permissions = ns.modules.auth or ns.modules.permissions or {}
local transport = ns.modules.syncTransport or {}
local bankLedger = ns.modules.bankLedger or {}
local store = ns.modules.store or ns.data.store

local COOLDOWN_SECONDS = 60
local ACTION_ORDER = {
    "requests",
    "minimums",
    "history",
    "ledger",
}

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalize_action(action)
    action = tostring(action or ""):lower()
    if action == "" then
        return "all"
    end

    if action == "request" then
        return "requests"
    end

    if action == "minimum" then
        return "minimums"
    end

    if action == "all" or action == "requests" or action == "minimums" or action == "history" or action == "ledger" then
        return action
    end

    return nil
end

local function allowed_actions_for_profile(accessProfile)
    if tostring(accessProfile or "") == "request_only" then
        return {
            requests = true,
            all = true,
        }
    end

    return {
        requests = true,
        minimums = true,
        history = true,
        ledger = true,
        all = true,
    }
end

local function cooldown_state(db)
    db = type(db) == "table" and db or {}
    db.ui = ensure_table(db.ui)
    db.ui.syncCooldowns = ensure_table(db.ui.syncCooldowns)
    return db.ui.syncCooldowns
end

local function current_context(db)
    if type(permissions.GetLivePlayerContext) == "function" then
        return permissions.GetLivePlayerContext(db)
    end

    return {}
end

local function current_guild_key(db)
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

local function current_addon_version()
    return tostring(((ns.constants or {}).ADDON_VERSION) or "")
end

local function clone_array_records(records)
    local out = {}
    for _, record in ipairs(records or {}) do
        local copy = {}
        for key, value in pairs(record or {}) do
            copy[key] = value
        end
        out[#out + 1] = copy
    end
    return out
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

local function default_action_handlers()
    return {
        requests = function(db, options)
            if type(transport.Send) ~= "function" then
                return false, "Manual sync is unavailable right now."
            end

            local snapshot = clone_array_records((db or {}).requests or {})
            transport.Send("GUILD", "GUILD", {
                type = "REQUESTS_SNAPSHOT",
                updatedAt = tonumber(options.now or 0) or 0,
                payload = {
                    guildKey = current_guild_key(db),
                    actorContext = current_context(db),
                    requests = snapshot,
                },
            })
            return true, string.format("Requested request sync for %d request(s).", #snapshot)
        end,
        minimums = function(db, options)
            if type(transport.Send) ~= "function" then
                return false, "Manual sync is unavailable right now."
            end

            local snapshot = clone_array_records((db or {}).minimums or {})
            transport.Send("GUILD", "GUILD", {
                type = "MINIMUMS_SNAPSHOT",
                updatedAt = tonumber(options.now or 0) or 0,
                payload = {
                    guildKey = current_guild_key(db),
                    actorContext = current_context(db),
                    minimums = snapshot,
                },
            })
            return true, string.format("Requested minimums sync for %d rule(s).", #snapshot)
        end,
        history = function(db, options)
            local historyView = ns.modules.historyView or {}
            if type(transport.Send) ~= "function" or type(historyView.BuildSyncSnapshot) ~= "function" then
                return false, "Manual sync is unavailable right now."
            end

            local snapshot = historyView.BuildSyncSnapshot((db or {}).auditLog or {})
            transport.Send("GUILD", "GUILD", {
                type = "HISTORY_SNAPSHOT",
                updatedAt = tonumber(options.now or 0) or 0,
                payload = {
                    guildKey = current_guild_key(db),
                    actorContext = current_context(db),
                    entries = snapshot,
                },
            })
            return true, string.format("Requested history sync for %d visible row(s).", #snapshot)
        end,
        ledger = function(db, options)
            if type(transport.Send) ~= "function" or type(bankLedger.EnsureState) ~= "function" then
                return false, "Manual sync is unavailable right now."
            end

            local ledgerState = bankLedger.EnsureState(db)
            local itemGroups = {}
            for _, row in ipairs((ledgerState or {}).itemLogs or {}) do
                local tabIndex = tonumber(row.tabIndex or 0) or 0
                local tabName = tostring(row.tabName or ("Tab " .. tostring(tabIndex)))
                local key = string.format("%d|%s", tabIndex, tabName)
                local group = itemGroups[key]
                if group == nil then
                    group = {
                        tabIndex = tabIndex,
                        tabName = tabName,
                        transactions = {},
                    }
                    itemGroups[key] = group
                end

                local parts = split_timestamp(row.timestamp or row.when)
                local transaction = {
                    type = item_row_type(row.action),
                    who = row.who,
                    itemID = row.itemID,
                    itemName = row.item,
                    quantity = row.quantity,
                    fromTabName = row.fromTabName ~= "-" and row.fromTabName or nil,
                    craftedQuality = row.craftedQuality or row.qualityTier,
                }
                for keyName, value in pairs(parts) do
                    transaction[keyName] = value
                end
                group.transactions[#group.transactions + 1] = transaction
            end

            local itemCount = 0
            for _, group in pairs(itemGroups) do
                local payload = {
                    guildKey = current_guild_key(db),
                    actorContext = current_context(db),
                    version = current_addon_version(),
                    kind = "item",
                    sourceTabIndex = group.tabIndex,
                    sourceTabName = group.tabName,
                    scanStartedAt = tonumber(options.now or 0) or 0,
                    transactions = group.transactions,
                }
                if type(bankLedger.SanitizeRemoteDeltaPayload) == "function" then
                    payload = bankLedger.SanitizeRemoteDeltaPayload(payload)
                end
                itemCount = itemCount + #(payload.transactions or {})
                transport.Send("GUILD", "GUILD", {
                    type = "LEDGER_DELTA",
                    updatedAt = tonumber(options.now or 0) or 0,
                    payload = payload,
                })
            end

            local moneyTransactions = {}
            for _, row in ipairs((ledgerState or {}).moneyLogs or {}) do
                local parts = split_timestamp(row.timestamp or row.when)
                local transaction = {
                    type = money_row_type(row.action),
                    who = row.who,
                    amountCopper = row.amountCopper or row.amount,
                }
                for keyName, value in pairs(parts) do
                    transaction[keyName] = value
                end
                moneyTransactions[#moneyTransactions + 1] = transaction
            end

            local moneyCount = #moneyTransactions
            if #moneyTransactions > 0 then
                local payload = {
                    guildKey = current_guild_key(db),
                    actorContext = current_context(db),
                    version = current_addon_version(),
                    kind = "money",
                    scanStartedAt = tonumber(options.now or 0) or 0,
                    repairThresholdGold = tonumber((((db or {}).ui or {}).logsHistorySettings or {}).repairThresholdGold or 5000) or 5000,
                    transactions = moneyTransactions,
                }
                if type(bankLedger.SanitizeRemoteDeltaPayload) == "function" then
                    payload = bankLedger.SanitizeRemoteDeltaPayload(payload)
                end
                moneyCount = #(payload.transactions or {})
                if moneyCount > 0 then
                    transport.Send("GUILD", "GUILD", {
                        type = "LEDGER_DELTA",
                        updatedAt = tonumber(options.now or 0) or 0,
                        payload = payload,
                    })
                end
            end

            return true, string.format("Requested ledger sync for %d item row(s) and %d money row(s).", itemCount, moneyCount)
        end,
    }
end

local function action_targets(action, accessProfile)
    if action == "all" then
        if tostring(accessProfile or "") == "request_only" then
            return { "requests" }, "requests"
        end

        return ACTION_ORDER, "all"
    end

    return { action }, action
end

local function remaining_cooldown_seconds(state, action, now)
    local lastRunAt = tonumber((state or {})[action] or 0) or 0
    local elapsed = math.max(0, (tonumber(now or 0) or 0) - lastRunAt)
    local remaining = COOLDOWN_SECONDS - elapsed
    if remaining > 0 then
        return remaining
    end

    return 0
end

local function mark_run(state, action, now)
    state[action] = tonumber(now or 0) or 0
end

function manualActions.ResolveDefaultAction(accessProfile)
    if tostring(accessProfile or "") == "request_only" then
        return "requests"
    end

    return "all"
end

function manualActions.Run(db, options)
    options = type(options) == "table" and options or {}
    local accessProfile = tostring(options.accessProfile or "full_shell")
    local action = normalize_action(options.action)
    local now = tonumber(options.now or (_G.time and _G.time() or 0)) or 0
    local allowed = allowed_actions_for_profile(accessProfile)
    local skipCooldown = options.skipCooldown == true

    if not action then
        return {
            ok = false,
            action = "invalid",
            message = "Unknown sync action.",
        }
    end

    if allowed[action] ~= true then
        return {
            ok = false,
            action = action,
            message = "This sync action requires broader guild-management access.",
        }
    end

    local targets, reportedAction = action_targets(action, accessProfile)
    local state = cooldown_state(db)
    if not skipCooldown then
        local actionCooldown = remaining_cooldown_seconds(state, action, now)
        if actionCooldown > 0 then
            return {
                ok = false,
                action = reportedAction,
                message = string.format("This sync action is cooling down. Manual sync actions use a 60-second cooldown. Try again in %d seconds.", actionCooldown),
            }
        end

        for _, targetAction in ipairs(targets) do
            local remaining = remaining_cooldown_seconds(state, targetAction, now)
            if remaining > 0 then
                return {
                    ok = false,
                    action = reportedAction,
                    message = string.format("This sync action is cooling down. Manual sync actions use a 60-second cooldown. Try again in %d seconds.", remaining),
                }
            end
        end
    end

    local handlers = ensure_table(ns.modules.syncManualActionHandlers)
    local defaults = default_action_handlers()
    for _, targetAction in ipairs(targets) do
        local handler = handlers[targetAction] or defaults[targetAction]
        if type(handler) == "function" then
            local ok, handlerMessage = handler(db, {
                action = targetAction,
                accessProfile = accessProfile,
                now = now,
            })
            if ok == false then
                return {
                    ok = false,
                    action = reportedAction,
                    message = tostring(handlerMessage or "Unable to trigger sync."),
                }
            end
        end
    end

    if not skipCooldown then
        mark_run(state, action, now)
        for _, targetAction in ipairs(targets) do
            mark_run(state, targetAction, now)
        end
    end

    local successMessage = action == "all"
        and "Triggered all available sync actions."
        or string.format("Triggered %s sync.", reportedAction)

    return {
        ok = true,
        action = reportedAction,
        message = successMessage,
    }
end

ns.modules.syncManualActions = manualActions

return manualActions
