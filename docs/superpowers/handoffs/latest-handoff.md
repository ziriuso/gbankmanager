# GBankManager Handoff

## Resume Here

### 2026-06-04 Ledger Engine 1.2.0 Implementation Checkpoint

- Current local checkpoint:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - latest commit is the current `fix: recover stale ledger manifest sync` checkpoint
  - target release line: `v1.2.1`
  - local branch is ahead of origin; only expected local noise is untracked `.vscode/`
- Scope implemented:
  - `GBankManager.toc`, `ADDON_VERSION`, and About metadata now target `1.2.1` / `v1.2.1`
  - `v1.2.0` was pushed first but failed during the release workflow's Lua suite before packaging, GitHub Release creation, or CurseForge upload; `v1.2.1` is the follow-up publish tag
  - `LEDGER_FORCE_CLEAR_VERSION = 1.2.0` intentionally forces one clean Bank Ledger reset while preserving inventory, Minimums, Requests, auth, blacklist, UI settings, and general sync peers
  - `LEDGER_PROTOCOL_VERSION = 2` gates the new manifest, bucket-request, and bucket-reply payload families; old or missing ledger protocols are rejected as `old_ledger_protocol`
  - ledger row identity now uses durable occurrence IDs and count metadata so repeated same-hour activity can be represented without relying on remote row positions
  - `LedgerManifest.lua` builds deterministic global and six-hour bucket hashes, compares manifests, and selects rows for requested buckets
  - `LedgerScanner.lua` owns ledger log target planning, fixed money-log query id, raw item/money log reads, and scanner diagnostics
  - native ledger scans now publish a single `LEDGER_MANIFEST` only after local native row writes; no-change scans do not publish row payloads
  - manual `Sync Ledger` now announces the local manifest instead of sending digest/delta row bursts
  - peers request only differing buckets and reply with bucket rows targeted to the requesting client
  - when a stale or empty client announces a behind ledger manifest, fuller peers can reply directly with the local missing bucket rows instead of asking the stale client for rows it does not have
  - `MergeBucketRows` appends only valid bucket rows, rejects malformed row payloads before they can create synthetic ledger entries, is idempotent on replay, and does not echo outbound sync
  - `/gbm debug ledger` now includes ledger protocol, reset marker, global hash, bucket count, and recent manifest/request/reply state
- Focused verification green during implementation:
  - `.\tools\lua\lua.exe .\tests\spec\store_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_ledger_manifest_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\chat_output_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_unit.lua`
- Manual validation still needed before release:
  1. With two 1.2.1 clients online, create a new guild-bank item or money-log row on client A, wait for client A to scan, and confirm client B receives missing rows through manifest/bucket sync exactly once.
  2. On a stale or empty client that missed the original manifest, run `Sync Ledger` and confirm the fuller online peer sends back missing bucket rows.
  3. Repeat the scan or `Sync Ledger` with no further bank-log changes and confirm no row payload or chat line repeats.
  4. Run `/gbm debug sync` and `/gbm debug ledger` and confirm the last ledger manifest is matched or lists only differing buckets.
  5. Keep an older addon client online if available, trigger its ledger sync, and confirm the 1.2.0 client rejects the payload as an old ledger protocol without importing rows.

### 2026-06-04 Ledger Sync Noise Stabilization Checkpoint

- Current local checkpoint:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - base release in the worktree is `v1.1.2`
  - local work is a follow-up to live guild reports of repeated ledger delta chatter during high activity
- Scope implemented:
  - `BankLedger.BuildSyncDigest` now produces a compact ledger digest with stable hash, item count, money count, total count, and per-bucket hashes
  - manual `Sync Ledger` and scanner-published ledger updates now announce `LEDGER_DIGEST` before `LEDGER_DELTA`
  - same-hash ledger delta sends are suppressed for a short burst window while digest announcements remain available for convergence/debug state
  - scanner-ledger publishing still stays quiet when the scan produced no pending ledger payloads
  - inbound `LEDGER_DIGEST` traffic is validated with the same guild, version, blacklist, and sender checks as ledger deltas, stores the peer digest, and records `matched` or `different` in the existing sync decision surface
  - inbound `SYNC_HELLO` is now presence-only: it updates last-seen peer state and refreshes the Sync tab without running the same catch-up family set as `Sync All`
  - accepted remote `LEDGER_DELTA` payloads only print `Synced ledger delta ...` when they merge actual new rows; no-change and rejected ledger deltas stay quiet in chat while `/gbm debug sync` still records the decision
  - native local ledger writes from manual, bank-open, or passive scans remain the trigger for automatic ledger sync publication
  - sync tests that expect routine chat now explicitly opt out of the default-on routine chat suppression setting
- Focused verification now green:
  - `.\tools\lua\lua.exe .\tests\spec\sync_ledger_digest_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
- Docs updated in this slice:
  - `README.md`
  - `docs/testing.md`
  - `docs/manual-test-checklist.md`
  - this handoff
- Recommended next manual verification:
  1. In a live guild with two addon clients, perform a new guild-bank item or money-log action, let client A publish the ledger update, and confirm client B imports the row once.
  2. Repeat `Sync Ledger` or a scan burst with no further ledger changes and confirm client B does not receive duplicate rows or another `Synced ledger delta ...` line; `/gbm debug sync` should show ledger digest convergence instead of repeated applied deltas.
  3. `/reload` one client with another online and confirm login hello updates peer last-seen state without dispatching Requests, Minimums, History, or Ledger catch-up payloads until a manual sync action or native local write occurs.

### 2026-06-03 Routine Addon Chat Suppression Checkpoint

- Current local checkpoint:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - base release in the worktree is being prepared as `v1.1.2`
  - issue under implementation: `https://github.com/ziriuso/gbankmanager/issues/11`
- Scope implemented:
  - added persisted `ui.chatSettings.suppressRoutineMessages`, defaulting off and normalized through database migrations
  - added reusable `Core/ChatOutput.lua` and loaded it early in `GBankManager.toc`
  - `Sync/Transport.lua` now treats accepted sync status output as routine by default
  - guild-bank scanner start/finish/progress chat now flows through the routine output gate while still updating visible scanner status text
  - scanner warnings and failures bypass the routine mute
  - explicit slash debug and test output remains visible
  - `Options -> Appearance` now has an immediate-save `Suppress Routine Chat` toggle beside the existing local appearance toggles
  - follow-up default changed `Suppress Routine Chat` to on for missing or fresh settings while preserving an explicit saved off state
  - follow-up Appearance chrome now extends behind the added toggle stack and onboarding replay control; future Options expansion should grow the owning panel background with the new controls
  - follow-up minimap launcher positioning now derives its radius from the minimap and launcher sizes so the icon sits on the minimap edge instead of inside the map
  - follow-up New Request wizard copy now says `Search for the item you would like stocked. Current expansion items only, no gear.`
  - `GBankManager.toc` now advertises `1.1.2` / `v1.1.2`; `ADDON_VERSION` fallback matches `1.1.2` while the ledger clear marker remains `1.1.1`
