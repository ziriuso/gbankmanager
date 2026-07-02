# GBankManager Code Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate the critical and high-impact findings from `docs/code-review-improvement-plan.md` while keeping the addon releasable after each small slice.

**Architecture:** Treat the review document as the specification, but re-confirm each finding against the current checkout before editing because the review line numbers were captured at `master` `f73e659`. Start by making the headless lanes trustworthy, then fix namespace wiring and inbound sync trust boundaries, then proceed through codec hardening, ledger convergence, and performance work in dependency order.

**Tech Stack:** WoW Retail Lua addon, Lua 5.1 headless specs under `tests/spec/*.lua`, SavedVariables through `GBankManagerDB`, AceComm/AceSerializer transport bundled under `GBankManager/Libs`, baseline verification with `.\tools\lua\lua.exe .\tests\run_all.lua`, live verification through `/gbm test unit` and `/gbm test smoke`.

---

## Current Repo Truth

- Checkout: `C:\GitHub\gbankmanager`
- Branch: `master`
- HEAD at planning time: `e0930c9 Merge docs/code-review-improvement-plan: add code-review improvement plan`
- Local status at planning time: `master...origin/master [ahead 2]`, no dirty files reported by `git status -sb`
- Baseline verification at planning time: `.\tools\lua\lua.exe .\tests\run_all.lua` passed
- Important gap: direct orphan-spec run failed:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_crafted_quality_live_regression_spec.lua
```

Expected current failure before Task 1/2: line 123 fails with `request details should keep the separate quality icon hidden under the shared item-display contract`.

## Implementation Rules

- Follow TDD for every behavioral change: write or expose the failing test first, run it, implement the minimum fix, rerun the focused test, then run the owning lane.
- Keep one review item or tightly related cluster per commit.
- Update `docs/testing.md` and `docs/manual-test-checklist.md` whenever verification commands, live smoke expectations, or manual QA order changes.
- Do not commit secrets or local machine paths except documented existing development paths already used by this repo.
- Do not start Phase 3 or Phase 4 cleanup until Phase 1 and Phase 2 are green locally and represented in the lane runners.
- Record assumptions in commit messages or plan updates when live-client behavior cannot be proven headlessly.

---

## File Structure

- `docs/code-review-improvement-plan.md`
  - Source review specification. Update only if implementation discovers a finding is obsolete or materially different.
- `docs/testing.md`
  - Lane coverage, commands, and new security/codec/manual verification notes.
- `docs/manual-test-checklist.md`
  - Retail checks for namespace/UI display, forged sync rejection, codec rejection, and ledger convergence.
- `GBankManager/Domain/CraftedQuality.lua`
  - Main-addon module registration for crafted-quality rendering.
- `GBankManager/Domain/ItemDisplay.lua`
  - Main-addon module registration for shared item-display payloads.
- `GBankManager/Domain/Permissions.lua`
  - Local player context already exists here; add local roster/sender context resolution here if shared by sync handlers and tests.
- `GBankManager/Sync/SyncEvents.lua`
  - Inbound sync trust boundary, sender validation, capability gates, UI refresh gating.
- `GBankManager/Sync/Codec.lua`
  - Bounded decode for nested tables, table counts, malformed lengths, and invalid payloads.
- `GBankManager/Sync/Transport.lua`
  - Safe decode around chunk reassembly and direct payload fallback.
- `GBankManager/Domain/LedgerManifest.lua`
  - Content-based ledger manifest row tokens.
- `GBankManager/Domain/BankLedger.lua`
  - Runtime fingerprint indexes, cheap `EnsureState`, batched bucket merges.
- `GBankManager/Data/Defaults.lua`
  - Remove persisted fingerprint-index defaults after runtime cache exists.
- `GBankManager/Data/Migrations.lua`
  - Versioned compaction for persisted fingerprint indexes and any guild-key merge fix.
- `GBankManager/Data/Store.lua`
  - `GetDatabase` cache and retention-prune throttling after invalidation points are confirmed.
- `GBankManager/UI/MainFrame.lua`
  - Request search snapshot reuse and filter debounce.
- `tests/helpers/test_runner.lua`
  - Shared lane discovery or lane coverage assertion helper.
- `tests/run_unit.lua`, `tests/run_ui.lua`, `tests/run_integration.lua`
  - Lane ownership for all specs.
- `tests/spec/test_runner_spec.lua`
  - Lane coverage regression.
- `tests/spec/ui_crafted_quality_live_regression_spec.lua`
  - Existing failing crafted-quality/request-details regression.
- `tests/spec/toc_spec.lua`
  - Bootstrap/module wiring assertions.
- `tests/spec/sync_spec.lua`
  - Forged actor-context rejection, local-rank authority, codec receive safety, UI refresh guard integration.
- `tests/spec/sync_ledger_manifest_spec.lua`
  - Ledger manifest convergence expectation.
- `tests/spec/bank_ledger_spec.lua`
  - Runtime index and bucket merge performance/correctness contracts.
- `tests/spec/store_spec.lua`
  - SavedVariables compaction and `GetDatabase` cache contracts.
- `tests/spec/ui_requests_spec.lua`
  - Request snapshot reuse, debounce, and request-details display contracts.

---

### Task 1: Make the test lanes trustworthy before fixing behavior

**Files:**
- Modify: `tests/helpers/test_runner.lua`
- Modify: `tests/run_unit.lua`
- Modify: `tests/run_ui.lua`
- Modify: `tests/run_integration.lua`
- Modify: `tests/spec/test_runner_spec.lua`
- Modify: `docs/testing.md`

- [ ] **Step 1: Reproduce the current hidden failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
.\tools\lua\lua.exe .\tests\spec\ui_crafted_quality_live_regression_spec.lua
```

