# Crafted Quality Non-Inventory Resolver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split crafted-quality presentation so Inventory keeps its current path while every non-inventory surface resolves through one bundled-data-authoritative resolver.

**Architecture:** Add a dedicated non-inventory crafted-quality presentation helper in `GBankManager/Domain/CraftedQuality.lua` that returns one normalized atlas/markup payload for shared tables, search selectors, detail modals, and exports. Keep `ItemCatalog.ApplyCanonicalCraftedQuality()` responsible for canonical bundled item metadata, but stop asking the inventory-oriented resolver to answer non-inventory questions in view/controller files.

**Tech Stack:** Lua 5.1 test runner, WoW UI frame helpers, bundled `GBankManager_ItemData` metadata, focused UI regression specs.

---

### Task 1: Capture the non-inventory resolver contract in tests

**Files:**
- Modify: `tests/spec/crafted_quality_spec.lua`
- Modify: `tests/spec/ui_crafted_quality_live_regression_spec.lua`
- Modify: `tests/spec/ui_search_results_control_spec.lua`
- Test: `.\tools\lua\lua.exe .\tests\run_ui.lua`

- [ ] **Step 1: Write the failing crafted-quality resolver expectations**

Add expectations that assert a non-inventory-specific resolver returns the bundled two-rank atlas for `241320`, `241322`, `241324`, and `243734`, while generic non-item-aware behavior stays unchanged.

- [ ] **Step 2: Run the focused specs to verify the new assertions fail**

Run: `.\tools\lua\lua.exe .\tests\run_ui.lua`
Expected: FAIL in the new crafted-quality assertions because the helper does not exist yet.

- [ ] **Step 3: Extend live UI regression coverage**

Add assertions for Minimums, Requests, Request Details, search selectors, and Exports so each surface proves it is consuming one non-inventory crafted-quality source of truth.

- [ ] **Step 4: Re-run the focused specs**

Run: `.\tools\lua\lua.exe .\tests\run_ui.lua`
Expected: FAIL in the new UI crafted-quality assertions and PASS elsewhere.

### Task 2: Implement the dedicated non-inventory resolver

**Files:**
- Modify: `GBankManager/Domain/CraftedQuality.lua`
- Modify: `GBankManager/Domain/ItemCatalog.lua`
- Test: `tests/spec/crafted_quality_spec.lua`

- [ ] **Step 1: Add a non-inventory presentation helper**

Implement a helper that resolves canonical item fields, determines the correct non-inventory display atlas, and returns a single payload shaped for both texture and markup consumers.

- [ ] **Step 2: Keep Inventory behavior isolated**

Retain the existing inventory-aware display path so generic inventory rows and known good inventory item rows do not regress.

- [ ] **Step 3: Update diagnostics**

Expose the non-inventory final atlas in crafted-quality debug output so `/gbm debug quality <itemID>` reflects the shared non-inventory path directly.

- [ ] **Step 4: Run crafted-quality specs**

Run: `.\tools\lua\lua.exe .\tests\run_unit.lua`
Expected: PASS for `tests/spec/crafted_quality_spec.lua`.

### Task 3: Rewire non-inventory callers end to end

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `GBankManager/UI/MainRequestsController.lua`
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `GBankManager/UI/MainExportsController.lua`
- Test: `tests/spec/ui_requests_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/ui_search_results_control_spec.lua`
- Test: `tests/spec/ui_crafted_quality_live_regression_spec.lua`

- [ ] **Step 1: Replace direct non-inventory atlas or markup calls**

Route table rows, search rows, request details, minimum details, selected-item previews, and exports through the new non-inventory crafted-quality payload helper.

- [ ] **Step 2: Preserve texture-first rendering**

Continue to prefer dedicated texture regions where they already exist, using the helper payload’s atlas, and only use inline markup when a texture slot truly is unavailable.

- [ ] **Step 3: Run the focused UI suite**

Run: `.\tools\lua\lua.exe .\tests\run_ui.lua`
Expected: PASS for crafted-quality UI coverage.

### Task 4: Verify, document, and hand off

**Files:**
- Modify: `docs/testing.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Test: `.\tools\lua\lua.exe .\tests\run_all.lua`

- [ ] **Step 1: Update docs**

Document that non-inventory crafted-quality surfaces now share one bundled-data-authoritative resolver, while Inventory remains the reference texture path.

- [ ] **Step 2: Run the full suite**

Run: `.\tools\lua\lua.exe .\tests\run_all.lua`
Expected: PASS for crafted-quality changes; report any unrelated pre-existing harness failures exactly.

- [ ] **Step 3: Record the next blocker**

Update the latest handoff to note the crafted-quality resolver status and leave passive ledger refresh as the remaining live blocker if crafted-quality verification is green.
