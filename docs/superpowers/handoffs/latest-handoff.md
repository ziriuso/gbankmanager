# GBankManager Handoff

## Current Checkpoint

Updated: 2026-06-11

- Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- Branch: `codex/gbankmanager-v1`
- Current HEAD: `447d455 chore: prepare 1.2.5 release`
- Branch state before this handoff cleanup: in sync with `origin/codex/gbankmanager-v1`
- Expected local noise: untracked `.vscode/`
- This handoff cleanup is documentation-only unless it has been committed after the checkpoint above.

## Release State

- Current public release: `v1.2.5`
- Release commit: `447d455 chore: prepare 1.2.5 release`
- GitHub Actions release workflow: `27389094436`
- Workflow result: success
- GitHub Release: `GBankManager v1.2.5`
- Release asset: `GBankManager-1.2.5.zip`
- Release channel: stable CurseForge release
- Local Retail deploy completed to:
  - `C:\Gaming\World of Warcraft\_retail_\Interface\AddOns\GBankManager`
  - `C:\Gaming\World of Warcraft\_retail_\Interface\AddOns\GBankManager_ItemData`
- Deployed TOC was checked after release and advertised:
  - `## Version: 1.2.5`
  - `## X-Release-Tag: v1.2.5`

Do not tag, republish, or create another CurseForge release unless explicitly asked.

## Version And Migration Markers

- Addon display version:
  - `GBankManager/GBankManager.toc`: `1.2.5` / `v1.2.5`
  - `GBankManager/Core/Constants.lua` fallback `ADDON_VERSION`: `1.2.5`
- Ledger protocol:
  - `LEDGER_PROTOCOL_VERSION = 3`
- Intentional data-cleanup markers that should not be bumped unless the cleanup behavior changes:
  - `MONEY_LEDGER_DEDUPE_VERSION = "1.2.3-money-v7"`
  - `SAVED_VARIABLES_COMPACT_VERSION = "1.2.3-snapshot-v3"`
- The `1.2.3` text in those marker strings is not stale release metadata; it is the durable migration token for the cleanup pass that ships in the 1.2.x line.

## Shipped Through 1.2.5

- Minimap launcher now snaps to a LibDBIcon-style minimap ring radius instead of floating outside the minimap.
- Minimap launcher hover tooltip identifies the addon as `GuildBankManager`.
- Dragging the minimap launcher normalizes the stored angle.
- Escape closes the main addon shell.
- If the manual shopping list is open, Escape still closes the main addon shell while leaving the shopping list open; the shopping list still requires its close X.
- Release metadata and About version now advertise `v1.2.5`.
- Previous unreleased 1.2.3-line fixes are included in the shipped release:
  - quiet sync chat unless local rows actually arrive or change
  - no-change request, minimum, history, and ledger sync updates peer timestamps quietly
  - duplicate money-ledger cleanup with the `1.2.3-money-v7` marker
  - short-window raw-relative money deposit replay suppression
  - protocol-2 ledger payload rejection through `LEDGER_PROTOCOL_VERSION = 3`
  - SavedVariables compaction with the `1.2.3-snapshot-v3` marker
- Post-1.2.4 live follow-up in progress:
  - passive Guild Info auth-policy pulls should be skipped while inside dungeon or raid instances to avoid protected `GetInfoText()` blocked-action errors
- 1.2.5 release:
  - ships the post-1.2.4 instance guard above as a stable CurseForge release

## Verification Completed

- Local release gate passed:
  - `.\tools\lua\lua.exe .\tests\run_all.lua`
- Release workflow `27362918871` passed:
  - full Lua suite
  - combined package build
  - CurseForge upload
  - GitHub Release creation and zip attach
- Local Retail deploy completed after release:
  - `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json`
- Deployed Retail TOC confirmed `1.2.4` / `v1.2.4` before the 1.2.5 release-prep bump.

## Read First

- `README.md`
- `docs/testing.md`
- `docs/manual-test-checklist.md`
- `docs/superpowers/handoffs/latest-handoff.md`
- `docs/curseforge-release-workflow.md` if release handling resumes
- `GBankManager/UI/MinimapButton.lua`
- `GBankManager/UI/MainFrameShell.lua`
- `tests/spec/ui_shell_spec.lua`
- `GBankManager/Data/Store.lua`
- `GBankManager/Data/Defaults.lua`
- `GBankManager/Data/Migrations.lua`
- `GBankManager/Domain/BankLedger.lua`

Use the local `wow-addon-expert` guidance and local WoW Addon Dev Guide for WoW runtime, SavedVariables, UI, and deployment decisions.

## First Commands

Run these before starting the next slice:

```powershell
git status -sb
git rev-parse --abbrev-ref HEAD
git log -1 --oneline
.\tools\lua\lua.exe .\tests\run_all.lua
```

If release or GitHub workflow facts matter:

```powershell
gh auth status -h github.com
gh run list --workflow release-curseforge.yml --limit 5
gh release view v1.2.5 --json name,tagName,isPrerelease,assets,url
```

## Completed Live Validation

User confirmed the `v1.2.4` Retail validation items are complete and working as expected:

- installed `v1.2.4` Retail build after `/reload`
- About shows `v1.2.4`
- minimap launcher sits on the minimap ring, shows the `GuildBankManager` hover tooltip, can be dragged, and still toggles the addon shell
- Escape closes the main addon shell
- Escape closes the main addon shell while the manual shopping list remains open, and the shopping list only closes through its close X
- 1.2.3-line data fixes that shipped in 1.2.4 behave as expected:
  - money-ledger duplicates do not regrow after `/reload` or a follow-up bank scan
  - older protocol-2 ledger clients cannot repopulate cleaned rows
  - no-change sync stays quiet while peer timestamps update
  - SavedVariables compaction preserves current inventory, two recent backups, Minimums, Requests, auth, blacklist, settings, and useful ledger/audit history

## Next Work Order

1. Choose the next backlog slice deliberately.
2. Do not infer scope from old historical handoff sections or nearby backlog items.
3. If the next slice involves SavedVariables compaction, measure current size contributors before changing cleanup behavior.

## Preserved User Data Rules

When changing cleanup or compaction behavior, preserve:

- current inventory snapshot
- one or two recent backup snapshots
- Minimums
- Requests
- auth, blacklist, and settings
- useful audit and ledger history unless a retention setting says otherwise

Measure SavedVariables size contributors before assuming snapshots are the only source. Pay attention to snapshots, snapshot item payloads, generated/search/cache tables, bank-ledger item and money logs, audit/history, accidentally persisted item data, stale guild roots, and sync/debug state that can be safely cleared.
