# GBankManager Minimums Portability And History Sync Design

Date: 2026-06-02

## Scope

This design covers exactly two backlog items from GitHub project `GuildBankManager`:

1. `Add portable Minimums export and import`
2. `Design History sync propagation`

The implementation goal is:

- add a portable Minimums export/import workflow
- show imported Minimums in a review UI before apply
- allow last-minute edits before acceptance
- require local tab reassignment when imported tabs do not exist locally
- keep the `History` tab coherent across clients by reconstructing equivalent history rows from accepted synced changes

This design does not add a raw history-message transport. It also does not introduce new `History` categories for events that the addon does not already track in the `History` tab.

## Current Constraints

- Minimums are persisted in `db.minimums`.
- Minimums editing already has a draft-and-save workflow in `GBankManager/UI/MainMinimumsController.lua`.
- Minimums persistence and audit logging already flow through `GBankManager/UI/MinimumsView.lua`.
- History rows are rendered from `db.auditLog` through `GBankManager/UI/HistoryView.lua`.
- Request sync already reconstructs equivalent request audit rows locally in `GBankManager/Sync/SyncEvents.lua`.
- Sync source of truth remains accepted addon sync messages, not duplicated audit payloads.
- The current baseline full suite is not green before this feature slice because `tests/spec/item_catalog_target_spec.lua` is already failing with `fixture writer should open the target file`.

## Goals

### Minimums portability

- Export Minimums in a portable format that can be pasted between clients or guild contexts.
- Preserve stable Minimums identity:
  - `itemID`
  - `itemName`
  - `scope`
  - `tabName`
  - `quantity`
  - `enabled`
  - crafted-quality identity fields already used by Minimums and Requests
- Keep import guild targeting explicit at apply time by always importing into the active local guild instead of hard-binding to the source guild.
- Let the user review and edit imported rows before any save occurs.

### History tab sync

- Keep `History` tab entries coherent across clients after accepted sync changes.
- Reconstruct equivalent local history rows from accepted synced changes.
- Only reconstruct entry types the addon already uses in `db.auditLog`.
- Do not add separate sync-only history event types.

## Non-Goals

- No file picker or disk-based import/export workflow in this slice.
- No CSV import in this slice.
- No raw `HISTORY_*` addon sync transport.
- No new ledger-specific history event family if the current `History` tab does not already track it.
- No replay of every remote audit row exactly as-authored on the source client.

## Minimums Export Format

The first portable format is versioned JSON.

Top-level shape:

```json
{
  "schema": "gbankmanager.minimums",
  "version": 1,
  "exportedAt": 1760000000,
  "sourceGuild": "Example Guild",
  "rules": [
    {
      "itemID": 12345,
      "itemName": "Example Item",
      "scope": "TAB",
      "tabName": "Flasks",
      "quantity": 20,
      "enabled": true,
      "itemLink": "|cff...",
      "itemString": "item:12345:::::::::",
      "craftedQuality": 2,
      "craftedQualityIcon": "Professions-Icon-Quality-12-Tier2-Inv",
      "craftedQualityDisplayAtlas": "Professions-Icon-Quality-12-Tier2-Inv",
      "craftedQualityPreferredAtlas": "Professions-Icon-Quality-12-Tier2-Inv",
      "craftedQualityMax": 2
    }
  ]
}
```

Format rules:

- `schema` and `version` are required.
- `rules` must be an array.
- `itemID`, `itemName`, `scope`, `quantity`, and `enabled` are required for each row.
- `tabName` is required when `scope == "TAB"`.
- source guild metadata is informational only and must not block import into a different guild.

## Minimums Import UX

The chosen UX is `Paste -> review table -> edit -> confirm`.

### Entry point

- Add `Export` and `Import` actions to the Minimums action area.
- Reuse the addon's existing modal style instead of adding a new shell pattern.

### Import flow

1. User opens `Import Minimums`.
2. User pastes JSON payload into a multiline edit box.
3. User clicks `Preview Import`.
4. Addon parses the payload into staged imported rows.
5. Addon shows a review UI with one row per imported Minimum.
6. User can edit each staged row before final acceptance.
7. User clicks `Apply Import` to merge the accepted rows into the existing Minimums draft workflow.
8. User uses the normal `Save All` behavior to commit the imported draft rows.

### Review UI requirements

- Show imported rows in a table-like review surface.
- Each row must surface:
  - item
  - tier icon if available
  - imported tab
  - editable local tab
  - restock/enabled state
  - minimum quantity
  - row status
- If the imported `TAB` name does not match a locally available tab, mark the row clearly and require reassignment before apply.
- If a row targets a global or non-tab scope, that rule should not require tab reassignment.
- Allow the user to adjust:
  - local bank tab
  - minimum quantity
  - enabled/restock state
- Allow the user to drop a row from the staged import before apply.

### Row validation

Each staged row should carry a review status:

- `ready`
- `needs_tab`
- `invalid`
- `duplicate_candidate`

`Apply Import` stays disabled while any required row is still `needs_tab` or `invalid`.

### Apply behavior

- Applying the review does not write directly into `db.minimums`.
- Instead it populates the same draft/staged Minimums workflow used by normal Minimums editing.
- This keeps import behavior aligned with:
  - staged change badges
  - `Revert All`
  - `Save All`
  - existing validation rules

