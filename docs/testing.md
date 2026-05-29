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
  - sync transport chunking/reassembly coverage for oversized addon-message payloads so request, minimum, and ledger sync traffic stay within WoW's base addon-message size limit
  - guild-scoped request routing, officer-authoritative minimum snapshot acceptance or rejection, remote ledger-delta merge coverage that preserves local scan freshness, persisted peer-history buckets keyed by guild, and the retired auth-policy addon-comm path staying disabled
  - dashboard ranking and ledger-withdrawal-only coverage for the `Top 10 Most Used` card
  - migration/default-shape coverage, including the persisted live-smoke result container
- `ui`
  - shell layout, shared table behavior, requests, exports, minimums, and options/auth ownership specs
  - focused regression checks for shared scrollbars, request-only layout, options auth state, bundled indexed item-search behavior, the Minimums modal handoff from search into details, staged-row grouping, dashboard card or panel composition, shared visible crafted-tier symbols, slider drag-release behavior, shell surface variants, sidebar crest-footer behavior, tabbed Options navigation, and the persisted `Options -> Sync` peer-history view
  - shell-polish contracts for softer nav metadata, toolbar-band header state, timezone-bearing last-scan rendering, flatter dashboard/table surface variants, slimmer action-family routing, segmented-tab metadata, cleaner floating-sheet modal variants, dense-clean spacing, stronger neutral action contrast, higher-contrast select/dropdown triggers, wrapped dashboard quick-action labels, and the dedicated `Stock Settings` tab
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
  - confirms the shell-polish pass keeps header scan metadata readable with timezone abbreviation, preserves structured tables under flatter content sections, and keeps modal content readable while floating-sheet surfaces update
  - confirms local appearance controls cover the token-backed theme presets (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), a single linked `UI Scale` slider with a 90%-120% range, shell opacity, modal opacity, active-nav glow, collapsed-nav icons, and the minimap-button toggle
  - confirms the shell yields behind other dragged UI until clicked back to the front again
  - confirms the manual shopping list can stay open across tab switches or shell close, remembers its moved position, and keeps low-tier crafted icons normalized even when the source row has no live stock snapshot
  - auth policy publishing is manual in Retail: use `Save`, use `Select All` or mouse selection on the `Policy String`, paste it into `Guild Information`, press `Accept`, then use `Refresh Guild Info` to verify the live string
  - blacklist membership is no longer stored in Guild Info: edit a guild member's officer note manually, add or remove `[GBMBL]`, then confirm `Options -> Blacklist` can refresh the read-only parsed roster view
  - the themed crest art should swap when theme presets change, and the minimap button should appear or disappear immediately when the appearance toggle changes
  - item search should use the required bundled `GBankManager_ItemData` payload; if that payload is unavailable, the search UI should report the unavailable state clearly instead of showing misleading sparse local-only name results
  - Minimums should open a centered details modal after a confirmed add-search selection instead of dropping the user into the old footer editor flow
  - request search, request details, the request wizard preview, and Minimums details should prefer hyperlink-style item text when trusted stored links exist and should fall back to plain names when they do not. Request details and Minimums details should not rely on separate visible quality rows, while the New Request wizard selector may show a small shared-display quality icon to distinguish duplicate-name crafted variants.
  - Inventory should keep its dedicated texture path, while Minimums, Requests, Exports, and the manual shopping list should prefer the bundled canonical single-silver-diamond / gold-pentagon family for true two-rank crafted families, only consult live reagent-quality atlases if the canonical path is unavailable, and use the reagent-style medal atlases only as a last resort
  - shared table texture slots should defensively normalize stale two-rank atlas families at the final render boundary so persisted or legacy row data cannot reintroduce copper-diamond, double-silver, chat-quality, or reagent-medal icons when the row has two-rank crafted-family metadata
  - `/gbm debug atlas` should open a labeled visual atlas sampler for live-client crafted-quality investigation, `/gbm debug quality <itemID>` should continue to print item-aware resolver diagnostics, `/gbm debug render <itemID>` should print active table row data plus the visible row texture atlas after painting, and `/gbm debug request <itemID>` should print New Request wizard selector row or selected-item icon diagnostics
  - Inventory and Minimums should share the same table layout, and Minimums should use a compact transparent action strip instead of the old boxed footer search/editor panel
  - Minimums draft rows should clearly show green `added`, yellow `changed`, and red `deleted` state before `Save All`
  - Minimums should backfill crafted tier from the bundled catalog when snapshot or scan data omits `craftedQuality` and `craftedQualityIcon`
  - `/gbm request` should show the compact request window with the addon title, an own-request status table, row-click details, and the three-step `New Request` wizard with progress rail, preview card, quantity steppers, and explicit quantity/reason labeling
  - `Requests` should use details-modal workflow actions only, with the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, a `Refresh` button beside `Add Request`, and no top workflow action box.
  - Approved open requests should be auto-marked fulfilled by a guild-bank scan once scanned inventory meets the requested quantity, and fulfilled requests should retain Date Fulfilled.
  - Exports should show four export action cards, visible-table CSV output, Auctionator and TSM all-vs-missing modal choices, and a stocked-elsewhere tab/quantity detail modal.
  - Dashboard should show four metric cards plus `Top 10 Most Used`, `Recent Activity`, and `Quick Actions`
  - `Options -> Stock Settings` should let you change both `Restock Default` and the `Critical Shortage Threshold`, and the dashboard card should update its critical count using that percentage rule
  - `Options -> Data` should let you open real dropdown menus for guild-bank ledger retention, audit-history retention, and the guild-bank `Scan Interval`, should expose the repair-threshold input plus the `Mute Silvermoon Citizen` toggle, should keep the save button inside the panel chrome, should show visible save feedback after `Save Settings`, should surface a `Clear Data` section with confirmation-gated destructive actions, and saving those settings should prune out-of-window data when retention is finite and persist the mute toggle after `/reload`
  - `Bank Ledger` should pick up new log rows while the guild bank remains open, without needing another manual `Scan Bank`, including after `/reload` or relog when the guild bank is already open and passive refresh has to recover from live bank-open state instead of waiting for a fresh open event
  - `Exports` should keep the non-zero `Excess Qty` count visible, add a right-aligned drill-in arrow affordance in that cell, and the drill-in modal should summarize the total off-tab excess plus the per-tab breakdown
  - `Bank Ledger` should switch cleanly between `Item Log` and `Money Log`, open real dropdowns for the action filter and preset date-range filter, keep the shared table shell, filter by action plus date range, export the filtered rows to CSV with readable date-time values instead of raw integers, show item rows as `Date`, `Who`, `Action`, icon `Tier`, `Item`, `Quantity`, `Tab`, and `Moved From`, and keep the bottom summaries reduced to item totals plus gold totals that update from the selected date range
  - `Inventory` should expose an `Export CSV` action below the shared table and open the shared export modal with the currently filtered inventory rows
  - sync should report milestone chat feedback for login hello, accepted incoming updates, and rejected forged sync payloads without turning the chat frame into a step-by-step spam log
  - dashboard `Top 10 Most Used` should be driven by ledger-backed bank-withdrawal totals
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
- `release workflow` failures usually mean the tag format, CurseForge project settings, GitHub Actions secret or variable configuration, or package-shape expectations drifted.
- `wowless` failures usually mean a Docker/runtime issue, a broken Wowless product target, or a headless addon-load regression under Wowless.
- `live smoke` failures mean the addon loaded but a real in-client workflow no longer behaved as expected.
- because the smoke lane now resets its own auth and selector scratch state, a remaining `live smoke` failure is much more likely to be a real workflow regression than leftover local UI state
- `in-game unit` failures mean a deterministic module contract regressed even if the higher-level workflow smoke still passes.

