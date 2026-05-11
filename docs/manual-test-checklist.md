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
24. Follow the README local-development steps on a fresh UI reload and confirm `/gbm ui` and `/gbm scan` still work in sequence.
