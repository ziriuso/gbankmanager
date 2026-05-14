# WoW Guild Bank Addon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a World of Warcraft guild bank management addon that scans all accessible guild bank tabs, stores current inventory and scan history, computes shortages from recurring minimums and one-time purchase targets, manages approval-based requests, syncs between addon users, and exports purchase data to Auctionator and spreadsheet-friendly formats.

**Architecture:** Create a modular WoW addon in `GBankManager/` with thin UI/event layers and pure data-processing modules for snapshots, diffs, planning, permissions, and exports. Keep deterministic business logic in isolated Lua modules so it can be tested with a local Lua runner, while validating WoW API behavior in-game with slash-command smoke tests and bank interaction QA.

**Tech Stack:** World of Warcraft retail addon API, Lua 5.1-compatible addon code, SavedVariables persistence, `C_ChatInfo.SendAddonMessage` for sync, a vendored local Lua runner under `tools/lua/` for deterministic tests, and git for frequent commits.

---

## Proposed File Structure

### Addon files

- Create: `GBankManager/GBankManager.toc`
- Create: `GBankManager/Bootstrap.lua`
- Create: `GBankManager/Core/Namespace.lua`
- Create: `GBankManager/Core/Events.lua`
- Create: `GBankManager/Core/SlashCommands.lua`
- Create: `GBankManager/Core/Constants.lua`
- Create: `GBankManager/Data/Defaults.lua`
- Create: `GBankManager/Data/Migrations.lua`
- Create: `GBankManager/Data/Store.lua`
- Create: `GBankManager/Domain/Permissions.lua`
- Create: `GBankManager/Domain/Snapshots.lua`
- Create: `GBankManager/Domain/Diff.lua`
- Create: `GBankManager/Domain/Planning.lua`
- Create: `GBankManager/Domain/Exports.lua`
- Create: `GBankManager/Domain/Requests.lua`
- Create: `GBankManager/Sync/Codec.lua`
- Create: `GBankManager/Sync/Transport.lua`
- Create: `GBankManager/Sync/Coordinator.lua`
- Create: `GBankManager/UI/MainFrame.lua`
- Create: `GBankManager/UI/DashboardView.lua`
- Create: `GBankManager/UI/InventoryView.lua`
- Create: `GBankManager/UI/MinimumsView.lua`
- Create: `GBankManager/UI/TargetsView.lua`
- Create: `GBankManager/UI/RequestsView.lua`
- Create: `GBankManager/UI/HistoryView.lua`
- Create: `GBankManager/UI/ExportsView.lua`
- Create: `GBankManager/UI/RequestDialog.lua`
- Create: `GBankManager/UI/ExportDialog.lua`
- Create: `GBankManager/Features/GuildBankScanner.lua`

### Tests and tooling

- Create: `tests/run_all.lua`
- Create: `tests/helpers/assert.lua`
- Create: `tests/helpers/wow_stubs.lua`
- Create: `tests/spec/store_spec.lua`
- Create: `tests/spec/diff_spec.lua`
- Create: `tests/spec/planning_spec.lua`
- Create: `tests/spec/exports_spec.lua`
- Create: `tests/spec/requests_spec.lua`
- Create: `tools/lua/README.md`

### Docs

- Create: `README.md`
- Create: `docs/manual-test-checklist.md`

## Implementation Notes

- Keep SavedVariables schema versioned from day one to avoid lock-in.
- Treat latest accepted scan as current inventory truth.
- Keep request approval/fulfillment separate from planning math.
- Keep sync authority rules centralized in one module rather than spread through UI code.
- Put all string export formatting in `Domain/Exports.lua`, not in UI handlers.

### Task 1: Scaffold the addon, namespace, and local test harness

**Files:**
- Create: `GBankManager/GBankManager.toc`
- Create: `GBankManager/Bootstrap.lua`
- Create: `GBankManager/Core/Namespace.lua`
- Create: `GBankManager/Core/Constants.lua`
- Create: `GBankManager/Core/Events.lua`
- Create: `GBankManager/Core/SlashCommands.lua`
- Create: `tests/run_all.lua`
- Create: `tests/helpers/assert.lua`
- Create: `tests/helpers/wow_stubs.lua`
- Create: `tests/spec/store_spec.lua`
- Create: `tools/lua/README.md`
- Create: `README.md`

- [ ] **Step 1: Write the failing bootstrap test**

```lua
-- tests/spec/store_spec.lua
local assert = require("tests.helpers.assert")
local ns = dofile("GBankManager/Core/Namespace.lua")

assert.equal("GBankManager", ns.addonName, "namespace should expose addon name")
assert.truthy(type(ns.modules) == "table", "namespace should expose module table")
```

- [ ] **Step 2: Add the minimal test harness**

```lua
-- tests/helpers/assert.lua
local M = {}

function M.equal(expected, actual, message)
    if expected ~= actual then
        error((message or "values differ") .. string.format(" | expected=%s actual=%s", tostring(expected), tostring(actual)))
    end
end

function M.truthy(value, message)
    if not value then
        error(message or "expected truthy value")
    end
end

return M
```

```lua
-- tests/run_all.lua
local specs = {
    "tests/spec/store_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_all.lua")
```

```md
<!-- tools/lua/README.md -->
# Local Lua Runner

Place a portable Lua 5.1-compatible executable at `tools/lua/lua.exe`.

Expected command:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: FAIL with `cannot open GBankManager/Core/Namespace.lua`

- [ ] **Step 4: Create the addon scaffold and make the test pass**

```lua
-- GBankManager/Core/Namespace.lua
local ns = {
    addonName = "GBankManager",
    modules = {},
    state = {},
}

return ns
```

```lua
-- GBankManager/Core/Constants.lua
local ns = dofile("GBankManager/Core/Namespace.lua")

