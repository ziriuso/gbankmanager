# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current HEAD: `7fcca18` `feat: add officer dashboard ui shell`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`

## Current State

- Task 1: complete, reviewed, approved
- Task 2: complete, reviewed, approved
- Task 3: complete, reviewed, and fixed for runtime TOC integration
- Task 4: complete at the domain layer
- Task 5: complete as the officer UI shell
- Worktree status is clean
- Local Lua suite passes

## What Landed Since The Last Handoff

- Task 3 follow-up:
  - Fixed a real runtime gap where scan/diff modules were not loaded by `GBankManager.toc`
  - Tightened the tests so TOC loading is validated instead of manually loading Task 3 files in specs

- Task 4:
  - Added planning, requests, and exports domain modules
  - Expanded request lifecycle helpers for approval and suggested fulfillment/reopen flow
  - Added scoped planning details and export row materialization
  - Strengthened tests for planning, requests, and exports

- Task 5:
  - Added `UI/MainFrame.lua` modern shell with:
    - collapsible sidebar
    - top status bar
    - balanced-density layout
    - steel/slate default theme tokens
  - Added `DashboardView.lua`, `InventoryView.lua`, `HistoryView.lua`, `ExportsView.lua`, and `ExportDialog.lua`
  - Wired `/gbm ui`
  - Added `docs/manual-test-checklist.md`
  - Added UI test coverage in `tests/spec/ui_spec.lua`

## Important Commits

- `7fcca18` `feat: add officer dashboard ui shell`
- `acb9725` `docs: add task 5 ui shell design`
- `3ec8a6b` `feat: complete task 4 planning and request workflows`
- `69bf502` `feat: add planning engine and export builders`
- `43cc232` `feat: add snapshot scan and history diff foundation`
- `8feb0f6` `fix: harden task 2 migrations and spec harness`
- `ae019e0` `fix: wire task 2 persistence at runtime`

## Local Runner

- Local LuaJIT runner is available at `tools/lua/lua.exe`
- Verified command result at stop point:

```text
PASS tests/run_all.lua
```

## Recommended Next Step

Resume with Task 6 from the implementation plan.

Suggested order:

1. Re-read the Task 5 UI shell addendum to preserve the visual/system choices
2. Implement `UI/MinimumsView.lua` and `UI/TargetsView.lua`
3. Implement `UI/RequestsView.lua` and `UI/RequestDialog.lua`
4. Extend `UI/MainFrame.lua` navigation to include:
   - Minimums
   - Targets
   - Requests
5. Update `GBankManager.toc`
6. Extend `docs/manual-test-checklist.md`
7. Add or extend tests before each behavior slice where possible
8. Run `.\tools\lua\lua.exe .\tests\run_all.lua`

## Task 6 Design Intent

- Reuse the Task 5 shell instead of introducing a second UI style
- Keep the same steel/slate theme tokens and balanced density
- Minimums and Targets should feel like management workspaces, not plain forms
- Requests should preserve the officer-first workflow while keeping member filtering logic isolated
- Do not expand into sync behavior yet; keep Task 6 focused on UI and request-management interactions

## Notes

- Main repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for` is intentionally left on `master` with docs commits only
- Active implementation work is isolated in the worktree branch above
- `.superpowers/` is now gitignored because the visual companion created local scratch files during design exploration
