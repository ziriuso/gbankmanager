# GBankManager Testing

## Lanes

- `unit`: domain and feature rules that do not need frame-heavy setup
- `ui`: shell, controller, and focused UI behavior
- `integration`: addon bootstrap, slash wiring, and opt-in smoke harness routing
- `wowless`: companion-repo Docker smoke that loads the addon through Wowless
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
- `.\tools\test\run-wowless.ps1`
- `.\tools\test\run-live-smoke.ps1`

`run_all` executes `unit -> ui -> integration` and stops on the first failure.

## Lane Coverage

- `unit`
  - domain rules for auth, requests, exports, planning, sync, store, and scan persistence
  - migration/default-shape coverage, including the persisted live-smoke result container
- `ui`
  - shell layout, shared table behavior, requests, exports, minimums, and options/auth ownership specs
  - focused regression checks for shared scrollbars, request-only layout, and options auth state
- `integration`
  - TOC order and duplicate-load protection
  - shared namespace/module registration after bootstrap
  - slash-command wiring for explicit live smoke via `/gbm test smoke`
  - persisted smoke summaries and chat-visible smoke output
- `wowless`
  - companion-repo addon-load smoke through Wowless with fallback across supported Standard-gametype products
  - Docker-backed runtime bootstrap outside the main addon repo
  - optional and non-blocking until the runtime is proven stable
- `live smoke`
  - in-client checks run only when you explicitly invoke `/gbm test smoke`
  - confirms shell open/close, options scroll wiring, opacity controls, request-only vs full-shell access, minimum staging/save, and scan gating

## Failure Reading

- `unit` failures usually mean a domain or persistence regression and should be fixed before looking at UI fallout.
- `ui` failures usually mean a shell/controller contract drifted, even if the live client still partly renders.
- `integration` failures usually mean load order, slash routing, or smoke harness wiring broke.
- `wowless` failures usually mean a Docker/runtime issue, a broken Wowless product target, or a headless addon-load regression under Wowless.
- `live smoke` failures mean the addon loaded but a real in-client workflow no longer behaved as expected.

## Release Order

1. Run the local `unit`, `ui`, and `integration` lanes until they are green.
2. Optionally run `.\tools\test\run-wowless.ps1` once the companion repo and Docker Desktop are set up.
3. Confirm the GitHub Actions workflow is green.
4. Run `/gbm test smoke` in retail and review the chat summary.
5. Do a short visual spot-check only where automation cannot prove correctness.

## Wowless Companion Repo

The headless Wowless lane lives in the sibling repo:

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager-wowless-smoke`

That repo owns:

- Docker and Wowless bootstrap
- staging the addon into the Wowless checkout
- addon-load smoke execution
- companion-specific runtime docs

Main companion commands:

- `.\scripts\bootstrap.ps1`
- `.\scripts\run-smoke.ps1`

The companion harness tries product targets in this default order:

1. `wow`
2. `wowt`
3. `wow_beta`

The JSON report records which product actually passed as `selectedProduct`, plus per-product attempts under `productAttempts`.

From the addon repo you can invoke the companion lane with:

- `.\tools\test\run-wowless.ps1`

If PowerShell execution policy blocks direct script execution on Windows, run:

- `powershell -ExecutionPolicy Bypass -File .\tools\test\run-wowless.ps1`

## Live Smoke

Run these in retail only after the automated lanes pass:

1. Run `/gbm test smoke`.
2. Confirm chat prints one overall `PASS` or `FAIL` line plus individual check lines.
3. If it fails, inspect `GBankManagerDB.testing.liveSmoke` after `/reload` for the last persisted summary and check details.
4. If it passes, still do a short visual spot-check in `Options`, `Requests`, and `Minimums` for layout/art regressions the smoke cannot prove.
