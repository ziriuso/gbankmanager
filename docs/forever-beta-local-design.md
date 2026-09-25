# Forever beta local deployment

## Scope

Build and deploy GBankManager to the installed WoW: Forever beta at
`C:\Gaming\World of Warcraft\_classic_beta_`. Keep the Retail item payload and
the existing CurseForge release artifact unchanged. Publishing a Forever file
to CurseForge is a later release task.

## Source and data contract

- Resolve `Forever` to product `wow_classic_beta` and client folder
  `_classic_beta_`.
- Extract item rows from that installed product. The Forever profile uses the
  nine top-level categories shown in the beta Auction House: Weapons, Armor,
  Containers, Consumables, Trade Goods, Ammo, Recipes, Quest Items, and
  Miscellaneous, across the product's eras. The Retail
  `ProcurementCurrentExpansion` profile stays as it is.
- Omit quality labels and Retail crafted-quality tiers from the Forever catalog
  and avoid using quality to rank or decorate Forever search results. Hide tier
  columns in tables and omit them from the built-in CSV exports. The guild
  bank scan skips client quality APIs, and snapshot rows discard legacy quality
  values for Forever.
- Keep Forever extraction, manifest, progress, and generated Lua payloads
  separate from Retail. Generate the Forever payload at
  `Forever/GBankManager_ItemData/` with the same runtime addon identity
  (`GBankManager_ItemData`).
- Add interface `16001` to the main addon TOC and the generated Forever data TOC.
  Do not add it to the Retail data TOC.
- Deploy `GBankManager` and the Forever data folder into the Forever AddOns
  directory. Check every installed file against its source by hash.

## Acceptance checks

1. Unit tests cover target resolution, Forever Auction House categories,
   quality omission in item data, displays, and exports, and isolated data
   generation without changing Retail output.
2. The full Lua suite passes.
3. The generated Forever data has a nonempty, indexed payload and records the
   Forever client build and source.
4. The beta AddOns directory contains `GBankManager` and
   `GBankManager_ItemData`; both TOCs support interface `16001`, and installed
   hashes match the built files.
5. In-game checks remain necessary for guild bank scanning, transaction logs,
   peer sync, SavedVariables, and the request/minimum item search. The installed
   client cannot be exercised by repository tests alone.

## Assumption to validate

The Forever product's `ItemSparse` and `Item` rows are the appropriate source
for its procurement catalog. Confirm representative items in game before
publishing a public Forever release.

## Local build and deployment

The Forever beta target resolves to `_classic_beta_` and product
`wow_classic_beta`. A refresh defaults to the `ProcurementForever` profile,
keeps its manifest under `tools/catalog/runtime/forever/`, and generates the
checked-in payload under `Forever/GBankManager_ItemData/`.

This checkout does not bundle wow.export. On this machine, use the existing
ignored runtime from the canonical checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Forever -WoWRoot 'C:\Gaming\World of Warcraft' -WowExportRoot 'C:\GitHub\gbankmanager\tools\catalog\runtime\wow.export\portable-wow-export-win-x64-0.2.17' -Fresh -Json
.\tools\lua\lua.exe .\tests\run_all.lua
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Forever -WoWRoot 'C:\Gaming\World of Warcraft' -Json
```

The initial refresh creates a separate empty Forever manifest before merging
the extracted client rows. The local wow.export cache also needs a current
binary listfile and ItemSparse definition for the Forever build. For build
`1.60.1.70009`, the source ItemSparse layout is `6FCC3191`; the current
wowdev definition lists that build under the same layout. Keep these ignored
cache files out of git. The class IDs come from the matching `Item` DB2
layout (`9A2A4834` for this build), so that definition must also be present in
the ignored wow.export cache.

The generated Forever payload uses the folder name `GBankManager_ItemData`
inside `Forever/` and at the installation target. The Retail data folder at
the repository root remains the release source for Retail.
