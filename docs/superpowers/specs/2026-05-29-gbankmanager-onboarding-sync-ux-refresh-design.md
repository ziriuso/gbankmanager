# GBankManager Onboarding And Sync UX Refresh Design

## Summary

Refresh the first-run onboarding and `Options -> Sync` experience so the addon better explains guild-backed permissions, blacklist behavior, request synchronization, and peer sync status without feeling cramped or confusing.

This slice also reworks related `Options` layout issues that are now directly exposed by the onboarding and sync experience:

- onboarding footer button styling and modal behavior
- `Appearance` panel chrome around `Replay Onboarding`
- `Data` panel spacing and repair-threshold clarity
- a reusable scrollable sync status table with explicit sync actions

The goal is to keep the existing guild-policy architecture intact while making the live operator experience clearer for both full-shell and request-only users.

## Goals

- Make onboarding feel like a helpful movable guide rather than a cramped blocking popup.
- Explain Guild Info policy, blacklist sourcing, and request sync behavior in plain language.
- Replace the current sync peer list with a clearer status table and explicit sync actions.
- Support both full-shell and request-only users with role-appropriate sync controls.
- Add throttled manual sync triggers through both the UI and slash commands.
- Improve `Appearance` and `Data` panel layout so the new controls feel intentional and readable.

## Non-Goals

- Changing the underlying guild-policy source of truth away from Guild Info and existing blacklist parsing.
- Adding a new addon-comm-based permissions sync family.
- Replacing the existing automatic sync flows with manual-only behavior.
- Persisting onboarding modal position between opens.
- Changing the completed item-hyperlink migration or CSV `Tier` behavior.

## User Roles

### Full-Shell Users

Full-shell users can access the main shell, all sync families, and replay the manager onboarding flow from `Options -> Appearance`.

### Request-Only Users

Request-only users still receive first-run onboarding, but their sync controls are limited to request-related actions. They can trigger request sync manually, while non-request sync actions remain visible but disabled with explanatory helper text.

## Onboarding Experience

## Modal Behavior

The onboarding surface remains a modal overlay, but it changes from a fixed blocking popup into a movable companion panel.

Behavior requirements:

- the modal is draggable while open
- the modal recenters every time it opens
- the modal can remain open while the user changes shell tabs underneath it
- `Skip` dismisses the current walkthrough without setting suppression
- `Do Not Show Again` dismisses the walkthrough and suppresses future auto-open behavior
- replayed onboarding from `Options -> Appearance` always starts at the first step of the relevant flow

The modal should still visually read as a guided overlay, but its footer and spacing must be cleaned up so the dismiss actions no longer look crowded or malformed.

## Footer Controls

The onboarding footer becomes an intentionally structured action row:

- primary progression action stays visually dominant
- `Skip` is a secondary action
- `Do Not Show Again` is a distinct suppression action with enough width, padding, and text legibility to avoid the current cramped appearance

All three controls should use the shared button styling system where possible, with only the minimum onboarding-specific sizing and spacing needed.

## Content Refresh

### Step 1

Step 1 remains a brief orientation step. It should explain what the addon helps with and set expectations for the role-aware walkthrough.

### Step 2: Permissions

Step 2 becomes a deeper permissions explanation.

It must explicitly explain:

- Guild Info is the source of truth for the guild permission policy
- the addon reads Guild Info to determine what actions a player can perform
- blacklist behavior is part of the guild-backed policy model, not a local freeform permission override
- `Refresh Guild Policy` is the way to reread the current Guild Info and guild-backed policy inputs

This step should avoid implying that policy is synced peer-to-peer through addon comms. The messaging must reinforce that permissions come from guild-maintained data, not from another player pressing a sync button.

### Step 3: Blacklist

Step 3 must explain blacklist behavior more clearly than the current copy.

It should cover:

- what blacklist does
- who it affects
- how it influences request behavior
- why the parsed result display is read-only

The read-only explanation should be explicit: the addon is showing the interpreted guild-backed result, not an editable local source. If the guild wants a different outcome, officers update the real guild policy source and then use `Refresh Guild Policy`.

### Requests Messaging

Any onboarding copy that references requests must explicitly say that request updates synchronize between online addon users. This copy should be present in both the manager and request-only flows where relevant.

## Role-Specific Flow

The onboarding shell stays shared, but the content remains role-aware:

- full-shell users see the manager-oriented walkthrough with permissions, blacklist, and broader workflow guidance
- request-only users see the request-focused flow, including request synchronization guidance

Both flows should reuse the same modal component, footer layout, and drag behavior.

## Options Layout Updates

## Appearance Panel

The `Appearance` panel background chrome must extend far enough to fully contain the `Replay Onboarding` copy and button. The current visual mismatch, where the panel background stops short of the replay area, should be removed.

The existing `Replay Onboarding` affordance remains in `Options -> Appearance`.

## Data Panel

The `Data` panel layout changes are part of this same UX pass because the onboarding and live operator flow now draw attention to these controls.

Required changes:

- move `Repair Threshold` into the left-side control area instead of leaving it isolated on the right
- add helper text explaining that any withdrawal amount equal to or under the threshold is classified as a repair rather than a normal withdrawal
- lower the `Save Settings` row so it does not crowd the threshold field
- lower the `Clear Data` section as well so the panel breathes more naturally

The existing save-based persistence model for the `Data` panel remains unchanged, except for the previously approved immediate-save toggles that already live elsewhere.

## Sync Tab Redesign

## Table Surface

`Options -> Sync` becomes a real scrollable status table rather than a simple stacked peer history view.

Columns:

