# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Latest code commit: `551ffb0` (`refactor: sharpen domain ui separation`)
- Latest docs commit: `034d290` (`docs: close out phase 5 refactor plan`)
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: `PASS tests/run_all.lua`

## Read First

1. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
2. `docs/superpowers/plans/2026-05-13-wow-guild-bank-addon-refactor-plan.md`
3. `docs/superpowers/handoffs/latest-handoff.md`
4. `git status -sb`
5. `.\tools\lua\lua.exe .\tests\run_all.lua`

## Current Repo State

- Worktree is expected to be clean after commit `034d290`
- If anything is dirty when resuming, inspect before changing behavior because the current handoff assumes a clean baseline

## Current Product State

### Architecture

- `Core/` is now a thin bootstrap, event-registration, and slash-command layer
- `Data/` owns defaults, migrations, and store-backed DB access
- `Domain/` owns snapshots, diffing, planning, exports, requests, and permissions
- `Features/` owns live scan workflows and feature-owned event adapters
- `UI/` is split into shell plus focused controllers:
  - `MainFrameShell.lua`
  - `MainTableController.lua`
  - `MainRequestsController.lua`
  - `MainExportsController.lua`
  - `MainMinimumsController.lua`
  - `MainFrame.lua`

### Shell

- `/gbm ui` opens the officer shell
- Current tabs are `Dashboard`, `Inventory`, `History`, `Minimums`, `Requests`, `Exports`, `About`, and `Options`
- `Targets` has been removed and should not come back

### History

- `History` is procurement-audit-only
- Do not restore raw bank diff history into this view

### Exports

- Export generation is grounded in the planning model
- Officer-facing `Spreadsheet` has been renamed to `CSV`
- Selecting an export preset opens a modal with:
  - scrollable output
  - `Select All`
  - `Copy`
  - `Close`
- Auctionator has an editable shopping-list name field
- Auctionator output follows the screenshot-driven caret/semicolon format and should stay the source of truth unless the user supplies a newer sample

### Minimums

- Minimums uses direct in-table editing with staged draft rows
- Saved rows do not allow `Bank Tab` editing
- New rows use a `Bank Tab` dropdown instead of freeform entry
- Inline ghosted cell text behind active editors was removed
- Search field is labeled
- Search / toggle controls were repositioned to avoid overlap
- Add modal labels and row alignment were improved
- `Restock Source` is hidden from the Minimums table for now
- A stronger draft-indicator overlay was added to improve live-client row highlighting
- Search resolution now goes beyond the active guild-bank snapshot by using remembered item data and search catalog entries already known to the addon

## Important Constraints

- Keep `History` procurement-audit-only
- Do not reintroduce `Targets`
- Keep exports as outputs of planning, not a separate source of truth
- Keep using TDD for follow-up fixes

## Deferred TODO

- Offline/global item discovery for Minimums add-item search remains intentionally deferred
- Do not reintroduce Auction House requirements as the primary search path
- If broader item discovery work resumes later, prefer a self-owned persisted item index or other explicit design rather than fragile reads from other addons

## Best Next Work

1. Finish any remaining Phase 6 naming/docs polish if a later session finds stale references
2. Re-verify the new Minimums draft/highlight treatment in the live WoW client
3. Confirm the inline `Restock` and `Minimum` editors still feel visually aligned with the original text baseline at WoW scale
4. Recheck the staged-row `Bank Tab` dropdown visibility and usability in live client
5. Recheck non-bank add-item search with real user flows and decide whether the current remembered-item catalog behavior is sufficient
6. If live-client QA still finds Minimums rendering issues, keep the fixes focused and do not reopen unrelated shell or export work

## Docs Updated In The Latest Work

- `README.md`
  - refreshed feature wording and architecture overview to match the refactored module split
- `docs/manual-test-checklist.md`
  - refreshed phase-6 QA wording and removed stale target-focused language
- `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
  - should be treated through its delta sections, not the original target-era task list
- `docs/superpowers/plans/2026-05-13-wow-guild-bank-addon-refactor-plan.md`
  - phase tracker for the completed refactor slices

## Suggested Next Prompt

> Continue work on the WoW guild bank addon from the implementation worktree.
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
> Branch: `codex/gbankmanager-v1`
>
> Read first:
> `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
> `docs/superpowers/plans/2026-05-13-wow-guild-bank-addon-refactor-plan.md`
> `docs/superpowers/handoffs/latest-handoff.md`
>
> Then run:
> `git status -sb`
> `.\tools\lua\lua.exe .\tests\run_all.lua`
>
> Resume from commit `551ffb0`.
>
> Priority for this session: return to live-client Minimums QA follow-up or new feature work from the refactored baseline.
>
> Required outcomes:
> 1. Keep `History` procurement-audit-only and do not reintroduce `Targets`.
> 2. Keep exports grounded in the planning model.
> 3. Re-verify Minimums live-client behavior only if the session is reopening QA follow-up work.
> 4. Treat offline/global item discovery as a separate explicit design task.
> 5. Use TDD for any follow-up fixes and rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.
