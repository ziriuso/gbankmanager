# GBankManager Item Hyperlink Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace visible crafted-quality tier columns and icon-only quality rendering with shared hyperlink-style item display across the addon while preserving numeric `Tier` values in CSV exports.

**Architecture:** Introduce one shared item-display helper that prefers trusted bundled or learned item hyperlinks when available and falls back to semantic item-name rendering when not. Visible UI surfaces collapse quality into the item display itself, but structured row metadata keeps numeric crafted-quality values for sorting, filtering, and CSV export, and the item-data pipeline is extended with optional hyperlink fields without abandoning the current semantic crafted-quality fallback model.

**Tech Stack:** WoW Lua addon runtime, bundled `GBankManager_ItemData` payload, maintainer catalog PowerShell and Node pipeline under `tools/catalog/`, focused Lua specs in `tests/spec/*.lua`, local Lua runner `.\tools\lua\lua.exe`, live Retail verification after deploy

---

## File Structure

- `GBankManager/GBankManager.toc`
  - load-order entry for any new shared item-display helper module
- `GBankManager/Domain/ItemCatalog.lua`
  - bundled item lookup
  - client-cache lookup
  - merged item metadata shape exposed to UI and exports
- `GBankManager/Domain/CraftedQuality.lua`
  - semantic crafted-quality fallback and numeric quality normalization
- `GBankManager/Domain/ItemDisplay.lua`
  - new shared helper for visible hyperlink-style item text, plain-text export name, and sort-safe quality metadata
- `GBankManager/Domain/Exports.lua`
  - export row materialization
  - preserved numeric `itemTierValue` output even after UI tier-column removal
- `GBankManager/Domain/Snapshots.lua`
  - snapshot row shape and item-link persistence when scan-time links are known
- `GBankManager/Features/GuildBankScanner.lua`
  - scan-time item-link capture where the client exposes a real link
- `GBankManager/UI/TableLayouts.lua`
  - shared table-column definitions for Inventory, Minimums, and Requests
- `GBankManager/UI/MainTableController.lua`
  - shared row rendering for icon-plus-text item display within the Item column
- `GBankManager/UI/InventoryView.lua`
  - Inventory row building, sorting, and CSV export contract
- `GBankManager/UI/MinimumsView.lua`
  - Minimums row building, sorting, and shared item display contract
- `GBankManager/UI/RequestsView.lua`
  - Requests table-row item display and row metadata
- `GBankManager/UI/MainFrameShell.lua`
  - shared search-result rows and selected-item preview surfaces
- `GBankManager/UI/MainRequestsController.lua`
  - request wizard preview and request details item display
- `GBankManager/UI/MainMinimumsController.lua`
  - minimum details and selected-item display
- `GBankManager/UI/MainExportsController.lua`
  - visible export table setup and drill-in behavior
- `GBankManager/UI/ExportsView.lua`
  - default CSV export contract for Exports
- `GBankManager/UI/ExportDialog.lua`
  - shared export preset contract
- `GBankManager/UI/BankLedgerView.lua`
  - item-log visible row contract and ledger CSV output
- `GBankManager_ItemData/SearchBootstrap.lua`
  - bundled payload ingestion for optional hyperlink fields
- `tools/catalog/runtime/extract-item-db2.js`
  - semantic extraction plus optional hyperlink-oriented fields where source data supports them
- `tools/catalog/Merge-ExtractedItemCatalog.ps1`
  - maintainer merge contract for optional hyperlink fields
- `tools/catalog/Import-LearnedItemCatalog.ps1`
  - learned catalog enrichment path for trusted item links
- `tools/catalog/Export-IndexedItemSearchData.ps1`
  - emitted bundled payload fields for hyperlink-aware item display
- `tests/spec/item_catalog_spec.lua`
  - bundled and client item metadata merge behavior
- `tests/spec/item_catalog_extract_spec.lua`
  - maintainer extraction and emitted item-data row fields
- `tests/spec/item_display_spec.lua`
  - new shared item-display helper contract
- `tests/spec/ui_table_spec.lua`
  - shared table-column and row-rendering contract
- `tests/spec/ui_inventory_spec.lua`
  - Inventory visible columns and CSV behavior
- `tests/spec/ui_minimums_spec.lua`
  - Minimums visible columns and detail surfaces
- `tests/spec/ui_requests_spec.lua`
  - Requests tables, request wizard, and request details
- `tests/spec/ui_search_results_control_spec.lua`
  - shared search selector rows and selected-item surface
