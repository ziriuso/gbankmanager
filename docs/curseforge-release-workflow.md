# CurseForge Release Workflow

This repo now supports tag-driven CurseForge publishing for the combined `GBankManager` release artifact.

The published zip contains:

- `GBankManager/`
- `GBankManager_ItemData/`

The same built zip is also attached to the matching GitHub Release.

Repo-local release handling skill:

- `docs/skills/gbankmanager-release-operator/SKILL.md`

Use that skill when you want Codex to run the normal GBankManager release flow or diagnose a failed release workflow.

Example prompt:

> Use `$gbankmanager-release-operator` at `docs/skills/gbankmanager-release-operator` to handle the next release publish for this repo.

## Release Channels

The workflow derives the CurseForge release type directly from the git tag:

- `v1.0.1-alpha.1` -> `alpha`
- `v1.0.1-beta.1` -> `beta`
- `v1.0.1` -> `release`

Anything containing `-alpha` publishes as an alpha file.
Anything containing `-beta` publishes as a beta file.
A plain semantic version tag publishes as a release file.

Use plain semantic version tags for stable public releases, and keep using `-alpha` or `-beta` suffixes whenever a prerelease channel is the intended outcome.

## GitHub Actions Workflow

Workflow file:

- `.github/workflows/release-curseforge.yml`

Trigger:

- pushes to tags matching `v*`

Behavior:

1. checks out the repo
2. runs `.\tools\lua\lua.exe .\tests\run_all.lua`
3. builds one combined zip
4. uploads that zip to CurseForge
5. creates or updates the matching GitHub Release
6. attaches the same zip to the GitHub Release

## Maintainer Release Checklist

Use this checklist when cutting a stable release yourself.

1. Start from the release worktree and confirm the branch:

```powershell
cd C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1
git status -sb
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
```

2. Update the release version surfaces before tagging:

- `GBankManager/GBankManager.toc`: update `## Version:` to the semantic version without `v`, for example `1.2.0`.
- `GBankManager/GBankManager.toc`: update `## X-Release-Tag:` to the matching tag, for example `v1.2.0`.
- `GBankManager/Core/Constants.lua`: update the fallback `ADDON_VERSION` string to the same semantic version. The live addon normally reads the TOC value, but the fallback should stay aligned for tests and unusual load paths.
- `GBankManager/Core/Constants.lua`: do not bump `LEDGER_FORCE_CLEAR_VERSION` as routine release metadata. Change it only when the release intentionally needs a new one-time Bank Ledger reset. For 1.2.0, confirm `LEDGER_FORCE_CLEAR_VERSION` matches `1.2.0` and `LEDGER_PROTOCOL_VERSION` is bumped to `2` before tagging.
- `tests/spec/toc_spec.lua`: update the expected `## Version:` and `## X-Release-Tag:` lines.
- `tests/spec/ui_about_spec.lua`: update the expected visible release tag.
- User-facing docs that mention the release behavior, usually `README.md`, `docs/testing.md`, `docs/manual-test-checklist.md`, and `docs/superpowers/handoffs/latest-handoff.md` when the current checkpoint changes.

`GBankManager_ItemData/GBankManager_ItemData.toc` currently has no `## Version:` metadata. Only update its `## Interface:` line when supported WoW client interface numbers change, and keep `tests/spec/toc_spec.lua` aligned.

3. Run the full release gate:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

4. Commit and push the release-prep checkpoint:

```powershell
git add GBankManager README.md docs tests
git commit -m "chore: prepare 1.4.0 release"
git push origin codex/guild-bank-tab-scan-guard
```

5. Create and push the release tag:

```powershell
git tag v1.4.0
git push origin v1.4.0
```

6. Watch the tag-triggered workflow:

```powershell
gh run list --workflow release-curseforge.yml --limit 5
gh run watch <run-id>
```

7. Confirm the release and artifact:

```powershell
gh release view v1.4.0 --json name,tagName,isPrerelease,assets,url
```

The stable release should have `isPrerelease: false`, a `GBankManager-1.4.0.zip` asset, and a successful CurseForge upload step in the workflow log.

8. Deploy the same committed worktree locally after the release gate is green:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail -Json
```

After deploying, `/reload` in game and open `About` to confirm the visible release tag matches the tag you pushed.

## Required GitHub Repository Settings

### Repository secret

Create this in:

- `GitHub repo -> Settings -> Secrets and variables -> Actions -> Secrets`

Secret name:

- `CF_API_TOKEN`

This must be the CurseForge API token. Never store the token in the repository, workflow YAML, scripts, docs, commit messages, or tags.

### Repository variables

Create these in:

- `GitHub repo -> Settings -> Secrets and variables -> Actions -> Variables`

Required variable:

- `CF_PROJECT_ID`

Set it to the CurseForge project id for the main combined project.

Optional variable:

- `CF_GAME_VERSION_IDS`

This can be a single CurseForge game version id or a comma-separated list if automatic TOC-interface resolution ever needs an override.

If `CF_GAME_VERSION_IDS` is not set, the publish script will:

1. read `## Interface:` from `GBankManager/GBankManager.toc`
2. convert it to a retail version string like `12.0.5`
3. query CurseForge for the matching WoW game version id

## Token Rotation Reminder

The CurseForge token that was shared during setup should be treated as exposed and rotated.

After generating a new token:

1. open `GitHub repo -> Settings -> Secrets and variables -> Actions -> Secrets`
2. edit `CF_API_TOKEN`
3. paste the new token value
4. save the secret

No repository code changes are needed when the token rotates.

## Example Prerelease Publish

Example prerelease tag:

- `v1.0.1-beta.1`

Example flow:

```powershell
git tag v1.0.1-beta.1
git push origin v1.0.1-beta.1
```

That tag should:

- publish a CurseForge beta file
- create a prerelease on GitHub
- attach the built zip to that prerelease

## Example Stable Release

Example stable tag:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

That tag should:

- publish a CurseForge release file
- create a normal GitHub Release
- attach the built zip to the GitHub Release
