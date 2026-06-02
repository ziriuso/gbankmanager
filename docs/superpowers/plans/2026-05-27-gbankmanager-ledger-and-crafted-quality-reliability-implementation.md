# GBankManager Crafted-Quality and Ledger Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore correct non-inventory crafted-quality icons, make ledger scans and passive ledger refresh reliable across reloads, and replace the Exports excess-quantity text affordance with a right-aligned drill-in icon.

**Architecture:** Keep the current GBankManager UI and data surfaces, but correct the narrow shared resolver and ledger delta logic causing the live failures. Bundled crafted-quality display atlases become authoritative again for non-inventory item-aware surfaces, and ledger rescans move to a stable fingerprint plus `GUILDBANKLOG_UPDATE` debounced read model modeled after the working `GuildBankLedger` addon.

**Tech Stack:** WoW Lua addon runtime, shared GBankManager modules in `GBankManager/`, focused Lua specs in `tests/spec/*.lua`, local test runner `.\tools\lua\lua.exe`, live WoW verification after deploy

---

## File Structure

- `GBankManager/Domain/CraftedQuality.lua`
  - shared crafted-quality atlas resolution
  - item-aware display atlas selection
  - crafted-quality debug reporting
- `GBankManager/Domain/BankLedger.lua`
  - normalized ledger row shape
  - stable fingerprint generation and persisted dedupe index
  - source-window delta helpers
- `GBankManager/Features/GuildBankScanner.lua`
  - manual ledger scan entrypoint
  - passive bank-open refresh flow
  - `GUILDBANKLOG_UPDATE` debounce and read scheduling
- `GBankManager/Features/GuildBankScannerEvents.lua`
  - event routing for `GUILDBANKLOG_UPDATE` and guild-bank open/close events
- `GBankManager/Domain/Exports.lua`
  - export row metadata for the excess drill-in icon
- `GBankManager/UI/MainFrame.lua`
  - shared table configuration and exports row interaction
- `GBankManager/UI/MainExportsController.lua`
  - stocked-elsewhere modal and exports presentation wiring
- `tests/spec/crafted_quality_spec.lua`
  - unit coverage for atlas resolution and debug output
- `tests/spec/ui_crafted_quality_live_regression_spec.lua`
  - UI regression coverage for Minimums, Requests, Request Details, and Exports
- `tests/spec/bank_ledger_spec.lua`
  - bank-ledger merge and persisted-state behavior
- `tests/spec/bank_ledger_scanner_spec.lua`
  - scanner query path, debounce path, and passive refresh behavior
- `tests/spec/ui_exports_spec.lua`
  - Exports table affordance and modal behavior
- `README.md`
  - current feature behavior notes
- `docs/testing.md`
  - verification expectations
- `docs/manual-test-checklist.md`
  - live validation steps
- `docs/superpowers/handoffs/latest-handoff.md`
  - next-session context and remaining risks

---

### Task 1: Restore bundled crafted-quality display atlases for non-inventory item-aware rendering

**Files:**
- Modify: `tests/spec/crafted_quality_spec.lua`
- Modify: `tests/spec/ui_crafted_quality_live_regression_spec.lua`
- Modify: `GBankManager/Domain/CraftedQuality.lua`
- Test: `tests/spec/crafted_quality_spec.lua`
- Test: `tests/spec/ui_crafted_quality_live_regression_spec.lua`

- [ ] **Step 1: Write the failing crafted-quality resolver expectations**

```lua
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    craftedQuality.GetDisplayAtlasForItem(241320, "Professions-ChatIcon-Quality-Tier1", 1, "reagent", 0),
    "item-aware non-inventory display should keep the bundled two-rank display atlas instead of rewriting it"
)

local debugInfo = craftedQuality.DebugItemResolution(241322, "Professions-ChatIcon-Quality-Tier1", 1, 0, "reagent")
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    debugInfo.finalDisplayAtlas,
    "crafted-quality diagnostics should report the bundled display atlas as the final non-inventory display choice"
)
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    debugInfo.finalAtlas,
    "crafted-quality diagnostics should expose the same final atlas used by non-inventory display consumers"
)
```

