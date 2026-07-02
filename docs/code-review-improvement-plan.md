# Code Review Improvement Plan

This document captures the findings from a full code-review pass over `GBankManager`
(and its companion `GBankManager_ItemData` addon) and turns them into an ordered,
actionable remediation plan.

The review split the codebase across four areas — Domain/Data/Core, Sync/Features,
UI, and architecture/tooling — and the two highest-impact findings were verified
directly against the source. Line numbers reflect the tree at the time of review
(`master` at `f73e659`) and should be re-confirmed before editing.

## How to use this document

- Work top-to-bottom by phase. Phases are ordered by impact, not by area.
- Each item lists the file(s), the problem, why it matters, and the intended fix.
- Every behavioral fix should land with a regression test in the existing headless
  suite (see [`docs/testing.md`](testing.md)) and, where relevant, an entry in
  [`docs/manual-test-checklist.md`](manual-test-checklist.md).
- Prefer small, reviewable commits — ideally one item (or one tightly-related
  cluster) per commit.

## Overall assessment

The addon is well structured and disciplined: clean module boundaries, `_G.`-prefixed
globals, structured `GetGuildBankTransaction` parsing instead of locale scraping, a
real headless test suite, and no taint hazards (custom menus, namespaced popups,
nil-safe item lookups). The items below are where it can improve; the Critical and
High phases contain the items that actually change in-game behavior or the security
posture.

---

## Phase 1 — Critical (behavior-breaking / security)

### 1.1 Fix the namespace-registration split for `CraftedQuality` and `ItemDisplay`
- **Files:** [`GBankManager/Domain/CraftedQuality.lua:3`](../GBankManager/Domain/CraftedQuality.lua),
  [`GBankManager/Domain/ItemDisplay.lua:3`](../GBankManager/Domain/ItemDisplay.lua)
- **Problem:** Both files do `ns = _G.GBankManagerNamespace or ns`. Because
  `GBankManager_ItemData` is a **hard dependency**, it loads first and its
  `Namespace.lua:9` publishes *its own* private table to `_G.GBankManagerNamespace`.
  So these two modules register into the ItemData addon's table, while every
  consumer (`Domain/Exports.lua`, the views, controllers, `MainFrameShell`) reads
  `ns.modules.craftedQuality` / `ns.modules.itemDisplay` from the **main addon's**
  vararg table — getting `nil` and silently falling through their
  `type(x.Fn) == "function"` guards.
- **Impact:** Crafted-quality coloring and item-display formatting do not work on
  real clients. The test suite hides this because its loader rebinds `ns` to each
  file's return value ([`tests/helpers/assert.lua:86`](../tests/helpers/assert.lua)),
  which WoW never does.
- **Fix:** Make both files use the plain vararg `ns` like every other main-addon
  file (drop the `_G.GBankManagerNamespace` adoption). Add an in-game assertion /
  smoke check that both modules resolve to real implementations after load.
- **Test:** Fix the currently-failing
  `ui_crafted_quality_live_regression_spec.lua` (see 1.4) and add a wiring
  assertion that `ns.modules.craftedQuality` and `ns.modules.itemDisplay` expose
  their expected functions under the real (non-rebinding) load model.

### 1.2 Stop trusting attacker-supplied rank in sync permission checks
- **Files:** [`GBankManager/Domain/Permissions.lua:475`](../GBankManager/Domain/Permissions.lua),
  [`GBankManager/Sync/SyncEvents.lua:223`](../GBankManager/Sync/SyncEvents.lua)
  (`actor_matches_sender` and all `handle_*` functions)
- **Problem:** Every sync handler derives authority from `payload.actorContext`.
  `permissions.Can` returns `true` the moment `context.isGuildMaster` is set, and
  that field arrives over the wire. `actor_matches_sender` binds only the
  name/character key to the sender — it never confirms rank against the guild
  roster. A regular member can send
  `actorContext = { name = <their real name>, isGuildMaster = true, guildRankIndex = 0 }`
  and pass every check.
