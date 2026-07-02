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

All `tests/spec/*_spec.lua` files must be listed in exactly one local lane. The
lane manifests live in `tests/helpers/spec_lanes.lua`, and
`tests/spec/test_runner_spec.lua` fails when a spec is missing from every lane or
appears in more than one lane.

- `unit`
  - domain rules for auth, requests, exports, planning, sync, store, and scan persistence
  - sync transport chunking/reassembly coverage for oversized addon-message payloads so request, minimum, and ledger sync traffic stay within WoW's base addon-message size limit
  - guild-scoped request routing, including request-management broadcasts that no longer whisper resolved roster recipients, officer-authoritative minimum snapshot acceptance or rejection, stale minimum snapshot preservation plus reciprocal catch-up replies, login hello catch-up dispatch by local access profile, 1.2.0 ledger protocol reset coverage, manifest-first ledger sync coverage, stale-manifest bucket pushback, bucket request/reply row transfer, malformed bucket-payload rejection, old or missing ledger protocol rejection, ledger chat emitted only when rows are written, persisted peer-history buckets keyed by guild, and the retired auth-policy addon-comm path staying disabled
  - dashboard ranking and ledger-withdrawal-only coverage for the `Top 10 Most Used` card
  - routine chat suppression coverage through the shared chat-output helper, including default-on muted routine sync or scan chatter while errors and explicit debug output remain visible
  - migration/default-shape coverage, including the persisted live-smoke result container
