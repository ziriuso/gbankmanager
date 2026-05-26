# GBankManager Item Catalog Maintainer Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current primary item-catalog refresh path with a local-client, target-selectable maintainer pipeline that builds `GBankManager_ItemData` from Retail, PTR, or Beta installs while preserving the existing addon-side shared search behavior.

**Architecture:** The addon-side `ItemCatalog` and `GBankManager_ItemData` split stays intact. New maintainer scripts under `tools/catalog/` will resolve a WoW target, extract and normalize item rows from the selected client, merge them into the checked-in manifest, and rebuild the bundled data addon. Existing Blizzard API and credential-free refresh scripts will remain temporarily, but documentation will demote them to fallback status.

**Tech Stack:** Lua addon runtime, Windows PowerShell maintainer tooling, checked-in JSON manifest, generated Lua addon data, WoW local client data extraction, existing local test harness `.\tools\lua\lua.exe .\tests\run_all.lua`

---

## Current File Structure And Responsibilities

### Existing addon-side files

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Domain\ItemCatalog.lua`
  - shared runtime search and merge path for bundled and learned item data
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\GBankManager_ItemData.toc`
  - load-on-demand addon descriptor for bundled item data
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\Data.lua`
  - generated bundled item data payload
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\runtime\item-catalog-input.json`
  - checked-in source-of-truth manifest for generated item data

### Existing maintainer tooling

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Build-ItemDataAddon.ps1`
  - rebuilds `GBankManager_ItemData\Data.lua` from the manifest
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Export-StaticItemCatalog.ps1`
  - low-level JSON-to-Lua generator
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Update-BlizzardItemMetadata.ps1`
  - existing credentialed metadata path to demote
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Update-CredentialFreeItemCatalog.ps1`
  - existing public-upstream path to demote

### New files to add

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Resolve-WoWTarget.ps1`
  - named-target and explicit-path resolution helper
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Extract-ItemDb2.ps1`
  - local-client extraction entrypoint for selected target
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Merge-ExtractedItemCatalog.ps1`
  - merge logic for normalized extracted rows into the checked-in manifest
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
  - top-level maintainer orchestration command
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Import-LearnedItemCatalog.ps1`
  - imports runtime-learned item rows into the manifest
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_merge_spec.lua`
  - merge rule coverage
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_target_spec.lua`
  - target resolution contract coverage

### Existing docs to update

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`

---

## Guardrails

- Keep the addon-side `ItemCatalog` interface stable while maintainer tooling evolves.
- Do not regress current Minimums or Requests search behavior during pipeline work.
- Keep the generated addon output minimal and derived; do not ship raw DB2 extracts.
- Prefer branch-aware local-client data over Blizzard web API item metadata.
- Keep Windows PowerShell the primary maintainer shell.
- Follow TDD where behavior changes are being introduced.
- Run `.\tools\lua\lua.exe .\tests\run_all.lua` after each completed slice that touches addon/runtime behavior.

---

## Phase 1: Target Resolution And Documentation Baseline

**Goal:** Introduce the named target model and make the repo docs reflect the new primary maintainer strategy before extraction logic lands.

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Resolve-WoWTarget.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_target_spec.lua`

- [ ] Add focused target-resolution tests covering `Retail`, `PTR`, `Beta`, and `-WoWRoot` override behavior.
- [ ] Implement `Resolve-WoWTarget.ps1` with explicit named targets, sane default install roots, and overridable locale/path handling.
- [ ] Make docs clearly state that local-client extraction is now the recommended primary path.
- [ ] Demote Blizzard API and credential-free catalog scripts in docs to fallback or legacy status only.
- [ ] Run the focused target-resolution tests.
- [ ] Commit the target-resolution and docs baseline.

**Success criteria:**

- maintainers have one clear recommended path
- the target model is explicit and documented
- repo docs no longer describe Blizzard web enrichment as the primary strategy

---

## Phase 2: Refresh Orchestration Shell

**Goal:** Add a top-level maintainer command that resolves a target, validates the environment, and prepares the orchestration contract even before full extraction logic is complete.

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Build-ItemDataAddon.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_target_spec.lua`

- [ ] Add tests that define the expected environment-failure contract for unknown targets, missing roots, and missing required client data paths.
- [ ] Implement `Refresh-ItemCatalog.ps1` to call `Resolve-WoWTarget.ps1`, validate the selected install, and emit a structured summary or explicit failure classification.
- [ ] Keep the top-level script able to stop cleanly before extraction with actionable diagnostics if the environment is incomplete.
- [ ] Update `tools/catalog/README.md` with the new canonical command examples.
- [ ] Run the focused target and contract tests.
- [ ] Commit the orchestration shell.

**Success criteria:**

- a maintainer can run one canonical command per target
- missing-install failures are explicit and categorized
- the repo has one documented entrypoint for catalog refresh

---

## Phase 3: Local Extraction And Normalization

**Goal:** Implement local-client extraction for the selected target and normalize the result into the minimal manifest schema used by the addon.

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Extract-ItemDb2.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\runtime\item-catalog-input.json`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_merge_spec.lua`

- [ ] Add tests that define the normalized row contract:
  - `itemID`
  - `name`
  - `quality`
  - `qualityName`
  - `status`
  - `source`
  - `target`
  - `build`
  - `locale`
  - `lastVerifiedAt`
- [ ] Implement `Extract-ItemDb2.ps1` to extract raw item rows from the selected local client and merge hotfix-aware data from that target.
- [ ] Normalize extracted rows into the checked-in manifest schema, keeping the output minimal and addon-focused.
- [ ] Wire `Refresh-ItemCatalog.ps1` to invoke the extraction and normalization phase.
- [ ] Run the focused normalization and merge tests.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Refresh-ItemCatalog.ps1 -Target Retail` on a real local install and capture the first successful target refresh summary.
- [ ] Commit the extraction and normalization slice.

