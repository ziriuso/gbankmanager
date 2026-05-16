# GBankManager Item Search Selector Redesign

## Summary

Redesign the shared item search used by Minimums and Requests so it behaves like a real catalog search instead of a fragile substring auto-fill. The new design should support broad word-based queries such as `flask of` and `flask magister`, show multiple qualifying matches in a scrollable result list, display crafting quality directly in the list, and require an explicit confirmed catalog selection before Minimums `Add` or Requests `Create` can proceed.

## Goals

- Return broad, relevant results for partial multi-word item searches.
- Distinguish same-name or near-same-name catalog variants before selection.
- Stop auto-overwriting user input during broad or ambiguous name searches.
- Keep the search UI reusable across Minimums and Requests.
- Preserve exact item-ID lookup as a fast direct path.

## Non-Goals

- No typo-tolerant fuzzy matching in this pass.
- No live remote fetches or runtime catalog mutation beyond existing local saved-catalog behavior.
- No unrelated Minimums or Requests layout refactor outside what is needed for the new shared result list.

## Search Behavior

### Item ID search

- Exact numeric item ID remains a direct resolver.
- If the item ID exists in the bundled or saved catalog, it resolves immediately.
- Exact item-ID resolution may auto-select the matched row.

### Item name search

- Name queries are normalized into lowercase tokens.
- A qualifying result must contain all query tokens.
- Token normalization should be singular/plural-friendly for common variants such as `magister` and `magisters`.
- Search relevance should rank matches in this order:
  1. exact full-name match
  2. exact full-name prefix match
  3. all query tokens matched in-order within the name
  4. all query tokens matched anywhere in the name
- Broad or ambiguous name queries must never auto-select a result.
- Exact full-name matches may auto-select.

## Shared Selector UI

Replace the current small fixed match-button stack with a reusable scrollable result list in the shared shell selector.

Each result row should show:

- crafting quality icon when present
- readable item name as the primary label
- item ID in the same row for certainty

The selected-item panel should continue to show:

- selected item name
- crafting quality icon when present

### Selection rules

- No result selected:
  - `Selected Item` remains empty
  - `Add` or `Create` remains disabled
- Clicking a result row:
  - selects the item
  - fills both search inputs
  - updates the selected-item display
  - enables the action button
- Exact item-ID resolution:
  - may select immediately
- Exact full-name resolution:
  - may select immediately
- Partial name search with multiple matches:
  - updates the scrollable results only
  - does not auto-select

## Minimums and Requests integration

- Minimums and Requests must keep using the same shared selector component.
- Minimums `Add` requires a confirmed selected catalog item.
- Requests `Create` should use the same confirmed-selection contract for the item fields.
- Existing saved-catalog storage behavior should remain intact so resolved selections continue to improve later searches.

## Testing

Add or update focused tests for:

- `flask of` returning multiple results
- `flask magister` returning all items containing both terms
- singular/plural-friendly matching behavior
- exact item-ID immediate resolution
- exact full-name immediate resolution
- partial-name multi-match behavior with no auto-select
- selected-item requirement for Minimums `Add`
- selected-item requirement for Requests item selection flow
- scrollable shared result list wiring in both views

## Documentation

Update:

- `README.md`
- `docs/manual-test-checklist.md`

to describe:

- token-based shared item search
- scrollable results
- crafting-quality visibility in results
- explicit selection requirement before Minimums `Add` or Requests submission
