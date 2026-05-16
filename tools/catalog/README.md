# Item Catalog Tooling

## Purpose

These scripts maintain the bundled addon item catalog used by:

- Minimums add-item search
- Requests item search

## Recommended Maintainer Path

The recommended primary refresh flow is now local-client extraction from a selected WoW install target.

Supported targets:

- `Retail`
- `PTR`
- `Beta`

Canonical examples:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target PTR -Fresh
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Beta -Fresh
```

Default catalog profile:

- `ProcurementCurrentExpansion`
  - current expansion only
  - AH-style procurement categories only:
    - `Consumables`
    - `Containers`
    - `Gems`
    - `Reagents`
    - `Item Enhancements`
  - implemented from Blizzard item class and subclass metadata when available in local extraction data
  - keeps the shipped addon search payload small enough for responsive live WoW search

Optional full refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh -CatalogProfile Full
```

Optional custom install root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Beta -WoWRoot "D:\World of Warcraft Beta" -Fresh
```

`Refresh-ItemCatalog.ps1` is now the canonical maintainer entrypoint. It requires exactly one execution mode:

- `-Fresh`
- `-Resume`

`-Fresh` clears target-scoped progress state and restarts extraction from the beginning.

`-Resume` continues from the last completed sequential item boundary during extraction, and restarts merge or build from the last safe completed phase boundary when extraction already finished.

In the current phase it resolves the selected target, validates the install layout, runs local extraction and normalization when the selected target is extractable, merges normalized rows into the checked-in manifest, and rebuilds the generated item-data addon from that merged manifest. `Resolve-WoWTarget.ps1` remains the shared helper that maps named targets to install roots, client directories, product codes, and locale settings for the rest of the maintainer pipeline.

Use `Import-LearnedItemCatalog.ps1` only as a secondary maintainer path when addon runtime discoveries should be preserved before the next confirmed refresh, especially during PTR or Beta testing.

## Commands

Generate Lua from an existing manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Build-ItemDataAddon.ps1
```

`Build-ItemDataAddon.ps1` now exports only active non-deprecated manifest rows into the shipped addon data, so manifest history can be retained for maintainers without bloating live search memory.

Write the generated addon data to a custom path:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Build-ItemDataAddon.ps1 -OutputLuaPath .\tests\tmp\item-data.lua
```

Resolve a named target or explicit install override without running extraction yet:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Resolve-WoWTarget.ps1 -Target Retail
```

Validate a target end-to-end and emit a readiness summary. In Phase 5, extractable targets continue through local ItemSparse extraction, normalization, manifest merge, and generated addon rebuild:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh -Json
```

Resume an interrupted target refresh from saved progress:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Resume
```

Import runtime-learned rows from an addon export into the checked-in manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath .\tools\catalog\runtime\item-catalog-learned.json
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath .\tools\catalog\runtime\item-catalog-learned.json -OutputPath .\tests\tmp\item-catalog-imported.json
```

Maintainer smoke recipe:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh
.\tools\lua\lua.exe .\tests\run_all.lua
```