- `tests/spec/ui_exports_spec.lua`
  - Exports visible table columns and drill-in behavior
- `tests/spec/exports_spec.lua`
  - export row materialization and CSV contract
- `tests/spec/ui_bank_ledger_spec.lua`
  - Bank Ledger item-log visible table contract
- `tests/spec/bank_ledger_spec.lua`
  - ledger CSV contract for numeric quality tier preservation
- `README.md`
  - feature description for hyperlink-style display and CSV behavior
- `docs/testing.md`
  - focused and full verification commands
- `docs/manual-test-checklist.md`
  - live `/reload` verification steps
- `docs/maintainer-catalog-workflow.md`
  - maintainer data-flow expectations for optional hyperlink fields
- `docs/superpowers/handoffs/latest-handoff.md`
  - next-session resume instructions and approved product contract

---

### Task 1: Establish the shared item-display contract before moving any view

**Files:**
- Create: `GBankManager/Domain/ItemDisplay.lua`
- Modify: `GBankManager/GBankManager.toc`
- Create: `tests/spec/item_display_spec.lua`
- Modify: `tests/spec/item_catalog_spec.lua`
- Test: `tests/spec/item_display_spec.lua`
- Test: `tests/spec/item_catalog_spec.lua`

- [ ] **Step 1: Write the failing unit tests for hyperlink-first display with semantic fallback**

```lua
local itemDisplay = _G.dofile("GBankManager/Domain/ItemDisplay.lua")

local hyperlinkItem = {
    itemID = 241322,
    name = "Flask of the Magisters",
    itemLink = "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    craftedQuality = 2,
    craftedQualityMax = 2,
}

local display = itemDisplay.BuildDisplayPayload(hyperlinkItem)
assert.equal(hyperlinkItem.itemLink, display.visibleText, "display payload should prefer a trusted stored hyperlink when present")
assert.equal("Flask of the Magisters", display.plainTextName, "display payload should preserve a plain-text export-safe item name")
assert.equal(2, display.tierValue, "display payload should preserve numeric crafted quality for sorting and CSV")

local fallbackDisplay = itemDisplay.BuildDisplayPayload({
    itemID = 244559,
    name = "Thalassian Phoenix Oil",
    craftedQuality = 2,
    craftedQualityMax = 2,
})
assert.equal("Thalassian Phoenix Oil", fallbackDisplay.plainTextName, "fallback display should still expose a stable plain-text item name")
assert.equal(2, fallbackDisplay.tierValue, "fallback display should preserve numeric quality even without a link")
assert.truthy(tostring(fallbackDisplay.visibleText or "") ~= "", "fallback display should still produce visible item text when no trusted link exists")
```

- [ ] **Step 2: Add the failing ItemCatalog merge expectations for optional link fields**

```lua
local bundled = itemCatalog.HydrateItem({
    itemID = 241322,
    name = "Flask of the Magisters",
    itemLink = "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    craftedQuality = 2,
    craftedQualityMax = 2,
})

assert.equal(
    "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    bundled.itemLink,
    "catalog hydration should preserve trusted bundled hyperlink fields"
)
```

- [ ] **Step 3: Run the focused tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_display_spec.lua
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected:

- `FAIL` because `ItemDisplay.lua` does not exist yet
- `FAIL` because current catalog hydration ignores `itemLink`

- [ ] **Step 4: Implement the minimal shared display helper and wire it into TOC load order**

```lua
local _, ns = ...

local itemDisplay = {}

function itemDisplay.BuildDisplayPayload(item)
    item = type(item) == "table" and item or {}

    local visibleText = tostring(item.itemLink or item.itemString or "")
    local plainTextName = tostring(item.name or item.itemName or "Unknown")
    local tierValue = tonumber(item.craftedQuality or item.qualityTier or 0) or 0

    if visibleText == "" then
        visibleText = plainTextName
    end

    return {
        visibleText = visibleText,
        plainTextName = plainTextName,
        tierValue = tierValue,
        itemID = tonumber(item.itemID),
    }
end

ns.modules.itemDisplay = itemDisplay

return itemDisplay
```

- [ ] **Step 5: Re-run the focused tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_display_spec.lua
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected:

- `PASS tests/spec/item_display_spec.lua`
- `PASS tests/spec/item_catalog_spec.lua`

- [ ] **Step 6: Commit**

```bash
git add GBankManager/GBankManager.toc GBankManager/Domain/ItemDisplay.lua tests/spec/item_display_spec.lua tests/spec/item_catalog_spec.lua
git commit -m "feat: add shared item display payload helper"
```

