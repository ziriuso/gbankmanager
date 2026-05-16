package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.GBankManagerDB = {
    currentSnapshotId = "minimums-ui",
    snapshots = {
        ["minimums-ui"] = {
            items = {
                [7007] = {
                    itemID = 7007,
                    name = "Algari Mana Oil",
                    totalCount = 4,
                    tabs = {
                        Alchemy = 4,
                        ["Gems and Enchants"] = 1,
                    },
                },
            },
        },
    },
    minimums = {},
    requests = {},
    auditLog = {},
    ui = {
        minimumItemCatalog = {
            {
                itemID = 990001,
                name = "Test Crafted Widget",
                craftedQuality = 5,
                craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
            },
            {
                itemID = 243734,
                name = "Thalassian Phoenix Oil",
                craftedQuality = 2,
                craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
            },
            {
                itemID = 990010,
                name = "Test Variant Flask",
                craftedQuality = 2,
                craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
            },
            {
                itemID = 990011,
                name = "Test Variant Flask",
                craftedQuality = 5,
                craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
            },
        },
        minimumSettings = {
            defaultQuantity = 250,
        },
    },
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("MINIMUMS")
assert.truthy(mainFrame.minimumsPanel:IsShown(), "minimums editor panel should show in the minimums view")
assert.truthy(mainFrame.tableViewportFrame:IsShown(), "minimums view should show the shared table viewport")
assert.equal("Save All", mainFrame.minimumSaveButton.labelText:GetText(), "minimums view should keep the top-level save action label")
assert.equal(7, #mainFrame.tableColumnLayout, "minimums view should fully remove the deprecated restock-source column")
assert.equal("Minimum", mainFrame.tableHeaderLabels[7]:GetText(), "minimums view should end the table at the minimum column")
assert.truthy(mainFrame.tableHeaderLabels[8] == nil or mainFrame.tableHeaderLabels[8].shown == false, "minimums view should not render a ghost eighth header")
assert.truthy((mainFrame.minimumsPanel:GetHeight() or 0) >= 108, "minimums footer should be tall enough to keep search clear of the action buttons")
assert.truthy(((mainFrame.minimumSearchInput.points[1] or {})[5] or 0) < ((mainFrame.minimumNewButton.points[1] or {})[5] or 999), "minimums search should sit above the bottom action row instead of colliding with it")

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
assert.truthy(mainFrame.minimumAddModal:IsShown(), "add should open the minimum modal")
assert.equal("250", mainFrame.minimumAddQuantityInput:GetText(), "new minimum rows should start from the configured default minimum value")
assert.truthy(mainFrame.minimumAddButton.enabled == false, "minimum add modal should keep Add disabled until a catalog item is selected")
assert.equal("Search Item ID", mainFrame.minimumAddItemIDLabel:GetText(), "minimum add modal should clearly label the item-id search box")
assert.equal("Search Item Name", mainFrame.minimumAddItemNameLabel:GetText(), "minimum add modal should clearly label the item-name search box")
assert.equal("Minimum", mainFrame.minimumAddQuantityLabel:GetText(), "minimum add modal should label the quantity field clearly")
assert.equal("Matches", mainFrame.minimumAddResultsLabel:GetText(), "minimum add modal should label the results list clearly")
assert.equal("Selected Item", mainFrame.minimumAddSelectedItemLabel:GetText(), "minimum add modal should clearly label the selected item display")

mainFrame:ResetMinimumAddRow()
mainFrame.minimumAddItemIDInput:SetText("243734")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
assert.equal("243734", mainFrame.minimumAddItemIDInput:GetText(), "minimum add modal should resolve item 243734 by exact item id before the modal handoff assertion runs")
assert.equal("Thalassian Phoenix Oil", mainFrame.minimumAddItemNameInput:GetText(), "minimum add modal should populate item 243734 name before the modal handoff assertion runs")
assert.truthy(mainFrame.minimumAddButton.enabled ~= false, "minimum add modal should enable Add after resolving item 243734 before the modal handoff assertion runs")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(mainFrame.minimumDetailsModal ~= nil, "minimums should build a reusable details modal shell")
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "search modal should close after confirming an item for add")
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "minimum add flow should continue directly into details")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "minimums should not use the footer editor after add")
assert.equal("243734", mainFrame.minimumDetailsItemIDText:GetText(), "details modal should inherit the chosen item id from the search modal")
assert.equal("Thalassian Phoenix Oil", mainFrame.minimumDetailsItemNameText:GetText(), "details modal should inherit the chosen item name from the search modal")
assert.truthy(mainFrame.minimumPendingRules == nil or next(mainFrame.minimumPendingRules) == nil, "minimum add handoff should not stage a draft row before later details confirmation work lands")
assert.equal("add", mainFrame.minimumDetailsConfirmButton.iconKind, "details modal should use the shared add icon button")
assert.equal("remove", mainFrame.minimumDetailsRemoveButton.iconKind, "details modal should use the shared remove icon button")
assert.equal("undo", mainFrame.minimumDetailsUndoButton.iconKind, "details modal should use the shared undo icon button")
assert.equal("common-icon-plus", (mainFrame.minimumDetailsConfirmButton.iconTexture or {}).atlas, "details modal should wire the shared add icon atlas for the confirm action")
assert.equal(0.35, (((mainFrame.minimumDetailsConfirmButton.iconTexture or {}).tint or {})[1] or 0), "details modal should tint the shared add icon green")
assert.equal("", mainFrame.minimumDetailsConfirmButton.labelText:GetText(), "details modal confirm action should remain icon-only")
assert.equal("", mainFrame.minimumDetailsRemoveButton.labelText:GetText(), "details modal remove action should remain icon-only")
assert.equal("", mainFrame.minimumDetailsUndoButton.labelText:GetText(), "details modal undo action should remain icon-only")
assert.truthy(mainFrame.minimumDetailsConfirmButton.enabled == false, "details modal confirm action should stay disabled until later task wiring lands")
assert.truthy(mainFrame.minimumDetailsRemoveButton.enabled == false, "details modal remove action should stay disabled until later task wiring lands")
assert.truthy(mainFrame.minimumDetailsUndoButton.enabled == false, "details modal undo action should stay disabled until later task wiring lands")

