# GBankManager First-Run Onboarding Design

## Goal

Add a first-run onboarding walkthrough that appears the first time a player opens the UI they can access, whether they launch it from the minimap button or `/gbm`.

The onboarding should:

- teach full-shell users how initial guild setup works
- teach request-only users how the request workflow works
- explain blacklist behavior in user-friendly terms
- be skippable
- support `Do not show again`
- be manually reopenable from `Options`

This is an onboarding and guidance feature, not an automation feature. It should explain setup and workflow without trying to edit Guild Info, write officer notes, or make guild-policy changes on the user's behalf.

## Scope

### In scope

- role-aware first-run onboarding for:
  - full-shell users
  - request-only users
- automatic trigger on first accessible UI open from:
  - `/gbm`
  - minimap button
- reusable walkthrough modal shell
- persisted local onboarding state
- `Skip`
- `Do not show again`
- `Options` entry point to reopen the walkthrough
- focused automated tests for state, triggers, and UI behavior

### Out of scope

- automated Guild Info publishing
- automated blacklist writes
- officer-note editing
- setup wizards that directly change live guild policy
- forcing walkthrough completion before UI use
- cross-guild or guild-shared onboarding preferences

## Trigger Behavior

When a player opens the UI they can access for the first time, the addon should evaluate onboarding state and access profile.

If the player has full-shell access:

- open the manager walkthrough unless it was already completed or suppressed with `Do not show again`

If the player has request-only access:

- open the request-only walkthrough unless it was already completed or suppressed with `Do not show again`

This trigger should run when UI entry happens from:

- `/gbm`
- minimap button

The trigger should not run for:

- explicit manual reopen from `Options`
- users who already completed the relevant walkthrough
- users who selected `Do not show again` for the relevant walkthrough

If a player skips without choosing `Do not show again`, the walkthrough remains eligible to auto-open again on a future first-access-style entry.

If a player's access changes later, the addon should treat the other onboarding flow as independently eligible. A player who first saw the request-only walkthrough but later gains full-shell access should still be able to receive the manager walkthrough once.

## Walkthrough Content

### Full-shell walkthrough

Keep the manager flow short, practical, and role-oriented.

#### Step 1: Welcome

Explain what GBankManager does in plain language:

- scan guild-bank inventory
- manage requests
- manage minimums
- coordinate setup through guild permissions

Controls:

- `Start`
- `Skip`
- `Do not show again`

#### Step 2: Permissions and Guild Info

Explain:

- permissions come from Guild Info policy
- `Options -> Permissions` is where officers review and manage access
- rank permissions determine which players can view or perform workflow actions

Optional step action:

- `Open Permissions`

#### Step 3: Blacklist

Explain blacklist in user-friendly terms:

- it is for blocking request-system usage for specific players
- the addon reads blacklist membership from `[GBMBL]` in officer notes
- the addon shows the result in a read-only view
- guild leadership manages membership outside the addon by editing officer notes

Optional step action:

- `Open Blacklist`

#### Step 4: Request system

Explain both sides of the workflow:

- members create requests and review status
- managers review, approve or deny, and choose bank tabs when approving
- approved requests can create or update matching Minimums behavior behind the scenes

Optional step action:

- `Open Requests`

#### Step 5: Recommended first setup order

Provide a short setup checklist:

1. review permissions
2. verify blacklist guidance
3. test a request flow
4. scan the bank

Optional step actions:

- `Open Dashboard`
- `Open Requests`

#### Step 6: Finish

End with a simple next step:

- `Open Permissions`
- `Open Requests`
- `Done`

### Request-only walkthrough

Keep the request-only flow smaller and focused on what that player can actually use.

#### Step 1: Welcome

Explain that this player has access to the lightweight request workflow rather than the full management shell.

Controls:

- `Start`
- `Skip`
- `Do not show again`

#### Step 2: How requests work

Explain:

- how to create a request
- how to review request status
- that guild managers handle approval decisions

Optional step action:

- `Open New Request`

#### Step 3: Blacklist

Explain in plain language:

- if guild leadership marks a player as blocked for requests, new request submission will be denied
- this is controlled by guild leadership, not by the request-only user

#### Step 4: Finish

Offer:

- `Open New Request`
- `Done`

## UI Structure

Implement one reusable onboarding modal rather than separate UI implementations for each role.

The modal should support:

- title
- body copy
- optional short bullet list
- optional contextual action button such as `Open Permissions` or `Open New Request`
- footer controls for `Back`, `Next`, `Skip`, and `Do not show again`
- a small step indicator such as `2 of 5`

Role-specific behavior should come from step data rather than branching entire UI implementations. This keeps the control reusable and scalable as the project evolves.

The modal should sit on top of the currently accessible UI:

- full-shell users stay in the full shell
- request-only users stay in the compact request flow

The onboarding should guide navigation but should not force the wrong shell mode for the current player.

## Flow Model