- [ ] **Step 2: Write the failing UI regression expectations for the known live items**

```lua
mainFrame:SelectView("MINIMUMS")
assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    (mainFrame.tableRowsData[1] or {}).tier,
    "minimums rows should render the bundled two-rank reagent display atlas"
)

mainFrame:OpenRequestDetailsModal("request-live-tier")
assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    mainFrame.requestDetailsQualityText:GetText(),
    "request details should render the bundled two-rank reagent display atlas"
)

mainFrame:SelectView("EXPORTS")
assert.equal(
    "|A:Interface-Crafting-ReagentQuality-2-Med:22:22|a",
    (mainFrame.tableRowsData[1] or {}).itemTier,
    "exports rows should render the bundled two-rank reagent display atlas"
)
```

- [ ] **Step 3: Run the focused crafted-quality specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\crafted_quality_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_crafted_quality_live_regression_spec.lua
```

Expected:

- `FAIL` because current two-rank non-inventory display resolution returns `Professions-ChatIcon-Quality-12-Tier2`

- [ ] **Step 4: Implement the minimal crafted-quality resolver fix**

```lua
local function normalize_preferred_item_atlas(atlasName, quality, maxQuality, style)
    local parsedTier = craftedQuality.ParseTier(atlasName, quality or 0)
    local resolvedMaxQuality = normalized_max_quality(maxQuality, parsedTier)
    local text = unwrap_markup_atlas(atlasName)

    if resolvedMaxQuality == 2 and parsedTier >= 1 and parsedTier <= 2 then
        if text ~= "" then
            return text
        end
        return display_atlas_for_tier(parsedTier, style, resolvedMaxQuality) or ""
    end

    if text ~= "" then
        return text
    end

    return display_atlas_for_tier(parsedTier, style, resolvedMaxQuality) or ""
end

function craftedQuality.GetDisplayAtlasForItem(itemID, icon, fallbackQuality, style, maxQuality)
    local resolvedIcon, resolvedQuality, resolvedMaxQuality, resolvedDisplayAtlas = resolve_item_quality_fields(itemID, icon, fallbackQuality, maxQuality)
    if resolvedDisplayAtlas ~= "" then
        return normalize_preferred_item_atlas(resolvedDisplayAtlas, resolvedQuality, resolvedMaxQuality, style)
    end
    return craftedQuality.GetDisplayAtlas(resolvedIcon, resolvedQuality, style, resolvedMaxQuality)
end
```

- [ ] **Step 5: Run the focused crafted-quality specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\crafted_quality_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_crafted_quality_live_regression_spec.lua
```

Expected:

- `PASS tests/spec/crafted_quality_spec.lua`
- `PASS tests/spec/ui_crafted_quality_live_regression_spec.lua`

- [ ] **Step 6: Commit**

```bash
git add tests/spec/crafted_quality_spec.lua tests/spec/ui_crafted_quality_live_regression_spec.lua GBankManager/Domain/CraftedQuality.lua
git commit -m "fix: restore bundled non-inventory crafted quality atlases"
```

---

### Task 2: Replace fragile ledger persisted-state overlap behavior with stable transaction fingerprints

**Files:**
- Modify: `tests/spec/bank_ledger_spec.lua`
- Modify: `GBankManager/Domain/BankLedger.lua`
- Test: `tests/spec/bank_ledger_spec.lua`

- [ ] **Step 1: Write the failing reload-like ledger merge regression**

