# GBankManager Handoff

## Resume Here

- Repo root: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Latest code commit: `88b38ef` (`docs: complete phase 6 refactor polish`)
- Latest docs commit: `88b38ef` (`docs: complete phase 6 refactor polish`)
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

### Shell And Auth

- `/gbm ui` is now auth-aware:
  - `full_ui` users open the full shell
  - non-blacklisted guild members without `full_ui` open a lightweight Requests surface
  - blacklisted users are denied
- `/gbm request` opens the lightweight Requests surface for non-blacklisted guild members
- `/gbm scan` requires `full_ui`
- Current tabs are `Dashboard`, `Inventory`, `History`, `Minimums`, `Requests`, `Exports`, `About`, and `Options`
- `Targets` has been removed and should not come back

### Auth And Permissions

- Auth policy now lives in saved state under `db.auth`
- A compact durable auth-policy carrier now exists for guild-wide sharing via Guild Info text
- Addon chat sync is now a fast path, not the only source of truth
- Policy stores:
  - `version`
  - `revision`
  - `updatedAt`
  - `updatedBy`
  - `updatedByRankIndex`
  - `guildPolicyString`
  - `guildPolicySource`
  - `rankMetadata`
  - per-capability allowlists
  - blacklist entries keyed by `Realm-Character`
  - blacklist hashes for compact durable distribution
- `Guildmaster` remains implicitly allowed for all capabilities and cannot be locked out by blacklist
- Capabilities currently implemented:
  - `full_ui`
  - `request_submit`
  - `request_approve`
  - `request_reject`
  - `request_edit`
  - `request_fulfill`
  - `request_reopen`
  - `minimum_add`
  - `minimum_edit`
  - `minimum_delete`
  - `auth_manage`
- `Options` now includes an auth-management panel with:
  - rank preview
  - current-access preview
  - compact per-capability rank toggles
  - blacklist add/remove staging
  - auth save / revert actions
  - policy string preview
  - Guild Info write / refresh actions
- Request creation no longer trusts typed requester/role fields; it derives actor identity from live WoW guild context
- Officer workflow buttons in Requests now gate on live permissions instead of editable role text
- Request creation now uses labeled fields and visible validation messages instead of silent failure
- Request-only mode now uses a compact shell layout without the dead sidebar gutter or last-scan clutter

### Sync

- `ADDON_LOADED` now refreshes auth rank metadata before UI use
- Guild auth rereads now also react to guild-state events such as roster/rank/motd updates
- Sync payloads now support nested table payloads for:
  - `AUTH_POLICY_SNAPSHOT`
  - `REQUEST_CREATED`
  - `REQUEST_UPDATED`
- Incoming auth snapshots merge through `ResolveAuthConflict`
- Incoming request sync validates capability intent locally before applying
- Addon comms remain guild-wide and should still be treated as authorization, not secrecy

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

1. Run a second live-client auth regression using `docs/auth-manual-test-plan.md` against the new Guild Info-backed policy flow
2. Verify Guildmaster `Write` and `Refresh` behavior from the auth panel with real guild permissions
3. Recheck member request creation now that the form has labeled fields and visible validation
4. Confirm request sync behaves correctly across two logged-in guild clients for create, approve, reject, fulfill, and reopen
5. Re-verify the newer Minimums live-client behavior from the refactored/auth-enabled baseline

## Docs Updated In The Latest Work

- `README.md`
  - refreshed feature wording and architecture overview to match the refactored module split
- `docs/manual-test-checklist.md`
  - now includes auth-role-system manual QA coverage in addition to the earlier phase-6 QA wording
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
> Resume from commit `88b38ef`.
>
> Priority for this session: live-client auth and request-sync QA from the refactored baseline.
>
> Required outcomes:
> 1. Keep `History` procurement-audit-only and do not reintroduce `Targets`.
> 2. Keep exports grounded in the planning model.
> 3. Re-verify auth, blacklist, and request-sync behavior across at least two guild clients before broadening scope again.
> 4. Treat offline/global item discovery as a separate explicit design task.
> 5. Use TDD for any follow-up fixes and rerun `.\tools\lua\lua.exe .\tests\run_all.lua` before claiming completion.
