# Manual Test Checklist

## Current Focus Order

When resuming product QA after this checkpoint, prioritize the next manual checks in this order:

1. Recheck the dashboard `Ready to Buy` mismatch against real live SavedVariables before any code fix, plus future validation for a dedicated `Critical Shortages` dashboard card
2. Validate the completed Guild Info auth slice end to end: Restock Default propagation, preload on load or refresh, explicit `Character-Server` blacklist guidance, correct last-updated actor metadata, and policy-history visibility or sync behavior
3. Validate guild-bank-open auto-scan with the 10-minute throttle and manual-scan coexistence
3a. If the guild bank opens before tab metadata is fully ready, confirm the auto-scan still wakes and begins once `GUILDBANK_UPDATE_TABS` fires.
4. Validate guild-client sync behavior for chat milestones, history, requests, approval-created minimum side effects, and permission-policy updates
5. Validate the landed UI polish foundation, including the native-paneled shell pass, soft nav buttons with stronger selected state, slimmer actions, segmented tabs, colored themes, scalable theme or sizing controls, separate shell-vs-modal opacity slider behavior, and the shell yielding behind other dragged UI until clicked again
6. Validate the broadened in-game unit-test lane
7. Maintainer deployment/status workflow and target-path UI

1. Copy both `GBankManager` and `GBankManager_ItemData` into `Interface/AddOns`.
2. Run `/reload`.
3. Open the guild bank.
4. Run `/gbm ui`.
5. Confirm the main frame opens on the dashboard view.
6. Confirm the sidebar can collapse and expand without losing the active view.
7. Confirm the top bar shows scan metadata and action status text.
7a. Confirm the top-bar `Last scan` text includes an abbreviated timezone when a scan exists.
7b. Confirm the top toolbar uses a short timezone abbreviation like `EDT` or `EST` and does not wrap a long timezone name such as `Eastern Daylight Time`.
8. Confirm inventory filtering returns matching items.
9. Confirm history filtering can narrow by change type and actor.
10. Confirm selecting each export button opens the export modal instead of trapping output inline in the Exports panel.
10a. Confirm Exports presents `Auctionator*`, `TSM*`, `CSV`, and `Shopping List` as distinct action cards with one-line descriptions before opening any modal output.
10b. Confirm those four export cards each show a large icon and use `Generate` or `Open List` call-to-action labels instead of the older long button names.
10c. Confirm there is no ghost container box behind the four export cards, that the card descriptions plus CTA buttons have enough breathing room instead of feeling cramped, and that the shared note `* Does not provide Quantity in Export.` appears below the cards.
11. Confirm the sidebar includes Minimums, Requests, Exports, About, and Options without changing the shell style.
11a. Open `About` and confirm it now renders through a centered branded panel with crest art, addon name, semantic version plus build stamp, author, guild identity, and `/gbm help` hint instead of the old plain text block.
12. Add a recurring minimum and confirm saving the same item and scope updates the existing rule.
13. Confirm the dashboard purchase summary changes when minimums and approved open requests change.
13a. Confirm the dashboard now shows four metric cards (`Last Scan`, `Pending Requests`, `Ready to Buy`, `Critical Shortages`) plus separate `Top 10 Most Used`, `Recent Activity`, and `Quick Actions` panels.
13b. Confirm the dashboard `Quick Actions` row is trimmed to `Add Minimum`, `Create Request`, and `Export Data`, and confirm `Create Request` opens the request workflow immediately.
13c. Click `Create Request` from Dashboard and confirm it opens the request wizard modal, not just the `Requests` tab underneath.
13c. Confirm each dashboard metric card now shows a large icon and still keeps the card title, primary value, and subtitle readable at the default shell scale.
14. Submit a member request and confirm it begins as `PENDING`.
15. Submit an officer/admin request and confirm it also begins as `PENDING`; no role should auto-approve.
16. Confirm a member-scoped request list only shows rows for that requester.
17. Log in on two addon-enabled guild characters and confirm a `SYNC_HELLO` is sent on login.
18. Approve a request on one character, relay the sync payload, and confirm the second character records the incoming message state.
19. Create conflicting request records and confirm officer authority wins over a newer member update.
20. Capture a manual recovery payload and confirm it can be replayed without Lua errors after a `/reload`.
21. With the guild bank open, verify a scan queues only tabs the current character can view.
21a. In `Options -> Data`, note the chosen `Scan Interval`, then close and reopen the guild bank after more than that interval since the last successful scan and confirm the scan starts automatically without using `/gbm scan` or the `Scan Bank` button.
21b. Reopen the guild bank again inside the configured `Scan Interval` window and confirm auto-scan does not restart, then trigger `/gbm scan` manually and confirm manual scan still runs immediately.
22. Change bank contents between scans and confirm the dashboard and history reflect the new snapshot.
22a. Place the same item in two visible guild-bank tabs, run `/gbm scan`, and confirm Inventory shows one row per tab with each row's tab-specific quantity.
22b. With the same scan, open Minimums in `Show All` and confirm the same shared item appears once per tab with the matching per-tab current quantity.
23. Generate Auctionator, CSV, and TSM export text from the same demand rows and confirm each output formats correctly in the export modal, with no nested inner text box around the output area.
23a. For Auctionator specifically, confirm the generated import string uses the current caret-delimited list format (`ListName^Item One^Item Two`) instead of the old newline-only helper text.
24. In the export modal, use `Select All` and confirm the full output highlights correctly inside the scrollable edit box, manual mouse drag selection still works afterward, and visible guidance/status feedback explains the manual `Ctrl+C` step before closing the modal.
25. Open the Inventory view with enough rows to overflow and confirm the scroll controls move through the table without blanking the header.
26. Resize the inventory name column and confirm the wider width is reflected immediately while neighboring columns stay readable.
27. Use the inline inventory column filters and confirm filtering by `Item`, `Bank Tab`, and `Restock` narrows the visible rows immediately.
27a. Use the Inventory `Item ID` column filter and confirm an exact item ID narrows the table to the matching row.
27b. Open Minimums and confirm Inventory and Minimums use the same column order: `Item ID`, `Tier`, `Item`, `Bank Tab`, `Current`, `Restock`, and `Minimum`.
27c. Open Minimums and confirm filtering happens through the shared table filter row, including `Item ID`, `Item`, and `Bank Tab`, with no old bottom search box visible.
27d. Confirm the Minimums table height matches Inventory and the bottom area is only a clean raised action strip (`Add`, `Save All`, `Enabled Only`, `Show All`) without the old boxed footer panel or buttons hugging the bottom edge. After staging a change, confirm the footer also shows a staged-change count and reveals `Revert All`.
28. Confirm the inventory quality column shows a quality marker for known uncommon-or-better items and stays blank for items without known quality.
29. Confirm long item names and long tab lists clip with an ellipsis instead of spilling into adjacent inventory columns.
30. Run a scan, `/reload`, and confirm both the inventory snapshot and last-scan status still appear before starting a fresh scan.
31. Open the History tab and confirm request approvals, minimum changes, and auth-policy updates render as audit-style rows with actor, old value, new value, and timestamp columns.
31a. Open `Bank Ledger` after a successful guild-bank scan and confirm it defaults into the shared table shell with `Item Log` mode, action filtering, a preset `Date Range` dropdown, summary lines, and `Export CSV`. Confirm the item table now shows `Date`, `Who`, `Action`, icon `Tier`, `Item`, `Quantity`, `Tab`, and `Moved From`. When the ledger follow-up runs, confirm chat reports both `Guild bank ledger scan started.` and a matching `Guild bank ledger scan finished (X item rows, Y money rows).` completion line.
31aa. Click `Scan Bank`, wait for the main bank scan plus the ledger follow-up to finish, then click `Scan Bank` again without changing the live guild-bank logs. Confirm the second run does not duplicate existing ledger rows, and confirm manual `Scan Bank` still forces the ledger follow-up even when the configured `Scan Interval` would normally throttle auto scans.
31b. Switch `Bank Ledger` to `Money Log` and confirm the shared table changes to `Date/Time`, `Who`, `Action`, and `Amount`, with the hidden item-only columns removed from the visible layout.
31c. In `Bank Ledger`, click the `Action` control and confirm a real dropdown opens beneath it instead of cycling in place. Change the action filter and date range and confirm the filtered rows, summaries, and CSV output all stay in sync. The bottom summaries should stay reduced to `Deposits | Withdrawals | Moved` on the first line and `Gold In | Gold Out | Repairs` on the second line, and the date range should update those totals immediately.
32. Open the Requests tab and confirm pending requests appear ahead of approved-open requests, with date requested, requester, item ID, item name, quantity, status, and date fulfilled columns rendered in the shared table shell.
32a. Confirm the full-shell navigation labels the officer/admin surface as `Requests`, does not show inline `Create Request` controls, and no longer shows the old top workflow actions box.
32b. Confirm the `Requests` table uses the shared filter row and can search by `Item Name` and exact `Item ID`.
32c. Confirm the bottom Requests filter strip reads left-to-right as `All`, `Pending Approval`, `Pending Fulfillment`, and `Completed`, keeps the active filter highlighted, right-aligns those filters as a group, and keeps `Add Request` plus `Refresh` anchored on the far left.
32d. Open a deletable request in `Requests`, confirm the details popup exposes `Delete` only when the viewer has the request-delete permission, click it, and confirm the row disappears without Lua errors.
33. Approve an open request, run a bank scan with enough quantity for that item, and confirm the request becomes `Fulfilled` with Date Fulfilled populated. Run another scan and confirm fulfilled requests are no longer reprocessed.
33a. Seed an `APPROVED` / `OPEN` request that already has `approvedBankTab` or `tabName` but is missing `minimumRuleKey`, then open the addon and confirm it self-heals by creating or rebinding the matching tab-scoped minimum automatically.
34. Follow the README local-development steps on a fresh UI reload and confirm `/gbm ui` and `/gbm scan` still work in sequence.
35. Open Minimums and confirm there is no old bottom `Search` label or search input, and the separate `Enabled Only` and `Show All` buttons fit cleanly without clipping while the active filter stays highlighted.
36. Select an existing saved minimum row and confirm changed rows tint yellow, deleted rows tint red, and newly staged rows tint green in the live client.
37. Select an existing saved minimum row and confirm the remove and undo actions use icon buttons instead of placeholder glyph text.
38. Select an existing saved minimum row and confirm `Bank Tab` stays read-only while `Restock` and `Minimum` still edit inline.
39. Select any actively edited minimum row and confirm the underlying inline cell text is hidden behind the live editor controls instead of ghosting through.
40. Click `Add` in Minimums and confirm the modal labels `Search Item ID`, `Search Item Name`, `Selected Item`, `Minimum`, and `Matches` are visible and do not overflow the dialog.
41. Search for an item name that has multiple quality variants and confirm the modal shows a clean stacked scrollable results list instead of jumbled buttons, with the higher crafted tier listed before lower crafted tiers for duplicate-name variants. Then search by exact item ID and by partial token queries such as `flask of`, `flask of the sha`, `flask sun`, `flask magister`, and `thalassian phoenix oil` in both Minimums and Requests and confirm the selected-item area shows the resolved item name plus a crafting-quality icon whenever the chosen catalog row carries one.
42. Type only one character into `Search Item Name` in Minimums and Requests and confirm no results list opens yet. Then type a second character and confirm the scrollable results list activates.
43. Search for an item that exists in the bank and in the WoW client item cache and confirm client-item results are still available alongside bank matches.
44. Click `Add` in Minimums, resolve a catalog item, and confirm the search modal closes into the centered `Minimum Details` modal instead of staging a row directly into the table.
45. In the `Minimum Details` modal, confirm the selected item name and item ID carry over from the add-search selection, and for existing rows confirm clicking the row opens the same modal instead of the old footer editor with the current `Bank Tab` prefilled as read-only text.
46. In the `Minimum Details` modal, confirm new rows still choose `Bank Tab`, existing rows cannot edit `Bank Tab`, `Restock` and `Minimum` remain editable, the footer editor is no longer the primary editing surface, and a missing `Bank Tab` warning turns red for new rows.
47. Use the Minimums search box with and without matches and confirm the empty-state message remains clear when filters hide all rows.
48. Click a saved minimum row without editing it and confirm the row does not immediately show an undo state until a real change is made.
49. Confirm the deprecated `Restock Source` column is fully gone from Minimums, with no blank ghost header or stray extra column after `Minimum`.
50. Confirm staged and saved Minimums rows are now edited through the centered details modal rather than the old footer editor or inline row widgets.
51. Confirm draft row colors communicate state clearly before `Save All`: green for newly added rows, yellow for edited rows, and red for removed rows.
51a. Confirm staged Minimums rows stay grouped at the top until saved and show visible `ADD`, `EDIT`, or `DELETE` badges.
52. Search for a non-bank item using a partial name from the bundled item catalog or a prior exact resolution and confirm the add modal can still surface it outside the current guild bank snapshot.
53. If a controlled debug build intentionally skips `GBankManager_ItemData`, confirm the search UI reports the bundled item database as unavailable instead of showing a misleading sparse local-only match list.
54. Confirm known crafted items still show a crafted tier in Minimums even when the current snapshot lacks tier data, using the bundled catalog as fallback for `craftedQuality` and `craftedQualityIcon`.
55. Open the shell tabs after a `/reload` and confirm the current navigation remains `Dashboard`, `Inventory`, `Minimums`, `Requests`, `Exports`, `History`, `Bank Ledger`, `Options`, and `About` with no `Targets` tab returning.
56. Log in as Guildmaster and confirm `/gbm ui` opens the full shell, `/gbm request` opens the request view, and the `Options` auth panel can save rank capability changes.
57. Configure a member rank with no `full_ui` access but with `request_submit`, then confirm `/gbm ui` opens the lightweight Requests surface with no officer action controls.
57a. Run `/gbm request` and confirm the smaller end-user workflow shows `Guild Bank Manager` in the header, an own-request table with `Item ID`, `Item Name`, `Quantity`, and `Status`, plus a `New Request` button that opens a three-step request wizard with a progress rail.
58. Remove `request_submit` from a member rank and confirm the lightweight Requests surface becomes read-only with the `You do not have permission to submit requests.` banner.
59. In the request wizard, confirm Step 1 uses the shared item search, Step 2 captures quantity and reason with working `+` / `-` steppers, Step 3 requires a preferred Bank Tab, Step 4 reads back Item Name, Quality, Quantity, Bank Tab, and Reason, and Submit creates a pending request.
59a. In `Requests`, confirm clicking a request row opens the details modal with workflow actions, an explicitly labeled `Decision Note` box while pending, fixed aligned label/value rows with tighter label/value spacing, `Requested By` above `Date Requested`, and bottom detail rows for `Updated By`, `Date Updated`, and `Decision Note`. Confirm officers/admins cannot approve their own requests, and Guild Master can approve their own request only by explicitly clicking the approval workflow action.
59ab. In `Requests`, confirm `All`, `Pending Approval`, `Pending Fulfillment`, and `Completed` render as tab-like pills, while `Add Request` and `Refresh` render as separate secondary action buttons instead of matching the filters.
59aa. For an approvable request, confirm `Approve` is disabled until the approver chooses an `Approval Bank Tab`. Enter a Decision Note, approve, and confirm the details modal stays open, hides the decision-note editor, shows the updated status plus bottom `Updated By`, `Date Updated`, and saved `Decision Note`, keeps workflow buttons aligned horizontally with `Close`, and Minimums now has an enabled tab-scoped rule for the requested item, requested quantity, and chosen bank tab. Repeat with a rejected request and confirm the saved decision note remains visible but the editor is hidden.
59b. In `/gbm request`, click a pending own request and confirm the details modal shows Item Name, Quality, Quantity, Submission Note, Status, Decision Note, and Date Requested in local time with an abbreviated timezone and no `(Local)` suffix. Open `New Request` while rows are visible and confirm clicks inside the wizard do not open request details underneath. Confirm the request author can cancel it before approval/fulfillment and that the cancel syncs back to admin clients.
59c. Open Inventory, History, Minimums, Requests, and Exports with enough rows to scroll, and confirm the shared table viewport ends before the slim scrollbar, with the scrollbar just outside the table frame and not overlapping the rightmost column.
59ca. In Inventory, History, Minimums, Requests, and Exports, confirm the shared table header, filter strip, and viewport all retain the carved mockup styling and alternating row backgrounds instead of falling back to one generic boxed panel look.
59caa. In those same table views, confirm alternating rows now have clearly stronger odd/even background contrast even with the flatter shell pass, and confirm rows rely on tonal banding plus a subtle bottom separator rather than hard boxed side borders.
59cab. In Inventory, History, Minimums, Requests, and Exports, confirm the shared search/filter inputs read darker than the filter strip behind them and stay visually distinct at a glance instead of blending into the table band.
59cb. Compare the full live shell against the current mockup target and confirm the main frame, sidebar, top header, metric cards, export cards, and Options tabs all read as layered matte panels with thin gold borders, subtle header bands, and active nav accent rails instead of plain tooltip-style rectangles.
59cc. Confirm the shell chrome no longer falls back to the older boxed-in-boxes treatment: the top toolbar should not draw a full framed rectangle, the main content band should not draw its own full border box, and flatter panels or cards should not show the older inset header strip unless the surface explicitly calls for it.
59cd. Confirm the nav rows, table header band, filter band, table viewport, and flatter dashboard support panels do not rely on full backdrop borders for their shape, and instead read as softer surfaces with separators or accent rails.
59d. Open Exports and confirm the table columns are `Item ID`, `Item Tier`, `Item Name`, `Bank Tab`, `Amount to Stock`, and `Excess Stock`; confirm `Item Tier` shows the crafted-quality icon when available, `Excess Stock` shows either `None` or the alternate guild-bank tab with the highest quantity, and clicking that value opens the modal listing all other bank tabs and quantities.
59e. Click `Auctionator` and confirm the modal asks whether to buy all rows or only rows `Not In Guild Bank`; confirm each choice changes the generated shopping-list output. Click `CSV` and confirm the modal shows comma-delimited text with the visible header row. Click `TSM` and confirm it uses the same all-vs-missing choice flow and emits a comma-delimited item-ID import list.
59f. Click `Shopping List` and confirm it opens a movable checklist window with quality, item, and quantity rows plus the note `Does not sync back to addon.` Check and uncheck a few rows and confirm they strike through only for the current window session and use plain checkbox marks instead of bracket text.
59fa. Confirm the manual shopping list line-breaks `Does not sync back to addon.`, uses readable built-in checkboxes, shows the brighter reagent-quality icon for two-rank low/max items instead of raw `T2` text or the dull chat icon pair, stays open when switching tabs or closing the main shell, and reopens in its last moved position.
59g. Add or load a Minimums row whose Bank Tab shows `GLOBAL`, or a legacy approved request that still lacks both `minimumRuleKey` and bank-tab data, confirm it sorts to the top in orange, clicking it requires selecting a Bank Tab, and `Save All` blocks with `Bank Tab must be set on Orange Rows.` until the row is fixed.
59ga. In the Minimums details modal, confirm `Confirm` uses the emphasized positive action treatment, `Remove` uses the destructive treatment, `Undo` uses the compact icon treatment, and `Cancel` uses the secondary treatment.
59h. In `Options`, confirm the local appearance controls now include theme presets (`Default`, `High Contrast`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`), a single `UI Scale` slider with a 90% to 120% range, a `Show Minimap Button` toggle, and separate shell-vs-modal opacity sliders with 0% to 100% ranges. Change each control and confirm the shell updates immediately without misaligning headers, rows, footer strips, top-bar buttons, modal chrome, or the themed sidebar crest.
59h0. While changing `UI Scale`, confirm the dashboard metric cards and support panels resize with the shell instead of staying at their original fixed dimensions.
59h1. Confirm `UI Scale` now lives in the right-hand slider column above `Shell Opacity` and `Modal Opacity`, and confirm `Show Minimap Button` now sits directly below the theme preset grid.
59h2. Confirm `UI Scale`, `Shell Opacity`, and `Modal Opacity` all use the same slider width, and confirm there is visible bottom padding under `Modal Opacity` inside the panel chrome.
59hc. Lower `Shell Opacity` and `Modal Opacity` and confirm the background or art surfaces fade while labels, icons, and buttons remain crisp instead of the entire frame dimming together.
59ha. In `Options`, drag each slider directly and confirm the updated slider chrome feels deliberate in motion: the thumb should not get stuck after releasing off the bar, the track should stay visually aligned, and the new darker `Default` baseline should match the mockup more closely than the older lighter shell.
59hb. In `Options`, confirm the top-level tabs now read `Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, and `Data`, and that switching tabs swaps a single content pane instead of rendering one long stacked settings page.
59hbd. In `Options -> Stock Settings`, confirm `Restock Default` and `Critical Shortage Threshold` save together, and that the threshold explanation makes it clear critical means current stock is at or below the chosen percentage of minimum.
59hba. Confirm the Options tabs read as soft segmented buttons rather than heavy framed pills, and confirm the footer/admin/request action buttons feel slimmer than the older shell pass while remaining clearly clickable.
59hbb. Compare `Requests`, `Minimums`, `Exports`, `Options`, and request/minimums details modals, and confirm neutral action buttons now contrast clearly from the surface behind them instead of blending into the same panel tone.
59hbc. Open any Bank Tab selector in Requests, Minimums, or Options rank selection and confirm the trigger reads like a distinct select control rather than another flat panel-colored button.
59ha. Confirm each appearance slider can be adjusted both by dragging or clicking the slider itself and by using the `+` / `-` buttons.
59hab. Drag an appearance slider, release the mouse off the bar, and confirm the slider stops dragging immediately instead of staying latched until another click.
59i. Collapse the sidebar and confirm nav icons remain visible, the active tab still glows clearly, and expanded mode still keeps the active nav and active workflow filter buttons visually stronger than inactive controls.
59ia. Expand the sidebar again and confirm the footer zone now shows only the theme crest/logo instead of the older character or guild text card, then collapse the sidebar and confirm the entire footer zone disappears cleanly.
59ib. Switch between `Default`, `Alliance`, `Horde`, `Legion`, `Nature`, `Pride`, `Void`, and `High Contrast`, and confirm the sidebar crest/logo swaps to the matching art for each theme, stays centered, fills the footer zone cleanly, and does not clip or stretch.
59ie. Toggle `Show Minimap Button` off and on in `Options -> Appearance`, confirm the minimap launcher hides and reappears immediately, confirm it uses the shipped custom minimap art instead of the old shell crest icon, and confirm clicking the launcher while the addon is already open closes the shell on the second click.
59if. In `Minimums` and `Requests`, confirm the lower action strips now use the same flatter fill and opacity treatment as `Bank Ledger` instead of the older darker boxed footer look.
59ic. Open the request wizard and confirm step 2 shows explicit `Quantity` and `Reason` labels inside the left content panel, the `-` / `+` buttons are the same size and style, and the search-result rows align the quality icon, `[Tn]` tier marker, and item text on a clean shared baseline.
59j. Open Exports with crafted items that are both present and absent in current bank stock, and confirm the visible `Tier` column uses the same quality symbol mapping in both states instead of swapping between mismatched icon families. Also confirm the `Tier` header text and `Excess Stock` column spacing no longer overflow.
59k. Open Inventory and Minimums and confirm the far-right `Minimum` header no longer collides with the frame edge at the default scale or at the largest supported shell scale.
59ka. Open Exports and Requests with only a few rows and confirm the shared scrollbar stays hidden until there is actual overflow.
59l. In `Options -> Auth`, confirm long policy-string helper or status text wraps cleanly inside the policy area and does not flow behind the blacklist controls.
59m. With two addon-enabled guild clients online, confirm login hello, accepted synced updates, and rejected forged updates emit compact chat-window feedback without spamming per-step noise.
59n. Open the addon, then drag another draggable WoW UI or addon frame over it and confirm that other frame can come above `GBankManager`; click back onto the addon shell or one of its modals and confirm it comes to the front again.
59o. Seed or capture ledger withdrawals for at least two items and confirm the dashboard `Top 10 Most Used` card ranks the higher total withdrawals first, with ten visible rows when enough data exists.
59p. Run `/gbm test unit` and confirm chat prints one overall `PASS` or `FAIL` summary plus individual check lines. If it fails, inspect `GBankManagerDB.testing.inGameUnit` after `/reload` and confirm the saved result payload includes the failing check IDs and details.
60. Add `[GBMBL]` manually to a guild member's officer note in `Guild & Communities`, click the `Refresh` button below the parsed blacklist member box in `Options -> Blacklist`, and confirm the member appears in the read-only parsed roster view.
60b. Confirm the parsed blacklist summary line still has visible padding beneath it and does not crowd the panel edge.
60a. Remove `[GBMBL]` from the same officer note, refresh guild data or `/reload`, and confirm the member disappears from the read-only Blacklist tab.
61. Create a request from a request-only member and confirm an officer/guildmaster client receives it through addon comms and can act on it from the full Requests shell.
61a. After tagging that requester with `[GBMBL]`, click Blacklist `Refresh` on the request-submitting client, try to submit another request, and confirm the request is denied immediately.
62. Save an auth-policy change on one officer-authorized client and confirm a second addon-enabled guild client receives the updated rank policy, learned blacklist reason data, Restock Default value, and a visible auth-policy history row.
63. In `Options`, change the auth policy, click `Save`, and confirm the status text explains that Guild Info publishing is now manual and does not claim the Blacklist tab writes officer notes.
64. In `Options -> Permissions`, confirm the `Policy String` helper copy now reads as short ordered steps, does not run into the save buttons, and `Select All` still highlights the whole snippet with visible copy guidance.
65. Copy the `Policy String`, paste it into the in-game `Guild Information` dialog, press `Accept`, then click `Refresh Guild Info` in the addon and confirm the same string reloads into the field, the `Last Update` metadata shows the correct actor, and the Restock Default input matches the guild-shared value.
66. Open the History tab after multiple request, minimum, and auth changes and confirm the newest timestamped row renders first.
66a. In History, confirm the visible columns are now `When`, `Category`, `Item`, `Action`, and `Who`, and that long audit values no longer overflow into cramped `Old Value` or `New Value` grid columns.
66b. Click a History row and confirm a centered `History Details` modal opens with the full old and new values, actor, action, item, and timestamp.
66c. In Inventory, History, Minimums, Requests, and Exports, confirm adjacent filter inputs keep a small gap between boxes and read as separate softer controls rather than one continuous hard-edged strip.
66d. On Dashboard, confirm the `Quick Actions` labels (`Add Minimum`, `Create Request`, `Export Data`) fit cleanly inside their buttons without clipping or running into neighboring actions.
66e. In `Options -> Stock Settings`, lower the `Critical Shortage Threshold`, return to Dashboard, and confirm the `Critical Shortages` card count drops when fewer items qualify as critical. Raise it again and confirm the count increases accordingly.
66f. In `Options -> Data`, click each of the three select controls and confirm a real dropdown menu opens beneath the control instead of the label just cycling in place. Choose new values for guild-bank ledger retention, history retention, and `Scan Interval`, save the settings, confirm the status text reports `Saved logs/history settings.`, confirm the save button stays inside the panel chrome, and confirm the chosen labels persist after closing and reopening the shell. Also confirm that the same saved `Scan Interval` governs both guild-bank-open auto-scans and direct ledger rescans.
66fa. In `Options -> Data`, confirm the three dropdown labels align cleanly on one row and that none of the controls drift outside the visible panel chrome.
66fb. In `Options -> Data`, confirm the three destructive clear-data buttons use the same width and that each label is visually centered.
66g. In `Options -> Data`, confirm the `Clear Data` section sits below the save row, and that `Clear Guild Bank Log Data`, `Clear Guild Bank Inventory Data`, and `Clear Completed Request History` each open a confirmation popup that explicitly says the action is irreversible.
66h. Run `/gbm` and confirm it opens the UI the player has access to. Then run `/gbm help` and confirm chat prints the supported slash-command list instead of opening a view or starting a scan.
66. Run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Get-ItemCatalogMaintainerStatus.ps1 -Target Retail` and confirm it reports the resolved client path, AddOns path, current sync status, last sync time, and build fields without PowerShell errors.
67. Launch `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Open-ItemCatalogMaintainer.ps1`, switch between `Retail`, `PTR`, and `Beta`, and confirm the launcher refreshes target status without requiring code edits.
68. From the maintainer launcher or CLI, run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh` and confirm it completes with `nextStep = "addon-rebuilt"` and no failure class. If the run is interrupted, rerun the same target with `-Resume` and confirm it continues from the saved progress state.
69. If PTR or Beta discoveries were exported from addon testing, run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath <path>` and confirm the manifest gains learned rows without overwriting existing confirmed rows.
70. Run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail` or use the maintainer launcher `Deploy Addons` action and confirm both addon folders copy into the selected target's `Interface\AddOns`.
71. For release automation, create a beta tag such as `v0.9.0-beta.1` on a throwaway branch or dry-run repository, confirm `.github/workflows/release-curseforge.yml` runs the Lua suite, confirm the matching GitHub Release is created as a prerelease, and confirm the attached zip contains both `GBankManager/` and `GBankManager_ItemData/`.
71. After any catalog refresh or learned import, run `.\tools\lua\lua.exe .\tests\run_all.lua` and confirm the bundled item-data addon still supports Minimums and Requests item search.