Expected before implementation: `run_all` passes, direct spec fails at line 123. This proves lane coverage is incomplete.

- [ ] **Step 2: Add a failing lane-coverage assertion**

Add a helper that compares all `tests/spec/*_spec.lua` files against the lane-owned spec lists. The assertion must fail on the current checkout because `ui_crafted_quality_live_regression_spec.lua` is not in any lane.

Implementation direction:

```lua
-- tests/helpers/test_runner.lua
function M.collect_spec_files()
    local files = {}
    local slash = tostring(package.config or ""):sub(1, 1)
    local command = slash == "\\"
        and 'dir /b tests\\spec\\*_spec.lua 2>nul'
        or 'ls tests/spec/*_spec.lua 2>/dev/null'
    local handle = io.popen and io.popen(command)
    if handle then
        for file in handle:lines() do
            file = tostring(file or "")
            if file ~= "" and not file:find("^tests[/\\]spec[/\\]") then
                file = "tests/spec/" .. file
            end
            file = file:gsub("\\", "/")
            files[#files + 1] = file
        end
        handle:close()
    end
    table.sort(files)
    return files
end
```

Expose each lane list as a module-returned table or through a `runner.run_specs(specs)` return value so `tests/spec/test_runner_spec.lua` can assert no spec is unowned.

- [ ] **Step 3: Run the failing test**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\test_runner_spec.lua
```

Expected before lane updates: FAIL with the first unowned spec name, including `tests/spec/ui_crafted_quality_live_regression_spec.lua`.

- [ ] **Step 4: Wire every spec into exactly one lane**

Assign current orphan specs by ownership:

- `ui_*_spec.lua` -> `tests/run_ui.lua`
- `toc_spec.lua`, `live_smoke_spec.lua`, `in_game_unit_spec.lua`, `slash_commands_spec.lua` -> `tests/run_integration.lua`
- domain, sync, catalog, release, planning, and store specs -> `tests/run_unit.lua`

Keep `run_all` order as `unit -> ui -> integration`.

- [ ] **Step 5: Verify lane coverage now catches the known regression**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\test_runner_spec.lua
.\tools\lua\lua.exe .\tests\run_ui.lua
```

