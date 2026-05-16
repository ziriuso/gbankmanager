# GBankManager Item Catalog Refresh Resume Design

## Summary

Add explicit resumable execution to the maintainer item-catalog refresh pipeline so long-running local extraction can recover from timeouts, crashes, or interrupted maintainer sessions without restarting from item `1`.

The maintainer command surface should require one explicit execution mode:

- `-Fresh`
- `-Resume`

This applies to `Refresh-ItemCatalog.ps1` and the extraction phase it orchestrates for:

- `Retail`
- `PTR`
- `Beta`

The primary goal is to make full-catalog extraction trustworthy enough to finish a complete item database build on maintainer machines before returning to addon feature work.

## Goals

- Make long-running extraction resumable by target.
- Track extraction progress in a stable machine-readable state file.
- Preserve partial normalized extraction output across interrupted runs.
- Restart extraction from the last completed sequential `itemID`.
- Keep merge and generated-addon rebuild gated behind a fully completed extraction.
- Keep JSON reporting explicit enough for maintainers and future CI/debug tooling.

## Non-Goals

- Making merge or build partially resumable in this first slice.
- Running multiple concurrent refreshes for the same target against one shared state file.
- Hiding execution mode behind implicit auto-resume behavior.
- Replacing the existing manifest merge rules.

## Command Surface

### Required execution mode

`Refresh-ItemCatalog.ps1` must require exactly one of:

- `-Fresh`
- `-Resume`

If neither or both are supplied, the script must fail with a clear usage error.

### Canonical commands

Fresh Retail refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh
```

Resume Retail refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Resume
```

Fresh PTR refresh with custom root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target PTR -WoWRoot "D:\World of Warcraft PTR" -Fresh
```

Resume Beta refresh with custom root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Beta -WoWRoot "D:\World of Warcraft Beta" -Resume
```

## State Model

### Progress file location

Progress must be tracked per target under:

- `tools/catalog/runtime/state/item-catalog-refresh-retail.json`
- `tools/catalog/runtime/state/item-catalog-refresh-ptr.json`
- `tools/catalog/runtime/state/item-catalog-refresh-beta.json`

The exact filename format should be deterministic from the resolved target name.

### Progress file fields

Required fields:

- `target`
- `mode`
- `status`
- `phase`
- `build`
- `locale`
- `wowRoot`
- `clientDirectory`
- `outputPath`
- `manifestPath`
- `outputLuaPath`
- `startedAt`
- `updatedAt`
- `completedAt`
- `resumeSupported`
- `rawRowCountSeen`
- `normalizedCountWritten`
- `lastProcessedItemID`
- `lastProcessedIndex`
- `highestSeenItemID`
- `failureClass`
- `failureMessage`

### Status values

Recommended values:

- `running`
- `failed`
- `completed`

### Phase values

Recommended values:

- `extraction`
- `merge`
- `build`

In this slice, resumability only needs to apply to `extraction`. Merge and build should still restart from the beginning of their own phase once extraction is complete.

## Extraction Resume Behavior

### Ordering

Extraction must process normalized rows in ascending `itemID` order.

This ordering becomes the resume contract.

### Fresh mode

`-Fresh` must:

- clear any existing progress file for the selected target
- clear any target-scoped partial normalized extraction output
- initialize a new progress file immediately
- start from the first extracted row

### Resume mode

`-Resume` must:

- require an existing progress file for the selected target
- require that the saved state is resumable and in `failed` or `running` extraction state
- restart after `lastProcessedItemID`
- continue appending to the partial normalized extraction output instead of rewriting it from scratch

If no valid resume state exists, the script must fail with a clear message telling the maintainer to rerun with `-Fresh`.

### Incremental writes

Extraction output should be written incrementally enough that interrupted runs keep useful progress.

The extractor must:

- update progress after a bounded batch size instead of only at the end
- write partial normalized rows often enough that a timeout loses only a small tail of work

The exact batch size can be implementation-defined, but it must be deterministic and documented.

## Phase Boundaries

### Extraction

Extraction is the only resumable phase in this slice.

It is considered complete only when:

- all sequential rows have been processed
- the extracted output document has a valid final item count
- the progress file status can move to the next phase

### Merge

Merge must only run after extraction completes cleanly.

If merge fails:

- the refresh should report `failureClass = "merge"`
- the extraction progress file should remain available for diagnostic use
- the next `-Resume` run may skip extraction only if the extracted output is already finalized and the implementation marks that state explicitly

### Build

Build must only run after a successful merge.

If build fails:

- the refresh should report `failureClass = "build"`
- the merge output should remain intact for rerun/debug

## JSON Reporting Contract

The top-level `Refresh-ItemCatalog.ps1 -Json` result should add:

- `mode`
- `progressPath`
- `resumeSupported`
- `phase`
- `lastProcessedItemID`
- `lastProcessedIndex`
- `highestSeenItemID`
- `normalizedCountWritten`

Failure output should preserve the existing categorized `failureClass` reporting and add progress information when available.

## Failure Handling

### Fresh-mode failures

If a fresh extraction fails midway:

- keep the progress file
- keep the partial normalized extraction output
- report that the maintainer may rerun with `-Resume`

### Resume-mode failures

If a resumed extraction fails again:

- update the same progress file
- preserve the latest completed item boundary
- keep the failure resumable unless corruption is detected

### Corruption handling

If the progress file or partial output is missing, unreadable, or inconsistent:

- `-Resume` must fail explicitly
- the error message must recommend `-Fresh`

## Documentation Requirements

Update:

- `tools/catalog/README.md`
- `README.md`
- `docs/minimum-item-catalog-strategy.md`

The docs must explain:

- when to use `-Fresh`
- when to use `-Resume`
- where progress files are stored
- what pass/fail means for resumable extraction
- that the full item database path is now intended to survive long maintainer runs

## Testing Requirements

Add focused coverage for:

- invalid mode combinations
- fresh mode clearing previous state
- resume mode requiring existing valid state
- resume mode restarting after `lastProcessedItemID`
- progress file updates during extraction fixtures
- categorized failures preserving resumable progress

Full regression remains:

- `.\tools\lua\lua.exe .\tests\run_all.lua`