## Release Order

1. Run the local `unit`, `ui`, and `integration` lanes until they are green.
2. Optionally run `.\tools\test\run-wowless.ps1` once the companion repo and Docker Desktop are set up.
3. Confirm the GitHub Actions workflow is green.
3a. For tagged release work, confirm `.github/workflows/release-curseforge.yml` is green and that the matching GitHub Release contains the packaged zip attachment.
4. Run `/gbm test unit` in retail and review the chat summary.
5. Run `/gbm test smoke` in retail and review the chat summary.
6. Do a short visual spot-check only where automation cannot prove correctness.
7. During live Minimums and Requests search checks, confirm known query families such as `flask of`, `flask of the sha`, `flask sun`, and `thalassian phoenix oil` return the expected bundled result families and crafted-tier splits.
8. During live Minimums editing checks, confirm add flow moves from the search modal into the centered details modal, existing rows open the same modal, and draft row colors match add/edit/remove state before `Save All`.
9. During live shell-polish checks, confirm action buttons and dropdown triggers stand out from the screen surfaces instead of blending into them, and confirm longer dashboard quick-action labels wrap cleanly without clipping.

## Next Test Priorities

The next planned validation work should follow product priority, not test-only convenience:

Completed on 2026-05-28: the item-hyperlink and crafted-quality live regression passed after `/reload` across Minimums, Requests, Request Details, New Request, and Exports, including the required `244559` anchor case and CSV numeric `Tier` preservation.

