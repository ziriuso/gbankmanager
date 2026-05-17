# GBankManager Testing

## Lanes

- `unit`: domain and feature rules that do not need frame-heavy setup
- `ui`: shell, controller, and focused UI behavior
- `integration`: addon bootstrap, slash wiring, and opt-in smoke harness routing
- `wowless`: companion-repo Docker smoke that loads the addon through Wowless
- `live smoke`: explicit retail-client validation after the automated lanes are green

## Commands

- `.\tools\lua\lua.exe .\tests\run_unit.lua`
- `.\tools\lua\lua.exe .\tests\run_ui.lua`
- `.\tools\lua\lua.exe .\tests\run_integration.lua`
- `.\tools\lua\lua.exe .\tests\run_all.lua`
- `.\tools\test\run-unit.ps1`
- `.\tools\test\run-ui.ps1`
- `.\tools\test\run-integration.ps1`
- `.\tools\test\run-all.ps1`
- `.\tools\test\run-wowless.ps1`
- `.\tools\test\run-live-smoke.ps1`

`run_all` executes `unit -> ui -> integration` and stops on the first failure. The Lua runners print `RUN` and `PASS` for each lane and each spec as they execute, so long-running catalog or UI specs identify where time is being spent instead of leaving the terminal silent.

## Lane Coverage

- `unit`
  - domain rules for auth, requests, exports, planning, sync, store, and scan persistence
  - migration/default-shape coverage, including the persisted live-smoke result container
- `ui`
  - shell layout, shared table behavior, requests, exports, minimums, and options/auth ownership specs
  - focused regression checks for shared scrollbars, request-only layout, options auth state, bundled indexed item-search behavior, and the Minimums modal handoff from search into details
- `integration`
  - TOC order and duplicate-load protection
  - shared namespace/module registration after bootstrap
  - slash-command wiring for explicit live smoke via `/gbm test smoke`
  - persisted smoke summaries and chat-visible smoke output
- `wowless`
  - companion-repo addon-load smoke through Wowless with fallback across supported Standard-gametype products
  - Docker-backed runtime bootstrap outside the main addon repo
  - optional and non-blocking until the runtime is proven stable
- `live smoke`
  - in-client checks run only when you explicitly invoke `/gbm test smoke`
  - confirms shell open/close, options scroll wiring, opacity controls, request-only vs full-shell access, minimum staging/save, and scan gating
  - auth policy publishing is manual in Retail: use `Save`, copy the `Policy String`, paste it into `Guild Information`, press `Accept`, then use `Refresh Guild Info` to verify the live string
  - item search should use the required bundled `GBankManager_ItemData` payload; if that payload is unavailable, the search UI should report the unavailable state clearly instead of showing misleading sparse local-only name results
  - Minimums should open a centered details modal after a confirmed add-search selection instead of dropping the user into the old footer editor flow
  - Inventory and Minimums should share the same table layout, and Minimums should use a compact transparent action strip instead of the old boxed footer search/editor panel
  - Minimums draft rows should clearly show green `added`, yellow `changed`, and red `deleted` state before `Save All`
  - Minimums should backfill crafted tier from the bundled catalog when snapshot or scan data omits `craftedQuality` and `craftedQualityIcon`
  - `/gbm request` should show the compact request window with the addon title, an own-request status table, row-click details, and the three-step `New Request` wizard

## Failure Reading

- `unit` failures usually mean a domain or persistence regression and should be fixed before looking at UI fallout.
- `ui` failures usually mean a shell/controller contract drifted, even if the live client still partly renders.
- Minimums-specific UI failures should be read against the new modal contract first: search-to-details handoff, details-shell reuse for existing rows, and draft-state styling are now the primary behavior surface instead of the old footer editor.
- `integration` failures usually mean load order, slash routing, or smoke harness wiring broke.
- `wowless` failures usually mean a Docker/runtime issue, a broken Wowless product target, or a headless addon-load regression under Wowless.
- `live smoke` failures mean the addon loaded but a real in-client workflow no longer behaved as expected.

## Release Order

1. Run the local `unit`, `ui`, and `integration` lanes until they are green.
2. Optionally run `.\tools\test\run-wowless.ps1` once the companion repo and Docker Desktop are set up.
3. Confirm the GitHub Actions workflow is green.
4. Run `/gbm test smoke` in retail and review the chat summary.
5. Do a short visual spot-check only where automation cannot prove correctness.
6. During live Minimums and Requests search checks, confirm known query families such as `flask of`, `flask of the sha`, `flask sun`, and `thalassian phoenix oil` return the expected bundled result families and crafted-tier splits.
7. During live Minimums editing checks, confirm add flow moves from the search modal into the centered details modal, existing rows open the same modal, and draft row colors match add/edit/remove state before `Save All`.