Expected after lane wiring but before Task 2: lane coverage passes, `run_ui` fails at `ui_crafted_quality_live_regression_spec.lua`.

- [ ] **Step 6: Update docs**

Update `docs/testing.md` so the Lane Coverage section states that all `tests/spec/*_spec.lua` files must be owned by one lane and that `test_runner_spec.lua` enforces this.

- [ ] **Step 7: Commit**

Run:

```powershell
git add tests/helpers/test_runner.lua tests/run_unit.lua tests/run_ui.lua tests/run_integration.lua tests/spec/test_runner_spec.lua docs/testing.md
git commit -m "test: enforce spec lane coverage"
```

---

### Task 2: Fix namespace registration for CraftedQuality and ItemDisplay

**Files:**
- Modify: `GBankManager/Domain/CraftedQuality.lua`
- Modify: `GBankManager/Domain/ItemDisplay.lua`
- Modify: `tests/spec/toc_spec.lua`
- Modify: `tests/spec/ui_crafted_quality_live_regression_spec.lua` only if the existing assertion needs a narrower message
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Add or confirm the failing wiring test**

In `tests/spec/toc_spec.lua`, assert that after the real TOC-style load, the main addon namespace contains both modules:

```lua
assert.truthy(type(ns.modules.craftedQuality) == "table", "main addon namespace should own craftedQuality")
assert.truthy(type(ns.modules.craftedQuality.GetNonInventoryDisplayAtlasForItem) == "function", "craftedQuality should expose non-inventory atlas resolution")
assert.truthy(type(ns.modules.itemDisplay) == "table", "main addon namespace should own itemDisplay")
assert.truthy(type(ns.modules.itemDisplay.BuildDisplayPayload) == "function", "itemDisplay should expose display payload builder")
```

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\toc_spec.lua
.\tools\lua\lua.exe .\tests\run_ui.lua
```

Expected before implementation: `toc_spec.lua` or `run_ui` fails due the namespace split and/or the request-details quality-icon regression.

- [ ] **Step 2: Use the vararg namespace in both main-addon modules**

Change the opening namespace adoption in both files from:

```lua
ns = _G.GBankManagerNamespace or ns or {}
```

to:

```lua
ns = ns or {}
```

Do not change `GBankManager_ItemData/Namespace.lua`; the companion addon may still publish its own payload namespace.

- [ ] **Step 3: Rerun focused tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\toc_spec.lua
.\tools\lua\lua.exe .\tests\spec\item_display_spec.lua
.\tools\lua\lua.exe .\tests\spec\crafted_quality_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_crafted_quality_live_regression_spec.lua
```

Expected: all focused specs pass. If the request-details icon assertion still fails, fix the request-details rendering path in the same commit because it is the visible symptom that lane coverage exposed.

- [ ] **Step 4: Run the owning lane and baseline**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_ui.lua
.\tools\lua\lua.exe .\tests\run_integration.lua
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: all pass.

- [ ] **Step 5: Update manual QA**

Add a manual checklist line for `/reload`, opening Minimums, Requests, Request Details, and Exports, and confirming shared item text plus dedicated crafted-quality icon rendering still match the `241322`/`241326` two-rank families.

- [ ] **Step 6: Commit**

Run:

```powershell
git add GBankManager/Domain/CraftedQuality.lua GBankManager/Domain/ItemDisplay.lua tests/spec/toc_spec.lua tests/spec/ui_crafted_quality_live_regression_spec.lua docs/manual-test-checklist.md
git commit -m "fix: register item display modules in addon namespace"
```

---

### Task 3: Stop trusting inbound actorContext for sync permissions

**Files:**
- Modify: `GBankManager/Domain/Permissions.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/Testing/LiveSmoke.lua`
- Modify: `tests/helpers/wow_stubs.lua`
- Modify: `tests/spec/chat_output_spec.lua`
- Modify: `tests/spec/sync_ledger_digest_spec.lua`
- Modify: `tests/spec/sync_ledger_manifest_spec.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`