- `Character`
- `Last Time Seen`
- `Last Time Synchronized`

`Character` must display `Name-Realm` instead of a short local-only name.

The table is:

- guild-scoped
- read-only
- backed by persisted peer history
- scrollable when the peer count exceeds the visible area

The table should use the project's shared table patterns instead of inventing a one-off rendering surface.

## Sync Actions

The sync surface also exposes explicit manual actions:

- `Sync Requests`
- `Sync Minimums`
- `Sync Ledger`
- `Sync All`

No `Sync Permissions` button is added. The existing `Refresh Guild Policy` behavior on the permissions surface remains the correct policy refresh path.

## Role-Aware Availability

### Full-Shell Users

Full-shell users can trigger:

- `Sync Requests`
- `Sync Minimums`
- `Sync Ledger`
- `Sync All`

### Request-Only Users

Request-only users can trigger:

- `Sync Requests`

They still see the other sync actions, but those actions are disabled with explanatory text indicating that those sync families require broader guild-management access.

## Sync Semantics

Manual sync actions should call into a shared sync-action layer rather than embedding comm behavior directly in the button or slash-command handlers.

Intended behavior:

- `Sync Requests` requests request-state synchronization from eligible online guild peers with the addon
- `Sync Minimums` requests minimums synchronization from eligible online guild peers with the addon
- `Sync Ledger` requests ledger synchronization from eligible online guild peers with the addon
- `Sync All` performs all sync families the current user is allowed to request

For request-only users, `Sync All` resolves to the same effective behavior as `Sync Requests`.

## Sync Status Meaning

`Last Time Seen` should represent peer presence or hello-style activity.

`Last Time Synchronized` should update only when the addon records a real sync-family success signal, such as an accepted sync payload or a completed valid sync interaction. Presence-only activity must not update the synchronized timestamp.

## Slash Commands

Add the following player-facing commands:

- `/gbm sync`
- `/gbm sync requests`
- `/gbm sync minimums`
- `/gbm sync ledger`
- `/gbm sync all`

Default behavior for bare `/gbm sync`:

- full-shell users: equivalent to `/gbm sync all`
- request-only users: equivalent to `/gbm sync requests`

If a user invokes a sync action they are not allowed to run, the addon should respond with clear player-facing feedback instead of silently failing.

## Cooldown And Throttling

Manual sync actions need anti-spam protection.

Requirements:

- 60-second cooldown per sync action per character
- separate cooldown buckets by action
- `Sync Requests` cooldown does not block `Sync Ledger`
- `Sync All` has its own explicit cooldown path
- `Sync All` must also respect action-level cooldowns for the families it tries to invoke

User feedback should explain when a sync action is cooling down and when the player can try again.

The same cooldown behavior must apply consistently across:

- sync buttons in `Options -> Sync`
- slash-command sync triggers

## Component And Architecture Notes

- Keep controls reusable and scalable by building the sync surface from existing shared-table and shared-button patterns where possible.
- Introduce a shared sync-action coordinator if one does not already exist, instead of duplicating throttle and permission checks across UI and slash paths.
- Keep peer history persistence guild-scoped so cross-guild state cannot bleed between characters.
- Avoid widening the policy system beyond its current Guild Info and blacklist parsing model.

## Testing Strategy

Follow TDD for each implementation slice.

Expected coverage areas:

- onboarding footer layout contract
- draggable onboarding modal behavior
- recenter-on-open modal behavior
- updated onboarding copy expectations for permissions, blacklist, and request sync messaging
- `Appearance` replay section containment
- `Data` panel repair-threshold helper text and revised layout expectations
- sync table column rendering and `Name-Realm` formatting
- role-aware sync action availability
- slash-command routing for all sync commands
- cooldown behavior for each action and `Sync All`
- `Last Time Seen` vs `Last Time Synchronized` update semantics where testable in the current harness

## Documentation Updates

Update these docs during implementation:

- `README.md`
- `docs/manual-test-checklist.md`
- `docs/superpowers/handoffs/latest-handoff.md`

If manual sync behavior or onboarding semantics materially change during implementation, keep those docs aligned before closing the slice.

## Risks And Guardrails

- Do not conflate the completed item-hyperlink migration with new blockers from this slice.
- CSV exports must keep `Tier` as a numeric value.
- Treat `244559` only as a future same-itemID multi-quality smoke anchor, not as a blocker for this onboarding and sync UX work.
- Be careful that request-only sync affordances do not accidentally imply broader permissions than the player actually has.
- Keep live guild-policy messaging honest: permissions come from guild data, not peer sync.

## Acceptance Criteria

- Onboarding footer controls are readable and visually stable.
- The onboarding modal can be dragged while open and reopens centered.
- Step 2 clearly explains Guild Info-based permissions and the `Refresh Guild Policy` path.
- Step 3 clearly explains blacklist behavior and why parsed results are read-only.
- Request onboarding copy explicitly references synchronization between online addon users.
- `Appearance` visually contains the `Replay Onboarding` section.
- `Data` shows the repair-threshold helper text and the save/clear sections no longer crowd the inputs.
- `Options -> Sync` shows a scrollable table with `Character`, `Last Time Seen`, and `Last Time Synchronized`.
- Character names render as `Name-Realm`.
- Full-shell users can manually run requests, minimums, ledger, and all sync actions.
- Request-only users can manually run requests sync and see the other actions disabled with explanatory messaging.
- `/gbm sync` and its subcommands route to the same sync-action backend as the UI buttons.
- Manual sync triggers are throttled to 60 seconds per action per character with clear cooldown feedback.