ns.constants = {
    SCHEMA_VERSION = 1,
    ADDON_PREFIX = "GBankManager",
    INTERACTION_TYPE = 10,
    SLOTS_PER_TAB = 98,
}

return ns.constants
```

```lua
-- GBankManager/Bootstrap.lua
local ns = dofile("GBankManager/Core/Namespace.lua")
dofile("GBankManager/Core/Constants.lua")

return ns
```

```lua
-- GBankManager/Core/Events.lua
local ns = dofile("GBankManager/Bootstrap.lua")
ns.modules.events = {}
return ns.modules.events
```

```lua
-- GBankManager/Core/SlashCommands.lua
local ns = dofile("GBankManager/Bootstrap.lua")
ns.modules.slash = {}
return ns.modules.slash
```

```toc
## Interface: 110100
## Title: GBankManager
## Notes: Guild bank inventory and procurement manager
## Author: ziriuso
## SavedVariables: GBankManagerDB

Core/Namespace.lua
Core/Constants.lua
Bootstrap.lua
Core/Events.lua
Core/SlashCommands.lua
```

```md
# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.
```

- [ ] **Step 5: Run the test to verify it passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

- [ ] **Step 6: Commit the scaffold**

```powershell
git add GBankManager README.md tests tools
git commit -m "feat: scaffold addon and test harness"
```

### Task 2: Add SavedVariables schema, migrations, and permissions

**Files:**
- Create: `GBankManager/Data/Defaults.lua`
- Create: `GBankManager/Data/Migrations.lua`
- Create: `GBankManager/Data/Store.lua`
- Create: `GBankManager/Domain/Permissions.lua`
- Modify: `tests/run_all.lua`
- Modify: `tests/spec/store_spec.lua`

- [ ] **Step 1: Write failing tests for default schema and officer permissions**

```lua
-- tests/spec/store_spec.lua
local assert = require("tests.helpers.assert")
local defaults = dofile("GBankManager/Data/Defaults.lua")
local store = dofile("GBankManager/Data/Store.lua")
local permissions = dofile("GBankManager/Domain/Permissions.lua")

local db = store.CreateFreshDatabase("My Guild")
assert.equal(1, db.meta.schemaVersion, "fresh db should use schema version 1")
assert.equal("My Guild", db.meta.guildName, "guild name should be stored")
assert.truthy(db.requests ~= nil, "requests table should exist")
assert.truthy(permissions.CanApproveRequests("OFFICER"), "officers should approve requests")
assert.truthy(not permissions.CanViewInventory("MEMBER"), "members should not view inventory")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: FAIL with `cannot open GBankManager/Data/Defaults.lua`

- [ ] **Step 3: Implement the schema defaults, migrations, and permission helpers**

```lua
-- GBankManager/Data/Defaults.lua
local defaults = {}

function defaults.CreateDatabase(guildName)
    return {
        meta = {
            schemaVersion = 1,
            guildName = guildName or "Unknown",
            createdAt = 0,
            updatedAt = 0,
        },
        snapshots = {},
        currentSnapshotId = nil,
        changeLog = {},
        minimums = {},
        oneTimeTargets = {},
        requests = {},
        exportTemplates = {},
        syncState = {
            lastSyncAt = 0,
        },
    }
end

return defaults
```

```lua
-- GBankManager/Data/Migrations.lua
local migrations = {}

function migrations.Apply(db)
    db.meta = db.meta or {}
    db.meta.schemaVersion = db.meta.schemaVersion or 1
    db.snapshots = db.snapshots or {}
    db.changeLog = db.changeLog or {}
    db.minimums = db.minimums or {}
    db.oneTimeTargets = db.oneTimeTargets or {}
    db.requests = db.requests or {}
    db.exportTemplates = db.exportTemplates or {}
    db.syncState = db.syncState or { lastSyncAt = 0 }
    return db
end

return migrations
```

```lua
-- GBankManager/Data/Store.lua
local defaults = dofile("GBankManager/Data/Defaults.lua")
local migrations = dofile("GBankManager/Data/Migrations.lua")

local store = {}

function store.CreateFreshDatabase(guildName)
    return defaults.CreateDatabase(guildName)
end

function store.Normalize(db)
    return migrations.Apply(db or defaults.CreateDatabase("Unknown"))
end

return store
```

```lua
-- GBankManager/Domain/Permissions.lua
local permissions = {}

function permissions.CanApproveRequests(role)
    return role == "OFFICER" or role == "GUILDMASTER"
end

function permissions.CanViewInventory(role)
    return role == "OFFICER" or role == "GUILDMASTER"
end

function permissions.AutoApprovesOwnRequests(role)
    return permissions.CanApproveRequests(role)
end

return permissions
```

```lua
-- tests/run_all.lua
local package_path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

package.path = package_path

local specs = {
    "tests/spec/store_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_all.lua")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

- [ ] **Step 5: Commit schema and permission helpers**

```powershell
git add GBankManager/Data GBankManager/Domain tests
git commit -m "feat: add persistence schema and permissions"
```

### Task 3: Implement scanning, snapshots, and change-log diffing

**Files:**
- Create: `GBankManager/Domain/Snapshots.lua`
- Create: `GBankManager/Domain/Diff.lua`
- Create: `GBankManager/Features/GuildBankScanner.lua`
- Modify: `GBankManager/Core/Events.lua`
- Modify: `GBankManager/Core/SlashCommands.lua`
- Create: `tests/spec/diff_spec.lua`
- Modify: `tests/run_all.lua`

- [ ] **Step 1: Write failing tests for snapshot aggregation and diff generation**

```lua
-- tests/spec/diff_spec.lua
local assert = require("tests.helpers.assert")
local snapshots = dofile("GBankManager/Domain/Snapshots.lua")
local diff = dofile("GBankManager/Domain/Diff.lua")

