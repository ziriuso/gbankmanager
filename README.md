# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.

Local tests use a Lua 5.1-compatible runner to load the addon in `.toc` order with one shared namespace, matching the WoW addon runtime shape.

## Features

- One-button guild bank scan foundation with snapshot, tab-scoped item rows, and change-log storage
- Officer-first dashboard shell with inventory, history, minimums, requests, exports, about, and options workspaces
- Recurring stock minimum helpers with a modal-based add/edit flow and procurement-planning export workflows
- Member request submission with explicit approval workflow and no auto-approval path
- Auctionator, CSV, and custom-delimited export builders
- Guild sync foundation with authority-first conflict resolution and login hello messages

## Architecture

- `Core/` keeps bootstrap, constants, slash commands, and thin event registration.
- `Data/` owns defaults, migrations, and store-backed SavedVariables access.
- `Domain/` owns pure planning, exports, requests, diff, and permission rules.
- `Features/` owns live WoW workflows such as guild-bank scanning.
- `UI/` owns the shell plus view/controller modules layered on top of shared helpers.

Current UI ownership is intentionally split across:

- `UI/MainFrameShell.lua`
- `UI/TableLayouts.lua`
- `UI/MainTableController.lua`
- `UI/MainRequestsController.lua`
- `UI/MainExportsController.lua`
- `UI/MainMinimumsController.lua`
- `UI/MainFrame.lua`

## Item Catalog

- The addon now uses a shared item catalog path for both Minimums and Requests.
- Minimums add flow now moves from the search modal directly into a centered `Minimum Details` modal, existing Minimums rows reuse that same modal with the current Bank Tab prefilled as a read-only value, and the Minimums table defaults to `Show All` on open.
- Minimums and Requests both use the same reusable selector with clearly labeled `Search Item ID` and `Search Item Name` inputs plus a selected-item display for the resolved name and any available crafting-quality icon.
- Name search is token-based, ranked, and shared through a cached session per editor surface, so broad queries like `flask of` return a scrollable multi-match list while exact item IDs still resolve directly.
- Name search does not activate until two typed characters, which avoids noisy one-character scans and keeps broad bundled queries responsive.
- The shipped bundled search payload is now generated from a procurement-focused catalog profile by default: current-expansion items only, limited to the addon-relevant AH-style categories `Consumables`, `Containers`, `Gems`, `Reagents`, and `Item Enhancements`, plus any learned active overflow rows retained in the manifest.
- Match rows render through one reusable virtualized results control instead of an eager button stack.
- Match rows show the crafting-quality icon or tier when available, followed by the item name and item ID so quality variants stay distinguishable before selection, and duplicate-name crafted variants sort with the higher tier first.
- Minimums details use the same bundled catalog to backfill `craftedQuality` and `craftedQualityIcon` when scan data does not already include them, so the modal and table can still show the right crafted tier for known items.
- Minimums and the request wizard require a confirmed catalog selection before submission can advance, and raw-text-only request submission is rejected.
- Bundled item data is shipped in the required sibling addon `GBankManager_ItemData/`, which now loads as a core dependency of `GBankManager` instead of as an optional load-on-demand companion.
- The bundled companion addon now ships a generated indexed payload instead of one monolithic flat search table:
  - chunked item-record files
  - chunked token-to-itemID index files
  - a bootstrap/finalize path that marks the dataset ready only after all chunks attach
  - an explicit global payload bridge so the main addon can consume the bundled search data reliably even if WoW keeps the two addon namespaces separate at runtime
- If that bundled indexed payload is unavailable at runtime, name search now fails closed with a clear unavailable message instead of silently falling back to a misleading sparse local-only result set.
- Search sessions now keep bundled indexed data and supplemental local data separate, so broad name queries do not rescan the full bundled catalog as fallback work on every keystroke.
- In Minimums, draft row styling is now part of the editing contract:
  - green for newly added rows
  - yellow for edited rows
  - red for removed rows