- `ui`
  - shell layout, shared table behavior, requests, exports, minimums, and options/auth ownership specs
  - focused regression checks for shared scrollbars, request-only layout, options auth state, bundled indexed item-search behavior, the Minimums modal handoff from search into details, staged-row grouping, dashboard card or panel composition, shared visible crafted-tier symbols, slider drag-release behavior, shell surface variants, sidebar crest-footer behavior, tabbed Options navigation, and the persisted `Options -> Sync` peer-history view
  - shell-polish contracts for softer nav metadata, toolbar-band header state, timezone-bearing last-scan rendering, flatter dashboard/table surface variants, slimmer action-family routing, segmented-tab metadata, cleaner floating-sheet modal variants, dense-clean spacing, stronger neutral action contrast, higher-contrast select/dropdown triggers, wrapped dashboard quick-action labels, LibDBIcon-style minimap-ring placement, Escape-to-close shell handling that leaves the independent manual shopping list open, and the dedicated `Stock Settings` tab
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
  - confirms local appearance controls cover the token-backed theme presets (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), a single linked `UI Scale` slider with a 90%-120% range, shell opacity, modal opacity, active-nav glow, collapsed-nav icons, the minimap-button toggle, the minimap launcher snapping to the minimap ring with a `GuildBankManager` hover tooltip, the default-on `Suppress Chat Except Sync Changes` toggle, and enough panel chrome behind every Appearance control
  - confirms the shell yields behind other dragged UI until clicked back to the front again
  - confirms the manual shopping list can stay open across tab switches, shell close, or Escape closing the shell, remembers its moved position, requires its close X, and keeps low-tier crafted icons normalized even when the source row has no live stock snapshot
  - auth policy publishing is manual in Retail: use `Save`, use `Select All` or mouse selection on the `Policy String`, paste it into `Guild Information`, press `Accept`, then use `Refresh Guild Info` to verify the live string
  - blacklist membership is no longer stored in Guild Info: edit a guild member's officer note manually, add or remove `[GBMBL]`, then confirm `Options -> Blacklist` can refresh the read-only parsed roster view
  - the themed crest art should swap when theme presets change, and the minimap button should appear or disappear immediately when the appearance toggle changes
  - item search should use the required bundled `GBankManager_ItemData` payload; if that payload is unavailable, the search UI should report the unavailable state clearly instead of showing misleading sparse local-only name results
  - Minimums should open a centered details modal after a confirmed add-search selection instead of dropping the user into the old footer editor flow
  - request search, request details, the request wizard preview, and Minimums details should prefer hyperlink-style item text when trusted stored links exist and should fall back to plain names when they do not. Request details and Minimums details should not rely on separate visible quality rows, while the New Request wizard selector may show a small shared-display quality icon to distinguish duplicate-name crafted variants.
  - Inventory should keep its dedicated texture path, while Minimums, Requests, Exports, and the manual shopping list should prefer the bundled canonical single-silver-diamond / gold-pentagon family for true two-rank crafted families, only consult live reagent-quality atlases if the canonical path is unavailable, and use the reagent-style medal atlases only as a last resort
  - shared table texture slots should defensively normalize stale two-rank atlas families at the final render boundary so persisted or legacy row data cannot reintroduce copper-diamond, double-silver, chat-quality, or reagent-medal icons when the row has two-rank crafted-family metadata
  - `/gbm debug atlas` should open a labeled visual atlas sampler for live-client crafted-quality investigation, `/gbm debug quality <itemID>` should continue to print item-aware resolver diagnostics, `/gbm debug render <itemID>` should print active table row data plus the visible row texture atlas after painting, `/gbm debug request <itemID>` should print New Request wizard selector row or selected-item icon diagnostics, and `/gbm debug sync` should print the local identity plus the last sync envelope, decision, and peer keys for the active guild
  - Inventory and Minimums should share the same table layout, and Minimums should use a compact transparent action strip instead of the old boxed footer search/editor panel
  - Minimums draft rows should clearly show green `added`, yellow `changed`, and red `deleted` state before `Save All`
  - Minimums should backfill crafted tier from the bundled catalog when snapshot or scan data omits `craftedQuality` and `craftedQualityIcon`
  - request-only access should keep the compact request shell available through `/gbm`, with `Requests`, `Options`, and `About` navigation, while `/gbm request` should still jump straight into the three-step `New Request` wizard with progress rail, preview card, quantity steppers, and explicit quantity/reason labeling
  - `Requests` should use details-modal workflow actions only, with the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, a `Refresh` button beside `Add Request`, and no top workflow action box.
  - Approved open requests should be auto-marked fulfilled by a guild-bank scan once scanned inventory meets the requested quantity, and fulfilled requests should retain Date Fulfilled.
  - Exports should show four export action cards, visible-table CSV output, direct Auctionator and TSM output modals, and a stocked-elsewhere tab/quantity detail modal.
  - Dashboard should show four metric cards plus `Top 10 Most Used`, `Recent Activity`, and `Quick Actions`
  - `Options -> Stock Settings` should let you change both `Restock Default` and the `Critical Shortage Threshold`, and the dashboard card should update its critical count using that percentage rule
  - `Options -> Data` should let you open real dropdown menus for guild-bank ledger retention, audit-history retention, and the guild-bank `Scan Interval`, should expose the repair-threshold input, should keep the save button inside the panel chrome, should show visible save feedback after `Save Settings`, should surface a `Clear Data` section with confirmation-gated destructive actions, and saving those settings should prune out-of-window Bank Ledger item/money rows plus audit-history rows when retention is finite while leaving Minimums, Requests, and sync peers alone. Inventory snapshots are separately compacted to the active snapshot plus two recent backups. The immediate local toggles under `Options -> Appearance`, including `Mute Silvermoon Citizen` and `Suppress Chat Except Sync Changes`, should persist after `/reload`.
  - `Bank Ledger` should pick up new log rows while the guild bank remains open, without needing another manual `Scan Bank`, including after `/reload` or relog when the guild bank is already open and passive refresh has to recover from live bank-open state instead of waiting for a fresh open event
  - `Exports` should keep the non-zero `Excess Qty` count visible, add a right-aligned drill-in arrow affordance in that cell, and the drill-in modal should summarize the total off-tab excess plus the per-tab breakdown
  - `Bank Ledger` should switch cleanly between `Item Log` and `Money Log`, open real dropdowns for the action filter and preset date-range filter, keep the shared table shell, filter by action plus date range, export the filtered rows to CSV with readable date-time values instead of raw integers, show item rows as `Date`, `Who`, `Action`, icon `Tier`, `Item`, `Quantity`, `Tab`, and `Moved From`, and keep the bottom summaries reduced to item totals plus gold totals that update from the selected date range
  - `Inventory` should expose an `Export CSV` action below the shared table and open the shared export modal with the currently filtered inventory rows
  - sync should report compact chat feedback for accepted incoming updates without turning the chat frame into a step-by-step spam log, while login-triggered catch-up stays silent and ledger reject/no-change details remain available through `/gbm debug sync`
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
- `tests/spec/diff_spec.lua` also verifies stocked one-time Minimums (`Restock: No` with a positive minimum quantity) are removed after a successful guild-bank scan, emit normal `MINIMUM_REMOVED` history, preserve understocked one-time rows, preserve recurring `Restock: Yes` rows, and publish the updated `MINIMUMS_SNAPSHOT`.
- `tests/spec/store_spec.lua` verifies fresh scans persist tab-scoped item rows in saved variables.
- `tests/spec/inventory_quality_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums `Show All` render one row per bank tab with per-tab quantities.
- `tests/spec/ui_table_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify Inventory and Minimums share the same column order, including a wider `Item` column and matching table height.
- `tests/spec/ui_table_spec.lua` verifies shared table content stops before the external slim scrollbar so the bar does not overlap the rightmost column.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums uses shared table filters, hides the old bottom search, and keeps only the compact three-button action strip below the table.
- `tests/spec/ui_minimums_spec.lua` verifies existing saved minimum rows auto-populate Bank Tab as a read-only value, including legacy saved rows that need the tab inferred from the table row.
- `tests/spec/minimums_portability_spec.lua` verifies portable Minimums export emits the versioned `gbankmanager.minimums` payload shape, import parsing accepts valid rows, flags missing local tabs as `needs_tab`, and rejects malformed or wrong-schema payloads.
- `tests/spec/ui_requests_spec.lua` verifies the full-shell `Requests` surface has no inline creation panel or top workflow action box, uses shared table filters, includes date requested plus date fulfilled, exposes the bottom `All` / `Pending Approval` / `Pending Fulfillment` / `Completed` filter strip, and keeps `Add Request` plus `Refresh` on the left edge.
- `tests/spec/ui_requests_spec.lua` also verifies request-only mode uses the smaller titled request shell, restricts sidebar navigation to `Requests`, `Options`, and `About`, limits `Options` to `Appearance`, `Sync`, and `Data`, preserves row-click details, and keeps the item -> quantity/reason -> review request wizard, including progress-rail state, preview visibility, and quantity steppers.
- `tests/spec/ui_requests_spec.lua` verifies request details align values to fixed modal columns, render crafted-quality icons inline beside the shared item display without leaving the retired quality-row gap, labels the Decision Note input, keeps details open after approval, prompts approvers for Bank Tab, leaves breathing room above the Approval Bank Tab control, and saves approval-created Minimums rules.
- `tests/spec/ui_requests_spec.lua` also verifies request modals block table click-through, request details use fixed label/value rows, show Requested By above Date Requested, show Updated By and Date Updated near the bottom with Decision Note, hide the decision-note editor after approval or denial, and align workflow buttons with Close.
- `tests/spec/ui_requests_spec.lua` also verifies request table rows and wizard-created requests preserve semantic crafted-quality metadata (`craftedQualityMax`, `craftedQualityFamilySize`, and canonical display/preferred atlases), so the shared table renderer can remap live two-rank chat atlases to the same single-silver-diamond and gold-pentagon icon family used by Minimums and Exports.
- `tests/spec/requests_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/auth_source_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_requests_spec.lua` verify the new request-delete permission, stored delete action, delete sync handling, the request-details `Delete` workflow path, and the single-broadcast guild sync contract for managed request updates.
- `tests/spec/requests_spec.lua` verifies stored request actions still work when no explicit auth policy is present, while auth-policy-backed denial paths remain covered, no request auto-approves, non-guildmaster self-approval is blocked, Guild Master self-approval remains an explicit workflow action, approval metadata preserves Decision Note and Bank Tab, and authors can cancel pending own requests.
- `tests/spec/requests_spec.lua` verifies request audit history stores actor names instead of Lua actor tables, and approved open requests can be auto-fulfilled from a bank scan when inventory meets the requested quantity.
- `tests/spec/store_spec.lua` verifies fresh guild-bank scans auto-fulfill approved open requests and store Date Fulfilled from the scan timestamp.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` verify the reworked Exports table columns, stocked-elsewhere modal, `Excess Stock` and `None` labeling, crafted-quality icon rendering, export action cards, CSV output modal, direct Auctionator output, and TSM item-ID import output.
- `tests/spec/exports_spec.lua` and `tests/spec/ui_exports_spec.lua` also verify Auctionator's current caret-delimited import format, the line-broken local-only note in the manual shopping list helper, clearer built-in checkboxes, and the canonical single-silver or gold-pentagon two-rank quality icons inside that helper.
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
- `tests/spec/ui_options_spec.lua` also verifies the latest Appearance/Data relayout: `UI Scale` now lives in the right-hand slider column above shell and modal opacity, the minimap toggle sits directly under the theme presets, the Appearance panel background chrome grows with newly added controls, the `Data` dropdown labels stay aligned on one row inside the panel chrome, and the repair-threshold plus mute controls persist alongside the ledger scan settings.
- `tests/spec/slash_commands_spec.lua` verifies `/gbm` now opens the accessible UI instead of scanning, request-only access lands on the request-only `Requests` shell without auto-opening the request wizard, and `/gbm help` prints the supported slash-command list in chat.
- `tests/spec/slash_commands_spec.lua` also verifies `/gbm debug ledger` prints copy-friendly scanner state plus raw Blizzard item-log and money-log counts/sample rows for live ledger import investigations.
- `tests/spec/slash_commands_spec.lua` also verifies `/gbm debug sync` prints the local player identity, last decoded sync envelope, last accept or reject reason, and stored peer keys so live request-sync investigations can compare client state without adding ad hoc chat prints.
- `tests/spec/sync_spec.lua` now also verifies sync hello traffic can bootstrap peer presence for a client whose root still points at the placeholder `Unknown Guild` without dispatching the full manual sync family set, and that request snapshots can canonicalize stored peer identities to `Character-Server` and promote the live guild key before peers are filed or request snapshots are rejected as `wrong_guild`.
- `tests/spec/ui_options_spec.lua` now also verifies the `Options -> Sync` table refreshes immediately when new guild hello traffic arrives while the Sync tab is already open, that the Sync peer subtable sizes its scroll child plus visible rows to a real drawable width so peers render in the live client instead of disappearing inside a zero-width clipped region, and that each peer row exposes an inline destructive remove control that clears only that one stored peer.
- `tests/spec/sync_spec.lua` now also verifies legacy or missing-protocol ledger manifest traffic is rejected before it can mutate the ledger, while accepted bucket replies that merge zero rows stay quiet in chat and positive bucket merges emit only one compact status line.
- `tests/spec/sync_ledger_manifest_spec.lua` verifies manifest building, six-hour bucket hashes, matching vs differing manifest comparison, targeted bucket requests, direct bucket replies to stale manifest senders, bucket replies, off-target request or reply ignores, and manual `Sync Ledger` manifest announcements.
- `tests/spec/sync_spec.lua` now also verifies `GUILDBANK_UPDATE_TABS` and `GUILDBANKBAGSLOTS_CHANGED` do not arm an auto-scan when the guild bank is actually closed, even if stale tab APIs still report accessible tabs after `/reload`.
- `tests/spec/slash_commands_spec.lua` also verifies `/gbm debug quality <itemID>` help text plus chat output, including the lazy-load fallback path, the final inventory display atlas, and the final non-inventory atlas, so crafted-quality live diagnostics still speak in chat even if the helper module registry dropped out before `/reload`.
- `tests/spec/bank_ledger_spec.lua` now also verifies that a fully rotated busy money-log window still appends the newly visible rows instead of being discarded as a suspicious same-size no-overlap batch.
- `tests/spec/bank_ledger_spec.lua` also verifies real repeated item and money activity appends when the same actor later moves the same item/quantity or gold amount again, and that the ledger uses a `GuildBankLedger`-style session batch-count merge so same-identity batches can shrink and regrow without losing new rows.
- `tests/spec/bank_ledger_spec.lua` also verifies source-stable money dedupe uses persisted row fingerprints instead of runner-local timestamp formatting, so release runners in another timezone keep the source-matching row during cleanup.
- `tests/spec/toc_spec.lua` and `tests/spec/ui_about_spec.lua` verify `GBankManager.toc` carries the current addon `Version` metadata and that the About panel renders that semantic version alongside the local build stamp.
- `tests/spec/ui_minimums_spec.lua` verifies staged Minimums rows group at the top, expose `ADD` / `EDIT` / `DELETE` badges, reveal staged-summary plus `Revert All` footer affordances only while drafts exist, keep the shared selector's crafted-quality icons visible in Minimums search results plus the selected-item summary just like Requests, preserve the typed minimum value when the add-search modal hands off into `Minimum Details`, and keep the lower add-search controls from shifting right when the selected-item icon appears.
- `tests/spec/ui_minimums_spec.lua` verifies Minimums now uses separate `Enabled Only` and `Show All` buttons with active-state highlighting.
- `tests/spec/ui_minimums_spec.lua` also verifies the portable import review flow stages rows instead of writing immediately: missing imported tabs block apply until a local tab is chosen, review rows can be edited before confirm, and accepting the review feeds the existing draft/save workflow rather than mutating saved Minimums directly.
- `tests/spec/ui_minimums_spec.lua` also verifies the Minimums import modal uses a wider scrollable layout: the pasted payload field now opens focused inside a visible dedicated input surface, parse failures stay in a clean status line without raw Lua file paths, imported review rows render inside a scrollable viewport only after preview succeeds, action buttons stay anchored in the modal footer, and crafted-quality review rows show their icon in the review list.
- `tests/spec/ui_minimums_spec.lua` also verifies the portable Minimums export modal pretty-prints the JSON payload into the shared scrollable output surface and exposes the same `Select All` copy guidance used by the other export modals.
- `tests/spec/auth_source_spec.lua`, `tests/spec/auth_spec.lua`, `tests/spec/history_spec.lua`, `tests/spec/sync_spec.lua`, and `tests/spec/ui_options_spec.lua` verify auth policy strings now preserve Restock Default plus updater metadata, Options can reload that Guild Info state, auth-policy updates appear in History newest-first, and the Blacklist tab explains the shared `[GBMBL]` officer-note contract.
- `tests/spec/auth_source_spec.lua` and `tests/spec/auth_spec.lua` also verify the compact updater-hash policy-string encoding, the removal of Guild Info blacklist membership export, and legacy blacklist-key normalization behavior.
- `tests/spec/officer_note_blacklist_spec.lua` and `tests/spec/ui_options_spec.lua` verify appended `[GBMBL]` officer-note tags, guild-roster-driven blacklist refresh, the read-only Blacklist tab guidance, the cleaner ordered-list officer-note instructions, the explicit themed `Refresh` action below the parsed-member list, the removal of the old duplicate blacklist header, and the refresh-status transition back to the parsed summary after `GUILD_ROSTER_UPDATE`.
- `tests/spec/ui_options_spec.lua` also covers the extra Blacklist footer padding, the aligned `Data` dropdown headings, the equal-width centered clear-data buttons, and the matched `UI Scale` / opacity slider widths.
- `tests/spec/ui_requests_spec.lua` verifies request creation reparses guild-backed blacklist state before submit and denies newly blacklisted actors.
- `tests/spec/diff_spec.lua`, `tests/spec/bank_ledger_scanner_spec.lua`, and `tests/spec/sync_spec.lua` verify opening the guild bank auto-scans only after the 10-minute throttle window, retries long enough for delayed tab metadata on reopen, waits briefly between queried tabs, ignores suspicious partial auto-scan snapshots when a previously populated tab reads empty, still forces one bank-open ledger scan when the main snapshot or ledger freshness interval would otherwise skip it, prevents pending ledger scans from starting during the main inventory scan, hard-defers direct ledger scan requests until inventory scanning finishes without letting passive requests hide a visible manual follow-up, self-chains passive ledger refresh only after the active scan finishes, while manual scan remains unaffected and the scanner event adapter now owns `GUILDBANKFRAME_OPENED`.
- `tests/spec/sync_spec.lua` verifies synced request creation writes local history, higher-authority request updates win conflict resolution, synced approvals recreate the matching Minimums rule plus history rows on receiving clients, officer-authored minimum snapshots are accepted while member-authored snapshots are rejected, fresh `Unknown` guild roots promote to the live or synced guild before valid request traffic is applied, remote ledger deltas merge without advancing the local scan timer, older or missing-version ledger deltas are rejected as `older_version`, persisted peer history stays partitioned by guild, retired auth-policy snapshots stay ignored, login hello silently dispatches the catch-up families allowed by the receiver's local access profile, and sync milestone chat feedback is emitted for accepted sync updates without adding ledger no-change chatter.
- `tests/spec/sync_spec.lua` also verifies inbound request updates, request snapshots, minimum snapshots, and ledger deltas are only accepted from the `GUILD` addon channel, so same-guild payloads delivered over `WHISPER` are rejected before they can mutate local state.
- `tests/spec/sync_spec.lua` also verifies request sync rejects non-guildmaster self-approval updates and forged cancellation updates while accepting author cancellations.
- `tests/spec/sync_spec.lua` now also verifies accepted remote request snapshots reconstruct the existing local `REQUEST_*` History rows when a snapshot is what catches a client up, accepted remote minimum snapshots reconstruct the existing local `MINIMUM_*` History rows while staying quiet on identical replays, accepted remote `HISTORY_SNAPSHOT` payloads merge only the visible History-tab rows without duplicating identical replays or importing hidden ledger-only audit rows, and inbound `SYNC_HELLO` updates peer presence without triggering the `Sync All` catch-up family set for the receiver's local access profile.
- `tests/spec/ui_minimums_sync_spec.lua` verifies `Minimums -> Save All` now publishes the guild-scoped `MINIMUMS_SNAPSHOT` message family through addon communication.
- `tests/spec/sync_peer_state_spec.lua` verifies persisted sync-peer history stores `lastSeen`, `lastMessageType`, and `version` by guild so one guild's sync state cannot bleed into another, and that deleting one stored peer only removes that peer from the requested guild bucket.
- `tests/spec/planning_spec.lua` verifies approved requests converted into Minimums rules do not double-count demand as both request demand and restock demand.
- `tests/spec/dashboard_spec.lua` verifies the dashboard ignores zero-shortage demand rows for `Ready to Buy` counting and now ranks the `Top 10 Most Used` card by ledger-backed withdrawals before falling back to older shortage-history behavior.
- `tests/spec/chat_output_spec.lua` verifies the reusable chat-output helper defaults routine messages on, suppresses routine scan and sync chatter when the global setting is enabled, keeps scanner status text updated while muted, and leaves explicit debug or error output visible.
- `tests/spec/ui_shell_spec.lua` verifies the shell opts into top-level ordering, raises on click, and keeps registered modals layered above the shell when focus changes.
- `tests/spec/ui_shell_spec.lua`, `tests/spec/ui_table_spec.lua`, `tests/spec/ui_requests_spec.lua`, and `tests/spec/ui_options_spec.lua` verify the shell now defaults below higher-priority dialogs, hides zero-range shared scrollbars, preloads auth policy from Guild Info on options open, applies shell and modal opacity to backdrop or art layers without dimming content, keeps scaled table layouts inside the shell viewport, keeps top-bar scan plus status controls from overlapping when scaled, uses built-in WoW `UISliderTemplate` appearance controls, exposes the six-tab Options shell (`Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, `Sync`, `Data`), keeps the immediate local Appearance toggles including `Suppress Chat Except Sync Changes` inside their panel chrome, keeps appearance plus sync plus data controls inside their panel chrome, keeps the Sync peer-table action column inset from the table edge with a reserved scrollbar gutter, and lets appearance sliders release cleanly even when the mouse-up happens off the bar.
- `tests/spec/ui_dashboard_spec.lua`, `tests/spec/ui_requests_spec.lua`, `tests/spec/ui_options_spec.lua`, `tests/spec/ui_exports_spec.lua`, and `tests/spec/ui_minimums_spec.lua` also verify the current contrast pass: dashboard quick actions now get room to wrap labels, footer/action-strip buttons contrast from their parent surfaces, export CTAs share one primary treatment, request/minimums/options dropdown triggers use the dedicated select control styling, the `Requests` and `Minimums` lower strips now reuse the same flatter footer surface as `Bank Ledger`, and `Options -> Data` plus `Bank Ledger` now route through the addon-local dropdown panel path instead of cycling labels on click while surfacing visible save confirmation.
- `tests/spec/ui_shell_spec.lua` and `tests/spec/ui_options_spec.lua` also verify the newer art-layer shell contract: reusable frame background textures, nav accent bars, flatter toolbar or content chrome with fewer framed edges, reduced reliance on full backdrop borders for flat shell surfaces, short timezone abbreviations in the top header, sidebar crest-footer behavior, minimap-button toggling and hover tooltip, the persisted Sync peer list, and the six-tab Options shell contract. The minimap launcher now acts as a true toggle: first click opens the addon and the next click closes it.
- `tests/spec/bank_ledger_spec.lua`, `tests/spec/bank_ledger_scanner_spec.lua`, `tests/spec/sync_ledger_manifest_spec.lua`, `tests/spec/ui_bank_ledger_spec.lua`, and `tests/spec/ui_options_spec.lua` verify append-only guild-bank log capture, repeated scans of the same visible log window not duplicating prior rows, preserving legitimate repeated activity, durable count-based ledger row identity, 1.2.0 clean-baseline reset, event-driven ledger log querying across all accessible item tabs plus the fixed Blizzard money-log slot, scanner-driven fully rotated item-log and money-log windows appending instead of getting stuck behind stale no-overlap source snapshots, debounced `GUILDBANKLOG_UPDATE` handling for delayed money-log rows, native scans publishing `LEDGER_MANIFEST` when local rows are written or when a throttled peer catch-up manifest is needed, bucket manifest match/mismatch coverage including stale-client catch-up replies, bucket reply merge coverage without outbound sync echo, malformed bucket-row rejection, configurable repair-threshold classification, the shared configurable `Scan Interval`, reload-safe passive rescans, active `Bank Ledger` table refresh when passive imports add rows, retention pruning for ledger item/money rows and audit history, ledger CSV export with readable timestamps, item-vs-money table modes, real dropdown-backed action filtering, and user/item summary reporting. This version intentionally clears ledger data once on first load, hides the manual `Options -> Data -> Dedupe Ledger` button, and relies on versioned load-time money cleanup for duplicate recovery.
- `tests/spec/bank_ledger_scanner_spec.lua` verifies passive guild-bank ledger refresh can keep importing newly visible rows while the bank stays open without printing repeated `auto-refresh found` row-count status lines.
- `tests/spec/bank_ledger_scanner_spec.lua` verifies a no-change ledger scan can still announce a throttled manifest when known guild peers may be stale, so a fuller client does not require manual `Sync Ledger` just to advertise existing item or money rows.
- `tests/spec/bank_ledger_spec.lua` verifies raw relative Blizzard money-log rows (`0/0/0` plus visible hour) do not duplicate when later scans or sync payloads mint different absolute timestamps for the same visible money entry, including short-window raw-relative deposit rows whose visible hour drifts during bank-open rescans, and that the internal ledger dedupe planner still flags existing duplicate relative money rows for cleanup coverage while the visible Data-tab action remains hidden.
- `tests/spec/store_spec.lua` verifies the v1.2.3 load-time money-ledger cleanup removes duplicate raw-relative money rows once, preserves item ledger rows, clears polluted money caches and stale ledger sync debug state, records `meta.moneyLedgerDedupedForVersion = 1.2.3-money-v7`, and reruns recovery for v6-stamped clients that may still carry Client-A-shaped drifted deposit duplicates. It also verifies the v1.2.3 SavedVariables compaction pass removes generated snapshot search catalogs, prunes inventory snapshots to the active snapshot plus two recent backups on load and after fresh scans, preserves durable rows in retained snapshots, caps raw inventory diff diagnostics to the newest 500 rows, and records `meta.savedVariablesCompactedForVersion = 1.2.3-snapshot-v3`.
- `tests/spec/sync_spec.lua` and `tests/spec/sync_ledger_manifest_spec.lua` verify current ledger protocol 3 rejects older same-version protocol-2 ledger manifests, bucket replies, and direct ledger deltas as `old_ledger_protocol`, so older 1.2.3 builds cannot re-poison repaired money ledgers.
- `tests/spec/ui_requests_spec.lua` and `tests/spec/ui_minimums_spec.lua` verify request and minimum item searches build transient search catalogs without persisting generated catalog tables back onto saved inventory snapshots.
- `tests/spec/planning_spec.lua` and `tests/spec/exports_spec.lua` verify disabled positive Minimums behave as one-time targets: they contribute `ONE_TIME_TARGET` export demand while understocked, stop contributing once stocked, and leave recurring `Restock: Yes` demand labeled as `RESTOCK`.
- `tests/spec/ui_minimums_spec.lua` verifies a positive new Minimum staged from a bank-backed `Show All` row defaults to Restock enabled for recurring behavior, while an explicit Restock disable stages the rule as a one-time target instead of deleting the target.
- `tests/spec/ui_inventory_spec.lua` verifies the Inventory footer CSV action, shared export-modal wiring, and filtered visible-row CSV output.
- `tests/spec/ui_shell_spec.lua` also verifies the manual `Scan Bank` button explicitly requests the ledger follow-up in addition to the normal inventory snapshot.
- `tests/spec/ui_about_spec.lua` verifies the dedicated branded About panel, crest/icon slot, trimmed guild-only identity copy, concise `/gbm help` hint, and removal of the old generic body-text fallback.
- `tests/spec/ui_table_spec.lua` now also verifies dedicated table header/filter/viewport surface variants, stronger semantic alternating row-token styling, row separators without boxed side edges, and higher-contrast filter inputs that sit forward from the darker filter band.
- `tests/spec/ui_table_spec.lua` also verifies shared table filters keep visible spacing between adjacent search boxes instead of rendering as one continuous hard-edged strip.
- `tests/spec/history_spec.lua` and `tests/spec/ui_history_spec.lua` verify History stays newest-first, removes visible `Old Value` plus `New Value` grid columns, exposes those values through a row-click `History Details` modal instead, and limits History sync snapshots to the same visible Request, Minimum, and auth-policy rows that the page already renders.
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

