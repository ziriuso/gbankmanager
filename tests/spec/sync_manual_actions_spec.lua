local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

_G.UnitName = function()
    return "SyncTester"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local manualActions = ns.modules.syncManualActions
local transport = ns.modules.syncTransport

local function fresh_db()
    return {
        ui = {},
    }
end

assert.truthy(type(manualActions) == "table", "manual sync actions module should load from the toc")
assert.truthy(type(manualActions.ResolveDefaultAction) == "function", "manual sync actions should expose default action routing")
assert.truthy(type(manualActions.Run) == "function", "manual sync actions should expose the manual sync runner")

assert.equal("all", manualActions.ResolveDefaultAction("full_shell"), "full-shell bare sync should default to all")
assert.equal("requests", manualActions.ResolveDefaultAction("request_only"), "request-only bare sync should default to requests")

local db = fresh_db()
local dispatchCalls = {}
ns.modules.syncManualActionHandlers = {
    requests = function(_, options)
        dispatchCalls[#dispatchCalls + 1] = {
            action = "requests",
            now = options.now,
        }
        return true, "Triggered request sync."
    end,
    minimums = function(_, options)
        dispatchCalls[#dispatchCalls + 1] = {
            action = "minimums",
            now = options.now,
        }
        return true, "Triggered minimums sync."
    end,
    history = function(_, options)
        dispatchCalls[#dispatchCalls + 1] = {
            action = "history",
            now = options.now,
        }
        return true, "Triggered history sync."
    end,
    ledger = function(_, options)
        dispatchCalls[#dispatchCalls + 1] = {
            action = "ledger",
            now = options.now,
        }
        return true, "Triggered ledger sync."
    end,
}

local requestOnlyResult = manualActions.Run(db, {
    action = "requests",
    accessProfile = "request_only",
    now = 1717000000,
})

assert.equal(true, requestOnlyResult.ok, "request-only users should be allowed to trigger request sync")
assert.equal("requests", requestOnlyResult.action, "request-only request sync should keep the requests action label")
assert.equal(1, #dispatchCalls, "request-only request sync should dispatch exactly once")

local denied = manualActions.Run(db, {
    action = "ledger",
    accessProfile = "request_only",
    now = 1717000000,
})

assert.equal(false, denied.ok, "request-only users should not be allowed to trigger ledger sync")
assert.truthy(string.find(denied.message or "", "requires broader guild-management access", 1, true) ~= nil, "denied sync actions should explain why they are disabled")
assert.equal(1, #dispatchCalls, "denied sync actions should not dispatch")

local first = manualActions.Run(db, {
    action = "requests",
    accessProfile = "full_shell",
    now = 1717000061,
})
local second = manualActions.Run(db, {
    action = "requests",
    accessProfile = "full_shell",
    now = 1717000080,
})

assert.equal(true, first.ok, "first request sync after cooldown should be allowed")
assert.equal(false, second.ok, "request sync should be throttled for 60 seconds")
assert.truthy(string.find(second.message or "", "60", 1, true) ~= nil, "throttled sync should mention the cooldown window")

local ledgerAllowed = manualActions.Run(db, {
    action = "ledger",
    accessProfile = "full_shell",
    now = 1717000080,
})

assert.equal(true, ledgerAllowed.ok, "ledger sync should use a different cooldown bucket than request sync")
assert.equal(3, #dispatchCalls, "ledger sync should still dispatch even while request sync is cooling down")

local requestOnlyAll = manualActions.Run(db, {
    action = "all",
    accessProfile = "request_only",
    now = 1717000200,
})

assert.equal(true, requestOnlyAll.ok, "request-only Sync All should resolve to the request sync path")
assert.equal("requests", requestOnlyAll.action, "request-only Sync All should collapse to the requests action")

local historyAllowed = manualActions.Run(db, {
    action = "history",
    accessProfile = "full_shell",
    now = 1717000240,
})

assert.equal(true, historyAllowed.ok, "full-shell users should be allowed to trigger history sync")
assert.equal("history", historyAllowed.action, "history sync should keep the history action label")

local fullShellAll = manualActions.Run(db, {
    action = "all",
    accessProfile = "full_shell",
    now = 1717000300,
})

assert.equal(true, fullShellAll.ok, "full-shell Sync All should run when all family cooldowns are clear")
assert.equal("all", fullShellAll.action, "full-shell Sync All should report the all action label")
assert.equal(9, #dispatchCalls, "full-shell Sync All should dispatch each eligible family once, including history")

local fullShellAllCooldown = manualActions.Run(db, {
    action = "all",
    accessProfile = "full_shell",
    now = 1717000310,
})

assert.equal(false, fullShellAllCooldown.ok, "Sync All should have its own cooldown")
assert.truthy(string.find(fullShellAllCooldown.message or "", "cooling down", 1, true) ~= nil, "Sync All cooldown feedback should be player-facing")

local originalHandlers = ns.modules.syncManualActionHandlers
local originalSend = transport.Send
local sentMessages = {}
ns.modules.syncManualActionHandlers = nil
transport.Send = function(distribution, target, message)
    sentMessages[#sentMessages + 1] = {
        distribution = distribution,
        target = target,
        message = message,
    }
    return true
end

local defaultLedgerDb = fresh_db()
defaultLedgerDb.meta = {
    guildName = "Guild Testers",
}
defaultLedgerDb.bankLedger = {
    itemLogs = {
        {
            entryId = "manual-item-a",
            timestamp = 21600,
            action = "Deposit",
            who = "SyncTester-Stormrage",
            itemID = 1,
            item = "Manual Oil",
            quantity = 2,
            tabIndex = 1,
            tabName = "Alchemy",
        },
    },
    moneyLogs = {
        {
            entryId = "manual-money-b",
            timestamp = 43200,
            action = "Repair",
            who = "SyncTester-Stormrage",
            amountCopper = 100,
        },
    },
}

local defaultLedgerSync = manualActions.Run(defaultLedgerDb, {
    action = "ledger",
    accessProfile = "full_shell",
    now = 1717000400,
    skipCooldown = true,
})

assert.equal(true, defaultLedgerSync.ok, "default ledger sync should succeed")
assert.equal("Announced ledger manifest for 2 row(s).", defaultLedgerSync.message, "manual ledger sync should announce the manifest row count")
assert.equal(1, #sentMessages, "manual ledger sync should send exactly one manifest message")
assert.equal("GUILD", sentMessages[1].distribution, "manual ledger manifests should use guild distribution")
assert.equal("GUILD", sentMessages[1].target, "manual ledger manifests should use guild target metadata")
assert.equal("LEDGER_MANIFEST", sentMessages[1].message.type, "manual ledger sync should send a ledger manifest")
assert.equal(2, tonumber(((sentMessages[1].message.payload or {}).ledgerProtocol) or 0), "manual ledger manifests should advertise protocol 2")
assert.equal(2, tonumber((((sentMessages[1].message.payload or {}).manifest or {}).totalCount) or 0), "manual ledger manifests should include the built manifest row count")

transport.Send = originalSend
ns.modules.syncManualActionHandlers = originalHandlers
