# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.

Local tests use a Lua 5.1-compatible runner to load the addon in `.toc` order with one shared namespace, matching the WoW addon runtime shape.

## Features

- One-button guild bank scan foundation with snapshot, tab-scoped item rows, and change-log storage
- Officer-first dashboard shell with inventory, history, minimums, requests, exports, about, and options workspaces
- Dashboard now uses four metric cards plus `Top 5 Most Used`, `Recent Activity`, and `Quick Actions` panels inside the officer shell
- The shared shell modernization pass now uses explicit surface/button variants plus reusable art layers for the main shell, sidebar, header, metric cards, export action cards, branded About panel, request/minimum workflows, table chrome, and nav items, with matte fills, gold line work, header bands, nav accent rails, a sidebar crest/footer identity card, and a tabbed Options shell
- Recurring stock minimum helpers with a modal-based add/edit flow and procurement-planning export workflows
- Member request submission with explicit approval workflow and no auto-approval path
- Auctionator, CSV, and custom-delimited export builders, including current caret-delimited Auctionator list import output
- Guild sync foundation with authority-first conflict resolution, chat-visible sync milestones, and login hello messages
- Local appearance customization with a token-backed theme system (`Generic WoW`, `High Contrast`, `Alliance`, `Horde`, `Nature`, `Void`), linked shell-and-table scaling, shell opacity, modal opacity, collapsed-nav icons, and direct slider interaction plus steppers
- In-client verification commands for both workflow smoke (`/gbm test smoke`) and deterministic in-game unit checks (`/gbm test unit`)

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
- The request-only flow now uses a four-step wizard: item selection, quantity, preferred bank tab, and confirm, with a live preview rail and quantity steppers.
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
5. Optionally launch the local maintainer workflow UI with `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Open-ItemCatalogMaintainer.ps1` for target selection, saved status, refresh, and deploy. See [docs/maintainer-catalog-workflow.md](docs/maintainer-catalog-workflow.md).
6. Optionally run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath <path>` before a PTR or Beta refresh if addon-learned discoveries need to be preserved.
7. If you are resuming on a MacBook, use [docs/macos-readme.md](docs/macos-readme.md) for clone, worktree, WoW path detection, deploy, and resume guidance.
7. Optionally run the companion Wowless smoke lane with `.\tools\test\run-wowless.ps1` after setting up the sibling repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager-wowless-smoke`. The companion report records the selected Wowless product and per-product fallback attempts.
8. Copy both `GBankManager` and `GBankManager_ItemData` into `World of Warcraft\_retail_\Interface\AddOns\`, or use `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail`.
9. Use `/gbm ui` to open the officer shell.
10. Use `/gbm scan` while the guild bank is open to exercise the scan flow.
11. Use `/gbm test smoke` for workflow smoke and `/gbm test unit` for the in-client unit lane after copying the addon into WoW.

## Next Roadmap

The next planned work after the completed pre-polish workflow block is:

1. Continue the shelved UI polish refinement pass from [docs/ui-polish-suggestions.md](docs/ui-polish-suggestions.md), focusing on action-strip icon expansion, softer less-blocky surfaces, spacing cleanup, and theme tuning on top of the already-landed linked scale, opacity, preset, and nav-icon foundation.
2. Revisit deeper sync catch-up only if live guild testing shows the current request, history, auth, and approval-side minimum syncing still leaves workflow gaps.

### Recently Completed

- Scan snapshots now persist `itemRows` alongside aggregate `items`, using `itemID|TAB|tabName` row identity for one row per bank tab while preserving aggregate totals for diff and planning.
- Inventory and Minimums `Show All` now consume tab-scoped scan rows so shared items render with the correct per-tab quantity.
- Inventory and Minimums now share the same table layout: `Item ID`, `Tier`, `Item`, `Bank Tab`, `Current`, `Restock`, and `Minimum`, with the Item column widened to use the old right-side whitespace.
- Minimums uses the shared table header/filter controls instead of the old bottom search box, and its footer is a compact three-button action strip rather than a boxed editor panel.
- Requests never auto-approve. Officers/admins cannot approve their own requests; only the Guild Master can manually approve their own request through the same workflow action as any other approval.
- The officer-facing Requests tab is now `Request Admin`, focused on workflow management with shared table search and a request-list/details-modal flow.
- `/gbm request` now opens a smaller end-user workflow window with `Guild Bank Manager` in the header, a four-column own-request status table, row-click details, request cancellation for pending own requests, and a four-step `New Request` wizard with a progress rail, preview card, quantity steppers, and explicit bank-tab selection.
- Request approval now requires the approver to choose a Bank Tab, persists the Decision Note back into request details, and immediately saves/updates an enabled tab-scoped Minimums rule for the requested item and amount.
- Request details now show Requested By above Date Requested, keep Updated By, Date Updated, and Decision Note at the bottom of the fixed-row detail list, hide the decision-note editor after approval or denial, block click-through while request modals are open, normalize request history actors to character names, and keep shared table scrollbars inside the table viewport.
- Request deletion is now a distinct permission in the guild auth model, and authorized users can delete a request directly from the request-details workflow popup.
- Request Admin now highlights the active bottom filter, keeps `Add` on the far left, right-aligns the `All`, `Pending Approval`, and `Pending Fulfillment` filters, uses the shared table height, and keeps the `Date Fulfilled` filter within bounds.
- Request Admin now also includes a `Completed` filter and a left-side `Refresh` action beside `Add Request`.
- Exports now shows `Excess Stock`, uses `None` for missing alternate stock, renders crafted-quality icons in the visible `Item Tier` column, and emits the newer Auctionator shopping-list line format while keeping numeric tier values for CSV-style outputs.
- Exports now presents the supported outputs as four action cards: `Auctionator`, `TSM`, `CSV Spreadsheet`, and `Manual Shopping List`, while keeping the generated formats unchanged.
- Dashboard metric cards and export action cards now carry dedicated large icons, and the export cards now use `Generate` or `Open List` CTA labels closer to the target mockup.
- The near-literal mockup fidelity pass now also drives the live shell palette and chrome more aggressively: the `Generic WoW` preset is darker and bluer, nav buttons carry left accent rails, dashboard quick actions use icon-led primary buttons, and shared sliders now render through a more deliberate track/thumb treatment instead of the earlier plain boxed controls.
- About now renders through a centered branded panel instead of the old plain body-text fallback, and the shared table shell now uses dedicated header/filter/viewport variants plus semantic alternating row tokens rather than generic panel tinting.
- Minimums now uses separate `Enabled Only` and `Show All` buttons with an obvious active-state highlight instead of a single toggle label.
- The guild auth policy string now carries the shared Restock Default plus updater metadata, pulls from Guild Info on load and guild updates, refreshes the Options restock input from live Guild Info data, and appends policy-update history rows that now show in the History view.
- `Options -> Auth` now includes a `Select All` helper beside the compact `Policy String`, so officers can focus, highlight, and copy the full Guild Info snippet without manual drag selection.
- `Options -> Blacklist` is now a read-only roster view with instructions for the shared `[GBMBL]` officer-note tag plus a `Refresh` action that reparses guild-roster officer notes, and guild-shared blacklist membership now comes from parsing those officer-note tags instead of the Guild Info policy string.
- Dashboard mismatch investigation did not land a code change: the obvious local machine paths did not reveal a live SavedVariables file, and the dashboard plus Exports count paths both reduce from the same demand-plan shape, so live repro should come before any dashboard fix.
- Opening the guild bank now auto-starts a scan when at least 10 minutes have elapsed since the last successful scan, and the retry path now stays alive long enough for delayed tab or slot metadata on reopen. Manual slash or button scans still work immediately.
- Synced request create and update messages now append local history rows on receiving clients, approved request sync recreates the tab-scoped Minimums side effect on receivers, and request conflict resolution now prefers higher-authority updaters before timestamp tie-breaks.
- The auth policy string now compacts updater identity with a hash token instead of storing the full updater name in Guild Info, while still preserving local updater attribution when it can be rehydrated from live or previously known state.
- Compact auth-policy imports no longer carry blacklist membership. Guild-shared blacklist membership now comes from appended officer-note tags, while learned blacklist reasons stay local and continue to travel through addon sync snapshots.
- Blacklist entries now normalize to `Character-Server`, migrate legacy server-first ordering, and render in the read-only Blacklist tab directly from guild-roster officer-note parsing.
- The read-only Blacklist tab no longer attempts officer-note writes. To blacklist or unblacklist a member, edit that member's officer note in Guild & Communities and add or remove `[GBMBL]`, then refresh guild data or `/reload`.
- Request creation now refreshes guild-backed blacklist state before submit, so a newly tagged blacklisted member is denied request creation as soon as the latest officer-note parse is available on that client.
- History rows now build newest-first by timestamp so recent approvals, minimum edits, and auth changes stay at the top of the table.
- The sidebar footer identity card now refreshes on addon load plus live guild events, so the current guild name can recover from early `GetGuildInfo("player")` timing and no longer sticks on `No Guild` until `/reload`.
- Crafted-quality rendering now normalizes the low-tier and max-tier atlas variants so Exports, Inventory, Minimums, Requests, and request-details all show the same visible quality symbols whether the source came from live scan data or fallback catalog/search data.
- Two-rank crafted items now stay on one shared visible chat-icon family across table rows, details, request review, exports, and the manual shopping list instead of switching to a mismatched inventory-atlas family.
- The shell now supports a token-backed theme manager with local-only presets (`Generic WoW`, `High Contrast`, `Alliance`, `Horde`, `Nature`, `Void`), linked shell scale and table density behavior, separate shell and modal opacity sliders, collapsed-nav icons, and stronger active-state glow for nav plus workflow filter buttons.
- The UI modernization pass is now in a committed checkpoint state: reusable shell, theme, table, request-wizard, export-card, and Options-tab scaffolding are in place, but the live addon still needs substantial art-pack-driven polish before it matches the Alliance mockup or broader visual guide literally.
- The request-only workflow panel and shared request wizard are mid-modernization: the member-facing launcher now presents the four-step guided flow, and the wizard exposes a visual progress rail plus a request preview card without changing request persistence or sync behavior.
- Request Admin filters, request details actions, the request-only launcher, wizard navigation, and Minimums modal actions now all route through dedicated shared button variants (`primary`, `secondary`, `tab`, `icon`, `danger`) instead of the earlier one-style-fits-all bordered buttons.
- Appearance sliders now use a safer drag-release surface and a more polished thumb or track treatment so releasing the mouse off the bar does not leave the slider latched into drag mode.
- Shell scaling now clamps shared table height inside the content area so footer action strips stay visible, keeps the top-bar scan and status controls from overlapping at smaller scales, and preserves the floating manual shopping list across tab switches or shell close while remembering its saved position.
- The addon shell now opts into top-level window ordering so other dragged UI can come above it, and clicking back onto the addon brings the shell and its registered modals forward again.
- Dashboard `Top 5 Most Used` now ranks repeated shortage or restock cycles from persisted snapshot history and active Minimums rules before falling back to raw withdrawal totals when no stocking history exists.
- Minimums now groups staged rows at the top of the table, exposes `ADD` / `EDIT` / `DELETE` row badges, shows a staged-change summary in the footer, and reveals `Revert All` only when draft changes exist.
- `/gbm test unit` now also covers blacklist normalization, officer request-queue prioritization, and unresolved minimum repair-row ordering so more pure-domain regressions can be caught in-client without relying on workflow smoke alone.
- `/gbm test smoke` now follows the real Minimums modal add flow during its draft-stage check and hard-resets request selector state before the confirmed-selection gating check, so those two live smoke results match the current product workflow instead of the retired footer-editor path.
- Maintainers now have repo-local deployment helpers plus a small local PowerShell maintainer launcher for target selection, saved status, refresh, and deploying both addon folders into `Retail`, `PTR`, or `Beta`.
