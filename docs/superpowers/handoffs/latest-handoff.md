# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Remote tracking: `origin/codex/gbankmanager-v1`
- Latest pushed branch commit before this checkpoint: `1480974` (`feat: land shell polish and theme branding checkpoint`)
- Latest checkpoint in this phase: the shell-polish checkpoint is now extended by the first real `Bank Ledger` implementation plus the `Data` options slice. The addon now scans guild-bank item logs and money logs as a follow-up stage of the established guild-bank scan flow, uses the configurable `Scan Interval` as both the ledger throttle and the guild-bank-open auto-scan throttle, stores append-only ledger deltas locally, exposes a shared-table `Bank Ledger` surface with item-vs-money modes, action filters, a preset date-range dropdown, CSV export, and usage summaries, moves retention plus scan-interval controls into a trimmed `Data` options tab with visible save feedback plus destructive cleanup actions, and drives the dashboard `Top 10 Most Used` card from ledger-backed withdrawal totals. Repeated ledger scans over the same visible Blizzard log window now use source-based delta overlap detection plus a fast bulk-query ledger pass patterned after `GuildBankSnapshots`: query every accessible item-log tab plus the money log up front, wait once, then merge all targets without visually switching the selected guild-bank tab. The manual `Scan Bank` button now forces the ledger follow-up even when the configured `Scan Interval` would normally throttle auto scans. The implementation plan doc for the shell pass still lives at `docs/superpowers/plans/2026-05-23-gbankmanager-ui-shell-polish-implementation.md`.
- `UI Scale` now relayouts the dashboard shell as part of the same appearance refresh path instead of only resizing the frame and shared table density. The four metric cards plus the top-items, recent-activity, and quick-actions dashboard panels now grow and shrink with shell scale, and regression coverage for that behavior lives in `tests/spec/ui_options_spec.lua`.
- The latest polish follow-up also rebalanced the options layout and dashboard actions: `UI Scale` now sits in the right-hand slider column above shell and modal opacity, `Show Minimap Button` now lives directly beneath the theme preset grid, the `Data` dropdown labels were realigned to one row inside panel chrome, and the dashboard `Quick Actions` row is now trimmed to `Add Minimum`, `Create Request`, and `Export Data`.
- The latest command and polish follow-up also tightens the remaining shell details: `/gbm` now opens the UI the current player can access instead of starting a scan, `/gbm help` prints the supported slash-command list, request-only access now opens the request wizard immediately, Blacklist keeps extra footer padding under the parsed summary line, `Options -> Data` now uses equal-width centered clear-data buttons, and `Exports` plus `Request Details` now force the same corrected reagent-style two-rank quality icons even when the source icon was already stored as chat-markup.
- Current repo status at handoff time: local working checkpoint, not yet committed or pushed. Automated tests are green via `.\tools\lua\lua.exe .\tests\run_all.lua`.
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: `PASS tests/run_all.lua`

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

- Worktree is committed and pushed through `1480974`, with the new Bank Ledger + Data slice still local-only in the worktree.
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
- Opening the guild bank now auto-starts a scan only when at least 10 minutes have elapsed since the last successful scan, and the reopen path now keeps retrying long enough for delayed tab metadata instead of giving up after the first short burst. Manual scan button or slash behavior is unchanged.
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
- Crafted-quality rendering now keeps a split display contract on purpose: Inventory and Minimums keep the compact chat-icon family, while Exports, the manual shopping list, request review, and request details now use the brighter reagent-quality icons for the two-rank low/max pair.
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
- Sync now reports milestone chat feedback for login hello, accepted incoming updates, and ignored forged payloads without writing per-step noise into chat.
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

1. `UI polish`
   - Live-review the newly landed shell-polish checkpoint in Retail against the approved browser `Target Look`.
   - If the no-art-pack shell still feels too plain in any surface, tune within the shared shell contract first rather than adding one-off boxes back in.
   - After that review, continue into the art-pack-assisted mockup-fidelity pass: sidebar crest treatment, panel trims, header banding, nav active rails, card plates, and subtle inset divider assets.
   - Re-apply any more literal dashboard composition work only after those shell assets exist.
   - Use [docs/ui-polish-suggestions.md](../../ui-polish-suggestions.md) as the refinement shelf, but treat the art pack as the next actual build step after this shell checkpoint is reviewed live.

2. `In-game unit test lane`
   - Live-verify the broadened `/gbm test unit` lane in retail after the automated lanes are green.

3. `Dashboard follow-up only if live repro exists`
   - Recheck the `Ready to Buy` mismatch against a real SavedVariables file or live client session.
   - Do not change dashboard math unless the mismatch reproduces against current live data.
   - If it does reproduce, add the dedicated `Critical Shortages` card with explicit ranking rules in that same dashboard pass.