- Maintainers now use a local-client item catalog pipeline under `tools/catalog/`, targeting `Retail`, `PTR`, or `Beta`, and `Refresh-ItemCatalog.ps1` now carries extraction, merge, generated addon rebuild, plus target-scoped progress and phase-boundary resume in one command.
- That maintainer pipeline now defaults to `ProcurementCurrentExpansion`, and the generated addon only exports active non-deprecated rows so old manifest history does not bloat the live search payload.
- `Import-LearnedItemCatalog.ps1` exists as the secondary maintainer path for PTR/Beta discoveries that need to land before the next confirmed target refresh.
- Bundled catalog rows keep generic rarity in `quality` and `qualityName`, while `craftedQuality` and `craftedQualityIcon` are the addon-meaningful profession-tier fields and stay `nil` for non-crafted items.
- When the local client does not expose crafted tiers directly for modern duplicate-name crafted variants, the maintainer pipeline derives those tiers from stable grouped item-level ordering so searches such as `Flask of the Shattered Sun` and `Thalassian Phoenix Oil` can surface distinct crafted variants reliably.
- Older Blizzard web metadata and credential-free refresh scripts remain available only as fallback tooling, not the recommended primary path.
- The full maintainer manifest and local `wow.export` runtime are now intentionally git-ignored local assets under `tools/catalog/runtime/`; only the generated addon payload in `GBankManager_ItemData/` is shipped in git.

## Local Development

1. Keep both addon folders at `GBankManager/` and `GBankManager_ItemData/`.
2. Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
3. If item catalog data needs refresh, run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh`.
   This now refreshes the default procurement-only current-expansion search catalog unless you explicitly override the catalog profile.
   Before the first refresh on a fresh clone, place the local manifest at `.\tools\catalog\runtime\item-catalog-input.json` and the extractor runtime under `.\tools\catalog\runtime\wow.export\`.
4. If a long refresh is interrupted, rerun the same target with `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Resume`. Extraction resumes from the last saved `itemID`, while merge and generated addon rebuild restart from the last safe completed phase boundary.
5. Optionally run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath <path>` before a PTR or Beta refresh if addon-learned discoveries need to be preserved.
6. Optionally run the companion Wowless smoke lane with `.\tools\test\run-wowless.ps1` after setting up the sibling repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager-wowless-smoke`. The companion report records the selected Wowless product and per-product fallback attempts.
7. Copy both `GBankManager` and `GBankManager_ItemData` into `World of Warcraft\_retail_\Interface\AddOns\`.
8. Use `/gbm ui` to open the officer shell.
9. Use `/gbm scan` while the guild bank is open to exercise the scan flow.

## Next Roadmap

The next planned work after the request workflow slice is:

1. Rework the Exports UI after the request/admin split.
2. Finish broader UI polish such as theme customization, resize/scale, and spacing cleanup.
3. Build an in-game unit-test lane through the unit test addon after the product-facing UI slices above are stable.
4. Strengthen addon communication between guild users so history, requests, and minimums sync reliably across addon-enabled guild clients.
5. Fully document the maintainer deployment flow and add a small maintainer UI for choosing the WoW target path (`Retail`, `PTR`, `Beta`) plus surfacing current status, last sync time, and the WoW patch/build used for the last sync.

### Recently Completed

- Scan snapshots now persist `itemRows` alongside aggregate `items`, using `itemID|TAB|tabName` row identity for one row per bank tab while preserving aggregate totals for diff and planning.
- Inventory and Minimums `Show All` now consume tab-scoped scan rows so shared items render with the correct per-tab quantity.
- Inventory and Minimums now share the same table layout: `Item ID`, `Tier`, `Item`, `Bank Tab`, `Current`, `Restock`, and `Minimum`, with the Item column widened to use the old right-side whitespace.
- Minimums uses the shared table header/filter controls instead of the old bottom search box, and its footer is a compact three-button action strip rather than a boxed editor panel.
- Requests never auto-approve. Officers/admins cannot approve their own requests; only the Guild Master can manually approve their own request through the same workflow action as any other approval.
- The officer-facing Requests tab is now `Request Admin`, focused on workflow management with shared table search and a request-list/details-modal flow.
- `/gbm request` now opens a smaller end-user workflow window with `Guild Bank Manager` in the header, a four-column own-request status table, row-click details, request cancellation for pending own requests, and a three-step `New Request` wizard.
- Request approval now requires the approver to choose a Bank Tab, persists the Decision Note back into request details, and immediately saves/updates an enabled tab-scoped Minimums rule for the requested item and amount.
- Request details now show Requested By above Date Requested, keep Updated By, Date Updated, and Decision Note at the bottom of the fixed-row detail list, hide the decision-note editor after approval or denial, block click-through while request modals are open, normalize request history actors to character names, and keep shared table scrollbars inside the table viewport.
