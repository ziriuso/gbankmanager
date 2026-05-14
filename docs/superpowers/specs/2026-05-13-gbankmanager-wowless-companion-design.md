# GBankManager Wowless Companion Repo Design

## Summary

Create a dedicated secondary repository for GBankManager's headless Wowless smoke lane rather than embedding Wowless runtime machinery directly into the addon repo. The companion repo will own Docker-based Wowless bootstrap, addon mounting/copying, headless smoke execution, and optional CI integration, while the main addon repo remains responsible for unit, UI, integration, and live-retail smoke.

This first slice is intentionally narrow:

- build a real runnable Wowless smoke lane
- keep it optional and non-blocking at first
- make local setup explicit on Windows with Docker Desktop
- define a stable contract between the addon repo and the companion repo
- avoid claiming live-client correctness from Wowless

## Why A Companion Repo

Wowless currently expects a Docker-based development/runtime environment and is materially larger than the addon itself. Keeping that machinery outside the main addon repo gives us cleaner separation of concerns:

- `GBankManager` stays focused on addon source, local Lua lanes, and live-smoke workflows
- the Wowless companion can evolve its own runtime bootstrap and CI mechanics without creating noise in the addon repo
- we avoid a large submodule/vendor decision before the lane proves its value

This also matches the current testing model:

- main repo proves domain and controller behavior quickly
- companion repo proves addon-load/runtime smoke in a WoW-like headless environment
- live retail still remains the final authority for fragile real-client behavior

## Goals

- Provide a real headless `wowless` smoke lane for GBankManager.
- Support a local developer workflow on Windows once Docker Desktop is installed.
- Support an optional GitHub Actions job that runs the same smoke lane in CI.
- Verify core runtime behaviors:
  - addon loads without hard runtime errors
  - namespace/bootstrap survives
  - SavedVariables defaults initialize
  - slash entrypoints can be exercised
  - major shell views can be selected
- Keep the lane clearly labeled as smoke coverage, not full UI correctness.

## Non-Goals

- Do not replace live retail smoke.
- Do not treat Wowless as authoritative for secure execution or combat restrictions.
- Do not move existing local Lua test lanes into the companion repo.
- Do not build deep visual assertions or pixel-perfect layout validation in Wowless.
- Do not over-generalize this first repo into a multi-addon framework.

## Repository Strategy

### Recommended repository

Use a dedicated sibling repository, for example:

- `GBankManager-wowless-smoke`

This repo is specific to GBankManager and optimized for the addon's current runtime/test surface. If a future addon needs the same pattern, we can generalize after this lane is stable.

### Ownership split

Main addon repo:

- addon source
- local Lua lanes: `unit`, `ui`, `integration`
- live retail smoke harness
- docs that reference the Wowless companion lane
- optional CI hook or status expectations for the Wowless job

Wowless companion repo:

- Wowless bootstrap and version pinning
- Docker-based runtime setup
- scripts that run GBankManager through Wowless
- headless smoke spec/assertions
- optional CI workflow for the headless lane

## Runtime Contract Between Repos

The companion repo needs a small, explicit contract so local and CI execution behave the same way.

### Required input

The companion repo accepts the absolute path to an addon checkout root containing:

- `GBankManager/GBankManager.toc`
- all addon source directories under `GBankManager/`

Preferred invocation shape:

- local path argument or environment variable such as `GBM_ADDON_ROOT`

Example logical contract:

- addon root points to the repo root or worktree root
- addon directory under that root is `GBankManager`

### Output

The companion repo should produce:

- a terminal summary with PASS/FAIL
- a per-check breakdown
- a non-zero process exit code on smoke failure
- optional machine-readable artifact such as JSON for CI upload

### Stability rule

The contract should avoid depending on private worktree paths beyond the single root input. The companion repo should treat the addon as an external source tree, not as something copied into its own source permanently.

## Local Runtime Setup

### Local prerequisites

The first supported local path is Windows with Docker Desktop installed and running.

Required local tools:

- Git
- Docker Desktop
- Docker Compose support via `docker compose`

Optional but helpful:

- PowerShell 7 or Windows PowerShell 5.1

### Local bootstrap flow

The companion repo should expose a simple bootstrap sequence:

1. verify Docker is installed and the daemon is reachable
2. clone or initialize the pinned Wowless runtime source inside the companion repo workspace
3. prepare any Wowless environment files required by upstream
4. build or start the Dockerized Wowless environment
5. run a smoke command against the supplied addon root

### Failure behavior

If Docker is missing locally, the scripts should fail fast with a clear message like:

- Docker Desktop is required for local Wowless smoke
- install Docker Desktop and rerun bootstrap

This avoids pretending there is a partial unsupported local runtime.

## Companion Repo Structure

The companion repo should stay small and purposeful.

Suggested layout:

- `README.md`
  - setup overview
  - required tools
  - exact local commands
- `docs/`
  - lane purpose
  - troubleshooting
  - CI notes
