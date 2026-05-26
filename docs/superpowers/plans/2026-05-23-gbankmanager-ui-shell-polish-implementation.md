# GBankManager UI Shell Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the shared GBankManager shell so it feels smoother, more WoW-native, less box-heavy, and more theme-expressive without waiting for a dedicated art pack.

**Status:** Implemented locally on 2026-05-23 with automated tests green. The next step is live visual review in Retail before committing or pushing the checkpoint.

**Architecture:** Update the shared shell contract first, then let Dashboard, tables, actions, tabs, and modals inherit the new treatment. Preserve the current theme manager and behavior model, but rebalance surface variants, native WoW controls, spacing, and active-state expression toward the approved Hybrid Modern direction.

**Tech Stack:** WoW Lua addon runtime, shared shell helpers in `GBankManager/UI/MainFrameShell.lua`, view composition in `GBankManager/UI/MainFrame.lua`, focused Lua test harness in `tests/spec/*.lua`, local test runner `.\tools\lua\lua.exe`

---

## File Structure

- `GBankManager/UI/MainFrameShell.lua`
  - shared surface variants
  - shared button variants
  - nav active-state treatment
  - top header chrome
  - modal shell treatment
  - theme-aware surface alpha behavior
- `GBankManager/UI/MainFrame.lua`
  - shell composition and layout
  - header last-scan string with timezone abbreviation
  - dashboard card inheritance
  - tab/filter/action wiring
- `GBankManager/UI/DashboardView.lua`
  - card and panel layout inheritance for the flatter shell direction
- `GBankManager/UI/HistoryView.lua`
  - table or filter presentation inheritance if needed
- `GBankManager/UI/RequestsView.lua`
  - request-admin tabs or filters if needed
- `GBankManager/Testing/LiveSmoke.lua`
  - smoke assertions that depend on header or appearance behavior
- `tests/spec/ui_shell_spec.lua`
  - shared shell contracts
- `tests/spec/ui_dashboard_spec.lua`
  - dashboard card and panel contracts
- `tests/spec/ui_table_spec.lua`
  - table shell contracts
- `tests/spec/ui_requests_spec.lua`
  - tabs, filters, and action treatment where request surfaces depend on shared shell variants
- `tests/spec/ui_options_spec.lua`
  - appearance state remains stable after shell polish
- `README.md`
  - current shell direction and visual-state notes
- `docs/testing.md`
  - test-lane expectations for shell polish
- `docs/manual-test-checklist.md`
  - manual shell validation
- `docs/superpowers/handoffs/latest-handoff.md`
  - update current checkpoint and remaining UI work

---

### Task 1: Rebalance shared shell surfaces around the approved “Native Paneled” direction

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `tests/spec/ui_shell_spec.lua`
- Test: `tests/spec/ui_shell_spec.lua`

- [ ] **Step 1: Write the failing shell-surface test**

```lua
assert.equal("sidebar-soft-row", mainFrame.sidebarNavStyle, "shell should expose the softer nav-row styling contract")
assert.equal("toolbar-band", mainFrame.headerStyle, "shell should expose the clean toolbar-band header contract")
assert.equal("flat-band", mainFrame.contentSectionStyle, "shell should expose the flatter content-band contract")
assert.truthy((mainFrame.sidebar.gbmSurfaceVariant or "") == "sidebar", "sidebar should still use the shared sidebar surface variant")
assert.truthy((mainFrame.topBar.gbmSurfaceVariant or "") == "header-toolbar", "top bar should move to the toolbar-style header variant")
assert.truthy((mainFrame.content.gbmSurfaceVariant or "") == "content-band", "main content should move to the flatter content-band variant")
```

- [ ] **Step 2: Run the shell spec to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
```

Expected: FAIL because the new shell-style contract names and variants do not exist yet.

- [ ] **Step 3: Implement the minimal shared surface-variant changes**

```lua
local SURFACE_VARIANTS = {
    shell = {
        colorToken = "bg",
        borderToken = "borderSoft",
    },
    sidebar = {
        colorToken = "panel",
        borderToken = "borderSoft",
    },
    ["header-toolbar"] = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
    ["content-band"] = {
        colorToken = "bg",
        borderToken = "borderSoft",
    },
    ["panel-flat"] = {
        colorToken = "panelAlt",
        borderToken = "borderSoft",
    },
}

mainFrame.headerStyle = "toolbar-band"
mainFrame.sidebarNavStyle = "sidebar-soft-row"
mainFrame.contentSectionStyle = "flat-band"

mainFrameShell.ApplySurfaceVariant(mainFrame.topBar, "header-toolbar", currentTheme.colors.panelAlt)
mainFrameShell.ApplySurfaceVariant(mainFrame.content, "content-band", currentTheme.colors.background)
```

- [ ] **Step 4: Run the shell spec to verify it passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua tests/spec/ui_shell_spec.lua
git commit -m "refactor: soften shared shell surface variants"
```

