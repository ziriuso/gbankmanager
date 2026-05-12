# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current HEAD before this checkpoint: `bfbd837` `feat: refine guild bank ui and refresh handoff`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`

## Current State

- Addon loads in game
- `/gbm ui` opens the shell
- `Scan Bank` reports progress and completes
- Latest scan snapshot and last-scan metadata now persist across reloads
- Inventory has:
  - column resizing
  - inline column filters
  - a quality column
  - clipped text instead of column bleed
  - improved viewport/scrollbar alignment
- Dashboard has an added export-readiness / total-buy card
- `History` is re-enabled, but now points at procurement audit data rather than bank diff data
- `Requests` now renders a real officer queue table instead of a placeholder screen
- Local Lua suite passes

## What Landed Since `bfbd837`

### Inventory and scan persistence

- Added a six-column inventory table with:
  - quality marker column
  - name
  - quantity
  - tab
  - restock
  - minimum
- Added inline per-column filtering in the Inventory screen
- Reworked table viewport sizing so the body aligns with the header and no longer overhangs the inner frame
- Improved scrollbar structure and row framing in the shared shell
- Added quality capture to scan snapshots and scanner item reads
- Preserved latest snapshot, `currentSnapshotId`, and last-scan metadata through SavedVariables normalization and reloads

### History redesign

- Re-enabled the `History` tab in sidebar navigation
- Replaced old bank-diff-oriented history rows with audit-style rows shaped around:
  - request events
  - minimum changes
  - actor
  - old value
  - new value
  - timestamp

### Requests system progress

- Expanded request lifecycle support in `Domain/Requests.lua`:
  - approve
  - reject
  - fulfill
  - reopen
- Added stored mutation helpers that update DB state and append audit log rows:
  - `CreateAndStore`
  - `ApproveStored`
  - `RejectStored`
  - `MarkFulfilledStored`
  - `ReopenStored`
- Added request audit entry builders for History consumption
- Added `RequestsView.BuildOfficerQueue`
- Added `RequestsView.BuildTableRows`
- Wired the Requests tab to render officer queue rows through the shared shell

### Minimum audit groundwork

- Added `auditLog` to DB defaults and migrations
- Added `MinimumsView.UpsertWithAudit`
- Minimum upserts can now emit `MINIMUM_CREATED` / `MINIMUM_UPDATED` style audit rows into persisted state

## Files Touched In This Checkpoint

- `GBankManager/Data/Defaults.lua`
- `GBankManager/Data/Migrations.lua`
- `GBankManager/Domain/Requests.lua`
- `GBankManager/Domain/Snapshots.lua`
- `GBankManager/Features/GuildBankScanner.lua`
- `GBankManager/UI/DashboardView.lua`
- `GBankManager/UI/HistoryView.lua`
- `GBankManager/UI/InventoryView.lua`
- `GBankManager/UI/MainFrame.lua`
- `GBankManager/UI/MinimumsView.lua`
- `GBankManager/UI/RequestsView.lua`
- `tests/spec/requests_spec.lua`
- `tests/spec/store_spec.lua`
- `tests/spec/ui_spec.lua`
- `docs/manual-test-checklist.md`

## Important Constraints

- Keep the new History direction:
  - request history
  - minimum-setting changes
  - who changed a minimum
  - old vs new minimum values
  - when the change happened
- Do **not** revive the old visible history model based on guild-bank item add/remove diff rows
- Preserve the steel/slate shell and left-aligned text style
- Continue using TDD with the Lua runner before claiming completion

## Verified State

- Verified on `2026-05-12` with:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
PASS tests/run_all.lua
```

## Recommended Next Offline Step

Wire the live UI controls into the new stored request/minimum mutation helpers so the addon stops relying on passive helpers and starts producing real persisted workflow history from actual officer actions.

Suggested order:

1. Add request action handlers in the Requests UI path for:
   - approve
   - reject
   - fulfill
   - reopen
2. Route those actions through the new stored helpers in `Domain/Requests.lua`
3. Add minimum edit/create flows that call `MinimumsView.UpsertWithAudit`
4. Refresh Requests and History views after each mutation
5. Add tests proving the shared DB is updated and the visible tables refresh from persisted state

## Next Offline Prompt

Use this prompt for the next session:

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
> Resume from the current clean head on branch `codex/gbankmanager-v1`.  
>  
> Priority for this offline session:  
> 1. Wire live Requests UI actions to persisted stored mutations for approve/reject/fulfill/reopen.  
> 2. Wire minimum create/edit flows to `UpsertWithAudit` so History fills from real saved changes.  
> 3. Make Requests and History refresh immediately after mutations.  
> 4. Keep using TDD and verify with `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.  
>  
> Keep the History tab focused on procurement workflow audit events, not bank diff history.

## Notes

- WoW was down for maintenance during this checkpoint, so no new in-game/manual verification was performed after these changes
- The best next work remains offline-safe request/minimum mutation wiring and additional Lua coverage