local snapshot = snapshots.FromTabScan({
    scanId = "scan-2",
    guildName = "My Guild",
    actor = "OfficerOne",
    scannedTabs = {
        { index = 1, name = "Flasks", slots = {
            { itemID = 1001, name = "Flask Alpha", count = 4 },
            { itemID = 1001, name = "Flask Alpha", count = 6 },
        }},
    },
})

assert.equal(10, snapshot.items[1001].totalCount, "snapshot should aggregate duplicate item stacks")

local previous = {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 3, tabs = { ["Flasks"] = 3 } }
    }
}

local changes = diff.BuildChangeLog(previous, snapshot)
assert.equal("QUANTITY_INCREASED", changes[1].type, "diff should report quantity increase")
assert.equal(7, changes[1].delta, "diff should capture quantity delta")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: FAIL with `cannot open GBankManager/Domain/Snapshots.lua`

- [ ] **Step 3: Implement snapshot shaping and diffing**

```lua
-- GBankManager/Domain/Snapshots.lua
local snapshots = {}

function snapshots.FromTabScan(raw)
    local items = {}

    for _, tab in ipairs(raw.scannedTabs or {}) do
        for _, slot in ipairs(tab.slots or {}) do
            local entry = items[slot.itemID] or {
                itemID = slot.itemID,
                name = slot.name,
                totalCount = 0,
                tabs = {},
            }

            entry.totalCount = entry.totalCount + slot.count
            entry.tabs[tab.name] = (entry.tabs[tab.name] or 0) + slot.count
            items[slot.itemID] = entry
        end
    end

    return {
        scanId = raw.scanId,
        guildName = raw.guildName,
        actor = raw.actor,
        scannedTabs = raw.scannedTabs,
        scannedAt = raw.scannedAt or time(),
        items = items,
    }
end

return snapshots
```

```lua
-- GBankManager/Domain/Diff.lua
local diff = {}

function diff.BuildChangeLog(previous, current)
    local changes = {}
    local visited = {}

    previous = previous or { items = {} }
    current = current or { items = {} }

    for itemID, currentEntry in pairs(current.items) do
        local previousEntry = previous.items[itemID]
        visited[itemID] = true

        if not previousEntry then
            table.insert(changes, {
                type = "ITEM_ADDED",
                itemID = itemID,
                name = currentEntry.name,
                delta = currentEntry.totalCount,
            })
        elseif currentEntry.totalCount > previousEntry.totalCount then
            table.insert(changes, {
                type = "QUANTITY_INCREASED",
                itemID = itemID,
                name = currentEntry.name,
                delta = currentEntry.totalCount - previousEntry.totalCount,
            })
        elseif currentEntry.totalCount < previousEntry.totalCount then
            table.insert(changes, {
                type = "QUANTITY_DECREASED",
                itemID = itemID,
                name = currentEntry.name,
                delta = previousEntry.totalCount - currentEntry.totalCount,
            })
        end
    end

    for itemID, previousEntry in pairs(previous.items) do
        if not visited[itemID] then
            table.insert(changes, {
                type = "ITEM_REMOVED",
                itemID = itemID,
                name = previousEntry.name,
                delta = previousEntry.totalCount,
            })
        end
    end

    table.sort(changes, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    return changes
end

return diff
```

```lua
-- GBankManager/Features/GuildBankScanner.lua
local ns = dofile("GBankManager/Bootstrap.lua")
local snapshots = dofile("GBankManager/Domain/Snapshots.lua")
local diff = dofile("GBankManager/Domain/Diff.lua")

local scanner = {
    scanInProgress = false,
    tabsToScan = {},
    rawTabs = {},
    waitingForTab = nil,
}

function scanner.BeginScan()
    scanner.scanInProgress = true
    scanner.tabsToScan = {}
    scanner.rawTabs = {}
end

function scanner.FinishScan(actor, guildName, previousSnapshot)
    local currentSnapshot = snapshots.FromTabScan({
        scanId = tostring(time()),
        actor = actor,
        guildName = guildName,
        scannedTabs = scanner.rawTabs,
    })

    return currentSnapshot, diff.BuildChangeLog(previousSnapshot, currentSnapshot)
end

ns.modules.scanner = scanner
return scanner
```

```lua
-- tests/run_all.lua
package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

for _, path in ipairs({
    "tests/spec/store_spec.lua",
    "tests/spec/diff_spec.lua",
}) do
    dofile(path)
end

print("PASS tests/run_all.lua")
```

- [ ] **Step 4: Wire the in-game scan button and slash command**

```lua
-- GBankManager/Core/SlashCommands.lua
local ns = dofile("GBankManager/Bootstrap.lua")
local scanner = dofile("GBankManager/Features/GuildBankScanner.lua")

SLASH_GBANKMANAGER1 = "/gbm"
SlashCmdList["GBANKMANAGER"] = function(msg)
    local cmd = strtrim((msg or "")):lower()
    if cmd == "" or cmd == "scan" then
        scanner.BeginScan()
    end
end

ns.modules.slash = SlashCmdList["GBANKMANAGER"]
return ns.modules.slash
```