PTR or Beta smoke recipe with learned import before the next confirmed refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath .\tools\catalog\runtime\item-catalog-learned.json
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target PTR -WoWRoot "D:\World of Warcraft PTR" -Fresh
.\tools\lua\lua.exe .\tests\run_all.lua
```

## Progress And Resume

Progress files are target-scoped and stored under `tools/catalog/runtime/state/`.

Current target-scoped examples:

- `tools/catalog/runtime/state/item-catalog-refresh-retail.json`
- `tools/catalog/runtime/state/item-catalog-refresh-ptr.json`
- `tools/catalog/runtime/state/item-catalog-refresh-beta.json`

Each target also keeps a partial normalized rows file beside that progress file during extraction.

Use `-Fresh` when:

- you want to restart a target refresh from scratch
- you suspect prior progress state is stale or corrupt
- the client build changed and you want a clean pass

Use `-Resume` when:

- a previous refresh was interrupted
- the progress file for that target exists
- you want extraction to continue after the last completed sequential `itemID`
- you want merge or generated addon rebuild to restart from the last completed safe phase boundary

If `-Resume` is requested without a valid progress file, the command fails clearly and tells you to rerun with `-Fresh`.

Current learned import contract:

- top-level JSON object with an `items` array
- optional top-level metadata:
  - `source`
  - `exportedAt`
  - `target`
  - `build`
  - `locale`
- each `items` row must include:
  - `itemID`
  - `name`
- each `items` row may include:
  - `quality`
  - `qualityName`
  - `craftedQuality`
  - `craftedQualityIcon`
  - `source`
  - `target`
  - `build`
  - `locale`

Example learned import payload:

```json
{
  "source": "addon_saved_search_catalog",
  "exportedAt": "2026-05-14T19:30:00.000Z",
  "target": "PTR",
  "build": "11.2.8.70000",
  "locale": "en_US",
  "items": [
    {
      "itemID": 555555,
      "name": "PTR Test Potion",
      "quality": 2,
      "qualityName": "Uncommon",
      "craftedQuality": 4,
      "craftedQualityIcon": "Professions-ChatIcon-Quality-Tier4"
    }
  ]
}
```

Crafted-quality contract:

- `quality` and `qualityName` remain the generic Blizzard item-rarity fields
- `craftedQuality` is the addon-meaningful profession tier field when an item has a crafting tier
- `craftedQualityIcon` stores the atlas string used by the addon UI for that tier
- non-crafted rows should keep both `craftedQuality` and `craftedQualityIcon` as `null` in the manifest and effectively `nil` in generated Lua
- when a modern crafted duplicate-name group does not expose a direct tier field through the local client extraction path, the maintainer pipeline derives `craftedQuality` by sorting that duplicate-name group by item level and assigning ascending tiers within the group
- the current derived-tier heuristic is intentionally narrow: same exact name, same expansion and rarity, 2-5 rows, unique positive item levels, compact item-ID range, and a modern expansion floor so legacy duplicate-name items do not get false crafted tiers

Current learned import behavior:

- adds new learned rows to the manifest
- refreshes existing non-confirmed rows with the imported learned metadata
- never overwrites existing confirmed rows
- allows a later `Refresh-ItemCatalog.ps1` confirmed extraction to supersede those learned rows

Current `-Json` contract:

- `status`
  - `ready` when validation succeeds and the shell is ready for the future build phase
  - `failed` when validation stops with a categorized failure
- `failureClass`
  - `usage` for invalid `-Fresh` / `-Resume` combinations or missing resume state
  - `environment` for invalid targets, missing installs, or missing required client paths
  - `extraction` when local extraction fails after validation
  - `merge` when manifest merge fails after extraction
  - `build` when the generated addon rebuild fails after merge
- `target` and `requestedTarget`
  - `requestedTarget` preserves what the maintainer asked for
  - `target` is populated only after successful target resolution
- stable location and target fields
  - `wowRoot`
  - `clientDirectory`
  - `dataDirectory`
  - `localeDirectory`
  - `product`
  - `locale`
  - `installRootSource`
- stable reporting fields
  - `message`
  - `mode`
  - `progressPath`
  - `partialRowsPath`
  - `phase`
  - `phaseStatus`
  - `phaseStartedAt`
  - `phaseCompletedAt`
  - `completedPhases`
  - `phaseProgress`
  - `resumeSupported`
  - `requiredPaths`
  - `missingPaths`
  - `checks`
  - `extractionImplemented`
  - `rawRowCount`
  - `rawRowCountSeen`
  - `normalizedCount`
  - `normalizedCountWritten`
  - `normalizedRowsPath`
  - `build`
  - `lastVerifiedAt`
  - `lastProcessedItemID`
  - `lastProcessedIndex`
  - `highestSeenItemID`
  - `manifestPath`
  - `mergedItemCount`
  - `addedCount`
  - `refreshedCount`
  - `retainedCount`
  - `deprecatedCount`
  - `buildSucceeded`
  - `outputLuaPath`
  - `generatedItemCount`
  - `generatedTokenCount`
  - `nextStep`
- `requiredPaths`, `missingPaths`, and `checks`
  - intentionally remain array-shaped even when empty so downstream tooling can rely on a stable contract
- current success behavior
  - exit code `0`
  - `status = "ready"`
  - `failureClass = null`
  - `nextStep = "addon-rebuilt"` when refresh completes extraction, merge, and build
  - `phase = "build"` and `phaseStatus = "completed"` when the full pipeline finishes
  - `buildSucceeded = true` after a successful generated addon rebuild
  - extractable targets also include `build`, `rawRowCount`, `rawRowCountSeen`, `normalizedCount`, `normalizedCountWritten`, `normalizedRowsPath`, `lastVerifiedAt`, `lastProcessedItemID`, `lastProcessedIndex`, `highestSeenItemID`, `manifestPath`, merge counters, `outputLuaPath`, and `generatedItemCount`
- current failure behavior
  - nonzero exit code
  - `status = "failed"`
  - actionable usage, environment, extraction, merge, or build message

## Runtime Search Expectations

- `GBankManager_ItemData` is now a required startup dependency of `GBankManager`, not an optional load-on-demand helper.
- The generated item data now ships as chunked indexed search payloads plus a readiness marker.
- The companion addon also publishes an explicit global payload bridge so the main addon can hydrate the bundled search dataset even when addon-local namespaces are not shared in the live client.
- Name-search consumers should only use the bundled token index when the payload reports fully ready.
- If the bundled payload is unavailable at runtime, addon search should report the unavailable state clearly instead of silently degrading to sparse local-only name results.
- Known maintained query families that should work after a successful refresh include:
  - `flask of`
  - `flask of the sha`
  - `flask sun`
  - `thalassian phoenix oil`

Legacy fallback: attempt a credential-free refresh from public upstreams, then regenerate the load-on-demand item addon:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Update-CredentialFreeItemCatalog.ps1 -Region us
```

