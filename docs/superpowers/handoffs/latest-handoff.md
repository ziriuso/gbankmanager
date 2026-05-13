# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\superpower-i-want-to-brainstorm-for\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Latest feature commit: `2b710c7` (`feat: polish minimums workflow and shell`)
- Current test command: `.\tools\lua\lua.exe .\tests\run_all.lua`
- Latest verified result in this handoff: `PASS tests/run_all.lua`

## Read First

1. `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
2. `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
3. `docs/superpowers/specs/2026-05-11-wow-guild-bank-task-5-ui-shell-design.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `git status -sb`

## Current Repo State

- Current dirty file expected at handoff time:
  - `M docs/superpowers/handoffs/latest-handoff.md`
- Code and tests are otherwise clean after commit `2b710c7`

## Current Product State

### Shell

- `/gbm ui` opens the current officer shell
- Top bar title/subtitle are generalized to `Guild Bank Manager` / `Guild Bank Management`
- `Dashboard`, `Inventory`, `History`, `Minimums`, `Requests`, `Exports`, `About`, and `Options` are current shell tabs
- `Targets` has been removed from the shell and should stay removed

### Dashboard

- Last scan formatting now abbreviates timezone names such as `Eastern Daylight Time` to `EDT`

### History

- `History` is procurement audit history only
- Visible history table now includes an explicit timestamp column labeled `When`
- Do not restore raw bank diff history into this view

### Inventory

- Inventory quality sorting is improved and covered offline
- Parser now handles `Tier`, `Quality`, and `Rank`-style crafted-quality icon variants
- Remaining real-client risk still exists for:
  - `Algari Mana Oil`
  - `Potion Bomb of Speed`

### Minimums

- Minimums has been rewritten into a direct in-table draft flow
- Key current behavior:
  - row-level direct editing
  - row-level `Undo`
  - explicit row-level remove control
  - bottom `Save All`
  - yellow tint for changed rows
  - red tint for deleted rows
  - green tint for added rows
  - no draft-actions text box
  - no `All Sources` filter
  - `Show All` anchored below the table at bottom-right
- Add modal now renders above the table stack
- Add-item lookup falls back beyond snapshot-only resolution using available client item info

### Confirmed Minimums Follow-Up Bugs

These came from live review and should be treated as active bugs, not optional polish:

- row highlighting is not visibly happening in the live client
- remove and undo row controls still need real icon treatment instead of placeholder glyphs
- existing saved rows should not allow `Bank Tab` editing
- new rows should use a `Bank Tab` dropdown of real guild bank tab names
- inline editors still show ghosted underlying cell values behind the active inputs
- add modal still has text overflow
- add search results still jumble under the fields instead of using a clean dropdown/list
- add search still appears too bank-driven and needs to behave like WoW item database or client item-info search
- modal fields need clearer labels
- `Enabled Only` / `Show All` text still overflows in at least one state
- the Minimums search box in the control frame still needs a visible label

### Exports

- Export generation is still planning-backed
- Current officer-facing gap:
  - preset buttons still route output into text display without a true copy-friendly modal flow
  - there is not yet a proper copy/paste workflow for long outputs
- Officer-facing rename needed:
  - `Spreadsheet` should be `CSV`
- Auctionator remains incomplete:
  - current format is not yet the user-approved Auctionator sample format
  - shopping-list name should be officer-editable instead of effectively hardcoded

## Latest User-Confirmed Export Requirements

These are the active requirements for the next worker.

### Export Modal

- Selecting an export should open a modal
- The modal should include:
  - scrollable content area
  - `Select All` button
  - `Copy` button
  - `Close` button
- The modal must make it practical to copy the full generated output

### CSV Preset

- Rename `Spreadsheet` to `CSV`

### Auctionator Preset

- Output must match the user-provided screenshot/sample format
- `GBankManager` in that format is only the shopping-list name
- Add a field when Auctionator is selected so the officer can set the shopping-list name
- The shopping-list name should default reasonably, but remain editable

## Next Worker Must Also Address

These Minimums items are now explicitly required in the next work set:

1. Make row highlight colors visibly work in the live client
2. Replace placeholder remove and undo controls with real icons
3. Prevent `Bank Tab` editing on existing saved rows
4. Add a real `Bank Tab` dropdown for newly staged rows
5. Eliminate ghosted underlying cell text behind inline editors
6. Fix add-modal text overflow
7. Replace the current jumbled search-results layout with a clean dropdown/list
8. Make add-item search behave like WoW item database or client item-info search rather than bank-only lookup
9. Add clear labels to modal fields
10. Fix `Enabled Only` / `Show All` overflow
11. Add a visible label for the Minimums search field

## Docs Updated In This Session

- `docs/superpowers/specs/2026-05-11-wow-guild-bank-addon-design.md`
  - removed stale Targets-first product assumptions
  - updated History/Exports/About/CSV/Auctionator requirements
- `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`
  - added `Current Delta 2026-05-12`
  - added a focused next-worker export task pack
- `docs/superpowers/handoffs/latest-handoff.md`
  - fully refreshed to current product state

## Next Worker Task List

1. Implement a true export modal flow instead of relying on inline text only
2. Rename `Spreadsheet` to `CSV` everywhere user-facing
3. Add Auctionator shopping-list name input
4. Rebuild Auctionator output to match the user-provided sample
5. Fix the confirmed Minimums live-client issues listed above
6. Add or update tests for export modal visibility, export content routing, preset naming, Auctionator formatting, and Minimums constraints where stubs can verify them
7. Rerun `.\tools\lua\lua.exe .\tests\run_all.lua`
8. Update `docs/manual-test-checklist.md` for export modal copy/paste QA and Minimums follow-up QA
9. Refresh addon files into WoW `AddOns` for manual testing after code changes

## Constraints

- Keep `History` focused on procurement audit events only
- Do not reintroduce `Targets`
- Keep exports as outputs of planning, not a separate source of truth
- Keep using TDD
- Verify with fresh `.\tools\lua\lua.exe .\tests\run_all.lua` output before claiming completion

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
> Resume from commit `2b710c7`.  
>  
> Priority for this session: finish the Exports workflow.  
>  
> Required outcomes:  
> 1. Rename `Spreadsheet` to `CSV`.  
> 2. When an export preset is selected, open a modal with a scrollable output area.  
> 3. Add `Select All`, `Copy`, and `Close` actions to that export modal.  
> 4. Add an editable shopping-list name field for Auctionator.  
> 5. Rebuild the Auctionator output to match the user-provided screenshot/sample format exactly.  
> 6. Fix the confirmed Minimums live-client issues from the handoff:
>    - visible row highlighting
>    - real remove/undo icons
>    - no Bank Tab editing on saved rows
>    - Bank Tab dropdown for new rows
>    - no ghosted underlying inline cell text
>    - add-modal text overflow
>    - clean search dropdown/list
>    - non-bank-only add-item search behavior
>    - clearer modal field labels
>    - toggle overflow fix
>    - labeled Minimums search field
> 7. Keep exports grounded in the planning model.  
> 8. Keep `History` procurement-audit-only and do not reintroduce `Targets`.  
> 9. Use TDD and verify with `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.
