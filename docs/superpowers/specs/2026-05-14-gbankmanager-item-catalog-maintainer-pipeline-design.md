# GBankManager Item Catalog Maintainer Pipeline Design

## Summary

Build a maintainer-only item catalog pipeline that generates the bundled `GBankManager_ItemData` addon from a local World of Warcraft client install instead of relying on Blizzard web item APIs or brittle public third-party endpoints.

The pipeline should support explicit client targets:

- `Retail`
- `PTR`
- `Beta`

Each target should be refreshable from a maintainer machine by pointing the tooling at the matching WoW install, extracting current DB2 item data plus hotfix data, normalizing the results into the checked-in manifest, and rebuilding the load-on-demand addon dataset used by:

- Minimums add-item search
- Requests item search

Players must never need to fetch, build, or refresh this catalog themselves.

## Goals

- Keep item search fully offline at addon runtime.
- Make maintainer refreshes branch-aware for current and upcoming releases.
- Generate a compact derived dataset that stores only the fields the addon needs now:
  - `itemID`
  - `name`
  - `quality`
  - `qualityName`
- Replace Blizzard web API enrichment as the primary refresh path.
- Avoid dependence on fragile public AH or third-party item metadata endpoints.
- Preserve runtime-learned item discoveries as a secondary maintainer input, not the primary source of truth.

## Non-Goals

- Shipping raw DB2 dumps inside the addon.
- Requiring end users to install external tools or generate data.
- Building a complete universal item metadata warehouse on the first pass.
- Solving every future item field now, such as icons, classes, or auction pricing history.
- Treating third-party public datasets as the primary canonical source.

## Constraints

- The addon must continue to ship a separate load-on-demand item data addon:
  - `GBankManager_ItemData/GBankManager_ItemData.toc`
  - `GBankManager_ItemData/Data.lua`
- The main addon must continue to lazy-load bundled item data only when needed.
- The maintainer workflow must run on Windows PowerShell.
- The workflow must support explicit target selection for `Retail`, `PTR`, and `Beta`.
- The workflow must allow explicit path override for non-standard install locations.
- The workflow must be hotfix-aware by using data from the selected local client install.
- Documentation must be kept current alongside the tooling.

## Data Source Strategy

### Primary source

Use a maintainer’s local WoW client install for the selected target as the primary source of current item data.

This source provides:

- branch-correct DB2 data
- matching local hotfix cache data
- a workflow that works for live and pre-release client builds

### Supporting tooling

The implementation should rely on open-source client data tooling and definitions instead of custom reverse engineering from scratch.

Expected tool classes:

- client/CDN extraction tooling
- DB2 schema definitions
- normalization scripts that convert extracted data into the addon manifest shape

### Secondary sources

The following should be treated as secondary and optional:

- runtime-learned item discoveries from addon usage
- manual maintainer seed rows
- future importers for external datasets

These may add or preserve rows, but they should not replace the local-client extraction path as the recommended refresh method.

### Deprecated primary paths

The following should no longer be documented as the recommended primary path:

- Blizzard web API enrichment
- credential-free public AH discovery endpoints

They may remain in the repo temporarily as fallback or legacy tooling, but the maintainer docs should clearly demote them.

## Maintainer Workflow

### Normal refresh flow

The top-level maintainer command should look like:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail
```

Equivalent examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target PTR
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Beta
```