- [x] **Step 1: Add failing forged-authority tests**

In `tests/spec/sync_spec.lua`, add cases proving a same-name sender cannot self-promote by sending `actorContext.isGuildMaster = true` or `guildRankIndex = 0` when the local roster says they are a member.

Cover at least:

- request approval/update/delete action that currently passes `actor_can`
- `MINIMUMS_SNAPSHOT`
- `LEDGER_BUCKET_REPLY`
- `LEDGER_DELTA`
- empty `actorContext.name` and empty `actorContext.characterKey`, which must fail `actor_matches_sender`

Expected current failure before implementation: forged member payloads are accepted or merged.

- [x] **Step 2: Add roster stubs**

Extend `tests/helpers/wow_stubs.lua` with deterministic guild roster functions:

```lua
_G.__guildRoster = _G.__guildRoster or {}

function _G.GetNumGuildMembers()
    return #(_G.__guildRoster or {})
end

function _G.GetGuildRosterInfo(index)
    local row = (_G.__guildRoster or {})[index]
    if type(row) ~= "table" then
        return nil
    end
    return row.name, row.rankName, row.rankIndex, row.level, row.class, row.zone, row.note, row.officerNote, row.online
end
```

Reset `_G.__guildRoster` in tests that mutate it.

- [x] **Step 3: Resolve sender authority locally**

Add a function in `GBankManager/Domain/Permissions.lua` that derives a context from local roster data for an inbound sender:

```lua
function permissions.GetGuildRosterContextBySender(sender, actorContext)
    actorContext = type(actorContext) == "table" and actorContext or {}
    local senderKey = permissions.BuildCharacterKey(sender, actorContext.realmName)
    local senderName = tostring(sender or ""):match("^([^%-]+)") or tostring(sender or "")
    local count = type(_G.GetNumGuildMembers) == "function" and tonumber(_G.GetNumGuildMembers() or 0) or 0
    for index = 1, count do
        local name, rankName, rankIndex = _G.GetGuildRosterInfo(index)
        local rosterKey = permissions.BuildCharacterKey(name, actorContext.realmName)
        local rosterName = tostring(name or ""):match("^([^%-]+)") or tostring(name or "")
        if rosterKey == senderKey or rosterName == senderName then
            local normalizedRankIndex = tonumber(rankIndex)
            return {
                name = rosterName,
                realmName = actorContext.realmName,
                characterKey = rosterKey,
                guildRankName = rankName or "",
                guildRankIndex = normalizedRankIndex,
                isGuildMaster = normalizedRankIndex == 0,
                inGuild = true,
            }
        end
    end
    return {
        name = senderName,
        realmName = actorContext.realmName,
        characterKey = senderKey,
        inGuild = false,
        isGuildMaster = false,
    }
end
```

Adjust details to match existing `BuildCharacterKey`/realm helpers. The key rule is: inbound capability checks must use locally-derived rank, never remote `actorContext.guildRankIndex` or `actorContext.isGuildMaster`.

- [x] **Step 4: Use local authority context in sync handlers**

In `GBankManager/Sync/SyncEvents.lua`, keep the incoming `actorContext` for identity/audit fields, but use a local context for all permission checks:

```lua
local function actor_authority_context(actorContext, sender)
    if permissions and type(permissions.GetGuildRosterContextBySender) == "function" then
        return permissions.GetGuildRosterContextBySender(sender, actorContext)
    end
    return {
        name = tostring(sender or ""),
        characterKey = normalize_character_key(sender),
        inGuild = false,
        isGuildMaster = false,
    }
end
```

Then replace capability checks such as:

```lua
actor_can(actorContext, capability, localPolicy)
permissions.IsBlacklisted(actorContext, localPolicy)
```

with local authority checks where the result controls mutation:

