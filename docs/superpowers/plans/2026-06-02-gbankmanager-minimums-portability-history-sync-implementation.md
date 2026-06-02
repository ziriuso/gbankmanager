# GBankManager Minimums Portability And History Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add portable Minimums export/import with a review-first UI, and keep the History tab coherent across clients by reconstructing equivalent local Minimums history rows from accepted sync snapshots.

**Architecture:** Add a dedicated portable Minimums codec helper for versioned JSON export, import parsing, and review-row staging. Wire the Minimums controller to preview imported rows, require local tab reassignment when needed, and only apply reviewed rows into the existing Minimums draft workflow. Extend accepted `MINIMUMS_SNAPSHOT` sync handling to diff prior vs next Minimums state and append the same `MINIMUM_*` audit rows the History tab already understands.

**Tech Stack:** Lua addon modules, existing WoW-style UI controller/view modules, local Lua test runners, addon sync transport in `SyncEvents.lua`

---

### Task 1: Portable Minimums Codec

**Files:**
- Create: `GBankManager/Domain/MinimumsPortability.lua`
- Test: `tests/spec/minimums_portability_spec.lua`

- [ ] **Step 1: Write the failing export and parse tests**

Add tests that prove:

```lua
local portability = dofile("GBankManager/Domain/MinimumsPortability.lua")

local payload = portability.Export({
    guildName = "Guild Testers",
    minimums = {
        {
            itemID = 2001,
            itemName = "Potion Alpha",
            scope = "TAB",
            tabName = "Alchemy",
            quantity = 25,
            enabled = true,
            craftedQuality = 2,
            craftedQualityIcon = "Professions-Icon-Quality-12-Tier2-Inv",
        },
    },
})

assert.truthy(string.find(payload, "\"schema\":\"gbankmanager.minimums\"", 1, true) ~= nil)
assert.truthy(string.find(payload, "\"tabName\":\"Alchemy\"", 1, true) ~= nil)

local parsed = portability.Parse(payload, { "Alchemy", "Cooking" })
assert.equal("ready", parsed.rows[1].status)
assert.equal("Alchemy", parsed.rows[1].resolvedTabName)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\minimums_portability_spec.lua`

Expected: FAIL because `GBankManager/Domain/MinimumsPortability.lua` does not exist yet.

- [ ] **Step 3: Write minimal portability helper**

Implement:

```lua
local portability = {}

function portability.Export(context)
    -- build versioned JSON string from stable Minimums fields only
end

function portability.Parse(payloadText, availableTabs)
    -- decode JSON, validate schema, and build review rows with status values
end

return portability
```

Include row statuses:

- `ready`
- `needs_tab`
- `invalid`
- `duplicate_candidate`

- [ ] **Step 4: Run test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\minimums_portability_spec.lua`

Expected: PASS

- [ ] **Step 5: Extend tests for missing tabs and malformed payloads**

Add tests that prove:

```lua
local parsedMissingTab = portability.Parse(validPayload, { "Cooking" })
assert.equal("needs_tab", parsedMissingTab.rows[1].status)

local parsedBadSchema = portability.Parse("{\"schema\":\"wrong\"}", { "Alchemy" })
assert.equal(false, parsedBadSchema.ok)
```

- [ ] **Step 6: Run test to verify new failures**

Run: `.\tools\lua\lua.exe .\tests\spec\minimums_portability_spec.lua`

Expected: FAIL on missing validation behavior.

- [ ] **Step 7: Implement validation behavior**

Handle:

- missing or wrong schema/version
- malformed JSON
- missing required row fields
- `TAB` rows whose `tabName` is not locally available

- [ ] **Step 8: Run test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\minimums_portability_spec.lua`

Expected: PASS

### Task 2: Minimums Import Review UI

**Files:**
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing review-stage UI tests**

Add tests that prove:

```lua
mainFrame:PreviewImportedMinimums(validPayload)

assert.equal(1, #(mainFrame.minimumImportReviewRows or {}))
assert.equal("needs_tab", mainFrame.minimumImportReviewRows[1].status)

mainFrame:SetImportedMinimumRowTab(1, "Alchemy")
assert.equal("Alchemy", mainFrame.minimumImportReviewRows[1].resolvedTabName)
assert.equal("ready", mainFrame.minimumImportReviewRows[1].status)
```

Also add a test that `Apply Import` stages rows into the existing pending draft state instead of directly mutating `db.minimums`.

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: FAIL because import-review methods and state do not exist yet.

- [ ] **Step 3: Add review modal state and preview wiring**

Implement controller state for:

- raw import text
- parsed review rows
- selected imported row
- import validation status

Add controller methods:

```lua
function mainFrame:PreviewImportedMinimums(payloadText)
function mainFrame:SetImportedMinimumRowTab(rowIndex, tabName)
function mainFrame:SetImportedMinimumRowQuantity(rowIndex, quantity)
function mainFrame:SetImportedMinimumRowEnabled(rowIndex, enabled)
function mainFrame:RemoveImportedMinimumRow(rowIndex)
function mainFrame:ApplyReviewedImportedMinimums()
```