local originalGetMinimumSearchSnapshot = mainFrame.GetMinimumSearchSnapshot
local minimumSearchSnapshotCalls = 0
function mainFrame:GetMinimumSearchSnapshot()
    minimumSearchSnapshotCalls = minimumSearchSnapshotCalls + 1
    return originalGetMinimumSearchSnapshot(self)
end

mainFrame:ResetMinimumAddRow()
mainFrame.minimumSearchSession = nil
mainFrame.minimumAddItemNameInput:SetText("f")
assert.equal(0, mainFrame.minimumAddSearchSelector.resultsDataProvider:GetSize(), "minimum add modal should not activate name search before two typed characters")
assert.truthy(not mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should keep the results list hidden before two typed characters")
mainFrame.minimumAddItemNameInput:SetText("fl")
assert.truthy((mainFrame.minimumAddSearchSelector.resultsDataProvider:GetSize() or 0) > 0, "minimum add modal should activate name search once two characters are typed")
mainFrame.minimumAddItemNameInput:SetText("fla")
assert.equal(1, minimumSearchSnapshotCalls, "minimum add modal should build the shared search session once and reuse it across follow-up name queries")
mainFrame.GetMinimumSearchSnapshot = originalGetMinimumSearchSnapshot
mainFrame:ResetMinimumAddRow()

mainFrame.minimumAddItemNameInput:SetText("Test Crafted")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.equal("Test Crafted", mainFrame.minimumAddItemNameInput:GetText(), "minimum add modal should not overwrite an in-progress partial name search")
assert.equal("No item selected.", mainFrame.minimumAddSelectedItemNameText:GetText(), "minimum add modal should wait for explicit selection on partial name matches")
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should show matches for a partial name search")
assert.truthy(mainFrame.minimumAddButton.enabled == false, "minimum add modal should keep Add disabled while only partial name matches are showing")
mainFrame.minimumAddMatchButtons[1]:GetScript("OnClick")(mainFrame.minimumAddMatchButtons[1])
mainFrame.minimumAddItemNameInput:SetText("Test Crafted Widget")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.equal("990001", mainFrame.minimumAddItemIDInput:GetText(), "minimum add modal should resolve catalog items by item name")
assert.equal("Test Crafted Widget", mainFrame.minimumAddSelectedItemNameText:GetText(), "minimum add modal should show the selected item name after resolution")
assert.equal("Professions-ChatIcon-Quality-Tier5", mainFrame.minimumAddSelectedItemQualityIcon.atlas, "minimum add modal should show the selected item crafting quality icon when available")
assert.truthy(mainFrame.minimumAddButton.enabled ~= false, "minimum add modal should enable Add after a catalog item is selected")

mainFrame:ResetMinimumAddRow()
mainFrame.minimumAddItemNameInput:SetText("flask of")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should show a scrollable result panel for broad token queries")
assert.truthy(type(mainFrame.minimumAddSearchSelector.resultsScrollBox) == "table", "minimums selector should expose a virtualized results scroll box")
assert.truthy(type(mainFrame.minimumAddSearchSelector.resultsDataProvider) == "table", "minimums selector should expose a results data provider")
assert.truthy((mainFrame.minimumAddSearchSelector.resultsDataProvider:GetSize() or 0) > 0, "minimums selector should populate the results data provider for broad searches")
assert.truthy((mainFrame.minimumAddSearchSelector.resultsScrollFrame or {}).scrollChild ~= nil, "minimum add modal should wire a scroll child for result rows")
local minimumBroadResultRow = (mainFrame.minimumAddSearchSelector.resultRows or {})[1] or {}
assert.truthy(string.find((minimumBroadResultRow.itemText or {}):GetText() or "", tostring(((minimumBroadResultRow.resolvedItem or {}).itemID or "")), 1, true) ~= nil, "minimum add result rows should show the item id inline")
assert.truthy(((mainFrame.minimumAddSearchSelector.resultRows or {})[1] or {}).qualityIcon ~= nil, "minimum add result rows should expose a crafting quality icon region")

mainFrame:ResetMinimumAddRow()
mainFrame.minimumAddItemIDInput:SetText("241323")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
assert.equal("241323", mainFrame.minimumAddItemIDInput:GetText(), "minimum add modal should resolve known bundled catalog items by exact item id")
assert.equal("Flask of the Magisters", mainFrame.minimumAddItemNameInput:GetText(), "minimum add modal should populate the bundled catalog item name from an exact item-id search")
assert.truthy(mainFrame.minimumAddButton.enabled ~= false, "minimum add modal should enable Add after an exact item-id catalog match")

mainFrame.minimumAddItemNameInput:SetText("flask of")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.equal("", mainFrame.minimumAddItemIDInput:GetText(), "minimum add modal should clear the stale item-id field when a broader name search invalidates the prior selection")
assert.equal("No item selected.", mainFrame.minimumAddSelectedItemNameText:GetText(), "minimum add modal should clear the selected item display when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should reopen the matches panel when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.minimumAddSearchSelector.resultsScrollController ~= nil, "minimum add modal should use the shared shell scroll controller for result rows")
assert.truthy(mainFrame.minimumAddSearchSelector.resultsScrollBar ~= nil, "minimum add modal should expose the shared shell scrollbar for result rows")

mainFrame:ResetMinimumAddRow()
mainFrame.minimumAddItemNameInput:SetText("test variant flask")
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should keep duplicate-name quality variants in the results list")
assert.truthy(string.find((((mainFrame.minimumAddSearchSelector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "[T5]", 1, true) ~= nil, "minimum add result rows should show the higher crafted tier first for duplicate-name variants")
assert.truthy(string.find((((mainFrame.minimumAddSearchSelector.resultRows or {})[2] or {}).itemText or {}):GetText() or "", "[T2]", 1, true) ~= nil, "minimum add result rows should keep lower crafted tiers visible as separate entries")
assert.equal("Professions-ChatIcon-Quality-Tier5", (((mainFrame.minimumAddSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}).atlas, "minimum add result rows should show the crafted quality icon for the selected tier entry")
local selectedMinimumVariantRow = mainFrame.minimumAddMatchButtons[2]
local selectedMinimumVariantItem = selectedMinimumVariantRow.resolvedItem
mainFrame.minimumAddMatchButtons[2]:GetScript("OnClick")(mainFrame.minimumAddMatchButtons[2])
mainFrame.minimumAddItemNameInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemNameInput)
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
assert.equal(tostring((selectedMinimumVariantItem or {}).itemID or ""), mainFrame.minimumAddItemIDInput:GetText(), "minimum add modal should preserve the explicitly selected duplicate-name item id after delayed input callbacks")
assert.equal(tostring((selectedMinimumVariantItem or {}).name or (selectedMinimumVariantItem or {}).itemName or ""), mainFrame.minimumAddSelectedItemNameText:GetText(), "minimum add modal should keep the selected item display after delayed input callbacks")
assert.equal((selectedMinimumVariantItem or {}).craftedQualityIcon, mainFrame.minimumAddSelectedItemQualityIcon.atlas, "minimum add modal should keep the selected duplicate-name tier after delayed input callbacks")
assert.truthy(not mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should keep the matches panel hidden after a duplicate-name selection survives delayed input callbacks")
assert.truthy(mainFrame.minimumAddButton.enabled ~= false, "minimum add modal should keep Add enabled after delayed callbacks on a valid selection")
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame.minimumAddItemIDInput:SetText("7007")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddSearchSelector:ClearSelection()
mainFrame.minimumAddQuantityInput:SetText("250")
local minimumWithoutSelection = mainFrame:CreateMinimumFromAddRow()
assert.truthy(minimumWithoutSelection == nil, "minimum add flow should reject raw text fields when no confirmed catalog item is selected")
assert.truthy(mainFrame.minimumPendingRules == nil or next(mainFrame.minimumPendingRules) == nil, "minimum add flow should not stage a draft from raw text fields alone")

mainFrame.minimumAddItemIDInput:SetText("7007")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddQuantityInput:SetText("250")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "minimum add modal should close after handing a later add flow into details")
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "minimum add action should keep using the centered details modal instead of staging directly into the table")
assert.equal("7007", mainFrame.minimumDetailsItemIDText:GetText(), "minimum add handoff should keep the selected item id visible in the details modal")
assert.equal("Algari Mana Oil", mainFrame.minimumDetailsItemNameText:GetText(), "minimum add handoff should keep the selected item name visible in the details modal")
assert.truthy(mainFrame.minimumPendingRules == nil or next(mainFrame.minimumPendingRules) == nil, "minimum add handoff should still avoid staging draft rows before details confirmation exists")

_G.GBankManagerDB.minimums = {
    {
        itemID = 7007,
        itemName = "Algari Mana Oil",
        quantity = 250,
        scope = "TAB",
        tabName = "Alchemy",
        enabled = true,
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()

local existingRow = mainFrame.tableRowsData[1]
mainFrame:HandleTableRowClick(existingRow)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "existing minimum row click should open the centered details modal")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should not be the active edit surface after existing-row click")
assert.equal("Algari Mana Oil", mainFrame.minimumDetailsItemNameText:GetText(), "existing minimum row click should populate the details modal item name")
assert.truthy(mainFrame.tableRows[1].isSelected == true, "existing minimum row click should refresh the selected-row highlight before opening the modal")
assert.truthy(mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "existing minimum row click should keep the Bank Tab selector available in the details modal")
assert.truthy(not mainFrame.minimumDetailsBankTabValueText:IsShown(), "existing minimum row click should not duplicate the Bank Tab below the selector")
assert.equal("Alchemy", mainFrame.minimumDetailsBankTabDropdownButton.labelText:GetText(), "existing minimum row click should prefill the Bank Tab selector with the saved Bank Tab")

mainFrame.minimumDetailsQuantityInput:SetText("300")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "confirming existing minimum details should close the modal after staging the edit")
local changedExistingRow = mainFrame.tableRowsData[1]
assert.equal(300, changedExistingRow.quantityValue, "confirming existing minimum details should stage the edited quantity")
assert.equal("changed", mainFrame:GetMinimumDraftState(changedExistingRow), "confirming existing minimum details should mark the row as changed")
assert.truthy(mainFrame.tableRows[1].minimumDraftTint ~= nil, "changed minimum rows should keep draft styling after modal confirmation")
assert.equal("changed", mainFrame.tableRows[1].minimumDraftState, "edited minimum rows should expose changed state on the row frame")
assert.equal("yellow", mainFrame.tableRows[1].minimumDraftTint, "edited minimum rows should expose yellow draft tint on the row frame")
assert.equal(0.42, ((mainFrame.tableRows[1].minimumDraftBackground or {}).color or {})[1], "edited minimum rows should apply the yellow draft overlay to the table row")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should remain hidden after editing a minimum through the modal")
assert.truthy(mainFrame.tableRows[1].minimumInlineArtifactsHidden == true, "edited minimum rows should keep inline editor remnants neutralized")

mainFrame:HandleTableRowClick(changedExistingRow)
mainFrame.minimumDetailsRemoveButton:GetScript("OnClick")(mainFrame.minimumDetailsRemoveButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "removing an existing minimum through the details modal should close the modal")
local deletedExistingRow = mainFrame.tableRowsData[1]
assert.equal("deleted", mainFrame:GetMinimumDraftState(deletedExistingRow), "removing an existing minimum through the details modal should mark it deleted")
assert.truthy(mainFrame.tableRows[1].minimumDraftTint ~= nil, "deleted minimum rows should keep draft styling after modal removal")
assert.equal("deleted", mainFrame.tableRows[1].minimumDraftState, "removed minimum rows should expose deleted state on the row frame")
assert.equal("red", mainFrame.tableRows[1].minimumDraftTint, "removed minimum rows should expose red draft tint on the row frame")
assert.equal(0.44, ((mainFrame.tableRows[1].minimumDraftBackground or {}).color or {})[1], "removed minimum rows should apply the red draft overlay to the table row")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should remain hidden after deleting a minimum through the modal")
assert.truthy(mainFrame.tableRows[1].minimumInlineArtifactsHidden == true, "deleted minimum rows should keep inline editor remnants neutralized")

mainFrame:HandleTableRowClick(deletedExistingRow)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "clicking a deleted minimum row should reopen the details modal")
assert.truthy(mainFrame.minimumDetailsConfirmButton.enabled == false, "deleted minimum rows should keep confirm disabled so they cannot be restaged directly")
assert.truthy(mainFrame.minimumDetailsRemoveButton.enabled == false, "deleted minimum rows should keep remove disabled while the row is already marked deleted")
assert.truthy(mainFrame.minimumDetailsUndoButton.enabled ~= false, "deleted minimum rows should keep undo available as the restore path")
local deletedQuantityBeforeConfirm = deletedExistingRow.quantityValue
mainFrame.minimumDetailsQuantityInput:SetText("400")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)
local stillDeletedRow = mainFrame.tableRowsData[1]
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "confirm should stay inert for deleted minimum rows instead of closing and restaging them")
assert.equal("deleted", mainFrame:GetMinimumDraftState(stillDeletedRow), "confirm should not restage deleted minimum rows")
assert.equal(deletedQuantityBeforeConfirm, stillDeletedRow.quantityValue, "confirm should not mutate deleted minimum rows while they await undo or Save All")
mainFrame.minimumDetailsUndoButton:GetScript("OnClick")(mainFrame.minimumDetailsUndoButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "undoing an existing minimum through the details modal should close the modal")
local restoredExistingRow = mainFrame.tableRowsData[1]
assert.truthy(mainFrame:GetMinimumDraftState(restoredExistingRow) == nil, "undoing an existing minimum through the details modal should clear its draft state")
assert.equal(250, restoredExistingRow.quantityValue, "undoing an existing minimum through the details modal should restore the baseline quantity")
assert.truthy(mainFrame.tableRows[1].minimumDraftTint == nil, "undoing an existing minimum through the details modal should clear draft row styling")

_G.GBankManagerDB.minimums = {
    {
        itemID = 243734,
        itemName = "Thalassian Phoenix Oil",
        quantity = 80,
        scope = "TAB",
        tabName = "Alchemy",
        enabled = true,
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()

local backfilledTierRow = mainFrame.tableRowsData[1]
assert.equal(243734, tonumber(backfilledTierRow.itemID), "fixture should expose the Thalassian Phoenix Oil minimum row for crafted-tier backfill coverage")
assert.equal(2, tonumber(backfilledTierRow.craftedQuality), "minimums rows should backfill crafted tier from the bundled catalog when saved row data omits it")
assert.equal("Professions-ChatIcon-Quality-Tier2", backfilledTierRow.craftedQualityIcon, "minimums rows should backfill the crafted tier icon from the bundled catalog when saved row data omits it")
mainFrame:HandleTableRowClick(backfilledTierRow)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "clicking the backfilled minimum row should open the details modal")
assert.equal("Professions-ChatIcon-Quality-Tier2", mainFrame.minimumDetailsItemQualityIcon.atlas, "minimum details modal should reuse the crafted-tier backfill when row data omits it")
assert.equal("Tier 2", mainFrame.minimumDetailsItemQualityText:GetText(), "minimum details modal should show crafted-tier text alongside the crafted-tier icon")
assert.equal("Alchemy", mainFrame.minimumDetailsBankTabDropdownButton.labelText:GetText(), "minimum details modal should prefill the Bank Tab selector from the existing saved row")

_G.GBankManagerDB.minimums = {
    {
        itemID = 7007,
        itemName = "Algari Mana Oil",
        quantity = 250,
        scope = "TAB",
        tabName = "Alchemy",
        enabled = true,
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()
assert.truthy(mainFrame.minimumShowAllRows == true, "minimums should default to Show All rows")
assert.equal("Enabled Only", mainFrame.minimumShowAllToggleButton.labelText:GetText(), "minimums toggle should start in the Show All state")
assert.equal("", mainFrame.minimumEditorStateText:GetText() or "", "minimums footer should not show the old centered-modal hint text")
assert.truthy(not mainFrame.minimumEditorStateText:IsShown(), "minimums footer should hide the old centered-modal hint text")

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
mainFrame.minimumAddItemIDInput:SetText("243734")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "new minimum details should show the Bank Tab selector")
assert.truthy(not mainFrame.minimumDetailsBankTabValueText:IsShown(), "new minimum details should not duplicate the Bank Tab name under the selector")
mainFrame.minimumDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownButton)
mainFrame.minimumDetailsBankTabDropdownOptions[1]:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownOptions[1])
mainFrame.minimumDetailsQuantityInput:SetText("100")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "confirming a new minimum through the details modal should close the modal")
local addedDraftRow
local addedDraftFrame
for rowIndex, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 243734 then
        addedDraftRow = row
        addedDraftFrame = mainFrame.tableRows[rowIndex]
        break
    end