- Focused verification now green:
  - `.\tools\lua\lua.exe .\tests\spec\chat_output_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\diff_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_unit.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
- Docs updated in this slice:
  - `README.md`
  - `docs/testing.md`
  - `docs/manual-test-checklist.md`
  - this handoff
- Recommended next manual verification before release or deploy:
  1. In Retail, confirm `Options -> Appearance -> Suppress Routine Chat` starts checked, run a manual scan plus a two-client routine sync update, and confirm routine scan/sync chat is hidden while UI status, warnings/errors, `/gbm debug sync`, and `/gbm test unit` remain visible; then toggle it off and confirm routine chat feedback returns.

### 2026-06-03 Ledger Sync Dedupe + Review Cleanup Checkpoint

- Current local checkpoint in the v1.1.0 line:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - base public release remains `v1.1.0`; current patch release prep targets `v1.1.1`
  - issue under investigation came from live duplicate `Bank Ledger -> Money Log` rows after sync replay
- Root cause narrowed and covered locally:
  - a local money-log source window could stay at an older same-identity batch count after remote ledger sync appended an extra repeated occurrence
  - the next local guild-bank money-log read could then treat that already-synced repeated row as new and append it again
  - older locally stored money rows could also be "known" only through the coarse legacy fingerprint while still counting as zero exact hour-level matches, which let a later local money-log replay append a third copy even with no peer online
- Local fix now in the worktree:
  - remote ledger merge now reconciles same-source batch counts for matching visible ledger identities so a later local scan does not reappend the same repeated money row just because it arrived through sync first
  - `Options -> Data` now adds `Dedupe Ledger`
  - `Dedupe Ledger` is review-first: preview counts first, then a `Review Rows` modal with the exact rows to remove, then `Clean Up`
  - cleanup now targets item rows with the same visible ledger date, actor, action, item, quantity, tab, and moved-from values, plus money rows with the same visible ledger date, actor, action, and amount
  - the `Review Rows` modal now provisions a slim scrollbar and expands its text content height so long cleanup lists can be reviewed before applying
  - latest live-cache evidence showed cleanup could keep an older money duplicate whose hour no longer matched `moneySourceSnapshots`; after cleanup cleared transient state, the next money scan could reimport the current Blizzard row
  - cleanup now keeps a source-stable money row when the current money source snapshot can identify a matching visible hour, removes the extras, rebuilds ledger fingerprints, and clears transient batch-count state so the next scan does not regrow the cleaned row
  - local money scans now also bridge legacy coarse money-row precision when the same Blizzard hour-level row is seen again, so older polluted rows do not keep growing by one more copy on each new local scan
  - remote ledger sync now sanitizes outbound manual/scanner `LEDGER_DELTA` payloads and inbound remote merge batches so a peer cache that still contains duplicate visible rows cannot re-contaminate a repaired client
  - follow-up live finding: older clients can still send a polluted payload whose first remaining visible duplicate has a different timestamp than the repaired receiver's kept row; inbound remote merge now seeds the visible-dedupe filter from existing receiver rows before applying the remote batch
  - latest local source-data check found the active Retail cache had `1068` item ledger rows, `0` `itemSourceSnapshots`, and `186` same-visible-date item duplicate groups covering `999` rows; item replay protection now bridges legacy item rows by visible date so shifted timestamps do not regrow the same displayed row
  - `v1.1.1` now forces a one-time Bank Ledger clear during database normalization when `ADDON_VERSION` matches `LEDGER_FORCE_CLEAR_VERSION`, records `meta.ledgerClearedForVersion`, and marks fresh databases as already cleared so later reloads keep newly scanned rows
  - outbound manual and scanner `LEDGER_DELTA` payloads now include the addon version, and inbound ledger deltas are accepted only when the remote version is the same or newer; missing-version or older-version ledger deltas are rejected as `older_version`
  - local Blizzard ledger scans remain the source of truth for real repeated same-identity activity; remote sync is intentionally conservative because it cannot distinguish true identical rows from a dirty peer cache
  - retention settings are active cleanup hooks for Bank Ledger item/money rows and visible audit-history rows on database load, after ledger scans, and on logs/history settings save; they do not currently prune inventory snapshots, Minimums, Requests, or sync-peer history
- Focused verification now green:
  - `.\tools\lua\lua.exe .\tests\spec\store_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua`
- Full suite status:
  - `.\tools\lua\lua.exe .\tests\run_all.lua` passes; the older `tests/spec/item_catalog_target_spec.lua` fixture-writer blocker is not reproducing under the approved run
- Local Retail deploy completed after the current changes:
  - `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json`
  - deployed `GBankManager` and `GBankManager_ItemData` into `C:\Gaming\World of Warcraft\_retail_\Interface\AddOns`
- Recommended next live pass:
  1. Reproduce the old two-client ledger sync path that used to create duplicate money rows.
  2. Confirm the next local money-log scan does not reappend the already-synced repeated row, and also confirm a local money-log replay with no peer online does not grow an older duplicate set by one more row.
  3. With one older client still containing old duplicate ledger rows, run `Sync Ledger` or `Sync All` and confirm a cleaned receiver does not gain those duplicate visible rows even when the older sender's copy has a different timestamp.
  4. Confirm a missing-version or older-version client cannot repopulate ledger rows through `LEDGER_DELTA`; same-version and newer clients should still sync ledger rows normally.
  5. If any older duplicates remain, use `Options -> Data -> Dedupe Ledger`, inspect `Review Rows`, confirm long review lists scroll, and confirm cleanup removes only duplicate same-visible-date item rows or money rows with the same visible ledger date, actor, action, and amount while keeping a source-stable money survivor when available.

### 2026-06-02 v1.1.0 Release Success

- Current repo truth after release:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - release-prep commit used for the public tag: `b93de46` (`chore: prepare 1.1.0 release metadata`)
  - pushed tag: `v1.1.0`
  - release workflow run: `26851324160`
  - GitHub release: `GBankManager v1.1.0`
  - release asset: `GBankManager-1.1.0.zip`
- Release result:
  - `Release to CurseForge` completed successfully
  - the full Lua suite passed inside the release workflow
  - the combined package built successfully
  - the CurseForge upload step succeeded
  - the GitHub Release was created with the combined zip attached

### 2026-06-02 Portable Minimums + History Sync + Peer Table Polish Slice

- Current repo truth at resume:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - current stable release prep version in `GBankManager.toc`: `1.1.0`
  - HEAD at session start of the backlog slice: `353c102`
  - later pre-polish pushed checkpoint before this follow-up work: `cb06993` (`fix: stabilize minimum imports and sync peers`)
  - only pre-existing local noise was untracked `.vscode/`
- Exact GitHub backlog items resolved first before coding:
  - `Add portable Minimums export and import`
  - `Design History sync propagation`
- Confirmed implementation scope from those exact items plus follow-up clarification:
  - Minimums import/export is now a portable JSON payload flow
  - import is review-first, not immediate apply
  - review rows allow last-minute edits before acceptance, including remapping a missing imported Bank Tab to a local tab
  - accepted remote sync should reconstruct the existing `History` tab categories already tracked today
  - do not add new ledger-history or minimum-snapshot-only audit categories
- Local implementation now in the worktree:
  - new `GBankManager/Domain/MinimumsPortability.lua` module exports versioned `gbankmanager.minimums` payloads and parses them back into review rows
  - `Minimums` now has `Export` and `Import` actions
  - import opens a review modal, blocks rows whose imported tab does not exist locally until the user picks a local tab, allows quantity/enabled edits, and stages accepted rows through the existing draft workflow so `Save All` still controls the final write
  - accepted remote `MINIMUMS_SNAPSHOT` payloads now diff previous vs accepted rules and append equivalent local `MINIMUM_CREATED`, `MINIMUM_UPDATED`, `MINIMUM_ENABLED`, `MINIMUM_DISABLED`, and `MINIMUM_REMOVED` audit rows when those outcomes actually occurred
  - live/sync identity is now normalized to `Character-Server` at the builder and peer-storage layers, so login hello, `/gbm debug sync`, and Sync-tab peer rows no longer drift back to `Server-Character`
  - accepted remote `REQUESTS_SNAPSHOT` catch-up sync now also reconstructs existing `REQUEST_*` History rows when the snapshot is what brings a receiver up to date
  - visible History rows now also have a dedicated `HISTORY_SNAPSHOT` sync family that merges only the same `History` page categories already shown today
  - `Options -> Sync` now includes `Sync History`, and `Sync All` now includes that family too
  - this older checkpoint originally made incoming guild hello trigger the same catch-up family set as `Sync All`; the 2026-06-04 ledger sync noise checkpoint supersedes that behavior and makes hello presence-only again
  - `Options -> Sync` now includes an inline red peer-remove control so one bad stored peer can be cleared without resetting the whole guild peer table
  - the Sync peer table now provisions its own slim scrollbar, keeps that scrollbar hidden until the peer list truly overflows, reserves a stable right-side gutter for it, and keeps the delete `X` inside a dedicated trailing action column instead of hugging the outer edge
  - `Minimums -> Import` now opens with a visibly framed focused payload field and keeps the lower review viewport hidden until preview actually succeeds, while parse failures stay in a clean status line
- Verification now green on the current local checkpoint:
  - `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
- Local Retail deploy also completed from this checkpoint:
  - `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json`
- Docs updated in this slice:
  - `README.md`
  - `docs/testing.md`
  - `docs/manual-test-checklist.md`
  - this handoff
- If resuming from here, start with live/manual validation of `Sync History` and the refreshed `Options -> Sync` peer table behavior on two guild clients, then rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before the next code slice

### 2026-06-01 PTR Maintainer + 12.0.7 Support Checkpoint

- Current local checkpoint:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - main addon TOC now advertises `## Interface: 120007, 120005`
  - item-data addon TOC now advertises `## Interface: 120007, 120005`
  - generated item-data TOC rebuilds now also stamp `120007, 120005`
- PTR maintainer compatibility fixes:
  - `Resolve-WoWTarget.ps1` now accepts both `_ptr_` and `_xptr_` for `PTR`
  - `Refresh-ItemCatalog.ps1` now accepts shared-root `Data\wowxptr`
  - extraction now passes `wowxptr` when the local PTR build manifest uses that product alias
- Real maintainer run succeeded for `PTR`:
  - target resolved to `C:\Gaming\World of Warcraft\_xptr_`
  - data resolved to `C:\Gaming\World of Warcraft\Data\wowxptr`
  - build `12.0.7.67808`
  - normalized rows `5968`
  - generated item count `5969`
