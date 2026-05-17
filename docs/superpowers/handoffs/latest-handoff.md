# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Remote tracking: `origin/codex/gbankmanager-v1`
- Latest pushed branch commit: `28de907` (`feat: land item search and minimums workflow improvements`)
- Latest local-only committed work in this phase: `e3e97ea` (`feat: rework request and export workflows`)
- Current repo status at handoff time: uncommitted export polish and minimums validation slice on `codex/gbankmanager-v1` unless this handoff is committed after deployment
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: `PASS tests/run_all.lua` after adding per-lane and per-spec test-runner progress output

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
- Minimums uses the shared header/filter row instead of the old bottom search box, and its footer is now a compact transparent action strip with `Add`, `Save All`, and `Enabled Only` controls.
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
- Exports now uses the shared table plus a bottom action strip. The table shows `Item ID`, `Item Tier`, `Item Name`, `Bank Tab`, `Amount to Stock`, and `Excess Stock In`.
- `Excess Stock In` now shows the alternate guild-bank tab with the highest quantity, and the stocked-elsewhere detail modal still lists every alternate tab and quantity.
- CSV, Auctionator, and TSM export modals now remove the nested inner text box, and the output area now uses a dedicated scrollable edit-box surface so `Select All` and manual mouse selection both target a real copyable field. The old `Copy` button has been removed.
- Auctionator and TSM now use the choice label `Not In Guild Bank` for the missing-only path.
- Exports now includes a movable `Manual Shopping List` window with one-session checklist strike-through rows, plain checkbox marks, and an explicit `Does not sync back to addon.` note.
- Minimums rows with unresolved `GLOBAL` Bank Tab now sort to the top in orange, open into an editable Bank Tab picker, and `Save All` blocks with `Bank Tab must be set on Orange Rows.` until the row is corrected.
- Approved open requests that already carry a bank tab but are missing `minimumRuleKey` now self-heal on refresh by creating or rebinding the matching tab-scoped Minimums rule automatically. Only the truly tab-less legacy requests still surface as orange repair rows.
- Approved open requests that lost both `minimumRuleKey` and request-side bank-tab data now attempt one more self-heal: if there is exactly one enabled tab-scoped Minimums rule for that item, the request binds to that existing rule automatically instead of surfacing a duplicate orange orphan row.

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

1. `Requests follow-up`
   - Add a new permission that allows request deletion.
   - Add a `Delete` workflow action in the request details popup.

2. `Exports follow-up`
   - Inspect the Auctionator addon import path and verify the shopping-list string format is still correct for quantity and quality, not accidentally feeding min/max price slots.
   - Rename the table column/value behavior to `Excess Stock`, with row output showing either `None` or the tab name with the highest excess quantity.
   - Tighten the shared Exports column spacing so Bank Tab text does not overflow.
   - Fix Exports tier rendering so it shows the crafted-quality icon instead of raw `0`.

3. `Request Admin follow-up`
   - Highlight the active bottom filter button so the selected state is obvious.
   - Right-align the bottom filter options in Request Admin.
   - Add an `Add` button on the far left of the bottom action strip to launch the add-request workflow from Request Admin.
   - Match the Request Admin table height to the shared table height used by the other major tabs.
   - Fix the `Date Fulfilled` filter box so it no longer overflows off the right edge.

4. `Minimums follow-up`
   - Split the `Enabled Only` / `All` toggle into two separate buttons.
   - Highlight the active Minimums filter button.

5. `Guild auth string follow-up`
   - Add the Restock Default setting to the guild permission string stored in Guild Info.
   - On addon load, preload the Options permission UI from the current Guild Info auth string so the panel reflects live stored policy data immediately.
   - Update the blacklist text box guidance so it explicitly requires `Character-Server` formatting.
   - Encode the last-updated person into the Guild Info policy string so the loaded policy metadata identifies the correct updater.
   - Track permission-policy updates in History if that audit trail is not already present.
   - Sync permission-policy update history cleanly between addon-enabled guild clients.

6. `Dashboard investigation`
   - Investigate why the dashboard `Ready to Buy` card reports 5 export rows while Exports currently shows 4.
   - Inspect live addon/saved data first.
   - If this is only stale local test data, clear or reset the local saved variables and do not implement a code change.
   - Add a dedicated dashboard card for critical shortages when the dashboard slice is revisited, with clear ranking/selection rules so the card surfaces the most urgent shortages rather than a generic duplicate count.

7. `Guild bank scan automation`
   - Trigger a scan automatically when the guild bank opens.
   - On subsequent opens, auto-scan only if at least 10 minutes have elapsed since the last scan.
   - Keep manual scan support unchanged.

8. `Communication and sync hardening`
   - Review how the Guild Roster Manager addon handles addon-to-addon communication, conflict resolution, and authoritative winners.
   - Use that research to strengthen GBankManager sync behavior for history, requests, and minimums.
   - Include permission-policy history sync and authority rules in that same research-backed communication pass.
   - Treat this as a product workflow slice, not just a transport-only change.

9. `UI polish`
   - Theme customization
   - Resize / scale
   - Spacing and gap cleanup
   - Highlight the active nav button so the selected tab is obvious.
   - Review the two-tier crafted-quality icon mapping and match the in-game convention where the lower tier uses the single silver diamond and the max tier uses the gold pentagon everywhere quality is shown.
   - Revisit Window Transparency as slider-based controls instead of a simple toggle/input flow.
   - Research how addons such as Deadly Boss Mods and Horizon Suite implement opacity sliders before building the control.
   - Support separate opacity settings for the main shell and for modal popup windows so they can be tuned independently.

10. `In-game unit test lane`
   - Build out unit tests that can be run in-game through the unit test addon.

11. `Maintainer deployment and sync UI`
   - Fully document the maintainer deployment and usage workflow.
   - Build a small maintainer-facing UI for the catalog/deployment pipeline.
   - It should allow choosing the WoW target path for `Retail`, `PTR`, or `Beta`.
   - It should show current status, last sync time, and the WoW patch/build the catalog was synced from.

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

## Immediate Engineering Focus

When resuming, begin with the next roadmap item unless the user explicitly redirects:

1. Start with the request and export follow-up block before broader UI polish.
2. Investigate the dashboard export-row mismatch against live saved data before writing a code fix.
3. Fold Guild Roster Manager communication research into the sync-hardening phase rather than treating sync as a blind transport-only task.
4. Keep the admin `Request Admin` surface focused on officer/guildmaster management.

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
> Resume with the new pre-polish roadmap block:
> 1. Requests delete permission plus popup delete action
> 2. Exports Auctionator format verification plus Exports column/icon follow-ups
> 3. Request Admin active-filter highlight
> 4. Minimums split filter buttons plus active highlight
> 5. Restock Default in guild permission string plus Options-page preload from Guild Info
>    and policy metadata/history sync follow-ups
> 6. Dashboard `Ready to Buy` mismatch investigation
> 7. Guild-bank-open auto-scan with 10-minute throttle
> 8. Communication and sync hardening informed by Guild Roster Manager research
>
> After that block, continue with broader UI polish, the in-game unit-test lane, and finally the maintainer deployment/status UI.
