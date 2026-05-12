# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current HEAD before this checkpoint: `d5899a7` `feat: complete task 8 scan and export integration`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`

## Current State

- Task 1: complete
- Task 2: complete
- Task 3: complete
- Task 4: complete at the domain layer
- Task 5: complete as the base officer UI shell
- Task 6: partially elevated beyond the original shell plan with working navigation and early management views
- Task 7: sync foundation exists
- Task 8: scan/export integration exists and the addon is loading in game
- Local Lua suite passes

## What Landed Since The Prior Handoff

- Runtime compatibility:
  - Updated `GBankManager.toc` to a current retail interface value
  - Added `## Category: Guild` so the addon appears under the Guild grouping in the in-game addon list
  - Added `tests/spec/toc_spec.lua` to keep TOC metadata from regressing

- Task 6 and UI shell follow-up:
  - Added `UI/MinimumsView.lua`, `UI/TargetsView.lua`, `UI/RequestsView.lua`, and `UI/RequestDialog.lua`
  - Extended the shell navigation with `Minimums`, `Targets`, `Requests`, and `Options`
  - Added a draggable shell, close button, sidebar collapse control, and transparency controls under `Options`
  - Fixed multiple runtime shell issues:
    - invisible startup mouse blocker
    - slash command stale frame reference
    - removed API usage for resize handling
    - missing font inheritance on font strings
    - collapsed sidebar label stacking
  - Left-aligned view text while keeping button labels centered

- Task 7:
  - Added `Sync/Codec.lua`, `Sync/Coordinator.lua`, and `Sync/Transport.lua`
  - Wired login/addon-message event handling in `Core/Events.lua`
  - Added authority-first conflict resolution coverage in `tests/spec/sync_spec.lua`

- Task 8 and scan progress:
  - `Scan Bank` now starts a real scan loop instead of only changing a label
  - Scanner now tracks:
    - total tabs
    - completed tabs
    - waiting tab
    - live status text
  - Top-bar status now surfaces scan progress and completion
  - Completed scans now update saved snapshot metadata in the DB

- Current UI rendering:
  - Dashboard now shows early card-style content
  - Inventory now uses an early structured table layout with columns for:
    - Name
    - Quantity
    - Tab
    - Restock
    - Minimum
  - History rendering helpers still exist in code, but the `History` tab has now been hidden from sidebar navigation pending a redesign

## Important Commits

- `d5899a7` `feat: complete task 8 scan and export integration`
- `a3a17db` `feat: add task 6 management ui and task 7 sync foundation`
- `7fcca18` `feat: add officer dashboard ui shell`
- `3ec8a6b` `feat: complete task 4 planning and request workflows`
- `69bf502` `feat: add planning engine and export builders`

## Local Runner

- Local LuaJIT runner is available at `tools/lua/lua.exe`
- Verified command result at stop point:

```text
PASS tests/run_all.lua
```

## Current UX Summary

- Addon loads in game without the earlier interface/runtime errors
- `/gbm ui` opens the main frame
- `Scan Bank` reports progress and can complete a live scan
- Dashboard scan timestamp is now being formatted rather than shown raw
- Inventory and Dashboard are moving toward structured layouts
- Column overlap is improved via explicit column widths, but true user-driven column resizing is not implemented yet

## Direction Change

### History Tab

Do **not** continue the old `History` direction of showing guild-bank item adds/removes as a visible officer tab.

New direction:

- Re-enable `History` later only after redesigning it around:
  - request history
  - changes to restock settings
  - who changed a minimum
  - what the previous and new minimum values were
  - when the setting/request change occurred

In other words:

- Move away from "bank diff audit log"
- Move toward "procurement workflow and policy audit log"

The current hidden/disabled `History` tab behavior should be treated as intentional until that redesign starts.

## Recommended Next Step

Continue the UI refinement pass rather than expanding system scope.

Suggested order:

1. Finish Inventory table polish:
   - prevent remaining text overflow
   - add real visible row framing if useful
   - add true scroll behavior if needed
   - add user-resizable columns if desired
2. Continue Dashboard polish:
   - improve card spacing and hierarchy
   - make last scan metadata friendlier
   - refine top-5-used logic if withdrawal semantics need tightening
3. Keep `History` hidden
4. If a new audit/history design starts, treat it as a requirements reset around requests/restock changes rather than reviving the current bank-diff UI

## Notes

- Main repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for` is intentionally left on `master` with docs commits only
- Active implementation work remains isolated in this worktree branch
- There are working-tree changes beyond `d5899a7` at this stop point; commit them together with this handoff refresh
