# GBankManager Testing

## Lanes

- `unit`: domain and feature rules that do not need frame-heavy setup
- `ui`: shell, controller, and focused UI behavior
- `integration`: addon bootstrap and TOC wiring smoke
- `live smoke`: explicit retail-client validation after the automated lanes are green

## Commands

- `.\tools\lua\lua.exe .\tests\run_unit.lua`
- `.\tools\lua\lua.exe .\tests\run_ui.lua`
- `.\tools\lua\lua.exe .\tests\run_integration.lua`
- `.\tools\lua\lua.exe .\tests\run_all.lua`
- `.\tools\test\run-unit.ps1`
- `.\tools\test\run-ui.ps1`
- `.\tools\test\run-integration.ps1`
- `.\tools\test\run-all.ps1`
- `.\tools\test\run-live-smoke.ps1`

`run_all` executes `unit -> ui -> integration` and stops on the first failure.

## Release Order

1. Run the local `unit`, `ui`, and `integration` lanes until they are green.
2. Confirm the GitHub Actions workflow is green.
3. Run the live retail smoke pass.
4. Do a short visual spot-check only where automation cannot prove correctness.

## Live Smoke

Run these in retail only after the automated lanes pass:

1. `/gbm ui`
2. Confirm the shell opens and view switching still works.
3. Open `Options` and confirm full scroll reachability, opacity changes, and auth/rank rendering.
4. Open `Requests` and confirm full-shell and request-only layouts do not overflow or lose their shared scrollbar behavior.
5. Open `Minimums` and confirm add/save flows still render correctly.
6. Confirm scan gating still matches officer/full-shell access.