- **Impact:** Any member can approve/reject/delete requests, overwrite minimums,
  and inject audit history on every other client. The ledger handlers
  (`handle_ledger_bucket_reply` / `handle_ledger_delta`) have **no** capability gate
  at all, so any member can fabricate deposit/withdrawal rows into everyone's ledger.
- **Fix:** On receipt, resolve the sender's real rank / GM status locally via
  `GetGuildRosterInfo` and run `permissions.Can` against that locally-derived
  context. Treat `actorContext` as an identity claim only, still subject to
  `actor_matches_sender`. Add a capability gate (e.g. `full_ui`) to the ledger
  merge paths, consistent with the request handlers.
- **Also fix:** `actor_matches_sender` returns `true` when both `name` and
  `characterKey` are empty (both guard blocks skipped) — require a non-empty actor
  identity that positively matches the sender.

---

## Phase 2 — High (crash/DoS, convergence, hot-path performance)

### 2.1 Harden the codec decoder against crafted messages
- **File:** [`GBankManager/Sync/Codec.lua:74`](../GBankManager/Sync/Codec.lua) (the `"T"` branch)
- **Problem:** `count` is attacker-controlled and drives an unbounded loop; nested
  `T` tags recurse without a depth limit; the receive-path decode is not wrapped in
  `pcall`.
- **Impact:** A one-line crafted GUILD addon message freezes or stack-overflows
  every receiving client.
- **Fix:** Bound `count` by the remaining string length, cap recursion depth, and
  `pcall` the decode on the receive path.

### 2.2 Make ledger manifest tokens content-based so peers converge
- **File:** [`GBankManager/Domain/LedgerManifest.lua:48`](../GBankManager/Domain/LedgerManifest.lua)
- **Problem:** `row_identity_token` prefers the per-client `entryId` over the
  content `fingerprint`. Merges assign fresh local IDs, so two peers with identical
  data compute different bucket hashes forever and keep exchanging bucket payloads
  that merge zero rows.
- **Fix:** Prefer `row.fingerprint`; fall back to `entryId` only when the
  fingerprint is empty (swap the two branches).

### 2.3 Stop rebuilding the fingerprint index on every `EnsureState`; batch merges
- **File:** [`GBankManager/Domain/BankLedger.lua:842`](../GBankManager/Domain/BankLedger.lua)
  (`EnsureState`, `rebuild_fingerprint_index`, `MergeBucketRows`)
- **Problem:** `EnsureState` wipes and repopulates the whole index on every call,
  and `MergeBucketRows` runs one full-log merge per row (O(N×M)).
- **Impact:** A single ledger-view refresh walks the log multiple times; incoming
  sync merges hitch the frame.
- **Fix:** Make `EnsureState` cheap via a dirty flag / entry count and skip the
  rebuild when nothing changed. Batch `MergeBucketRows` into one merge per source
  key instead of one call per row.

### 2.4 Stop persisting the fingerprint indexes to SavedVariables
- **Files:** [`GBankManager/Data/Defaults.lua:80`](../GBankManager/Data/Defaults.lua),
  [`GBankManager/Data/Migrations.lua:73`](../GBankManager/Data/Migrations.lua),
  [`GBankManager/Domain/BankLedger.lua:820`](../GBankManager/Domain/BankLedger.lua)
- **Problem:** `itemFingerprints` / `moneyFingerprints` are written to disk but
  rebuilt from scratch every session, roughly doubling ledger SavedVariables size
  for zero benefit.
- **Fix:** Move the index to a runtime-only cache; nil the persisted tables in a
  versioned compaction migration.

### 2.5 Cache `store.GetDatabase` instead of re-migrating per call
- **File:** [`GBankManager/Data/Store.lua:573`](../GBankManager/Data/Store.lua)
- **Problem:** `GetDatabase` runs `migrations.Apply` twice plus a ledger prune on
  every call, and is called from ~23 sites including every routine chat message.
- **Fix:** Normalize once at `ADDON_LOADED` and after external mutation (sync
  merge); cache on `ns.state.db`; make repeat calls return the cache; throttle
  `PruneRetention`.