4. `Deeper sync catch-up only if needed`
   - If live guild testing still shows gaps, add direct minimum delta sync plus richer `SYNC_HELLO` catch-up behavior.
   - Keep using authoritative entity mutations and locally rebuilt history rather than shipping `auditLog` wholesale.

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
- Request detail regression coverage now includes modal click-through protection, fixed-row detail alignment, tighter label/value spacing, Requested By placement, Updated By / Date Updated / Decision Note bottom placement, post-decision editor hiding, workflow-button alignment with Close, actor-name history rows, shared table scrollbar bounds, and the reserved scrollbar gutter.
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
- Appearance and crafted-quality regression coverage now also spans shared two-rank icon normalization plus slider drag-release behavior in `inventory_quality_spec`, `ui_table_spec`, `ui_exports_spec`, `ui_minimums_spec`, `ui_requests_spec`, and `ui_options_spec`.
- Auth regression coverage now also spans compact updater-hash policy encoding plus legacy blacklist-key normalization.
- Dashboard regression coverage now spans `dashboard_spec` for zero-shortage `Ready to Buy` counting plus `ui_dashboard_spec` for the four-card dashboard layout, `Recent Activity`, and `Quick Actions`.
- Exports regression coverage now also verifies the action-card presentation, icon slots, and `Generate` / `Open List` CTA labels in `ui_exports_spec`.
- Minimums regression coverage now also verifies staged-row grouping, row badges, and staged-summary or `Revert All` footer behavior in `ui_minimums_spec`.
- Sync regression coverage now also includes milestone chat feedback for hello, accepted sync, and ignored forged payloads.
- In-game unit-lane regression coverage now spans `in_game_unit_spec.lua` plus `store_spec.lua` for slash availability, persistence, chat output, the saved-variables shape of `testing.inGameUnit`, blacklist normalization, officer queue prioritization, and unresolved minimum repair-row ordering.
- Live-smoke regression coverage now also verifies deterministic behavior when ambient auth policy denies raider request submission and when stale request/minimum selector state existed before the smoke run.
- Live-smoke and options regression coverage now also verify the policy-string `Select All` affordance, the current modal-driven Minimums staging flow, and successful request creation after the gating check clears stale selector state.
- Maintainer tooling regression coverage now spans `item_catalog_maintainer_spec.lua` for the status adapter and deployment helper, and the repo now ships `Open-ItemCatalogMaintainer.ps1` as the small local maintainer-facing launcher over the catalog pipeline.

## Immediate Engineering Focus

When resuming, begin with the next roadmap item unless the user explicitly redirects:

1. Start with the shelved UI polish pass in [docs/ui-polish-suggestions.md](../../ui-polish-suggestions.md), but begin by building the art pack needed to make the Alliance mockup achievable.
2. Keep the dashboard `Ready to Buy` mismatch as a live-repro-only follow-up unless real current data proves it is a product bug.
3. If more sync work is still needed after live guild testing, extend catch-up and direct minimum delta sync without abandoning the current authority-first approach.

## Important Constraints

- Keep using the local WoW addon development guide as the source of truth for addon/runtime patterns.
- Keep documentation updated as each roadmap item lands.
- Keep controls reusable and scalable across the project.
- Continue to favor focused subsystem tests over growing broad monolithic UI assertions.
- Do not expose maintainer credentials or local catalog assets in git.
- TSM export intentionally uses TSM 4.14's supported item-ID import path rather than generating TSM's private serialized export blob.

## Suggested Next Prompt

> Continue work on the WoW guild bank addon from the implementation worktree.
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
> Branch: `codex/gbankmanager-v1`
>
> Read first:
> `README.md`
> `docs/testing.md`
> `docs/manual-test-checklist.md`
> `docs/superpowers/handoffs/latest-handoff.md`
>
> Then run:
> `git status -sb`
> `.\tools\lua\lua.exe .\tests\run_all.lua`
>
> Resume with the post-workflow roadmap:
> 1. Implement the shelved UI polish pass using `docs/ui-polish-suggestions.md`, starting with an addon-local art pack for Alliance/mockup fidelity
> 2. Live-verify the broadened `/gbm test unit` lane in retail
> 3. Only revisit the dashboard `Ready to Buy` mismatch if a live SavedVariables repro exists
> 4. Only broaden sync catch-up beyond the current request/history/auth slice if live guild testing still shows gaps
## 2026-05-18 Runtime follow-up

- SavedVariables now need to be treated as load-order sensitive on Retail/macOS as well as Windows; `GBankManager.toc` should keep `## LoadSavedVariablesFirst: 1` in place unless init is fully deferred behind `ADDON_LOADED`.
- Scanner follow-up is now focused on reliability rather than visuals:
  - auto-scan should tolerate guild-bank data arriving a beat after `GUILDBANKFRAME_OPENED`
  - scan start/finish status should be chat-visible again
  - per-tab waits need a timeout fallback so one missed event does not wedge future scans
  - snapshot ids should stay unique even for same-second scans