```lua
local reloadStateDb = fresh_db()
reloadStateDb.bankLedger.itemSourceSnapshots["item:1"] = {
    "stale|snapshot|row|one",
    "stale|snapshot|row|two",
}

local firstImport = bankLedger.MergeItemTransactions(reloadStateDb, {
    scanStartedAt = 1716573600,
    sourceTabIndex = 1,
    sourceTabName = "Freebiez",
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent-Stormrage",
            itemID = 245795,
            itemName = "Contract: The Hara'ti",
            quantity = 2,
            year = 2026,
            month = 5,
            day = 27,
            hour = 12,
        },
    },
})

assert.equal(1, firstImport, "stale persisted source snapshots should not block a real new item-log row from importing")
assert.equal(1, #reloadStateDb.bankLedger.itemLogs, "reload-like stale source snapshots should still allow append-only ledger import")
```

- [ ] **Step 2: Add the failing money-log variant and stable dedupe expectation**

```lua
local reloadMoneyDb = fresh_db()
reloadMoneyDb.bankLedger.moneySourceSnapshots.money = {
    "stale|money|snapshot",
}

local importedMoneyCount = bankLedger.MergeMoneyTransactions(reloadMoneyDb, {
    scanStartedAt = 1716573600,
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent-Stormrage",
            amount = 50010000,
            year = 2026,
            month = 5,
            day = 27,
            hour = 12,
        },
    },
})

local duplicateMoneyCount = bankLedger.MergeMoneyTransactions(reloadMoneyDb, {
    scanStartedAt = 1716573900,
    transactions = {
        {
            type = "deposit",
            who = "Zirleficent-Stormrage",
            amount = 50010000,
            year = 2026,
            month = 5,
            day = 27,
            hour = 12,
        },
    },
})

assert.equal(1, importedMoneyCount, "stale persisted money snapshots should not block a real new money-log row")
assert.equal(0, duplicateMoneyCount, "stable money fingerprints should still suppress duplicates on repeat scans")
```

- [ ] **Step 3: Run the ledger merge spec to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `FAIL` because current persisted source snapshots can suppress real new rows

- [ ] **Step 4: Implement stable ledger fingerprints and persisted dedupe**

```lua
local function stable_item_fingerprint(row)
    return make_fingerprint({
        tostring(row.timestamp or 0),
        tostring(row.who or ""),
        tostring(row.action or ""),
        tostring(row.itemID or 0),
        tostring(row.quantity or 0),
        tostring(row.tabName or ""),
        tostring(row.fromTabName or "-"),
    })
end

local function stable_money_fingerprint(row)
    return make_fingerprint({
        tostring(row.timestamp or 0),
        tostring(row.who or ""),
        tostring(row.action or ""),
        tostring(row.amountCopper or 0),
    })
end

local function append_delta_rows(ledger, entries, fingerprintIndex, sourceSnapshots, sourceKey, normalizedRows, mergedCount, entryPrefix, fingerprintFactory)
    local delta = describe_source_delta(sourceSnapshots, sourceKey, normalizedRows)
    if delta.emptyAfterKnown or delta.suspiciousNoOverlap then
        sourceSnapshots[sourceKey] = delta.currentFingerprints
        return mergedCount
    end

    local startIndex = delta.appendMode == "back" and math.max(1, (#normalizedRows - delta.newRowCount) + 1) or 1
    local endIndex = delta.appendMode == "back" and #normalizedRows or delta.newRowCount

    for index = startIndex, endIndex do
        local row = normalizedRows[index]
        local stableFingerprint = fingerprintFactory(row)
        if fingerprintIndex[stableFingerprint] ~= true then
            row.entryId = next_entry_id(ledger, entryPrefix)
            row.fingerprint = stableFingerprint
            row.fingerprintBase = nil
            row.sourceIndex = nil
            fingerprintIndex[stableFingerprint] = true
            entries[#entries + 1] = row
            mergedCount = mergedCount + 1
        end
    end

    sourceSnapshots[sourceKey] = delta.currentFingerprints
    return mergedCount
end
```

- [ ] **Step 5: Wire the stable fingerprint helpers into item and money merge**

