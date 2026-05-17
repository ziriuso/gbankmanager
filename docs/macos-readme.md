# macOS README

This document is the travel-friendly macOS setup and resume guide for `GBankManager`.

Use it when opening this branch on a MacBook, especially on a fresh default macOS install.

## What This Covers

- cloning the repo on macOS
- checking out the correct branch
- optionally creating a separate worktree
- finding the correct local test command on Mac
- locating the Retail WoW addon folders on macOS
- copying the addon into the live WoW AddOns directory
- resuming the current UI modernization roadmap

## Repository And Branch

- Repository: `https://github.com/ziriuso/gbankmanager.git`
- Branch: `codex/gbankmanager-v1`

## Recommended Local Repo Path

Use:

```bash
~/Code/gbankmanager
```

## Basic macOS Setup

### 1. Confirm Git

```bash
git --version
```

If Git is missing, install Xcode Command Line Tools first:

```bash
xcode-select --install
```

### 2. Clone The Repo

```bash
mkdir -p ~/Code
cd ~/Code
git clone https://github.com/ziriuso/gbankmanager.git
cd gbankmanager
git checkout codex/gbankmanager-v1
```

### 3. Optional Separate Worktree

If you want this branch in its own sibling folder:

```bash
cd ~/Code/gbankmanager
git worktree add ../gbankmanager-v1 codex/gbankmanager-v1
cd ../gbankmanager-v1
```

## Read First After Clone

Before changing code, read:

1. `README.md`
2. `docs/testing.md`
3. `docs/manual-test-checklist.md`
4. `docs/superpowers/handoffs/latest-handoff.md`
5. `docs/ui-reference/mockup-reference-manifest.md`
6. `docs/ui-polish-suggestions.md`
7. `docs/superpowers/plans/2026-05-17-gbankmanager-ui-modernization-plan.md`
8. `docs/superpowers/specs/2026-05-17-gbankmanager-ui-modernization-pass.md`

Then run:

```bash
git status -sb
```

## Lua Test Runner On macOS

The checked-in Windows runner path:

```text
.\tools\lua\lua.exe .\tests\run_all.lua
```

will not be the right command on a Mac.

On macOS:

1. inspect the repo for a Mac-compatible Lua runner
2. if none exists, use a local Lua 5.1-compatible interpreter without changing project behavior
3. keep the test entrypoints the same:
   - `tests/run_all.lua`
   - `tests/run_ui.lua`
   - targeted specs under `tests/spec/`

Suggested discovery steps:

```bash
find . -maxdepth 3 \( -name "lua" -o -name "lua5.1" -o -name "lua*" \) 2>/dev/null
```

If you already have Lua installed:

```bash
lua -v
```

or:

```bash
lua5.1 -v
```

Once you identify the right interpreter, use it consistently for:

```bash
<lua-command> tests/run_all.lua
<lua-command> tests/run_ui.lua
<lua-command> tests/spec/ui_dashboard_spec.lua
```

If Lua is missing entirely, install the smallest suitable dependency rather than changing the project layout.

## Default macOS WoW Paths

For a default newer macOS install, check these first:

### Retail AddOns

```text
/Applications/World of Warcraft/_retail_/Interface/AddOns
```

### Retail WTF

```text
/Applications/World of Warcraft/_retail_/WTF
```

### SavedVariables

```text
/Applications/World of Warcraft/_retail_/WTF/Account/<ACCOUNT>/SavedVariables
```

These are the first paths to try, but the actual install location should be verified instead of assumed.

### Verify The Install

```bash
ls "/Applications/World of Warcraft/_retail_/Interface/AddOns"
ls "/Applications/World of Warcraft/_retail_/WTF" || true
```

If WoW is not under `/Applications`, search for it:

```bash
find /Applications -maxdepth 3 -type d -name "_retail_" 2>/dev/null
```

## Deploy To Retail On macOS

After confirming the install path, copy both addon folders:

```bash
cd ~/Code/gbankmanager

mkdir -p "/Applications/World of Warcraft/_retail_/Interface/AddOns"

rm -rf "/Applications/World of Warcraft/_retail_/Interface/AddOns/GBankManager"
rm -rf "/Applications/World of Warcraft/_retail_/Interface/AddOns/GBankManager_ItemData"

cp -R "GBankManager" "/Applications/World of Warcraft/_retail_/Interface/AddOns/"
cp -R "GBankManager_ItemData" "/Applications/World of Warcraft/_retail_/Interface/AddOns/"
```

Verify:

```bash
ls "/Applications/World of Warcraft/_retail_/Interface/AddOns/GBankManager"
ls "/Applications/World of Warcraft/_retail_/Interface/AddOns/GBankManager_ItemData"
```

Depending on how WoW was installed, writing inside `/Applications` may prompt for permission.

## Current Branch Context

Important recent commits:

- `b391ad5` - `feat: land UI modernization checkpoint`
- `b381424` - `docs: capture UI mockup handoff state`

Current honest state:

- the reusable UI scaffolding is in place
- the dashboard-heavy follow-up was intentionally rolled back one iteration
- the addon still needs substantial UI polish
- the next major step is building an addon-local art pack to support Alliance-first mockup fidelity

## Resume Goal On macOS

Resume with:

1. repo and test-environment setup
2. WoW path verification on Mac
3. reading the current handoff and mockup reference manifest
4. continuing the UI polish pass

## UI Priority Order

1. Build or integrate an addon-local art pack for Alliance-first fidelity
2. Re-approach dashboard fidelity only after the shell art pack exists
3. Keep the `Ready to Buy` mismatch as live-repro-only unless real current data proves it is a product bug
4. Only broaden sync catch-up if live guild testing shows real remaining gaps

## Notes For The Next Worker

- Always use the local WoW Addon Dev Guide as the primary source of truth for WoW addon/runtime patterns.
- Keep documentation updated as work lands.
- Keep controls reusable and scalable.
- Use TDD and focused subsystem tests.
- Do not break saved variables, requests, exports, scans, permissions, or slash commands.
- Preserve real WoW crafting quality tier icons.

