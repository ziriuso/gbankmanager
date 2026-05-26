# Item Search Selector Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile shared item search with a token-ranked catalog resolver and a scrollable, quality-aware shared result list for Minimums and Requests.

**Architecture:** Keep the search engine in `GBankManager/Domain/ItemCatalog.lua` and keep the UI reusable in `GBankManager/UI/MainFrameShell.lua`. Minimums and Requests should continue to consume one shared selector, while focused specs lock the resolver behavior, selection gating, and result-list rendering contract.

**Tech Stack:** Lua 5.1 addon runtime, shared WoW frame helpers, focused Lua specs under `tests/spec/`, local Lua runner at `tools/lua/lua.exe`

---

## File Map

- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Domain\ItemCatalog.lua`
  - Add token normalization, token-aware ranking, and broader multi-match result behavior.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
  - Replace the fixed match-button stack with a reusable scrollable result list that can show quality icon, item name, and item ID.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
  - Keep Minimums `Add` gated behind a confirmed selected catalog item and bind it to the redesigned shared selector.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainRequestsController.lua`
  - Keep Requests item selection aligned with the redesigned shared selector and confirmed-selection contract.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Testing\LiveSmoke.lua`
  - Keep the live smoke path aligned with the selected-catalog-item contract.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
  - Add resolver behavior coverage for tokenized multi-word search and exact-vs-ambiguous selection rules.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
  - Add focused coverage for scrollable shared results and Minimums gating.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`
  - Add focused coverage for Requests shared results and selection behavior.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\live_smoke_spec.lua`
  - Keep the direct live-smoke spec aligned with the selected-item contract.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`

