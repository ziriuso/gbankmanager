# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result in this handoff: `PASS tests/run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`

## Current State

- `/gbm ui` shell is active and procurement-focused
- `History` stays focused on workflow audit events, not bank diff history
- `Inventory` is now in a strong place:
  - columns are ordered `Tier`, `Name`, `Tab`, `Restock`, `Qty`, `Min`
  - `Tier`, `Name`, `Tab`, `Restock`, `Qty`, and `Min` all support header click sorting
  - `Name`, `Tab`, and `Restock` keep text filtering while also supporting sort
  - active sort headers use ASCII markers `^` and `v`
  - crafted quality icons are larger
  - quality sorting now tries to parse more than one atlas naming pattern and pushes unranked rows after ranked tiers
  - inventory rendering rebinds to the saved variables DB before drawing
- `Requests` has persisted approve/reject/fulfill/reopen flows plus create flow
- `Minimums` has:
  - persisted enabled/disabled state
  - merged bank + saved/manual rows
  - enabled-only default
  - `Show All`
  - search
  - manual-only filter
  - row selection
  - draft cue for bank-only rows
- `Targets` now has a real editor flow with saved create/update and open/closed status changes
- `Exports` now uses planning output instead of placeholder text
- Custom export output is adjustable from the shell by delimiter, field list, and header on/off
- Local Lua suite passes

## What Landed In This Session Range

### Inventory polish and persistence hardening

- Inventory header layout was cleaned up and the shared table now supports cleaner header interactions
- Inventory now supports sort markers in the header and per-column sort toggles
- Text filtering remains on `Name`, `Tab`, and `Restock`
- Crafted-quality sorting now prefers parsed atlas tier names before falling back to raw numeric quality
- The tier parser now recognizes more than one atlas naming pattern, including older or expansion-specific strings that still embed `Tier1` to `Tier5`
- Unknown or noisy crafted quality values are pushed after ranked tiers instead of breaking the `1..5` ordering
- Inventory rendering and scanner writes both now rebind to the active saved variables DB before use to reduce detached-state persistence bugs
- Local Lua coverage was extended around:
  - saved-variable rebinding
  - inventory column order
  - header sort markers
  - tier parsing from multiple atlas-name variants

### Requests and audit wiring

- Requests actions now route through persisted stored mutations
- Request creation also uses stored state and fills History immediately
- Requests and History refresh after workflow mutations

### Minimums workflow completion

- Minimum rules persist explicit `enabled` state instead of being removed on disable
- Disabled minimums no longer contribute to planning or inventory restock signaling
- Minimums table merges:
  - latest bank snapshot rows
  - saved rules
  - manual-only rules
- Enabled rows sort first
- In `Show All`, configured rows now stay ahead of raw bank-only rows
- Minimums defaults to enabled-only view, with:
  - `Show All`
  - search
  - manual-only toggle
- Selected rows are visually tracked in the shared table
- Empty states now explain why the table is blank
- Clicking a bank-only row loads a draft into the editor so it can be turned into a real saved rule

### Exports made real

- `Domain/Exports.lua` now materializes planning rows from the active demand model
- Zero-demand rows are omitted from exports
- Export rows now include:
  - `itemID`
  - `itemName`
  - `currentQuantity`
  - `restockQuantity`
  - `targetQuantity`
  - `requestQuantity`
  - `totalToBuy`
  - `scopeSummary`
  - `reason`
- Exports tab now supports:
  - `Spreadsheet`
  - `Auctionator`
  - `Custom`
- Custom export controls now allow:
  - delimiter change
  - field selection/order
  - header on/off

### Targets brought into the procurement flow

- `TargetsView.lua` now includes saved helpers for:
  - upsert with audit
  - status change with audit
- Targets table rows now show:
  - current bank quantity
  - status
  - target quantity
  - scope
- Open targets can surface `Suggested` when current bank quantity already meets the target
- Targets tab now supports:
  - row selection
  - save/update
  - close
  - reopen
  - create new target
- Target audit events now appear in History

## Files Touched In The Current Working State

- `GBankManager/Domain/Exports.lua`
- `GBankManager/Domain/Planning.lua`
- `GBankManager/UI/ExportDialog.lua`
- `GBankManager/UI/ExportsView.lua`
- `GBankManager/UI/HistoryView.lua`
- `GBankManager/UI/InventoryView.lua`
- `GBankManager/UI/MainFrame.lua`
- `GBankManager/UI/MinimumsView.lua`
- `GBankManager/UI/RequestsView.lua`
- `GBankManager/UI/TargetsView.lua`
- `GBankManager/Features/GuildBankScanner.lua`
- `tests/helpers/wow_stubs.lua`
- `tests/spec/diff_spec.lua`
- `tests/spec/exports_spec.lua`
- `tests/spec/planning_spec.lua`
- `tests/spec/store_spec.lua`
- `tests/spec/ui_spec.lua`