- Verification:
  - `.\tools\lua\lua.exe .\tests\spec\toc_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\item_catalog_merge_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\item_catalog_target_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\item_catalog_extract_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`

### 2026-06-01 Post-1.0 Checkpoint

- Current repo truth:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - HEAD: `c658dfd` (`chore: prepare 1.0.0 release metadata`)
  - release tag: `v1.0.0`
  - GitHub release: `GBankManager v1.0.0`
  - branch is in sync with `origin/codex/gbankmanager-v1`
  - only local noise should be untracked `.vscode/`
- `v1.0.0` released successfully on 2026-06-01:
  - tag `v1.0.0` pushed successfully
  - `Release to CurseForge` workflow run `26788707133` completed successfully
  - GitHub release asset: `GBankManager-1.0.0.zip`
  - CurseForge upload step succeeded
- Live/manual sync sanity has now passed in a real guild.
- Older sections below this checkpoint are archival and intentionally preserve earlier beta-era resume context.
- Current remaining follow-up is backlog polish, not a known release blocker:
  - passive ledger refresh validation after `/reload` with the bank already open
  - active-view auto-refresh for accepted sync updates
  - portable Minimums export/import
  - possible History sync design

### 2026-06-01 Sync Debug Follow-up

- Current local troubleshooting checkpoint adds `/gbm debug sync`.
- The latest live clue from two-client testing was a `wrong_guild` reject even though both characters were in the same guild; the debug output showed the runtime root could still be keyed as `Unknown Guild`.
- The current local fix now treats `Unknown Guild` the same as `Unknown` across store normalization, sync receive validation, manual sync actions, request publish paths, Minimums publish paths, Sync-tab peer lookups, and `/gbm debug sync`.
- The current local follow-up also refreshes `Options -> Sync` live when guild hello or accepted sync traffic arrives while that tab is already open.
- The current local follow-up also suppresses repeated `Synced ledger delta ...` chat lines when a remote ledger delta is accepted but merges zero new rows.
- The current local follow-up also blocks stale `GUILDBANK_UPDATE_TABS` or `GUILDBANKBAGSLOTS_CHANGED` events from arming an inventory auto-scan when the guild bank is actually closed after `/reload`.
- The current local follow-up now also auto-publishes guild-scoped `LEDGER_DELTA` sync payloads whenever a manual, bank-open, or passive ledger scan appends new ledger rows locally, so other online guild clients do not have to wait for a separate `Sync Ledger` click.
- The current local follow-up now also fixes the live `Options -> Sync` peer list rendering bug: the Sync subtable now assigns a concrete scroll-child and row width instead of relying on anchor-only width resolution that left the peer rows clipped away in the real WoW client.
- The current local follow-up also brings the Minimums add-item modal back into line with the New Request wizard: both now enable the shared selector's crafted-quality icon path, so crafted search results and the selected-item summary show the same quality icons in both surfaces.
- The current local follow-up also fixes two Minimums add-flow regressions: the typed `Minimum` value now carries from the add-search modal into `Minimum Details` instead of resetting to the default, and the lower add-search controls no longer jump right when a crafted-quality selected-item icon appears.
- Completed feature note:
  - global `Suppress Routine Chat` option now lives under `Options -> Appearance`
  - default scope mutes routine scan/sync status or progress messages only
  - `/gbm debug ...`, in-game test output, warnings, and real error messages remain visible
  - add active-view auto-refresh when accepted remote sync mutates Requests, Minimums, or Bank Ledger data
  - preferred scope: repaint only when the relevant view is currently open, while preserving filters, selected row, and scroll where possible
  - likely moderate effort because each view already has a refresh path, but Requests and Bank Ledger currently reset scroll or selection state during naive refreshes
  - add History sync so audit and history-tab entries can propagate across clients the same way requests, minimums, and ledger data do
  - likely moderate effort because history currently acts like local side-effect logging in several flows and would need a dedupe or merge contract before cross-client replay is safe
  - add portable Minimums export/import so officers can back up one guild's stock-policy configuration and optionally apply it in a different guild without re-entering every rule by hand
  - likely moderate effort because the format should preserve tab-scoped rows, enabled state, and crafted-quality item identity while making guild targeting an explicit import choice instead of a hardcoded source-guild lock
- The new debug command prints:
  - local `name`, `characterKey`, `guild`, and active guild key
  - the last decoded sync envelope (`type`, `sender`, `distribution`, `guildKey`, `actorName`, `actorCharacterKey`)
  - the last sync decision (`accepted`, `category`, `reason`, `peerCharacterKey`, plus sender and guild fields)
  - the stored peer rows and `peerKeys` for the active guild
- Focused regression coverage now also checks:
  - `/gbm debug sync` chat output in `tests/spec/slash_commands_spec.lua`
  - rejected request snapshots now persist `lastSyncDecision.category= requests_snapshot` and `reason= actor_sender_mismatch` in `tests/spec/sync_spec.lua`
  - sync hello traffic and request snapshots both bootstrap a client whose saved root still uses the placeholder `Unknown Guild`
  - `tests/spec/ui_options_spec.lua` now verifies the open Sync tab repaints immediately when a new guild peer hello arrives
  - `tests/spec/ui_options_spec.lua` now also verifies the Sync peer subtable gets a concrete drawable width so stored peers render visibly in the live client
  - `tests/spec/ui_minimums_spec.lua` now also verifies the Minimums add-item selector shows crafted-quality icons in both result rows and the selected-item summary, matching the Requests selector contract
  - `tests/spec/ui_minimums_spec.lua` now also verifies the add-search modal preserves a typed minimum through the handoff into `Minimum Details` and keeps the lower controls horizontally stable after a selection resolves
  - `tests/spec/sync_spec.lua` now verifies duplicate no-op ledger deltas stay quiet in chat while still being accepted
  - `tests/spec/sync_spec.lua` now verifies closed-bank reload noise cannot arm an inventory scan from stale guild-bank tab or bag-slot events
  - `tests/spec/bank_ledger_scanner_spec.lua` now verifies ledger scans automatically publish one guild-scoped sync delta per merged item-log or money-log target while repeated no-change reruns stay quiet
  - `tests/spec/bank_ledger_spec.lua` still verifies a later local ledger scan does not duplicate a row that was already merged from remote sync traffic
- Historical live clue to revisit only if sync regresses:
  - the login hello chat line once reported `Stormrage-Zirleficent`, which suggested a remaining `Server-Character` identity path even though peer storage is supposed to stay `Character-Server`
  - if live request sync ever fails again while tests are green, start by running `/gbm debug sync` on both clients and compare `characterKey`, `actorCharacterKey`, `peerCharacterKey`, and `peerKeys`

### 2026-06-01 Local Troubleshooting Update

- Current repo truth at session start:
  - worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
  - branch: `codex/gbankmanager-v1`
  - HEAD: `65cde0a` (`chore:update-release-actions-for-node24`)
  - branch was in sync with `origin/codex/gbankmanager-v1`
  - only pre-existing local noise was untracked `.vscode/`
  - published beta remains `v0.9.0-beta.4`
- Full local verification was green before this troubleshooting slice:
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua`
- Live/manual sync finding:
  - request sync could be rejected on a fresh client when the local SavedVariables root was still under `Unknown`, even though the incoming payload had the correct guild key.
  - local fixes now prefer live guild info when resolving the active guild and migrate an `Unknown` root into the real guild key before valid guild-scoped request traffic is applied.
- Request-only UX follow-up now in the local worktree:
  - `/gbm` for request-only users opens the trimmed Requests shell instead of auto-opening the request wizard.
  - request-only sidebar navigation is limited to `Requests`, `Options`, and `About`.
  - request-only `Options` is limited to `Appearance`, `Sync`, and `Data`.
  - `/gbm request` still opens the request-creation wizard directly.
- Focused local verification for this slice should include:
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`

### 2026-05-28 Sync Rollout Update

- AceComm sync rollout is now through Task 5 on top of the published `v0.9.0-beta.3` checkpoint.
- Landed commits in this phase:
  - `ea8cfd2` `feat:add-guild-root-and-acecomm-transport`
  - `56302f2` `feat:target-request-sync-by-guild-policy`
  - `17a7737` `feat:add-minimum-and-ledger-sync-families`
  - `ef244b9` `feat: add sync peer history and options tab`
