# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.

Marketplace copy for publishing is kept in [docs/curseforge-description.md](docs/curseforge-description.md).
Release automation setup for CurseForge and GitHub Releases is documented in [docs/curseforge-release-workflow.md](docs/curseforge-release-workflow.md).

Local tests use a Lua 5.1-compatible runner to load the addon in `.toc` order with one shared namespace, matching the WoW addon runtime shape.

## License

- Source code in this repository is licensed under the [Mozilla Public License 2.0](LICENSE).
- Custom branding and image assets in `art/` are covered by the separate [asset and IP notice](LICENSE-assets.md) and are not included in the MPL grant unless explicitly stated otherwise.
- The project license does not grant rights to Blizzard Entertainment intellectual property or other third-party content referenced by the addon.

## Features

- One-button guild bank scan foundation with snapshot, tab-scoped item rows, and change-log storage
- Officer-first dashboard shell with inventory, minimums, requests, exports, history, bank-ledger, about, and options workspaces
- Dashboard now uses four metric cards plus `Top 10 Most Used`, `Recent Activity`, and a trimmed `Quick Actions` panel with `Add Minimum`, `Create Request`, and `Export Data`
- The shared shell modernization pass now follows the approved no-art-pack `Hybrid Modern` direction: a native-paneled shell, soft distinct nav buttons with stronger selected state, a cleaner toolbar-band header, flatter dark-band content sections, separate metric cards, structured tables, slimmer actions, segmented tabs, cleaner floating-sheet modals, distinct colored themes, dense-but-clean spacing, and a more aggressively simplified chrome pass that removes nested line treatment, drops most full backdrop borders on flat shell surfaces, and relies on separators plus accent rails instead of boxes-within-boxes
- The current shell follow-up also normalizes interactive control contrast: neutral action buttons now sit forward from panel backgrounds more consistently, select-style dropdown triggers now use a dedicated higher-contrast control treatment, export CTAs share one primary look, and dashboard `Quick Actions` now allow wrapped labels instead of overflowing longer text
- `Options` now includes a dedicated `Stock Settings` tab that holds both `Restock Default` and a configurable `Critical Shortage Threshold`, where critical means current stock is at or below the chosen percentage of minimum
- `Options` now also includes a dedicated `Data` tab that controls guild-bank ledger retention, audit-history retention, the configurable `Scan Interval`, and a repair-classification threshold for money-log withdrawals. Saving that panel now gives visible confirmation, that one scan interval now drives both the guild-bank-open auto-scan throttle and direct ledger rescans when the inventory snapshot is still fresh, and that same panel now owns irreversible local-data cleanup actions behind confirmation prompts. `Mute Silvermoon Citizen` now lives under `Options -> Appearance` and saves immediately when toggled, and `Repair Threshold` now explains that withdrawals equal to or under the value count as repairs instead of normal withdrawals.
- Dashboard `Top 10 Most Used` is now driven by bank-ledger withdrawal rows instead of the older stocking-history fallback.
- Recurring stock minimum helpers with a modal-based add/edit flow and procurement-planning export workflows
- Member request submission with explicit approval workflow and no auto-approval path
- Auctionator, CSV, and custom-delimited export builders, including current caret-delimited Auctionator list import output plus an excess-stock drill-in that keeps the count visible with a right-aligned arrow affordance and summarizes the off-tab total plus tab-by-tab breakdown
- Inventory now also exposes a filtered `Export CSV` action through the shared export modal so the visible inventory table can be copied without leaving the shell
- Guild sync foundation with authority-first conflict resolution and compact inbound sync chat milestones
- `Bank Ledger` now centralizes guild-bank item logs and money logs, stores append-only deltas from guild-bank log scans, avoids duplicating rows when repeated scans reread the same visible Blizzard log window, queries all accessible item logs plus the fixed Blizzard money-log slot in one burst, debounces `GUILDBANKLOG_UPDATE` before reading the logs back, keeps the visible guild-bank tab stable during import, follows the working `GuildBankLedger` cadence by preventing ledger starts during the main inventory scan and self-chaining passive rescans only after the active scan finishes, hard-defers even direct ledger scan requests while inventory scanning is active, normalizes Blizzard’s relative log timestamps against server time, uses a `GuildBankLedger`-style session batch-count merge so same-identity batches can shrink and regrow without losing new item or money rows, keeps real repeated item or money activity when the same actor later moves the same item/quantity or gold amount again, now also keeps scanner-driven fully rotated busy item-log and money-log windows instead of discarding them as suspicious no-overlap batches, supports shared table filters plus a preset date-range dropdown, exposes ledger CSV export, shows item-log rows as `Date`, `Who`, `Action`, icon-based `Tier`, `Item`, `Quantity`, `Tab`, and `Moved From`, and summarizes item movement plus gold in, gold out, and repairs over the active date range. If local ledger history was polluted by earlier scanner/cache drift, `Options -> Data -> Clear Guild Bank Log Data` is the supported one-time recovery path.
- Local appearance customization with a token-backed theme system (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), built-in WoW `UISliderTemplate` controls for `UI Scale` (90%-120%), shell opacity, and modal opacity, a right-column slider stack with matched slider widths, theme presets with the minimap toggle directly beneath them, collapsed-nav icons, a show/hide minimap-button toggle, direct slider interaction plus steppers, and a header last-scan display that now uses timezone abbreviations such as `EDT` or `EST` when a scan exists
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
- Minimums and Requests both use the same reusable selector with clearly labeled `Search Item ID` and `Search Item Name` inputs plus one shared selected-item display that prefers trusted hyperlink-style item text and falls back to normalized plain names when no stored link is available.
- Name search is token-based, ranked, and shared through a cached session per editor surface, so broad queries like `flask of` return a scrollable multi-match list while exact item IDs still resolve directly.
- Name search does not activate until two typed characters, which avoids noisy one-character scans and keeps broad bundled queries responsive.
- The shipped bundled search payload is now generated from a procurement-focused catalog profile by default: current-expansion items only, limited to the addon-relevant AH-style categories `Consumables`, `Containers`, `Gems`, `Reagents`, and `Item Enhancements`, plus any learned active overflow rows retained in the manifest.
- Match rows render through one reusable virtualized results control instead of an eager button stack.
- Match rows now render through the same shared item-display contract as the selected-item preview: trusted stored hyperlinks when available, normalized plain-name fallback when not, no inline item IDs in the visible label, and duplicate-name crafted variants still sorted with the higher tier first.
- Minimums details use the same bundled catalog to backfill `craftedQuality` and `craftedQualityIcon` when scan data does not already include them, so the modal and table can still show the right crafted tier for known items.
- Minimums and the request wizard require a confirmed catalog selection before submission can advance, and raw-text-only request submission is rejected.
- The request-only flow now uses a three-step wizard: item selection, quantity/reason, and confirm, with a live preview rail and quantity steppers.
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
- The shared item-display foundation now lives in `Domain/ItemDisplay.lua`: it prefers trusted stored item hyperlinks for visible text when available, falls back to normalized plain item names when they are not, and preserves numeric crafted-quality values separately for sorting and CSV workflows.
- Learned and bundled catalog hydration now preserves optional `itemLink` and `itemString` fields alongside the existing semantic crafted-quality fallback fields, so later hyperlink-first UI surfaces can reuse trusted item text without abandoning numeric tier metadata.
- Requests officer rows, request-only rows, request details, and Minimums details now consume that shared item-display contract instead of depending on separate visible crafted-quality icon rows. The New Request wizard uses the same shared item text plus a selector-local quality icon so duplicate-name crafted variants stay visually distinguishable while still preserving hyperlink-style item text.
- Item-aware crafted-quality rendering now treats the bundled `GBankManager_ItemData` payload as the authoritative source for profession-tier family size. Inventory keeps its own texture path, and non-inventory item-display surfaces such as Minimums, Requests, Exports, and the manual shopping list now converge on the same single-silver-diamond / gold-pentagon two-rank family from the bundled canonical item-aware path before considering live reagent-quality variants, with the older reagent-medal family left only as a last-resort fallback.
- The shared table renderer also normalizes stale two-rank texture inputs at the final paint boundary, so old `Professions-ChatIcon-Quality-Tier*`, `Professions-Icon-Quality-Tier*`, or reagent-medal atlas values cannot leak back into visible Minimums, Requests, or Exports rows when row metadata identifies a two-rank crafted family.
- `/gbm debug quality <itemID>` now prints the bundled crafted-quality rank, family size, bundled display or preferred atlas, any live reagent-quality payload, the final inventory display atlas, and the final non-inventory atlas or markup atlas.
- `/gbm debug atlas` opens a live visual sampler of crafted-quality atlas candidates so Retail can identify the exact single-silver-diamond and gold-pentagon texture labels when a client build renders the resolver output unexpectedly.
- `/gbm debug render <itemID>` prints the active table renderer diagnostics for live rows, including matching `tableRowsData` atlas fields, active column keys, and the atlas on each visible row texture after painting.
- `/gbm debug request <itemID>` prints the New Request wizard selector diagnostics, including visible result-row and selected-item quality atlases, for modal issues that are outside the shared table renderer path.
- `/gbm debug ledger` prints the live scanner flags plus raw Blizzard item-log and money-log counts/sample rows, so missing ledger activity can be diagnosed before choosing whether to clear local ledger history.
- `/gbm debug sync` prints the local live player identity, the last decoded sync envelope, the last sync accept or reject reason, and the currently stored peer keys for the active guild so two-client AceComm investigations can confirm whether traffic is landing under the expected `Character-Server` identity.
- Sync guild resolution now treats both `Unknown` and `Unknown Guild` as placeholders, so login hello, manual sync actions, request publishes, and the `Options -> Sync` peer table can promote into the real live guild before request or ledger sync traffic is validated.
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
8. Optionally run the companion Wowless smoke lane with `.\tools\test\run-wowless.ps1` after setting up the sibling repo [ziriuso/GBankManager-wowless-smoke](https://github.com/ziriuso/GBankManager-wowless-smoke). The companion report records the selected Wowless product and per-product fallback attempts.
9. Copy both `GBankManager` and `GBankManager_ItemData` into your WoW Retail `Interface\AddOns\` folder, or use `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail`.
10. Use `/gbm` to open the UI you have access to:
   - full-shell users land in the officer shell
   - request-only users land in the trimmed request shell on `Requests`, with `Options` and `About` still available
   - first-run users now see a role-aware walkthrough when opening from `/gbm` or the minimap button
11. Use `/gbm help` to print the currently supported player-facing slash commands in chat.
12. Use `/gbm ui` to open the accessible shell without forcing a scan.
13. Use `/gbm request` to open the request workflow directly.
14. Use `/gbm scan` while the guild bank is open to exercise the scan flow.
15. Use `/gbm test smoke` for workflow smoke and `/gbm test unit` for the in-client unit lane after copying the addon into WoW.

## Release Automation

- Git tags matching `v*` now drive release packaging through `.github/workflows/release-curseforge.yml`.
- The release workflow runs `.\tools\lua\lua.exe .\tests\run_all.lua`, builds one combined zip containing both `GBankManager/` and `GBankManager_ItemData/`, uploads that zip to the single CurseForge project, and attaches the same zip to the matching GitHub Release.
- A repo-local release skill lives at `docs/skills/gbankmanager-release-operator/SKILL.md` for normal publish handling plus failed-release follow-up.
- The companion Wowless smoke lane lives in [ziriuso/GBankManager-wowless-smoke](https://github.com/ziriuso/GBankManager-wowless-smoke) and can be used alongside this repo for addon-load and smoke verification.
- Tag naming controls the release channel:
  - `v0.9.0-alpha.1` -> CurseForge `alpha`
  - `v0.9.0-beta.1` -> CurseForge `beta`
  - `v1.0.0` -> CurseForge `release`
- Configure the release workflow with:
  - GitHub Actions secret `CF_API_TOKEN`
  - GitHub Actions variable `CF_PROJECT_ID`
  - optional GitHub Actions variable `CF_GAME_VERSION_IDS`

## Next Roadmap

The next planned work after the completed pre-polish workflow block is:

1. Review addon communication and sync behavior end to end, including hello peer discovery, accepted updates, rejected forged payloads, request propagation, approval-created Minimums side effects, and guild-bank scan or ledger status noise.
2. Do the release/install sanity pass for the current beta artifact flow, confirming the combined package installs both addon folders and the About/version text matches the package.
3. After those two, return to the shelved UI polish refinement pass from [docs/ui-polish-suggestions.md](docs/ui-polish-suggestions.md) and the longer-term art-pack follow-up.

### Current Remaining Follow-Up

- Passive guild-bank ledger refresh now follows the working `GuildBankLedger` self-chaining cadence more closely; continue live validation around new item and money rows after `/reload` with the bank already open.
- `/gbm debug ledger` is available for ledger investigations; run it while the guild bank is open on `Log` and `Money Log` if live Blizzard rows are visible but GBankManager imports `0 item rows, 0 money rows`. If older local history or fingerprints are suspect, clear only `Guild Bank Log Data` from `Options -> Data` and rescan from a clean ledger.
- `/gbm debug sync` is available for live sync investigations; run it on both clients after login hello, after `Sync Requests`, and after creating or approving a request when `Options -> Sync` stays empty or chat reports an ignored sync snapshot. Compare `characterKey`, `actorCharacterKey`, `peerCharacterKey`, and `peerKeys` directly to confirm both clients are storing peers and actor context in `Character-Server` form.
- If `/gbm debug sync` reports `wrong_guild` while the client is visibly in a guild, check whether the stored root key is `Unknown Guild`; the sync layer now treats that placeholder the same as `Unknown` and promotes the runtime root from the payload guild key or live guild before validating the message.
- Live/manual sync sanity still needs a pass against real guild peers after install.

### Recently Completed

- Scan snapshots now persist `itemRows` alongside aggregate `items`, using `itemID|TAB|tabName` row identity for one row per bank tab while preserving aggregate totals for diff and planning.
- Inventory and Minimums `Show All` now consume tab-scoped scan rows so shared items render with the correct per-tab quantity.
- Inventory and Minimums now share the same table layout: `Item ID`, `Tier`, `Item`, `Bank Tab`, `Current`, `Restock`, and `Minimum`, with the Item column widened to use the old right-side whitespace.
- Minimums uses the shared table header/filter controls instead of the old bottom search box, and its footer is a compact three-button action strip rather than a boxed editor panel.
- Requests never auto-approve. Officers/admins cannot approve their own requests; only the Guild Master can manually approve their own request through the same workflow action as any other approval.
- The officer-facing Requests tab is now `Requests`, focused on workflow management with shared table search and a request-list/details-modal flow.
- Request-only access now uses a smaller end-user shell with `Guild Bank Manager` in the header, `Requests` plus `Options` plus `About` navigation, a four-column own-request status table, row-click details, request cancellation for pending own requests, and a three-step `New Request` wizard with a progress rail, preview card, quantity steppers, and quantity/reason confirmation flow. `/gbm` opens that shell on `Requests` without auto-opening the wizard, while `/gbm request` still jumps straight into request creation.
- Request approval now requires the approver to choose a Bank Tab, persists the Decision Note back into request details, and immediately saves/updates an enabled tab-scoped Minimums rule for the requested item and amount.
- Request details now show Requested By above Date Requested, keep Updated By, Date Updated, and Decision Note at the bottom of the fixed-row detail list, hide the decision-note editor after approval or denial, block click-through while request modals are open, normalize request history actors to character names, and keep shared table scrollbars inside the table viewport.
- Request deletion is now a distinct permission in the guild auth model, and authorized users can delete a request directly from the request-details workflow popup.
- Requests now highlights the active bottom filter, keeps `Add` on the far left, right-aligns the `All`, `Pending Approval`, and `Pending Fulfillment` filters, uses the shared table height, and keeps the `Date Fulfilled` filter within bounds.
- Requests now also includes a `Completed` filter and a left-side `Refresh` action beside `Add Request`.
- Requests and the shared search/details flow now route visible item rendering through stored item hyperlinks when available, keep plain-text fallback names when they are not, render Request Details quality inline beside the item name instead of reserving a separate row, remove the separate quality row from the wizard preview, and persist trusted `itemLink`/`itemString` metadata when a request is created from the shared selector.
- The item-hyperlink migration is live-regressed after `/reload`: Minimums, Requests, Request Details, New Request, and Exports now use the shared item display with inline crafted-quality icons, and the required `244559` anchor case is covered by the completed live regression pass while CSV exports continue to preserve numeric `Tier` values.
- Exports now shows `Excess Stock`, uses `None` for missing alternate stock, renders crafted-quality icons in the visible `Item Tier` column, and emits the newer Auctionator shopping-list line format while keeping numeric tier values for CSV-style outputs.
- Exports now presents the supported outputs as four action cards: `Auctionator`, `TSM`, `CSV`, and `Shopping List`, while keeping the generated formats unchanged.
- The shell navigation is now ordered as `Dashboard`, `Inventory`, `Minimums`, `Requests`, `Exports`, `History`, `Bank Ledger`, `Options`, and `About`, with refreshed iconography for each section.
- The `About` panel now shows the tagged version plus a local build stamp, restores `Author: Zirleficent-Stormrage`, keeps `Guild` on its own line with extra spacing, and retains the `/gbm help` hint.
- First-run onboarding now uses separate manager and request-only walkthroughs, auto-opens from `/gbm` or the minimap button until completed or suppressed, can be replayed by full-shell users from `Options -> Appearance`, recenters every time it reopens, can be dragged around the shell while it stays open, and now uses a simpler footer with no `Skip` action plus a step-one-only `Do Not Show Again` button.
- `Options -> Sync` now shows a peer table with `Character`, `Last Time Seen`, and `Last Time Synchronized`, stores peer identity in `Character-Server` form, and `/gbm sync`, `/gbm sync requests`, `/gbm sync minimums`, `/gbm sync ledger`, and `/gbm sync all` now route through the same 60-second manual sync cooldown layer while ignoring self-origin sync payloads.
- Inbound addon sync now only accepts `GUILD` channel traffic for request, request-snapshot, minimums, ledger, and hello message families; same-guild payloads delivered over `WHISPER` or other channels are ignored.
- Fresh clients now promote an `Unknown` local guild root from live guild info or the first accepted guild-scoped sync payload, so valid request sync traffic is not dropped just because SavedVariables have not been initialized under the real guild key yet.
- Dashboard metric cards and export action cards now carry dedicated large icons, and the export cards now use `Generate` or `Open List` CTA labels closer to the target mockup.
- Dashboard `Critical Shortages` now reads from the configurable stock threshold instead of always counting every below-minimum row as critical.
- The near-literal mockup fidelity pass now also drives the live shell palette and chrome more aggressively: the `Default` preset is darker and bluer, nav buttons carry left accent rails, dashboard quick actions use icon-led primary buttons, and shared sliders now render through a more deliberate track/thumb treatment instead of the earlier plain boxed controls.
- About now renders through a centered branded panel instead of the old plain body-text fallback, and the shared table shell now uses dedicated header/filter/viewport variants plus semantic alternating row tokens rather than generic panel tinting.
- Minimums now uses separate `Enabled Only` and `Show All` buttons with an obvious active-state highlight instead of a single toggle label.
- The guild auth policy string now carries the shared Restock Default plus updater metadata, pulls from Guild Info on load and guild updates, refreshes the Options restock input from live Guild Info data, and appends policy-update history rows that now show in the History view.
- `Options -> Auth` now includes a `Select All` helper beside the compact `Policy String`, so officers can focus, highlight, and copy the full Guild Info snippet without manual drag selection.
- `Options -> Blacklist` is now a read-only roster view with short ordered-list instructions for the shared `[GBMBL]` officer-note tag plus a `Refresh` action placed below the parsed-member list, and guild-shared blacklist membership now comes from parsing those officer-note tags instead of the Guild Info policy string.
- The Blacklist tab now reserves extra panel padding beneath the parsed-summary text so the footer summary does not crowd the surrounding chrome.
- Dashboard mismatch investigation did not land a code change: the obvious local machine paths did not reveal a live SavedVariables file, and the dashboard plus Exports count paths both reduce from the same demand-plan shape, so live repro should come before any dashboard fix.
- Dashboard `Pending Requests` no longer shows the retired `auto-matched fulfillments` note, and the old `SUGGESTED_FULFILLED` request state is no longer part of the active request workflow.
- Opening the guild bank now auto-starts a scan when at least 10 minutes have elapsed since the last successful scan, and the retry path now stays alive long enough for delayed tab or slot metadata on reopen. Fresh-open auto scans now wait briefly between queried tabs and ignore suspicious partial snapshots when a previously populated tab reads empty, so a cold automatic scan cannot replace a fuller saved snapshot; opening the bank also forces one ledger scan pass even when the ledger interval is still fresh, and manual slash or button scans still work immediately.
- Synced request create and update messages now append local history rows on receiving clients, approved request sync recreates the tab-scoped Minimums side effect on receivers, request-management actions now publish one guild-scoped addon message instead of whispering resolved guild recipients, and request conflict resolution now prefers higher-authority updaters before timestamp tie-breaks.
- The auth policy string now compacts updater identity with a hash token instead of storing the full updater name in Guild Info, while still preserving local updater attribution when it can be rehydrated from live or previously known state. The `Policy String` helper text in `Options -> Permissions` is now written as a short step list so the manual Guild Info publish flow is easier to follow in game.
- Compact auth-policy imports no longer carry blacklist membership. Guild-shared blacklist membership now comes from appended officer-note tags, while learned blacklist reasons stay local and continue to travel through addon sync snapshots.
- Blacklist entries now normalize to `Character-Server`, migrate legacy server-first ordering, and render in the read-only Blacklist tab directly from guild-roster officer-note parsing.
- The read-only Blacklist tab no longer attempts officer-note writes. To blacklist or unblacklist a member, edit that member's officer note in Guild & Communities and add or remove `[GBMBL]`, then refresh guild data or `/reload`.
- `Options -> Data` now keeps the retention and scan dropdown titles aligned on one baseline, sizes the three destructive clear-data buttons to one shared width with centered labels, and keeps the full save plus clear-data stack inside the visible panel chrome.
- Request creation now refreshes guild-backed blacklist state before submit, so a newly tagged blacklisted member is denied request creation as soon as the latest officer-note parse is available on that client.
- History rows now build newest-first by timestamp so recent approvals, minimum edits, and auth changes stay at the top of the table.
- History now keeps the visible table compact with `When`, `Category`, `Item`, `Action`, and `Who`, while `Old Value` and `New Value` move into a row-click `History Details` modal so long audit values stop overflowing the grid.
- The sidebar branding footer now uses a theme-specific crest/logo instead of the older text identity card, hides completely when the sidebar is collapsed, and crops the shipped crest art so the visible logo fills more of the footer zone without distortion.
- Crafted-quality rendering now normalizes the low-tier and max-tier atlas variants from the bundled addon data path without changing stored data.
- Crafted-quality rendering now resolves from one shared family-aware rule instead of per-view atlas swaps: Inventory keeps its dedicated two-rank texture handling, while Minimums, Requests, Exports, and the manual shopping list prefer the bundled canonical single-silver-diamond / gold-pentagon family for true two-rank rows, only consult live reagent-quality atlases if the canonical item-aware path is unavailable, and use the older reagent-medal atlas as a final fallback. Five-rank families stay on the default atlas set and non-crafted rows stay blank.
- The shell now supports a token-backed theme manager with local-only presets (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), per-theme crest art, a minimap launcher with a local show/hide toggle, a single `UI Scale` control that drives both shell scale and shared table density across a 90%-120% range, built-in WoW `UISliderTemplate` sliders for shell and modal opacity, collapsed-nav icons, stronger active-state glow for nav plus workflow filter buttons, and surface-only opacity so text plus controls stay crisp while the shell or modal art fades.
- The UI modernization pass is now in a committed checkpoint state: reusable shell, theme, table, request-wizard, export-card, and Options-tab scaffolding are in place, but the live addon still needs substantial art-pack-driven polish before it matches the Alliance mockup or broader visual guide literally.
- The request-only workflow panel and shared request wizard are mid-modernization: the member-facing launcher now presents the three-step guided flow, and the wizard exposes a visual progress rail plus a request preview card without changing request persistence or sync behavior.
- Requests filters, request details actions, the request-only launcher, wizard navigation, and Minimums modal actions now all route through dedicated shared button variants (`primary`, `secondary`, `tab`, `icon`, `danger`) instead of the earlier one-style-fits-all bordered buttons.
- Appearance sliders now use a safer drag-release surface and a more polished thumb or track treatment so releasing the mouse off the bar does not leave the slider latched into drag mode.
- Shell scaling now clamps shared table height inside the content area so footer action strips stay visible, keeps the top-bar scan and status controls from overlapping at smaller scales, and preserves the floating manual shopping list across tab switches or shell close while remembering its saved position.
- Shared table filters now inset slightly inside each column so adjacent search boxes keep visible spacing and a softer edge treatment instead of touching edge-to-edge.
- The addon shell now opts into top-level window ordering so other dragged UI can come above it, and clicking back onto the addon brings the shell and its registered modals forward again.
- Dashboard `Top 10 Most Used` now uses ledger-backed withdrawal rankings first, with a ten-row panel instead of the older top-five fallback.
- `Bank Ledger` is now a live shared-table workspace with `Item Log` and `Money Log` modes, action/date filters, CSV export, and summary lines for item movement plus gold in, gold out, and repairs over the filtered range.
- Minimums now groups staged rows at the top of the table, exposes `ADD` / `EDIT` / `DELETE` row badges, shows a staged-change summary in the footer, and reveals `Revert All` only when draft changes exist.
- `/gbm test unit` now also covers blacklist normalization, officer request-queue prioritization, and unresolved minimum repair-row ordering so more pure-domain regressions can be caught in-client without relying on workflow smoke alone.
- `/gbm test smoke` now follows the real Minimums modal add flow during its draft-stage check and hard-resets request selector state before the confirmed-selection gating check, so those two live smoke results match the current product workflow instead of the retired footer-editor path.
- Maintainers now have repo-local deployment helpers plus a small local PowerShell maintainer launcher for target selection, saved status, refresh, and deploying both addon folders into `Retail`, `PTR`, or `Beta`.
