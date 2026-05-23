# GBankManager Testing

## Lanes

- `unit`: domain and feature rules that do not need frame-heavy setup
- `ui`: shell, controller, and focused UI behavior
- `integration`: addon bootstrap, slash wiring, and opt-in smoke harness routing
- `wowless`: companion-repo Docker smoke that loads the addon through Wowless
- `live smoke`: explicit retail-client validation after the automated lanes are green
- `in-game unit`: explicit retail-client deterministic checks run through `/gbm test unit`

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
  - dashboard ranking and stocking-history coverage for the `Top 5 Most Used` card
  - migration/default-shape coverage, including the persisted live-smoke result container
- `ui`
  - shell layout, shared table behavior, requests, exports, minimums, and options/auth ownership specs
  - focused regression checks for shared scrollbars, request-only layout, options auth state, bundled indexed item-search behavior, the Minimums modal handoff from search into details, staged-row grouping, dashboard card or panel composition, shared visible crafted-tier symbols, slider drag-release behavior, shell surface variants, sidebar identity footer behavior, and tabbed Options navigation
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
  - seeds its own request-access auth shape and clears stale request/minimum selector state first, so prior live guild policy or leftover UI state does not create false failures
  - confirms shell open/close, options scroll wiring, opacity controls, request-only vs full-shell access, current Minimums modal staging/save, and scan gating
  - confirms appearance sliders support both direct slider interaction and plus/minus stepping
  - confirms local appearance controls cover the token-backed theme presets (`Generic WoW`, `High Contrast`, `Alliance`, `Horde`, `Nature`, `Void`), a single linked `UI Scale` slider with a 90%-120% range, shell opacity, modal opacity, active-nav glow, and collapsed-nav icons
  - confirms the shell yields behind other dragged UI until clicked back to the front again
  - confirms the manual shopping list can stay open across tab switches or shell close, remembers its moved position, and keeps low-tier crafted icons normalized even when the source row has no live stock snapshot
  - auth policy publishing is manual in Retail: use `Save`, use `Select All` or mouse selection on the `Policy String`, paste it into `Guild Information`, press `Accept`, then use `Refresh Guild Info` to verify the live string
  - blacklist membership is no longer stored in Guild Info: edit a guild member's officer note manually, add or remove `[GBMBL]`, then confirm `Options -> Blacklist` can refresh the read-only parsed roster view
  - item search should use the required bundled `GBankManager_ItemData` payload; if that payload is unavailable, the search UI should report the unavailable state clearly instead of showing misleading sparse local-only name results
  - Minimums should open a centered details modal after a confirmed add-search selection instead of dropping the user into the old footer editor flow
  - Inventory and Minimums should share the same table layout, and Minimums should use a compact transparent action strip instead of the old boxed footer search/editor panel
  - Minimums draft rows should clearly show green `added`, yellow `changed`, and red `deleted` state before `Save All`
  - Minimums should backfill crafted tier from the bundled catalog when snapshot or scan data omits `craftedQuality` and `craftedQualityIcon`
  - `/gbm request` should show the compact request window with the addon title, an own-request status table, row-click details, and the four-step `New Request` wizard with progress rail, preview card, quantity steppers, and explicit bank-tab selection
  - `Request Admin` should use details-modal workflow actions only, with the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, a `Refresh` button beside `Add Request`, and no top workflow action box.
  - Approved open requests should be auto-marked fulfilled by a guild-bank scan once scanned inventory meets the requested quantity, and fulfilled requests should retain Date Fulfilled.
  - Exports should show four export action cards, visible-table CSV output, Auctionator and TSM all-vs-missing modal choices, and a stocked-elsewhere tab/quantity detail modal.
  - Dashboard should show four metric cards plus `Top 5 Most Used`, `Recent Activity`, and `Quick Actions`
  - sync should report milestone chat feedback for login hello, accepted incoming updates, and rejected forged sync payloads without turning the chat frame into a step-by-step spam log
  - dashboard `Top 5 Most Used` should rank repeated shortage cycles from stocking history above one-off raw withdrawal spikes when minimum-backed history exists
