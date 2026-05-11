# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/handoffs/latest-handoff.md`
4. `git status -sb`

## Current State

- Task 1: complete, reviewed, approved
- Task 2: complete, reviewed, approved
- Task 3: implementation committed, but stop point reached before review loop finished
- Task 3 concern from worker: scan/snapshot/diff files are implemented and tested, but may still need TOC loading integration review because `GBankManager.toc` was not modified in that task

## Important Commits

- `43cc232` `feat: add snapshot scan and history diff foundation`
- `8feb0f6` `fix: harden task 2 migrations and spec harness`
- `ae019e0` `fix: wire task 2 persistence at runtime`
- `8a6fceb` `feat: add persistence schema and permissions`
- `09ded5d` `fix: align scaffold with wow addon loading`
- `b8c6976` `feat: scaffold addon and test harness`

## Local Runner

- Local LuaJIT runner is now available at `tools/lua/lua.exe`
- Verified command result before stopping:

```text
PASS tests/run_all.lua
```

- Minimal checked-in runtime files are:
  - `tools/lua/lua.exe`
  - `tools/lua/lua51.dll`
  - `tools/lua/msvcp140.dll`
  - `tools/lua/vcruntime140.dll`
  - `tools/lua/concrt140.dll`
  - `tools/lua/vccorlib140.dll`

## Recommended Next Step

Resume with the Task 3 review loop instead of starting Task 4 immediately:

1. Review commit `43cc232` for Task 3 spec compliance
2. Review commit `43cc232` for Task 3 code quality
3. Fix anything found
4. Only then move to Task 4

## Notes

- Main repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for` is intentionally left on `master` with docs commits only
- Active implementation work is isolated in the worktree branch above