- Latest pushed checkpoint adds:
  - officer-authoritative `MINIMUMS_SNAPSHOT` publish on `Minimums -> Save All`
  - inbound minimum snapshot acceptance or rejection by Guild Info policy
  - `bankLedger.MergeRemoteDelta(...)` so incoming `LEDGER_DELTA` traffic merges without advancing local scan freshness
  - persisted sync-peer history in new `GBankManager/Sync/PeerState.lua`, keyed by guild so cross-guild data cannot bleed between characters
  - new persisted `Options -> Sync` tab that shows known peers, last-alive timestamps, and last message type for the active guild
  - removal of the retired outbound `AUTH_POLICY_SNAPSHOT` send path so guild policy remains Guild-Info-only
  - deterministic live-smoke seeding for request sync even when the ambient auth policy denies raider request submission
- Verification currently passing on this local checkpoint:
  - `.\tools\lua\lua.exe .\tests\spec\sync_peer_state_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_minimums_sync_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\auth_spec.lua`
  - `.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua`
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
- Next implementation target after this checkpoint:
  - continue the sync rollout with release or install sanity against the published beta package
  - then review small polish follow-ups for `About` and `/gbm help`

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Remote tracking: `origin/codex/gbankmanager-v1`
- Latest pushed branch commit: `ef244b9` (`feat: add sync peer history and options tab`)
- Latest checkpoint in this phase: the shell-polish checkpoint is now extended by a cleaner `Bank Ledger` import pass plus the richer `Data` options slice. The addon now scans guild-bank item logs and money logs as a follow-up stage of the established guild-bank scan flow, uses the configurable `Scan Interval` as both the ledger throttle and the guild-bank-open auto-scan throttle, stores append-only ledger deltas locally, exposes a shared-table `Bank Ledger` surface with item-vs-money modes, action filters, a preset date-range dropdown, CSV export, and usage summaries, and keeps retention, scan-interval, and repair-threshold controls in the trimmed `Data` options tab with visible save feedback plus destructive cleanup actions. `Mute Silvermoon Citizen` now lives under `Options -> Appearance` and saves immediately on toggle. The ledger importer now follows the `GuildBankLedger`-style query and merge pattern more closely: it queries all accessible item logs plus the fixed Blizzard money-log slot in one burst, debounces `GUILDBANKLOG_UPDATE`, keeps the visible guild-bank tab stable during import, normalizes Blizzard’s relative log timestamps against server time, and uses session batch counts so same-identity visible batches can shrink and regrow without dropping new rows. If older local ledger data was polluted by the previous scanner/cache behavior, `Options -> Data -> Clear Guild Bank Log Data` is the supported one-time recovery path. The manual `Scan Bank` button still forces the ledger follow-up even when the configured `Scan Interval` would normally throttle auto scans. The implementation plan doc for the shell pass still lives at `docs/superpowers/plans/2026-05-23-gbankmanager-ui-shell-polish-implementation.md`.
- The pushed UI review and item-display checkpoint makes bundled item-data metadata authoritative for crafted tier rendering everywhere the addon shows crafted items, uses the same semantic `craftedQualityMax` family rules across Inventory, Requests, Minimums, Exports, and request search/details, and routes non-inventory crafted-quality visuals through dedicated texture-backed atlas slots instead of inline FontString atlas markup so true two-rank items stop drifting back to stale compact chat icons, missing icons, or duplicated inline markup. Item-aware rendering now relies on the bundled addon data path before live `C_TradeSkillUI` reagent-quality responses, so icon families stay stable before and after scans. The same checkpoint also strips legacy `[Tn]` prefixes from shared search labels, keeps Minimums and Requests rows from reintroducing inline tier markup after bundled backfill, forces request officer-table rows to backfill against bundled metadata before rendering, prefers bundled crafted-quality fields over stale saved request/minimum/search-catalog data, suppresses the post-create auto-selection that was leaving a highlighted request row after creation, narrows the request reason input to avoid preview overlap, aligns the `Data` dropdown row, adds the new repair-threshold plus ambient-chatter controls to `Options -> Data`, slightly deepens the Appearance chrome for the relocated UI Scale slider column, adds responsive relayout for the Exports action cards under shell resize, and updates export rows plus the manual shopping list so `Qty To Buy` subtracts `Excess Qty`.
- `UI Scale` now relayouts the dashboard shell as part of the same appearance refresh path instead of only resizing the frame and shared table density. The four metric cards plus the top-items, recent-activity, and quick-actions dashboard panels now grow and shrink with shell scale, and regression coverage for that behavior lives in `tests/spec/ui_options_spec.lua`.
- The latest polish follow-up also rebalanced the options layout and dashboard actions: `UI Scale` now sits in the right-hand slider column above shell and modal opacity, `Show Minimap Button` now lives directly beneath the theme preset grid, the `Data` dropdown labels were realigned to one row inside panel chrome, and the dashboard `Quick Actions` row is now trimmed to `Add Minimum`, `Create Request`, and `Export Data`.
- The latest command and polish follow-up also tightens the remaining shell details: `/gbm` now opens the UI the current player can access instead of starting a scan, `/gbm help` prints the supported player-facing slash-command list without exposing debug or test commands, request-only access now opens the request wizard immediately, Blacklist keeps extra footer padding under the parsed summary line, `Options -> Data` now uses equal-width centered clear-data buttons, and `Exports` plus `Request Details` now force the same corrected reagent-style two-rank quality icons even when the source icon was already stored as chat-markup.
- The latest local copy/export follow-up also makes `Bank Ledger` CSV timestamps readable, adds a filtered `Inventory` CSV export entry point through the shared modal, shortens the `History` and `Bank Ledger` page subtitles, clears the old `Options` page subtitle, and updates `About` to show the tagged version plus local build stamp, `Author: Zirleficent-Stormrage`, a separately spaced `Guild` line, and `/gbm help`.
- The current local onboarding checkpoint adds role-aware first-run walkthroughs for both full-shell and request-only users. The walkthrough now auto-opens the first time the UI is opened from `/gbm` or the minimap button, keeps request-only users on the compact requests surface, adds a full-shell `Replay Onboarding` control under `Options -> Appearance`, and now uses a simpler footer with no `Skip` button plus a step-one-only `Do Not Show Again` action.
- The latest onboarding and sync UX refresh makes the onboarding modal draggable while open and recentered on every reopen, deepens the permissions and blacklist copy so it explicitly points back to Guild Info and guild-backed parsed results, and updates request guidance to mention synchronization between online addon users.
- Exports now send `Auctionator` and `TSM` straight to the output modal without the old all-vs-missing filter prompt, while `CSV` and `Shopping List` keep their existing direct flows.
- `Options -> Sync` now uses a peer table with `Character`, `Last Time Seen`, and `Last Time Synchronized`, while `/gbm sync`, `/gbm sync requests`, `/gbm sync minimums`, `/gbm sync ledger`, and `/gbm sync all` now route through the same 60-second manual sync cooldown path. Self-origin sync payloads are ignored so manual sync no longer echoes accepted-sync chat noise back to the sender client.
- Request create, approve, reject, fulfill, reopen, cancel, and delete actions now publish one guild-scoped addon sync message instead of whispering every resolved guild recipient, which stops live `No player named ...` roster-spam errors when managing requests.
- The central addon-message dispatcher now rejects non-`GUILD` sync traffic before decoding or applying it, so same-guild payloads delivered over `WHISPER` can no longer mutate requests, request snapshots, minimums, or ledger state.
- `Options -> Appearance` now leaves enough chrome behind `Replay Onboarding`, and `Options -> Data` now moves `Repair Threshold` back into the left column with helper text explaining the repair-versus-withdrawal cutoff before the lower save and clear-data sections. The `Data` panel chrome is now also deep enough to keep the full clear-data button stack inside the visible background.
- The latest crafted-quality follow-up now makes the actual visible contract explicit in code: bundled rank and family-size metadata stay authoritative, Inventory no longer drops `tierIconAtlas` while rows flow through the shared table renderer, and non-inventory item-display surfaces now prefer the bundled canonical single-silver-diamond / gold-pentagon family for true two-rank crafted rows before consulting live reagent-quality atlases, with the older reagent-medal atlases left as the last fallback.
- The latest slash-command polish retires the old `/gbm auth` player-facing entrypoint, keeps `/gbm help` focused on supported player commands, and avoids WoW chat escape collisions by rendering sync subcommands with slash separators instead of raw pipe characters.
- The current local checkpoint also extends `/gbm debug quality <itemID>` so live crafted-quality mismatches can print bundled rank and atlas data, the live reagent-quality payload, the final shared item-aware atlas, the final non-inventory atlas, and the final texture-display atlas directly into chat after `/reload`.
- The current ledger-debug checkpoint adds `/gbm debug ledger` for copy-friendly live scanner diagnostics and strengthens the scan coordinator so any direct ledger scan request made during an inventory scan is queued for the inventory-to-ledger handoff instead of querying Blizzard item or money logs early. If a visible manual scan follow-up is already queued, later passive requests cannot turn that follow-up silent.
- The latest ledger-dedupe fix addresses the live `/gbm debug ledger` evidence where Blizzard APIs returned raw item and money rows but GBankManager still merged `0 item rows, 0 money rows`: normal time-bearing rows now dedupe with their time identity, and the merge now uses a `GuildBankLedger`-style session batch-count comparison when the same source is rescanned. This keeps a later same-actor/same-item/quantity or same-actor/same-money-amount transaction appendable without requiring legacy-cache preservation.
- Product direction changed on 2026-05-28: stop iterating on visible crafted-quality tier icons as the long-term UX. The approved shared item-hyperlink migration is now implemented and pushed: visible item tables and details use shared hyperlink-style item display, quality is inline with the item name, visible tier columns are removed from the migrated surfaces, and numeric `Tier` values remain available for CSV exports. The execution plan for that pivot lives at `docs/superpowers/plans/2026-05-28-gbankmanager-item-hyperlink-migration-plan.md`.
- The completed migration includes `Domain/ItemDisplay.lua`, optional `itemLink` and `itemString` catalog hydration/storage, bundled extraction/export/bootstrap preservation for those optional fields, Minimums/Requests/Request Details/New Request/Exports shared item display, and live-regressed crafted-quality atlas behavior for the required anchor set including `244559`.
- The repo now also includes a first tagged-release automation path for the single-project CurseForge package: `.github/workflows/release-curseforge.yml` runs the full Lua suite on `v*` tags, builds one combined zip containing both `GBankManager/` and `GBankManager_ItemData/`, uploads it to CurseForge using protected GitHub Actions configuration (`CF_API_TOKEN`, `CF_PROJECT_ID`, optional `CF_GAME_VERSION_IDS`), and attaches the same zip to the matching GitHub Release.
- The CurseForge publish script now also forces `gameVersions` to serialize as an array even when only one resolved version id is present, matching the current CurseForge upload API requirement and preventing single-version beta or release uploads from failing before the GitHub Release step.
- A repo-local release skill now lives at `docs/skills/gbankmanager-release-operator/SKILL.md`; use it when asked to handle a normal GBankManager publish or to diagnose and recover from a failed release workflow.
- The beta release automation path is now proven through `v0.9.0-beta.3`. The tag ran `.github/workflows/release-curseforge.yml` successfully, published the CurseForge beta upload step, and attached `GBankManager-0.9.0-beta.3.zip` to the GitHub prerelease at `https://github.com/ziriuso/gbankmanager/releases/tag/v0.9.0-beta.3`.
- The addon communication review now includes a transport-safety fix for oversized sync tables: request/auth sync payloads are chunked before `C_ChatInfo.SendAddonMessage` and reassembled before the existing `CHAT_MSG_ADDON` handlers run, so they stay within WoW's base addon-message payload limit without changing the normal small-message hello path.
- Current repo status at handoff time: `origin/codex/gbankmanager-v1` is at the pushed checkpoint `ef244b9`, the full Lua suite passed on this sync rollout checkpoint, and local status now includes this refreshed handoff file plus untracked `.vscode/`.
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: on 2026-05-28, `.\tools\lua\lua.exe .\tests\run_all.lua` passes in this worktree after the ledger import stabilization and `v0.9.0-beta.3` release metadata bump. The older `item_catalog_target_spec.lua` fixture-writer blocker described in the previous handoff snapshot is still no longer reproducing here.