end
assert.truthy(addedDraftRow ~= nil, "confirming a new minimum through the details modal should stage a new row")
assert.equal(100, addedDraftRow.quantityValue, "confirming a new minimum through the details modal should stage the entered quantity")
assert.equal("Alchemy", addedDraftRow.tabName, "confirming a new minimum through the details modal should stage the selected bank tab")
assert.equal("added", mainFrame:GetMinimumDraftState(addedDraftRow), "newly staged rows should remain draft adds before save")
assert.truthy(addedDraftFrame.minimumDraftTint ~= nil, "newly staged minimum rows should receive draft styling after modal confirmation")
assert.equal("added", addedDraftFrame.minimumDraftState, "added minimum rows should expose added state on the row frame")
assert.equal("green", addedDraftFrame.minimumDraftTint, "added minimum rows should expose green draft tint on the row frame")
assert.equal(0.12, ((addedDraftFrame.minimumDraftBackground or {}).color or {})[1], "added minimum rows should apply the green draft overlay to the table row")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "footer editor should remain hidden after staging a new minimum through the modal")
assert.truthy(addedDraftFrame.minimumInlineArtifactsHidden == true, "added minimum rows should keep inline editor remnants neutralized")

mainFrame:HandleTableRowClick(addedDraftRow)
mainFrame.minimumDetailsRemoveButton:GetScript("OnClick")(mainFrame.minimumDetailsRemoveButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "removing a newly staged minimum through the details modal should close the modal")
local removedAddedDraftRow
for _, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 243734 then
        removedAddedDraftRow = row
        break
    end