```lua
local authorityContext = actor_authority_context(actorContext, sender)
permissions.IsBlacklisted(authorityContext, localPolicy)
actor_can(authorityContext, capability, localPolicy)
```

Do this for auth policy, requests, minimum snapshots, request snapshots, history snapshots, ledger manifests, ledger bucket requests, ledger bucket replies, ledger deltas, and ledger digests.

- [x] **Step 5: Require a positive actor identity match**

Change `actor_matches_sender` so it returns `false` unless at least one non-empty actor name or actor character key positively matches the sender.

- [x] **Step 6: Gate ledger merges**

Add a `full_ui` capability check before accepting `LEDGER_BUCKET_REPLY`, `LEDGER_DELTA`, `LEDGER_MANIFEST`, and `LEDGER_BUCKET_REQUEST`. Use the same local authority context from Step 4.

- [x] **Step 7: Verify focused and broad sync tests**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\auth_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\in_game_unit_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
.\tools\lua\lua.exe .\tests\run_integration.lua
```

Expected: forged member payloads are rejected; legitimate locally-authorized officer/guildmaster payloads still pass.

- [x] **Step 8: Update docs**

Document that inbound sync permission decisions use the receiver's local roster/rank view and add a manual two-client check: member attempts to approve or sync ledger data must be ignored while an officer/guildmaster still converges normally.

- [x] **Step 9: Commit**

Run:

```powershell
git add GBankManager/Domain/Permissions.lua GBankManager/Sync/SyncEvents.lua tests/helpers/wow_stubs.lua tests/spec/auth_spec.lua tests/spec/sync_spec.lua tests/spec/in_game_unit_spec.lua docs/testing.md docs/manual-test-checklist.md
git commit -m "fix: verify inbound sync authority locally"
```

---

### Task 4: Harden sync codec decoding against crafted payloads

**Files:**
- Modify: `GBankManager/Sync/Codec.lua`
- Modify: `GBankManager/Sync/Transport.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `docs/testing.md`

- [x] **Step 1: Add failing codec tests**

In `tests/spec/sync_spec.lua`, add tests for:

- table count larger than remaining payload
- nested `T` depth above a fixed limit
- malformed string length
- direct receive path with malformed payload
- chunk reassembly path with malformed payload

Expected before implementation: at least one test errors or hangs instead of returning `nil`/invalid.

- [x] **Step 2: Bound decode**

In `GBankManager/Sync/Codec.lua`, make `decode_value` return `value, nextIndex, err` and enforce:

```lua
local MAX_DECODE_DEPTH = 16
local MAX_TABLE_ENTRIES = 256
local MAX_STRING_LENGTH = 8192
```

Reject missing separators, negative lengths, oversized lengths, table counts above the cap, and recursion deeper than the depth cap.

- [x] **Step 3: Make `DecodeTable` fail closed**

Wrap table-payload decode in `pcall`; return `nil, "decode_error"` or `nil, err` on malformed input. Keep existing valid payload behavior unchanged.

- [x] **Step 4: Guard receive paths**

In `SyncEvents.lua` and `Transport.lua`, treat `nil` decoded messages as invalid input and return without mutating `ns.state.lastSyncMessage`, peer history, or the database.

- [x] **Step 5: Verify**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
```

Expected: malformed payloads are rejected without error; existing sync encode/decode tests pass.

- [x] **Step 6: Update docs and commit**

Run:

```powershell
git add GBankManager/Sync/Codec.lua GBankManager/Sync/Transport.lua GBankManager/Sync/SyncEvents.lua tests/spec/sync_spec.lua docs/testing.md
git commit -m "fix: bound sync codec decoding"
```

---

### Task 5: Make ledger manifest tokens content-based

**Files:**
- Modify: `GBankManager/Domain/LedgerManifest.lua`
- Modify: `tests/spec/sync_ledger_manifest_spec.lua`
- Modify: `docs/manual-test-checklist.md`

- [x] **Step 1: Flip the existing expectation first**

In `tests/spec/sync_ledger_manifest_spec.lua`, change the assertion that currently expects different hashes for shared fingerprints and different entry IDs. It should expect equal hashes when `fingerprint` matches.

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
```

