# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.

Local tests use a Lua 5.1-compatible runner to load the addon in `.toc` order with one shared namespace, matching the WoW addon runtime shape.

## Features

- One-button guild bank scan foundation with snapshot and change-log storage
- Officer-first dashboard shell with inventory, history, export, minimums, targets, and request workspaces
- Recurring stock minimum helpers and one-time target management helpers
- Member request submission with officer auto-approval behavior for elevated roles
- Auctionator, spreadsheet, and custom-delimited export builders
- Guild sync foundation with authority-first conflict resolution and login hello messages

## Local Development

1. Keep the addon folder at `GBankManager/`.
2. Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
3. Copy `GBankManager` into `World of Warcraft\_retail_\Interface\AddOns\`.
4. Use `/gbm ui` to open the officer shell.
5. Use `/gbm scan` while the guild bank is open to exercise the scan flow.
