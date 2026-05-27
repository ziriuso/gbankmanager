# GBankManager Crafted-Quality and Ledger Reliability Design

## Goal

Fix the remaining live regressions in the current local checkpoint without broadening scope:

1. Restore correct crafted-quality icons on non-inventory surfaces for true two-rank items.
2. Make guild bank ledger scans and passive ledger refresh reliably import new log rows across reloads and addon sessions.
3. Replace the Exports `Excess Qty` text drill-in affordance with a clearer icon-only affordance aligned to the far right of the cell.

Sync planning is intentionally paused for this slice.

## Status

Design approved for spec write on 2026-05-27. Implementation has not started yet.

## Current Problems

### Crafted-quality icons

Live debug for item `241322` shows:

- bundled quality family is `2`
- bundled preferred and display atlas is `Interface-Crafting-ReagentQuality-2-Med`
- final chosen atlas is being rewritten to `Professions-ChatIcon-Quality-12-Tier2`

That means the current failure is not missing bundled data and not a live Blizzard reagent payload problem. The current shared resolver is overriding the bundled non-inventory display choice and forcing a newer atlas family the user does not want.

### Ledger scans and passive refresh

Live behavior shows:

- a clear-data ledger rebuild imports rows
- later manual scans can work inside that same addon session
- after reload or a later session, new rows can stop importing until data is cleared again

The current merge path relies on persisted source-window snapshots to infer deltas. That makes it fragile when the saved comparison window becomes stale or no longer matches the current server-returned visible log window. The current fingerprint indexes are also not stable transaction fingerprints; they are only tracking generated local `entryId` values. That leaves the ledger importer without a durable second dedupe guard.

Passive refresh currently sits on top of that same brittle merge path, so even when the timer fires, it can still conclude that nothing changed.

### Exports drill-in affordance

The current `Excess Qty` text label format like `19 view` is easy to miss and does not clearly read as an interactive drill-in. The underlying modal behavior is acceptable and should be preserved.

## Architecture

Keep the existing product surfaces and data model where possible:

- keep the current table views, ledger screens, summaries, and export modal
- keep bundled item-data as the primary source of crafted-quality family and display intent
- keep ledger storage append-only

Change only the narrow behavior causing the live regressions:

- crafted-quality final display-atlas selection rules
- ledger rescan and delta-dedup strategy
- exports cell presentation for `Excess Qty`

## Design

### 1. Crafted-quality display fix

For non-inventory display surfaces, bundled display intent becomes authoritative again.

Rules:

- If bundled item data provides `craftedQualityDisplayAtlas` or `craftedQualityPreferredAtlas`, use that as the display atlas for item-aware non-inventory rendering.
- Do not rewrite bundled true two-rank display atlases into the `Quality-12` chat-icon family.
- Only synthesize a display atlas from tier and family size when bundled display data is missing.
- Keep inventory behavior unchanged unless a focused failing test proves it also needs adjustment.

Expected result:

- items `241320`, `241322`, `241324`, and `243734` render with the intended two-rank family on `Minimums`, `Request Details`, request search, and `Exports`
- a bank scan should not change those icons afterward

### 2. Ledger scan and passive refresh reliability fix

Adopt the working parts of `GuildBankLedger`'s strategy while preserving GBankManager's existing UI and stored row shape.

#### Scan flow

- Manual scan and passive refresh use the same ledger rescan entrypoint.
- That entrypoint:
  - queries all accessible item logs
  - queries the fixed money-log slot `MAX_GUILDBANK_TABS + 1`
  - waits on `GUILDBANKLOG_UPDATE`
  - debounces on the last observed log update
  - reads all item and money logs in one pass

#### Merge and dedupe

- Introduce stable transaction fingerprints derived from transaction content, not local generated `entryId`.
- Persist those stable fingerprints as the real dedupe index for item and money logs.
- Treat source-window snapshots as a helper for ordering and delta detection, not as the only trust source.
- If the persisted source-window state is stale after reload, stable fingerprint dedupe still prevents duplicates while allowing true new rows to import.

#### Reload safety

- Add a small migration or normalization step that repairs old ledger fingerprint state from existing ledger rows when possible.
- If old source snapshot state is unusable, allow the importer to rebuild the active comparison window without requiring the user to clear all ledger data.