Expected before implementation: FAIL because `row_identity_token` still prefers `entryId`.

- [x] **Step 2: Prefer content fingerprint**

Change `row_identity_token` in `GBankManager/Domain/LedgerManifest.lua` so the first branch is:

```lua
local fingerprint = trim(row.fingerprint)
if fingerprint ~= "" then
    return make_fingerprint({ kind, "fingerprint", fingerprint })
end

local entryId = trim(row.entryId)
if entryId ~= "" then
    return make_fingerprint({ kind, "entry", entryId })
end
```

- [x] **Step 3: Verify**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
```

Expected: peers with identical row fingerprints compute identical bucket/global hashes.

- [x] **Step 4: Update manual QA and commit**

Add a two-client ledger sync checklist line: after both clients have identical visible ledger rows from different local entry IDs, `Sync Ledger` should not keep exchanging zero-merge bucket payloads.

Run:

```powershell
git add GBankManager/Domain/LedgerManifest.lua tests/spec/sync_ledger_manifest_spec.lua docs/manual-test-checklist.md
git commit -m "fix: use content fingerprints for ledger manifests"
```

---

### Task 6: Make ledger state indexes runtime-only and cheaper

**Files:**
- Modify: `GBankManager/Domain/BankLedger.lua`
- Modify: `GBankManager/Data/Defaults.lua`
- Modify: `GBankManager/Data/Migrations.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`
- Modify: `tests/spec/store_spec.lua`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Add failing persistence and rebuild tests**

Add tests proving:

- fresh defaults no longer include persisted `bankLedger.itemFingerprints` or `bankLedger.moneyFingerprints`
- migration removes persisted fingerprint tables and records a compaction marker
- `EnsureState` does not rebuild indexes on a second call when log lengths and dirty markers have not changed
- appending item or money rows marks the relevant runtime index dirty

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected before implementation: defaults/migration tests fail because fingerprints are persisted; rebuild test fails because `EnsureState` always rebuilds.

- [ ] **Step 2: Introduce runtime index state**

In `BankLedger.lua`, keep the public ledger shape unchanged, but store fingerprint indexes under a runtime-only table that is never attached to SavedVariables. A concrete acceptable shape:

```lua
db.bankLedgerRuntime = db.bankLedgerRuntime or {}
db.bankLedgerRuntime.itemFingerprints = db.bankLedgerRuntime.itemFingerprints or {}
db.bankLedgerRuntime.moneyFingerprints = db.bankLedgerRuntime.moneyFingerprints or {}
db.bankLedgerRuntime.indexState = db.bankLedgerRuntime.indexState or {
    itemCount = -1,
    moneyCount = -1,
    itemDirty = true,
    moneyDirty = true,
}
```

If a runtime table on `db` would still persist, use an upvalue weak-key cache instead:

```lua
local runtimeByDb = setmetatable({}, { __mode = "k" })
```

Use the weak-key cache if tests show `db.bankLedgerRuntime` would be serialized.

- [ ] **Step 3: Rebuild only when dirty or count changed**

Have `EnsureState` compare current log counts and dirty flags before calling `rebuild_fingerprint_index`. Existing functions that mutate logs must mark the matching dirty flag.

- [ ] **Step 4: Remove persisted defaults and compact old saves**

Remove `itemFingerprints` and `moneyFingerprints` from `Defaults.lua`. Add a versioned migration in `Migrations.lua` that nils both persisted tables and records a marker such as:

```lua
db.meta.ledgerFingerprintIndexesCompactedForVersion = "2026-07-02-runtime-indexes"
```

- [ ] **Step 5: Verify**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
```

