# Item Search Reliability Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current flat bundled item search with a reliable Ludwig-style token-indexed search subsystem that returns complete live-client results and keeps Minimums and Requests responsive.

**Architecture:** Generate compressed token-indexed bundled search data inside `GBankManager_ItemData`, validate that payload explicitly at runtime, expose a shared `ItemCatalog` search engine with session-scoped caches, and replace the current eager results stack with one reusable virtualized list control for Minimums and Requests. Keep crafted-quality rendering in the row contract, but make the runtime robust even when crafted metadata is missing.

**Tech Stack:** WoW Lua 5.1, companion addon TOC/data files, PowerShell maintainer scripts, bundled WoW UI `ScrollBox`/`DataProvider` patterns, existing Lua unit/UI/integration test harness

---

## File Structure

- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Domain\ItemCatalog.lua`
  - Replace flat-list query flow with indexed lookup, readiness validation, and session cache helpers.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
  - Replace eager search results panel with reusable virtualized result control contract.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
  - Stop rebuilding full search catalogs per keystroke. Use search session lifecycle.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainRequestsController.lua`
  - Same search-session contract as Minimums.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\GBankManager_ItemData.toc`
  - Load generated search bootstrap plus chunk files.
- Replace generation target: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\Data.lua`
  - Stop generating one monolithic flat file; move to generated bootstrap + chunks.
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\SearchBootstrap.lua`
  - Runtime-ready bundled search payload bootstrap.
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Export-IndexedItemSearchData.ps1`
  - Generate indexed chunked bundled search output.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Build-ItemDataAddon.ps1`
  - Call indexed exporter instead of flat `Data.lua` generator.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
  - Rebuild through indexed exporter and report readiness counts.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\helpers\wow_stubs.lua`
  - Add minimal `ScrollBox`/`DataProvider` stubs required by the reusable search list control.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\helpers\ui_fixture.lua`
  - Reset search-session/runtime globals cleanly for the new shared selector.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
  - Add indexed search engine tests and live-query fixture coverage.
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_index_spec.lua`
  - Focused generator/index/readiness tests.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
  - Validate 2-character gate, virtualized results, and action gating.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`
  - Same as Minimums for Requests.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\live_smoke_spec.lua`
  - Cover known bundled query fixtures.
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`

### Task 1: Lock the runtime contract with failing tests

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_index_spec.lua`

- [ ] **Step 1: Write the failing index and readiness tests**

```lua
local indexedPayload = {
    metadata = { itemCount = 4, tokenCount = 5, ready = true },
    itemsByID = {
        [241323] = { itemID = 241323, name = "Flask of the Magisters" },
        [241324] = { itemID = 241324, name = "Flask of the Blood Knights" },
        [241326] = { itemID = 241326, name = "Flask of the Shattered Sun" },
        [241327] = { itemID = 241327, name = "Flask of the Shattered Sun" },
    },
    tokenToItemIDs = {
        flask = { 241323, 241324, 241326, 241327 },
        of = { 241323, 241324, 241326, 241327 },
        shattered = { 241326, 241327 },
        sun = { 241326, 241327 },
    },
}

assert.truthy(itemCatalog.IsBundledSearchReady(indexedPayload), "bundled indexed payload should require a ready metadata marker")

local result = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask of the sha")
assert.equal("multiple", result.status, "indexed search should keep broad token matches grouped")
assert.equal(2, #result.matches, "shattered-sun query should return both quality variants")
```

- [ ] **Step 2: Run the focused failing tests**

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua`

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_index_spec.lua`

Expected: FAIL with missing `IsBundledSearchReady`, `ResolveIndexedQuery`, or missing readiness/index assertions.

- [ ] **Step 3: Add broad live-query fixture expectations to the tests**

```lua
local flask = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask")
assert.truthy(#flask.matches >= 4, "indexed search should return the full flask family, not a tiny subset")

local flaskOf = itemCatalog.ResolveIndexedQuery(indexedPayload, "flask of")
assert.truthy(#flaskOf.matches >= 4, "indexed search should support broad token combinations")
```

- [ ] **Step 4: Re-run the focused tests to confirm they still fail for the right reason**

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua`

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_index_spec.lua`

Expected: FAIL on missing runtime index support, not syntax or harness errors.