- [ ] **Step 4: Reuse existing Minimums draft workflow for apply**

Applying review rows must populate:

- `self.minimumPendingRules`
- `self.minimumPendingDirty`
- `self.minimumPendingDeleted`

without writing directly to `db.minimums`.

- [ ] **Step 5: Run UI test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: PASS

- [ ] **Step 6: Add export action coverage**

Add a focused test that export action produces a non-empty portable payload from current Minimums rows.

- [ ] **Step 7: Run UI test to verify export behavior fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: FAIL on missing export action or payload generation.

- [ ] **Step 8: Implement export action**

Wire the Minimums export action through the portability helper and existing modal pattern so it exposes the versioned JSON payload in a copyable surface.

- [ ] **Step 9: Run UI test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: PASS

### Task 3: Minimums Import Save Path

**Files:**
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing save-path audit test**

Add a test that:

```lua
mainFrame:PreviewImportedMinimums(validPayload)
mainFrame:SetImportedMinimumRowTab(1, "Alchemy")
mainFrame:ApplyReviewedImportedMinimums()
mainFrame:SaveAllMinimumChanges()

assert.equal("MINIMUM_CREATED", db.auditLog[#db.auditLog].type)
assert.equal("Potion Alpha", db.auditLog[#db.auditLog].itemName)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: FAIL because the imported rows are not yet flowing cleanly through the existing save path.

- [ ] **Step 3: Align imported draft rows with existing identity rules**

Ensure imported rows stage using the same identity fields as manually added rows:

- `itemID`
- `scope`
- `tabName`

and preserve crafted-quality identity fields used by Minimums.

- [ ] **Step 4: Run test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: PASS

### Task 4: Reconstructed Minimums History From Accepted Sync

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `tests/spec/sync_spec.lua`
- Possibly modify: `tests/spec/history_spec.lua`
- Test: `tests/spec/sync_spec.lua`

- [ ] **Step 1: Write the failing accepted-snapshot history test**

Add a sync test that accepts a remote `MINIMUMS_SNAPSHOT` and proves:

```lua
assert.equal("MINIMUM_CREATED", db.auditLog[#db.auditLog].type)
assert.equal("Potion Alpha", db.auditLog[#db.auditLog].itemName)
assert.equal("OfficerOne", db.auditLog[#db.auditLog].actor)
```

Add another test for a replayed or no-change snapshot:

```lua
local beforeCount = #(db.auditLog or {})
local accepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", encodedPayload, "GUILD", "OfficerOne-Stormrage")
assert.truthy(accepted)
assert.equal(beforeCount, #(db.auditLog or {}))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`

Expected: FAIL because accepted remote Minimums snapshots currently replace `db.minimums` without reconstructing equivalent history rows.

- [ ] **Step 3: Add Minimums snapshot diff helper**

Implement a local helper in `SyncEvents.lua` that:

- clones prior `db.minimums`
- clones incoming `minimums`
- compares by stable rule key
- appends only the existing `MINIMUM_*` event types the History tab already knows

- [ ] **Step 4: Keep sync scope narrow**

Do not add:

- raw history transport
- ledger snapshot audit rows
- sync-envelope audit rows

Only reconstruct the current `MINIMUM_*` audit rows from accepted state changes.

- [ ] **Step 5: Run sync test to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`

Expected: PASS

### Task 5: Focused Verification And Docs

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Test: `tests/spec/minimums_portability_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/sync_spec.lua`

- [ ] **Step 1: Run focused feature tests**

Run:

```bash
.\tools\lua\lua.exe .\tests\spec\minimums_portability_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected: PASS for all focused feature specs.

- [ ] **Step 2: Update user-facing docs**

Document:

- Minimums export action
- review-first import flow
- required tab reassignment for missing imported tabs
- History-tab convergence from accepted remote Minimums changes

- [ ] **Step 3: Run full suite**

Run: `.\tools\lua\lua.exe .\tests\run_all.lua`

Expected:

- either PASS, or
- only the pre-existing unrelated baseline failure remains, which must be reported explicitly if it still occurs

- [ ] **Step 4: Review git diff**

Run:

```bash
git status -sb
git diff -- docs/superpowers/specs/2026-06-02-gbankmanager-minimums-portability-history-sync-design.md
git diff -- README.md docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md GBankManager/Domain/MinimumsPortability.lua GBankManager/UI/MainMinimumsController.lua GBankManager/Sync/SyncEvents.lua tests/spec/minimums_portability_spec.lua tests/spec/ui_minimums_spec.lua tests/spec/sync_spec.lua
```

Expected: only intended Minimums portability, import review, History reconstruction, and documentation changes.
