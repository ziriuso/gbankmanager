# CurseForge Release Workflow

## Forever branch

Keep Forever on its own long-lived branch in the same GitHub repository. This
branch's `.github/workflows/release-curseforge.yml` reacts only to
`forever-v*` tags. The first tag is `forever-v1.6.0`. A pushed tag from this
branch runs the full Lua suite, builds `GBankManager-Forever-1.6.0.zip`,
uploads it to the **existing** GuildBankManager CurseForge project as a file
tagged only for WoW Forever, and attaches the same zip to a GitHub Release.
This first file uses CurseForge's `Release` channel so the app can install it
by default for Forever. A later `-beta` tag creates an opt-in Beta file.
Retail tags and packages continue to come from `master`.

The Forever zip has two top-level addon folders: `GBankManager/` and
`GBankManager_ItemData/`. The latter is copied from
`Forever/GBankManager_ItemData/`, not the Retail folder at the repository root.
The main addon TOC is marked only for interface `16001` and carries the
Forever tag and version. The package builder checks those values in the staged
zip as well.

Before tagging a Forever release:

1. Confirm this branch is based on the intended Retail release and the working
   tree is clean. Keep Forever-specific changes off `master`.
2. Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
3. Build the proposed package locally with
   `.\tools\release\Build-CurseForgePackage.ps1 -TagName forever-v1.6.0 -Target Forever`
   and inspect the zip: exactly the two addon folders, both TOCs at interface
   `16001`, the expected Forever item count, and no Retail data.
4. Push the Forever branch. Create and push the Forever tag on its verified
   commit. Do not merge it into `master` merely to publish Forever.
5. Watch the tag workflow and verify the GitHub zip plus the new Forever file
   under the existing CurseForge listing before calling the release complete.

The existing GitHub secret `CF_API_TOKEN` and variable `CF_PROJECT_ID` are
shared. `CF_FOREVER_GAME_VERSION_IDS` is an optional, separate variable for the
Forever CurseForge version ID. When it is absent, the publisher resolves
interface `16001` to game version `1.60.1` from CurseForge's version list.
Never use the Retail `CF_GAME_VERSION_IDS` override for a Forever upload.

## Retail branch (`master`)

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

1. Start from the intended checkout or release worktree and confirm its exact branch and commit. Do not rely on a hard-coded machine-local worktree path:

```powershell
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
git add GBankManager GBankManager_ItemData README.md docs tests
git commit -m "chore: prepare 1.5.1 release"
git push -u origin HEAD
```

5. Open, verify, and merge the release pull request before tagging:

```powershell
gh pr create --base master --head <release-branch> --title "Prepare GBankManager 1.5.1 release" --body-file <pull-request-body-file>
gh pr checks <pr-number> --watch
gh pr merge <pr-number> --merge --delete-branch=false
git fetch origin master
git rev-parse origin/master
```

If branch policy blocks a normal merge and the user explicitly authorized an administrative bypass, rerun the merge command with `--admin`. Never tag the release branch itself; the release tag must identify the merged `origin/master` commit.

6. Create and push the release tag on the merged default-branch commit:

```powershell
git tag v1.5.1 origin/master
git push origin v1.5.1
```

7. Watch the tag-triggered workflow:

```powershell
gh run list --workflow release-curseforge.yml --limit 5
gh run watch <run-id>
```

8. Confirm the release and artifact:

```powershell
gh release view v1.5.1 --json name,tagName,isPrerelease,assets,url
```

The stable release should have `isPrerelease: false`, a `GBankManager-1.5.1.zip` asset, and a successful CurseForge upload step in the workflow log.

9. Deploy the same committed worktree locally after the release gate is green:

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

1. read the first, six-digit Retail value from `## Interface:` in `GBankManager/GBankManager.toc` (later values may include Forever's five-digit interface)
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