Define the walkthroughs as data-driven sequences:

- `manager_first_run_steps`
- `request_only_first_run_steps`

Each step should be represented by a small data contract with fields such as:

- `id`
- `title`
- `description`
- optional `bullets`
- optional `targetView`
- optional `primaryAction`
- optional `primaryActionLabel`
- `allowBack`

The controller should:

1. load the relevant step set
2. show the current step in the onboarding modal
3. optionally switch the visible target view when a step requests it
4. advance or rewind through the step sequence
5. mark completion or suppression state when the user exits intentionally

This keeps the walkthrough logic easy to extend later without duplicating frame construction logic.

## Persistence Model

Onboarding state should be saved as local UX state in SavedVariables.

Recommended shape:

```lua
onboarding = {
    completed = {
        manager = false,
        requestOnly = false,
    },
    doNotShowAgain = {
        manager = false,
        requestOnly = false,
    },
    lastShownVersion = nil,
}
```

Rules:

- this state is local to the player, not guild-shared
- `completed` and `doNotShowAgain` are tracked separately for manager and request-only flows
- manual reopen from `Options` must ignore `completed` and `doNotShowAgain`
- `lastShownVersion` may be stored for future migration or re-show behavior, but v1 does not need to actively re-display walkthroughs based on version changes

## Trigger Integration

The onboarding trigger should plug into the same accessible-UI entry path already used by:

- `/gbm`
- minimap button open behavior

Behavior rules:

- determine the current access profile before deciding which walkthrough to launch
- only auto-open after the accessible UI is successfully shown
- when the walkthrough opens, it should overlay the current UI rather than replace the entry flow

Exit behavior:

- `Skip` closes the walkthrough without marking completion
- `Do not show again` suppresses future auto-open for that role flow
- completing the final step marks the relevant walkthrough as completed

## Options Integration

`Options` should expose a manual entry point to reopen onboarding.

Requirements:

- available to full-shell users from the existing options surface
- clearly labeled as a help or onboarding action
- able to launch the manager walkthrough on demand

For v1, a single `Replay Onboarding` entry point in `Options` is sufficient for full-shell users.

Because request-only users do not currently have access to `Options`, this design does not treat manual replay for request-only users as part of v1. Their request-focused walkthrough still auto-opens on first eligible UI access. If manual replay parity is desired later for request-only users, add a separate help or replay affordance inside the compact request surface rather than trying to force `Options` into request-only mode.

## Testing Strategy

Follow focused TDD coverage rather than a single broad integration spec.

### Core tests

- first `/gbm` open for full-shell access auto-opens manager onboarding
- first `/gbm` open for request-only access auto-opens request-only onboarding
- minimap open follows the same trigger behavior
- `Skip` closes without marking completion
- `Do not show again` suppresses future auto-open
- finishing the last step marks the relevant walkthrough completed
- `Options` can reopen the walkthrough even after completion or suppression
- step actions open the intended target views or flows
- request-only onboarding does not force the full shell
- a later full-shell promotion can still trigger manager onboarding even if request-only onboarding was already seen

### Suggested spec split

- onboarding state/controller spec
- slash-command and minimap trigger spec
- onboarding modal UI spec
- options reopen spec

This keeps the tests aligned with the project's preference for focused subsystem coverage.

## Edge Cases

### Access changes

If a player moves from request-only access to full-shell access later:

- the manager walkthrough should still be eligible once unless already completed or suppressed

### Skip behavior

If a player skips without suppression:

- the walkthrough can auto-open again on a future eligible launch

### Suppression behavior

If a player selects `Do not show again`:

- auto-open is suppressed
- manual reopen from `Options` still works

### Request-only mode

If the player only has request access:

- onboarding should remain attached to the compact request surface
- it must not redirect them into inaccessible or irrelevant management UI

### Combat or fragile UI timing

If the addon is in a transient or fragile state when the UI first opens:

- defer walkthrough display until the accessible UI is stably shown rather than trying to force the modal immediately

### Future walkthrough revisions

If onboarding content changes later:

- the persisted version field gives a path for future controlled re-show behavior
- v1 should not automatically resurface walkthroughs after completion unless intentionally designed later

## Implementation Notes

- prefer one reusable onboarding modal shell with data-driven steps
- do not build a separate welcome-screen application mode
- do not perform live guild configuration changes from the walkthrough
- keep copy practical and friendly rather than technical
- preserve current role boundaries and access rules
- keep state local so there is no cross-guild or cross-player preference bleed

## Success Criteria

- first accessible UI open from `/gbm` or the minimap button can show a role-appropriate onboarding flow
- full-shell users receive a short setup-focused walkthrough
- request-only users receive a short request-focused walkthrough
- users can skip
- users can suppress future auto-open with `Do not show again`
- users can replay onboarding from `Options`
- onboarding preferences stay local
- automated coverage proves trigger, suppression, completion, and reopen behavior