## Read First

1. `README.md`
2. `docs/testing.md`
3. `docs/manual-test-checklist.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`
6. `.\tools\lua\lua.exe .\tests\run_all.lua`
7. `docs/ui-reference/mockup-reference-manifest.md`
8. `docs/macos-readme.md` when resuming from a MacBook travel setup

## Current Repo State

- Branch is committed and pushed through the sync peer-history checkpoint `ef244b9`; current local status includes this refreshed handoff file plus untracked `.vscode/` user/IDE state.
- The branch includes the release automation slice (`12780d6`, `f44a4cb`), the repo-local release operator skill (`eab477b`), the MPL-plus-assets licensing docs (`fbab6e3`), the item-display/crafted-quality migration checkpoint (`6debadd`), the ledger import stabilization checkpoint (`19ce18e`), the beta release metadata checkpoint (`2199c4c`), the AceComm transport and guild-root storage slice (`ea8cfd2`), targeted request routing (`56302f2`), minimums plus ledger sync families (`17a7737`), and persisted peer history with `Options -> Sync` (`ef244b9`).
- The latest successful published beta tag is `v0.9.0-beta.3`.
- The branch already contains the indexed item-search redesign, procurement-only catalog reduction, and the Minimums modal workflow cleanup.
- The generated bundled item payload lives in the shipped addon `GBankManager_ItemData/`.
- Local maintainer-only catalog assets under `tools/catalog/runtime/` remain intentionally git-ignored.

## Current Product State

### Stable Recent Work