### Task 1: Lock The Resolver Contract In Tests

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\lua\lua.exe`

- [ ] **Step 1: Write the failing resolver tests**

Add assertions like:

```lua
local broadResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = {
        { itemID = 241322, name = "Flask of the Magisters" },
        { itemID = 241323, name = "Flask of the Magisters" },
        { itemID = 241324, name = "Flask of the Blood Knights", craftedQuality = 1, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1" },
        { itemID = 241325, name = "Flask of the Blood Knights", craftedQuality = 2, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2" },
    },
}, "flask of")
assert.equal("multiple", broadResolution.status, "token search should keep broad multi-word queries in multi-match mode")
assert.truthy(#(broadResolution.matches or {}) >= 4, "token search should return every matching flask-of variant")

local normalizedResolution = itemCatalog.ResolveQuery({
    items = {},
    searchCatalog = {
        { itemID = 241322, name = "Flask of the Magisters" },
        { itemID = 241323, name = "Flask of the Magisters" },
    },
}, "flask magister")
assert.equal("multiple", normalizedResolution.status, "token search should match singular/plural-friendly variants")
assert.equal(2, #(normalizedResolution.matches or {}), "token search should return all matching Magisters rows")
```

- [ ] **Step 2: Run the direct resolver spec to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected: `FAIL` on the new token-search assertions because the current resolver still uses raw substring matching and limited ranking.

- [ ] **Step 3: Implement the minimal resolver changes**

Add helper functions in `ItemCatalog.lua` for normalization and ranking, for example:

```lua
local function normalize_search_text(value)
    local lowered = string.lower(tostring(value or ""))
    lowered = lowered:gsub("[%p%c]", " ")
    lowered = lowered:gsub("%s+", " ")
    lowered = lowered:gsub("^%s+", ""):gsub("%s+$", "")
    return lowered
end

local function normalize_token(token)
    token = normalize_search_text(token)
    if token:sub(-1) == "s" and #token > 3 then
        return token:sub(1, -2)
    end
    return token
end
```

Use those helpers to:

- split query text into tokens
- require every token to be present
- score exact full-name, exact prefix, in-order token, and any-order token matches
- keep exact numeric item-ID resolution unchanged

- [ ] **Step 4: Run the direct resolver spec again**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected: `PASS`

- [ ] **Step 5: Commit**

```powershell
git add GBankManager/Domain/ItemCatalog.lua tests/spec/item_catalog_spec.lua
git commit -m "feat: rank token-based item catalog searches"
```

### Task 2: Redesign The Shared Result List UI

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\helpers\wow_stubs.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`

- [ ] **Step 1: Write the failing shared-selector UI tests**

Add focused assertions such as:

```lua
mainFrame.minimumAddItemNameInput:SetText("flask of")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should show a scrollable result panel for broad token queries")
assert.truthy((mainFrame.minimumAddResultsScrollFrame or {}).scrollChild ~= nil, "minimum add modal should wire a scroll child for result rows")
assert.truthy(string.find(mainFrame.minimumAddResultRows[1].itemText:GetText() or "", "241", 1, true) ~= nil, "result rows should show the item id inline")
assert.truthy(mainFrame.minimumAddResultRows[1].qualityIcon ~= nil, "result rows should expose a crafting quality icon region")
```

Mirror the same contract in `ui_requests_spec.lua`.

- [ ] **Step 2: Run the focused UI specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected: `FAIL` because the selector still renders a fixed match-button stack instead of a scrollable result list.

- [ ] **Step 3: Implement the shared scrollable result list**

Replace the fixed button stack in `MainFrameShell.lua` with a reusable structure like:

```lua
selector.resultsScrollFrame = _G.CreateFrame("ScrollFrame", nil, selector.resultsPanel)
selector.resultsScrollFrame:SetPoint("TOPLEFT", selector.resultsPanel, "TOPLEFT", 4, -4)
selector.resultsScrollFrame:SetPoint("BOTTOMRIGHT", selector.resultsPanel, "BOTTOMRIGHT", -20, 4)

selector.resultsScrollChild = _G.CreateFrame("Frame", nil, selector.resultsScrollFrame)
selector.resultsScrollChild:SetSize(resultsPanelWidth - 28, resultsPanelHeight)
selector.resultsScrollFrame:SetScrollChild(selector.resultsScrollChild)
```

Each reusable result row should own:

- `qualityIcon`
- `itemText`
- click handler that calls `ApplySelectedItem`

Format the label as:

```lua
local qualityLabel = craftedQuality and string.format("T%d", craftedQuality) or "-"
row.itemText:SetText(string.format("%s  [%s]  (%s)", name, qualityLabel, itemID))
```

The icon should show when `craftedQualityIcon` exists and hide otherwise.

- [ ] **Step 4: Run the focused UI specs again**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected: `PASS`

- [ ] **Step 5: Commit**

```powershell
git add GBankManager/UI/MainFrameShell.lua tests/helpers/wow_stubs.lua tests/spec/ui_minimums_spec.lua tests/spec/ui_requests_spec.lua
git commit -m "feat: add scrollable shared item search results"
```

### Task 3: Keep Minimums, Requests, And Smoke Gating Consistent

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainRequestsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Testing\LiveSmoke.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\live_smoke_spec.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\run_all.lua`

- [ ] **Step 1: Write the failing gating and smoke assertions**

Extend `ui_minimums_spec.lua` and `live_smoke_spec.lua` with checks like:

```lua
assert.truthy(mainFrame.minimumAddButton.enabled == false, "minimum add should stay disabled until a catalog result is selected")
mainFrame.minimumAddResultRows[1]:GetScript("OnClick")(mainFrame.minimumAddResultRows[1])
assert.truthy(mainFrame.minimumAddButton.enabled ~= false, "minimum add should enable after selecting a result row")
```

Keep the live smoke path aligned by asserting the smoke command still returns `PASS` after using the selector-driven add contract.

- [ ] **Step 2: Run the focused specs to verify the new assertions**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\live_smoke_spec.lua
```

Expected: `FAIL` until the controllers and smoke path consume the new scrollable result rows consistently.

- [ ] **Step 3: Implement the minimal controller and smoke updates**

In `MainMinimumsController.lua` and `MainRequestsController.lua`:

- keep `minimumAddSelectedCatalogItem` / request-side selected item as the source of truth
- enable actions only from confirmed selection
- clear selection and disable actions when typing invalidates the current selection

In `LiveSmoke.lua`:

- trigger item-ID or exact-name resolution through the selector scripts before staging a minimum
- do not bypass the selected-item contract with raw text fields

- [ ] **Step 4: Run the full suite**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected:

```text
PASS tests/run_unit.lua
PASS tests/run_ui.lua
PASS tests/run_integration.lua
PASS tests/run_all.lua
```

- [ ] **Step 5: Commit**

```powershell
git add GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MainRequestsController.lua GBankManager/Testing/LiveSmoke.lua tests/spec/live_smoke_spec.lua tests/spec/ui_minimums_spec.lua
git commit -m "fix: require explicit catalog selection for item search"
```

### Task 4: Update Docs And Re-Deploy

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`

- [ ] **Step 1: Update the docs**

Add explicit notes that:

- name search is token-based
- broad queries like `flask of` should return a scrollable result list
- result rows show crafting quality, item name, and item ID
- Minimums `Add` and Requests item selection require an explicit selected catalog row unless there is an exact direct resolution

- [ ] **Step 2: Run final verification**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
git status -sb
```

Expected:

- full Lua suite passes
- only the intended search-redesign files are modified

- [ ] **Step 3: Deploy for live testing**

Run the existing clean deploy flow that replaces both addon folders:

```powershell
$srcRoot = 'C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1'
$destRoot = 'C:\Gaming\World of Warcraft\_retail_\Interface\AddOns'
```

Replace:

- `GBankManager`
- `GBankManager_ItemData`

- [ ] **Step 4: Commit**

```powershell
git add README.md docs/manual-test-checklist.md
git commit -m "docs: describe token-based shared item search"
```

## Self-Review

- Spec coverage:
  - token-based ranked search is covered in Task 1
  - scrollable result list with quality-visible rows is covered in Task 2
  - explicit selection requirement is covered in Task 3
  - documentation updates are covered in Task 4
- Placeholder scan:
  - no `TODO`, `TBD`, or vague “handle later” language remains
- Type consistency:
  - the plan consistently uses `minimumAddSelectedCatalogItem`, `requestCreate...`, `resultsScrollFrame`, and `resultsScrollChild` as the intended naming direction