Expected: ledger behavior remains unchanged; SavedVariables no longer carry fingerprint-index tables.

- [ ] **Step 6: Update docs and commit**

Document the compaction marker and add a manual `/reload` check confirming old saves load and ledger rows still dedupe after fingerprint tables are removed.

Run:

```powershell
git add GBankManager/Domain/BankLedger.lua GBankManager/Data/Defaults.lua GBankManager/Data/Migrations.lua tests/spec/bank_ledger_spec.lua tests/spec/store_spec.lua docs/testing.md docs/manual-test-checklist.md
git commit -m "perf: keep ledger fingerprint indexes runtime-only"
```

---

### Task 7: Batch bucket-row merges

**Files:**
- Modify: `GBankManager/Domain/BankLedger.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`

- [ ] **Step 1: Add failing batch-merge contract**

In `tests/spec/bank_ledger_spec.lua`, add coverage for a bucket payload with multiple item rows from the same source tab and multiple money rows. Assert that all valid rows merge, duplicate replay still merges zero, and the merge path calls the expensive source merge once per kind/source bucket instead of once per row.

If direct call-count assertions require invasive hooks, assert the externally visible result first and keep call-count instrumentation local to tests through a temporary debug counter on `bankLedger`.

- [ ] **Step 2: Group rows before merging**

In `MergeBucketRows`, collect valid item rows by source tab/index and valid money rows by source key, then call `MergeItemTransactions` or `MergeMoneyTransactions` once per group with all grouped transactions.

- [ ] **Step 3: Verify and commit**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
git add GBankManager/Domain/BankLedger.lua tests/spec/bank_ledger_spec.lua
git commit -m "perf: batch ledger bucket merges"
```

---

### Task 8: Cache Store.GetDatabase behind explicit invalidation

**Files:**
- Modify: `GBankManager/Data/Store.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/Features/GuildBankScanner.lua` if fresh scans bypass Store mutation helpers
- Modify: `tests/spec/store_spec.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `docs/testing.md`

- [ ] **Step 1: Confirm invalidation points before coding**

Search for direct SavedVariables mutation and `store.GetDatabase` callers:

```powershell
rg -n "GetDatabase\\(|GBankManagerDB|ns\\.state\\.db|migrations\\.Apply|PruneRetention|guilds\\[" GBankManager tests
```

Record in this plan if a direct mutation path needs an explicit `store.InvalidateDatabaseCache(reason)` call.

- [ ] **Step 2: Add failing cache tests**

In `tests/spec/store_spec.lua`, assert:

- two consecutive `store.GetDatabase("Guild")` calls return the same active table without re-running migrations
- changing guild name returns/rebinds the correct guild table
- `store.InvalidateDatabaseCache("sync_merge")` causes the next call to normalize again
- retention prune runs at most once per configured throttle window

- [ ] **Step 3: Implement cache and invalidation**

Add:

```lua
store.InvalidateDatabaseCache = function(reason)
    ns.state.dbCache = nil
    ns.state.dbCacheReason = tostring(reason or "")
end
```

Cache by normalized guild key and root table identity. Any sync merge, fresh scan, clear-data action, or guild-key promotion must invalidate before the next read.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\run_unit.lua
git add GBankManager/Data/Store.lua GBankManager/Sync/SyncEvents.lua GBankManager/Features/GuildBankScanner.lua tests/spec/store_spec.lua tests/spec/sync_spec.lua docs/testing.md
git commit -m "perf: cache normalized guild database"
```

---

### Task 9: Gate hidden UI refreshes and reuse request search snapshots

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `docs/manual-test-checklist.md`

- [ ] **Step 1: Add failing UI refresh tests**

Cover:

- incoming sync while main frame is hidden sets a dirty flag and does not rebuild active view rows
- showing the frame consumes the dirty flag and refreshes once
- request refresh builds the item search snapshot once and passes it through `BackfillRequestCraftedTier`
- request filter `OnTextChanged` is debounced or limited to rows-only rebuild

- [ ] **Step 2: Implement visibility guard**

In `refresh_visible_sync_views`, require both active view and `mainFrame:IsShown()` before rebuilding. If hidden, set a dirty flag on the frame or `ns.state`.

- [ ] **Step 3: Reuse request search snapshot**

In `MainFrame.lua`, build the request search/catalog snapshot once per request refresh and pass it to every request-row backfill call, mirroring the existing minimums controller pattern.

- [ ] **Step 4: Verify and commit**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\run_ui.lua
.\tools\lua\lua.exe .\tests\run_all.lua
git add GBankManager/Sync/SyncEvents.lua GBankManager/UI/MainFrame.lua tests/spec/sync_spec.lua tests/spec/ui_requests_spec.lua docs/manual-test-checklist.md
git commit -m "perf: defer hidden sync refreshes"
```