- [ ] **Step 5: Commit the red test baseline**

```bash
git add tests/spec/item_catalog_spec.lua tests/spec/item_catalog_index_spec.lua
git commit -m "test: add indexed item search contract coverage"
```

### Task 2: Build the indexed bundled-search engine

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\Domain\ItemCatalog.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_spec.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_index_spec.lua`

- [ ] **Step 1: Implement readiness validation and indexed lookup helpers**

```lua
function itemCatalog.IsBundledSearchReady(payload)
    local metadata = type(payload) == "table" and payload.metadata or nil
    return type(payload) == "table"
        and type(payload.itemsByID) == "table"
        and type(payload.tokenToItemIDs) == "table"
        and type(metadata) == "table"
        and metadata.ready == true
        and tonumber(metadata.itemCount or 0) > 0
        and tonumber(metadata.tokenCount or 0) > 0
end

local function hydrate_indexed_items(payload, itemIDs)
    local matches = {}
    for _, itemID in ipairs(itemIDs or {}) do
        local item = payload.itemsByID[itemID]
        if item then
            table.insert(matches, item)
        end
    end
    return matches
end
```

- [ ] **Step 2: Implement token-index query intersection and ranking**

```lua
function itemCatalog.ResolveIndexedQuery(payload, query)
    local normalizedQuery, queryTokens = tokenize_text(query)
    if normalizedQuery == "" then
        return { status = "missing", matches = {} }
    end

    local candidateIDs = intersect_token_lists(payload.tokenToItemIDs, queryTokens)
    local matches = rank_indexed_matches(payload, candidateIDs, normalizedQuery, queryTokens)

    if #matches == 1 then
        return { status = "resolved", item = matches[1], matches = matches }
    elseif #matches > 1 then
        return { status = "multiple", matches = matches }
    end

    return { status = "missing", matches = {} }
end
```

- [ ] **Step 3: Add a session cache builder and stop resolving from flat rebuilt lists**

```lua
function itemCatalog.CreateSearchSession(snapshot)
    local bundledPayload = itemCatalog.GetBundledSearchPayload()
    return {
        payload = bundledPayload,
        recentQueries = {},
        fallbackItems = collect_search_items(snapshot),
    }
end
```

- [ ] **Step 4: Run focused catalog tests**

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua`

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_index_spec.lua`

Expected: PASS

- [ ] **Step 5: Run the full unit lane**

Run: `.\tools\lua\lua.exe .\tests\run_unit.lua`

Expected: `PASS tests/run_unit.lua`

- [ ] **Step 6: Commit the engine slice**

```bash
git add GBankManager/Domain/ItemCatalog.lua tests/spec/item_catalog_spec.lua tests/spec/item_catalog_index_spec.lua
git commit -m "feat: add indexed bundled item search engine"
```

### Task 3: Generate chunked Ludwig-style bundled search data

**Files:**
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\SearchBootstrap.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager_ItemData\GBankManager_ItemData.toc`
- Create: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Export-IndexedItemSearchData.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Build-ItemDataAddon.ps1`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tools\catalog\Refresh-ItemCatalog.ps1`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\item_catalog_index_spec.lua`

- [ ] **Step 1: Write a failing generator test for chunked indexed output**

```lua
assert.truthy(searchBootstrapChunk ~= nil, "indexed search bootstrap should be loadable")
assert.truthy(type(payload.itemsByID) == "table", "indexed bootstrap should attach compact item records")
assert.truthy(type(payload.tokenToItemIDs) == "table", "indexed bootstrap should attach token index data")
assert.equal(true, payload.metadata.ready, "indexed bootstrap should mark readiness only after all chunks attach")
```

- [ ] **Step 2: Implement the exporter to emit bootstrap plus item/token chunks**

```powershell
$bootstrap = @"
local _, ns = ...
ns = _G.GBankManagerNamespace or ns or {}
ns.data = ns.data or {}

local payload = {
    metadata = {
        itemCount = $itemCount,
        tokenCount = $tokenCount,
        ready = false,
    },
    itemsByID = {},
    tokenToItemIDs = {},
}