#### Passive refresh

- Keep passive refresh bank-open only.
- Reuse the exact same query and read path as manual ledger scans.
- Passive refresh should report only when new rows are actually added.

Expected result:

- new item-log and money-log rows continue importing after `/reload`
- passive refresh can discover new rows while the bank remains open
- repeated rescans remain append-only without duplicate rows

### 3. Exports drill-in affordance

Keep the current modal behavior and row click behavior, but improve the cell affordance.

Rules:

- keep the `Excess Qty` number visible in the table
- remove the literal `view` text
- when `Excess Qty > 0`, show a small icon-only drill-in affordance aligned to the far right side of the `Excess Qty` cell
- when `Excess Qty == 0`, show no drill-in icon

Behavior:

- clicking the row continues to open the stocked-elsewhere modal
- clicking the icon opens the same stocked-elsewhere modal

The modal should continue to show:

- total excess outside the assigned minimum tab
- per-tab breakdown of that excess

## Components

### Files expected to change

- `GBankManager/Domain/CraftedQuality.lua`
- `GBankManager/Domain/BankLedger.lua`
- `GBankManager/Features/GuildBankScanner.lua`
- `GBankManager/Features/GuildBankScannerEvents.lua`
- `GBankManager/Domain/Exports.lua`
- `GBankManager/UI/MainExportsController.lua`
- `GBankManager/UI/MainFrame.lua`
- shared table rendering if needed for the right-aligned icon affordance
- relevant specs and docs

### Likely unchanged

- request workflow rules
- inventory scan snapshot flow
- permissions dropdown behavior
- sync surfaces and messaging

## Testing Strategy

Follow TDD for each behavior change.

### Focused failing specs first

1. Crafted-quality
- non-inventory item-aware rendering should keep bundled true two-rank display atlases instead of rewriting them to `Quality-12`
- live regression cases should cover the known item IDs and the exact bundled-to-final atlas flow

2. Ledger merge and scan flow
- new rows should import after reload with persisted prior ledger state present
- stale source-window state should not block real new rows
- stable transaction fingerprints should prevent duplicates on repeated scans
- passive refresh should use the same shared rescan path as manual ledger scan

3. Exports affordance
- non-zero excess rows should expose an icon affordance flag or cell metadata
- zero-excess rows should not
- the modal should still show total outside assigned tab plus per-tab breakdown

### Verification commands

Run focused specs first, then:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

### Live verification after deploy

After `/reload`, verify:

1. Crafted-quality icons
- `Minimums`
- `Request Details`
- request search
- `Exports`
- item IDs `241320`, `241322`, `241324`, `243734`
- verify before and after `Scan Bank`

2. Ledger scan
- with new item-log and money-log rows visible in Blizzard UI, `Scan Bank` should import them
- `/reload`, then repeat with additional rows and confirm import still works

3. Passive refresh
- leave the guild bank open after a successful scan
- confirm new rows are eventually picked up without pressing `Scan Bank`

4. Exports drill-in
- non-zero `Excess Qty` rows show the right-aligned icon affordance
- clicking still opens the same stocked-elsewhere modal

## Risks and Mitigations

### Risk: changing crafted-quality selection breaks inventory

Mitigation:

- keep inventory behavior explicitly covered by focused specs
- scope the crafted-quality change to non-inventory display resolution rules unless inventory failures prove otherwise

### Risk: ledger dedupe change creates duplicates for existing users

Mitigation:

- add stable-fingerprint regression tests using repeated visible windows, shifted windows, and reload-like persisted state
- repair or rebuild saved dedupe state intentionally during migration

### Risk: table icon affordance becomes inconsistent with current shared row rendering

Mitigation:

- use the existing shared table icon support where possible
- keep row-click behavior as the primary interaction contract

## Out of Scope

- sync architecture and sync options tab
- ledger CSV timestamp normalization
- any request workflow changes beyond preserving existing behavior
- broader visual polish outside the Exports drill-in affordance

## Success Criteria

- non-inventory two-rank crafted items use the intended icon family live
- ledger scans keep importing new rows across reloads without requiring clear-data resets
- passive refresh detects new ledger rows while the bank remains open
- `Excess Qty` clearly reads as interactive through a right-aligned icon affordance
