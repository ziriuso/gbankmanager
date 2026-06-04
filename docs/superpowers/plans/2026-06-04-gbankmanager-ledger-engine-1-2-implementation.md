# GBankManager Ledger Engine 1.2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Bank Ledger scan, dedupe, and ledger-sync internals with a clean 1.2.0 full-batch ledger engine while preserving the existing GBankManager UI.

**Architecture:** Introduce a hard 1.2.0 ledger protocol/reset boundary, durable count-based ledger identity, time-bucket hashes, manifest-first sync, and bucket request/reply row transfer. Keep the existing Bank Ledger UI and scanner entry points, but move ledger-specific coordination and sync payload building into focused modules so remote merges never echo outbound sync.

**Tech Stack:** WoW Retail Lua addon, AceSerializer/AceComm transport already bundled in `GBankManager/Libs`, SavedVariables via `GBankManagerDB`, local Lua specs under `tests/spec/*.lua`, baseline verification with `.\tools\lua\lua.exe .\tests\run_all.lua`

---

## Coordination Rules

- Do not mention private research sources in commit messages, branch names, release notes, or public-facing docs.
- Treat `.vscode/` as unrelated local noise.
- Do not revert or overwrite existing unstaged changes unless the task explicitly owns that file and has read the current diff first.
- Use `apply_patch` for manual edits.
- Follow TDD: write or update the focused test, run it to see the expected failure, implement, rerun the focused test, then run a broader lane when the task touches shared contracts.
- Every task should leave the worktree in a commit-ready state. Commit messages should use neutral wording such as `feat: add ledger protocol reset boundary`.

---

## File Structure

- `GBankManager/GBankManager.toc`
  - Version metadata and load order for any new ledger modules.
- `GBankManager/Core/Constants.lua`
  - `ADDON_VERSION`, `LEDGER_FORCE_CLEAR_VERSION`, and new `LEDGER_PROTOCOL_VERSION`.
- `GBankManager/Data/Store.lua`
  - One-time 1.2.0 ledger reset and clear-data behavior.
- `GBankManager/Domain/BankLedger.lua`
  - Existing public Bank Ledger API; keep UI-facing functions here while extracting focused helpers only when the task needs it.
- `GBankManager/Domain/LedgerIdentity.lua`
  - New durable transaction identity, base-key grouping, occurrence ids, adjacent-hour drift helpers.
- `GBankManager/Domain/LedgerManifest.lua`
  - New global hash, 6-hour bucket hashes, manifest comparison, bucket row selection, protocol metadata.
- `GBankManager/Features/GuildBankScanner.lua`
  - Keep existing inventory scan ownership; route ledger scans through the full-batch ledger scan coordinator and publish manifests after native local writes.
- `GBankManager/Features/LedgerScanner.lua`
  - New focused ledger log target planning, `QueryGuildBankLog`, debounce/fallback finalization, raw transaction reads, and scan diagnostics.
- `GBankManager/Sync/ManualActions.lua`
  - Manual `ledger` action publishes manifest instead of eager row deltas.
- `GBankManager/Sync/SyncEvents.lua`
  - New `LEDGER_MANIFEST`, `LEDGER_BUCKET_REQUEST`, and `LEDGER_BUCKET_REPLY` handlers plus protocol gating.
- `GBankManager/Sync/Transport.lua`
  - Reuse existing chunking; only change if application-level bucket reply identifiers are needed.
- `GBankManager/Core/SlashCommands.lua`
  - Extend `/gbm debug ledger` and `/gbm debug sync` output if those commands are wired here.
- `tests/spec/store_spec.lua`
  - 1.2.0 reset and clear-data coverage.
- `tests/spec/toc_spec.lua`, `tests/spec/ui_about_spec.lua`
  - Version assertions.
- `tests/spec/bank_ledger_spec.lua`
  - Identity, durable count, bucket hash, bucket selection, and remote merge contracts.
- `tests/spec/bank_ledger_scanner_spec.lua`
  - Full-batch scanner, diagnostics, and manifest-only publish after local writes.
- `tests/spec/sync_ledger_manifest_spec.lua`
  - New focused manifest/bucket sync spec; replace or retire digest-only expectations.
- `tests/spec/sync_spec.lua`
  - Integration-level protocol rejection, self-origin, chat noise, and bucket reply merge coverage.
- `tests/spec/sync_manual_actions_spec.lua`
  - Manual sync cooldown/action behavior with manifest-first ledger sync.
- `tests/spec/slash_commands_spec.lua`
  - Debug output additions.
- `README.md`, `docs/testing.md`, `docs/manual-test-checklist.md`, `docs/curseforge-release-workflow.md`, `docs/superpowers/handoffs/latest-handoff.md`
  - Updated 1.2.0 protocol/reset, bucket sync, verification, and release notes.

---

### Task 0: Commit the current verified sync-noise baseline

**Files:**
- Stage existing modified files only after inspecting the current diff:
  - `GBankManager/Sync/SyncEvents.lua`
  - `README.md`
  - `docs/manual-test-checklist.md`
  - `docs/superpowers/handoffs/latest-handoff.md`
  - `docs/testing.md`
  - `tests/spec/bank_ledger_scanner_spec.lua`
  - `tests/spec/sync_spec.lua`
