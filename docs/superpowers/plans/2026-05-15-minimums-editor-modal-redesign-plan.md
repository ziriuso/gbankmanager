# Minimums Editor Modal Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Minimums footer editor with a centered reusable details modal, immediately hand off from search into details during add flow, fix draft-state row styling, and backfill crafted tier from the bundled item catalog when scan data is missing it.

**Architecture:** Keep the existing Minimums search modal, but route confirmed item selection into a second centered `Minimum Details` modal that becomes the sole editor for both staged and existing Minimums rows. Move crafted-tier enrichment into a shared Minimums hydration helper, and reduce table rows to display-only state with modal launch and consistent added/edited/removed styling.

**Tech Stack:** WoW Lua, Blizzard frame APIs, GBankManager shared shell helpers, local Lua test harness, focused UI specs.

---

## File Structure Map

**Precondition**

The worktree currently contains unrelated uncommitted search-selection fixes in:

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_requests_spec.lua`

Do not mix those changes into this Minimums modal implementation. Land or preserve them separately before editing the files below.

**Files to modify**

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
  - Build the new details modal
  - Remove footer-editor-driven workflow
  - Open details modal after search add confirmation and on row click
  - Centralize crafted-tier backfill for Minimums display state
  - Apply row draft-state styling consistently

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
  - Extend reusable icon-button helpers for a green plus action
  - Keep icon-only button rendering with no fallback letter overlays

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrame.lua`
  - Remove any remaining footer-editor assumptions in row-click handling and theme application

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
  - Add failing and then passing tests for modal handoff, centered editor reuse, row highlighting, icon cleanup, and crafted-tier backfill

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`
  - Update Minimums manual verification steps

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\testing.md`
  - Update focused Minimums testing notes if the old footer flow is documented

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
  - Update any user-facing note that still describes the footer editor

**No new files required unless the Minimums modal helper becomes too large.**

If `MainMinimumsController.lua` becomes unmanageable during implementation, split modal-specific helper functions into:

- `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsModal.lua`

Only do this if the change stops being readable in the existing file.

---

### Task 1: Lock the Minimums modal behavior in tests

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing tests for the new modal-driven flow**

Add assertions like:

```lua
mainFrame.minimumAddItemIDInput:SetText("243734")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)

assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "minimum add flow should hand off directly into the details modal")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "minimums should not use the footer editor after add")
assert.equal("Thalassian Phoenix Oil", mainFrame.minimumDetailsItemNameText:GetText(), "details modal should show the selected item name")
assert.equal("Professions-ChatIcon-Quality-Tier2", mainFrame.minimumDetailsItemQualityIcon.atlas, "details modal should backfill crafted tier from the catalog when scan data does not provide it")
```

Also add row-state tests like:

```lua
assert.equal("added", mainFrame:GetMinimumDraftState(stagedRow), "newly confirmed rows should remain draft adds before save")
assert.truthy(stagedRowFrame.minimumDraftTint ~= nil, "added rows should receive draft styling")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails for the right reason**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because `minimumDetailsModal` does not exist yet or because the footer editor is still shown.

- [ ] **Step 3: Commit the failing-test checkpoint**

```bash
git add tests/spec/ui_minimums_spec.lua
git commit -m "test: cover minimums modal editor flow"
```

---

### Task 2: Add reusable icon-only support for the new Minimums actions

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrameShell.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing test for icon-only add/remove/undo buttons**

Add expectations like:

```lua
assert.equal("add", mainFrame.minimumDetailsConfirmButton.iconKind, "details modal should use the shared add icon button")
assert.equal("remove", mainFrame.minimumDetailsRemoveButton.iconKind, "details modal should use the shared remove icon button")
assert.equal("undo", mainFrame.minimumDetailsUndoButton.iconKind, "details modal should use the shared undo icon button")
assert.equal("", mainFrame.minimumDetailsRemoveButton.labelText:GetText(), "remove button should not overlay fallback letters")
assert.equal("", mainFrame.minimumDetailsUndoButton.labelText:GetText(), "undo button should not overlay fallback letters")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because the new modal buttons are not built yet and the shared shell does not yet expose the green add icon path.