- `in-game unit`
  - in-client deterministic checks run only when you explicitly invoke `/gbm test unit`
  - persists results under `GBankManagerDB.testing.inGameUnit`
  - currently covers auth policy round-tripping, request workflow invariants, crafted-quality normalization, dashboard stocking-history ranking, sync sender validation, blacklist normalization, officer queue prioritization, and unresolved minimum repair-row ordering
  - crafted-quality coverage will reload the helper if the module registry dropped it, matching the live UI modules' fallback behavior instead of failing on a harness-only lookup miss

## Failure Reading

- `unit` failures usually mean a domain or persistence regression and should be fixed before looking at UI fallout.
- `ui` failures usually mean a shell/controller contract drifted, even if the live client still partly renders.
- Minimums-specific UI failures should be read against the new modal contract first: search-to-details handoff, details-shell reuse for existing rows, and draft-state styling are now the primary behavior surface instead of the old footer editor.
- `integration` failures usually mean load order, slash routing, or smoke harness wiring broke.
- `wowless` failures usually mean a Docker/runtime issue, a broken Wowless product target, or a headless addon-load regression under Wowless.
- `live smoke` failures mean the addon loaded but a real in-client workflow no longer behaved as expected.
- because the smoke lane now resets its own auth and selector scratch state, a remaining `live smoke` failure is much more likely to be a real workflow regression than leftover local UI state
- `in-game unit` failures mean a deterministic module contract regressed even if the higher-level workflow smoke still passes.

## Release Order

1. Run the local `unit`, `ui`, and `integration` lanes until they are green.
2. Optionally run `.\tools\test\run-wowless.ps1` once the companion repo and Docker Desktop are set up.
3. Confirm the GitHub Actions workflow is green.
4. Run `/gbm test unit` in retail and review the chat summary.
5. Run `/gbm test smoke` in retail and review the chat summary.
6. Do a short visual spot-check only where automation cannot prove correctness.
7. During live Minimums and Requests search checks, confirm known query families such as `flask of`, `flask of the sha`, `flask sun`, and `thalassian phoenix oil` return the expected bundled result families and crafted-tier splits.
8. During live Minimums editing checks, confirm add flow moves from the search modal into the centered details modal, existing rows open the same modal, and draft row colors match add/edit/remove state before `Save All`.

## Next Test Priorities

The next planned validation work should follow product priority, not test-only convenience:

1. Live-verify the completed auth, auto-scan, and request-sync slices together: Guild Info preload, Restock Default propagation, auth-policy history visibility, guild-bank-open auto-scan throttling on both first open and reopen after 10 minutes, and synced request approval creating the matching Minimums rule on receiving clients.
2. Recheck the dashboard `Ready to Buy` mismatch against real live SavedVariables before making any code change. No local repro-backed code fix landed in this slice.
3. Broaden UI polish validation across the shared table shells, nav active-state styling, quality-tier icon rendering, scalable theme or sizing controls, collapsed-nav icons, separate shell or modal opacity slider behavior, and the newer window ordering behavior around other draggable UI.
4. Live-verify the broadened in-game unit lane in retail after the automated lanes are green.
5. Live-verify the maintainer status adapter, deployment helper, and local maintainer launcher against a real WoW target path.

### Recent Regression Coverage