- Do not stage: `.vscode/`

- [ ] **Step 1: Verify the existing local changes are the sync-noise baseline**

Run:

```powershell
git status -sb
git diff -- GBankManager/Sync/SyncEvents.lua tests/spec/sync_spec.lua tests/spec/bank_ledger_scanner_spec.lua README.md docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
```

Expected: only the prior presence-only hello, quiet ledger no-change/reject chat, related tests, and docs are modified.

- [ ] **Step 2: Run the baseline focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_ledger_digest_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: all commands exit `0`.

- [ ] **Step 3: Stage only the verified baseline files**

Run:

```powershell
git add GBankManager/Sync/SyncEvents.lua README.md docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md tests/spec/bank_ledger_scanner_spec.lua tests/spec/sync_spec.lua
git diff --cached --name-only
```

Expected staged names are exactly the seven files listed above.

- [ ] **Step 4: Commit the baseline**

Run:

```powershell
git commit -m "fix: quiet ledger sync no-change chatter"
```

Expected: commit succeeds and does not mention private research sources.

---

### Task 1: Add the 1.2.0 protocol and reset boundary

**Files:**
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Core/Constants.lua`
- Modify: `GBankManager/Data/Store.lua`
- Modify: `tests/spec/toc_spec.lua`
- Modify: `tests/spec/ui_about_spec.lua`
- Modify: `tests/spec/store_spec.lua`

- [ ] **Step 1: Write failing reset and version tests**

In `tests/spec/store_spec.lua`, extend the existing versioned ledger clear test so the seeded database includes old ledger sync state:

```lua
local db = store.GetDatabase()
db.bankLedger.itemLogs = { { entryId = "old-item-1", itemID = 123, quantity = 1 } }
db.bankLedger.moneyLogs = { { entryId = "old-money-1", amountCopper = 100 } }
db.syncState = {
    peers = {
        ["Guild Testers"] = {
            ["MemberOne-Stormrage"] = { lastSeen = 10 },
        },
    },
    ledgerDigest = { hash = "old-hash" },
    ledgerPeerDigests = { ["MemberOne-Stormrage"] = { hash = "old-peer-hash" } },
    ledgerBucketManifests = { ["MemberOne-Stormrage"] = { globalHash = "old-global" } },
    ledgerPendingBucketRequests = { ["request-1"] = true },
}
db.meta.ledgerClearedForVersion = nil

local reloaded = store.NormalizeDatabase(db, "Guild Testers")

