# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Remote tracking: `origin/codex/gbankmanager-v1`
- Latest pushed branch commit: `28de907` (`feat: land item search and minimums workflow improvements`)
- Latest local-only committed work in this phase: `e3e97ea` (`feat: rework request and export workflows`)
- Current repo status at handoff time: uncommitted auth compaction, linked-scale and floating-shopping-list morning-review fixes, sync chat feedback, dashboard stocking-history, broadened in-game unit coverage, maintainer catalog status and deploy tooling, policy-string select-all, smoke-harness modal/gating refresh, two-rank crafted-icon normalization, slider drag-release polish, docs, and shell-focus slice on `codex/gbankmanager-v1`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: `PASS tests/run_all.lua`

## Read First

1. `README.md`
2. `docs/testing.md`
3. `docs/manual-test-checklist.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`
6. `.\tools\lua\lua.exe .\tests\run_all.lua`

## Current Repo State

- Worktree may contain the latest uncommitted item 2/3 correction slice until it is committed/deployed.
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
- The full-shell request surface is now `Request Admin`: workflow actions remain visible with more bottom spacing, inline request creation is hidden, shared table search is enabled, and the admin table exposes date requested, requestor, item ID, tier, item name, quantity, approval, fulfillment, and note.
- `/gbm request` now opens a separate end-user request workflow panel with own-request status rows and a `New Request` wizard entrypoint.
- Requests never auto-approve. Officers/admins cannot approve their own requests; the Guild Master can approve their own request only through an explicit workflow approval action.
- `/gbm request` now uses a smaller compact window with `Guild Bank Manager` in the header, an own-request table (`Item ID`, `Item Name`, `Quantity`, `Status`), row-click details, pending-request cancellation for authors, and a three-step item -> quantity/reason -> review wizard.
- `Request Admin` now uses the same request-list/details pattern, with workflow actions available from the details popup.
- Request details now label the Decision Note input, align detail/readback values to fixed modal columns, and keep the details modal open after status changes.
- Approving a request requires an approver-selected Bank Tab, stores the Decision Note and Bank Tab on the request, and immediately saves/updates an enabled tab-scoped Minimums rule for the requested quantity.
- Request details now block table click-through, keep fixed label/value rows with tighter label/value spacing, show Requested By above Date Requested, show Updated By, Date Updated, and Decision Note at the bottom of the detail list, hide the decision-note editor after approval or denial, and request audit history normalizes actor tables into character names.
- Request Admin no longer shows the old top workflow actions box. Actions live in the details modal, and the bottom filter strip switches between `All`, `Pending Approval`, and `Pending Fulfillment`.
- Approved open requests are now auto-marked `FULFILLED` by a guild-bank scan when scanned inventory for the requested item meets the requested quantity. Fulfillment records `fulfilledBy = Bank Scan` and Date Fulfilled.
- Request dates now display with an abbreviated timezone and no `(Local)` suffix.
- Shared table scrollbars now sit just outside the table viewport so the table frame ends before the bar and rightmost columns are not overlapped.
- Exports now uses the shared table plus a bottom action strip. The table shows `Item ID`, `Tier`, `Item Name`, `Bank Tab`, `Amount to Stock`, and `Excess Stock`.
- `Excess Stock` now shows either `None` or the alternate guild-bank tab with the highest quantity, and the stocked-elsewhere detail modal still lists every alternate tab and quantity.
- Exports now renders crafted-quality icons in the visible `Item Tier` column while keeping numeric tier values available for CSV-style outputs.
- Auctionator export now emits the modern shopping-list line format instead of the older quantity or quality overloaded string.
- Request deletion is now a distinct permission capability, and authorized users can delete requests from the request-details workflow popup.
- Request Admin now highlights the active bottom filter, right-aligns `All`, `Pending Approval`, and `Pending Fulfillment`, keeps a far-left `Add` launcher, and uses the shared table height without the `Date Fulfilled` filter overflowing.
- The guild auth policy string now carries the shared Restock Default plus updater metadata. Guild Info pull now refreshes those values into the local Options state, auth-policy updates now write History rows, and those auth-policy rows are now visible in the History view.
- Blacklist entry UI now explicitly asks for `Character-Server` input, and guild-shared blacklist membership now comes from appended `[GBMBL]` officer-note tags instead of the Guild Info policy string.
- Dashboard `Ready to Buy` mismatch investigation did not land a code fix in this slice. Obvious local machine paths did not reveal a live SavedVariables file, and the dashboard card count plus Exports row count both currently derive from the same demand-plan shape in code, so this should be reproed live before changing code.
- Opening the guild bank now auto-starts a scan only when at least 10 minutes have elapsed since the last successful scan. Manual scan button or slash behavior is unchanged.
- Synced request create and update messages now append local History rows on receiving clients, approved request sync recreates the tab-scoped Minimums side effect on receivers, and request conflict resolution now prefers higher-authority updaters before timestamp tie-breaks.
- CSV, Auctionator, and TSM export modals now remove the nested inner text box, and the output area now uses a dedicated scrollable edit-box surface so `Select All` and manual mouse selection both target a real copyable field. The old `Copy` button has been removed.
- Auctionator and TSM now use the choice label `Not In Guild Bank` for the missing-only path.
- Exports now includes a movable `Manual Shopping List` window with one-session checklist strike-through rows, plain checkbox marks, and an explicit `Does not sync back to addon.` note.
- Minimums rows with unresolved `GLOBAL` Bank Tab now sort to the top in orange, open into an editable Bank Tab picker, and `Save All` blocks with `Bank Tab must be set on Orange Rows.` until the row is corrected.
- Approved open requests that already carry a bank tab but are missing `minimumRuleKey` now self-heal on refresh by creating or rebinding the matching tab-scoped Minimums rule automatically. Only the truly tab-less legacy requests still surface as orange repair rows.
- Approved open requests that lost both `minimumRuleKey` and request-side bank-tab data now attempt one more self-heal: if there is exactly one enabled tab-scoped Minimums rule for that item, the request binds to that existing rule automatically instead of surfacing a duplicate orange orphan row.
- The auth policy string now compacts updater identity with a hash token instead of storing the full updater name in Guild Info, while still rehydrating a real updater name locally when the addon can infer it from live or previously known policy state.
- Compact auth-policy imports no longer carry blacklist membership. Guild-shared blacklist membership now comes from appended officer-note tags, while learned reasons stay local and continue to sync through addon auth snapshots.
- Blacklist entries now normalize to `Character-Server`, migrate legacy server-first ordering, automatically append or remove `[GBMBL]` when officers save changes, and preserve the rest of the officer note text whenever the tag fits within Blizzard's 31-character note limit.
- Crafted-quality rendering now normalizes the two-rank and max-rank atlas variants so Exports, Inventory, Minimums, Requests, and request details show the same visible tier symbols whether the source came from live scan data or fallback catalog/search data.
- The appearance foundation is now live: local-only theme presets (`Current`, `Contrast`, `Horde`, `Alliance`, `Void`, `Adventurer`, `Moonglade`), linked shell scale and table density behavior, separate shell and modal opacity sliders, collapsed-nav icons, and stronger active-state glow for nav plus workflow filter buttons.
- Appearance sliders now support direct slider interaction in addition to `+` / `-` stepping, and opening `Options` proactively reloads the current Guild Info auth policy before populating the visible auth controls.
- Two-rank crafted items now stay on the shared visible chat-icon family across Inventory, Minimums, Requests, Exports, and the manual shopping list, and appearance sliders now stop dragging cleanly even when the mouse is released off the bar.
- Sync now reports milestone chat feedback for login hello, accepted incoming updates, and ignored forged payloads without writing per-step noise into chat.
- The shell now participates in top-level window ordering so other dragged addon or Blizzard UI can come above it, and clicking back onto the shell or its registered modals brings `GBankManager` back to the front.
- The shell now defaults to a lower dialog stratum, keeps shared columns fitted inside the shell viewport, clamps shared table height so bottom action strips stay inside the window, hides zero-range scrollbars on Request Admin and Exports, applies modal opacity across Minimums and Exports workflow modals, keeps the top-bar scan plus status controls separated at smaller scales, and keeps the manual shopping list plus Auctionator export output aligned with the live product expectations.
- The floating manual shopping list now lives independently from the main shell, survives tab switches and shell close, remembers its moved position locally, and keeps low-tier crafted icons normalized even when the source row has no live stock snapshot.
- Dashboard `Top 5 Most Used` now ranks repeated shortage cycles from persisted snapshot history plus active Minimums rules before falling back to raw withdrawal totals when there is no stocking history yet.
- `/gbm test unit` now also covers blacklist normalization, officer request-queue prioritization, and unresolved minimum repair-row ordering, with persisted results under `GBankManagerDB.testing.inGameUnit`.
- `/gbm test smoke` now seeds deterministic request-access auth and clears stale request/minimum selector state before its gating checks, so live guild policy or leftover UI selections do not create false negatives. `/gbm test unit` also reloads the crafted-quality helper if the module registry lost it, matching the UI modules' existing fallback behavior.
- `Options -> Auth` now includes a `Select All` helper for the compact policy string, and the smoke lane now exercises the live Minimums modal handoff plus a hard reset of request confirmed-selection state before its gating assertions.
- Maintainers now have repo-local catalog status and deployment helpers plus `tools/catalog/Open-ItemCatalogMaintainer.ps1` for target selection, saved sync status, refresh, and deploying both addon folders into `Retail`, `PTR`, or `Beta`.