---

### Task 2: Update sidebar nav and top header to the approved shell language

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_shell_spec.lua`
- Modify: `tests/spec/ui_dashboard_spec.lua`
- Test: `tests/spec/ui_shell_spec.lua`
- Test: `tests/spec/ui_dashboard_spec.lua`

- [ ] **Step 1: Write the failing nav and header tests**

```lua
assert.equal("nav-soft", mainFrame.collapseButton.gbmButtonFamily, "sidebar controls should use the softer nav-button family")
assert.equal("nav-soft", ((mainFrame.navButtons or {})[1] or {}).gbmButtonFamily, "sidebar nav rows should use the softer distinct-button family")
assert.equal("selected-strong", ((mainFrame.navButtons or {})[1] or {}).gbmSelectionStyle, "selected nav rows should expose the stronger active-state contract")
assert.truthy(string.find(mainFrame.statusText:GetText() or "", "EDT", 1, true) ~= nil or string.find(mainFrame.statusText:GetText() or "", "EST", 1, true) ~= nil, "header last-scan text should include a timezone abbreviation")
assert.truthy((mainFrame.topBar:GetHeight() or 0) <= 76, "toolbar-band header should stay visually slimmer than the older framed header")
```

- [ ] **Step 2: Run the targeted shell and dashboard tests to verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_dashboard_spec.lua
```

Expected: FAIL because the nav family, stronger active-state contract, and timezone-rendering behavior are not implemented yet.

- [ ] **Step 3: Implement the minimal header and nav updates**

```lua
local function format_scan_status_with_zone(timestamp)
    if not timestamp then
        return "No scan yet"
    end

    local dateText = date("%Y-%m-%d %H:%M %Z", timestamp)
    return "Last scan " .. dateText
end

button.gbmButtonFamily = "nav-soft"
button.gbmSelectionStyle = isSelected and "selected-strong" or "selected-soft"

mainFrame.topBar:SetHeight(math.max(52, math.floor(theme.spacing.topBarHeight * 0.92)))
mainFrame.statusText:SetText(format_scan_status_with_zone(lastScanTimestamp))
```

- [ ] **Step 4: Run the targeted shell and dashboard tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_dashboard_spec.lua
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua GBankManager/UI/MainFrame.lua tests/spec/ui_shell_spec.lua tests/spec/ui_dashboard_spec.lua
git commit -m "refactor: modernize sidebar nav and toolbar header"
```

---

### Task 3: Flatten shared content sections, keep separate metric cards, and preserve structured tables

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/DashboardView.lua`
- Modify: `tests/spec/ui_dashboard_spec.lua`
- Modify: `tests/spec/ui_table_spec.lua`
- Test: `tests/spec/ui_dashboard_spec.lua`
- Test: `tests/spec/ui_table_spec.lua`

- [ ] **Step 1: Write the failing dashboard and table tests**

```lua
assert.truthy((mainFrame.dashboardTopItemsPanel.gbmSurfaceVariant or "") == "panel-flat", "dashboard lower panels should inherit the flatter dark-band surface")
assert.truthy((mainFrame.dashboardRecentActivityPanel.gbmSurfaceVariant or "") == "panel-flat", "recent-activity panel should inherit the flatter dark-band surface")
assert.truthy((mainFrame.dashboardQuickActionsPanel.gbmSurfaceVariant or "") == "panel-flat", "quick-actions panel should inherit the flatter dark-band surface")
assert.truthy((mainFrame.dashboardCards[1].gbmSurfaceVariant or "") == "metric-card-flat", "dashboard metrics should remain separate cards but use the flatter card variant")

assert.truthy((mainFrame.tableHeaderFrame.gbmSurfaceVariant or "") == "table-header-flat", "table headers should use the flatter header shell")
assert.truthy((mainFrame.tableFilterFrame.gbmSurfaceVariant or "") == "table-filter-flat", "table filters should use the flatter filter shell")
assert.truthy((mainFrame.tableViewportFrame.gbmSurfaceVariant or "") == "table-viewport-structured", "table viewport should preserve the structured-row shell")
```

- [ ] **Step 2: Run the targeted dashboard and table tests to verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_dashboard_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_table_spec.lua
```

Expected: FAIL because the flatter panel/card variants and structured table shell variants do not exist yet.

- [ ] **Step 3: Implement the minimal surface inheritance changes**

```lua
SURFACE_VARIANTS["metric-card-flat"] = {
    colorToken = "panelAlt",
    borderToken = "borderSoft",
}

