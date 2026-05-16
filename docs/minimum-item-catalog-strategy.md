# Minimum Item Catalog Strategy

## Goal

Provide a bundled item catalog that ships with the addon and powers item search for:

- Minimums `Add`
- Requests item creation

The catalog should be maintainable by addon builders, not end users. Players should never need to build or fetch the dataset themselves.

## Recommendation

Do not use Wowhead scraping or Wowhead database export as the primary build source.

Do not use Blizzard web item metadata as the primary maintainer refresh source either.

Use a maintainer's local WoW client install as the primary refresh source, with explicit target support for:

- `Retail`
- `PTR`
- `Beta`

Optional upstream discovery feeds and fallback metadata scripts can still exist, but they should not be the canonical or recommended primary path.

That gives us the right split:

- local client extraction gives us branch-correct, hotfix-aware item details
- the addon receives a generated required companion item-data addon checked into the repo and shipped beside the main addon
- the shipped live search payload stays small enough to avoid the full-universe `90 MB` style search experience that showed up with the original broad catalog

## Default Shipping Profile

The default shipped catalog is no longer the full item universe.

It is now a procurement-focused profile:

- current expansion only
- Blizzard AH-style procurement categories only:
  - `Consumables`
  - `Containers`
  - `Gems`
  - `Reagents`
  - `Item Enhancements`

Implementation notes:

- the maintainer pipeline defaults to `ProcurementCurrentExpansion`
- `Refresh-ItemCatalog.ps1 -CatalogProfile Full` still exists for maintainer diagnostics and one-off investigations
- the generated addon exports only active non-deprecated manifest rows, so the repo can preserve deprecated history without shipping that history to players

## Why Not Wowhead

Wowhead is valuable as a human reference, but it is the wrong bulk source for this addon catalog.

Reasons:

- Wowhead does not expose a documented public bulk item export flow for this use case.
- A Wowhead forum response explicitly says they do not allow scraping or exporting their data.
- Wowhead’s client and looter flow is designed to feed data into Wowhead, not to provide us with a supported outbound dataset for addon builds.

## Recommended Data Flow

### Source 1: Maintainer manifest

Use a checked-in manifest as the source-of-truth working set.

Each row should track:

- `itemID`
- `name`
- `quality`
- `qualityName`
- `craftedQuality`
- `craftedQualityIcon`
- `status`
- `source`
- `lastVerifiedAt`

### Source 2: Local client extraction

Use the selected local WoW client target for:

- item name
- item quality
- crafting quality tier when the source row exposes it
- derived crafted quality tier for modern duplicate-name crafted groups when the source row does not expose that tier directly

What we store in the addon:

- `itemID`
- `name`
- `quality`
- `qualityName`
- `craftedQuality`
- `craftedQualityIcon`

Meaning of the quality fields:

- `quality` and `qualityName` keep the generic Blizzard rarity values like `Common`, `Uncommon`, `Rare`, and `Epic`
- `craftedQuality` is the addon-meaningful profession tier value for search and UI reuse
- `craftedQualityIcon` stores the atlas used by the addon UI to render that tier consistently
- non-crafted rows should keep `craftedQuality = nil` and `craftedQualityIcon = nil`

Optional later fields:

- `classId`
- `subclassId`
- `icon`

## Addon Storage Model

The addon now has two catalog layers:

1. Bundled static catalog addon
   - `GBankManager_ItemData/GBankManager_ItemData.toc`
   - `GBankManager_ItemData/Generated/*.lua`
   - checked into git
   - required dependency of the main addon, loaded at startup

2. Learned runtime catalog
   - `ui.minimumItemCatalog`
   - stores exact item resolutions encountered by the user
   - supplements the bundled data without replacing it

3. Runtime indexed search session
   - created once per Minimums or Requests editor surface
   - holds a cached bundled payload reference plus a fallback item list
   - caches repeated query results so follow-up typing does not rebuild the full search source

The shared search path merges:

- bundled static catalog
- learned runtime catalog
- saved minimums
- saved requests
- one-time targets
- current snapshot items

The runtime query contract now is:

- exact numeric `Item ID` search resolves directly
- `Item Name` search activates only after 2 typed characters
- bundled results come from a token-to-itemID index, not a flat full-table scan
- fallback/local rows can still be used for exact runtime hydration, but broad name search should not silently degrade into a sparse local-only result list when the bundled indexed payload is unavailable
- fallback search-session rows now stay limited to supplemental learned, saved, request, minimum, and snapshot items so broad bundled queries do not pay for a second full-catalog scan on each keystroke
- the UI renders a virtualized scrollable results list instead of one button per match
- duplicate-name crafted variants should remain separate rows and show distinct crafted tiers whenever the catalog payload carries them