assert.equal("1.2.0", tostring(reloaded.meta.ledgerClearedForVersion or ""), "1.2.0 should stamp the ledger reset marker")
assert.equal(0, #(reloaded.bankLedger.itemLogs or {}), "1.2.0 reset should clear old item ledger rows")
assert.equal(0, #(reloaded.bankLedger.moneyLogs or {}), "1.2.0 reset should clear old money ledger rows")
assert.truthy(((reloaded.syncState or {}).peers or {})["Guild Testers"], "general sync peers should survive the ledger reset")
assert.equal(nil, ((reloaded.syncState or {}).ledgerDigest), "ledger digest sync state should reset")
assert.equal(nil, ((reloaded.syncState or {}).ledgerPeerDigests), "peer ledger digest sync state should reset")
assert.equal(nil, ((reloaded.syncState or {}).ledgerBucketManifests), "ledger bucket manifest state should reset")
assert.equal(nil, ((reloaded.syncState or {}).ledgerPendingBucketRequests), "ledger bucket request state should reset")
```

Also update version assertions in `tests/spec/toc_spec.lua` and `tests/spec/ui_about_spec.lua` to expect `1.2.0` and `v1.2.0`.

- [ ] **Step 2: Run tests and verify the expected failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\spec\toc_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_about_spec.lua
```

Expected before implementation: failures showing old version `1.1.2`, old clear marker `1.1.1`, and stale ledger sync metadata still present.

- [ ] **Step 3: Implement constants and reset helper**

In `GBankManager/Core/Constants.lua`, update constants:

```lua
ns.constants.ADDON_VERSION = ns.constants.ADDON_VERSION or addon_metadata("Version") or "1.2.0"
ns.constants.LEDGER_FORCE_CLEAR_VERSION = ns.constants.LEDGER_FORCE_CLEAR_VERSION or "1.2.0"
ns.constants.LEDGER_PROTOCOL_VERSION = ns.constants.LEDGER_PROTOCOL_VERSION or 2
```

In `GBankManager/GBankManager.toc`, update:

```text
## Version: 1.2.0
## X-Release-Tag: v1.2.0
```

In `GBankManager/Data/Store.lua`, add a focused helper near `apply_versioned_ledger_reset_to_database`:

```lua
local function clear_ledger_sync_state(db)
    db.syncState = type(db.syncState) == "table" and db.syncState or {}
    db.syncState.ledgerDigest = nil
    db.syncState.ledgerPeerDigests = nil
    db.syncState.ledgerBucketManifests = nil
    db.syncState.ledgerPendingBucketRequests = nil
    db.syncState.ledgerLastManifest = nil
    db.syncState.ledgerLastBucketRequest = nil
    db.syncState.ledgerLastBucketReply = nil
end
```

Call it immediately after `db.bankLedger = fresh_bank_ledger(...)`:

```lua
db.bankLedger = fresh_bank_ledger(db.meta.guildName or "Unknown")
clear_ledger_sync_state(db)
db.meta.ledgerClearedForVersion = resetVersion
```

- [ ] **Step 4: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\spec\toc_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_about_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

Run:

```powershell
git add GBankManager/GBankManager.toc GBankManager/Core/Constants.lua GBankManager/Data/Store.lua tests/spec/store_spec.lua tests/spec/toc_spec.lua tests/spec/ui_about_spec.lua
git commit -m "feat: add ledger protocol reset boundary"
```

---

### Task 2: Add durable ledger identity and count metadata

**Files:**
- Create: `GBankManager/Domain/LedgerIdentity.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Domain/BankLedger.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`

- [ ] **Step 1: Write failing identity/count tests**

In `tests/spec/bank_ledger_spec.lua`, add a case that simulates a fresh Lua session by clearing any in-memory batch state and relying on persisted count metadata:

```lua
local payload = {
    kind = "item",
    sourceTabIndex = 2,
    sourceTabName = "Extra Stuff",
    scanStartedAt = 1718300000,
    transactions = {
        { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 },
        { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 },
    },
}

local firstMerge = bankLedger.MergeItemTransactions(db, payload)
assert.equal(2, firstMerge, "first full batch should append both same-hour occurrences")

local ledger = bankLedger.EnsureState(db)
ledger.sessionBatchCounts = nil
local replayMerge = bankLedger.MergeItemTransactions(db, payload)
assert.equal(0, replayMerge, "persisted event counts should prevent reload-time duplicate appends")

payload.transactions[#payload.transactions + 1] = { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, year = 0, month = 0, day = 0, hour = 16 }
local laterMerge = bankLedger.MergeItemTransactions(db, payload)
assert.equal(1, laterMerge, "one extra visible occurrence should append exactly one row")
```

Add the same shape for money transactions using same actor, same amount, same hour.

- [ ] **Step 2: Run the spec and verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected before implementation: reload simulation appends duplicate rows or lacks persisted count metadata.

- [ ] **Step 3: Create `LedgerIdentity.lua`**

Create a module with these public functions:

```lua
local _, ns = ...
ns = ns or {}
ns.modules = ns.modules or {}

local identity = {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function stable_join(parts)
    local out = {}
    for index, value in ipairs(parts or {}) do
        out[index] = trim(value):gsub("|", "/")
    end
    return table.concat(out, "|")
end

function identity.HourSlotFromTimestamp(timestamp)
    return math.floor((tonumber(timestamp or 0) or 0) / 3600)
end

function identity.ItemBase(row)
    return stable_join({
        "item",
        row.action or row.type,
        row.who,
        tonumber(row.itemID or 0) or 0,
        tonumber(row.quantity or row.count or 0) or 0,
        row.tabName or row.sourceTabName or ("Tab " .. tostring(row.tabIndex or row.sourceTabIndex or 0)),
        row.fromTabName or "-",
        identity.HourSlotFromTimestamp(row.timestamp or row.when),
    })
end

function identity.MoneyBase(row)
    return stable_join({
        "money",
        row.action or row.type,
        row.who,
        tonumber(row.amountCopper or row.amount or 0) or 0,
        identity.HourSlotFromTimestamp(row.timestamp or row.when),
    })
end

function identity.WithOccurrence(base, occurrence)
    return tostring(base or "") .. ":" .. tostring(tonumber(occurrence or 0) or 0)
end

function identity.CountRowsByBase(rows, baseBuilder)
    local counts = {}
    local groups = {}
    local order = {}
    for _, row in ipairs(rows or {}) do
        local base = tostring(baseBuilder(row) or "")
        if base ~= "" then
            if counts[base] == nil then
                counts[base] = 0
                groups[base] = {}
                order[#order + 1] = base
            end
            counts[base] = counts[base] + 1
            groups[base][#groups[base] + 1] = row
        end
    end
    return counts, groups, order
end

ns.modules.ledgerIdentity = identity
return identity
```

Load it before `Domain/BankLedger.lua` in `GBankManager/GBankManager.toc`.

- [ ] **Step 4: Persist count metadata in `BankLedger.lua`**

Extend `bankLedger.EnsureState(db)` so the ledger has durable count tables:

```lua
db.bankLedger.eventCounts = ensure_table(db.bankLedger.eventCounts)
db.bankLedger.eventCounts.item = ensure_table(db.bankLedger.eventCounts.item)
db.bankLedger.eventCounts.money = ensure_table(db.bankLedger.eventCounts.money)
```

Update `append_delta_rows` or replace its count logic so it compares the current batch count against `ledger.eventCounts[kind][base].count`. After a merge, store the high-water count:

```lua
local function update_event_counts(ledger, kind, currentCounts, now)
    ledger.eventCounts = ensure_table(ledger.eventCounts)
    ledger.eventCounts[kind] = ensure_table(ledger.eventCounts[kind])
    for base, count in pairs(currentCounts or {}) do
        local entry = ledger.eventCounts[kind][base]
        if type(entry) ~= "table" or (tonumber(count or 0) or 0) > (tonumber(entry.count or 0) or 0) then
            ledger.eventCounts[kind][base] = {
                count = tonumber(count or 0) or 0,
                asOf = tonumber(now or server_timestamp_now()) or server_timestamp_now(),
            }
        end
    end
end
```

When appending rows, assign `entryId` from the stable occurrence id instead of only `next_entry_id` for the new protocol rows.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected: count-based repeated row tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add GBankManager/GBankManager.toc GBankManager/Domain/LedgerIdentity.lua GBankManager/Domain/BankLedger.lua tests/spec/bank_ledger_spec.lua
git commit -m "feat: add durable ledger row identity"
```

---

### Task 3: Add bucket manifest hashing and row selection

**Files:**
- Create: `GBankManager/Domain/LedgerManifest.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Domain/BankLedger.lua`
- Create: `tests/spec/sync_ledger_manifest_spec.lua`
- Modify: `tests/run_unit.lua` if new specs are listed manually

- [ ] **Step 1: Write failing manifest tests**

Create `tests/spec/sync_ledger_manifest_spec.lua` with assertions for global hash, 6-hour buckets, matching comparison, and bucket row selection:

```lua
local manifest = _G.dofile("GBankManager/Domain/LedgerManifest.lua")

local rows = {
    { entryId = "item-a", timestamp = 21600, itemID = 1 },
    { entryId = "item-b", timestamp = 21700, itemID = 2 },
    { entryId = "money-c", timestamp = 43200, amountCopper = 100 },
}

local built = manifest.Build({
    itemLogs = { rows[1], rows[2] },
    moneyLogs = { rows[3] },
}, { ledgerProtocol = 2, version = "1.2.0" })

assert.equal(2, tonumber(built.ledgerProtocol or 0), "manifest should carry ledger protocol")
assert.equal(3, tonumber(built.totalCount or 0), "manifest should count item and money rows")
assert.truthy((built.buckets or {})[1], "first 6-hour bucket should exist")
assert.truthy((built.buckets or {})[2], "second 6-hour bucket should exist")

local diff = manifest.Compare(built, {
    ledgerProtocol = 2,
    buckets = {
        [1] = built.buckets[1],
        [2] = "different",
    },
})
assert.equal(1, #(diff.differentBuckets or {}), "comparison should request only differing buckets")
assert.equal(2, tonumber(diff.differentBuckets[1] or 0), "bucket 2 should be the only differing bucket")
```

- [ ] **Step 2: Run the new spec and verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
```

Expected: fails because `LedgerManifest.lua` does not exist.

- [ ] **Step 3: Implement `LedgerManifest.lua`**

Create a pure helper module:

```lua
local _, ns = ...
ns = ns or {}
ns.modules = ns.modules or {}

local ledgerManifest = {}
local BUCKET_SECONDS = 21600

local function stable_hash(value)
    value = tostring(value or "")
    local hash = 5381
    for index = 1, #value do
        hash = ((hash * 33) + string.byte(value, index)) % 4294967296
    end
    return tostring(hash)
end

local function xor_hash(left, right)
    return tostring(((tonumber(left or 0) or 0) + (tonumber(right or 0) or 0)) % 4294967296)
end

function ledgerManifest.BucketKey(timestamp)
    return math.floor((tonumber(timestamp or 0) or 0) / BUCKET_SECONDS)
end

local function add_row(out, row)
    local id = tostring((row or {}).entryId or (row or {}).fingerprint or "")
    if id == "" then
        return
    end
    local bucketKey = ledgerManifest.BucketKey((row or {}).timestamp or (row or {}).when)
    local token = stable_hash(id)
    out.buckets[bucketKey] = xor_hash(out.buckets[bucketKey], token)
    out.globalHash = xor_hash(out.globalHash, token)
    out.totalCount = out.totalCount + 1
end

function ledgerManifest.Build(ledger, options)
    local out = {
        ledgerProtocol = tonumber((options or {}).ledgerProtocol or ((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0,
        version = tostring((options or {}).version or ((ns.constants or {}).ADDON_VERSION) or ""),
        totalCount = 0,
        globalHash = "0",
        buckets = {},
    }
    for _, row in ipairs((ledger or {}).itemLogs or {}) do
        add_row(out, row)
    end
    for _, row in ipairs((ledger or {}).moneyLogs or {}) do
        add_row(out, row)
    end
    return out
end

function ledgerManifest.Compare(localManifest, remoteManifest)
    local result = { matched = true, differentBuckets = {} }
    local localBuckets = (localManifest or {}).buckets or {}
    local remoteBuckets = (remoteManifest or {}).buckets or {}
    local seen = {}
    for bucket in pairs(localBuckets) do
        seen[bucket] = true
    end
    for bucket in pairs(remoteBuckets) do
        seen[bucket] = true
    end
    for bucket in pairs(seen) do
        if tostring(localBuckets[bucket] or "0") ~= tostring(remoteBuckets[bucket] or "0") then
            result.matched = false
            result.differentBuckets[#result.differentBuckets + 1] = tonumber(bucket) or bucket
        end
    end
    table.sort(result.differentBuckets, function(a, b) return tonumber(a) < tonumber(b) end)
    return result
end

function ledgerManifest.RowsForBuckets(ledger, bucketKeys)
    local wanted = {}
    for _, bucketKey in ipairs(bucketKeys or {}) do
        wanted[tonumber(bucketKey)] = true
    end
    local rows = { item = {}, money = {} }
    for _, row in ipairs((ledger or {}).itemLogs or {}) do
        if wanted[ledgerManifest.BucketKey(row.timestamp or row.when)] then
            rows.item[#rows.item + 1] = row
        end
    end
    for _, row in ipairs((ledger or {}).moneyLogs or {}) do
        if wanted[ledgerManifest.BucketKey(row.timestamp or row.when)] then
            rows.money[#rows.money + 1] = row
        end
    end
    return rows
end

ns.modules.ledgerManifest = ledgerManifest
return ledgerManifest
```

Load it after `Domain/LedgerIdentity.lua` and before `Domain/BankLedger.lua`.

- [ ] **Step 4: Expose manifest helpers from `BankLedger.lua`**

Add thin wrappers:

```lua
function bankLedger.BuildLedgerManifest(db)
    local ledgerManifest = ns.modules.ledgerManifest or {}
    local ledger = bankLedger.EnsureState(db or {})
    return type(ledgerManifest.Build) == "function" and ledgerManifest.Build(ledger) or {}
end

function bankLedger.CompareLedgerManifest(db, remoteManifest)
    local ledgerManifest = ns.modules.ledgerManifest or {}
    local localManifest = bankLedger.BuildLedgerManifest(db)
    return type(ledgerManifest.Compare) == "function" and ledgerManifest.Compare(localManifest, remoteManifest) or { matched = false, differentBuckets = {} }
end

function bankLedger.RowsForLedgerBuckets(db, bucketKeys)
    local ledgerManifest = ns.modules.ledgerManifest or {}
    local ledger = bankLedger.EnsureState(db or {})
    return type(ledgerManifest.RowsForBuckets) == "function" and ledgerManifest.RowsForBuckets(ledger, bucketKeys) or { item = {}, money = {} }
end
```

- [ ] **Step 5: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected: pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add GBankManager/GBankManager.toc GBankManager/Domain/LedgerManifest.lua GBankManager/Domain/BankLedger.lua tests/spec/sync_ledger_manifest_spec.lua tests/run_unit.lua
git commit -m "feat: add ledger bucket manifests"
```

---

### Task 4: Refactor native ledger scanning to full-batch manifest publishing

**Files:**
- Create: `GBankManager/Features/LedgerScanner.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Features/GuildBankScanner.lua`
- Modify: `tests/spec/bank_ledger_scanner_spec.lua`

- [ ] **Step 1: Write failing scanner tests**

In `tests/spec/bank_ledger_scanner_spec.lua`, update the outbound expectation after a native ledger scan:

```lua
assert.equal(1, #(outboundLedgerSyncMessages or {}), "native ledger scan should publish one manifest after local row writes")
local publishedManifest = ((outboundLedgerSyncMessages or {})[1] or {}).message or {}
assert.equal("LEDGER_MANIFEST", tostring(publishedManifest.type or ""), "native ledger scan should publish manifest, not row chunks")
assert.equal(2, tonumber(((publishedManifest.payload or {}).ledgerProtocol) or 0), "manifest should carry the ledger protocol")
assert.truthy(((publishedManifest.payload or {}).manifest or {}).globalHash, "manifest should include global hash")
```

Add a debounce/fallback diagnostic assertion:

```lua
local diagnostics = scanner.GetLedgerDiagnostics and scanner.GetLedgerDiagnostics() or {}
assert.equal("event", tostring(diagnostics.finalizeMode or ""), "ledger scan should prefer event debounce finalization")
assert.equal((tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1, tonumber(diagnostics.moneyQueryId or 0), "ledger scan should query the fixed money log id")
```

- [ ] **Step 2: Run scanner spec and verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
```

Expected before implementation: current scanner publishes `LEDGER_DIGEST` plus `LEDGER_DELTA` payloads.

- [ ] **Step 3: Create `LedgerScanner.lua`**

Move ledger-only target planning and raw log reading out of `GuildBankScanner.lua` into a module with this public shape:

```lua
function ledgerScanner.BuildTargets(queueAccessibleTabs, currentTabName)
function ledgerScanner.QueryTargets(targets)
function ledgerScanner.ReadTarget(target)
function ledgerScanner.ReadAllTargets(targets)
function ledgerScanner.GetDiagnostics()
function ledgerScanner.ResetDiagnostics()
```

The implementation must use:

```lua
local moneyLogQueryId = (tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1
```

and raw reads equivalent to:

```lua
local actionType, who, itemLink, count, tabOne, tabTwo, year, month, day, hour = _G.GetGuildBankTransaction(target.queryId, index)
local actionType, who, amount, year, month, day, hour = _G.GetGuildBankMoneyTransaction(index)
```

- [ ] **Step 4: Change scanner publish path**

In `GuildBankScanner.lua`, replace pending `LEDGER_DELTA` payload publication with one call that sends a manifest after `mergedItemRows + mergedMoneyRows > 0`:

```lua
local function publish_ledger_manifest(db, updatedAt)
    local transport = ns.modules.syncTransport or {}
    local bankLedger = ns.modules.bankLedger or {}
    if type(transport.Send) ~= "function" or type(bankLedger.BuildLedgerManifest) ~= "function" then
        return false
    end
    transport.Send("GUILD", "GUILD", {
        type = "LEDGER_MANIFEST",
        updatedAt = tonumber(updatedAt or 0) or 0,
        payload = {
            guildKey = current_guild_key(db),
            actorContext = current_context(db),
            version = tostring(((ns.constants or {}).ADDON_VERSION) or ""),
            ledgerProtocol = tonumber(((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0,
            manifest = bankLedger.BuildLedgerManifest(db),
        },
    })
    return true
end
```

Call `publish_ledger_manifest(db, publishedLedgerSyncAt)` in `finish_ledger_scan` only when native merge counts are non-zero.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected: pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add GBankManager/GBankManager.toc GBankManager/Features/LedgerScanner.lua GBankManager/Features/GuildBankScanner.lua tests/spec/bank_ledger_scanner_spec.lua
git commit -m "feat: publish ledger manifests after native scans"
```

---

### Task 5: Add manifest, bucket request, and bucket reply sync handlers

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/Sync/ManualActions.lua`
- Modify: `tests/spec/sync_ledger_manifest_spec.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `tests/spec/sync_manual_actions_spec.lua`

- [ ] **Step 1: Write failing sync tests**

In `tests/spec/sync_ledger_manifest_spec.lua`, add message-flow assertions:

```lua
-- Matching manifest should not request rows.
_G.C_ChatInfo.sentMessages = {}
local matchingAccepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", matchingManifestPayload, "GUILD", "MemberOne")
assert.truthy(matchingAccepted, "matching ledger manifest should be accepted")
assert.equal(0, #(_G.C_ChatInfo.sentMessages or {}), "matching manifest should not request bucket rows")

-- Differing manifest should request only differing bucket.
_G.C_ChatInfo.sentMessages = {}
local diffAccepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", differentManifestPayload, "GUILD", "MemberOne")
assert.truthy(diffAccepted, "different ledger manifest should be accepted")
local requestMessage = codec.DecodeTable((_G.C_ChatInfo.sentMessages[1] or {}).payload or "")
assert.equal("LEDGER_BUCKET_REQUEST", tostring(requestMessage.type or ""), "manifest mismatch should request buckets")
assert.equal(2, tonumber(((requestMessage.payload or {}).ledgerProtocol) or 0), "bucket request should carry protocol")
assert.equal(1, #(((requestMessage.payload or {}).buckets) or {}), "bucket request should include only differing buckets")
```

In `tests/spec/sync_spec.lua`, add missing/old protocol rejection:

```lua
local missingProtocolAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", missingProtocolManifestPayload, "GUILD", "MemberOne")
assert.truthy(not missingProtocolAccepted, "ledger manifest without protocol should be rejected")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "protocol rejection should be recorded")
```

- [ ] **Step 2: Run sync specs and verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected before implementation: new message families are ignored or missing.

- [ ] **Step 3: Add protocol validation helper in `SyncEvents.lua`**

Add a helper near `ledger_version_is_compatible`:

```lua
local function ledger_protocol_is_compatible(payload)
    local expected = tonumber(((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0
    local actual = tonumber((payload or {}).ledgerProtocol or 0) or 0
    return expected > 0 and actual >= expected
end
```

Use it for `LEDGER_MANIFEST`, `LEDGER_BUCKET_REQUEST`, and `LEDGER_BUCKET_REPLY`. Rejections should call:

```lua
remember_sync_decision(ns.state.lastSyncMessage, sender, payload, false, "ledger_manifest", "old_ledger_protocol")
```

Use the matching message family for request/reply decisions.

- [ ] **Step 4: Implement manifest handler**

Add `handle_ledger_manifest(db, payload, sender)`:

```lua
local compare = type(bankLedger.CompareLedgerManifest) == "function" and bankLedger.CompareLedgerManifest(db, payload.manifest or {}) or { matched = false, differentBuckets = {} }
remember_sync_decision(ns.state.lastSyncMessage, sender, payload, true, "ledger_manifest", compare.matched and "matched" or "different")
if compare.matched then
    return true
end
transport.Send("GUILD", "GUILD", {
    type = "LEDGER_BUCKET_REQUEST",
    updatedAt = tonumber(ns.state.lastSyncMessage.updatedAt or (_G.time and _G.time() or 0)) or 0,
    payload = {
        guildKey = active_guild_key(db),
        actorContext = current_context(db),
        version = tostring(((ns.constants or {}).ADDON_VERSION) or ""),
        ledgerProtocol = tonumber(((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0,
        target = sender,
        buckets = compare.differentBuckets or {},
    },
})
return true
```

If the transport can send whispers safely later, the first implementation may still use `GUILD` plus target metadata and let receivers ignore requests not addressed to them.

- [ ] **Step 5: Implement bucket request/reply**

For `LEDGER_BUCKET_REQUEST`, ignore requests whose `target` does not match the local character key or sender-compatible name. For matching requests:

```lua
local rows = type(bankLedger.RowsForLedgerBuckets) == "function" and bankLedger.RowsForLedgerBuckets(db, payload.buckets or {}) or { item = {}, money = {} }
transport.Send("GUILD", "GUILD", {
    type = "LEDGER_BUCKET_REPLY",
    updatedAt = tonumber(ns.state.lastSyncMessage.updatedAt or (_G.time and _G.time() or 0)) or 0,
    payload = {
        guildKey = active_guild_key(db),
        actorContext = current_context(db),
        version = tostring(((ns.constants or {}).ADDON_VERSION) or ""),
        ledgerProtocol = tonumber(((ns.constants or {}).LEDGER_PROTOCOL_VERSION) or 0) or 0,
        target = sender,
        buckets = payload.buckets or {},
        rows = rows,
    },
})
```

For `LEDGER_BUCKET_REPLY`, ignore replies whose `target` does not match local identity. Merge rows through a new `bankLedger.MergeBucketRows(db, payload)` wrapper. Print routine chat only when merged count is greater than zero.

- [ ] **Step 6: Change manual ledger sync to manifest-first**

In `ManualActions.lua`, replace digest/delta send in the `ledger` action with a single `LEDGER_MANIFEST` send. Return text like:

```lua
return true, string.format("Announced ledger manifest for %d row(s).", tonumber((manifest or {}).totalCount or 0) or 0)
```

- [ ] **Step 7: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: pass.

- [ ] **Step 8: Commit**

Run:

```powershell
git add GBankManager/Sync/SyncEvents.lua GBankManager/Sync/ManualActions.lua tests/spec/sync_ledger_manifest_spec.lua tests/spec/sync_spec.lua tests/spec/sync_manual_actions_spec.lua
git commit -m "feat: add ledger manifest sync flow"
```

---

### Task 6: Add bucket reply merge, non-echo behavior, and debug output

**Files:**
- Modify: `GBankManager/Domain/BankLedger.lua`
- Modify: `GBankManager/Core/SlashCommands.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`
- Modify: `tests/spec/slash_commands_spec.lua`
- Modify: `tests/spec/chat_output_spec.lua`

- [ ] **Step 1: Write failing merge and debug tests**

In `tests/spec/bank_ledger_spec.lua`, add:

```lua
local merged = bankLedger.MergeBucketRows(db, {
    ledgerProtocol = 2,
    rows = {
        item = {
            { type = "withdraw", who = "MemberOne", itemID = 238415, itemName = "Vantus Rune: Radiant", quantity = 1, tabName = "Extra Stuff", tabIndex = 2, timestamp = 1718300000 },
        },
        money = {
            { type = "repair", who = "MemberTwo", amountCopper = 12345, timestamp = 1718300000 },
        },
    },
})
assert.equal(2, tonumber(merged or 0), "bucket reply merge should append missing item and money rows")
assert.equal(0, tonumber(bankLedger.MergeBucketRows(db, samePayload) or 0), "identical bucket reply should merge no rows")
```

In `tests/spec/slash_commands_spec.lua`, extend `/gbm debug ledger` expectations to include `ledgerProtocol=2`, `reset=1.2.0`, `globalHash=`, and `buckets=`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
.\tools\lua\lua.exe .\tests\spec\chat_output_spec.lua
```

Expected before implementation: `MergeBucketRows` and debug lines are missing.

- [ ] **Step 3: Implement `MergeBucketRows`**

In `BankLedger.lua`, add:

```lua
function bankLedger.MergeBucketRows(db, payload)
    payload = type(payload) == "table" and payload or {}
    local total = 0
    local itemRows = ((payload.rows or {}).item) or {}
    if #itemRows > 0 then
        total = total + bankLedger.MergeItemTransactions(db, {
            kind = "item",
            sourceTabIndex = 0,
            sourceTabName = "Remote Bucket",
            scanStartedAt = tonumber(payload.updatedAt or 0) or 0,
            transactions = itemRows,
            allowSuspiciousUnknownAppend = true,
        })
    end
    local moneyRows = ((payload.rows or {}).money) or {}
    if #moneyRows > 0 then
        total = total + bankLedger.MergeMoneyTransactions(db, {
            kind = "money",
            scanStartedAt = tonumber(payload.updatedAt or 0) or 0,
            transactions = moneyRows,
            allowSuspiciousUnknownAppend = true,
        })
    end
    return total
end
```

If source tab metadata is present on each item row, preserve it in normalization instead of forcing `"Remote Bucket"`.

- [ ] **Step 4: Store debug state**

When handling manifests, requests, and replies, update `db.syncState` debug fields:

```lua
db.syncState.ledgerLastManifest = { sender = sender, reason = reason, updatedAt = updatedAt, buckets = compare.differentBuckets or {} }
db.syncState.ledgerLastBucketRequest = { sender = sender, buckets = payload.buckets or {}, updatedAt = updatedAt }
db.syncState.ledgerLastBucketReply = { sender = sender, buckets = payload.buckets or {}, merged = mergedCount, updatedAt = updatedAt }
```

Expose ledger debug data through existing slash debug helpers without adding routine chat.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
.\tools\lua\lua.exe .\tests\spec\chat_output_spec.lua
```

Expected: pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git add GBankManager/Domain/BankLedger.lua GBankManager/Core/SlashCommands.lua GBankManager/Sync/SyncEvents.lua tests/spec/bank_ledger_spec.lua tests/spec/slash_commands_spec.lua tests/spec/chat_output_spec.lua
git commit -m "feat: merge ledger bucket replies"
```

---

### Task 7: Update docs, release guidance, and handoff for 1.2.0

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/curseforge-release-workflow.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Modify: `docs/superpowers/specs/2026-06-04-gbankmanager-ledger-engine-1-2-design.md` only if implementation naming differs from the spec

- [ ] **Step 1: Update README ledger description**

Replace old digest/delta wording with:

```markdown
- Bank Ledger sync now uses a 1.2.0 ledger protocol with compact bucket manifests, bucket requests, and bucket replies. Native guild-bank log scans publish manifests only when new local rows are written; peers request only differing buckets, and old or missing-protocol ledger payloads are rejected before merge.
- The 1.2.0 compatibility boundary intentionally clears stored Bank Ledger rows and ledger sync metadata once, while preserving inventory, Minimums, Requests, auth, blacklist, UI settings, and general sync peers.
```

- [ ] **Step 2: Update testing docs**

In `docs/testing.md`, add coverage text for:

```markdown
- ledger protocol reset coverage for the 1.2.0 clean baseline
- durable count-based ledger row identity for repeated same-hour activity
- bucket manifest match/mismatch coverage
- bucket reply merge coverage without outbound sync echo
- old or missing ledger protocol rejection
```

- [ ] **Step 3: Update manual checklist**

Add live validation steps:

```markdown
With two 1.2.0 clients online, create a new guild-bank item or money-log row on client A, wait for client A to scan, and confirm client B receives missing rows through manifest/bucket sync exactly once. Repeat the scan with no further bank-log changes and confirm no row payload or chat line repeats. Run `/gbm debug sync` and confirm the last ledger manifest is matched or lists only the differing buckets.

Keep an older addon client online if available, trigger its ledger sync, and confirm the 1.2.0 client rejects the payload as an old ledger protocol without importing rows.
```

- [ ] **Step 4: Update release workflow docs**

In `docs/curseforge-release-workflow.md`, update examples from `1.1.2` to `1.2.0` where they describe the next release, and add:

```markdown
For 1.2.0, confirm `LEDGER_FORCE_CLEAR_VERSION` matches `1.2.0` and the ledger protocol constant is bumped before tagging.
```

- [ ] **Step 5: Update latest handoff**

Add a new top checkpoint with:

```markdown
### 2026-06-04 Ledger Engine 1.2.0 Implementation Checkpoint

- current branch and worktree
- latest commit hash
- implemented protocol/reset/scanner/sync state
- focused tests run
- full suite status
- manual two-client validation still needed
```

- [ ] **Step 6: Run doc search**

Run:

```powershell
rg -n "LEDGER_DIGEST|LEDGER_DELTA|1\\.1\\.2|1\\.1\\.1|same-hash|old ledger" README.md docs
```

Expected: remaining matches are either historical sections clearly marked as historical or intentionally refer to older releases.

- [ ] **Step 7: Commit**

Run:

```powershell
git add README.md docs/testing.md docs/manual-test-checklist.md docs/curseforge-release-workflow.md docs/superpowers/handoffs/latest-handoff.md docs/superpowers/specs/2026-06-04-gbankmanager-ledger-engine-1-2-design.md
git commit -m "docs: update ledger engine 1.2.0 guidance"
```

---

### Task 8: Final verification and release-readiness check

**Files:**
- No planned code edits unless verification finds a defect.

- [ ] **Step 1: Run focused ledger and sync specs**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
```

Expected: all pass.

- [ ] **Step 2: Run full suite**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: `PASS tests/run_all.lua`.

- [ ] **Step 3: Inspect git state**

Run:

```powershell
git status -sb
git log --oneline -8
```

Expected: branch contains the implementation commits and only `.vscode/` remains untracked.

- [ ] **Step 4: Final review**

Dispatch a final review subagent with the entire implementation diff and ask for:

```text
Review for protocol/reset correctness, scanner event/fallback behavior, count-based dedupe correctness, bucket sync convergence, chat-noise regressions, and missing tests. Report findings by severity with file/line references.
```

- [ ] **Step 5: Fix review findings or document residual risk**

If review finds issues, fix with TDD and rerun the relevant focused specs plus `run_all.lua`. Commit fixes with neutral messages.

---

## Execution Notes For Subagents

- Task 0 is a coordinator/local preflight task because it deals with already-existing unstaged work.
- Tasks 1 through 7 should be executed sequentially by fresh worker subagents, with spec-compliance and code-quality review after each task.
- Do not dispatch multiple implementation workers that edit `BankLedger.lua`, `GuildBankScanner.lua`, or `SyncEvents.lua` at the same time.
- Exploratory agents may run in parallel, but implementation workers should be serialized because the core files overlap.