- Shared item search is now responsive in live WoW after cutting the shipped search universe down to current-expansion procurement categories.
- Minimums now uses a centered modal workflow for add/edit details instead of the older footer editor.
- Existing saved Minimums rows show Bank Tab as an auto-populated read-only value in the details modal; only new rows choose Bank Tab.
- Minimums defaults to `Show All`.
- Existing Minimums rows can be edited through the centered modal with the current tab prefilled.
- Shared item search is used by both Minimums and Requests and requires a confirmed catalog selection for full-shell actions.
- Crafted tier can now backfill from the bundled search catalog when scan or snapshot data omits it.
- Scan snapshots now persist tab-scoped `itemRows` in addition to aggregate `items`, and Inventory plus Minimums `Show All` render one row per bank tab with per-tab quantities.
- Inventory and Minimums now share the same table layout: `Item ID`, `Tier`, `Item`, `Bank Tab`, `Current`, `Restock`, and `Minimum`, with a wider Item column consuming the old right-side whitespace.
- Minimums uses the shared header/filter row instead of the old bottom search box, and its footer is now a compact transparent action strip with `Add`, `Save All`, `Enabled Only`, and `Show All` controls.
- The full-shell request surface is now `Requests`: workflow actions remain visible with more bottom spacing, inline request creation is hidden, shared table search is enabled, and the admin table exposes date requested, requestor, item ID, tier, item name, quantity, approval, fulfillment, and note.
- `/gbm request` now opens a separate end-user request workflow panel with own-request status rows and a `New Request` wizard entrypoint.
- Requests never auto-approve. Officers/admins cannot approve their own requests; the Guild Master can approve their own request only through an explicit workflow approval action.
- `/gbm request` now uses a smaller compact window with `Guild Bank Manager` in the header, an own-request table (`Item ID`, `Item Name`, `Quantity`, `Status`), row-click details, pending-request cancellation for authors, and a three-step item -> quantity/reason -> review wizard.
- `Requests` now uses the same request-list/details pattern, with workflow actions available from the details popup.
- Request details now label the Decision Note input, align detail/readback values to fixed modal columns, and keep the details modal open after status changes.
- Approving a request requires an approver-selected Bank Tab, stores the Decision Note and Bank Tab on the request, and immediately saves/updates an enabled tab-scoped Minimums rule for the requested quantity.
- Request details now block table click-through, keep fixed label/value rows with tighter label/value spacing, show Requested By above Date Requested, show Updated By, Date Updated, and Decision Note at the bottom of the detail list, hide the decision-note editor after approval or denial, and request audit history normalizes actor tables into character names.
- Requests no longer shows the old top workflow actions box. Actions live in the details modal, and the bottom filter strip switches between `All`, `Pending Approval`, and `Pending Fulfillment`.
- Requests now also includes a `Completed` filter plus a left-side `Refresh` button beside `Add Request`.
- Approved open requests are now auto-marked `FULFILLED` by a guild-bank scan when scanned inventory for the requested item meets the requested quantity. Fulfillment records `fulfilledBy = Bank Scan` and Date Fulfilled.
- Request dates now display with an abbreviated timezone and no `(Local)` suffix.
- Shared table scrollbars now sit just outside the table viewport so the table frame ends before the bar and rightmost columns are not overlapped.
- Exports now uses the shared table plus a bottom action strip. The table shows `Item ID`, `Tier`, `Item Name`, `Bank Tab`, `Amount to Stock`, and `Excess Stock`.
- Exports now presents `Auctionator*`, `TSM*`, `CSV`, and `Shopping List` as four action cards on that bottom strip while keeping export formats unchanged, with a shared `* Does not provide Quantity in Export.` note under the cards.
- `Excess Stock` now shows either `None` or the alternate guild-bank tab with the highest quantity, and the stocked-elsewhere detail modal still lists every alternate tab and quantity.
- Exports now renders crafted-quality icons in the visible `Item Tier` column while keeping numeric tier values available for CSV-style outputs.
- Auctionator export now emits the modern shopping-list line format instead of the older quantity or quality overloaded string.
- Request deletion is now a distinct permission capability, and authorized users can delete requests from the request-details workflow popup.
- Requests now highlights the active bottom filter, right-aligns `All`, `Pending Approval`, `Pending Fulfillment`, and `Completed`, keeps a far-left `Add` launcher, and uses the shared table height without the `Date Fulfilled` filter overflowing.
- The guild auth policy string now carries the shared Restock Default plus updater metadata. Guild Info pull now refreshes those values into the local Options state, auth-policy updates now write History rows, and those auth-policy rows are now visible in the History view.
- Guild-shared blacklist membership now comes from appended `[GBMBL]` officer-note tags instead of the Guild Info policy string, and `Options -> Blacklist` is now a read-only instructions-plus-list surface with a `Refresh` action that reparses tagged guild members from officer notes on demand and on guild-roster refresh.
- Dashboard `Ready to Buy` mismatch investigation did not land a code fix in this slice. Obvious local machine paths did not reveal a live SavedVariables file, and the dashboard card count plus Exports row count both currently derive from the same demand-plan shape in code, so this should be reproed live before changing code.
- Opening the guild bank now auto-starts a scan only when at least 10 minutes have elapsed since the last successful scan, and the reopen path now keeps retrying long enough for delayed tab metadata instead of giving up after the first short burst. Fresh-open auto scans now wait briefly between queried tabs and ignore suspicious partial snapshots when a previously populated tab reads empty, so a cold automatic scan cannot replace a fuller saved snapshot. Bank-open now also forces one ledger scan pass even when ledger freshness is inside the configured interval; if the inventory snapshot is rejected, that queued ledger scan still continues. Manual scan button or slash behavior is unchanged.
- Synced request create and update messages now append local History rows on receiving clients, approved request sync recreates the tab-scoped Minimums side effect on receivers, and request conflict resolution now prefers higher-authority updaters before timestamp tie-breaks.
- CSV, Auctionator, and TSM export modals now remove the nested inner text box, and the output area now uses a dedicated scrollable edit-box surface so `Select All` and manual mouse selection both target a real copyable field. The old `Copy` button has been removed.
- Auctionator and TSM now use the choice label `Not In Guild Bank` for the missing-only path.
- Exports now includes a movable `Shopping List` window with one-session checklist strike-through rows, plain checkbox marks, and an explicit `Does not sync back to addon.` note.
- The shell navigation is now ordered as `Dashboard`, `Inventory`, `Minimums`, `Requests`, `Exports`, `History`, `Bank Ledger`, `Options`, and `About`, with refreshed per-tab icons and a live `Bank Ledger` surface instead of the older placeholder.
- Minimums rows with unresolved `GLOBAL` Bank Tab now sort to the top in orange, open into an editable Bank Tab picker, and `Save All` blocks with `Bank Tab must be set on Orange Rows.` until the row is corrected.
- Approved open requests that already carry a bank tab but are missing `minimumRuleKey` now self-heal on refresh by creating or rebinding the matching tab-scoped Minimums rule automatically. Only the truly tab-less legacy requests still surface as orange repair rows.
- Approved open requests that lost both `minimumRuleKey` and request-side bank-tab data now attempt one more self-heal: if there is exactly one enabled tab-scoped Minimums rule for that item, the request binds to that existing rule automatically instead of surfacing a duplicate orange orphan row.
- The auth policy string now compacts updater identity with a hash token instead of storing the full updater name in Guild Info, while still rehydrating a real updater name locally when the addon can infer it from live or previously known policy state.
- Compact auth-policy imports no longer carry blacklist membership. Guild-shared blacklist membership now comes from appended officer-note tags, while learned reasons stay local and continue to sync through addon auth snapshots.
- Blacklist entries now normalize to `Character-Server`, migrate legacy server-first ordering, and render in a read-only Blacklist tab that explains the `[GBMBL]` workflow instead of trying to write officer notes from inside the addon.
- Crafted-quality rendering now keeps one inline text contract on purpose: Inventory, Minimums, Requests, Exports, request details, and search selectors all use the stable compact chat-icon family for visible text markup, while texture-only consumers can still resolve the brighter reagent-quality atlas family separately.
- The appearance foundation is now live through a token-backed theme manager with local-only presets (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), a single `UI Scale` control that drives both shell scale and shared table density across a 90%-120% range, built-in WoW `UISliderTemplate` sliders for shell and modal opacity, collapsed-nav icons, stronger active-state glow for nav plus workflow filter buttons, surface-only opacity treatment so content stays crisp, per-theme crest/logo art, a custom minimap launcher, and an appearance toggle that can hide the minimap launcher locally.
- The 2026-05-23 shell-polish implementation pass is now layered on top of that foundation: sidebar nav buttons now expose a softer `nav-soft` family plus a stronger selected-state contract, dashboard and table surfaces now use flatter shared shell variants, primary/secondary/destructive actions expose the shared slimmer `action-slim` family, tabs expose `segmented-soft`, and key modals now use the cleaner `modal-sheet` surface variant instead of the older heavier boxed modal shell.
- The top header now follows the cleaner toolbar-band direction more closely and renders scan timestamps with timezone abbreviations such as `EDT` or `EST` when a scan exists.
- Shared shell surfaces have now been simplified further: the toolbar header drops its full framed top or side edges, the main content band drops its extra enclosing border box, flatter panels, cards, and soft nav buttons no longer draw the older inset header-strip chrome by default, and the flatter shell surfaces now stop relying on backdrop borders for their shape.
- The current table follow-up on top of that shell pass now pushes structure into contrast instead of box lines: filter bands keep a single separator, search inputs use the dedicated `input` surface again instead of being repainted to the shell background, and alternating table rows now use stronger odd/even token contrast with softer bottom-only separators instead of boxed side edges.
- That same table slice now also insets filter inputs slightly inside each column so adjacent search boxes keep visible spacing, and History now keeps `Old Value` plus `New Value` in a row-click `History Details` modal instead of forcing those long fields into the visible grid.
- The latest control-consistency slice on top of that table pass now normalizes interactive surfaces further: neutral footer/action-strip buttons sit forward from parent panels more clearly, request/minimums/options Bank Tab or rank pickers use a dedicated select-style trigger instead of recycling the same muddy button chrome, export action-card CTAs now share one primary treatment, and dashboard quick-action labels can wrap instead of overflowing longer names.
- The shell fidelity rewrite is now underway on top of that foundation: the main shell, sidebar, header, nav buttons, metric cards, export cards, and modal-capable panels now expose explicit surface/button variants plus reusable art layers instead of relying on one generic boxed treatment.
- That shell rewrite now also covers the centered branded About panel, dedicated table header/filter/viewport surfaces, semantic alternating row tokens, and shared button variants across request and Minimums workflows.
- The default `Default` preset is now darker and closer to the mockup baseline, dashboard quick actions now use icon-led primary buttons, the sidebar now carries theme-specific crest treatment above the nav stack, and appearance controls now render through built-in WoW `UISliderTemplate` widgets while preserving direct drag and stepper behavior.
- The sidebar footer now uses a theme crest/logo only. The older character-plus-guild identity card is gone, the crest hides entirely when the sidebar is collapsed, and the shipped crest art is cropped with texture coordinates so the visible logo fills more of the footer zone without distortion.
- `Options` now uses the trimmed five-tab shell (`Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, `Data`) instead of the older longer settings stack.
- The request-only modernization pass is underway: the member `New Request` flow now has a three-step progress rail, a live preview card, quantity/reason labeling, and quantity steppers while preserving the existing request persistence and sync path.
- Appearance sliders now support direct slider interaction in addition to `+` / `-` stepping, and opening `Options` proactively reloads the current Guild Info auth policy before populating the visible auth controls.
- Two-rank crafted items now keep that surface-specific icon treatment consistently across Exports, the manual shopping list, request review, and request details, and appearance sliders now stop dragging cleanly even when the mouse is released off the bar.
- Sync now keeps self login hello silent while still reporting compact chat feedback for accepted incoming updates and ignored forged payloads without writing per-step noise into chat.
- The shell now participates in top-level window ordering so other dragged addon or Blizzard UI can come above it, and clicking back onto the shell or its registered modals brings `GBankManager` back to the front.
- The shell now defaults to a lower dialog stratum, keeps shared columns fitted inside the shell viewport, clamps shared table height so bottom action strips stay inside the window, hides zero-range scrollbars on Requests and Exports, applies shell or modal opacity through backdrop and art layers instead of whole-frame alpha, keeps the top-bar scan plus status controls separated at smaller scales, and keeps the shopping list plus Auctionator export output aligned with the live product expectations.
- The floating manual shopping list now lives independently from the main shell, survives tab switches and shell close, remembers its moved position locally, and keeps low-tier crafted icons normalized even when the source row has no live stock snapshot.
- Dashboard now uses four metric cards (`Last Scan`, `Pending Requests`, `Ready To Buy`, `Critical Shortages`) plus dedicated `Top 10 Most Used`, `Recent Activity`, and `Quick Actions` panels.
- `Bank Ledger` is now the centralized guild-bank log workspace. It captures append-only deltas for item logs and money logs, normalizes them into the shared table shell, filters by action and date range, exports filtered CSV, shows item rows as `Date`, `Who`, `Action`, icon `Tier`, `Item`, `Quantity`, `Tab`, and `Moved From`, and keeps the footer summaries trimmed to item movement plus gold totals over the chosen date range.
- `Options` now trims to five tabs: `Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, and `Data`. `Data` owns ledger retention, audit-history retention, and the shared `Scan Interval` that throttles both guild-bank auto-scans and ledger rescans.
- `Options -> Data` select controls now open real WoW menu-backed dropdowns. They no longer fake selection by cycling values in place on every click, and the same tab now exposes confirmation-gated cleanup for guild-bank logs, guild-bank inventory snapshots, and completed request history.
- `Bank Ledger` now uses the same real dropdown path for its `Action` filter instead of cycling values on click.
- Live follow-up exposed two WoW-runtime mismatches that the desktop Lua harness did not catch at first: frame objects in the client do not satisfy the old plain-table dropdown guard, and some clients do not expose the `os` helpers that were used in ledger timestamp normalization. The dropdown/open path now validates WoW frame methods instead of `type(frame) == "table"`, and ledger plus UI timestamp formatting now prefer `_G.time` / `_G.date` with guarded fallbacks so live scans can finish instead of stopping after the start message.
- The minimap launcher now behaves as a true toggle: first click opens the addon, and clicking it again while the shell is already open closes the shell.
- `Minimums` and `Requests` now reuse the same flatter footer-strip fill and opacity treatment as `Bank Ledger`, and the `Requests` bottom filters are visually ordered `All`, `Pending Approval`, `Pending Fulfillment`, then `Completed`.
- `Options -> Appearance` and `Options -> Data` were resized so their lower controls and save actions stay inside the visible chrome.
- Dashboard metric cards now also expose dedicated icon slots, and Exports action cards now expose dedicated icons plus shorter CTA labels closer to the target mockup.
- The later dashboard-only expansion that added structured row widgets, a dedicated critical-shortages lower panel, richer quick-action cards, and a footer legend strip was rolled back one iteration because the live result still did not match the mockup closely enough.
- The honest state of the UI pass is that the scaffolding is strong, reusable, and worth keeping, but the addon still does not visually match the supplied Alliance art. The next meaningful UI milestone is an addon-local art pack to support the shell, cards, nav rail, and panel trims directly.
- The in-repo visual reference source of truth now lives in [docs/ui-reference/mockup-reference-manifest.md](../../ui-reference/mockup-reference-manifest.md), which preserves the screenshots and screen-level targets supplied in the working thread.
- The repo now also ships a dedicated macOS travel and setup guide in [docs/macos-readme.md](../../macos-readme.md) for clone, worktree, Lua-runner discovery, WoW path detection, and manual AddOns deployment on a default Mac install.
- Minimums staged rows now group at the top, expose `ADD` / `EDIT` / `DELETE` badges, show a staged-change summary in the footer, and reveal `Revert All` only while pending changes exist.
- Dashboard `Top 10 Most Used` now uses ledger-backed withdrawal totals first and only falls back to older history-driven ranking behavior when the ledger has no usable withdrawal rows yet.
- Guild-bank open now starts a direct ledger rescan whenever ledger data is stale but the inventory snapshot is still inside the configured scan interval, so stale logs do not wait on a second inventory pass.
- Guild-bank ledger scans now report both start and finish chat status, including merged item-row and money-row counts, so live validation can distinguish between a stalled scan and a completed zero-row pass.
- Scanner-originated item-log merges now opt into the same trusted rotated-window append path used by money logs, so a live guild-bank log window that fully rotates to new rows can append those rows instead of getting stuck behind a stale same-size source snapshot guard.
- Bank Ledger now treats a clean log reset as acceptable recovery for stale or poisoned local ledger caches. Use `Options -> Data -> Clear Guild Bank Log Data` if older local history blocks validation, then `/reload` and rescan from the clean batch-count merge baseline.
- The ledger scan coordinator now follows the working `GuildBankLedger` cadence more closely: pending ledger scans cannot start from tab-update noise while the main inventory scan is still running, and passive refresh self-chains after active ledger scan completion instead of arming the next cadence timer immediately after scan start.
- `/gbm test unit` now also covers blacklist normalization, officer request-queue prioritization, and unresolved minimum repair-row ordering, with persisted results under `GBankManagerDB.testing.inGameUnit`.
- `/gbm test smoke` now seeds deterministic request-access auth and clears stale request/minimum selector state before its gating checks, so live guild policy or leftover UI selections do not create false negatives. `/gbm test unit` also reloads the crafted-quality helper if the module registry lost it, matching the UI modules' existing fallback behavior.
- `Options -> Auth` now includes a `Select All` helper for the compact policy string, and the smoke lane now exercises the live Minimums modal handoff plus a hard reset of request confirmed-selection state before its gating assertions.
- History table rows now sort newest-first by timestamp, so approvals, minimum edits, and auth changes surface in descending order in the live History view.
- Request creation now reparses guild-backed blacklist state before submit, so newly tagged blacklisted members are denied request creation as soon as the refreshed officer-note parse is available on that client.
- Maintainers now have repo-local catalog status and deployment helpers plus `tools/catalog/Open-ItemCatalogMaintainer.ps1` for target selection, saved sync status, refresh, and deploying both addon folders into `Retail`, `PTR`, or `Beta`.

### Current Navigation

- `Dashboard`
- `Inventory`
- `Minimums`
- `Requests`
- `Exports`
- `History`
- `Bank Ledger`
- `Options`
- `About`

### Current Search/Catalog Constraints

- Bundled search data is intentionally scoped to current-expansion procurement items only:
  - `Consumables`
  - `Containers`
  - `Gems`
  - `Reagents`
  - `Item Enhancements`
- Name search waits for two typed characters before activating.
- Requests and Minimums currently depend on the bundled sibling addon `GBankManager_ItemData`.

## Confirmed Next Work Order

Work these in the exact order below unless a new blocking regression appears:

1. `Review addon communication`
   - Recheck addon sync and messaging behavior end to end in live guild testing.
   - Focus on silent self hello, accepted sync updates, ignored forged payloads, request propagation, request approval side effects, and any guild-bank scan or ledger status noise that still feels off in chat.
   - If communication gaps still exist, fix those next before taking on more visual polishing.

2. `Release/install sanity pass`
  - `v0.9.0-beta.3` succeeded through GitHub Actions and produced the GitHub prerelease zip.
  - Next live/manual check: confirm the CurseForge beta package installs cleanly with both addon folders, the vendored AceComm libs load correctly from the packaged zip, and the About/version text lines up with the packaged build.

3. `Small release-polish follow-ups`
   - Confirm the restored `About` author/build details still match the packaged beta.
   - Confirm `/gbm help` stays limited to player-facing commands in the packaged beta.
   - Keep `244559` as a future smoke anchor for same-itemID multi-quality behavior, but the full live regression for this migration is complete.

## Current Live Blockers

- Item-hyperlink/crafted-quality migration verification is complete after `/reload`; keep these spot-check items as future smoke anchors:
  - `240154` Arcanoweave Spellthread
  - `241320` Flask of Thalassian Resistance
  - `241322` Flask of the Magisters
  - `241324` Flask of the Blood Knights
  - `243734` Thalassian Phoenix Oil
  - `244559` same-itemID multi-quality check case
- Guild-bank-open ledger wakeup is now running as expected in live WoW. The latest follow-up fixes scanner-driven item-log imports so a fully rotated same-size visible item-log window appends new rows instead of being treated as an unsafe stale no-overlap batch; money-log imports are covered alongside item logs. The merge now mirrors the MIT-licensed `GuildBankLedger` reference more closely by comparing session batch counts for repeated scans of the same source, while the active/passive coordinator prevents ledger starts during inventory scan and waits for completion before scheduling the next passive tick. If old local ledger data looks poisoned, clear `Guild Bank Log Data` and validate from a fresh ledger baseline.
- Deferred follow-up items, intentionally not done in this checkpoint:
  - live/manual sync sanity against real guild peers after install

## Best Next Debug Step

Do not spend another session trying to perfect visible tier-icon parity as a standalone objective.

The next practical work item is the pushed AceComm sync review:

1. Live-test silent self hello plus accepted sync update chat milestones.
2. Live-test ignored forged payload feedback without chat spam.
3. Live-test request propagation and approval-created Minimums side effects on receiving clients.
4. Recheck everyone-to-everyone ledger sync and peer last-alive updates in `Options -> Sync`.
5. Recheck guild-bank scan and ledger status noise now that bank-open wakeup and rotated visible-log append behavior are covered.

## Completed In Current Slice

- Root cause: snapshot aggregates were keyed by `itemID`, while Inventory and Minimums `Show All` consumed only the aggregate row.
- Canonical row identity: tab-scoped `itemRows` with `itemID|TAB|tabName`.
- Compatibility: aggregate `snapshot.items[itemID]` remains intact for diff and planning.
- Regression coverage: `diff_spec`, `store_spec`, `inventory_quality_spec`, `ui_table_spec`, `ui_minimums_spec`, `ui_requests_spec`, and `requests_spec`.
- Shared table layout is centralized in `GBankManager/UI/TableLayouts.lua` so Inventory and Minimums stay visually aligned.
- Request action authorization now preserves the legacy no-auth-policy path while continuing to enforce explicit auth policies.
- Request creation always starts `PENDING`; non-guildmaster self-approval is denied in both stored actions and sync updates; author cancellation is supported and sync-validated.
- The `/gbm request` wizard is complete enough for item search, quantity/reason, bank-tab choice, review, submit, own-request status rows, a progress rail, a live preview card, quantity steppers, and details popup cancellation.
- Approved requests that create a Minimums rule carry `minimumRuleKey`, and planning skips those request rows as separate request demand to avoid double-counting.
- Request detail regression coverage now includes modal click-through protection, fixed-row detail alignment, inline crafted-quality icon placement beside the item name, removal of the retired Quality-row gap, tighter label/value spacing, Requested By placement, Updated By / Date Updated / Decision Note bottom placement, extra Approval Bank Tab breathing room, post-decision editor hiding, workflow-button alignment with Close, actor-name history rows, shared table scrollbar bounds, and the reserved scrollbar gutter.
- Local Lua runners now print `RUN`/`PASS` progress for each lane and spec so long-running tests no longer appear silent.
- Request scan-fulfillment regression coverage now spans `requests_spec` and `store_spec`.
- Exports regression coverage now spans `exports_spec` and `ui_exports_spec`, including highest-quantity excess-stock labeling, CSV output, Auctionator scoped output, TSM item-ID output, copy-guidance feedback, nested-box removal, and the manual shopping-list modal.
- Export modal regression coverage now also verifies that the output surface is a real scrollable edit box, that `Select All` focuses it, rewinds the cursor, and highlights the full output for manual `Ctrl+C`.
- Minimums regression coverage now includes unresolved `GLOBAL` row ordering, orange highlighting, editable Bank Tab recovery, save-time validation blocking, and approved-request self-heal when a bank tab already exists but the minimum binding is missing.
- Request deletion regression coverage now spans auth, auth-source, request-domain, sync, and request-UI specs.
- Requests regression coverage now also covers active-filter highlighting, far-left `Add Request` plus `Refresh`, the `Completed` filter, right-aligned filters, and shared-height sizing.
- Minimums regression coverage now also covers the split `Enabled Only` and `Show All` filter buttons plus active-state highlighting.
- Auth policy regression coverage now spans auth-source, auth, options UI, sync, history, and officer-note blacklist specs for Restock Default propagation, Guild Info updater metadata, Guild Info blacklist removal, officer-note tag writes, blacklist input normalization, and visible auth-policy history rows.
- Scanner regression coverage now spans unit and sync specs for guild-bank-open auto-scan throttling plus the `GUILDBANKFRAME_OPENED` and `GUILDBANK_UPDATE_TABS` wake-up path in the scanner event adapter.
- Guild-bank auto-scan now also wakes from `GUILDBANK_UPDATE_TABS`, not just the initial open event, timer retry, or bag-slot updates, so opening the bank before tab metadata is ready still starts a scan once the tab list finishes loading.
- Blacklist regression coverage now spans guild-roster officer-note parsing plus the read-only Blacklist tab guidance and parsed-member rendering.
- Sync-hardening regression coverage now spans request history parity on receiving clients, authority-first request conflict resolution, and approved-request minimum recreation on receiving clients.
- Appearance regression coverage now spans `ui_shell_spec`, `ui_options_spec`, and `live_smoke_spec` for the token-backed theme presets, the linked `UI Scale` control, split shell-vs-modal opacity controls, active-state glow, collapsed-nav icons, per-theme crest art, minimap-launcher visibility, and shell-top-level focus behavior.
- Appearance regression coverage now also verifies explicit shell/sidebar/header/card/button variant contracts, reusable art-layer presence, sidebar identity/footer collapse behavior, and the trimmed five-tab Options shell in `ui_shell_spec` and `ui_options_spec`.
- UI fidelity regression coverage now also verifies the branded About panel contract, table-header/filter/viewport variants, stronger semantic row token styling, bottom-only row separators, higher-contrast filter inputs, and shared request/minimum button-variant routing in `ui_about_spec`, `ui_table_spec`, `ui_requests_spec`, and `ui_minimums_spec`.
- Request-only UI regression coverage now also verifies the three-step wizard progress rail, preview visibility, quantity steppers, left-rail modal actions, and the removal of the dedicated bank-tab step in `ui_requests_spec.lua`.
- Requests crafted-quality coverage now also verifies request table rows, search results, and wizard-created requests carry semantic two-rank family metadata and canonical display atlases, so the shared table renderer can normalize live chat atlases to the same single-silver-diamond and gold-pentagon family already verified in Minimums and Exports.
- The New Request wizard selector now opts into a shared-display quality icon for search results, selected item, and preview, and `/gbm debug request <itemID>` dumps the modal selector icon state for live checks that are outside `/gbm debug render`.
- Appearance and crafted-quality regression coverage now also spans shared two-rank icon normalization plus slider drag-release behavior in `inventory_quality_spec`, `ui_table_spec`, `ui_exports_spec`, `ui_minimums_spec`, `ui_requests_spec`, and `ui_options_spec`.
- Auth regression coverage now also spans compact updater-hash policy encoding plus legacy blacklist-key normalization.
- Dashboard regression coverage now spans `dashboard_spec` for zero-shortage `Ready to Buy` counting plus `ui_dashboard_spec` for the four-card dashboard layout, `Recent Activity`, and `Quick Actions`.
- Exports regression coverage now also verifies the action-card presentation, icon slots, and `Generate` / `Open List` CTA labels in `ui_exports_spec`.
- Minimums regression coverage now also verifies staged-row grouping, row badges, and staged-summary or `Revert All` footer behavior in `ui_minimums_spec`.
- Sync regression coverage now also includes silent self hello plus chat feedback for accepted sync and ignored forged payloads.
- Release automation maintenance now targets `actions/checkout@v6` and `softprops/action-gh-release@v3` so the CurseForge workflow is aligned with GitHub's Node 24 JavaScript action transition warning.
- In-game unit-lane regression coverage now spans `in_game_unit_spec.lua` plus `store_spec.lua` for slash availability, persistence, chat output, the saved-variables shape of `testing.inGameUnit`, blacklist normalization, officer queue prioritization, and unresolved minimum repair-row ordering.
- Live-smoke regression coverage now also verifies deterministic behavior when ambient auth policy denies raider request submission and when stale request/minimum selector state existed before the smoke run.
- Live-smoke and options regression coverage now also verify the policy-string `Select All` affordance, the current modal-driven Minimums staging flow, and successful request creation after the gating check clears stale selector state.
- Maintainer tooling regression coverage now spans `item_catalog_maintainer_spec.lua` for the status adapter and deployment helper, and the repo now ships `Open-ItemCatalogMaintainer.ps1` as the small local maintainer-facing launcher over the catalog pipeline.

## Immediate Engineering Focus

When resuming, treat the branch as narrowed to the remaining blockers:

1. Resume addon communication with live/manual AceComm validation now that the transport, targeted request sync, minimums/ledger families, and persisted peer tracking are pushed.
2. Run the release/install sanity pass against the published `v0.9.0-beta.3` package, including vendored AceComm libs and `Options -> Sync`.
3. Then do the small polish follow-ups:
   - first-time guild setup walkthrough design

## Important Constraints

- Keep using the local WoW addon development guide as the source of truth for addon/runtime patterns.
- Keep documentation updated as each roadmap item lands.
- Keep controls reusable and scalable across the project.
- Continue to favor focused subsystem tests over growing broad monolithic UI assertions.
- Do not expose maintainer credentials or local catalog assets in git.
- TSM export intentionally uses TSM 4.14's supported item-ID import path rather than generating TSM's private serialized export blob.
