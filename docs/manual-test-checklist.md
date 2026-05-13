# Manual Test Checklist

1. Copy `GBankManager` into `Interface/AddOns`.
2. Run `/reload`.
3. Open the guild bank.
4. Run `/gbm ui`.
5. Confirm the main frame opens on the dashboard view.
6. Confirm the sidebar can collapse and expand without losing the active view.
7. Confirm the top bar shows scan metadata and action status text.
8. Confirm inventory filtering returns matching items.
9. Confirm history filtering can narrow by change type and actor.
10. Confirm selecting each export preset opens the export modal instead of trapping output inline in the Exports panel.
11. Confirm the sidebar includes Minimums, Requests, Exports, About, and Options without changing the shell style.
12. Add a recurring minimum and confirm saving the same item and scope updates the existing rule.
13. Confirm the dashboard purchase summary changes when minimums and approved open requests change.
14. Submit a member request and confirm it begins as `PENDING`.
15. Submit an officer request and confirm it begins as `APPROVED`.
16. Confirm a member-scoped request list only shows rows for that requester.
17. Log in on two addon-enabled guild characters and confirm a `SYNC_HELLO` is sent on login.
18. Approve a request on one character, relay the sync payload, and confirm the second character records the incoming message state.
19. Create conflicting request records and confirm officer authority wins over a newer member update.
20. Capture a manual recovery payload and confirm it can be replayed without Lua errors after a `/reload`.
21. With the guild bank open, verify a scan queues only tabs the current character can view.
22. Change bank contents between scans and confirm the dashboard and history reflect the new snapshot.
23. Generate Auctionator, CSV, and custom export text from the same demand rows and confirm each preset formats correctly in the export modal.
24. In the export modal, use `Select All`, then `Copy`, and confirm the full output is easy to copy/paste into the target tool before closing the modal.
25. Open the Inventory view with enough rows to overflow and confirm the scroll controls move through the table without blanking the header.
26. Resize the inventory name column and confirm the wider width is reflected immediately while neighboring columns stay readable.
27. Use the inline inventory column filters and confirm filtering by `Name`, `Tab`, and `Restock` narrows the visible rows immediately.
28. Confirm the inventory quality column shows a quality marker for known uncommon-or-better items and stays blank for items without known quality.
29. Confirm long item names and long tab lists clip with an ellipsis instead of spilling into adjacent inventory columns.
30. Run a scan, `/reload`, and confirm both the inventory snapshot and last-scan status still appear before starting a fresh scan.
31. Open the History tab and confirm request approvals and minimum changes render as audit-style rows with actor, old value, new value, and timestamp columns.
32. Open the Requests tab and confirm pending requests appear ahead of approved-open requests, with requester, item, quantity, approval, fulfillment, and note columns rendered in the shared table shell.
33. Confirm rejected requests and fulfilled requests transition correctly in the Requests flow once those actions are wired into the live controls.
34. Follow the README local-development steps on a fresh UI reload and confirm `/gbm ui` and `/gbm scan` still work in sequence.
35. Open Minimums and confirm the search field has a visible `Search` label and the `Enabled Only` / `Show All` toggle text fits cleanly without clipping.
36. Select an existing saved minimum row and confirm changed rows tint yellow, deleted rows tint red, and newly staged rows tint green in the live client.
37. Select an existing saved minimum row and confirm the remove and undo actions use icon buttons instead of placeholder glyph text.
38. Select an existing saved minimum row and confirm `Bank Tab` stays read-only while `Restock` and `Minimum` still edit inline.
39. Select any actively edited minimum row and confirm the underlying inline cell text is hidden behind the live editor controls instead of ghosting through.
40. Click `Add` in Minimums and confirm the modal labels `Item ID`, `Item Name`, `Minimum`, and `Matches` are visible and do not overflow the dialog.
41. Search for an item name that has multiple quality variants and confirm the modal shows a clean stacked results list instead of jumbled buttons.
42. Search for an item that exists in the bank and in the WoW client item cache and confirm client-item results are still available alongside bank matches.
43. Stage a new minimum row from the modal and confirm the row exposes a `Bank Tab` dropdown populated with known guild bank tab names before save.
44. Save an edited existing minimum row and confirm quantity and restock changes persist without changing the saved row's original `Bank Tab` scope.
45. Save a newly staged minimum row and confirm the chosen `Bank Tab` dropdown value persists as a tab-scoped minimum.
46. Use the Minimums search box with and without matches and confirm the empty-state message remains clear when filters hide all rows.
47. Click a saved minimum row without editing it and confirm the row does not immediately show an undo state until a real change is made.
48. While editing an existing row, confirm the inline `Restock` and `Minimum` controls stay vertically aligned with the original row text instead of dropping lower in the cell.
49. Search for a non-bank item using a partial name after it has been seen through a prior exact resolution or saved catalog entry and confirm the add modal can still surface it outside the current guild bank snapshot.
50. Open the shell tabs after a `/reload` and confirm the current navigation remains `Dashboard`, `Inventory`, `History`, `Minimums`, `Requests`, `Exports`, `About`, and `Options` with no `Targets` tab returning.
51. Log in as Guildmaster and confirm `/gbm ui` opens the full shell, `/gbm request` opens the request view, and the `Options` auth panel can save rank capability changes.
52. Configure a member rank with no `full_ui` access but with `request_submit`, then confirm `/gbm ui` opens the lightweight Requests surface with no officer action controls.
53. Remove `request_submit` from a member rank and confirm the lightweight Requests surface becomes read-only with the `You do not have permission to submit requests.` banner.
54. Blacklist a guild member from the auth panel and confirm both `/gbm ui` and `/gbm request` deny access for that character after `/reload`.
55. Create a request from a request-only member and confirm an officer/guildmaster client receives it through addon comms and can act on it from the full Requests shell.
56. Save an auth-policy change on one officer-authorized client and confirm a second addon-enabled guild client receives the updated rank policy and blacklist snapshot.
