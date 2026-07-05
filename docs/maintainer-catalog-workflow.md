# Maintainer Catalog Workflow

This workflow is for maintainers refreshing the bundled item catalog, validating the repo, and deploying both addon folders into a WoW target.

The recommended surface is the local PowerShell maintainer launcher:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Open-ItemCatalogMaintainer.ps1
```

The launcher is a thin wrapper over the same repo-local scripts described below. If the UI is unavailable or you want a copyable audit trail, use the CLI commands directly.

## What The Maintainer UI Does

The maintainer window centers on four actions:

1. `Refresh Status`
   - reads the resolved WoW target
   - shows the selected AddOns directory
   - shows the last saved sync state, last completed sync time, and catalog build

2. `Run Fresh Sync`
   - runs the canonical catalog refresh from the beginning for the selected target

3. `Resume Sync`
   - resumes the last interrupted target-scoped refresh for the selected target

4. `Deploy Addons`
   - copies both `GBankManager/` and `GBankManager_ItemData/` into the selected target's `Interface\AddOns\`

The launcher intentionally stays thin. Extraction, merge, and generated-addon rebuild still live in the underlying scripts so the CLI and UI remain the same workflow.

## Retail Fast Path

For the common "put the current worktree into live Retail and sanity-check it" workflow on this machine:

1. Verify the resolved Retail target and current status:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Get-ItemCatalogMaintainerStatus.ps1 -Target Retail -Json
```

2. Deploy the current repo state into Retail:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json
```

3. On this machine, the resolved Retail AddOns directory is expected to be:

```text
C:\Gaming\World of Warcraft\_retail_\Interface\AddOns
```

4. After deploy, `/reload` in game and run the focused live checks from `docs/testing.md` and `docs/manual-test-checklist.md`.

The deploy helper copies both addon folders from the current worktree state, including local uncommitted changes, so be intentional about the branch and `git status -sb` before using it as a live-client build.

## CLI Equivalents

Read status for a target:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Get-ItemCatalogMaintainerStatus.ps1 -Target Retail
```

Run a full refresh from scratch:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Fresh
```

Resume an interrupted refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail -Resume
```

Import learned PTR or Beta discoveries before the next confirmed refresh:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Import-LearnedItemCatalog.ps1 -LearnedRowsPath .\tools\catalog\runtime\item-catalog-learned.json
```

Run the local addon test gate after refresh:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Deploy both addon folders into the selected target:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail
```

## Status Meanings

`Get-ItemCatalogMaintainerStatus.ps1` currently reports these top-level sync states:

- `never_synced`
  - no saved target-scoped progress exists yet
- `in_progress`
  - the last refresh did not complete and may be resumable
- `failed`
  - the last refresh ended in a categorized failure
- `synced`
  - the last saved run completed through the generated-addon rebuild boundary

The most important fields for the UI are:

- `syncStatus`
- `lastSyncAt`
- `build`
- `clientDirectory`
- `addOnsDirectory`
- `phase`
- `phaseStatus`
- `progressPath`

## Target Notes

Supported named targets:

- `Retail`
- `PTR`
- `Beta`

By default the tooling resolves those targets through `Resolve-WoWTarget.ps1`. You can still override the install root explicitly with `-WoWRoot` when a maintainer machine uses a non-default path.

On current Blizzard installs, `PTR` may appear as `_xptr_` with shared extracted data under `Data\wowxptr` instead of the older `_ptr_\Data\...` layout. The 12.1 PTR on this machine resolves as `_ptr_` with shared product data under `Data\wowt`. The maintainer resolver and refresh shell now accept both layouts.

If a PTR refresh reaches `ItemSparse.db2` and then fails with `Unable to download DBD for ItemSparse`, refresh the ignored wow.export DBD cache before retrying. For the 12.1 PTR build `12.1.0.68412`, `ItemSparse.dbd` must include that build under layout `1C17D17F`.

## Deploy Notes

Deployment copies both addon folders:

- `GBankManager/`
- `GBankManager_ItemData/`

For go-forward local Retail deploys, prefer the repo helper over manual Explorer copy or drag/drop so the command history stays reproducible:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail
```

If you want the resolved path echoed back for logging or follow-up tooling, use `-Json`.

The deployment helper is intentionally local-maintainer-only. It does not write runtime catalog assets into git, and it does not expose the fallback metadata flows as primary actions.

## Keep Out Of Git

These maintainer assets remain local and git-ignored:

- `tools/catalog/runtime/item-catalog-input.json`
- `tools/catalog/runtime/wow.export/`
- target-scoped progress files under `tools/catalog/runtime/state/`

The only shipped catalog output that belongs in git is the generated addon payload under `GBankManager_ItemData/`.