SURFACE_VARIANTS["table-header-flat"] = {
    colorToken = "bgAlt",
    borderToken = "borderSoft",
}

SURFACE_VARIANTS["table-filter-flat"] = {
    colorToken = "panel",
    borderToken = "borderSoft",
}

SURFACE_VARIANTS["table-viewport-structured"] = {
    colorToken = "bg",
    borderToken = "borderSoft",
}

apply_surface_variant(self.dashboardTopItemsPanel, "panel-flat")
apply_surface_variant(self.dashboardRecentActivityPanel, "panel-flat")
apply_surface_variant(self.dashboardQuickActionsPanel, "panel-flat")
apply_surface_variant(self.dashboardCards[1], "metric-card-flat")
apply_surface_variant(self.tableHeaderFrame, "table-header-flat")
apply_surface_variant(self.tableFilterFrame, "table-filter-flat")
apply_surface_variant(self.tableViewportFrame, "table-viewport-structured")
```

- [ ] **Step 4: Run the targeted dashboard and table tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_dashboard_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_table_spec.lua
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua GBankManager/UI/MainFrame.lua GBankManager/UI/DashboardView.lua tests/spec/ui_dashboard_spec.lua tests/spec/ui_table_spec.lua
git commit -m "refactor: flatten content sections and preserve structured tables"
```

---

### Task 4: Convert actions, tabs, filters, and modals to the approved smoother variants

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Modify: `tests/spec/ui_exports_spec.lua`
- Test: `tests/spec/ui_requests_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/ui_exports_spec.lua`

- [ ] **Step 1: Write the failing action or modal tests**

```lua
assert.equal("action-slim", mainFrame.minimumAddButton.gbmButtonFamily, "minimum footer actions should use the slimmer action family")
assert.equal("action-slim", mainFrame.requestRefreshButton.gbmButtonFamily, "request-admin footer actions should use the slimmer action family")
assert.equal("segmented-soft", ((mainFrame.optionsTabButtons or {})[1] or {}).gbmTabStyle, "options tabs should use the softer segmented-tab treatment")
assert.equal("segmented-soft", ((mainFrame.requestFilterButtons or {})[1] or {}).gbmTabStyle, "request filters should use the softer segmented-filter treatment")
assert.truthy((mainFrame.requestDetailsModal.gbmSurfaceVariant or "") == "modal-sheet", "request details should use the cleaner floating-sheet surface")
assert.truthy((mainFrame.minimumDetailsModal.gbmSurfaceVariant or "") == "modal-sheet", "minimum details should use the cleaner floating-sheet surface")
```

- [ ] **Step 2: Run the targeted view tests to verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
```

Expected: FAIL because the slimmer action family, segmented tab style, and floating-sheet modal variant do not exist yet.

- [ ] **Step 3: Implement the minimal action, tab, and modal variant changes**

```lua
BUTTON_VARIANTS["action-slim"] = {
    surfaceVariant = "panel-flat",
}

SURFACE_VARIANTS["modal-sheet"] = {
    colorToken = "modalBg",
    borderToken = "borderSoft",
}

button.gbmButtonFamily = "action-slim"
button.gbmTabStyle = "segmented-soft"

apply_surface_variant(self.requestDetailsModal, "modal-sheet")
apply_surface_variant(self.minimumDetailsModal, "modal-sheet")
apply_surface_variant(self.minimumAddModal, "modal-sheet")
apply_surface_variant(self.exportModal, "modal-sheet")
```

- [ ] **Step 4: Run the targeted view tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua GBankManager/UI/MainFrame.lua GBankManager/UI/RequestsView.lua tests/spec/ui_requests_spec.lua tests/spec/ui_minimums_spec.lua tests/spec/ui_exports_spec.lua
git commit -m "refactor: adopt slimmer actions and cleaner modal sheets"
```

---

### Task 5: Strengthen theme expression and tighten dense-but-clean spacing

**Files:**
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_shell_spec.lua`
- Modify: `tests/spec/ui_options_spec.lua`
- Test: `tests/spec/ui_shell_spec.lua`
- Test: `tests/spec/ui_options_spec.lua`

- [ ] **Step 1: Write the failing theme-expression and spacing tests**

```lua
assert.truthy((mainFrame.themeExpressionStyle or "") == "colored-distinct", "shell should expose the stronger colored-theme expression contract")
assert.truthy((mainFrame.defaultDensityStyle or "") == "dense-clean", "shell should expose the dense-but-clean spacing contract")
assert.truthy((mainFrame.navButtonSpacing or 0) <= 42, "dense-clean spacing should reduce nav spacing from the roomier shell pass")
assert.truthy((mainFrame.dashboardCards[1]:GetHeight() or 0) <= 104, "dense-clean spacing should keep metric cards substantial but not oversized")
assert.truthy((mainFrame.optionsThemeButtons or {}).alliance ~= nil, "theme controls should remain intact after shell-spacing updates")
```

- [ ] **Step 2: Run the targeted shell and options tests to verify failure**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: FAIL because the theme-expression and dense-clean shell contracts are not yet represented in code.

- [ ] **Step 3: Implement the minimal theme and spacing updates**

```lua
mainFrame.themeExpressionStyle = "colored-distinct"
mainFrame.defaultDensityStyle = "dense-clean"