end
assert.truthy(removedAddedDraftRow == nil, "removing a newly staged minimum through the details modal should discard the staged row entirely")

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
mainFrame.minimumAddItemIDInput:SetText("243734")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
mainFrame.minimumDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownButton)
mainFrame.minimumDetailsBankTabDropdownOptions[1]:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownOptions[1])
mainFrame.minimumDetailsQuantityInput:SetText("100")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)
local restagedDraftRow
for _, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 243734 then
        restagedDraftRow = row
        break
    end
end
assert.truthy(restagedDraftRow ~= nil, "restaging a new minimum should recreate the draft row before undo coverage runs")

mainFrame:HandleTableRowClick(restagedDraftRow)
mainFrame.minimumDetailsWorkingState.tabName = ""
mainFrame.minimumDetailsBankTabDropdownButton.labelText:SetText("Select Bank Tab")
mainFrame.minimumDetailsQuantityInput:SetText("100")
mainFrame:UpdateMinimumDetailsActionState(mainFrame.minimumDetailsSourceRow, mainFrame.minimumDetailsWorkingState)
assert.equal("Select a Bank Tab to continue.", mainFrame.minimumDetailsStatusText:GetText(), "minimum details should prompt for Bank Tab when an edit has no selected tab")
assert.equal(1, ((mainFrame.minimumDetailsStatusText.textColor or {})[1] or 0), "minimum details should turn the missing Bank Tab warning red")
assert.equal(0.35, ((mainFrame.minimumDetailsStatusText.textColor or {})[2] or 0), "minimum details should use the red warning tint when Bank Tab is missing")
mainFrame.minimumDetailsWorkingState.tabName = "Alchemy"
mainFrame.minimumDetailsBankTabDropdownButton.labelText:SetText("Alchemy")
mainFrame:UpdateMinimumDetailsActionState(mainFrame.minimumDetailsSourceRow, mainFrame.minimumDetailsWorkingState)
mainFrame.minimumDetailsUndoButton:GetScript("OnClick")(mainFrame.minimumDetailsUndoButton)
assert.truthy(not mainFrame.minimumDetailsModal:IsShown(), "undoing a newly staged minimum through the details modal should close the modal")
local undoneAddedDraftRow
for _, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 243734 then
        undoneAddedDraftRow = row
        break
    end
end
assert.truthy(undoneAddedDraftRow == nil, "undoing a newly staged minimum through the details modal should discard the staged row entirely")