- `runtime/`
  - Wowless checkout or pinned runtime metadata
  - Docker/env bootstrap helpers
- `scripts/`
  - `bootstrap.ps1`
  - `run-smoke.ps1`
  - `run-smoke.sh` if needed for CI/Linux parity
- `smoke/`
  - smoke scenario definitions
  - assertion helpers
  - output formatting helpers
- `.github/workflows/`
  - optional Wowless smoke workflow

## Smoke Scope

The companion repo should intentionally mirror the testing roadmap's headless lane.

### Smoke checks for first slice

- addon loads from the TOC without hard runtime failure
- namespace and major modules register
- SavedVariables default shape initializes
- slash routes can be invoked for:
  - `/gbm ui`
  - `/gbm request`
  - `/gbm test smoke`
- major views can be selected headlessly:
  - dashboard
  - requests
  - options
  - minimums
- no obvious shell bootstrap regression during view changes

### Checks to defer

- deep scrolling behavior
- secure/protected behavior correctness
- combat-lockdown behavior
- visual fidelity
- Guild Bank API realism beyond smoke expectations

## CI Design

### Initial CI posture

The Wowless lane should be optional and non-blocking first.

Reasons:

- Wowless itself is pre-alpha and can fail for reasons outside addon logic
- Dockerized runtime adds a heavier dependency chain than the local Lua lanes
- we want a few stable branch runs before promoting it

### Suggested CI shape

Two valid integration models:

1. the companion repo owns its own workflow and is triggered manually or by branch coordination
2. the addon repo adds an optional `wowless` job that checks out both repos and invokes the companion scripts

For the first slice, prefer `2` only if it stays simple. The addon repo workflow can add a non-required `wowless` job later once the companion repo bootstrap is proven locally.

### CI environment

Prefer Linux runners for the Wowless job because Docker support is more predictable there than on Windows-hosted CI.

The job should:

1. checkout the addon repo
2. checkout the companion repo
3. bootstrap Wowless runtime
4. run smoke against the checked-out addon root
5. surface PASS/FAIL and upload any JSON/text report artifacts

## Data Flow

### Local

1. Developer updates GBankManager in its normal repo/worktree.
2. Developer runs the companion repo smoke script with the addon root path.
3. The companion script mounts or copies the addon into the Wowless runtime container.
4. Wowless executes the addon load/runtime smoke.
5. Script returns summarized results and exit code.

### CI

1. Workflow checks out addon repo and companion repo.
2. Companion repo bootstraps the pinned Wowless runtime in Docker.
3. Smoke runner receives addon root path from workflow.
4. Results are printed and optionally saved as artifacts.

## Error Handling

The companion repo should distinguish between these failure classes:

- environment failure
  - Docker missing
  - Docker daemon unavailable
  - Wowless bootstrap failure
- harness failure
  - smoke script bug
  - malformed input path
- addon smoke failure
  - addon load/runtime regression under Wowless

Each class should produce a different top-level message so contributors know whether to fix local setup, the harness, or addon code.

## Documentation Requirements

The companion repo README should include:

- what Wowless proves
- what Wowless does not prove
- exact bootstrap command
- exact smoke command
- Docker Desktop requirement for Windows
- how to point the harness at a GBankManager worktree

The main addon repo should later include a short pointer in `docs/testing.md` explaining that:

- Wowless smoke lives in the companion repo
- it is optional/non-blocking at first
- live retail smoke is still required for release confidence

## Rollout Plan

### Phase 1

- create the companion repo structure
- document prerequisites
- add local bootstrap script
- add local run-smoke script
- pin a Wowless runtime source/version
- run the first addon-load smoke against GBankManager

### Phase 2

- add structured smoke checks for slash/bootstrap/view-selection
- emit CI-friendly result output
- document troubleshooting

### Phase 3

- add optional GitHub Actions integration
- gather several stable runs
- decide whether the job should remain optional or become required

## Risks

- Docker requirement may slow contributor onboarding.
- Wowless upstream instability may create false negatives.
- A separate repo introduces coordination overhead if the contract is underspecified.
- Over-scoping the first slice into deep UI verification would make the lane brittle quickly.

## Mitigations

- keep the contract to a single addon-root input
- keep first smoke checks shallow and high-value
- keep the lane optional first
- document limitations prominently
- prefer Linux CI once the local path is validated

## Testing Strategy For This Design

The design is successful when:

- a developer with Docker Desktop can run one command in the companion repo and get a PASS/FAIL smoke result for a local GBankManager worktree
- failures clearly distinguish environment issues from addon regressions
- the main addon repo stays free of heavy Wowless runtime machinery
- the companion lane complements rather than replaces local Lua lanes and live-retail smoke

## Recommendation

Proceed with a dedicated `GBankManager-wowless-smoke` companion repo that owns a Docker-based Wowless smoke runner and accepts the addon root as an external input. Keep the first implementation slice limited to real addon-load/bootstrap/slash/view smoke, wire it for local execution first, then add an optional CI lane once the runtime path is proven.