Legacy fallback: enrich manifest rows with Blizzard item metadata, then optionally rebuild the load-on-demand item addon:

```powershell
$env:GBM_BNET_CLIENT_ID = "your-client-id"
$env:GBM_BNET_CLIENT_SECRET = "your-client-secret"
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Update-BlizzardItemMetadata.ps1 -BuildAddonData
```

## Output

The generated catalog now ships in a separate load-on-demand addon:

- `GBankManager_ItemData/GBankManager_ItemData.toc`
- `GBankManager_ItemData/Data.lua`

`Data.lua` is emitted in deterministic chunked append blocks so full Retail-sized rebuilds remain loadable by the Lua 5.1 addon test/runtime without changing the addon-side `ns.modules.staticItemCatalog` contract.

## Current Refresh Strategy

Primary:

- local-client extraction from the selected named target
- branch-aware maintenance for `Retail`, `PTR`, and `Beta`
- hotfix-aware data from the selected install
- a single top-level `Refresh-ItemCatalog.ps1` entrypoint for target resolution, extraction, merge, and generated addon rebuild

Phase 3 extraction details:

- the maintainer-owned headless extractor uses a local portable `wow.export` runtime under `tools/catalog/runtime/wow.export/`
- extraction opens the shared WoW install root with the selected product code, not the `_retail_` or `_ptr_` client folder alone
- normalized rows come from the effective `db2.ItemSparse.getAllRows()` view for that selected build, which is the hotfix-aware row set exposed by `wow.export`
- fixture-driven extraction tests still cover normalization without depending on a live client

Current phase behavior:

- validates the selected install root, client directory, and usable CASC data layout for the selected target
- returns a structured `environment` failure when the target or required paths are invalid
- runs extraction and normalization when the selected target is extractable
- merges refreshed rows into the local maintainer manifest with additive retention rules
- rebuilds `GBankManager_ItemData/Data.lua` from the merged manifest
- supports optional learned-row import as a secondary maintainer path before the next confirmed refresh
- exits `0` only for `ready`, and nonzero for `failed`