## Import Merge Rules

- Imported rows merge into the current active guild only.
- Identity key stays aligned with the existing Minimums rule identity:
  - `itemID`
  - `scope`
  - `tabName`
- If an imported row matches an existing rule after any user edits, stage it as an update.
- If it does not match, stage it as a new row.
- Rows removed from the review UI are ignored entirely.
- Import does not auto-delete existing local Minimums that are absent from the payload in this first slice.

This means v1 import is additive/update-oriented, not full replace.

## History Sync Design

### Principle

The `History` tab should converge by reconstructing equivalent local audit rows from accepted synced changes.

The addon should not:

- sync raw history rows
- sync a second audit log transport
- create special `History` rows for receipt of a sync envelope

### Existing precedent

Requests already do this correctly enough:

- accepted remote request create or update messages mutate local domain state
- the sync layer appends equivalent request audit rows locally
- the `History` tab then renders those rows from `db.auditLog`

This design extends that same model.

### Included reconstruction scope

For this slice, reconstruct equivalent history rows for:

- remote request changes already handled today
- remote Minimums snapshot changes

Do not add new reconstructed history rows for ledger deltas in this slice, because the user explicitly does not want us to begin tracking snapshot or ledger audit history beyond what the tab already tracks today.

### Minimums snapshot reconstruction

When a remote `MINIMUMS_SNAPSHOT` is accepted:

1. Clone the pre-apply local Minimums state.
2. Apply the remote snapshot.
3. Compare previous and next Minimums collections by stable rule key.
4. Append equivalent existing history rows for:
  - created rule
  - updated quantity
  - enabled -> disabled
  - disabled -> enabled
  - removed rule

Audit row mapping:

- new rule -> `MINIMUM_CREATED`
- changed quantity or edited tab-scoped identity -> `MINIMUM_UPDATED`
- enabled flip to true -> `MINIMUM_ENABLED`
- enabled flip to false -> `MINIMUM_DISABLED`
- removed prior rule -> `MINIMUM_REMOVED`

Actor and timestamp rules:

- use remote `actorContext.name` when available
- fall back to remote `actorContext.characterKey`
- use message `updatedAt` or a per-row updated timestamp if present

### Deduping

Reconstructed Minimums history must be deduped enough to avoid repeated rows when:

- the same remote snapshot arrives again
- the accepted snapshot produces no state change

No-change accepted snapshots should not append new `db.auditLog` rows.

## Components To Add Or Extend

### Domain or helper layer

Add a dedicated portable Minimums codec/helper responsible for:

- export serialization
- import parsing
- row normalization
- review-stage validation

This should stay separate from the export text builders in `GBankManager/Domain/Exports.lua`, because Minimums portability is configuration transfer, not procurement output.

### UI

Extend `GBankManager/UI/MainMinimumsController.lua` with:

- export action entry point
- import modal
- preview parsing action
- review-state storage
- editable staged imported rows
- apply-to-draft behavior

### Minimums persistence

Reuse `GBankManager/UI/MinimumsView.lua` audit and upsert helpers instead of introducing a second persistence path.

### Sync

Extend `GBankManager/Sync/SyncEvents.lua` so accepted remote Minimums snapshots reconstruct equivalent Minimums history rows after the state mutation is accepted.

## Testing Strategy

Follow TDD.

Add focused failing specs first for:

1. Minimums export serializes stable portable JSON.
2. Minimums import parser rejects invalid schema or malformed rows.
3. Imported `TAB` rows with missing local tabs are flagged for reassignment.
4. Import review edits can override the imported tab before apply.
5. Applying reviewed import stages Minimums changes without directly committing them.
6. Saving imported draft rows flows through existing Minimums audit behavior.
7. Accepted remote `MINIMUMS_SNAPSHOT` reconstructs equivalent `MINIMUM_*` history rows.
8. Replayed or no-change snapshots do not append duplicate history rows.

Likely spec files:

- new portable Minimums domain spec
- `tests/spec/ui_minimums_spec.lua`
- `tests/spec/sync_spec.lua`
- possibly `tests/spec/history_spec.lua`

## Documentation Updates

Update after implementation:

- `README.md`
- `docs/testing.md`
- `docs/manual-test-checklist.md`
- `docs/superpowers/handoffs/latest-handoff.md`

Document:

- Minimums export/import workflow
- import review and tab reassignment behavior
- History-tab convergence from accepted synced Minimums changes

## Risks

- Reusing the existing staged Minimums UI cleanly may require careful separation between normal manual drafts and imported drafts.
- Tab reassignment UX can become cramped if we try to reuse row controls too literally.
- Minimum identity changes involving tab reassignment can accidentally look like remove+create instead of update if the diff rules are sloppy.
- Remote Minimums snapshot reconstruction must avoid double-appending history rows during no-change or replay cases.

## Recommended Implementation Order

1. Add portable Minimums codec and failing unit tests.
2. Add review-stage import model and failing UI/controller tests.
3. Wire import review apply into existing Minimums draft flow.
4. Add export action and payload generation.
5. Add failing sync-history tests for accepted remote Minimums snapshots.
6. Implement reconstructed Minimums history append logic in sync.
7. Run focused specs.
8. Run full suite and note the pre-existing unrelated baseline failure if it remains.