```lua
local mergedCount = append_delta_rows(
    ledger,
    ledger.itemLogs,
    ledger.itemFingerprints,
    ledger.itemSourceSnapshots,
    sourceKey,
    normalizedRows,
    0,
    "item",
    stable_item_fingerprint
)

local mergedCount = append_delta_rows(
    ledger,
    ledger.moneyLogs,
    ledger.moneyFingerprints,
    ledger.moneySourceSnapshots,
    sourceKey,
    normalizedRows,
    0,
    "money",
    stable_money_fingerprint
)
```

- [ ] **Step 6: Run the ledger merge spec to verify it passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `PASS tests/spec/bank_ledger_spec.lua`

- [ ] **Step 7: Commit**

```bash
git add tests/spec/bank_ledger_spec.lua GBankManager/Domain/BankLedger.lua
git commit -m "fix: harden ledger dedupe across reloads"
```

---

### Task 3: Rework scanner ledger reads and passive refresh around the shared debounced rescan path

**Files:**
- Modify: `tests/spec/bank_ledger_scanner_spec.lua`
- Modify: `GBankManager/Features/GuildBankScanner.lua`
- Modify: `GBankManager/Features/GuildBankScannerEvents.lua`
- Modify: `GBankManager/Domain/BankLedger.lua`
- Test: `tests/spec/bank_ledger_scanner_spec.lua`
- Test: `tests/spec/bank_ledger_spec.lua`

- [ ] **Step 1: Add the failing scanner expectation for shared manual and passive rescan behavior**

```lua
local passiveQueryCount = 0
_G.QueryGuildBankLog = function(queryId)
    if queryId == 1 or queryId == 9 then
        passiveQueryCount = passiveQueryCount + 1
    end
end

scanner.guildBankOpen = true
scanner.scanInProgress = false
scanner.ledgerScanInProgress = false
scanner.passiveLedgerRefreshActive = false
scanner.passiveLedgerRefreshToken = 0

scanner.BeginLedgerScan({ force = true, silent = true, passive = true })
run_all_pending()

assert.truthy(passiveQueryCount >= 2, "passive ledger refresh should reuse the same all-log query path as manual ledger scans")
```

- [ ] **Step 2: Add the failing scanner regression for new rows after simulated reload state**

```lua
_G.GBankManagerDB.bankLedger.itemSourceSnapshots["item:1"] = {
    "stale|item|window",
}
_G.GBankManagerDB.bankLedger.moneySourceSnapshots.money = {
    "stale|money|window",
}

assert.truthy(scanner.BeginLedgerScan({ force = true }), "forced ledger scan should start with stale persisted source state present")
run_all_pending()

assert.truthy(#(_G.GBankManagerDB.bankLedger.itemLogs or {}) >= 1, "ledger scanner should still import visible item-log rows after reload-like stale source state")
assert.truthy(#(_G.GBankManagerDB.bankLedger.moneyLogs or {}) >= 1, "ledger scanner should still import visible money-log rows after reload-like stale source state")
```

- [ ] **Step 3: Run the focused scanner specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `FAIL` because the current scanner still relies on the old ledger merge assumptions

- [ ] **Step 4: Implement a single shared all-log rescan path**

```lua
local function query_all_ledger_logs()
    for _, target in ipairs(scanner.ledgerTargets or {}) do
        query_ledger_target(target)
    end
end

function scanner.BeginLedgerScan(options)
    local db = current_db()
    options = type(options) == "table" and options or {}
    if scanner.ledgerScanInProgress then
        return false
    end
    if options.force ~= true and not ledger_scan_allowed(db) then
        return false
    end

    scanner.ledgerTargets = build_ledger_targets()
    scanner.ledgerScanInProgress = true
    scanner.ledgerScanStartedAt = type(_G.time) == "function" and (_G.time() or 0) or 0
    scanner.ledgerScanSilent = options.silent == true
    scanner.ledgerMergedItemRows = 0
    scanner.ledgerMergedMoneyRows = 0
    clear_ledger_wait_state()

    if scanner.ledgerScanSilent ~= true then
        report_status("Guild bank ledger scan started.")
    end

    scanner.ledgerWaitToken = (tonumber(scanner.ledgerWaitToken or 0) or 0) + 1
    scanner.ledgerWaitSawEvent = false
    query_all_ledger_logs()
    schedule_ledger_target_timeout("ALL", scanner.ledgerWaitToken, LEDGER_TARGET_TIMEOUT_SECONDS)
    return true
end
```