---

### Task 2: Extend the maintainer and bundled item-data schema with optional hyperlink fields

**Files:**
- Modify: `tools/catalog/runtime/extract-item-db2.js`
- Modify: `tools/catalog/Merge-ExtractedItemCatalog.ps1`
- Modify: `tools/catalog/Import-LearnedItemCatalog.ps1`
- Modify: `tools/catalog/Export-IndexedItemSearchData.ps1`
- Modify: `GBankManager_ItemData/SearchBootstrap.lua`
- Modify: `GBankManager/Domain/ItemCatalog.lua`
- Modify: `tests/spec/item_catalog_extract_spec.lua`
- Modify: `tests/spec/item_catalog_spec.lua`
- Test: `tests/spec/item_catalog_extract_spec.lua`
- Test: `tests/spec/item_catalog_spec.lua`

- [ ] **Step 1: Write the failing extract/export expectations for optional hyperlink fields**

```lua
assert.equal(
    "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    read_item_field(normalizedOutputPath, 241322, "itemLink"),
    "exported item payload should preserve optional trusted hyperlink fields"
)

assert.equal(
    "item:241322::::::::80:::::",
    read_item_field(normalizedOutputPath, 241322, "itemString"),
    "exported item payload should preserve optional item-string fields when provided"
)
```

- [ ] **Step 2: Add the failing bootstrap expectation for bundled hyperlink ingestion**

```lua
bootstrap.AppendItemChunk({
    {
        itemID = 241322,
        name = "Flask of the Magisters",
        itemLink = "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
        itemString = "item:241322::::::::80:::::",
        craftedQuality = 2,
        craftedQualityMax = 2,
    },
})

assert.equal(
    "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    payload.itemsByID[241322].itemLink,
    "search bootstrap should keep optional item hyperlinks in the bundled payload"
)
```

- [ ] **Step 3: Run the focused tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_catalog_extract_spec.lua
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected:

- `FAIL` because the extract/export path does not emit `itemLink` or `itemString`

- [ ] **Step 4: Implement the minimal schema extension without changing the current itemID-keyed lookup model**

```powershell
$recordFields.Add("itemID = $itemID")
$recordFields.Add("name = $(ConvertTo-LuaString ([string]$nameValue))")
if ($null -ne $itemLinkValue) {
    $recordFields.Add("itemLink = $(ConvertTo-LuaString ([string]$itemLinkValue))")
}
if ($null -ne $itemStringValue) {
    $recordFields.Add("itemString = $(ConvertTo-LuaString ([string]$itemStringValue))")
}
```

```lua
qualityByItemID[itemID] = {
    itemID = itemID,
    itemLink = item.itemLink,
    itemString = item.itemString,
    craftedQuality = item.craftedQuality,
    craftedQualityMax = item.craftedQualityMax,
}
```

