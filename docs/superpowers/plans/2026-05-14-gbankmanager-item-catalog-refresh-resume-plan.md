# GBankManager Item Catalog Refresh Resume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit `-Fresh` and `-Resume` execution modes to the maintainer item-catalog refresh flow so long-running extraction can survive interruption and continue from the last completed sequential `itemID`.

**Architecture:** `Refresh-ItemCatalog.ps1` becomes the explicit mode gate and state coordinator. `Extract-ItemDb2.ps1` and its Node helper become batch-aware and progress-aware. A target-scoped progress file under `tools/catalog/runtime/state/` records extraction state, and merge/build remain downstream phases that only run after extraction is finalized.

**Tech Stack:** Windows PowerShell maintainer tooling, Node extraction helper, JSON progress files, existing JSON refresh summaries, Lua test harness, fixture-driven catalog pipeline specs.

---

## Current Files To Modify

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Extract-ItemDb2.ps1`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\runtime\extract-item-db2.js`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\README.md`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`

## Current Tests To Extend

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_extract_spec.lua`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_target_spec.lua`

## New Files To Add

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\runtime\state\` directory contract

---

## Guardrails

- Require exactly one of `-Fresh` or `-Resume`.
- Keep resumability target-scoped so Retail, PTR, and Beta do not collide.
- Keep merge/build blocked until extraction completes cleanly.
- Do not silently fall back from invalid resume state to fresh execution.
- Preserve categorized failure reporting.
- Keep documentation current with the actual command contract.

---

## Phase 1: Mode Gate And Progress Contract

**Goal:** Add the explicit mode surface and define the progress-file contract before changing extraction internals.

- [ ] Add failing tests for:
  - missing `-Fresh` / `-Resume`
  - both switches provided
  - `-Resume` with no progress file
- [ ] Update `Refresh-ItemCatalog.ps1` to require exactly one mode switch.
- [ ] Add deterministic target-scoped progress file path resolution under `tools/catalog/runtime/state/`.
- [ ] Add the top-level JSON fields:
  - `mode`
  - `progressPath`
  - `resumeSupported`
  - `phase`
- [ ] Run focused target/contract specs.

**Success criteria:**

- the maintainer command no longer has ambiguous execution behavior
- JSON summaries expose the progress file location and mode

---

## Phase 2: Extraction State Persistence

**Goal:** Persist extraction progress incrementally and safely enough to survive interruption.

- [ ] Add failing extraction-spec coverage for progress file creation and update.
- [ ] Extend the Node extraction helper to:
  - process normalized rows in ascending `itemID`
  - write batch progress
  - emit `lastProcessedItemID`
  - emit `lastProcessedIndex`
  - emit `highestSeenItemID`
  - emit `normalizedCountWritten`
- [ ] Update `Extract-ItemDb2.ps1` to pass through mode, state path, and output path details.
- [ ] Make fixture extraction write progress incrementally, not only at the end.
- [ ] Run focused extraction specs.

**Success criteria:**

- interrupted extraction leaves a valid progress file
- partial normalized output remains usable for resume

---

## Phase 3: Fresh And Resume Execution

**Goal:** Implement the real execution semantics for `-Fresh` and `-Resume`.

- [ ] Add failing tests for:
  - `-Fresh` clearing old state
  - `-Resume` restarting after `lastProcessedItemID`
  - invalid/corrupt resume state failing clearly
- [ ] Implement `-Fresh` behavior:
  - clear target-scoped progress state
  - clear target-scoped partial extracted output
  - initialize new progress state
- [ ] Implement `-Resume` behavior:
  - require an existing valid progress state
  - continue from the saved completed item boundary
  - preserve prior extracted rows
- [ ] Run focused extraction and refresh contract specs.

**Success criteria:**

- a broken long run can continue without restarting from item `1`
- invalid resume state fails explicitly instead of guessing

---

## Phase 4: Merge And Build Phase Coordination

**Goal:** Keep downstream phases clean while allowing resume-aware extraction to feed them.

- [ ] Add failing tests for merge/build only running after finalized extraction.
- [ ] Ensure `Refresh-ItemCatalog.ps1` distinguishes:
  - extraction failed but resumable
  - extraction complete
  - merge failed
  - build failed
- [ ] Preserve progress metadata in failure JSON for downstream diagnosis.
- [ ] Allow completed extraction to move into merge/build without losing state context.
- [ ] Run focused merge/target specs.

**Success criteria:**

- merge/build cannot run against incomplete extraction output
- failure classification remains accurate after resume support lands

---

## Phase 5: Docs And Full Verification

**Goal:** Document the operational maintainer flow and verify the pipeline still works broadly.

- [ ] Update:
  - `tools/catalog/README.md`
  - `README.md`
  - `docs/minimum-item-catalog-strategy.md`
- [ ] Document:
  - when to use `-Fresh`
  - when to use `-Resume`
  - where progress files live
  - how to recover from invalid resume state
  - what pass/fail means
- [ ] Rebuild generated addon data.
- [ ] Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
- [ ] Run at least one real local refresh attempt with the new mode contract and record whether it reaches a resumable boundary or full completion.

**Success criteria:**

- maintainers have a clear operational recipe for full database refreshes
- the addon test suite remains green
- the long-running refresh path is now recoverable

