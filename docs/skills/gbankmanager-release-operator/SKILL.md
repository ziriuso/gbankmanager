---
name: gbankmanager-release-operator
description: Use when handling a GBankManager alpha, beta, or release publish from this repo, or when following up on a failed release workflow. Trigger for requests to cut a tag, publish to CurseForge, attach the release zip to GitHub Releases, inspect release failures, or confirm release status after a tag push.
---

# GBankManager Release Operator

## Overview

Run the repo's full release flow for `GBankManager`: verify the addon, finalize the current checkpoint, create and push the correct tag, watch the `release-curseforge.yml` workflow, confirm the GitHub Release artifact, and handle release-failure follow-up when the workflow breaks.

This skill is repo-specific. Use it only in the `GBankManager` worktree and keep the release docs truthful whenever the release path changes.

## Read First

Before taking release action, read:

1. `README.md`
2. `docs/curseforge-release-workflow.md`
3. `docs/superpowers/handoffs/latest-handoff.md`
4. `.github/workflows/release-curseforge.yml`

Use these to confirm the current publish contract before creating or fixing a release.

## Preconditions

Confirm all of these before publishing:

- repo is `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`
- branch is the intended release branch, usually `codex/gbankmanager-v1`
- `gh` is installed and authenticated
- GitHub Actions secret `CF_API_TOKEN` exists
- GitHub Actions variable `CF_PROJECT_ID` exists
- the release workflow still builds one combined zip containing:
  - `GBankManager/`
  - `GBankManager_ItemData/`

Never print secrets, paste secret values into files, or echo tokens into chat.

## Release Channels

Use these tag shapes:

- `vX.Y.Z-alpha.N` -> CurseForge `alpha`
- `vX.Y.Z-beta.N` -> CurseForge `beta`
- `vX.Y.Z` -> CurseForge `release`

Use plain semantic version tags for stable public releases, and keep using alpha or beta suffixes whenever the user explicitly wants a prerelease channel.

## Normal Release Flow

Follow this order.

### 1. Check repo truth

Run:

```powershell
git status -sb
git rev-parse --abbrev-ref HEAD
```

If the worktree is dirty:

- inspect whether the changes are the intended release checkpoint
- if the checkpoint is coherent and the user asked for release handling, stage, commit, and push it
- if unrelated or surprising changes are mixed in, pause and confirm before publishing

### 2. Run release verification

Always run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Do not publish if this fails unless the user explicitly overrides that safety rail.

### 3. Confirm versioning surface

Check that:

- `GBankManager/GBankManager.toc` still has the intended `## Version:`
- the About tab version path still reflects the intended release line

If the requested release implies a version-string change, update docs and metadata before tagging.

### 4. Finalize the checkpoint

If needed:

```powershell
git add <files>
git commit -m "<message>"
git push origin <branch>
```

Use a commit message that describes the release-prep change truthfully. Do not create empty ceremonial commits.

### 5. Create and push the tag

Examples:

```powershell
git tag v0.9.0-beta.3
git push origin v0.9.0-beta.3
```

Push the branch before the tag if the release fix is not already on origin.

### 6. Watch the workflow

Use `gh`:

```powershell
gh run list --workflow release-curseforge.yml --limit 5
gh run watch <run-id>
```

Wait for a final state. Do not claim success while the workflow is still `in_progress`.

### 7. Confirm outputs

After a successful run, verify:

```powershell
gh release view <tag>
gh release view <tag> --json name,tagName,isPrerelease,assets,url
```

Confirm:

- the GitHub Release exists
- prerelease state matches channel for alpha or beta
- the combined zip is attached
- the workflow passed the CurseForge upload step

## Failure Follow-Up

If the release workflow fails, do not guess. Inspect the actual run.

### 1. Pull the failure details

```powershell
gh run view <run-id>
gh run view <run-id> --log-failed
```

Capture:

- failing step name
- exact error text
- whether the failure happened before or after the CurseForge upload

### 2. Classify the failure

Use these buckets:

- verification failure
  - tests failed
- packaging failure
  - combined zip shape or build metadata issue
- CurseForge upload failure
  - API payload, game version ids, auth, or project config
- GitHub Release failure
  - release creation or asset attach issue

### 3. Fix the root cause

Make the narrowest fix that addresses the actual failure.

Requirements:

- update docs if release behavior changed
- add or update a focused test when the failure is about repo logic or workflow contract
- rerun the relevant local tests first

### 4. Re-release safely

Do not reuse a failed tag for a new payload.

Instead:

- commit the fix
- push the branch
- create the next tag in sequence

Example:

```powershell
git tag v0.9.0-beta.2
git push origin v0.9.0-beta.2
```

Then repeat the workflow-watch and output-confirmation steps.

## Reporting Back

End every release handling task with:

- branch name
- commit hash used for the release
- pushed tag
- workflow result
- GitHub Release URL
- attached zip name
- whether CurseForge publish succeeded
- any follow-up needed

If the release failed, lead with the failing step and exact blocker.

## Common Mistakes

- tagging before pushing the release fix commit
- assuming `gh` is authenticated without checking
- claiming success before `gh run watch` finishes
- forgetting that failed release fixes should use a new beta or alpha tag
- editing release automation without updating `docs/curseforge-release-workflow.md`
- exposing token values in docs, workflow logs, or chat

## Quick Commands

```powershell
git status -sb
.\tools\lua\lua.exe .\tests\run_all.lua
gh auth status
gh run list --workflow release-curseforge.yml --limit 5
gh run view <run-id> --log-failed
gh release view <tag> --json name,tagName,isPrerelease,assets,url
```