## Important Constraints

- Keep `History` focused on procurement workflow audit events
- Do **not** restore visible bank diff history into the History tab
- Minimum disable should remain a persisted disabled state, not deletion
- Exports should remain outputs of the planning model, not a separate source of truth
- Inventory is considered in good shape overall, but real in-game tier sorting is still not fully fixed
- Known unresolved inventory tier-sorting follow-up:
  - `Algari Mana Oil` is still appearing in the wrong tier grouping in the live client
  - `Potion Bomb of Speed` is still not reliably sorting as rank 1 in the live client
  - this likely means there are still crafted-quality atlas/icon variants in-game that the current offline parser does not yet recognize
  - use the user-provided screenshots as reference when coming back to this after the minimums pass
- Continue using TDD and rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion
- No in-game validation was available in this session range

## Verified State

- Verified on `2026-05-12` with:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```

## Latest Follow-Up 2026-05-12

This section supersedes the older "Recommended Next Offline Step" block above.

### Current Resume Point

- Branch: `codex/gbankmanager-v1`
- Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Latest verified command:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```

### What Landed In The Latest Pass

- Minimums edits now stage as pending changes instead of writing immediately
- `Show All` rows can now be edited directly from the table instead of forcing the older top-editor path
- The current footer flow is moving in the right direction, but it still needs another live-client UI cleanup pass

### Next Priority

Use the live-client screenshots as the primary reference and do this next:

1. Fix Minimums column spacing and header overflow
2. Rename `Restock From` to `Restock Source`
3. Allow the `Restock Source` header to wrap to two lines if that helps spacing
4. Remove the appended add-minimum-row UI at the bottom
5. Replace it with footer buttons:
   - `Add`
   - `Save`
   - `Undo`
6. `Add` should open a modal with a clean search UI:
   - `Item ID`
   - `Item Name`
   - item quality search fields
   - user searches for item
   - user clicks add
   - modal closes
   - new row is inserted into the table
   - new row is highlighted so the user can fill in `Minimum`, `Restock`, and `Bank Tab`
7. `Undo` should restore the original Minimums state from when the view was opened
8. `Save` should commit all pending changes and update saved variables plus History correctly
9. History timestamps should be stored in UTC and localized only for in-game display
10. The stored last-scan value should also be UTC-at-rest and localized only for display
11. Change the Minimums subtitle to:
   - `Manage Guild Bank Item Minimum Stock Levels`
12. After the Minimums footer/modal polish, return to the inventory quality issue in the live client

### Important Carry-Forward Notes

- Keep `History` focused on procurement workflow audit events only
- Do not restore visible bank diff history into the History tab
- Inventory tier sorting is still not fully correct in the live client
- Continue to use the user screenshots as reference for:
  - `Algari Mana Oil`
  - `Potion Bomb of Speed`
- Best remaining risk is still real in-game behavior, not the offline Lua suite

### Next Offline Prompt

> Continue work on the WoW guild bank addon from the implementation worktree.  
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`  
>  
> Read first:  
> `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`  
> `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`  
> `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`  
> `docs/superpowers/handoffs/latest-handoff.md`  
>  
> Then run:  
> `git status -sb`  
> `.\tools\lua\lua.exe .\tests\run_all.lua`  
>  
> Resume from branch `codex/gbankmanager-v1`.  
>  
> Priority for this offline session:  
> 1. Fix Minimums column spacing and header overflow in the live client.  
> 2. Change `Restock From` to `Restock Source`, and let it wrap to two lines if that helps spacing.  
> 3. Remove the appended add-minimum-row view from the bottom.  
> 4. Replace it with footer buttons: `Add`, `Save`, `Undo`.  
> 5. `Add` should open a modal with `Item ID`, `Item Name`, and item-quality search fields. Searching and adding should close the modal and add a new highlighted row into the table so the user can fill `Minimum`, `Restock`, and `Bank Tab`.  
> 6. `Undo` should restore the original state from when the Minimums view was opened.  
> 7. `Save` should commit all pending changes and update both the database and History correctly.  
> 8. Store History timestamps in UTC and localize only for display in game.  
> 9. Store the last-scan value in UTC and localize only for display in game.  
> 10. Change the Minimums subtitle to `Manage Guild Bank Item Minimum Stock Levels`.  
> 11. After that, return to the inventory quality issue in the live client.  
> 12. Keep `History` focused on procurement workflow audit events only.  
> 13. Keep using TDD and verify with `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.

## Recommended Next Offline Step

Move from `Inventory` to a substantial `Minimums` redesign pass.

Suggested order:

1. Add crafting tier as the second column after item ID
2. Replace the `Source` column with:
   - `Bank Tab`
   - a new `Restock From` column