- [ ] **Step 3: Implement the minimal shared shell support**

Update `MainFrameShell.SetButtonIcon` so it supports an `add` kind and keeps label text empty for icon buttons:

```lua
function mainFrameShell.SetButtonIcon(button, kind)
    if not button then
        return
    end

    button.iconKind = kind
    if button.labelText then
        button.labelText:SetText("")
    end

    button.iconTexture = button.iconTexture or button:CreateTexture()
    if type(button.iconTexture.SetAllPoints) == "function" then
        button.iconTexture:SetAllPoints()
    end

    local atlasByKind = {
        add = "common-icon-rotateleft",
        remove = "common-icon-redx",
        undo = "common-icon-undo",
    }

    if type(button.iconTexture.SetAtlas) == "function" then
        button.iconTexture:SetAtlas(atlasByKind[kind] or "common-icon-undo", true)
    end
end
```

Replace the temporary `add` atlas with the best green-plus atlas available in the current shell/theme pass after verifying what the addon already uses elsewhere.

- [ ] **Step 4: Run the Minimums UI spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: the icon-only assertions now pass, even though the overall spec may still fail on the missing modal flow.

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainFrameShell.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: add shared icon-only minimums action support"
```

---

### Task 3: Build the centered reusable Minimum Details modal

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrame.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing test for modal construction and reuse**

Add assertions like:

```lua
assert.truthy(mainFrame.minimumDetailsModal ~= nil, "minimums should build a reusable details modal")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should not be used as the active edit surface")
mainFrame:HandleTableRowClick(existingRow)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "existing row click should open the centered details modal")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because the modal is not present and row click still opens the footer editor.

- [ ] **Step 3: Implement the minimal modal structure**

Add a new centered modal in `MainMinimumsController.lua` near the existing search modal:

```lua
mainFrame.minimumDetailsModal = mainFrame.minimumDetailsModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
mainFrame.minimumDetailsModal:SetSize(500, 250)
mainFrame.minimumDetailsModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
mainFrame.minimumDetailsModal.frameStrata = "FULLSCREEN_DIALOG"
if type(mainFrame.minimumDetailsModal.SetFrameStrata) == "function" then
    mainFrame.minimumDetailsModal:SetFrameStrata(mainFrame.minimumDetailsModal.frameStrata)
end
mainFrame.minimumDetailsModal.frameLevel = (mainFrame.frameLevel or 0) + 21
if type(mainFrame.minimumDetailsModal.SetFrameLevel) == "function" then
    mainFrame.minimumDetailsModal:SetFrameLevel(mainFrame.minimumDetailsModal.frameLevel)
end
applyPanelStyle(mainFrame.minimumDetailsModal, theme.colors.panelAlt)
mainFrame.minimumDetailsModal:Hide()
```

Add the title, item display, Bank Tab control, Restock toggle, Minimum input, status text, and icon-only confirm/remove/undo/cancel buttons in this modal instead of the footer panel.

- [ ] **Step 4: Route row click into the modal**

Replace footer-editor-driven row selection with:

```lua
function mainFrame:HandleTableRowClick(row)
    if not row then
        return nil
    end

    self.selectedMinimumKey = row.rowKey
    return self:OpenMinimumDetailsModal(row)
end
```

Keep `minimumEditorPanel` hidden during the new flow.

- [ ] **Step 5: Run the Minimums UI spec to verify the modal flow passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: the modal construction and row-click tests pass; remaining failures should now be around draft-state behavior or crafted-tier backfill.

- [ ] **Step 6: Commit**

```bash
git add GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MainFrame.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: add centered minimum details modal"
```

---

### Task 4: Hand off directly from search add into the details modal

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing test for add-to-details handoff**

Add a focused test like:

```lua
mainFrame:OpenMinimumAddModal()
mainFrame.minimumAddItemIDInput:SetText("243734")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)

assert.truthy(not mainFrame.minimumAddModal:IsShown(), "search modal should close after confirming an item for add")
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "minimum add flow should continue directly into details")
assert.equal("243734", mainFrame.minimumDetailsItemIDText:GetText(), "details modal should inherit the chosen item")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because `minimumAddButton` still stages rows directly and closes the modal.

- [ ] **Step 3: Implement the minimal handoff**

Replace direct staging in the `Add` button flow with:

```lua
function mainFrame:BeginMinimumDraftFromSelectedItem()
    local item = self:GetConfirmedMinimumAddItem()
    if not item then
        return nil
    end

    self:HideMinimumAddModal()
    return self:OpenMinimumDetailsModal({
        itemID = tonumber(item.itemID),
        itemName = tostring(item.name or item.itemName or ""),
        enabled = true,
        scope = "TAB",
        tabName = nil,
        quantity = self:GetMinimumSettings(currentDb()).defaultQuantity or 100,
        isNewlyAdded = true,
    })
end
```

Wire the existing add button to this handoff instead of directly calling `CreateMinimumFromAddRow()`.

- [ ] **Step 4: Run the Minimums UI spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: the add-to-details handoff now passes.

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainMinimumsController.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: hand off minimum adds into details modal"
```

---

### Task 5: Stage, edit, delete, and undo rows through the new modal

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing tests for confirm/remove/undo through the modal**

Add expectations like:

```lua
mainFrame.minimumDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownButton)
mainFrame.minimumDetailsBankTabDropdownOptions[1]:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownOptions[1])
mainFrame.minimumDetailsQuantityInput:SetText("100")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)

assert.truthy(#mainFrame.tableRowsData > 0, "confirming the details modal should stage a new row")
assert.equal("added", mainFrame:GetMinimumDraftState(mainFrame.tableRowsData[1]), "newly staged rows should be draft adds")
```

Add remove and undo assertions for both new and existing rows.

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because the details modal actions do not yet update draft state.

- [ ] **Step 3: Implement the minimal modal action handlers**

Add modal handlers like:

```lua
function mainFrame:ConfirmMinimumDetailsModal()
    local state = self.minimumDetailsWorkingState
    if not state or tostring(state.tabName or "") == "" then
        return nil
    end

    if not tonumber(state.quantity) then
        return nil
    end

    self:StageMinimumDraftFromState(state)
    self.minimumDetailsModal:Hide()
    self:ApplyMinimumFilters()
    return state
end
```

And:

```lua
function mainFrame:RemoveMinimumDetailsDraft()
    local row = self.minimumDetailsSourceRow
    if not row then
        return nil
    end

    self:MarkMinimumDeleted(row)
    self.minimumDetailsModal:Hide()
    self:ApplyMinimumFilters()
    return row
end
```

Implement a corresponding undo path that restores draft state and closes or refreshes the modal.

- [ ] **Step 4: Run the Minimums UI spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: confirm/remove/undo behavior now passes through the modal.

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainMinimumsController.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: route minimum draft actions through details modal"
```

---

### Task 6: Add crafted-tier backfill from the bundled item catalog

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing test for `243734` crafted-tier backfill**

Add a focused test like:

```lua
local row = mainFrame.tableRowsData[1]
assert.equal(243734, row.itemID, "fixture should expose the Thalassian Phoenix Oil row")
assert.equal(2, row.craftedQuality, "minimums row should backfill crafted quality from the bundled item catalog")
assert.equal("Professions-ChatIcon-Quality-Tier2", row.craftedQualityIcon, "minimums row should backfill crafted quality icon from the bundled item catalog")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because the row hydration does not yet enrich tier from the catalog.

- [ ] **Step 3: Implement the shared backfill helper**

Add a single helper in `MainMinimumsController.lua`:

```lua
function mainFrame:BackfillMinimumCraftedTier(item)
    if not item or tonumber(item.craftedQuality or 0) > 0 then
        return item
    end

    local itemCatalog = ns.modules.itemCatalog
    local resolved = itemCatalog and type(itemCatalog.GetItemByID) == "function"
        and itemCatalog.GetItemByID(tonumber(item.itemID))
        or nil

    if resolved then
        item.craftedQuality = item.craftedQuality or resolved.craftedQuality
        item.craftedQualityIcon = item.craftedQualityIcon or resolved.craftedQualityIcon
    end

    return item
end
```

Call it from both row hydration and details-modal state hydration.