ns.data.staticItemSearch = payload
"@
```

- [ ] **Step 3: Update the TOC to load bootstrap plus generated chunks**

```toc
## Interface: 120005
## Title: GBankManager Item Data
## Notes: Load on demand bundled item search data for GBankManager
## LoadOnDemand: 1
## LoadWith: GBankManager

Namespace.lua
SearchBootstrap.lua
Generated/Items_001.lua
Generated/Tokens_001.lua
Generated/Finalize.lua
```

- [ ] **Step 4: Rebuild the bundled addon from the current manifest**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\catalog\Build-ItemDataAddon.ps1`

Expected: generated bootstrap/chunk files written successfully

- [ ] **Step 5: Run the focused generator/index tests**

Run: `.\tools\lua\lua.exe .\tests\spec\item_catalog_index_spec.lua`

Expected: PASS

- [ ] **Step 6: Commit the data-generation slice**

```bash
git add GBankManager_ItemData tools/catalog tests/spec/item_catalog_index_spec.lua
git commit -m "feat: generate indexed bundled item search data"
```

### Task 4: Replace the eager match list with a reusable virtualized results control

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\helpers\wow_stubs.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`

- [ ] **Step 1: Write failing UI tests for the virtualized selector contract**

```lua
assert.truthy(type(mainFrame.minimumAddSearchSelector.resultsScrollBox) == "table", "minimums selector should expose a virtualized results scroll box")
assert.truthy(type(mainFrame.minimumAddSearchSelector.resultsDataProvider) == "table", "minimums selector should expose a data provider")
assert.equal(false, mainFrame.minimumAddButton:IsEnabled(), "add should stay disabled until a confirmed selection exists")
```

- [ ] **Step 2: Add minimal ScrollBox/DataProvider stubs for tests**

```lua
_G.CreateDataProvider = _G.CreateDataProvider or function(initial)
    return { data = initial or {}, Insert = function(self, value) table.insert(self.data, value) end }
end

_G.ScrollUtil = _G.ScrollUtil or {}
_G.ScrollUtil.InitScrollBoxListWithScrollBar = function(scrollBox, scrollBar, view)
    scrollBox._view = view
    scrollBox._scrollBar = scrollBar
end
```

- [ ] **Step 3: Replace the eager button-stack match panel with a reusable virtualized list contract**

```lua
selector.resultsDataProvider = CreateDataProvider()
selector.resultsScrollBox = CreateFrame("Frame", nil, selector.resultsPanel, "WowScrollBoxList")
selector.resultsScrollBar = selector.resultsScrollBar or mainFrameShell.CreateSlimScrollBar(selector.resultsPanel, {})

local view = CreateScrollBoxListLinearView()
view:SetElementInitializer("Button", function(row, elementData)
    row.itemText:SetText(elementData.label)
    if elementData.craftedQualityIcon then
        row.qualityIcon:SetAtlas(elementData.craftedQualityIcon, true)
        row.qualityIcon:Show()
    else
        row.qualityIcon:Hide()
    end
end)
ScrollUtil.InitScrollBoxListWithScrollBar(selector.resultsScrollBox, selector.resultsScrollBar, view)
```

- [ ] **Step 4: Run focused UI tests**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Run: `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`

Expected: PASS

- [ ] **Step 5: Run the full UI lane**

Run: `.\tools\lua\lua.exe .\tests\run_ui.lua`

Expected: `PASS tests/run_ui.lua`

- [ ] **Step 6: Commit the reusable control slice**

```bash
git add GBankManager/UI/MainFrameShell.lua tests/helpers/wow_stubs.lua tests/spec/ui_minimums_spec.lua tests/spec/ui_requests_spec.lua
git commit -m "feat: add virtualized shared item search results control"
```

### Task 5: Move Minimums and Requests to session-scoped indexed search

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainRequestsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`

- [ ] **Step 1: Write failing tests for 2-character activation and shared session use**

```lua
mainFrame.minimumAddItemNameInput:SetText("f")
assert.truthy(mainFrame.minimumAddSearchSelector.resultsDataProvider:GetSize() == 0, "single-character name search should not activate")

mainFrame.minimumAddItemNameInput:SetText("fl")
assert.truthy(mainFrame.minimumAddSearchSelector.resultsDataProvider:GetSize() > 0, "two-character search should activate")
```