### 2.6 Gate UI refreshes on visibility; build the request search snapshot once
- **Files:** [`GBankManager/Sync/SyncEvents.lua:627`](../GBankManager/Sync/SyncEvents.lua)
  (`refresh_visible_sync_views`),
  [`GBankManager/UI/MainFrame.lua:5184`](../GBankManager/UI/MainFrame.lua)
  (`BackfillRequestCraftedTier` loop)
- **Problem:** The sync-refresh guard checks `activeView` (never cleared on hide),
  not `IsShown()`, so incoming messages rebuild the hidden UI. Each REQUESTS
  refresh rebuilds the entire item search catalog **per request**
  (O(requests × catalog)), re-run on every filter keystroke and every sync message.
- **Fix:** Add `mainFrame:IsShown()` to the guard with a dirty flag consumed on
  next Show. Build the search snapshot once per refresh and pass it in (the
  minimums controller's `BackfillMinimumCraftedTier(row, snapshot)` already does
  this). Debounce filter-input `OnTextChanged` and route to a rows-only rebuild.

### 2.7 Wire all spec files into CI lanes and fix the failing spec
- **Files:** `tests/run_unit.lua`, `tests/run_ui.lua`, `tests/run_integration.lua`
- **Problem:** Lanes are hand-maintained; 19 of 52 spec files run in no lane. At
  least one — `ui_crafted_quality_live_regression_spec.lua:123` — fails today but
  CI cannot see it (likely a direct symptom of 1.1).
- **Fix:** Build lane lists by globbing `tests/spec/*_spec.lua` (or add a
  lane-coverage assertion), then fix the failing spec.

---

## Phase 3 — Medium (performance churn, data-integrity edges, correctness)

- **Per-scroll GC churn.**
  [`GBankManager/UI/MainTableController.lua:513`](../GBankManager/UI/MainTableController.lua)
  rebinds a new `OnClick` closure per visible row on every scroll tick, and
  `resolve_cell_icon` returns a fresh table per cell. Bind handlers once in
  `ensure_table_rows`; reuse a cell-icon table. This is the hottest allocation path
  in the addon.
- **Permanent no-op timers.** Every scrollbar installs an always-on `OnUpdate`
  ([`MainFrameShell.lua:2094`](../GBankManager/UI/MainFrameShell.lua)) and
  ChatFilters runs a permanent 20 Hz ticker
  ([`ChatFilters.lua:227`](../GBankManager/Features/ChatFilters.lua)) regardless of
  state. Install/cancel on demand (the minimap button already does this correctly).
- **Hello-triggered sync storm.** Every `SYNC_HELLO` makes each recipient
  re-broadcast four full snapshots to GUILD, bypassing the cooldown — O(N²) across
  a login wave. Debounce, and prefer whispering the newly-arrived peer.
- **Unbounded comm buffers.** `transport.pendingReceivedMessages`
  ([`Transport.lua:46`](../GBankManager/Sync/Transport.lua)) is queued but never
  drained in production; chunk-reassembly buffers have no size/time cap. Cap/expire
  both; the queue path looks entirely redundant and may be removable.
- **`trim()` returns two values.** Six near-identical copies (e.g.
  [`BankLedger.lua:82`](../GBankManager/Domain/BankLedger.lua)) leak a gsub count
  into time keys — self-consistent today but exactly the fingerprint-format
  fragility the last two releases fixed. Parenthesize the return and consolidate to
  one shared helper.
- **Guild key collision drops data.** `migrations.Apply`
  ([`Migrations.lua:262`](../GBankManager/Data/Migrations.lua)) lets `"Unknown"` and
  `"Unknown Guild"` normalize together so one overwrites the other. Merge (prefer
  newer `meta.updatedAt` / larger DB) instead of overwriting.
- **Dead theme-preset migration.** [`Migrations.lua:11`](../GBankManager/Data/Migrations.lua)
  captures `styleTokens` before `UI/StyleTokens.lua` loads, so `NormalizePresetKey`
  can never fire. Resolve the module lazily inside `Apply()`.
