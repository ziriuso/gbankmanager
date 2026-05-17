# GBankManager UI Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a full-screen visual modernization pass for the GBankManager addon while preserving current workflows, exports, permissions, scans, requests, and SavedVariables compatibility.

**Architecture:** Build a reusable presentation layer first: theme manager, style tokens, quality-icon renderer, and shared shell or table or modal helpers. Then migrate the shell, Dashboard, tables, Minimums, Requests, Exports, About, and Options onto that foundation without changing their domain contracts.

**Visual Target:** The supplied style-guide mockup is the near-literal look-and-feel target. Favor shared-primitive rewrites over incremental restyling when the current helper layer cannot reproduce the mockup's composition, hierarchy, and surface treatment.

**Tech Stack:** WoW Lua addon modules, Blizzard atlas-backed UI textures, current shared shell and table controllers, Lua unit and UI specs, in-client manual validation.

---

### Task 1: Add the shared theme and style-token foundation

**Files:**
- Create: `GBankManager/UI/ThemeManager.lua`
- Create: `GBankManager/UI/StyleTokens.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `tests/spec/ui_shell_spec.lua`
- Modify: `tests/spec/ui_options_spec.lua`

- [ ] Write failing tests for theme registry, preset migration, token lookup, invalid-theme fallback, and live theme-switch repaint hooks.
- [ ] Run `.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua` and `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua` and confirm the new assertions fail for the expected missing-theme-layer reason.
- [ ] Implement `ThemeManager.lua` and `StyleTokens.lua` with the six required themes, token lookup, preset migration, semantic status colors, density tokens, and repaint registration hooks.
- [ ] Refactor `MainFrameShell.lua` to consume the new foundation without changing existing caller contracts more than necessary.
- [ ] Re-run the targeted specs until they pass.

### Task 2: Add the reusable crafting quality icon renderer

**Files:**
- Create: `GBankManager/UI/Components/QualityIcon.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Domain/CraftedQuality.lua`
- Modify: `GBankManager/UI/InventoryView.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `GBankManager/UI/MainRequestsController.lua`
- Modify: `GBankManager/UI/MainExportsController.lua`
- Modify: `tests/spec/inventory_quality_spec.lua`
- Modify: `tests/spec/ui_exports_spec.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `tests/spec/in_game_unit_spec.lua`

- [ ] Write failing tests for two-tier rendering, five-tier rendering, atlas verification fallback, and size-aware rendering through one shared helper.
- [ ] Run the targeted specs and confirm the failures point to the missing shared renderer behavior rather than unrelated setup breakage.
- [ ] Implement a table-driven quality-icon renderer that verifies atlas availability at runtime when possible, applies textures with `SetAtlas`, and falls back safely to markup or a preserved atlas string.
- [ ] Update existing views and controllers to call the shared renderer instead of duplicating local quality-markup helpers.
- [ ] Re-run the targeted specs until they pass.

### Task 3: Rebuild the shared shell, navigation, header, buttons, sliders, and modal primitives for mockup fidelity

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_shell_spec.lua`
- Modify: `tests/spec/ui_options_spec.lua`

- [ ] Write failing tests for updated nav-button state, sidebar collapse behavior, header control layout under scale, modal opacity propagation, and safer slider interaction surfaces.
- [ ] Run the targeted specs and confirm the new expectations fail.
- [ ] Implement the new shell chrome, navigation rail, header composition, button variants, slider styling, input styling, and shared modal frame treatment using the theme and token layer.
- [ ] Do not reuse the old generic bordered panel or button look where it blocks fidelity; replace it with explicit shell variants that match the mockup.
- [ ] Re-run the targeted specs until they pass.

### Task 4: Upgrade the shared table system and screen-level data presentation to match the mockup's dense Blizzard-style table treatment

**Files:**
- Modify: `GBankManager/UI/MainTableController.lua`
- Modify: `GBankManager/UI/TableLayouts.lua`
- Modify: `GBankManager/UI/InventoryView.lua`
- Modify: `GBankManager/UI/HistoryView.lua`
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `GBankManager/UI/DashboardView.lua`
- Modify: `tests/spec/ui_table_spec.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `tests/spec/dashboard_spec.lua`

- [ ] Write failing tests for density-aware row sizing, alternating row treatment, header styling metadata, badge-capable column rendering, dashboard card data expansion, and Inventory or History or Request table contract changes.
- [ ] Run the targeted specs and confirm the failures are isolated to the new presentation contract.
- [ ] Implement the shared table modernization: row heights, alternating rows, hover and selection treatment, status-badge rendering, filter-row separation, tighter gold-framed headers, and any new dashboard card data required by the redesign.
- [ ] Re-run the targeted specs until they pass.

### Task 5: Rework Minimums staging visuals and staging-first ordering

**Files:**
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `GBankManager/UI/TableLayouts.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`

- [ ] Write failing tests for staged rows grouped at the top, `ADD` or `EDIT` or `DELETE` badge labeling, emphasized staged-change summary text, and save or revert affordance behavior.
- [ ] Run `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua` and confirm the new assertions fail.
- [ ] Implement display-only grouping and styling of staged rows without changing the existing pending overlay semantics or `Save All` persistence behavior.
- [ ] Re-run the targeted spec until it passes.

### Task 6: Redesign Request Admin and export surfaces on top of the shared primitives with near-literal mockup composition

**Files:**
- Modify: `GBankManager/UI/MainRequestsController.lua`
- Modify: `GBankManager/UI/MainExportsController.lua`
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `GBankManager/UI/ExportsView.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `tests/spec/ui_exports_spec.lua`
- Modify: `tests/spec/exports_spec.lua`

- [ ] Write failing tests for Request Admin tab-like filters, badge treatment, export action cards, and preserved export compatibility.
- [ ] Run the targeted specs and confirm the failures are UI-contract failures rather than output-format failures.
- [ ] Implement the Request Admin visual re-layout and the export-card presentation while keeping the underlying actions and generated export strings unchanged.
- [ ] Re-run the targeted specs until they pass.

### Task 7: Redesign Dashboard, About, and Options for the new visual system with near-literal mockup composition

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/DashboardView.lua`
- Modify: `tests/spec/dashboard_spec.lua`
- Modify: `tests/spec/ui_options_spec.lua`

- [ ] Write failing tests for dashboard metric-card content, quick-action availability, options tabbed sections, appearance control persistence, and preserved request-only behavior where applicable.
- [ ] Run the targeted specs and confirm the failures are specific to the new shell or view contract.
- [ ] Implement the dashboard panel redesign, cleaner About composition, and tabbed Options layout using the shared theme and component layer.
- [ ] Treat visual comparison against the supplied mockup as a required acceptance gate, not an optional polish pass.
- [ ] Re-run the targeted specs until they pass.

### Task 8: Update documentation and verify the full addon

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/ui-polish-suggestions.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`

- [ ] Update product and QA docs to describe the new theme system, density setting, quality-icon renderer, staged Minimums visuals, and the visual expectations for each main screen.
- [ ] Run `.\tools\lua\lua.exe .\tests\run_all.lua`.
- [ ] If the automated lanes are green, deploy with `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail` for live visual validation.
- [ ] After deployment, compare the live addon directly against the supplied mockup and log remaining fidelity gaps before calling the pass complete.
