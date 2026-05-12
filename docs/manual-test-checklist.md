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
10. Confirm export text can be generated from the Exports view helpers.
11. Confirm the sidebar includes Minimums, Targets, and Requests without changing the shell style.
12. Add a recurring minimum and confirm saving the same item and scope updates the existing rule.
13. Add a one-time target and confirm it reaches suggested fulfilled status once inventory meets the target quantity.
14. Submit a member request and confirm it begins as `PENDING`.
15. Submit an officer request and confirm it begins as `APPROVED`.
16. Confirm a member-scoped request list only shows rows for that requester.
17. Log in on two addon-enabled guild characters and confirm a `SYNC_HELLO` is sent on login.
18. Approve a request on one character, relay the sync payload, and confirm the second character records the incoming message state.
19. Create conflicting request records and confirm officer authority wins over a newer member update.
20. Capture a manual recovery payload and confirm it can be replayed without Lua errors after a `/reload`.
21. With the guild bank open, verify a scan queues only tabs the current character can view.
22. Change bank contents between scans and confirm the dashboard and history reflect the new snapshot.
23. Generate Auctionator, spreadsheet, and custom export text from the same demand rows and confirm each preset formats correctly.
24. Open the Inventory view with enough rows to overflow and confirm the scroll controls move through the table without blanking the header.
25. Resize the inventory name column and confirm the wider width is reflected immediately while neighboring columns stay readable.
26. Use the inline inventory column filters and confirm filtering by `Name`, `Tab`, and `Restock` narrows the visible rows immediately.
27. Confirm the inventory quality column shows a quality marker for known uncommon-or-better items and stays blank for items without known quality.
28. Confirm long item names and long tab lists clip with an ellipsis instead of spilling into adjacent inventory columns.
29. Run a scan, `/reload`, and confirm both the inventory snapshot and last-scan status still appear before starting a fresh scan.
30. Open the History tab and confirm request approvals and minimum changes render as audit-style rows with actor, old value, new value, and timestamp columns.
31. Open the Requests tab and confirm pending requests appear ahead of approved-open requests, with requester, item, quantity, approval, fulfillment, and note columns rendered in the shared table shell.
32. Confirm rejected requests and fulfilled requests transition correctly in the Requests flow once those actions are wired into the live controls.
33. Follow the README local-development steps on a fresh UI reload and confirm `/gbm ui` and `/gbm scan` still work in sequence.