3. Shift minimum logic from global-first to tab-aware behavior:
   - minimums should be based on the configured bank tab
   - if an item is under minimum in that tab but exists in a different tab, show `Restock From: <Tab Name>`
   - if no stock exists in other tabs, show `Restock From: Auction`
4. Bring the same sortable-header behavior from inventory into minimums
5. Remove text filters for `Current` and `Minimum`, but keep other useful text filters
6. Replace the top editor with inline table editing:
   - `Restock` becomes an inline `Yes` / `No`
   - `Minimum` becomes inline numeric editing
   - a `Save` button should appear on the far right for the edited row
7. Add a configurable default minimum value in `Options`
   - default value should be `100`
8. Replace the old top editor with a new-row flow at the bottom of the table:
   - adding by item ID should resolve and fill item name + quality
   - adding by item name should offer a quality-aware selection list when multiple variants exist
   - selecting an item should fill item ID and item name
   - `Bank Tab` and `Minimum` are required for new rows
9. Keep using TDD and extend offline coverage around:
   - minimum row shaping
   - tab-aware restock source calculation
   - sortable minimum columns
   - inline-edit persistence
   - add-row item resolution behavior
10. After the minimums pass, come back to the unresolved live-client inventory tier sorting bug for items like `Algari Mana Oil` and `Potion Bomb of Speed`

## Next Offline Prompt

> Continue work on the WoW guild bank addon from the implementation worktree.  
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`  
>  
> Read first:  
> `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`  
> `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`  
> `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`  
> `docs/superpowers/handoffs/latest-handoff.md`  
>  
> Then run:  
> `git status -sb`  
> `.\tools\lua\lua.exe .\tests\run_all.lua`  
>  
> Resume from branch `codex/gbankmanager-v1`.  
>  
> Priority for this offline session:  
> Inventory is in a good place. Move next to `Minimums` and implement this redesign:
> 1. Add crafting tier to the view as the 2nd column after `Item ID`.
> 2. Remove `Source` and replace it with `Bank Tab`.
> 3. Add a new `Restock From` column:
>    - minimums should be based on the configured bank tab, not global
>    - if under minimum and stock exists in another bank tab, show `Restock From: <Tab Name>`
>    - if no stock exists in another tab, show `Restock From: Auction`
> 4. Bring over the same sortable column-header behavior from `Inventory`.
> 5. Remove filter text search from `Current` and `Minimum`.
> 6. Replace the top editor with inline editing in the table:
>    - `Restock` is inline `Yes` / `No`
>    - `Minimum` is inline numeric editing
>    - when editing a row, show a `Save` button on the far right of that row
> 7. Add an `Options` setting for the default minimum value. Default it to `100`.
> 8. Replace the old top editor area with a new-row flow at the bottom:
>    - entering item ID should resolve and fill item name + quality
>    - entering item name should offer a dropdown/selection when multiple quality variants exist
>    - selecting a variant should fill item ID and item name
>    - `Bank Tab` and `Minimum` are required when adding a new item
> 9. Keep `History` focused on procurement workflow audit events only.
> 10. Leave a carry-forward note that inventory tier sorting still needs another live-client fix pass for items such as `Algari Mana Oil` and `Potion Bomb of Speed`; use the user’s screenshots as reference.
> 11. Keep using TDD and verify with `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.

## Notes

- The worktree is currently dirty with in-progress, uncommitted addon changes
- The addon has strong offline coverage now for Inventory, Requests, Minimums, Targets, Planning, and Exports
- Best remaining risk is real in-game behavior, especially item-specific crafted-quality atlas variants and UI behavior inside WoW itself
- Inventory tier sorting should be revisited after the minimums pass with the user screenshots as reference, because the live client still disagrees with the current offline parser for at least `Algari Mana Oil` and `Potion Bomb of Speed`

## Update 2026-05-12

- The offline `Minimums` redesign is now implemented and covered in the Lua suite
- The redesigned minimums workflow now includes:
  - tier as the second column after item ID
  - `Bank Tab` replacing `Source`
  - tab-aware `Restock From` values that prefer another guild-bank tab before `Auction`
  - inventory-style sortable headers in the minimums table
  - no text filters for `Current` or `Minimum`
  - inline row editing for `Restock` and `Minimum` with a row-level `Save`
  - a default minimum quantity setting in `Options`
  - a bottom add-row flow that resolves item IDs, offers quality-aware name matches, and saves new rows directly instead of staging them behind `Save All`
- Carry-forward note:
  - inventory tier sorting still needs another live-client fix pass for `Algari Mana Oil` and `Potion Bomb of Speed`
  - use the user screenshots as reference when revisiting crafted-quality atlas/icon handling in the live client
- Verified again with:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```