- [ ] **Step 5: Make `GUILDBANKLOG_UPDATE` debounce into one full read and merge pass**

```lua
function scanner.OnGuildBankLogUpdated()
    if not scanner.ledgerScanInProgress then
        return true
    end

    scanner.ledgerWaitSawEvent = true
    scanner.ledgerWaitToken = (tonumber(scanner.ledgerWaitToken or 0) or 0) + 1
    local waitToken = scanner.ledgerWaitToken

    schedule_after(LEDGER_QUERY_SETTLE_DELAY_SECONDS, function()
        if not scanner.ledgerScanInProgress or scanner.ledgerWaitToken ~= waitToken then
            return
        end

        capture_all_ledger_targets(current_db())
        finish_ledger_scan(current_db())
    end)
    return true
end
```

- [ ] **Step 6: Keep passive refresh on the shared rescan path**

```lua
schedule_after(PASSIVE_LEDGER_RESCAN_SECONDS, function()
    if scanner.passiveLedgerRefreshToken ~= refreshToken then
        return
    end

    scanner.passiveLedgerRefreshActive = false
    if scanner.guildBankOpen ~= true then
        return
    end

    if not scanner.scanInProgress and not scanner.ledgerScanInProgress then
        scanner.BeginLedgerScan({
            force = true,
            silent = true,
            passive = true,
        })
    end

    schedule_passive_ledger_refresh()
end)
```

- [ ] **Step 7: Run the focused scanner specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\bank_ledger_scanner_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
```

Expected:

- `PASS tests/spec/bank_ledger_scanner_spec.lua`
- `PASS tests/spec/bank_ledger_spec.lua`

- [ ] **Step 8: Commit**

```bash
git add tests/spec/bank_ledger_scanner_spec.lua GBankManager/Features/GuildBankScanner.lua GBankManager/Features/GuildBankScannerEvents.lua GBankManager/Domain/BankLedger.lua
git commit -m "fix: align ledger rescans with stable debounced log reads"
```

---

### Task 4: Replace the Exports excess drill-in text with a right-aligned icon affordance and update docs

**Files:**
- Modify: `tests/spec/ui_exports_spec.lua`
- Modify: `GBankManager/Domain/Exports.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/MainExportsController.lua`
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Test: `tests/spec/ui_exports_spec.lua`

- [ ] **Step 1: Write the failing exports UI affordance expectations**

```lua
assert.equal(10, mainFrame.tableRowsData[1].excessQtyValue, "exports rows should still keep the raw excess quantity value")
assert.equal("", tostring(mainFrame.tableRowsData[1].excessQtyLabel or ""), "exports rows should stop embedding the old view text in the display label")
assert.equal(true, mainFrame.tableRowsData[1].excessQtyHasDrillIn, "non-zero excess rows should expose a drill-in flag")
assert.equal(false, mainFrame.tableRowsData[2].excessQtyHasDrillIn, "zero-excess rows should not expose a drill-in flag")
assert.truthy(type((((mainFrame.tableRows or {})[1] or {}).columnIcons or {})[8]) == "table", "exports excess cells should use the shared table icon surface")
```

- [ ] **Step 2: Run the focused exports spec to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
```

Expected:

- `FAIL` because current rows still render `view` text instead of icon metadata

- [ ] **Step 3: Implement row metadata for the drill-in icon**