```lua
-- GBankManager/Core/Events.lua
local ns = dofile("GBankManager/Bootstrap.lua")
local scanner = dofile("GBankManager/Features/GuildBankScanner.lua")

local frame = CreateFrame("Frame")
frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")

frame:SetScript("OnEvent", function(_, event)
    if event == "GUILDBANKBAGSLOTS_CHANGED" and scanner.scanInProgress then
        -- continue scan queue here in implementation
    end
end)

ns.modules.events = frame
return frame
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

- [ ] **Step 6: Commit scan and diff support**

```powershell
git add GBankManager tests
git commit -m "feat: add snapshot scan and history diff foundation"
```

### Task 4: Implement planning, one-time targets, requests, and exports

**Files:**
- Create: `GBankManager/Domain/Planning.lua`
- Create: `GBankManager/Domain/Exports.lua`
- Create: `GBankManager/Domain/Requests.lua`
- Create: `tests/spec/planning_spec.lua`
- Create: `tests/spec/exports_spec.lua`
- Create: `tests/spec/requests_spec.lua`
- Modify: `tests/run_all.lua`

- [ ] **Step 1: Write failing tests for shortage math, request approval, and export formatting**

```lua
-- tests/spec/planning_spec.lua
local assert = require("tests.helpers.assert")
local planning = dofile("GBankManager/Domain/Planning.lua")

local plan = planning.BuildDemandPlan({
    snapshot = {
        items = {
            [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 6, tabs = { ["Flasks"] = 6 } }
        }
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 10, scope = "GLOBAL" }
    },
    oneTimeTargets = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", status = "OPEN" }
    },
    requests = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 2, approval = "APPROVED", fulfillment = "OPEN" }
    },
})

assert.equal(10, plan[1001].totalToBuy, "plan should merge minimums, targets, and requests")
assert.equal(4, plan[1001].sources.RESTOCK, "restock shortage should be included")
assert.equal(6, plan[1001].sources.ONE_TIME_TARGET, "one-time target gap should be included")
assert.equal(2, plan[1001].sources.REQUEST, "approved request should be included")
```

```lua
-- tests/spec/requests_spec.lua
local assert = require("tests.helpers.assert")
local requests = dofile("GBankManager/Domain/Requests.lua")