- `tests/spec/diff_spec.lua` verifies scan snapshots keep aggregate item totals and tab-scoped `itemRows` for shared items.
- `tests/spec/store_spec.lua` verifies fresh scans persist tab-scoped item rows in saved variables.
- `tests/spec/inventory_quality_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums `Show All` render one row per bank tab with per-tab quantities.
- `tests/spec/ui_table_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums share the same column order, including a wider `Item` column and matching table height.
- `tests/spec/ui_table_spec.lua` verifies shared table content stops before the external slim scrollbar so the bar does not overlap the rightmost column.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums uses shared table filters, hides the old bottom search, and keeps only the compact three-button action strip below the table.
- `tests/spec/ui_minimums_spec.lua` verifies existing saved minimum rows auto-populate Bank Tab as a read-only value, including legacy saved rows that need the tab inferred from the table row.
- `tests/spec/ui_requests_spec.lua` verifies the full-shell `Request Admin` surface has no inline creation panel or top workflow action box, uses shared table filters, includes date requested plus date fulfilled, exposes the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, and keeps `Add Request` plus `Refresh` on the left edge.
- `tests/spec/ui_requests_spec.lua` also verifies request-only mode uses the smaller titled request window, own-request status columns, row-click details, and the item -> quantity/reason -> bank-tab -> review request wizard, including progress-rail state, preview visibility, and quantity steppers.
- `tests/spec/ui_requests_spec.lua` verifies request details align values to fixed modal columns, labels the Decision Note input, keeps details open after approval, prompts approvers for Bank Tab, and saves approval-created Minimums rules.
- `tests/spec/ui_requests_spec.lua` also verifies request modals block table click-through, request details use fixed label/value rows, show Requested By above Date Requested, show Updated By and Date Updated near the bottom with Decision Note, hide the decision-note editor after approval or denial, and align workflow buttons with Close.
- `tests/spec/requests_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/auth_source_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_requests_spec.lua` verify the new request-delete permission, stored delete action, delete sync handling, and the request-details `Delete` workflow path.
- `tests/spec/requests_spec.lua` verifies stored request actions still work when no explicit auth policy is present, while auth-policy-backed denial paths remain covered, no request auto-approves, non-guildmaster self-approval is blocked, Guild Master self-approval remains an explicit workflow action, approval metadata preserves Decision Note and Bank Tab, and authors can cancel pending own requests.
- `tests/spec/requests_spec.lua` verifies request audit history stores actor names instead of Lua actor tables, and approved open requests can be auto-fulfilled from a bank scan when inventory meets the requested quantity.
- `tests/spec/store_spec.lua` verifies fresh guild-bank scans auto-fulfill approved open requests and store Date Fulfilled from the scan timestamp.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` verify the reworked Exports table columns, stocked-elsewhere modal, `Excess Stock` and `None` labeling, crafted-quality icon rendering, export action cards, CSV output modal, Auctionator all-vs-missing choice flow, and TSM item-ID import output.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` also verify Auctionator's current caret-delimited import format and quality-icon rendering inside the manual shopping list helper.
- `tests/spec/inventory_quality_spec.lua`, `tests/spec/ui_table_spec.lua`, `tests/spec/ui_exports_spec.lua`, `tests/spec/ui_minimums_spec.lua`, and `tests/spec/ui_requests_spec.lua` verify two-rank crafted items now stay on the shared visible chat-icon family instead of drifting into a mismatched inventory-atlas family on some surfaces.
- `tests/spec/ui_requests_spec.lua` verifies Request Admin active-filter styling, the far-left `Add Request` plus `Refresh` actions, right-aligned bottom filters, the `Completed` filter, and shared-height table sizing.
- `tests/spec/ui_dashboard_spec.lua` verifies the modernized dashboard layout with four metric cards, `Top 5 Most Used`, `Recent Activity`, and `Quick Actions`.
- `tests/spec/ui_dashboard_spec.lua` now also verifies metric-card icon slots so the dashboard fidelity pass keeps visual anchors on each card.
- `tests/spec/ui_minimums_spec.lua` verifies staged Minimums rows group at the top, expose `ADD` / `EDIT` / `DELETE` badges, and reveal staged-summary plus `Revert All` footer affordances only while drafts exist.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums now uses separate `Enabled Only` and `Show All` buttons with active-state highlighting.
- `tests/spec/auth_source_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/history_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_options_spec.lua` verify auth policy strings now preserve Restock Default plus updater metadata, Options can reload that Guild Info state, auth-policy updates appear in History newest-first, and the Blacklist tab explains the shared `[GBMBL]` officer-note contract.
- `tests/spec/auth_source_spec.lua` and `tests/spec/auth_spec.lua` also verify the compact updater-hash policy-string encoding, the removal of Guild Info blacklist membership export, and legacy blacklist-key normalization behavior.
- `tests/spec/officer_note_blacklist_spec.lua` and `tests/spec/ui_options_spec.lua` verify appended `[GBMBL]` officer-note tags, guild-roster-driven blacklist refresh, the read-only Blacklist tab guidance, the explicit themed `Refresh` action above the parsed-member list, the removal of the old duplicate blacklist header, and the refresh-status transition back to the parsed summary after `GUILD_ROSTER_UPDATE`.
- `tests/spec/ui_requests_spec.lua` verifies request creation reparses guild-backed blacklist state before submit and denies newly blacklisted actors.
- `tests/spec/diff_spec.lua` and `tests/spec/sync_spec.lua` verify opening the guild bank auto-scans only after the 10-minute throttle window, retries long enough for delayed tab metadata on reopen, while manual scan remains unaffected and the scanner event adapter now owns `GUILDBANKFRAME_OPENED`.
- `tests/spec/sync_spec.lua` verifies synced request creation writes local history, higher-authority request updates win conflict resolution, synced approvals recreate the matching Minimums rule plus history rows on receiving clients, and sync milestone chat feedback is emitted for hello, accepted sync, and ignored forged payloads.
- `tests/spec/sync_spec.lua` also verifies request sync rejects non-guildmaster self-approval updates and forged cancellation updates while accepting author cancellations.
- `tests/spec/planning_spec.lua` verifies approved requests converted into Minimums rules do not double-count demand as both request demand and restock demand.
- `tests/spec/dashboard_spec.lua` verifies the dashboard ignores zero-shortage demand rows for `Ready to Buy` counting and now ranks the `Top 5 Most Used` card by repeated stocking-history shortage cycles before falling back to raw withdrawal totals.
- `tests/spec/ui_shell_spec.lua` verifies the shell opts into top-level ordering, raises on click, and keeps registered modals layered above the shell when focus changes.
- `tests/spec/ui_shell_spec.lua`, `tests/spec/ui_table_spec.lua`, `tests/spec/ui_requests_spec.lua`, and `tests/spec/ui_options_spec.lua` verify the shell now defaults below higher-priority dialogs, hides zero-range shared scrollbars, preloads auth policy from Guild Info on options open, applies shell and modal opacity to backdrop or art layers without dimming content, keeps scaled table layouts inside the shell viewport, keeps top-bar scan plus status controls from overlapping when scaled, uses built-in WoW `UISliderTemplate` appearance controls, and lets appearance sliders release cleanly even when the mouse-up happens off the bar.
- `tests/spec/ui_shell_spec.lua` and `tests/spec/ui_options_spec.lua` also verify the newer art-layer shell contract: reusable frame background textures, nav accent bars, header-band card treatment, sidebar identity/footer behavior, late guild-name refresh behavior, and the six-tab Options shell contract.
- `tests/spec/ui_about_spec.lua` verifies the dedicated branded About panel, crest/icon slot, identity copy, slash-command hint, and removal of the old generic body-text fallback.
- `tests/spec/ui_table_spec.lua` now also verifies dedicated table header/filter/viewport surface variants plus semantic alternating row-token styling.
- `tests/spec/ui_requests_spec.lua` and `tests/spec/ui_minimums_spec.lua` now also verify the shared button-variant contracts for request admin filters, request wizard CTAs, destructive request actions, and Minimums modal actions.
- `tests/spec/ui_exports_spec.lua` verifies the floating manual shopping list stays independent from the main shell, remembers its saved position, and keeps normalized low-tier crafted icons in fallback rows.
- `tests/spec/ui_exports_spec.lua` now also verifies export action-card icon slots plus the `Generate` / `Open List` CTA labels used by the modernized cards.
- `tests/spec/test_runner_spec.lua` verifies the local Lua test runner emits progress before and after each spec.
- `tests/spec/in_game_unit_spec.lua` verifies `/gbm test unit` availability, persistence, chat output, and the broadened deterministic in-client unit checks.
- `tests/spec/item_catalog_maintainer_spec.lua` verifies the maintainer status adapter and deployment helper for resolved target paths, saved sync-state reporting, and copying both addon folders into `Interface\AddOns`.

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
3. If it fails, inspect `GBankManagerDB.testing.liveSmoke` after `/reload` for the last persisted summary and check details. Pay special attention to `minimums_render` and `request_selection_gating`, because those now exercise the live modal workflow and confirmed-selection reset path rather than the older footer-editor assumptions.
4. If it passes, still do a short visual spot-check in `Options`, `Requests`, and `Minimums` for layout/art regressions the smoke cannot prove.