Optional explicit path override:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Beta -WoWRoot "D:\World of Warcraft Beta"
```

### Refresh phases

The refresh flow should perform these phases in order:

1. Resolve target install and build context.
2. Validate required client data paths exist.
3. Extract raw item data from the selected client.
4. Merge hotfix data from the selected client.
5. Normalize extracted rows into the maintainer manifest shape.
6. Merge normalized rows into the checked-in manifest.
7. Rebuild `GBankManager_ItemData/Data.lua`.
8. Emit a clear summary of:
   - target
   - detected build
   - rows added
   - rows updated
   - unresolved rows
   - output files written

## Target Model

### Named targets

The tooling must support:

- `Retail`
- `PTR`
- `Beta`

Each named target resolves to:

- install root
- product identifier
- locale
- hotfix cache location
- working extraction directory

### Override rules

All scripts should support override parameters where relevant:

- `-Target`
- `-WoWRoot`
- `-Locale`

Normal maintainers should only need `-Target`.

Advanced cases such as alternate disks, multiple installs, or one-off test clients should use `-WoWRoot`.

## Manifest Model

The checked-in manifest remains the source of truth for the generated addon dataset.

Recommended row shape:

- `itemID`
- `name`
- `quality`
- `qualityName`
- `status`
- `source`
- `target`
- `build`
- `locale`
- `lastVerifiedAt`

### Status values

Recommended status values:

- `confirmed`
- `learned`
- `unresolved`
- `deprecated`

Definitions:

- `confirmed`: extracted and normalized successfully from a maintainer refresh
- `learned`: discovered during runtime or manual import but not yet refreshed from a selected client target
- `unresolved`: known row missing required metadata
- `deprecated`: intentionally retained historical row that is no longer active in the latest selected dataset

## Merge Rules

The merge phase should be additive and stable rather than destructive.

Rules:

- Keep existing confirmed rows unless replaced by fresher data from the selected target.
- Add newly discovered item IDs from extraction.
- Preserve learned rows until a confirmed row supersedes them.
- Do not silently delete missing rows on the first absence from one target refresh.
- Allow future target differences without destabilizing the manifest.

Recommended practical behavior:

- rows missing from a refresh should be candidates for `deprecated`, not immediate deletion
- refreshed rows should stamp:
  - `target`
  - `build`
  - `lastVerifiedAt`

## Generated Addon Output

The generated addon output remains:

- `GBankManager_ItemData/GBankManager_ItemData.toc`
- `GBankManager_ItemData/Data.lua`

The generated data file should remain compact and derived, not a raw database export.

The first-pass payload should include only:

- `itemID`
- `name`
- `quality`
- `qualityName`

If later search performance requires it, the build phase may also generate:

- normalized search keys
- prefix buckets
- packed name structures

That optimization should remain an internal generation detail and must not change addon behavior.

## Runtime-Learned Import Path

The maintainer system should also support importing runtime-learned item discoveries from addon data.

This import path is useful for:

- newly seen PTR or Beta items
- guild-specific request item discoveries
- minimums additions found during real testing

This import path should:

- merge learned rows into the manifest
- never overwrite fresher confirmed metadata
- mark imported rows as `learned`

## Script Surface

### New scripts

- `tools/catalog/Resolve-WoWTarget.ps1`
  - shared target resolution helper
- `tools/catalog/Extract-ItemDb2.ps1`
  - extracts raw item rows from the selected local client
- `tools/catalog/Merge-ExtractedItemCatalog.ps1`
  - merges normalized extracted rows into the manifest
- `tools/catalog/Refresh-ItemCatalog.ps1`
  - top-level maintainer orchestration command
- `tools/catalog/Import-LearnedItemCatalog.ps1`
  - imports runtime-learned catalog rows from addon exports

### Existing scripts retained

- `tools/catalog/Build-ItemDataAddon.ps1`
- `tools/catalog/Export-StaticItemCatalog.ps1`

### Existing scripts demoted

- `tools/catalog/Update-BlizzardItemMetadata.ps1`
- `tools/catalog/Update-CredentialFreeItemCatalog.ps1`

They may remain temporarily, but should be documented as fallback or legacy tooling instead of the recommended refresh path.

## Pass/Fail Contract

### Refresh passes when

- the selected target resolves successfully
- the selected WoW install exists
- required client data files are found
- extraction succeeds
- hotfix merge succeeds
- normalized rows contain required fields
- manifest merge succeeds
- `GBankManager_ItemData/Data.lua` is generated successfully

### Refresh fails when

- the target is unknown
- the WoW root does not exist
- required DB2 or hotfix files are missing
- extraction tooling fails
- schema drift prevents normalization
- generated output cannot be written

### Failure reporting

The top-level script should classify failures into one of:

- environment failure
- extraction failure
- schema failure
- merge failure
- generation failure

The failure output should be actionable and should name the failing target and path.

## Testing Strategy

### Local automated coverage

Add focused tests for:

- target resolution
- manifest merge rules
- normalization of extracted rows into the minimal addon schema
- generated data shape for `GBankManager_ItemData`

These tests should stay in the existing local Lua/PowerShell-oriented project harness where practical, with small focused ownership-based coverage rather than one giant integration test.

### Maintainer validation

Document a manual maintainer smoke pass for each target:

1. refresh target
2. rebuild item data addon
3. confirm generated dataset contains known recent items
4. run addon test suite
5. optionally deploy and live-test Minimums and Requests search

## Documentation Updates Required

Update:

- `tools/catalog/README.md`
- `docs/minimum-item-catalog-strategy.md`
- project `README.md` if command surface changes
- any maintainer or manual test docs that reference the old primary path

Documentation must explain:

- recommended refresh path
- target selection
- required local WoW installs
- custom install path overrides
- pass/fail expectations
- legacy fallback scripts and their reduced role

## Implementation Slices

### Slice 1

- add target resolution helper
- add top-level refresh orchestration shell
- update docs to reflect the new primary design

### Slice 2

- implement local extraction and normalization for the selected target
- merge into manifest
- rebuild `GBankManager_ItemData`

### Slice 3

- add runtime-learned import path
- add focused test coverage for target resolution and merge behavior
- tighten failure reporting and maintainer validation docs

## Risks

- local client data formats may shift between builds
- hotfix cache layout may differ between target branches
- target path assumptions may differ across maintainer machines
- extraction toolchain integration may be the most brittle part of the workflow

The design mitigates this by:

- keeping targets explicit
- keeping fields minimal
- isolating target resolution, extraction, merge, and generation into separate scripts
- documenting failure classes clearly

## Recommendation

Proceed with the local-client, branch-selectable maintainer pipeline as the canonical refresh workflow for the bundled item catalog.

This is the most reliable fit for:

- current Retail support
- PTR and Beta prep
- no end-user intervention
- Ludwig-style static bundled search behavior