## Retail Deploy

For this repo's normal local live-client flow, prefer the repo deployment helper over manual folder copy:

1. Check the resolved target and AddOns path:
   - `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Get-ItemCatalogMaintainerStatus.ps1 -Target Retail -Json`
2. Deploy the current worktree state:
   - `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json`
3. On this machine, Retail should resolve to:
   - `C:\Gaming\World of Warcraft\_retail_\Interface\AddOns`
4. `/reload` in game before smoke or manual validation.

The deploy helper copies both `GBankManager/` and `GBankManager_ItemData/` from the current worktree, including uncommitted local changes.

## Live Smoke

Run these in retail only after the automated lanes pass:

1. Run `/gbm test smoke`.
2. Confirm chat prints one overall `PASS` or `FAIL` line plus individual check lines.
3. If it fails, inspect `GBankManagerDB.testing.liveSmoke` after `/reload` for the last persisted summary and check details. Pay special attention to `minimums_render` and `request_selection_gating`, because those now exercise the live modal workflow and confirmed-selection reset path rather than the older footer-editor assumptions.
4. If it passes, still do a short visual spot-check in `Options`, `Requests`, and `Minimums` for layout/art regressions the smoke cannot prove.
5. For this checkpoint's manual follow-up, also spot-check the Minimums portable import review modal: export a payload, paste it back in, reassign at least one missing Bank Tab, edit one quantity before confirm, and verify the changes land as staged rows that still require `Save All`.
6. For the current History-sync slice, also run a two-client officer check: use `Sync History` or `Sync All`, then confirm client B's `History` tab gains the same visible Request, Minimum, and auth-policy rows from client A without importing hidden ledger-only audit entries or duplicating unchanged rows on a second replay.
7. For the current ledger-sync cleanup slice, also run a ledger replay check: after installing this version and reloading once, confirm the Bank Ledger starts from the one-time cleared baseline, then accept or send a remote ledger sync from a same-version or newer client and confirm a repaired receiver does not gain duplicate visible money or item rows. Also confirm a missing-version or older-version ledger sync is ignored and the next local bank-open money-log scan does not append an already-known Blizzard money-log row again. Confirm `Options -> Data` does not show the manual `Dedupe Ledger` button; duplicate recovery should come from the versioned load-time cleanup marker instead.