- **Request-id collision.** `build_request_id`
  ([`Requests.lua:81`](../GBankManager/Domain/Requests.lua)) collides for
  same-second duplicate submits. Append a per-session monotonic counter.
- **Deprecated / inconsistent APIs.** Add a `C_Item.GetItemInfo` fallback for the
  `GetItemInfo` call ([`ItemCatalog.lua:472`](../GBankManager/Domain/ItemCatalog.lua)).
  Unify time sources behind one helper preferring `GetServerTime()` — the ledger
  uses `GetServerTime()` while cross-peer sync timestamps use `time()`, so a skewed
  peer clock arbitrarily wins conflict resolution.
- **Test harness ships in release.** `Testing/` loads unconditionally in the TOC
  and is copied into the CurseForge package;
  [`LiveSmoke.lua:623`](../GBankManager/Testing/LiveSmoke.lua) hot-swaps global bank
  APIs without a `pcall`-protected restore. Exclude `Testing/` from the package and
  TOC-gate it (or wrap the smoke body so globals always restore).

---

## Phase 4 — Low / maintainability

- **Add a `.luacheckrc` and a lint stage in CI.** High-signal given the `_G.`
  discipline; would have caught 1.1 and the dead `store` local in `Bootstrap.lua:10`.
  Suggested config:
  ```lua
  std = "lua51"
  globals = {
    "GBankManagerDB", "GBankManagerNamespace",
    "GBankManagerItemSearchPayload", "GBankManagerItemCatalogData",
    "GBankManagerItemQualityByID",
  }
  read_globals = { "LibStub" }
  exclude_files = { "GBankManager/Libs/**", "GBankManager_ItemData/Generated/**" }
  ```
- **Split the god-files along existing seams.** `MainFrame.lua` (5,465 lines) is
  really five modules — extract `MainOptionsController` / `MainThemeApplier` via the
  existing `Controller.Attach` pattern (biggest win). `BankLedger.lua` (2,448)
  mixes identity, merge, planning, and export concerns; `SyncEvents.lua` (1,804) is
  a 130-line if/else dispatch ladder that wants a handler-by-type table. The
  `*View.lua` files are already exemplary and are the model to follow.
- **Remove verified dead code.** `HideMinimumInlineRow` /
  `ConfigureMinimumBankTabDropdown` (~120 lines of never-created widgets),
  `legacy_index_requires_rebuild`, `uses_fallback_for_capability`, the identical
  then/else in `GetBundledSearchPayload`, and the `dofile` fallbacks that can never
  fire in the WoW sandbox (or comment them if they are deliberate test-harness shims).
- **Companion-addon packaging.** `GBankManager_ItemData.toc` has no `## Version`;
  the hard dependency bricks the whole addon if the data addon is disabled.
  Consider `## OptionalDeps` (ItemCatalog already guards the missing payload) and
  stamp a version in the release script.
- **Localize the chat filter.** The English-only NPC name `"Silvermoon Citizen"`
  ([`ChatFilters.lua:21`](../GBankManager/Features/ChatFilters.lua)) breaks on
  non-English clients; key by creature ID via GUID.

---

## Suggested commit sequence

1. `fix: register crafted-quality and item-display in the addon namespace` (1.1)
2. `fix: verify sender rank locally for sync permission checks` (1.2)
3. `fix: guard codec decoder against crafted messages` (2.1)
4. `fix: use content fingerprints for ledger manifest tokens` (2.2)
5. `perf: make EnsureState incremental and batch bucket merges` (2.3)
6. `perf: drop persisted fingerprint indexes` (2.4)
7. `perf: cache GetDatabase and throttle retention prune` (2.5)
8. `perf: gate sync refreshes on visibility; build request snapshot once` (2.6)
9. `test: glob spec lanes and fix crafted-quality regression` (2.7)
10. Phase 3 items as individually-scoped commits.
11. Phase 4 cleanup (luacheck, file splits, dead-code removal) last.

Each behavioral commit should include or update a headless spec, and Phase 1–2
items should be re-verified in-game via the manual test checklist before a release
tag.