**Success criteria:**

- a selected local client target yields normalized manifest rows
- the row schema matches the addon’s actual needs
- the refresh command can produce a real extracted dataset from Retail at minimum

---

## Phase 4: Manifest Merge Rules

**Goal:** Make manifest updates additive and stable so target refreshes do not churn or erase valid existing data.

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Merge-ExtractedItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\runtime\item-catalog-input.json`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_merge_spec.lua`

- [ ] Add tests for merge behavior covering:
  - new rows are added
  - fresher confirmed rows replace older metadata
  - learned rows remain until confirmed rows supersede them
  - missing rows are not silently deleted on first absence
  - deprecated candidates are retained intentionally
- [ ] Implement `Merge-ExtractedItemCatalog.ps1` to merge normalized extracted rows into the checked-in manifest according to the approved rules.
- [ ] Stamp refreshed rows with `target`, `build`, and `lastVerifiedAt`.
- [ ] Keep merge output deterministic so rebuilds are reviewable in git.
- [ ] Run the merge tests.
- [ ] Run a full target refresh and inspect manifest diff quality.
- [ ] Commit the merge slice.

**Success criteria:**

- manifest refreshes are additive and reviewable
- one target refresh cannot accidentally wipe valid catalog history
- merge behavior is covered by focused tests

---

## Phase 5: Generated Addon Rebuild Integration

**Goal:** Make the new refresh flow regenerate `GBankManager_ItemData` cleanly and keep addon-side search behavior stable.

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Build-ItemDataAddon.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\Data.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\run_all.lua`

- [ ] Add or extend tests to confirm generated item data still loads lazily and still supports shared Minimums and Requests search.
- [ ] Wire `Refresh-ItemCatalog.ps1` to call `Build-ItemDataAddon.ps1` after a successful merge.
- [ ] Keep generated output compact and derived rather than embedding raw extraction payloads.
- [ ] Run `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Build-ItemDataAddon.ps1`.
- [ ] Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
- [ ] Commit the generated-addon integration slice.

**Success criteria:**

- one refresh command can produce a new checked-in `GBankManager_ItemData\Data.lua`
- addon-side search behavior remains green
- local tests continue to pass

---

## Phase 6: Runtime-Learned Import Path

**Goal:** Allow maintainers to merge runtime-learned item discoveries back into the manifest without overriding fresher extracted metadata.

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Import-LearnedItemCatalog.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_merge_spec.lua`

- [ ] Add tests that define learned-item import behavior:
  - imported learned rows are added
  - confirmed rows are not overwritten by learned rows
  - later confirmed refreshes can supersede learned metadata
- [ ] Implement `Import-LearnedItemCatalog.ps1` with a clear input contract for addon-exported learned item rows.
- [ ] Document when maintainers should use learned-item import, especially for PTR and Beta discovery.
- [ ] Run the learned-item merge tests.
- [ ] Commit the learned-item import slice.

**Success criteria:**

- PTR and Beta discoveries can feed back into the manifest
- learned rows supplement but do not destabilize confirmed extracted data

---

## Phase 7: Final Docs And Maintainer Validation

**Goal:** Make the new pipeline understandable and repeatable for future maintainers.

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`

- [ ] Document the canonical commands for `Retail`, `PTR`, and `Beta`.
- [ ] Document explicit `-WoWRoot` override usage.
- [ ] Document pass/fail categories:
  - environment failure
  - extraction failure
  - schema failure
  - merge failure
  - generation failure
- [ ] Add a short maintainer smoke recipe:
  1. refresh target
  2. rebuild item data
  3. run addon test suite
  4. optionally deploy both addon folders and live-test search
- [ ] Verify docs match the actual commands and script names.
- [ ] Commit the final maintainer documentation slice.

**Success criteria:**

- a future maintainer can refresh the dataset without reading implementation code
- docs reflect the real primary workflow and fallback paths honestly

---

## Spec Coverage Check

This plan covers the approved spec sections as follows:

- target model: Phases 1 and 2
- local extraction and hotfix-aware refresh: Phase 3
- merge rules and manifest model: Phase 4
- generated addon output: Phase 5
- runtime-learned import path: Phase 6
- pass/fail contract and maintainer docs: Phases 2 and 7
- documentation updates: Phases 1 and 7

No approved spec section is intentionally omitted.

