# Forever beta local deployment

## Scope

Build and deploy GBankManager to the installed WoW: Forever beta at
`C:\Gaming\World of Warcraft\_classic_beta_`. Keep the Retail item payload and
Retail CurseForge release artifact separate from the Forever version.

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
- Use interface `16001` in the Forever branch's main addon TOC and the
  generated Forever data TOC. Do not add it to the Retail data TOC.
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

## Guild bank with no purchased tabs

When the guild bank is open but has no accessible item tabs, Scan Bank should
still read the displayed bank balance and force a Money Log scan. The balance
and its scan time should be saved for the active guild and shown on the
Dashboard. No empty inventory snapshot should replace a prior item scan while
tab data may be delayed. The scan button must show a visible result, including
when the bank is closed or a scan is denied. An automatic scan may continue
retrying for delayed tab data after collecting money once.

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

## First Forever release checkpoint

On 2026-09-25, the dedicated `codex/forever` branch was pushed without merging
its Forever changes into `master`. Commit
`c9d613c256c31841105dc4d1775e1d228cbd855e` was tagged
`forever-v1.6.0`. The tag workflow passed its full Lua suite and exact zip
contents check. GitHub published the non-prerelease
`GBankManager-Forever-1.6.0.zip` asset at
`https://github.com/ziriuso/gbankmanager/releases/tag/forever-v1.6.0`.

The same workflow uploaded a `Release` file to CurseForge project `1552923`
and received file ID `8974199`. The file was tagged only for Forever game
version `1.60.1`. At the immediate post-upload check, the public CurseForge
listing still showed only the earlier Retail file and the new file page
returned 404; public visibility remains to be confirmed after moderation.
The local `_classic_beta_` installation was updated from this source and
verified at 73/73 main addon files plus 41/41 Forever item-data files, with
no hash mismatches.

## Proposed public release boundary

Keep `master` as the Retail release line and maintain Forever on a dedicated
branch of the same GitHub repository. Bring applicable shared fixes from
`master` into Forever deliberately; do not merge the Forever-only catalog or
client behavior back into `master` by default. Both variants can use the
existing CurseForge project, provided each uploaded file is tagged only for
its own WoW game version.

The Forever release must package `GBankManager/` with
`Forever/GBankManager_ItemData/` installed under the normal
`GBankManager_ItemData/` folder name. Its packaged TOCs must identify Forever
interface `16001`. The GitHub tag and zip name must clearly say Forever, and
the CurseForge upload must select only the Forever `1.60.1` game version. The
Retail release workflow and its existing package remain on `master`.

Before a public upload, run the full Lua suite, inspect the exact Forever zip,
confirm it contains no Retail item database, and verify the matching GitHub
release and CurseForge file after publication. The current tag-driven workflow
still builds a Retail zip and resolves a Retail game version, so it must be
adapted for this branch before any Forever tag is pushed.