1. Live-verify the completed auth, auto-scan, and request-sync slices together: Guild Info preload, Restock Default propagation, auth-policy history visibility, guild-bank-open auto-scan throttling on both first open and reopen after 10 minutes, and synced request approval creating the matching Minimums rule on receiving clients.
2. Recheck the dashboard `Ready to Buy` mismatch against real live SavedVariables before making any code change. No local repro-backed code fix landed in this slice.
3. Broaden UI polish validation across the shared table shells, nav active-state styling, scalable theme or sizing controls, collapsed-nav icons, separate shell or modal opacity slider behavior, and the newer window ordering behavior around other draggable UI.
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
- `tests/spec/ui_requests_spec.lua` verifies the full-shell `Requests` surface has no inline creation panel or top workflow action box, uses shared table filters, includes date requested plus date fulfilled, exposes the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, and keeps `Add Request` plus `Refresh` on the left edge.
- `tests/spec/ui_requests_spec.lua` also verifies request-only mode uses the smaller titled request window, own-request status columns, row-click details, and the item -> quantity/reason -> review request wizard, including progress-rail state, preview visibility, and quantity steppers.
- `tests/spec/ui_requests_spec.lua` verifies request details align values to fixed modal columns, render crafted-quality icons inline beside the shared item display without leaving the retired quality-row gap, labels the Decision Note input, keeps details open after approval, prompts approvers for Bank Tab, leaves breathing room above the Approval Bank Tab control, and saves approval-created Minimums rules.
- `tests/spec/ui_requests_spec.lua` also verifies request modals block table click-through, request details use fixed label/value rows, show Requested By above Date Requested, show Updated By and Date Updated near the bottom with Decision Note, hide the decision-note editor after approval or denial, and align workflow buttons with Close.
- `tests/spec/ui_requests_spec.lua` also verifies request table rows and wizard-created requests preserve semantic crafted-quality metadata (`craftedQualityMax`, `craftedQualityFamilySize`, and canonical display/preferred atlases), so the shared table renderer can remap live two-rank chat atlases to the same single-silver-diamond and gold-pentagon icon family used by Minimums and Exports.
- `tests/spec/requests_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/auth_source_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_requests_spec.lua` verify the new request-delete permission, stored delete action, delete sync handling, and the request-details `Delete` workflow path.
- `tests/spec/requests_spec.lua` verifies stored request actions still work when no explicit auth policy is present, while auth-policy-backed denial paths remain covered, no request auto-approves, non-guildmaster self-approval is blocked, Guild Master self-approval remains an explicit workflow action, approval metadata preserves Decision Note and Bank Tab, and authors can cancel pending own requests.
- `tests/spec/requests_spec.lua` verifies request audit history stores actor names instead of Lua actor tables, and approved open requests can be auto-fulfilled from a bank scan when inventory meets the requested quantity.
- `tests/spec/store_spec.lua` verifies fresh guild-bank scans auto-fulfill approved open requests and store Date Fulfilled from the scan timestamp.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` verify the reworked Exports table columns, stocked-elsewhere modal, `Excess Stock` and `None` labeling, crafted-quality icon rendering, export action cards, CSV output modal, Auctionator all-vs-missing choice flow, and TSM item-ID import output.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` also verify Auctionator's current caret-delimited import format, the line-broken local-only note in the manual shopping list helper, clearer built-in checkboxes, and reagent-style two-rank quality icons inside that helper.
- `tests/spec/inventory_quality_spec.lua`, `tests/spec/ui_table_spec.lua`, `tests/spec/ui_exports_spec.lua`, `tests/spec/ui_minimums_spec.lua`, `tests/spec/ui_requests_spec.lua`, `tests/spec/ui_search_results_control_spec.lua`, `tests/spec/crafted_quality_spec.lua`, and `tests/spec/ui_crafted_quality_live_regression_spec.lua` verify the current crafted-quality contract: bundled rank and family-size metadata stay authoritative, Inventory keeps its established item-aware display-atlas treatment without dropping row icon metadata, and all visible surfaces now share the same true two-rank atlas contract: `Professions-Icon-Quality-12-Tier1-Inv` for quality 1 and `Professions-Icon-Quality-12-Tier2-Inv` for quality 2.
- `tests/spec/item_display_spec.lua` and `tests/spec/item_catalog_spec.lua` verify the hyperlink-migration foundation: the shared item-display payload prefers trusted stored hyperlinks for visible text, falls back to normalized plain names when links are unavailable, and preserves optional `itemLink`/`itemString` catalog fields plus numeric crafted-quality metadata for later UI migration steps.
- `tests/spec/ui_search_results_control_spec.lua`, `tests/spec/ui_requests_spec.lua`, and `tests/spec/ui_minimums_spec.lua` now also verify the Task 4 UI migration slice: shared selectors stop showing inline item IDs as the primary visible label, request tables move item rendering onto the shared display field, Minimums details drop separate visible quality rows, Request Details renders its quality icon inline with the item name, and request creation persists trusted `itemLink`/`itemString` metadata for later surfaces.
- `tests/spec/ui_requests_spec.lua` verifies Requests active-filter styling, the far-left `Add Request` plus `Refresh` actions, right-aligned bottom filters, the `Completed` filter, and shared-height table sizing.
- `tests/spec/ui_dashboard_spec.lua` verifies the modernized dashboard layout with four metric cards, `Top 10 Most Used`, `Recent Activity`, and the trimmed `Quick Actions` set (`Add Minimum`, `Create Request`, `Export Data`).
- `tests/spec/release_workflow_spec.lua` verifies the CurseForge release workflow exists, runs the full Lua suite before packaging, uses the protected `CF_API_TOKEN` and `CF_PROJECT_ID` configuration names, builds one combined zip with both addon folders, uploads through the CurseForge upload API, and attaches that same zip to the GitHub Release.
- `tests/spec/release_operator_skill_spec.lua` verifies the repo-local `docs/skills/gbankmanager-release-operator/SKILL.md` keeps the release triggers, full-suite gate, failed-run log inspection, fresh-tag retry rule, and TOC version-check guidance intact.
- `tests/spec/ui_dashboard_spec.lua` now also verifies metric-card icon slots so the dashboard fidelity pass keeps visual anchors on each card.
- `tests/spec/ui_dashboard_spec.lua` also verifies `Critical Shortages` now honors the configurable threshold percentage from `Options -> Stock Settings`.
- `tests/spec/ui_options_spec.lua` now also verifies `UI Scale` resizes dashboard cards and support panels instead of only scaling the shell frame and shared table density.
- `tests/spec/ui_options_spec.lua` also verifies the latest Appearance/Data relayout: `UI Scale` now lives in the right-hand slider column above shell and modal opacity, the minimap toggle sits directly under the theme presets, the `Data` dropdown labels stay aligned on one row inside the panel chrome, and the repair-threshold plus mute controls persist alongside the ledger scan settings.
- `tests/spec/slash_commands_spec.lua` verifies `/gbm` now opens the accessible UI instead of scanning, request-only access opens the request wizard, and `/gbm help` prints the supported slash-command list in chat.
- `tests/spec/slash_commands_spec.lua` also verifies `/gbm debug ledger` prints copy-friendly scanner state plus raw Blizzard item-log and money-log counts/sample rows for live ledger import investigations.
- `tests/spec/slash_commands_spec.lua` also verifies `/gbm debug quality <itemID>` help text plus chat output, including the lazy-load fallback path, the final inventory display atlas, and the final non-inventory atlas, so crafted-quality live diagnostics still speak in chat even if the helper module registry dropped out before `/reload`.
- `tests/spec/bank_ledger_spec.lua` now also verifies that a fully rotated busy money-log window still appends the newly visible rows instead of being discarded as a suspicious same-size no-overlap batch.
- `tests/spec/bank_ledger_spec.lua` also verifies real repeated item and money activity appends when the same actor later moves the same item/quantity or gold amount again, and that the ledger uses a `GuildBankLedger`-style session batch-count merge so same-identity batches can shrink and regrow without losing new rows.
- `tests/spec/toc_spec.lua` and `tests/spec/ui_about_spec.lua` verify `GBankManager.toc` carries the current addon `Version` metadata and that the About panel renders that semantic version alongside the local build stamp.
- `tests/spec/ui_minimums_spec.lua` verifies staged Minimums rows group at the top, expose `ADD` / `EDIT` / `DELETE` badges, and reveal staged-summary plus `Revert All` footer affordances only while drafts exist.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums now uses separate `Enabled Only` and `Show All` buttons with active-state highlighting.
- `tests/spec/auth_source_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/history_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_options_spec.lua` verify auth policy strings now preserve Restock Default plus updater metadata, Options can reload that Guild Info state, auth-policy updates appear in History newest-first, and the Blacklist tab explains the shared `[GBMBL]` officer-note contract.
- `tests/spec/auth_source_spec.lua` and `tests/spec/auth_spec.lua` also verify the compact updater-hash policy-string encoding, the removal of Guild Info blacklist membership export, and legacy blacklist-key normalization behavior.
- `tests/spec/officer_note_blacklist_spec.lua` and `tests/spec/ui_options_spec.lua` verify appended `[GBMBL]` officer-note tags, guild-roster-driven blacklist refresh, the read-only Blacklist tab guidance, the cleaner ordered-list officer-note instructions, the explicit themed `Refresh` action below the parsed-member list, the removal of the old duplicate blacklist header, and the refresh-status transition back to the parsed summary after `GUILD_ROSTER_UPDATE`.
- `tests/spec/ui_options_spec.lua` also covers the extra Blacklist footer padding, the aligned `Data` dropdown headings, the equal-width centered clear-data buttons, and the matched `UI Scale` / opacity slider widths.
- `tests/spec/ui_requests_spec.lua` verifies request creation reparses guild-backed blacklist state before submit and denies newly blacklisted actors.
- `tests/spec/diff_spec.lua`, `tests/spec/bank_ledger_scanner_spec.lua`, and `tests/spec/sync_spec.lua` verify opening the guild bank auto-scans only after the 10-minute throttle window, retries long enough for delayed tab metadata on reopen, waits briefly between queried tabs, ignores suspicious partial auto-scan snapshots when a previously populated tab reads empty, still forces one bank-open ledger scan when the main snapshot or ledger freshness interval would otherwise skip it, prevents pending ledger scans from starting during the main inventory scan, hard-defers direct ledger scan requests until inventory scanning finishes without letting passive requests hide a visible manual follow-up, self-chains passive ledger refresh only after the active scan finishes, while manual scan remains unaffected and the scanner event adapter now owns `GUILDBANKFRAME_OPENED`.
- `tests/spec/sync_spec.lua` verifies synced request creation writes local history, higher-authority request updates win conflict resolution, synced approvals recreate the matching Minimums rule plus history rows on receiving clients, officer-authored minimum snapshots are accepted while member-authored snapshots are rejected, remote ledger deltas merge without advancing the local scan timer, persisted peer history stays partitioned by guild, retired auth-policy snapshots stay ignored, and sync milestone chat feedback is emitted for hello, accepted sync, and ignored forged payloads.
- `tests/spec/sync_spec.lua` also verifies request sync rejects non-guildmaster self-approval updates and forged cancellation updates while accepting author cancellations.
- `tests/spec/ui_minimums_sync_spec.lua` verifies `Minimums -> Save All` now publishes the guild-scoped `MINIMUMS_SNAPSHOT` message family through addon communication.
- `tests/spec/sync_peer_state_spec.lua` verifies persisted sync-peer history stores `lastSeen`, `lastMessageType`, and `version` by guild so one guild's sync state cannot bleed into another.
- `tests/spec/planning_spec.lua` verifies approved requests converted into Minimums rules do not double-count demand as both request demand and restock demand.
- `tests/spec/dashboard_spec.lua` verifies the dashboard ignores zero-shortage demand rows for `Ready to Buy` counting and now ranks the `Top 10 Most Used` card by ledger-backed withdrawals before falling back to older shortage-history behavior.
- `tests/spec/ui_shell_spec.lua` verifies the shell opts into top-level ordering, raises on click, and keeps registered modals layered above the shell when focus changes.
- `tests/spec/ui_shell_spec.lua`, `tests/spec/ui_table_spec.lua`, `tests/spec/ui_requests_spec.lua`, and `tests/spec/ui_options_spec.lua` verify the shell now defaults below higher-priority dialogs, hides zero-range shared scrollbars, preloads auth policy from Guild Info on options open, applies shell and modal opacity to backdrop or art layers without dimming content, keeps scaled table layouts inside the shell viewport, keeps top-bar scan plus status controls from overlapping when scaled, uses built-in WoW `UISliderTemplate` appearance controls, exposes the six-tab Options shell (`Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, `Sync`, `Data`), keeps appearance plus sync plus data controls inside their panel chrome, and lets appearance sliders release cleanly even when the mouse-up happens off the bar.
- `tests/spec/ui_dashboard_spec.lua`, `tests/spec/ui_requests_spec.lua`, `tests/spec/ui_options_spec.lua`, `tests/spec/ui_exports_spec.lua`, and `tests/spec/ui_minimums_spec.lua` also verify the current contrast pass: dashboard quick actions now get room to wrap labels, footer/action-strip buttons contrast from their parent surfaces, export CTAs share one primary treatment, request/minimums/options dropdown triggers use the dedicated select control styling, the `Requests` and `Minimums` lower strips now reuse the same flatter footer surface as `Bank Ledger`, and `Options -> Data` plus `Bank Ledger` now route through the addon-local dropdown panel path instead of cycling labels on click while surfacing visible save confirmation.
- `tests/spec/ui_shell_spec.lua` and `tests/spec/ui_options_spec.lua` also verify the newer art-layer shell contract: reusable frame background textures, nav accent bars, flatter toolbar or content chrome with fewer framed edges, reduced reliance on full backdrop borders for flat shell surfaces, short timezone abbreviations in the top header, sidebar crest-footer behavior, minimap-button toggling, the persisted Sync peer list, and the six-tab Options shell contract. The minimap launcher now acts as a true toggle: first click opens the addon and the next click closes it.
- `tests/spec/bank_ledger_spec.lua`, `tests/spec/bank_ledger_scanner_spec.lua`, and `tests/spec/ui_bank_ledger_spec.lua` verify append-only guild-bank log delta capture, repeated scans of the same visible log window not duplicating prior rows, preserving a legitimately new leading row even when it matches an older row exactly, tolerating rows with missing explicit date parts, `GuildBankLedger`-style session batch-count merging for shrinking/regrowing same-identity batches, event-driven ledger log querying across all accessible item tabs plus the fixed Blizzard money-log slot, scanner-driven fully rotated item-log and money-log windows appending instead of getting stuck behind stale no-overlap source snapshots, debounced `GUILDBANKLOG_UPDATE` handling for delayed money-log rows, live `GUILDBANKLOG_UPDATE` wakeups that queue or start silent passive ledger scans without racing the main inventory scan, stable visible-tab behavior during ledger imports, configurable repair-threshold classification, the shared configurable `Scan Interval` throttling both guild-bank auto-scan and ledger rescans, the newer player-interaction open/hide event path for passive rescans, reload-safe passive rescans when the bank is already open after `/reload`, active `Bank Ledger` table refresh when passive imports add rows, direct ledger rescans when the inventory snapshot is already fresh, handoff from the main guild-bank scan into ledger capture, retention pruning, ledger CSV export with readable timestamps, item-vs-money table modes, real dropdown-backed action filtering, and user/item summary reporting. Stale historical ledger-cache recovery is no longer a required contract; use `Options -> Data -> Clear Guild Bank Log Data` for a clean ledger reset if older local data was polluted.
- `tests/spec/ui_inventory_spec.lua` verifies the Inventory footer CSV action, shared export-modal wiring, and filtered visible-row CSV output.
- `tests/spec/ui_shell_spec.lua` also verifies the manual `Scan Bank` button explicitly requests the ledger follow-up in addition to the normal inventory snapshot.
- `tests/spec/ui_about_spec.lua` verifies the dedicated branded About panel, crest/icon slot, trimmed guild-only identity copy, concise `/gbm help` hint, and removal of the old generic body-text fallback.
- `tests/spec/ui_table_spec.lua` now also verifies dedicated table header/filter/viewport surface variants, stronger semantic alternating row-token styling, row separators without boxed side edges, and higher-contrast filter inputs that sit forward from the darker filter band.
- `tests/spec/ui_table_spec.lua` also verifies shared table filters keep visible spacing between adjacent search boxes instead of rendering as one continuous hard-edged strip.
- `tests/spec/history_spec.lua` and `tests/spec/ui_history_spec.lua` verify History stays newest-first, removes visible `Old Value` plus `New Value` grid columns, and exposes those values through a row-click `History Details` modal instead.
- `tests/spec/ui_requests_spec.lua` and `tests/spec/ui_minimums_spec.lua` now also verify the shared button-variant contracts for request admin filters, request wizard CTAs, destructive request actions, and Minimums modal actions.
- `tests/spec/ui_exports_spec.lua` verifies the floating manual shopping list stays independent from the main shell, remembers its saved position, and keeps normalized low-tier crafted icons in fallback rows.
- `tests/spec/ui_exports_spec.lua` now also verifies export action-card icon slots plus the `Generate` / `Open List` CTA labels used by the modernized cards.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` also verify the `Excess Qty` drill-in now keeps the count as plain cell text while rendering a separate right-aligned arrow icon affordance, and that the exports-specific crafted-tier inline fallback still preserves the expected two-rank icon family when the row only knows the tier value.
- `tests/spec/ui_exports_spec.lua` also verifies the cleaner export-card spacing and the removal of the ghost container behind the action-card row.
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
