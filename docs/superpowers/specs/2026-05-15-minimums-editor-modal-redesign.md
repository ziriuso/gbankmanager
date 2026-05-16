# GBankManager Minimums Editor Modal Redesign

## Summary

Replace the current footer-based Minimums row editor with a centered reusable modal editor that is used for both newly added rows and existing rows. Tighten the draft-state presentation in the table so the table only reflects state and selection, while all editing happens in the modal. Add crafted-tier backfill from the bundled item search catalog when scan data does not already provide `craftedQuality` and `craftedQualityIcon`.

This slice is intentionally focused on the Minimums editing experience. It does not redesign the search modal itself beyond handing off directly into the new details modal after an item is added from search.

## Goals

- Make Minimums add/edit behavior consistent and predictable.
- Remove the overflowing footer editor and replace it with a centered modal editor.
- Open the details editor immediately after adding a new item from search.
- Reuse the same editor for both new rows and existing rows.
- Show clear draft-state highlighting for added, edited, and removed rows before `Save All`.
- Remove the left-edge row artifact caused by inline editor state leaking into table rows.
- Use icon-only actions without overlaid fallback letters.
- Backfill crafted tier from the bundled search catalog when scan data does not provide it.

## Non-Goals

- No redesign of Requests in this slice.
- No redesign of the search selector itself beyond the add-to-editor handoff.
- No new guild-bank scan behavior.
- No changes to `Save All` persistence semantics beyond keeping the existing draft model working with the new modal editor.

## Current Problems

- The footer editor layout overflows and becomes visually unstable when editing newly added or existing rows.
- New rows are staged into the table and then edited in an awkward second-step footer flow instead of continuing directly into details.
- The current action buttons show icon overlays with fallback letters, which looks noisy and inconsistent.
- Table rows can show a left-edge rendering artifact after edits.
- Draft-state highlighting is not consistently communicating add, edit, and delete state before `Save All`.
- Crafted tiers can be missing from Minimums rows even when the bundled search catalog knows the correct crafted quality for that item.

## User Experience Design

### Add Flow

1. The user clicks `Add`.
2. The existing `Add Minimum Item` search modal opens.
3. The user searches and confirms an item from the bundled item database.
4. Clicking `Add` in the search modal immediately opens a new centered `Minimum Details` modal for that selected item.
5. The details modal is where the user sets:
   - `Bank Tab`
   - `Restock`
   - `Minimum`
6. Confirming in the details modal stages the row into the table as a draft add and closes the modal.

The search modal should no longer leave the user at the table and expect them to continue editing in the footer.

### Existing Row Edit Flow

1. The user clicks an existing Minimums table row.
2. The same centered `Minimum Details` modal opens, populated from the row state.
3. Changes made there update the draft state for that row.
4. Closing or confirming returns the user to the table, where the row highlights reflect its draft state.

The details modal is the only row-editing surface for Minimums after this redesign.

### Modal Behavior

- The details modal should be visually centered like the search modal.
- It should use reusable shell helpers and panel styling already used elsewhere in the project.
- It should include:
  - item name
  - item ID
  - crafted tier icon and tier text when available
  - Bank Tab control
  - Restock toggle
  - Minimum input
  - draft-state status text
  - action buttons

### Buttons And Icons

- Use icon-only buttons where appropriate.
- Add a proper green plus icon for add/confirm.
- Keep a red X for delete.
- Keep an undo icon for restoring draft state.
- Do not overlay fallback letters like `X` or `U` on top of icon buttons.

## Table State Contract

After this redesign, Minimums table rows do not host live editing widgets.

The table is responsible only for:

- showing item data
- showing crafted tier in the `Tier` column
- showing draft-state styling
- opening the details modal when clicked

The table should not be responsible for:

- inline Bank Tab dropdown editing
- inline Restock toggles
- inline Minimum input editing
- hosting footer-based row-editor controls

This separation is intended to eliminate the current layout overflow and the left-edge rendering artifact.

## Draft-State Styling

### Added Rows

- Row receives green-tinted draft styling.
- Row shows a green add indicator.

### Edited Rows

- Row receives yellow-tinted draft styling.
- Row shows an edit/change indicator.

### Removed Rows

- Row receives red-tinted draft styling.
- Row shows a delete indicator.

### Unchanged Rows

- Row uses normal styling.

Draft-state styling must be applied consistently before `Save All`, so the table clearly communicates pending changes.

## Crafted Tier Backfill

Minimums row rendering and details-modal rendering should resolve crafted tier in this order:

1. row or scan data if it already contains `craftedQuality` and `craftedQualityIcon`
2. bundled item search catalog entry for the same `itemID`
3. no crafted tier shown if neither source has it

This backfill logic should be implemented once and reused by:

- Minimums table row hydration
- Minimum details modal hydration

The goal is to keep the table and the modal consistent and not depend on guild-bank scan completeness for crafted-tier display.

## Architecture

### New Reusable Control

Introduce a reusable centered details modal for Minimums editing, built with shared shell helpers so the control pattern can be reused elsewhere if needed.

Responsibilities:

- receive a normalized Minimums editor state
- render that state
- allow Bank Tab, Restock, and Minimum edits
- emit confirm, remove, undo, and cancel actions

### Minimums Controller Changes

The Minimums controller should:

- stop using the footer editor as the active editing surface
- open the details modal after search add confirmation
- open the same details modal when an existing row is clicked
- keep draft creation and persistence logic in the controller
- apply draft-state styling to rows separately from modal editing

### Row Hydration Changes

Minimums row hydration should:

- enrich crafted-tier data using the shared backfill resolver
- expose normalized draft state for styling
- stop attaching inline editing widgets to rows

## Error Handling And Edge Cases

- If a new row does not have a Bank Tab selected, the details modal should not confirm the draft.
- If `Minimum` is empty or invalid, the details modal should not confirm the draft.
- If crafted tier is unavailable from both scan data and catalog data, the row and modal should render cleanly without it.
- Removed rows should stay clearly marked and undoable before `Save All`.
- Canceling the details modal for a brand-new add should not stage a partial row.

## Testing Strategy

Add focused Minimums tests for:

- `Add` opens the search modal.
- confirming an item from the search modal immediately opens the centered details modal.
- clicking an existing row opens the same details modal.
- the footer editor is no longer the active Minimums edit surface.
- newly added rows require Bank Tab, Restock, and Minimum in the details modal before staging.
- row draft-state styling correctly reflects added, edited, and removed state.
- the details modal uses crafted-tier backfill from the bundled catalog when scan data omits it.
- icon-only action buttons render without fallback letter overlays.
- no left-edge artifact or inline widget remnants are attached to table rows.

Manual verification should confirm:

- `243734` shows crafted tier through backfill if scan data lacks it
- add flow transitions directly from search into details
- existing row click opens the centered details modal
- row colors clearly communicate add, edit, and remove state before `Save All`

## Documentation Updates

Update:

- Minimums-related testing docs
- manual test checklist
- any Minimums usage notes in the project README if they describe the old footer editor flow

## Risks

- Replacing the footer editor touches several Minimums interaction assumptions at once.
- Draft-state logic and row hydration must stay aligned or table colors may drift from the underlying draft state.
- If crafted-tier backfill is implemented in multiple places instead of one shared resolver, the table and modal can diverge again.

## Recommendation

Proceed with a full Minimums editor shift to a centered reusable details modal and remove the footer editor from the active workflow. This is the cleanest way to solve the layout overflow, modal handoff, row artifact, inconsistent draft highlighting, and missing crafted-tier fallback together rather than as isolated patches.
