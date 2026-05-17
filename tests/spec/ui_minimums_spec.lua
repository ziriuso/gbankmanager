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
                    totalCount = 5,
                    tabs = {
                        Alchemy = 4,
                        ["Gems and Enchants"] = 1,
                    },
                },
                [8008] = {
                    itemID = 8008,
                    name = "Leyline Residue",
                    totalCount = 2,
                    tabs = {
                        Reagents = 2,
                    },
                },
            },
            itemRows = {
                {
                    itemID = 7007,
                    name = "Algari Mana Oil",
                    quantity = 4,
                    tabName = "Alchemy",
                    rowKey = "7007|TAB|Alchemy",
                },
                {
                    itemID = 7007,
                    name = "Algari Mana Oil",
                    quantity = 1,
                    tabName = "Gems and Enchants",
                    rowKey = "7007|TAB|Gems and Enchants",
                },
                {
                    itemID = 8008,
                    name = "Leyline Residue",
                    quantity = 2,
                    tabName = "Reagents",
                    rowKey = "8008|TAB|Reagents",
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
assert.truthy(mainFrame.tableFilterFrame:IsShown(), "minimums should reuse the shared table filter row")
assert.truthy(not mainFrame.minimumSearchLabel:IsShown(), "minimums should remove the old bottom search label in favor of shared table filters")
assert.truthy(not mainFrame.minimumSearchInput:IsShown(), "minimums should remove the old bottom search box in favor of shared table filters")
assert.equal(3, #mainFrame.tableRowsData, "minimums Show All should render one bank row per tab for shared items plus other bank rows")
assert.equal("Alchemy", mainFrame.tableRowsData[1].bankTab, "minimums Show All should preserve the first tab name")
assert.equal("4", mainFrame.tableRowsData[1].current, "minimums Show All should preserve the first per-tab quantity")
assert.equal("Gems and Enchants", mainFrame.tableRowsData[2].bankTab, "minimums Show All should preserve the second tab name")
assert.equal("1", mainFrame.tableRowsData[2].current, "minimums Show All should preserve the second per-tab quantity")
mainFrame.tableFilterInputs[4]:SetText("Reagents")
mainFrame.tableFilterInputs[4]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[4])
assert.equal(1, #mainFrame.tableRowsData, "minimums shared table filters should search by Bank Tab")
assert.equal("Reagents", mainFrame.tableRowsData[1].bankTab, "minimums shared Bank Tab filter should keep the matching row")
mainFrame.tableFilterInputs[4]:SetText("")
mainFrame.tableFilterInputs[4]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[4])
mainFrame.tableFilterInputs[1]:SetText("8008")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal(1, #mainFrame.tableRowsData, "minimums shared table filters should search by Item ID")
assert.equal("8008", mainFrame.tableRowsData[1].itemID, "minimums shared Item ID filter should keep the matching row")
mainFrame.tableFilterInputs[1]:SetText("missing")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal("No minimum rows match the current search and filters.", mainFrame.minimumEmptyStateText:GetText(), "minimums empty state should reflect shared table filters")
mainFrame.tableFilterInputs[1]:SetText("")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal("Save All", mainFrame.minimumSaveButton.labelText:GetText(), "minimums view should keep the top-level save action label")
assert.equal(7, #mainFrame.tableColumnLayout, "minimums view should fully remove the deprecated restock-source column")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "minimums should share the preferred table layout with inventory")
assert.equal("Tier", mainFrame.tableHeaderLabels[2]:GetText(), "minimums should share the preferred tier column with inventory")
assert.equal("Item", mainFrame.tableHeaderLabels[3]:GetText(), "minimums should share the preferred item column with inventory")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "minimums should share the preferred bank tab column with inventory")
assert.equal("Current", mainFrame.tableHeaderLabels[5]:GetText(), "minimums should share the preferred current column with inventory")
assert.equal("Restock", mainFrame.tableHeaderLabels[6]:GetText(), "minimums should share the preferred restock column with inventory")
assert.equal("Minimum", mainFrame.tableHeaderLabels[7]:GetText(), "minimums view should end the table at the minimum column")
assert.truthy(mainFrame.tableHeaderLabels[8] == nil or mainFrame.tableHeaderLabels[8].shown == false, "minimums view should not render a ghost eighth header")
assert.truthy((mainFrame.tableViewportHeight or 0) > 0, "minimums table should keep a positive shared table height")
assert.truthy((mainFrame.tableViewportHeight or 0) <= (mainFrame.defaultTableViewportHeight or 364), "minimums table should clamp inside the shared shell instead of pushing footer actions offscreen")
assert.truthy((mainFrame.minimumsPanel:GetHeight() or 0) <= 72, "minimums footer should be a compact action strip instead of a boxed editor panel")
assert.truthy(mainFrame.minimumsPanel.transparentActions == true, "minimums footer should remove the old boxed panel styling")
assert.equal(nil, mainFrame.minimumsPanel.backdrop, "minimums action strip should not draw a boxed backdrop")
assert.truthy(mainFrame.minimumNewButton:IsShown(), "minimums action strip should keep Add visible")
assert.truthy(mainFrame.minimumSaveButton:IsShown(), "minimums action strip should keep Save All visible")
assert.truthy(mainFrame.minimumEnabledOnlyButton:IsShown(), "minimums action strip should keep Enabled Only visible")
assert.truthy(mainFrame.minimumShowAllButton:IsShown(), "minimums action strip should keep Show All visible")
assert.truthy(((mainFrame.minimumNewButton.points[1] or {})[5] or 0) >= 30, "minimums left action buttons should sit raised from the bottom edge")
assert.truthy(((mainFrame.minimumEnabledOnlyButton.points[1] or {})[5] or 0) >= 30, "minimums right action buttons should sit raised from the bottom edge")
assert.truthy(not mainFrame.minimumEditorPanel:IsShown(), "minimums action strip should not show the old footer editor box")

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
assert.equal("Professions-ChatIcon-Quality-Tier2", mainFrame.minimumAddSelectedItemQualityIcon.atlas, "minimum add modal should keep the selected duplicate-name tier after delayed input callbacks")
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
assert.truthy(not mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "existing minimum row click should lock Bank Tab instead of showing an editable selector")
assert.truthy(mainFrame.minimumDetailsBankTabValueText:IsShown(), "existing minimum row click should show the read-only Bank Tab value")
assert.equal("Alchemy", mainFrame.minimumDetailsBankTabValueText:GetText(), "existing minimum row click should auto-populate the saved Bank Tab")
assert.truthy(not mainFrame.minimumDetailsBankTabDropdownPanel:IsShown(), "existing minimum row click should keep the Bank Tab options closed")

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
assert.equal("Professions-ChatIcon-Quality-Tier2", mainFrame.minimumDetailsItemQualityIcon.atlas, "minimum details modal should normalize two-rank backfill icons to the shared visible icon family")
assert.equal("Tier 2", mainFrame.minimumDetailsItemQualityText:GetText(), "minimum details modal should show crafted-tier text alongside the crafted-tier icon")
assert.equal("Alchemy", mainFrame.minimumDetailsBankTabValueText:GetText(), "minimum details modal should show the existing saved row Bank Tab as read-only text")
assert.truthy(not mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "minimum details modal should not expose an editable Bank Tab selector for existing saved rows")

_G.GBankManagerDB.minimums = {
    {
        itemID = 7007,
        itemName = "Algari Mana Oil",
        quantity = 250,
        scope = "TAB",
        enabled = true,
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()
local legacyExistingRow = mainFrame.tableRowsData[1]
assert.equal("Alchemy", legacyExistingRow.bankTab, "fixture should expose a primary bank tab for legacy saved minimums without tabName")
mainFrame:HandleTableRowClick(legacyExistingRow)
assert.truthy(mainFrame.minimumDetailsBankTabValueText:IsShown(), "legacy existing minimum edit should show a read-only Bank Tab value")
assert.equal("Alchemy", mainFrame.minimumDetailsBankTabValueText:GetText(), "legacy existing minimum edit should auto-populate Bank Tab from the table row")
assert.truthy(not mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "legacy existing minimum edit should not allow Bank Tab edits")

_G.GBankManagerDB.minimums = {
    {
        itemID = 8008,
        itemName = "Leyline Residue",
        quantity = 120,
        scope = "TAB",
        tabName = "Reagents",
        enabled = true,
    },
    {
        itemID = 7007,
        itemName = "Algari Mana Oil",
        quantity = 250,
        scope = "GLOBAL",
        enabled = true,
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()
local globalMinimumRow = mainFrame.tableRowsData[1]
assert.equal("7007", globalMinimumRow.itemID, "global minimum rows should sort to the top so missing bank tabs are hard to miss")
assert.equal("GLOBAL", globalMinimumRow.bankTab, "global minimum rows should keep the unresolved GLOBAL bank-tab marker visible")
assert.truthy(globalMinimumRow.needsBankTab == true, "global minimum rows should be marked as needing a bank tab before save")
assert.equal("orange", mainFrame.tableRows[1].minimumDraftTint, "global minimum rows should highlight in orange")
assert.equal(0.62, ((mainFrame.tableRows[1].minimumDraftBackground or {}).color or {})[1] or 0, "global minimum rows should use the orange warning overlay")
mainFrame:HandleTableRowClick(globalMinimumRow)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "global minimum rows should still open in the shared details modal")
assert.truthy(mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "global minimum rows should require picking a bank tab before save")
assert.truthy(not mainFrame.minimumDetailsBankTabValueText:IsShown(), "global minimum rows should not present the unresolved tab as read-only text")
assert.equal("Select a Bank Tab to continue.", mainFrame.minimumDetailsStatusText:GetText(), "global minimum rows should explain that a bank tab must be chosen")
mainFrame:HideMinimumDetailsModal()
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.truthy(mainFrame.minimumDetailsModal:IsShown(), "saving with unresolved global minimum rows should reopen the details modal")
assert.equal("Bank Tab must be set on Orange Rows.", mainFrame.minimumDetailsStatusText:GetText(), "saving with unresolved global minimum rows should show the required error message")

_G.GBankManagerDB.minimums = {
    {
        itemID = 8008,
        itemName = "Leyline Residue",
        quantity = 120,
        scope = "TAB",
        tabName = "Reagents",
        enabled = true,
    },
    {
        itemID = 241322,
        itemName = "Flask of the Magisters",
        quantity = 10,
        scope = "TAB",
        tabName = "Reagents",
        enabled = true,
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    },
}
_G.GBankManagerDB.requests = {
    {
        requestId = "auto-heal-approved-request",
        requester = "Zirleficent",
        requesterCharacterKey = "Stormrage-Zirleficent",
        itemID = 243734,
        itemName = "Thalassian Phoenix Oil",
        quantity = 100,
        approval = "APPROVED",
        fulfillment = "OPEN",
        tabName = "Alchemy",
        approvedBankTab = "Alchemy",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    },
    {
        requestId = "auto-heal-from-existing-minimum",
        requester = "Zirleficent",
        requesterCharacterKey = "Stormrage-Zirleficent",
        itemID = 241322,
        itemName = "Flask of the Magisters",
        quantity = 10,
        approval = "APPROVED",
        fulfillment = "OPEN",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    },
    {
        requestId = "legacy-approved-request",
        requester = "Zirleficent",
        requesterCharacterKey = "Stormrage-Zirleficent",
        itemID = 241324,
        itemName = "Flask of the Blood Knights",
        quantity = 100,
        approval = "APPROVED",
        fulfillment = "OPEN",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    },
}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()
assert.equal("243734|TAB|Alchemy", _G.GBankManagerDB.requests[1].minimumRuleKey, "approved requests with a bank tab should self-heal their missing minimum binding automatically")
assert.equal("Alchemy", _G.GBankManagerDB.requests[1].tabName, "approved requests that self-heal should preserve their chosen bank tab")
assert.equal("241322|TAB|Reagents", _G.GBankManagerDB.requests[2].minimumRuleKey, "approved requests with exactly one matching existing minimum should self-heal to that minimum even if the request lost its bank tab")
assert.equal("Reagents", _G.GBankManagerDB.requests[2].tabName, "approved requests that self-heal from an existing minimum should inherit the existing minimum bank tab")
local magistersGlobalCount = 0
for _, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 241322 and tostring(row.bankTab or "") == "GLOBAL" then
        magistersGlobalCount = magistersGlobalCount + 1
    end
end
assert.equal(0, magistersGlobalCount, "approved requests that can self-heal from an existing minimum should not surface a duplicate GLOBAL repair row")
local legacyRequestRow = mainFrame.tableRowsData[1]
assert.equal("241324", legacyRequestRow.itemID, "approved requests without a bound minimum should surface at the top of Minimums for repair")
assert.equal("GLOBAL", legacyRequestRow.bankTab, "approved requests without a chosen bank tab should surface as GLOBAL in Minimums")
assert.truthy(legacyRequestRow.needsBankTab == true, "approved requests without a chosen bank tab should require repair before save")
assert.equal("orange", mainFrame.tableRows[1].minimumDraftTint, "approved requests without a chosen bank tab should highlight orange in Minimums")
mainFrame:HandleTableRowClick(legacyRequestRow)
assert.truthy(mainFrame.minimumDetailsBankTabDropdownButton:IsShown(), "legacy approved requests should open with an editable Bank Tab picker")
mainFrame.minimumDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownButton)
mainFrame.minimumDetailsBankTabDropdownOptions[1]:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownOptions[1])
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)
local repairedLegacyDraftCount = 0
local repairedLegacyGlobalCount = 0
for _, row in ipairs(mainFrame.tableRowsData or {}) do
    if tonumber(row.itemID) == 241324 and tostring(row.bankTab or "") == "Alchemy" then
        repairedLegacyDraftCount = repairedLegacyDraftCount + 1
    end
    if tonumber(row.itemID) == 241324 and tostring(row.bankTab or "") == "GLOBAL" then
        repairedLegacyGlobalCount = repairedLegacyGlobalCount + 1
    end
end
assert.equal(1, repairedLegacyDraftCount, "repairing a legacy approved request should stage exactly one resolved draft row")
assert.equal(0, repairedLegacyGlobalCount, "repairing a legacy approved request should hide the orphan GLOBAL row while the repair draft is staged")
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal("TAB", _G.GBankManagerDB.minimums[4].scope, "saving a repaired legacy approved request should create a tab-scoped minimum")
assert.equal("Alchemy", _G.GBankManagerDB.minimums[4].tabName, "saving a repaired legacy approved request should persist the chosen bank tab on the minimum")
assert.equal("241324|TAB|Alchemy", _G.GBankManagerDB.requests[3].minimumRuleKey, "saving a repaired legacy approved request should bind the request back to its minimum rule")
assert.equal("Alchemy", _G.GBankManagerDB.requests[3].tabName, "saving a repaired legacy approved request should persist the chosen bank tab on the request")

_G.GBankManagerDB.minimums = {}
_G.GBankManagerDB.requests = {}
mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:RefreshView()

assert.truthy(mainFrame.minimumShowAllRows == true, "minimums should default to Show All rows")
assert.truthy(mainFrame.minimumShowAllButton.filterActive == true, "minimums should highlight Show All when Show All rows are active")
assert.truthy(mainFrame.minimumEnabledOnlyButton.filterActive ~= true, "minimums should leave Enabled Only inactive while Show All rows are active")
assert.truthy((mainFrame.minimumShowAllButton.backdropBorderColor or {})[1] == 0.85, "minimums should give the active filter a stronger glow")
assert.equal("", mainFrame.minimumEditorStateText:GetText() or "", "minimums footer should not show the old centered-modal hint text")
assert.truthy(not mainFrame.minimumEditorStateText:IsShown(), "minimums footer should hide the old centered-modal hint text")
mainFrame.minimumEnabledOnlyButton:GetScript("OnClick")(mainFrame.minimumEnabledOnlyButton)
assert.truthy(mainFrame.minimumShowAllRows == false, "minimums Enabled Only button should switch the table out of Show All mode")
assert.truthy(mainFrame.minimumEnabledOnlyButton.filterActive == true, "minimums should highlight Enabled Only when selected")
assert.truthy((mainFrame.minimumEnabledOnlyButton.backdropBorderColor or {})[1] == 0.85, "minimums should move the stronger glow to Enabled Only when selected")
mainFrame.minimumShowAllButton:GetScript("OnClick")(mainFrame.minimumShowAllButton)
assert.truthy(mainFrame.minimumShowAllRows == true, "minimums Show All button should restore Show All mode")
assert.truthy(mainFrame.minimumShowAllButton.filterActive == true, "minimums should re-highlight Show All after switching back")

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
