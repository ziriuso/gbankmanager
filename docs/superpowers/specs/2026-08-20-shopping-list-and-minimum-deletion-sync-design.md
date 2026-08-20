# Shopping List And Minimum Deletion Sync Design

Date: 2026-08-20

## Scope

This slice improves the local manual shopping session and prevents a deleted
Minimums rule from returning after guild sync.

## Shopping List Behavior

- The list is clipped to its modal and uses the existing reusable slim
  scrollbar, including mouse-wheel scrolling.
- The modal uses Blizzard's standard bottom-right hash resize grip, stays
  within readable minimum and practical maximum bounds, and expands the row
  width plus scroll viewport as the user enlarges it. Rows remain single-line
  so long labels cannot overlap the next item while the modal is compact.
- A row whose `Qty To Buy` is zero because another bank tab has enough stock
  displays `Restock from <Bank Tab>` instead of `x0`.
- Shift-clicking an item name while the Blizzard Auction House is visible puts
  the plain item name into the Buy search field. It does not automatically run
  the search or interact with the Auction House when it is closed.
- Checked rows keep their checked/strike-through state for the open list
  session and move below all unchecked rows. Relative order stays stable within
  the unchecked and checked groups.

## Minimum Deletion Sync Behavior

The current minimum snapshot merge preserves locally present rows that are
missing remotely. That protects newer local additions, but it also means an old
peer can reintroduce a rule another peer deleted.

Each database will therefore retain a small `minimumTombstones` map keyed by
`itemID|scope|tabName`. A tombstone records the deletion timestamp and enough
identity to compare it with a rule. Minimum snapshots carry the tombstones as a
record list.

Merge rules:

1. The newest state for a key wins, whether that state is a live rule or a
   tombstone.
2. An incoming or local tombstone suppresses an older or same-timestamp live
   rule.
3. A deliberate later add/edit clears an older tombstone for that key.
4. Missing tombstones from legacy peers do not remove local tombstones; the
   newer client replies with its fuller state without creating a reply loop.

## Acceptance Criteria

- Long manual shopping lists show a working scrollbar and remain clipped.
- The standard bottom-right resize grip enlarges the usable row width and
  viewport height, hiding the scrollbar when the expanded viewport fits every
  row.
- Zero-buy rows identify the bank tab to restock from.
- Shift-click fills, but does not submit, the visible Auction House Buy search.
- Checking a row moves it below every unchecked row without losing its checked
  state.
- Local removal creates and publishes a minimum tombstone.
- Sync cannot resurrect a rule older than a known deletion.
- A newer intentional rule can replace a tombstone.
- Focused tests and the complete Lua test gate pass.