- [ ] **Step 5: Re-run the focused tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\item_catalog_extract_spec.lua
.\tools\lua\lua.exe .\tests\spec\item_catalog_spec.lua
```

Expected:

- `PASS tests/spec/item_catalog_extract_spec.lua`
- `PASS tests/spec/item_catalog_spec.lua`

- [ ] **Step 6: Commit**

```bash
git add tools/catalog/runtime/extract-item-db2.js tools/catalog/Merge-ExtractedItemCatalog.ps1 tools/catalog/Import-LearnedItemCatalog.ps1 tools/catalog/Export-IndexedItemSearchData.ps1 GBankManager_ItemData/SearchBootstrap.lua GBankManager/Domain/ItemCatalog.lua tests/spec/item_catalog_extract_spec.lua tests/spec/item_catalog_spec.lua
git commit -m "feat: carry optional item hyperlinks through catalog data"
```

---

### Task 3: Remove visible Tier columns from Inventory and Minimums while preserving numeric CSV tier output

**Files:**
- Modify: `GBankManager/UI/TableLayouts.lua`
- Modify: `GBankManager/UI/MainTableController.lua`
- Modify: `GBankManager/UI/InventoryView.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `tests/spec/ui_table_spec.lua`
- Modify: `tests/spec/ui_inventory_spec.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Modify: `tests/spec/inventory_quality_spec.lua`
- Test: `tests/spec/ui_table_spec.lua`
- Test: `tests/spec/ui_inventory_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/inventory_quality_spec.lua`

- [ ] **Step 1: Write the failing visible-column expectations for Inventory and Minimums**

```lua
mainFrame:SelectView("INVENTORY")
assert.equal("Item", mainFrame.tableHeaderLabels[2]:GetText(), "inventory should collapse the old tier slot into the item column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[3]:GetText(), "inventory should shift the remaining columns left after removing visible tier")

mainFrame:SelectView("MINIMUMS")
assert.equal("Item", mainFrame.tableHeaderLabels[2]:GetText(), "minimums should collapse the old tier slot into the item column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[3]:GetText(), "minimums should shift the remaining columns left after removing visible tier")
```

- [ ] **Step 2: Write the failing CSV expectations that keep numeric tier values**

```lua
local csvText = inventoryView.BuildCsvText({
    {
        itemID = "241322",
        itemName = "Flask of the Magisters",
        tierValue = 2,
        bankTab = "Raid Buffet",
        current = "0",
        restock = "Yes",
        minimum = "10",
    },
})

assert.equal(
    "Item ID,Tier,Item,Bank Tab,Current,Restock,Minimum\n241322,2,Flask of the Magisters,Raid Buffet,0,Yes,10",
    csvText,
    "inventory csv should keep the numeric tier column even after visible tier-column removal"
)
```

- [ ] **Step 3: Run the focused UI tests to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_table_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_inventory_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\inventory_quality_spec.lua
```

Expected:

- `FAIL` because the visible table layouts still expose `Tier`

- [ ] **Step 4: Implement the shared table-layout and row-shape migration**

```lua
local INVENTORY_MINIMUM_COLUMNS = {
    { key = "itemID", label = "Item ID", width = 78, minWidth = 72, maxWidth = 96, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "itemDisplayText", label = "Item", width = 336, minWidth = 260, maxWidth = 420, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "bankTab", label = "Bank Tab", width = 134, minWidth = 118, maxWidth = 190, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "current", label = "Current", width = 68, minWidth = 64, maxWidth = 88, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "restock", label = "Restock", width = 76, minWidth = 72, maxWidth = 98, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "quantity", label = "Minimum", width = 80, minWidth = 72, maxWidth = 96, justifyH = "LEFT", filterMode = "none", sortable = true },
}
```

```lua
local display = itemDisplay.BuildDisplayPayload(item)

table.insert(rows, {
    itemID = tostring(item.itemID or ""),
    itemDisplayText = display.visibleText,
    itemName = display.plainTextName,
    tierValue = display.tierValue,
    cellIcons = nil,
    bankTab = bankTab,
    current = tostring(current),
    restock = restock,
    quantity = minimumText,
})
```

- [ ] **Step 5: Re-run the focused UI tests to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_table_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_inventory_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
.\tools\lua\lua.exe .\tests\spec\inventory_quality_spec.lua
```

Expected:

- `PASS` for all four focused specs

- [ ] **Step 6: Commit**

```bash
git add GBankManager/UI/TableLayouts.lua GBankManager/UI/MainTableController.lua GBankManager/UI/InventoryView.lua GBankManager/UI/MinimumsView.lua tests/spec/ui_table_spec.lua tests/spec/ui_inventory_spec.lua tests/spec/ui_minimums_spec.lua tests/spec/inventory_quality_spec.lua
git commit -m "refactor: collapse inventory and minimums tier columns into item display"
```

---

### Task 4: Migrate Requests, shared search, and detail surfaces to the shared item-display helper

**Files:**
- Modify: `GBankManager/UI/RequestsView.lua`
- Modify: `GBankManager/UI/MainFrameShell.lua`
- Modify: `GBankManager/UI/MainRequestsController.lua`
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `tests/spec/ui_search_results_control_spec.lua`
- Test: `tests/spec/ui_requests_spec.lua`
- Test: `tests/spec/ui_search_results_control_spec.lua`

- [ ] **Step 1: Write the failing shared-search and request-surface expectations**

```lua
assert.equal(
    "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    mainFrame.requestCreateResultsRows[1].itemText:GetText(),
    "request search rows should render the shared hyperlink-style item display"
)

assert.equal(
    "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    mainFrame.requestDetailsItemNameText:GetText(),
    "request details should render the shared hyperlink-style item display"
)

assert.truthy(
    not (mainFrame.requestDetailsQualityIcon and mainFrame.requestDetailsQualityIcon:IsShown()),
    "request details should stop depending on a separate quality icon once the shared item-display contract is in place"
)
```

- [ ] **Step 2: Run the focused request/search specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_search_results_control_spec.lua
```

Expected:

- `FAIL` because request surfaces still use separate quality icon/text regions

- [ ] **Step 3: Implement the shared item-display rendering path for requests and selectors**

```lua
local display = itemDisplay.BuildDisplayPayload(selectedItem)
self.requestDetailsItemNameText:SetText(display.visibleText)
self.requestDetailsQualityIcon:Hide()
self.requestDetailsQualityText:Hide()
```

```lua
resultRow.itemText:SetText(display.visibleText)
resultRow.qualityIcon:Hide()
resultRow.tierText:Hide()
```

- [ ] **Step 4: Re-run the focused request/search specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_search_results_control_spec.lua
```

Expected:

- `PASS tests/spec/ui_requests_spec.lua`
- `PASS tests/spec/ui_search_results_control_spec.lua`

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/RequestsView.lua GBankManager/UI/MainFrameShell.lua GBankManager/UI/MainRequestsController.lua GBankManager/UI/MainMinimumsController.lua tests/spec/ui_requests_spec.lua tests/spec/ui_search_results_control_spec.lua
git commit -m "refactor: move requests and search surfaces to shared item display"
```

---

### Task 5: Migrate Exports and Bank Ledger visible tables while preserving numeric tier in CSV output

**Files:**
- Modify: `GBankManager/Domain/Exports.lua`
- Modify: `GBankManager/UI/MainExportsController.lua`
- Modify: `GBankManager/UI/ExportsView.lua`
- Modify: `GBankManager/UI/ExportDialog.lua`
- Modify: `GBankManager/UI/BankLedgerView.lua`
- Modify: `tests/spec/exports_spec.lua`
- Modify: `tests/spec/ui_exports_spec.lua`
- Modify: `tests/spec/ui_bank_ledger_spec.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`
- Test: `tests/spec/exports_spec.lua`
- Test: `tests/spec/ui_exports_spec.lua`
- Test: `tests/spec/ui_bank_ledger_spec.lua`
- Test: `tests/spec/bank_ledger_spec.lua`

- [ ] **Step 1: Write the failing Exports and Bank Ledger visible-column expectations**

```lua
mainFrame:SelectView("EXPORTS")
assert.equal("Item Name", mainFrame.tableHeaderLabels[2]:GetText(), "exports should remove the visible tier column and show item display in the first content slot")

mainFrame:SelectView("BANK_LEDGER")
mainFrame:SetBankLedgerMode("ITEM")
assert.equal("Item", mainFrame.tableHeaderLabels[4]:GetText(), "bank ledger item mode should remove the visible tier column and shift item left")
```

- [ ] **Step 2: Write the failing CSV expectations that preserve numeric tier output**

```lua
local csvText = exportsView.BuildCsvText({
    {
        itemID = 241322,
        itemName = "Flask of the Magisters",
        itemTierValue = 2,
        bankTab = "Raid Buffet",
        minQty = 10,
        qtyInStock = 0,
        qtyToBuy = 10,
        excessQtyValue = 0,
    },
})

assert.equal(
    "Item ID,Tier,Item Name,Bank Tab,Min Qty,Qty In Stock,Qty To Buy,Excess Qty\n241322,2,Flask of the Magisters,Raid Buffet,10,0,10,0",
    csvText,
    "exports csv should preserve numeric tier values after visible tier-column removal"
)
```

- [ ] **Step 3: Run the focused Exports and Bank Ledger specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\exports_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `FAIL` because Exports and Bank Ledger still render visible tier columns

- [ ] **Step 4: Implement the visible-table migration while leaving CSV mappings numeric**

```lua
table.insert(rows, {
    itemID = row.itemID,
    itemDisplayText = display.visibleText,
    itemName = display.plainTextName,
    itemTierValue = display.tierValue,
    bankTab = bankTab,
    minQty = minimumQuantity,
    qtyInStock = quantityInStock,
    qtyToBuy = quantityToBuy,
})
```

```lua
fields = { "Item ID", "Tier", "Item Name", "Bank Tab", "Min Qty", "Qty In Stock", "Qty To Buy", "Excess Qty" },
labels = {
    ["Item ID"] = "itemID",
    ["Tier"] = "itemTierValue",
    ["Item Name"] = "itemName",
}
```

- [ ] **Step 5: Re-run the focused Exports and Bank Ledger specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\exports_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `PASS` for all four focused specs

- [ ] **Step 6: Commit**

```bash
git add GBankManager/Domain/Exports.lua GBankManager/UI/MainExportsController.lua GBankManager/UI/ExportsView.lua GBankManager/UI/ExportDialog.lua GBankManager/UI/BankLedgerView.lua tests/spec/exports_spec.lua tests/spec/ui_exports_spec.lua tests/spec/ui_bank_ledger_spec.lua tests/spec/bank_ledger_spec.lua
git commit -m "refactor: move exports and ledger item rows to hyperlink display"
```

---

### Task 6: Refresh docs, regenerate bundled item data, and complete verification

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/maintainer-catalog-workflow.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Modify: `GBankManager_ItemData/Generated/Items_*.lua`
- Modify: `GBankManager_ItemData/Generated/Finalize.lua`
- Test: `.\tools\lua\lua.exe .\tests\run_ui.lua`
- Test: `.\tools\lua\lua.exe .\tests\run_all.lua`

- [ ] **Step 1: Update docs to encode the new product contract**

```markdown
- Visible item tables now collapse crafted quality into hyperlink-style item display instead of a dedicated visible Tier column.
- CSV exports intentionally keep a numeric `Tier` column for spreadsheet workflows and downstream tooling.
- If a trusted item hyperlink is unavailable, the addon falls back to plain item-name rendering while keeping numeric quality metadata internally.
```

- [ ] **Step 2: Regenerate bundled item data after pipeline changes**

Run:

```powershell
.\tools\catalog\Refresh-ItemCatalog.ps1
```

Expected:

- generated `GBankManager_ItemData/Generated/Items_*.lua` and `Finalize.lua` include any new optional hyperlink fields without dropping existing semantic crafted-quality fields

- [ ] **Step 3: Run the focused UI lane**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_ui.lua
```

Expected:

- `PASS .\tests\run_ui.lua`

- [ ] **Step 4: Run the full suite**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected:

- either `PASS .\tests\run_all.lua`
- or the same known pre-existing harness blocker in `tests/spec/item_catalog_target_spec.lua` with `fixture writer should open the target file`

- [ ] **Step 5: Deploy to Retail and verify live after `/reload`**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail
```

Verify after `/reload`:

- `Inventory`, `Minimums`, `Requests`, `Exports`, and `Bank Ledger -> Item Log` no longer show a visible `Tier` column.
- The item-name surface in those views now renders hyperlink-style item display when a trusted link is known.
- Request add-item search, selected-item preview, request wizard preview, request details, and minimum details all use the same shared item-display contract.
- `240154`, `241322`, `241324`, `243734`, and `244559` no longer depend on separate visible crafted-quality icons for readability.
- `Inventory` CSV still exports `Item ID,Tier,Item,Bank Tab,Current,Restock,Minimum` with numeric `Tier` values.
- `Exports` CSV still exports `Item ID,Tier,Item Name,Bank Tab,Min Qty,Qty In Stock,Qty To Buy,Excess Qty` with numeric `Tier` values.
- `Bank Ledger` item CSV still preserves numeric quality tier data for item rows.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/testing.md docs/manual-test-checklist.md docs/maintainer-catalog-workflow.md docs/superpowers/handoffs/latest-handoff.md GBankManager_ItemData/Generated
git commit -m "docs: record hyperlink item display migration contract"
```

---

## Notes For The Implementer

- Do not reopen the old crafted-quality icon resolver as the primary UX solution. The approved product pivot is to remove visible tier-column dependence and move quality into shared item display.
- Keep the current itemID-keyed bundled payload for the first implementation pass. Optional `itemLink` and `itemString` fields are enough for phase one; a richer `variantKey` index is a future-safe extension, not a day-one blocker.
- Preserve `tierValue` or `itemTierValue` on structured rows even when the visible table no longer shows that field. Sorting, dedupe, and CSV all still need it.
- Keep Auctionator and TSM export formats unchanged unless a failing test proves otherwise.
- Treat `244559` as an explicit live spot-check item because it represents the same-itemID multi-quality concern that motivated the research.

## Self-Review

- Spec coverage: the plan covers the shared display helper, maintainer data shape, bundled payload ingestion, Inventory/Minimums/Requests/search/detail surfaces, Exports, Bank Ledger, CSV preservation, docs, and live verification.
- Placeholder scan: no `TODO` or `TBD` markers remain.
- Type consistency: the plan consistently uses `itemLink`, `itemString`, `visibleText`, `plainTextName`, `tierValue`, and `itemTierValue`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-28-gbankmanager-item-hyperlink-migration-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