### Current Navigation

- `Dashboard`
- `Inventory`
- `History`
- `Minimums`
- `Request Admin`
- `Exports`
- `About`
- `Options`

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
   - Continue the refinement pass on top of the landed appearance foundation.
   - Expand icons carefully from collapsed-nav only into expanded nav and then selective action-strip buttons.
   - Do the less-blocky pass: lighter panel treatment, tighter gaps, slimmer grouped controls, and calmer corners.
   - Live-QA the new shell focus ordering against other draggable UI.
   - Use [docs/ui-polish-suggestions.md](../../ui-polish-suggestions.md) as the implementation shelf for tomorrow.

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
- The `/gbm request` wizard is complete enough for item search, quantity/reason, review, submit, own-request status rows, and details popup cancellation.
- Approved requests that create a Minimums rule carry `minimumRuleKey`, and planning skips those request rows as separate request demand to avoid double-counting.
- Request detail regression coverage now includes modal click-through protection, fixed-row detail alignment, tighter label/value spacing, Requested By placement, Updated By / Date Updated / Decision Note bottom placement, post-decision editor hiding, workflow-button alignment with Close, actor-name history rows, shared table scrollbar bounds, and the reserved scrollbar gutter.
- Local Lua runners now print `RUN`/`PASS` progress for each lane and spec so long-running tests no longer appear silent.
- Request scan-fulfillment regression coverage now spans `requests_spec` and `store_spec`.
- Exports regression coverage now spans `exports_spec` and `ui_exports_spec`, including highest-quantity excess-stock labeling, CSV output, Auctionator scoped output, TSM item-ID output, copy-guidance feedback, nested-box removal, and the manual shopping-list modal.
- Export modal regression coverage now also verifies that the output surface is a real scrollable edit box, that `Select All` focuses it, rewinds the cursor, and highlights the full output for manual `Ctrl+C`.
- Minimums regression coverage now includes unresolved `GLOBAL` row ordering, orange highlighting, editable Bank Tab recovery, save-time validation blocking, and approved-request self-heal when a bank tab already exists but the minimum binding is missing.
- Request deletion regression coverage now spans auth, auth-source, request-domain, sync, and request-UI specs.
- Request Admin regression coverage now also covers active-filter highlighting, far-left `Add`, right-aligned filters, and shared-height sizing.
- Minimums regression coverage now also covers the split `Enabled Only` and `Show All` filter buttons plus active-state highlighting.
- Auth policy regression coverage now spans auth-source, auth, options UI, sync, history, and officer-note blacklist specs for Restock Default propagation, Guild Info updater metadata, Guild Info blacklist removal, officer-note tag writes, blacklist input normalization, and visible auth-policy history rows.
- Scanner regression coverage now spans unit and sync specs for guild-bank-open auto-scan throttling plus the new `GUILDBANKFRAME_OPENED` event adapter.
- Sync-hardening regression coverage now spans request history parity on receiving clients, authority-first request conflict resolution, and approved-request minimum recreation on receiving clients.
- Appearance regression coverage now spans `ui_shell_spec`, `ui_options_spec`, and `live_smoke_spec` for theme presets, shell scale, table density, split shell-vs-modal opacity controls, active-state glow, collapsed-nav icons, and shell-top-level focus behavior.
- Appearance and crafted-quality regression coverage now also spans shared two-rank icon normalization plus slider drag-release behavior in `inventory_quality_spec`, `ui_table_spec`, `ui_exports_spec`, `ui_minimums_spec`, `ui_requests_spec`, and `ui_options_spec`.
- Auth regression coverage now also spans compact updater-hash policy encoding plus legacy blacklist-key normalization.
- Dashboard regression coverage now spans `dashboard_spec` for zero-shortage `Ready to Buy` counting and shortage-cycle ranking in `Top 5 Most Used`.
- Sync regression coverage now also includes milestone chat feedback for hello, accepted sync, and ignored forged payloads.
- In-game unit-lane regression coverage now spans `in_game_unit_spec.lua` plus `store_spec.lua` for slash availability, persistence, chat output, the saved-variables shape of `testing.inGameUnit`, blacklist normalization, officer queue prioritization, and unresolved minimum repair-row ordering.
- Live-smoke regression coverage now also verifies deterministic behavior when ambient auth policy denies raider request submission and when stale request/minimum selector state existed before the smoke run.
- Live-smoke and options regression coverage now also verify the policy-string `Select All` affordance, the current modal-driven Minimums staging flow, and successful request creation after the gating check clears stale selector state.
- Maintainer tooling regression coverage now spans `item_catalog_maintainer_spec.lua` for the status adapter and deployment helper, and the repo now ships `Open-ItemCatalogMaintainer.ps1` as the small local maintainer-facing launcher over the catalog pipeline.

## Immediate Engineering Focus

When resuming, begin with the next roadmap item unless the user explicitly redirects:

1. Start with the shelved UI polish pass in [docs/ui-polish-suggestions.md](../../ui-polish-suggestions.md), but keep it as a deliberate implementation pass rather than ad hoc visual edits.
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
> 1. Implement the shelved UI polish pass using `docs/ui-polish-suggestions.md`
> 2. Live-verify the broadened `/gbm test unit` lane in retail
> 3. Only revisit the dashboard `Ready to Buy` mismatch if a live SavedVariables repro exists
> 4. Only broaden sync catch-up beyond the current request/history/auth slice if live guild testing still shows gaps