local navButtonSpacing = math.max(36, math.floor(40 * shellScale + 0.5))
local navButtonHeight = math.max(28, math.floor(30 * shellScale + 0.5))

if self.dashboardCards[1] then
    self.dashboardCards[1]:SetHeight(96)
end

apply_surface_variant(self.dashboardCards[1], "metric-card-flat", theme.colors.cardAlliance or theme.colors.panelAlt)
apply_surface_variant(self.dashboardCards[2], "metric-card-flat", theme.colors.cardVoid or theme.colors.panelAlt)
apply_surface_variant(self.dashboardCards[3], "metric-card-flat", theme.colors.cardNature or theme.colors.panelAlt)
apply_surface_variant(self.dashboardCards[4], "metric-card-flat", theme.colors.cardDanger or theme.colors.panelAlt)
```

- [ ] **Step 4: Run the targeted shell and options tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua GBankManager/UI/MainFrame.lua tests/spec/ui_shell_spec.lua tests/spec/ui_options_spec.lua
git commit -m "refactor: strengthen themes and tighten shell spacing"
```

---

### Task 6: Refresh smoke coverage, docs, and handoff after the shell pass

**Files:**
- Modify: `GBankManager/Testing/LiveSmoke.lua`
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Test: `tests/spec/live_smoke_spec.lua`
- Test: `tests/run_all.lua`

- [ ] **Step 1: Write the failing smoke/doc assertions**

```lua
assert.truthy(string.find(summary, "PASS", 1, true) ~= nil, "shell polish smoke should still pass after header, surface, and action changes")
assert.truthy(checksById.opacity_controls ~= nil and checksById.opacity_controls.passed == true, "opacity smoke should keep validating backdrop-only opacity changes")
assert.truthy(checksById.options_render_scroll ~= nil and checksById.options_render_scroll.passed == true, "options shell polish should not break the shared scroll path")
```

- [ ] **Step 2: Run smoke first to verify any shell assumptions that need updating**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua
```

Expected: FAIL only if the shell-polish pass changed smoke expectations that now need to be updated.

- [ ] **Step 3: Update smoke wording and docs to the new shell reality**

```markdown
- shared shell now uses a cleaner toolbar-band header, softer distinct nav rows, flatter dark-band content surfaces, slimmer actions, cleaner floating-sheet modals, structured rows, and colored theme expression without the art pack
- header last-scan time now includes timezone abbreviation
- shell polish keeps native WoW sliders, dense-clean spacing, and backdrop-only opacity behavior
```

- [ ] **Step 4: Run full verification**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected:

- `PASS tests/spec/live_smoke_spec.lua`
- `PASS tests/run_all.lua`

- [ ] **Step 5: Commit**

```bash
git add GBankManager/Testing/LiveSmoke.lua README.md docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
git commit -m "docs: record shell polish checkpoint"
```

---

## Self-Review

### Spec coverage

- Shared shell chrome: covered in Tasks 1 and 2
- Softer nav with stronger active state: covered in Task 2
- Clean toolbar-band header: covered in Task 2
- Last-scan timezone abbreviation: covered in Task 2
- Flatter dark-band content sections: covered in Task 3
- Separate metric cards: covered in Task 3
- Structured tables: covered in Task 3
- Slim modern actions: covered in Task 4
- Cleaner floating-sheet modals: covered in Task 4
- Soft segmented tabs and filters: covered in Task 4
- Colored themes: covered in Task 5
- Dense-but-clean spacing: covered in Task 5
- Docs and smoke refresh: covered in Task 6

No spec gaps remain.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” placeholders remain.
- Every task has file paths, test commands, and concrete code snippets.

### Type consistency

- Shared style labels remain consistent across tasks:
  - `header-toolbar`
  - `content-band`
  - `panel-flat`
  - `metric-card-flat`
  - `table-header-flat`
  - `table-filter-flat`
  - `table-viewport-structured`
  - `modal-sheet`
  - `action-slim`
  - `nav-soft`
  - `segmented-soft`
  - `selected-strong`

---

Plan complete and saved to `docs/superpowers/plans/2026-05-23-gbankmanager-ui-shell-polish-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