- [ ] **Step 4: Run the Minimums UI spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `243734` and similar rows now show the expected crafted tier data.

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainMinimumsController.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: backfill minimum crafted tiers from item catalog"
```

---

### Task 7: Apply reliable row draft-state styling and remove row artifacts

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainMinimumsController.lua`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\GBankManager\UI\MainFrame.lua`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\spec\ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing tests for added/edited/removed styling and no footer artifacts**

Add expectations like:

```lua
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should remain hidden in the modal-based Minimums flow")
assert.truthy(stagedRowFrame.minimumDraftTint ~= nil, "added rows should receive a draft tint")
assert.equal("added", stagedRowFrame.minimumDraftState, "added rows should expose their draft state on the row frame")
```

And after editing/removing:

```lua
assert.equal("changed", existingRowFrame.minimumDraftState, "edited rows should expose changed state")
assert.equal("deleted", removedRowFrame.minimumDraftState, "removed rows should expose deleted state")
```

- [ ] **Step 2: Run the Minimums UI spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `FAIL` because the current row styling is incomplete or still tied to footer-editor assumptions.

- [ ] **Step 3: Implement the minimal row-only styling path**

Make `ApplyMinimumDraftStyle` the single row-state renderer and remove any inline control remnants:

```lua
function mainFrame:SyncMinimumInlineRow(rowFrame, row, rowIndex)
    if not rowFrame then
        return
    end

    self:HideMinimumInlineRow(rowFrame)
    self:ApplyMinimumDraftStyle(rowFrame, rowIndex, row and self:GetMinimumDraftState(row) or nil)
end
```

Ensure `HideMinimumInlineRow` clears any leftover inline widgets or state anchors that can create the left-edge artifact.

- [ ] **Step 4: Run the Minimums UI spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: draft-state styling now passes and the footer editor is no longer the active row-edit surface.

- [ ] **Step 5: Commit**

```bash
git add GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MainFrame.lua tests/spec/ui_minimums_spec.lua
git commit -m "fix: stabilize minimum draft row styling"
```

---

### Task 8: Update docs and run the full suite

**Files:**
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\manual-test-checklist.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\docs\testing.md`
- Modify: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\README.md`
- Test: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1\tests\run_all.lua`

- [ ] **Step 1: Update the documentation to describe the modal-based Minimums editor**

Document:

```md
- Minimums add flow now transitions from item search into a centered details modal.
- Existing Minimums rows are edited through the same details modal.
- Draft row colors indicate added, edited, and removed state before Save All.
- Crafted tier can be backfilled from the bundled item catalog when scan data does not include it.
```

- [ ] **Step 2: Run the focused Minimums spec**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua`

Expected: `PASS`

- [ ] **Step 3: Run the full addon suite**

Run: `.\tools\lua\lua.exe .\tests\run_all.lua`

Expected:

```text
PASS tests/run_unit.lua
PASS tests/run_ui.lua
PASS tests/run_integration.lua
PASS tests/run_all.lua
```

- [ ] **Step 4: Commit**

```bash
git add docs/manual-test-checklist.md docs/testing.md README.md tests/spec/ui_minimums_spec.lua GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MainFrame.lua GBankManager/UI/MainFrameShell.lua
git commit -m "feat: redesign minimums editing around centered modal"
```

---

## Self-Review

### Spec Coverage

- Centered reusable details modal: covered in Tasks 3 and 4.
- Immediate add flow handoff from search into details: covered in Task 4.
- Icon-only add/remove/undo cleanup: covered in Task 2.
- Reliable add/edit/remove row highlighting: covered in Task 7.
- Remove inline/footer editing from rows: covered in Tasks 3 and 7.
- Crafted-tier backfill from catalog when scan data is missing: covered in Task 6.
- Docs and manual checklist updates: covered in Task 8.

### Placeholder Scan

- No `TODO`, `TBD`, or “implement later” placeholders remain.
- Each code-changing task includes concrete file paths, code snippets, commands, and expected outcomes.

### Type Consistency

- `minimumDetailsModal`, `minimumDetailsWorkingState`, and `BackfillMinimumCraftedTier` are used consistently throughout the plan.
- Draft state names remain `added`, `changed`, and `deleted` to match current controller semantics.