- [ ] **Step 2: Create and reuse search sessions instead of rebuilding search catalogs per keystroke**

```lua
function mainFrame:GetMinimumSearchSession()
    self.minimumSearchSession = self.minimumSearchSession or itemCatalog.CreateSearchSession(self:GetMinimumSearchSnapshot())
    return self.minimumSearchSession
end

function mainFrame:ResolveMinimumAddByName()
    return self.minimumAddSearchSelector:ResolveQuery(self.minimumAddItemNameInput:GetText() or "", "name", self:GetMinimumSearchSession())
end
```

- [ ] **Step 3: Apply the same session pattern to Requests**

```lua
function mainFrame:GetRequestSearchSession()
    self.requestSearchSession = self.requestSearchSession or itemCatalog.CreateSearchSession(self:GetRequestSearchSnapshot())
    return self.requestSearchSession
end
```

- [ ] **Step 4: Run focused UI tests**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Run: `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`

Expected: PASS

- [ ] **Step 5: Run the full test suite**

Run: `.\tools\lua\lua.exe .\tests\run_all.lua`

Expected: `PASS tests/run_all.lua`

- [ ] **Step 6: Commit the controller integration slice**

```bash
git add GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MainRequestsController.lua tests/spec/ui_minimums_spec.lua tests/spec/ui_requests_spec.lua
git commit -m "feat: use indexed search sessions in minimums and requests"
```

### Task 6: Add live-query fixtures, docs, and deployment validation steps

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\live_smoke_spec.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\minimum-item-catalog-strategy.md`

- [ ] **Step 1: Add failing integration coverage for known search fixtures**

```lua
local result = itemCatalog.ResolveIndexedQuery(payload, "flask of the sha")
assert.truthy(#result.matches >= 2, "live smoke fixture should keep both Shattered Sun variants available")
```

- [ ] **Step 2: Document the new search contract and maintainer output format**

```md
- Name search starts at 2 characters.
- Search uses token-indexed bundled data, not flat full-table scans.
- Results are virtualized and may show broad multi-match families.
- Crafted quality icons appear when the bundled payload includes crafted metadata.
```

- [ ] **Step 3: Run integration and umbrella test lanes**

Run: `.\tools\lua\lua.exe .\tests\run_integration.lua`

Run: `.\tools\lua\lua.exe .\tests\run_all.lua`

Expected:

- `PASS tests/run_integration.lua`
- `PASS tests/run_all.lua`

- [ ] **Step 4: Deploy to Retail for the next manual validation pass**

Run:

```powershell
$addonRoot = 'C:\Gaming\World of Warcraft\_retail_\Interface\AddOns'
$sourceRoot = 'C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1'
@('GBankManager', 'GBankManager_ItemData') | ForEach-Object {
    $destination = Join-Path $addonRoot $_
    if (Test-Path $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Copy-Item -LiteralPath (Join-Path $sourceRoot $_) -Destination $destination -Recurse
}
```

Expected: both addon folders replaced successfully

- [ ] **Step 5: Commit docs and validation coverage**

```bash
git add tests/spec/live_smoke_spec.lua README.md docs/manual-test-checklist.md docs/minimum-item-catalog-strategy.md
git commit -m "docs: document indexed item search behavior"
```

## Self-Review

### Spec coverage

- Ludwig-style token indexing: covered in Tasks 2 and 3
- explicit readiness validation: covered in Tasks 1, 2, and 3
- shared runtime search engine: covered in Task 2
- session cache: covered in Task 5
- reusable virtualized results control: covered in Task 4
- 2-character activation: covered in Task 5
- shared Minimums and Requests behavior: covered in Tasks 4 and 5
- maintainer pipeline changes: covered in Task 3
- docs and validation: covered in Task 6

### Placeholder scan

- no `TBD` or `TODO` placeholders
- each code-changing step includes concrete code or exact command content
- each test step includes exact commands and expected outcomes

### Type consistency

- indexed payload names are consistent:
  - `itemsByID`
  - `tokenToItemIDs`
  - `metadata.ready`
- runtime engine names are consistent:
  - `IsBundledSearchReady`
  - `ResolveIndexedQuery`
  - `CreateSearchSession`
- UI/session names are consistent:
  - `GetMinimumSearchSession`
  - `GetRequestSearchSession`

