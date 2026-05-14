# GBankManager

World of Warcraft guild bank inventory, planning, request, and export addon.

Local tests use a Lua 5.1-compatible runner to load the addon in `.toc` order with one shared namespace, matching the WoW addon runtime shape.

## Features

- One-button guild bank scan foundation with snapshot and change-log storage
- Officer-first dashboard shell with inventory, history, minimums, requests, exports, about, and options workspaces
- Recurring stock minimum helpers and procurement-planning export workflows
- Member request submission with officer auto-approval behavior for elevated roles
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
- `UI/MainTableController.lua`
- `UI/MainRequestsController.lua`
- `UI/MainExportsController.lua`
- `UI/MainMinimumsController.lua`
- `UI/MainFrame.lua`

## Deferred Work

- offline/global item discovery for Minimums add-item search remains a separate follow-up design task
- current non-bank search depends on locally known item data rather than a universal in-game catalog

## Local Development

1. Keep the addon folder at `GBankManager/`.
2. Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
3. Optionally run the companion Wowless smoke lane with `.\tools\test\run-wowless.ps1` after setting up the sibling repo at `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager-wowless-smoke`. The companion report records the selected Wowless product and per-product fallback attempts.
4. Copy `GBankManager` into `World of Warcraft\_retail_\Interface\AddOns\`.
5. Use `/gbm ui` to open the officer shell.
6. Use `/gbm scan` while the guild bank is open to exercise the scan flow.