## Next Test Priorities

The next planned validation work should follow product priority, not test-only convenience:

1. Validate the Exports UI rework after the request/admin split.
2. After those UI and workflow slices settle, build the dedicated in-game unit-test addon lane so live client verification can move beyond manual smoke.
3. After the core product workflow slices are stable, validate guild-client sync behavior for history, requests, and minimums as its own end-to-end lane.

### Recent Regression Coverage

- `tests/spec/diff_spec.lua` verifies scan snapshots keep aggregate item totals and tab-scoped `itemRows` for shared items.
- `tests/spec/store_spec.lua` verifies fresh scans persist tab-scoped item rows in saved variables.
- `tests/spec/inventory_quality_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums `Show All` render one row per bank tab with per-tab quantities.
- `tests/spec/ui_table_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums share the same column order, including a wider `Item` column and matching table height.
- `tests/spec/ui_table_spec.lua` verifies shared table content reserves a scrollbar gutter so columns and rows do not render underneath the inset scrollbar.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums uses shared table filters, hides the old bottom search, and keeps only the compact three-button action strip below the table.
- `tests/spec/ui_minimums_spec.lua` verifies existing saved minimum rows auto-populate Bank Tab as a read-only value, including legacy saved rows that need the tab inferred from the table row.
- `tests/spec/ui_requests_spec.lua` verifies the full-shell `Request Admin` surface has no inline creation panel, keeps workflow actions visible with extra bottom spacing, uses shared table filters, and includes date requested plus item name in the admin table.
- `tests/spec/ui_requests_spec.lua` also verifies request-only mode uses the smaller titled request window, own-request status columns, row-click details, and the item -> quantity/reason -> review request wizard.
- `tests/spec/ui_requests_spec.lua` verifies request details align values to fixed modal columns, labels the Decision Note input, keeps details open after approval, prompts approvers for Bank Tab, and saves approval-created Minimums rules.
- `tests/spec/ui_requests_spec.lua` also verifies request modals block table click-through, request details use fixed label/value rows, show Requested By above Date Requested, show Updated By and Date Updated near the bottom with Decision Note, hide the decision-note editor after approval or denial, and align workflow buttons with Close.
- `tests/spec/requests_spec.lua` verifies stored request actions still work when no explicit auth policy is present, while auth-policy-backed denial paths remain covered, no request auto-approves, non-guildmaster self-approval is blocked, Guild Master self-approval remains an explicit workflow action, approval metadata preserves Decision Note and Bank Tab, and authors can cancel pending own requests.
- `tests/spec/requests_spec.lua` verifies request audit history stores actor names instead of Lua actor tables.
- `tests/spec/sync_spec.lua` verifies request sync rejects non-guildmaster self-approval updates and forged cancellation updates while accepting author cancellations.
- `tests/spec/planning_spec.lua` verifies approved requests converted into Minimums rules do not double-count demand as both request demand and restock demand.
- `tests/spec/test_runner_spec.lua` verifies the local Lua test runner emits progress before and after each spec.

## Wowless Companion Repo

The headless Wowless lane lives in the sibling repo:

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager-wowless-smoke`

That repo owns:

- Docker and Wowless bootstrap
- staging the addon into the Wowless checkout
- addon-load smoke execution
- companion-specific runtime docs

Main companion commands:

- `.\scripts\bootstrap.ps1`
- `.\scripts\run-smoke.ps1`

The companion harness tries product targets in this default order:

1. `wow`
2. `wowt`
3. `wow_beta`

The JSON report records which product actually passed as `selectedProduct`, plus per-product attempts under `productAttempts`.

From the addon repo you can invoke the companion lane with:

- `.\tools\test\run-wowless.ps1`

If PowerShell execution policy blocks direct script execution on Windows, run:

- `powershell -ExecutionPolicy Bypass -File .\tools\test\run-wowless.ps1`

## Live Smoke

Run these in retail only after the automated lanes pass:

1. Run `/gbm test smoke`.
2. Confirm chat prints one overall `PASS` or `FAIL` line plus individual check lines.
3. If it fails, inspect `GBankManagerDB.testing.liveSmoke` after `/reload` for the last persisted summary and check details.
4. If it passes, still do a short visual spot-check in `Options`, `Requests`, and `Minimums` for layout/art regressions the smoke cannot prove.