---

## Phase 3 Follow-Up Order

After Tasks 1-9 are green and pushed, implement medium-risk items as separate commits in this order:

1. Main table per-scroll allocation cleanup in `GBankManager/UI/MainTableController.lua`
2. On-demand scrollbar/chat-filter timers in `GBankManager/UI/MainFrameShell.lua` and `GBankManager/Features/ChatFilters.lua`
3. `SYNC_HELLO` storm debounce and peer whisper preference in `GBankManager/Sync/SyncEvents.lua`
4. Transport buffer caps/expiry in `GBankManager/Sync/Transport.lua`
5. Shared `trim` helper consolidation, with a test proving no second `gsub` return leaks into fingerprints
6. Guild-key collision merge in `GBankManager/Data/Migrations.lua`
7. Lazy theme preset migration lookup in `GBankManager/Data/Migrations.lua`
8. Request ID monotonic suffix in `GBankManager/Domain/Requests.lua`
9. `C_Item.GetItemInfo` fallback and shared time-source helper
10. Exclude or TOC-gate `GBankManager/Testing/` from release package, with `pcall` restore for live smoke globals

Each item gets its own focused failing spec first and updates `docs/testing.md` or `docs/manual-test-checklist.md` when verification changes.

## Phase 4 Follow-Up Order

Do these only after behavior/security/performance fixes are stable:

1. Add `.luacheckrc` and CI lint stage.
2. Split `MainFrame.lua` along existing controller seams.
3. Split `BankLedger.lua` only where a tested helper boundary already exists.
4. Convert `SyncEvents.lua` dispatch ladder into a handler table.
5. Remove verified dead code in small commits.
6. Add companion-addon version stamping and decide, with maintainer approval, whether `GBankManager_ItemData` should remain a hard dependency or become `OptionalDeps`.
7. Localize or creature-ID-key the chat filter for `Silvermoon Citizen`.

## Final Verification Before Release

Run locally:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
powershell -ExecutionPolicy Bypass -File .\tools\test\run-all.ps1
```

Deploy for Retail smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Get-ItemCatalogMaintainerStatus.ps1 -Target Retail -Json
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json
```

In Retail after `/reload`:

- Run `/gbm test unit`.
- Run `/gbm test smoke`.
- Run the forged-sync two-client manual checks from Task 3.
- Run the ledger convergence check from Task 5.
- Spot-check Minimums, Requests, Request Details, and Exports crafted-quality rendering from Task 2.

## Self-Review Notes

- Spec coverage: all Critical and High items from `docs/code-review-improvement-plan.md` are represented by Tasks 1-9.
- Known uncertainty: `Store.GetDatabase` caching depends on all mutation paths being identified. Task 8 starts with a required invalidation audit before code changes.
- Known uncertainty: runtime-only ledger indexes may require a weak-key cache instead of a `db` child table so the cache cannot be serialized. Task 6 includes that decision point with a testable rule.
- Phase 3 and Phase 4 are intentionally ordered but not expanded into code-level steps here; write separate detailed plans for those once Phase 1 and Phase 2 are complete.