```lua
rows[#rows + 1] = {
    itemID = row.itemID,
    itemTier = crafted_quality_markup_for_item(itemID, preferred_quality_icon(qualitySource), qualityValue, qualitySource.craftedQualityFamilySize or qualitySource.craftedQualityMax),
    excessQty = excessQty,
    excessQtyValue = excessQty,
    excessQtyLabel = tostring(excessQty),
    excessQtyHasDrillIn = excessQty > 0,
    stockedElsewhereTabs = elsewhereTabs,
}
```

- [ ] **Step 4: Implement the shared table icon presentation for the Exports excess column**

```lua
if self.activeView == "EXPORTS" and columnLayout.key == "excessQtyLabel" then
    local hasDrillIn = rowData.excessQtyHasDrillIn == true
    local icon = rowFrame.columnIcons[columnIndex]
    local label = rowFrame.columns[columnIndex]

    label:SetText(tostring(rowData.excessQtyLabel or "0"))
    if hasDrillIn then
        icon.atlas = "communities-icon-addchannelplus"
        if type(icon.SetAtlas) == "function" then
            icon:SetAtlas(icon.atlas, true)
        end
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", rowFrame, "TOPLEFT", offset + width - 8, -12)
        icon:Show()
    else
        icon:Hide()
    end
end
```

- [ ] **Step 5: Keep the existing modal behavior and verify the total-off-tab summary remains**

```lua
function mainFrame:OpenExportStockedElsewhereModal(row)
    local totalExcess = tonumber(row.excessQtyValue or row.excessQty or 0) or 0
    local currentTab = tostring(row.bankTab or "Assigned Tab")
    local lines = {
        string.format("Total excess outside %s: %d", currentTab, totalExcess),
        "",
    }

    for _, tab in ipairs(row.stockedElsewhereTabs or {}) do
        lines[#lines + 1] = string.format("%s: %d", tostring(tab.tabName or "Unknown"), tonumber(tab.quantity or 0) or 0)
    end

    self.exportStockedElsewhereText:SetText(table.concat(lines, "\n"))
end
```

- [ ] **Step 6: Run the focused exports spec to verify it passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_exports_spec.lua
```

Expected:

- `PASS tests/spec/ui_exports_spec.lua`

- [ ] **Step 7: Update docs for the corrected live behavior**

```markdown
- Crafted-quality icons on non-inventory surfaces now honor bundled display atlas metadata for true two-rank items.
- Guild bank ledger scans and passive bank-open refresh now share the same debounced all-log query path and stable fingerprint dedupe.
- Exports `Excess Qty` uses a right-aligned drill-in icon when stocked-elsewhere details are available.
```

- [ ] **Step 8: Run the full regression suite**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected:

- `PASS tests/run_all.lua`

- [ ] **Step 9: Commit**

```bash
git add tests/spec/ui_exports_spec.lua GBankManager/Domain/Exports.lua GBankManager/UI/MainFrame.lua GBankManager/UI/MainExportsController.lua README.md docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
git commit -m "fix: clarify export excess drill-in and document ledger reliability"
```

---

## Self-Review

### Spec coverage

- Crafted-quality non-inventory atlas correction: covered by Task 1
- Ledger reliability across reloads: covered by Tasks 2 and 3
- Passive refresh using the working ledger rescan model: covered by Task 3
- Exports right-aligned icon affordance and modal continuity: covered by Task 4

### Placeholder scan

- No `TBD`, `TODO`, or deferred implementation placeholders remain
- Every code-changing step includes concrete code blocks
- Every verification step includes a concrete command and expected result

### Type consistency

- crafted-quality plan uses existing function names: `GetDisplayAtlasForItem`, `DebugItemResolution`, `DisplayMarkupForItem`
- ledger plan uses existing merge entrypoints: `MergeItemTransactions`, `MergeMoneyTransactions`, `BeginLedgerScan`, `OnGuildBankLogUpdated`
- exports plan uses current row keys: `excessQtyValue`, `excessQtyLabel`, `stockedElsewhereTabs`

