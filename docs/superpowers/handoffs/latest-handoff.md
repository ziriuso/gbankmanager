# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Latest code commit: `186f353` (`fix: tighten minimums inline editing and search`)
- Prior feature commit: `b879872` (`feat: finish exports workflow and minimums polish`)
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result: `PASS tests/run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`
6. `.\tools\lua\lua.exe .\tests\run_all.lua`

## Current Repo State

- Worktree is expected to be clean after commit `186f353`
- If anything is dirty when resuming, inspect before changing behavior because the current handoff assumes a clean baseline

## Current Product State

### Shell

- `/gbm ui` opens the officer shell
- Current tabs are `Dashboard`, `Inventory`, `History`, `Minimums`, `Requests`, `Exports`, `About`, and `Options`
- `Targets` has been removed and should not come back

### History

- `History` is procurement-audit-only
- Do not restore raw bank diff history into this view

### Exports

- Export generation is still grounded in the planning model
- Officer-facing `Spreadsheet` has been renamed to `CSV`
- Selecting an export preset opens a modal with:
  - scrollable output
  - `Select All`
  - `Copy`
  - `Close`
- Auctionator now has an editable shopping-list name field
- Auctionator output was rebuilt to the screenshot-driven caret/semicolon format and should be treated as the current source of truth unless the user supplies a newer sample

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

## Outstanding Tomorrow

These are the real next-session checks, in priority order.

1. Re-verify the new Minimums draft/highlight treatment in the live WoW client
2. Confirm the inline `Restock` and `Minimum` editors still feel visually aligned with the original text baseline at WoW scale
3. Recheck the staged-row `Bank Tab` dropdown visibility and usability in live client
4. Recheck non-bank add-item search with real user flows and decide whether the current remembered-item catalog behavior is sufficient
5. If live-client QA still finds Minimums rendering issues, keep the fixes focused and do not reopen unrelated shell or export work

## Known Behavior Notes

- Non-bank partial-name search is broader than before, but it is still limited by item data the addon already knows locally through saved data or prior exact resolution
- That means it is not yet a guaranteed universal WoW-wide substring search for unseen items
- If the user wants fully broader discovery later, that will likely need a separate design decision around how far to lean on client item APIs and cached item info

## Docs Updated In The Latest Work

- `docs/manual-test-checklist.md`
  - added export modal QA coverage
  - added Auctionator naming/format QA coverage
  - added Minimums follow-up QA coverage
- `docs/superpowers/handoffs/latest-handoff.md`
  - refreshed to the current post-exports, post-Minimums-follow-up state

## Suggested Next Prompt

> Continue work on the WoW guild bank addon from the implementation worktree.
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
> Branch: `codex/gbankmanager-v1`
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
> Resume from commit `186f353`.
>
> Priority for this session: live-client QA and focused follow-up fixes for Minimums.
>
> Required outcomes:
> 1. Verify the visible row-highlighting behavior in live client and strengthen it if needed.
> 2. Verify inline editor alignment in live client and tighten it if needed.
> 3. Verify staged-row `Bank Tab` dropdown visibility/usability and improve it if needed.
> 4. Re-test add-item search outside current bank snapshot and decide whether the current remembered-item catalog approach is sufficient.
> 5. Keep `History` procurement-audit-only and do not reintroduce `Targets`.
> 6. Keep exports grounded in the planning model.
> 7. Use TDD for any follow-up fixes and rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.