Validation notes from this machine on May 14, 2026:

- `Retail` resolves and refreshes successfully against `C:\Gaming\World of Warcraft`
- `PTR` and `Beta` target resolution were validated through explicit `-WoWRoot` overrides because those installs are not present locally

Fallback only:

- Blizzard web item metadata enrichment
- credential-free public upstream discovery

These older scripts remain in the repo temporarily, but they are no longer the recommended primary refresh path.

Local maintainer assets:

- `tools/catalog/runtime/item-catalog-input.json`
  - full maintainer manifest used as the export source
  - intentionally git-ignored because the complete source manifest is too large for GitHub
- `tools/catalog/runtime/wow.export/`
  - local portable extraction runtime used by `Extract-ItemDb2.ps1` and `Refresh-ItemCatalog.ps1`
  - intentionally git-ignored because the runtime contains large vendor binaries

When to use learned import:

- PTR or Beta playtesting discovers items before the next maintainer extraction run
- guild testing surfaces request or minimum-search items that are missing from the checked-in manifest
- you want those discoveries preserved in git review without pretending they are confirmed client-extracted metadata

When not to use learned import:

- as a replacement for the normal `Refresh-ItemCatalog.ps1 -Target Retail|PTR|Beta` flow
- when a confirmed local-client refresh is already available for the same target and build

## Credential-Free Fallback Behavior

This flow does not require Blizzard OAuth credentials.

What it does automatically:

- attempts to fetch current AH item IDs from the currently-supported public upstream
- merges them into the local manifest
- preserves known names and quality for items already in the manifest
- regenerates `GBankManager_ItemData/Data.lua`

What it cannot guarantee from public sources alone:

- automatic canonical name/quality hydration for brand new item IDs

As of May 14, 2026, the live Undermine Exchange API hostname used during implementation requested authorization headers when called directly. If that remains true in your environment, the script will fail with a clear message instead of pretending it refreshed successfully.

When new item IDs are discovered without metadata, the script keeps them as unresolved placeholder records such as `Item 12345`. The addon can still learn richer metadata later from runtime resolutions and saved search use.

## Blizzard Metadata Fallback Behavior

This flow requires maintainer credentials:

- `GBM_BNET_CLIENT_ID`
- `GBM_BNET_CLIENT_SECRET`

It remains useful for experimentation or one-off enrichment, but it is no longer the recommended main path for keeping the shipped catalog current.

## Files

- `runtime/item-catalog-input.json`
  - local maintainer manifest used as the export source and kept outside git
- `Resolve-WoWTarget.ps1`
  - resolves `Retail`, `PTR`, or `Beta` into maintainer target settings
- `Refresh-ItemCatalog.ps1`
  - top-level maintainer entrypoint for target validation, extraction, normalization, manifest merge, generated addon rebuild, and categorized reporting
- `Import-LearnedItemCatalog.ps1`
  - imports addon-exported learned rows into the checked-in manifest without overwriting confirmed rows
- `Extract-ItemDb2.ps1`
  - local-client extraction entrypoint that writes normalized Phase 3 rows
- `Merge-ExtractedItemCatalog.ps1`
  - merges normalized extracted rows into the checked-in manifest with deterministic ordering and retention rules
- `Build-ItemDataAddon.ps1`
  - converts the manifest into the load-on-demand item addon data file
- `Export-StaticItemCatalog.ps1`
  - lower-level manifest-to-Lua exporter used by the build script
- `Update-CredentialFreeItemCatalog.ps1`
  - legacy fallback for refreshing the manifest from public AH item universes and then regenerating Lua
- `Update-BlizzardItemMetadata.ps1`
  - legacy fallback for enriching manifest rows with official Blizzard item metadata using maintainer credentials