## Build Strategy

Recommended maintainer workflow:

1. resolve the maintainer target with `Retail`, `PTR`, or `Beta`
2. choose explicit refresh mode:
   - `-Fresh` to restart from the beginning
   - `-Resume` to continue from saved progress
3. refresh the manifest from the selected local client install
4. optionally import runtime-learned rows when PTR or Beta testing discovers items before the next confirmed refresh
5. let `Refresh-ItemCatalog.ps1` rebuild `GBankManager_ItemData` from the merged manifest
6. run `.\tools\lua\lua.exe .\tests\run_all.lua`
7. commit the manifest and generated item-data addon when they change

Resume behavior:

- progress is stored per target under `tools/catalog/runtime/state/`
- interrupted extraction can continue after the last completed sequential `itemID`
- interrupted merge and generated addon rebuild restart from the last safe completed phase boundary
- `-Fresh` clears prior target-scoped progress and restarts from the beginning
- `-Resume` requires an existing valid progress file for that target

Recommended learned import payload:

- top-level `items` array
- optional top-level `source`, `exportedAt`, `target`, `build`, and `locale`
- each row requires:
  - `itemID`
  - `name`
- each row may include:
  - `quality`
  - `qualityName`
  - `craftedQuality`
  - `craftedQualityIcon`

Example:

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

Learned import policy:

- use it as a secondary maintainer input, not the primary refresh source
- it is especially useful for PTR and Beta discovery while item names are being encountered in real testing
- imported learned rows must not overwrite confirmed manifest rows
- the next confirmed target refresh should be allowed to supersede learned metadata

Current Blizzard metadata and credential-free workflows remain fallback paths only.

Current limitation:

- public discovery is not reliable enough to be the primary freshness mechanism
- Blizzard web item metadata was not reliable enough in live implementation checks to remain the recommended main path
- local-client extraction is the primary design moving forward because it is branch-aware and better aligned with PTR/Beta prep

## Update Policy

Run metadata refresh and item-data addon generation as part of maintainer build or release preparation.

Suggested policy:

- refresh from the selected local client target during maintainer build or release prep
- keep support for `Retail`, `PTR`, and `Beta`
- import learned PTR/Beta discoveries only when they need to land before the next confirmed refresh
- regenerate the item-data addon from the merged manifest as part of the same maintainer flow
- run the addon test lanes after refresh so generated data stays covered by the normal repo gate

This avoids end-user intervention while also keeping build time bounded.

## Scope Notes

This catalog should remain focused on AH-searchable items first.

That means:

- yes: consumables, materials, enchants, recipes, tradable gear, misc trade goods
- no requirement yet: every soulbound or never-listed item in the game

If later we need a broader catalog than “items seen on the AH,” we should add a second ingestion path instead of overloading the AH-driven one.

## Current Status

Implemented now:

- shared addon-side catalog module
- bundled required companion item-data addon hook
- generated chunked bundled search payload with token-to-itemID indexes
- Minimums search merged onto the shared catalog path
- Requests search merged onto the shared catalog path
- session-cached indexed search for Minimums and Requests
- reusable virtualized search results control shared by both editors
- hard bundled-payload readiness gating so name search fails closed instead of pretending sparse local-only results are authoritative
- named target resolver for `Retail`, `PTR`, and `Beta`
- local client extraction and normalization from the selected target
- derived crafted-tier assignment for modern duplicate-name crafted groups that only differ by item-level tiers in extracted client data
- deterministic manifest merge rules with deprecated retention and freshness guards
- generated addon rebuild integration in the top-level refresh flow
- learned-row import tooling for PTR/Beta discovery
- credential-free manifest updater script
- Blizzard metadata enrichment script
- item-data addon build/export scripts

Operational status:

- `Refresh-ItemCatalog.ps1` is now the canonical maintainer command
- `Refresh-ItemCatalog.ps1` now requires explicit `-Fresh` or `-Resume`
- `Import-LearnedItemCatalog.ps1` is the secondary path for addon-learned PTR/Beta discoveries
- older credential-free and Blizzard metadata flows remain fallback-only

Future follow-up only if needed:

- stronger ID discovery imports if we want broader seeding beyond runtime-learned items and local client extraction
- deeper subclass filtering if a future expansion makes one of the AH-style procurement categories too noisy again