local memberRequest = requests.Create({
    role = "MEMBER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("PENDING", memberRequest.approval, "member requests should start pending")

local officerRequest = requests.Create({
    role = "OFFICER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("APPROVED", officerRequest.approval, "officer requests should auto-approve")
```

```lua
-- tests/spec/exports_spec.lua
local assert = require("tests.helpers.assert")
local exports = dofile("GBankManager/Domain/Exports.lua")

local text = exports.BuildDelimited({
    { itemID = 1001, itemName = "Flask Alpha", totalToBuy = 4, reason = "RESTOCK" }
}, {
    delimiter = ",",
    includeHeader = true,
    fields = { "itemName", "totalToBuy", "reason" },
})

assert.equal("itemName,totalToBuy,reason\nFlask Alpha,4,RESTOCK", text, "spreadsheet export should honor field order")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: FAIL with `cannot open GBankManager/Domain/Planning.lua`

- [ ] **Step 3: Implement planning and request rules**

```lua
-- GBankManager/Domain/Requests.lua
local permissions = dofile("GBankManager/Domain/Permissions.lua")

local requests = {}

function requests.Create(input)
    local autoApproved = permissions.AutoApprovesOwnRequests(input.role)
    return {
        requestId = input.requestId or tostring(time()),
        role = input.role,
        itemID = input.itemID,
        itemName = input.itemName,
        quantity = input.quantity,
        note = input.note or "",
        approval = autoApproved and "APPROVED" or "PENDING",
        fulfillment = "OPEN",
    }
end

return requests
```

```lua
-- GBankManager/Domain/Planning.lua
local planning = {}

local function ensureRow(plan, itemID, itemName)
    if not plan[itemID] then
        plan[itemID] = {
            itemID = itemID,
            itemName = itemName,
            totalToBuy = 0,
            sources = {
                RESTOCK = 0,
                ONE_TIME_TARGET = 0,
                REQUEST = 0,
            },
        }
    end
    return plan[itemID]
end

function planning.BuildDemandPlan(input)
    local plan = {}
    local snapshot = input.snapshot or { items = {} }

    for _, minimum in ipairs(input.minimums or {}) do
        local current = snapshot.items[minimum.itemID] and snapshot.items[minimum.itemID].totalCount or 0
        local shortage = math.max(0, minimum.quantity - current)
        local row = ensureRow(plan, minimum.itemID, minimum.itemName)
        row.sources.RESTOCK = row.sources.RESTOCK + shortage
        row.totalToBuy = row.totalToBuy + shortage
    end

    for _, target in ipairs(input.oneTimeTargets or {}) do
        if target.status == "OPEN" then
            local current = snapshot.items[target.itemID] and snapshot.items[target.itemID].totalCount or 0
            local shortage = math.max(0, target.quantity - current)
            local row = ensureRow(plan, target.itemID, target.itemName)
            row.sources.ONE_TIME_TARGET = row.sources.ONE_TIME_TARGET + shortage
            row.totalToBuy = row.totalToBuy + shortage
        end
    end

    for _, request in ipairs(input.requests or {}) do
        if request.approval == "APPROVED" and request.fulfillment == "OPEN" then
            local row = ensureRow(plan, request.itemID, request.itemName)
            row.sources.REQUEST = row.sources.REQUEST + request.quantity
            row.totalToBuy = row.totalToBuy + request.quantity
        end
    end

    return plan
end

return planning
```

- [ ] **Step 4: Implement export builders**

```lua
-- GBankManager/Domain/Exports.lua
local exports = {}

local function renderField(row, field)
    return tostring(row[field] or "")
end

function exports.BuildDelimited(rows, template)
    local lines = {}
    if template.includeHeader then
        table.insert(lines, table.concat(template.fields, template.delimiter))
    end

    for _, row in ipairs(rows) do
        local values = {}
        for _, field in ipairs(template.fields) do
            table.insert(values, renderField(row, field))
        end
        table.insert(lines, table.concat(values, template.delimiter))
    end

    return table.concat(lines, "\n")
end

function exports.BuildAuctionator(rows)
    local values = {}
    for _, row in ipairs(rows) do
        table.insert(values, string.format("%s x%d", row.itemName, row.totalToBuy))
    end
    return table.concat(values, "; ")
end

return exports
```

```lua
-- tests/run_all.lua
package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

for _, path in ipairs({
    "tests/spec/store_spec.lua",
    "tests/spec/diff_spec.lua",
    "tests/spec/planning_spec.lua",
    "tests/spec/requests_spec.lua",
    "tests/spec/exports_spec.lua",
}) do
    dofile(path)
end

print("PASS tests/run_all.lua")
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

- [ ] **Step 6: Commit planning, request, and export logic**

```powershell
git add GBankManager/Domain tests
git commit -m "feat: add planning engine and export builders"
```

### Task 5: Build officer dashboard, inventory, history, and export UI

**Files:**
- Create: `GBankManager/UI/MainFrame.lua`
- Create: `GBankManager/UI/DashboardView.lua`
- Create: `GBankManager/UI/InventoryView.lua`
- Create: `GBankManager/UI/HistoryView.lua`
- Create: `GBankManager/UI/ExportsView.lua`
- Create: `GBankManager/UI/ExportDialog.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Core/SlashCommands.lua`
- Create: `docs/manual-test-checklist.md`

- [ ] **Step 1: Add a main frame shell and slash command to open it**

```lua
-- GBankManager/UI/MainFrame.lua
local ns = dofile("GBankManager/Bootstrap.lua")

local mainFrame = CreateFrame("Frame", "GBankManagerFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(900, 560)
mainFrame:SetPoint("CENTER")
mainFrame:Hide()

function mainFrame:ShowDashboard()
    self:Show()
end

ns.modules.mainFrame = mainFrame
return mainFrame
```

```lua
-- GBankManager/Core/SlashCommands.lua
local ns = dofile("GBankManager/Bootstrap.lua")
local scanner = dofile("GBankManager/Features/GuildBankScanner.lua")
local mainFrame = dofile("GBankManager/UI/MainFrame.lua")

SLASH_GBANKMANAGER1 = "/gbm"
SlashCmdList["GBANKMANAGER"] = function(msg)
    local cmd = strtrim((msg or "")):lower()
    if cmd == "ui" then
        mainFrame:ShowDashboard()
    elseif cmd == "" or cmd == "scan" then
        scanner.BeginScan()
    end
end

return SlashCmdList["GBANKMANAGER"]
```

- [ ] **Step 2: Build dashboard and list views for officer workflows**

```lua
-- GBankManager/UI/DashboardView.lua
local dashboard = {}

function dashboard.BuildSummary(db, planRows)
    return {
        lastScanAt = db.meta.updatedAt,
        pendingRequestCount = #(db.requests or {}),
        exportReadyCount = #(planRows or {}),
    }
end

return dashboard
```

```lua
-- GBankManager/UI/InventoryView.lua
local inventoryView = {}

function inventoryView.FilterItems(items, query)
    local out = {}
    query = string.lower(query or "")
    for _, item in pairs(items or {}) do
        if query == "" or string.find(string.lower(item.name), query, 1, true) then
            table.insert(out, item)
        end
    end
    return out
end

return inventoryView
```

```lua
-- GBankManager/UI/HistoryView.lua
local historyView = {}

function historyView.Filter(entries, filters)
    local out = {}
    for _, entry in ipairs(entries or {}) do
        local include = true
        if filters.changeType and entry.type ~= filters.changeType then
            include = false
        end
        if include then
            table.insert(out, entry)
        end
    end
    return out
end

return historyView
```

```lua
-- GBankManager/UI/ExportsView.lua
local exports = dofile("GBankManager/Domain/Exports.lua")

local exportsView = {}

function exportsView.BuildSpreadsheetText(rows)
    return exports.BuildDelimited(rows, {
        delimiter = ",",
        includeHeader = true,
        fields = { "itemName", "totalToBuy", "reason" },
    })
end

return exportsView
```

- [ ] **Step 3: Register the UI files in the TOC and write manual QA steps**

```toc
## Interface: 110100
## Title: GBankManager
## Notes: Guild bank inventory and procurement manager
## Author: ziriuso
## SavedVariables: GBankManagerDB

Core/Namespace.lua
Core/Constants.lua
Bootstrap.lua
Data/Defaults.lua
Data/Migrations.lua
Data/Store.lua
Domain/Permissions.lua
Domain/Snapshots.lua
Domain/Diff.lua
Domain/Planning.lua
Domain/Exports.lua
Domain/Requests.lua
Features/GuildBankScanner.lua
UI/MainFrame.lua
UI/DashboardView.lua
UI/InventoryView.lua
UI/HistoryView.lua
UI/ExportsView.lua
Core/Events.lua
Core/SlashCommands.lua
```

```md
<!-- docs/manual-test-checklist.md -->
# Manual Test Checklist

1. Copy `GBankManager` into `Interface/AddOns`.
2. Run `/reload`.
3. Open the guild bank.
4. Click `Scan Bank`.
5. Run `/gbm ui`.
6. Confirm dashboard shows last scan metadata.
7. Confirm inventory search returns expected items.
8. Confirm history entries appear after two scans with changed counts.
9. Confirm export dialog opens and produces spreadsheet text.
```

- [ ] **Step 4: Validate the UI in-game**

Run:

```powershell
Copy-Item -Recurse -Force .\GBankManager "C:\Gaming\World of Warcraft\_retail_\Interface\AddOns\GBankManager"
```

Expected: addon folder updates without copy errors

Then in game:

- `/reload`
- `/gbm ui`

Expected: main frame opens

- [ ] **Step 5: Commit the officer UI shell**

```powershell
git add GBankManager/UI GBankManager/GBankManager.toc docs/manual-test-checklist.md
git commit -m "feat: add officer dashboard and export ui shell"
```

### Task 6: Add minimums, one-time purchase targets, and member request UI

**Files:**
- Create: `GBankManager/UI/MinimumsView.lua`
- Create: `GBankManager/UI/TargetsView.lua`
- Create: `GBankManager/UI/RequestsView.lua`
- Create: `GBankManager/UI/RequestDialog.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Add view helpers for recurring minimums and one-time targets**

```lua
-- GBankManager/UI/MinimumsView.lua
local minimumsView = {}

function minimumsView.Upsert(list, rule)
    local updated = false
    for index, existing in ipairs(list) do
        if existing.itemID == rule.itemID and existing.scope == rule.scope and existing.tabName == rule.tabName then
            list[index] = rule
            updated = true
        end
    end
    if not updated then
        table.insert(list, rule)
    end
    return list
end

return minimumsView
```

```lua
-- GBankManager/UI/TargetsView.lua
local targetsView = {}

function targetsView.MarkSuggestedFulfilled(target, currentCount)
    if currentCount >= target.quantity then
        target.status = "SUGGESTED_FULFILLED"
    end
    return target
end

return targetsView
```

- [ ] **Step 2: Add request resolution dialog and request list behavior**

```lua
-- GBankManager/UI/RequestDialog.lua
local requests = dofile("GBankManager/Domain/Requests.lua")

local dialog = {}

function dialog.ResolveMatches(index, query)
    local out = {}
    query = string.lower(query or "")
    for _, item in ipairs(index or {}) do
        local matchesName = string.find(string.lower(item.name), query, 1, true)
        local matchesID = tostring(item.itemID) == query
        if matchesName or matchesID then
            table.insert(out, item)
        end
    end
    return out
end

function dialog.Submit(input)
    return requests.Create(input)
end

return dialog
```

```lua
-- GBankManager/UI/RequestsView.lua
local requestsView = {}

function requestsView.FilterOwnRequests(rows, playerName)
    local out = {}
    for _, row in ipairs(rows or {}) do
        if row.requester == playerName then
            table.insert(out, row)
        end
    end
    return out
end

return requestsView
```

- [ ] **Step 3: Add the views to the main frame and TOC**

```lua
-- GBankManager/UI/MainFrame.lua
local ns = dofile("GBankManager/Bootstrap.lua")

local mainFrame = CreateFrame("Frame", "GBankManagerFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(900, 560)
mainFrame:SetPoint("CENTER")
mainFrame.views = {
    DASHBOARD = dofile("GBankManager/UI/DashboardView.lua"),
    INVENTORY = dofile("GBankManager/UI/InventoryView.lua"),
    MINIMUMS = dofile("GBankManager/UI/MinimumsView.lua"),
    TARGETS = dofile("GBankManager/UI/TargetsView.lua"),
    REQUESTS = dofile("GBankManager/UI/RequestsView.lua"),
    HISTORY = dofile("GBankManager/UI/HistoryView.lua"),
    EXPORTS = dofile("GBankManager/UI/ExportsView.lua"),
}

function mainFrame:SelectView(name)
    self.activeView = name
    self:Show()
end

ns.modules.mainFrame = mainFrame
return mainFrame
```

```toc
UI/MainFrame.lua
UI/DashboardView.lua
UI/InventoryView.lua
UI/MinimumsView.lua
UI/TargetsView.lua
UI/RequestsView.lua
UI/HistoryView.lua
UI/ExportsView.lua
UI/RequestDialog.lua
```

```md
<!-- docs/manual-test-checklist.md -->
10. Add a recurring minimum and confirm it persists after `/reload`.
11. Add a one-time purchase target and confirm it appears in the dashboard demand summary.
12. Submit a member request by item name and verify it starts as pending.
13. Submit an officer request and verify it is auto-approved.
14. Verify members can only see their own request rows.
```

- [ ] **Step 4: Validate member and officer request flows in-game**

Run:

```powershell
Copy-Item -Recurse -Force .\GBankManager "C:\Gaming\World of Warcraft\_retail_\Interface\AddOns\GBankManager"
```

Expected: addon folder updates without copy errors

Then in game:

- `/reload`
- `/gbm ui`

Expected: minimums, targets, and requests views open from the main frame

- [ ] **Step 5: Commit the planning management UI**

```powershell
git add GBankManager/UI GBankManager/GBankManager.toc docs/manual-test-checklist.md
git commit -m "feat: add stock policy and request management views"
```

### Task 7: Implement sync, import/export recovery, and authoritative merge rules

**Files:**
- Create: `GBankManager/Sync/Codec.lua`
- Create: `GBankManager/Sync/Transport.lua`
- Create: `GBankManager/Sync/Coordinator.lua`
- Modify: `GBankManager/Core/Events.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Write a failing test for authority-first record merge**

```lua
-- tests/spec/requests_spec.lua
local assert = require("tests.helpers.assert")
local coordinator = dofile("GBankManager/Sync/Coordinator.lua")

local resolved = coordinator.ResolveConflict(
    { role = "MEMBER", updatedAt = 100, approval = "PENDING" },
    { role = "OFFICER", updatedAt = 90, approval = "APPROVED" }
)

assert.equal("APPROVED", resolved.approval, "officer authority should beat newer member record")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: FAIL with `cannot open GBankManager/Sync/Coordinator.lua`

- [ ] **Step 3: Implement codec, transport, and conflict resolution**

```lua
-- GBankManager/Sync/Codec.lua
local codec = {}

function codec.EncodeTable(message)
    return message.type .. "|" .. tostring(message.updatedAt or 0) .. "|" .. (message.payload or "")
end

function codec.DecodeTable(text)
    local msgType, updatedAt, payload = string.match(text, "([^|]+)|([^|]+)|(.+)")
    return {
        type = msgType,
        updatedAt = tonumber(updatedAt),
        payload = payload,
    }
end

return codec
```

```lua
-- GBankManager/Sync/Coordinator.lua
local coordinator = {}

local rank = {
    MEMBER = 1,
    OFFICER = 2,
    GUILDMASTER = 3,
}

function coordinator.ResolveConflict(localRecord, remoteRecord)
    local localRank = rank[localRecord.role] or 0
    local remoteRank = rank[remoteRecord.role] or 0

    if remoteRank > localRank then
        return remoteRecord
    end

    if remoteRank < localRank then
        return localRecord
    end

    if (remoteRecord.updatedAt or 0) > (localRecord.updatedAt or 0) then
        return remoteRecord
    end

    return localRecord
end

return coordinator
```

```lua
-- GBankManager/Sync/Transport.lua
local codec = dofile("GBankManager/Sync/Codec.lua")

local transport = {}

function transport.Send(channel, distribution, message)
    local payload = codec.EncodeTable(message)
    C_ChatInfo.SendAddonMessage("GBankManager", payload, distribution, channel)
end

return transport
```

- [ ] **Step 4: Wire sync to login/guild events and manual recovery export**

```lua
-- GBankManager/Core/Events.lua
local ns = dofile("GBankManager/Bootstrap.lua")
local transport = dofile("GBankManager/Sync/Transport.lua")

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix("GBankManager")
        transport.Send("GUILD", "GUILD", {
            type = "SYNC_HELLO",
            updatedAt = time(),
            payload = UnitName("player"),
        })
    elseif event == "CHAT_MSG_ADDON" then
        -- decode and merge records here in implementation
    end
end)

ns.modules.events = frame
return frame
```

```toc
Sync/Codec.lua
Sync/Transport.lua
Sync/Coordinator.lua
Core/Events.lua
```

```md
<!-- docs/manual-test-checklist.md -->
15. Log in on two addon-enabled guild characters and confirm a sync hello is sent.
16. Approve a request on one character and confirm the approval appears on the other.
17. Create conflicting request states and confirm officer approval wins over member pending state.
18. Export data manually, clear SavedVariables, re-import, and confirm records are restored.
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

- [ ] **Step 6: Commit sync and recovery support**

```powershell
git add GBankManager/Sync GBankManager/Core/Events.lua GBankManager/GBankManager.toc tests docs/manual-test-checklist.md
git commit -m "feat: add guild sync and recovery workflows"
```

### Task 8: Finish integration, polish exports, and prepare the first playable release

**Files:**
- Modify: `GBankManager/Features/GuildBankScanner.lua`
- Modify: `GBankManager/Domain/Exports.lua`
- Modify: `GBankManager/UI/ExportDialog.lua`
- Modify: `GBankManager/UI/DashboardView.lua`
- Modify: `README.md`
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Finish the scan queue against live guild bank APIs**

```lua
-- GBankManager/Features/GuildBankScanner.lua
function scanner.QueueAccessibleTabs()
    wipe(scanner.tabsToScan)
    for tabIndex = 1, GetNumGuildBankTabs() do
        local _, _, isViewable = GetGuildBankTabInfo(tabIndex)
        if isViewable then
            table.insert(scanner.tabsToScan, tabIndex)
        end
    end
end

function scanner.ReadCurrentTab(tabIndex)
    local tabName = GetGuildBankTabInfo(tabIndex) or ("Tab " .. tabIndex)
    local tabData = { index = tabIndex, name = tabName, slots = {} }

    for slot = 1, 98 do
        local _, count = GetGuildBankItemInfo(tabIndex, slot)
        if count and count > 0 then
            local link = GetGuildBankItemLink(tabIndex, slot)
            local itemID = tonumber(string.match(link or "", "item:(%d+)"))
            if itemID then
                table.insert(tabData.slots, {
                    itemID = itemID,
                    name = C_Item.GetItemNameByID(itemID) or ("Item:" .. itemID),
                    count = count,
                })
            end
        end
    end

    table.insert(scanner.rawTabs, tabData)
end
```

- [ ] **Step 2: Finish export presets for Auctionator, spreadsheet, and custom templates**

```lua
-- GBankManager/Domain/Exports.lua
function exports.MaterializePlanRows(plan)
    local rows = {}
    for _, row in pairs(plan) do
        local reasonParts = {}
        for reason, quantity in pairs(row.sources) do
            if quantity > 0 then
                table.insert(reasonParts, string.format("%s:%d", reason, quantity))
            end
        end
        table.sort(reasonParts)
        table.insert(rows, {
            itemID = row.itemID,
            itemName = row.itemName,
            totalToBuy = row.totalToBuy,
            reason = table.concat(reasonParts, "|"),
        })
    end
    table.sort(rows, function(a, b) return a.itemName < b.itemName end)
    return rows
end
```

- [ ] **Step 3: Run the full local test suite and the manual checklist**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`

Run:

```powershell
Get-Content .\docs\manual-test-checklist.md
```

Expected: checklist contains scan, UI, request, sync, and export validation steps

Then in game:

- `/reload`
- `/gbm scan`
- `/gbm ui`

Expected: scan completes, dashboard updates, and export text is available

- [ ] **Step 4: Update documentation for setup and first release usage**

```md
<!-- README.md -->
# GBankManager

## Features

- One-button guild bank scanning
- Searchable inventory and scan history
- Recurring minimum stock rules
- One-time purchase targets
- Approval-based member requests
- Auctionator and spreadsheet exports
- Guild sync with manual recovery options

## Install

1. Copy `GBankManager` into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Place a Lua runner at `tools/lua/lua.exe` for local tests.
3. Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
4. Launch WoW and run `/reload`.
```

- [ ] **Step 5: Commit the release-ready v1 foundation**

```powershell
git add GBankManager README.md docs tests
git commit -m "feat: complete v1 guild bank manager foundation"
```

## Spec Coverage Check

- Bank scanning and current inventory are covered by Tasks 3 and 8.
- Searchable inventory and dated history are covered by Tasks 3 and 5.
- Recurring minimums and one-time purchase targets are covered by Tasks 4 and 6.
- Requests, approvals, and suggested fulfillment are covered by Tasks 4 and 6.
- Auctionator, spreadsheet, and custom-delimited exports are covered by Tasks 4, 5, and 8.
- Guild sync, authority rules, and recovery import/export are covered by Task 7.
- Dashboard-first officer UX and restricted member UX are covered by Tasks 5 and 6.

## Placeholder Scan

- No `TODO`, `TBD`, or deferred implementation markers should remain in execution commits.
- If a worker changes any module names, they must update test imports in the same task before moving on.

## Type Consistency Check

- Demand-source names are `RESTOCK`, `ONE_TIME_TARGET`, and `REQUEST`.
- Request approval states are `PENDING` and `APPROVED`.
- Fulfillment states start as `OPEN` and may become `SUGGESTED_FULFILLED`.
- Role strings are `MEMBER`, `OFFICER`, and `GUILDMASTER`.

Plan complete and saved to `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

---

## Current Delta 2026-05-12

The original task breakdown above is now partially stale. Current product direction and worker scope should follow this delta instead of re-introducing removed features.

### Scope Corrections

- `Targets` has been removed from the shell and should not be restored.
- Officer-facing `History` is procurement audit history only.
- `Spreadsheet` is now `CSV` in the officer-facing export UX.
- `About` is now a real shell tab.
- `Minimums` now uses direct in-table drafts with row-level undo and explicit remove actions.

### Current Verified Baseline

- Branch: `codex/gbankmanager-v1`
- Latest implementation commit: `186f353`
- Prior export workflow completion commit: `b879872`
- Verified command:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```

### Current Delta Status

The export workflow completion work and the first Minimums follow-up pass are now done.

Completed in `b879872` and `186f353`:

- export modal copy flow
- `Spreadsheet` to `CSV` rename
- Auctionator shopping-list name input
- screenshot-driven Auctionator output format
- Minimums search labeling and control-frame layout cleanup
- icon-based remove / undo controls
- saved-row `Bank Tab` lock
- staged-row `Bank Tab` dropdown
- hidden ghosted inline cell text
- improved add-modal labels and alignment
- hidden `Restock Source` column in Minimums for now

### Next Worker Focus: Live-Client Minimums QA

Use this section as the active checklist for the next session instead of reopening the completed export work.

**Files most likely:**

- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `tests/spec/ui_spec.lua`
- Modify: `docs/manual-test-checklist.md` if new QA steps are needed

- [ ] **Task A: Re-verify draft highlighting in live client**

Requirements:

- Confirm changed rows are visibly distinct in the live WoW client
- Confirm deleted rows are visibly distinct in the live WoW client
- Confirm added rows are visibly distinct in the live WoW client
- If the new draft-indicator layer is still too subtle, strengthen it without destabilizing row layout

- [ ] **Task B: Re-verify inline edit alignment**

Requirements:

- Confirm inline `Restock` and `Minimum` edit boxes remain aligned with the original text baseline at WoW scale
- If they still look vertically low, tighten offsets rather than reintroducing underlying static text

- [ ] **Task C: Re-verify staged-row Bank Tab usability**

Requirements:

- Confirm the staged-row `Bank Tab` dropdown is readable and obvious in live client
- Improve width, contrast, label, or placement if officers still have trouble seeing it

- [ ] **Task D: Re-test non-bank add-item search behavior**

Requirements:

- Confirm the remembered-item catalog approach covers the real user workflow
- If it does not, document the gap clearly before attempting a broader item discovery approach

- [ ] **Task E: Keep guardrails intact**

Requirements:

- Do not reintroduce `Targets`
- Keep `History` procurement-audit-only
- Keep exports grounded in planning data
- Use TDD for any follow-up changes
- Rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion

### Worker Guardrails

- Do not reintroduce `Targets`
- Do not expand History back into raw inventory diff UI
- Keep export generation grounded in the planning model
- Prefer small, verifiable UI changes with test coverage before live-client polish

---

## Current Delta 2026-05-13

The structural refactor is now complete through Phase 5. Treat the original task list in this document as historical implementation context, not the authoritative current module map.

### Current Root And Branch

- Root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager`
- Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`

### Current Refactored Shape

- `Core/`
  - thin bootstrap, slash commands, and event registration
- `Data/`
  - defaults, migrations, and normalized store access
- `Domain/`
  - snapshots, diff, planning, exports, requests, permissions
- `Features/`
  - guild-bank scan workflow and feature-owned event adapters
- `UI/`
  - `MainFrameShell.lua`
  - `MainTableController.lua`
  - `MainRequestsController.lua`
  - `MainExportsController.lua`
  - `MainMinimumsController.lua`
  - `MainFrame.lua`
  - view helpers for dashboard, inventory, requests, history, exports, and minimums

### Current Product Truth

- `Targets` is removed from the shell and must not be restored
- `History` stays procurement-audit-only
- `Spreadsheet` has been renamed to `CSV`
- Minimums uses direct draft rows with row-level undo and explicit remove actions
- Exports remain outputs of the planning model, not an independent source of truth

### Deferred Work

- Offline/global item discovery for Minimums add-item search remains deferred
- Do not treat Auction House lookup as a required dependency for normal addon use
- If this work resumes, prefer an explicit self-owned item index design over fragile reads from other addons

### Latest Verified Baseline

- Refactor phase-5 code commit: `551ffb0`
- Refactor phase-5 docs commit: `034d290`
- Verified command:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```
