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

local function color_distance(left, right)
    left = left or {}
    right = right or {}
    local total = 0
    for index = 1, 3 do
        total = total + math.abs((left[index] or 0) - (right[index] or 0))
    end
    return total
end

_G.GBankManagerDB = {
    currentSnapshotId = "exports-modal",
    snapshots = {
        ["exports-modal"] = {
            items = {
                [1001] = {
                    itemID = 1001,
                    name = "Flask Alpha",
                    totalCount = 12,
                    craftedQuality = 3,
                    tabs = {
                        ["Raid Buffer"] = 2,
                        ["Freebiez"] = 10,
                    },
                },
                [2002] = {
                    itemID = 2002,
                    name = "Potion Beta",
                    totalCount = 0,
                    tabs = {},
                },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 5, scope = "TAB", tabName = "Raid Buffer", enabled = true },
        { itemID = 241323, itemName = "Flask of the Magisters", quantity = 3, scope = "TAB", tabName = "Raid Buffer", enabled = true, craftedQuality = 2, craftedQualityIcon = "|A:Professions-ChatIcon-Quality-Tier2:22:22|a" },
    },
    requests = {},
    auditLog = {},
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
assert.truthy(mainFrame.exportsPanel:IsShown(), "exports should expose a bottom action strip")
assert.same(mainFrame.tableViewportFrame, (mainFrame.exportsPanel.points[1] or {})[2], "exports buttons should sit below the table viewport")
assert.equal(nil, mainFrame.exportsPanel.backdrop, "exports should remove the ghost container box behind the action cards")
assert.equal(4, #(mainFrame.exportActionCards or {}), "exports should present four action cards for the supported export targets")
assert.equal("Auctionator*", ((mainFrame.exportActionCards or {})[1] or {}).titleText:GetText(), "exports should title the first action card for Auctionator with the quantity footnote marker")
assert.equal("TSM*", ((mainFrame.exportActionCards or {})[2] or {}).titleText:GetText(), "exports should title the second action card for TSM with the quantity footnote marker")
assert.equal("CSV", ((mainFrame.exportActionCards or {})[3] or {}).titleText:GetText(), "exports should title the third action card for CSV")
assert.equal("Shopping List", ((mainFrame.exportActionCards or {})[4] or {}).titleText:GetText(), "exports should title the fourth action card for the shopping list helper")
assert.truthy(type(((mainFrame.exportActionCards or {})[1] or {}).iconTexture) == "table", "exports action cards should expose an icon texture")
assert.truthy((((mainFrame.exportActionCards or {})[1] or {}).iconTexture or {}).texture ~= nil, "exports action cards should assign a real icon texture")
assert.equal("Generate Auctionator Shopping List.", (((mainFrame.exportActionCards or {})[1] or {}).descriptionText or {}):GetText(), "exports should explain what the Auctionator card generates")
assert.equal("Export Group for TradeSkillMaster.", (((mainFrame.exportActionCards or {})[2] or {}).descriptionText or {}):GetText(), "exports should explain what the TSM card generates")
assert.equal("Export to CSV.", (((mainFrame.exportActionCards or {})[3] or {}).descriptionText or {}):GetText(), "exports should explain the CSV card concisely")
assert.truthy(string.find((((mainFrame.exportActionCards or {})[4] or {}).descriptionText or {}):GetText() or "", "checklist", 1, true) ~= nil, "exports should explain that the shopping-list card opens a checklist helper")
assert.equal("* Does not provide Quantity in Export.", (mainFrame.exportsFootnoteText or {}):GetText(), "exports should show a shared footnote for Auctionator and TSM quantity limits")
assert.equal("Generate", mainFrame.exportPresetAuctionatorButton.labelText:GetText(), "exports should use a Generate action label on the Auctionator card")
assert.equal("Generate", mainFrame.exportPresetTsmButton.labelText:GetText(), "exports should use a Generate action label on the TSM card")
assert.equal("Generate", mainFrame.exportPresetSpreadsheetButton.labelText:GetText(), "exports should use a Generate action label on the CSV card")
assert.equal("Open List", mainFrame.exportManualShoppingListButton.labelText:GetText(), "exports should use an Open List action label on the manual card")
assert.equal("primary", mainFrame.exportPresetAuctionatorButton.gbmButtonVariant, "exports should keep Auctionator CTA styling consistent with the other action cards")
assert.equal("primary", mainFrame.exportPresetTsmButton.gbmButtonVariant, "exports should keep TSM CTA styling consistent with the other action cards")
assert.equal("primary", mainFrame.exportPresetSpreadsheetButton.gbmButtonVariant, "exports should keep CSV CTA styling consistent with the other action cards")
assert.equal("primary", mainFrame.exportManualShoppingListButton.gbmButtonVariant, "exports should keep the manual shopping-list CTA styling consistent with the other action cards")
assert.truthy(color_distance(((mainFrame.exportPresetAuctionatorButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.exportActionCards[1].gbmArt or {}).innerFill or {}).color) >= 0.10, "exports CTAs should contrast from the export action cards")
assert.truthy(((mainFrame.exportActionCards[2].points[1] or {})[4] or 0) >= 16, "exports action cards should leave a little more spacing between cards")
assert.truthy((mainFrame.exportActionCards[1].descriptionText.width or 0) <= 144, "exports card descriptions should keep a narrower wrap width to avoid crowding the CTA")
assert.truthy((mainFrame.exportPresetAuctionatorButton.points[1] or {})[5] >= 16, "exports CTAs should sit a little higher within the cards for cleaner spacing")
assert.truthy((mainFrame.exportsFootnoteText.points[1] or {})[2] == mainFrame.exportsPanel, "exports should anchor the quantity footnote inside the transparent action area")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "exports table should start with Item ID")
assert.equal("Tier", mainFrame.tableHeaderLabels[2]:GetText(), "exports table should label the crafted-quality column as Tier")
assert.equal("Item Name", mainFrame.tableHeaderLabels[3]:GetText(), "exports table should show Item Name")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "exports table should show Bank Tab")
assert.equal("Min Qty", mainFrame.tableHeaderLabels[5]:GetText(), "exports table should show the minimum-rule quantity")
assert.equal("Qty In Stock", mainFrame.tableHeaderLabels[6]:GetText(), "exports table should show current in-stock quantity")
assert.equal("Qty To Buy", mainFrame.tableHeaderLabels[7]:GetText(), "exports table should show the amount still needed")
assert.equal("Excess Qty", mainFrame.tableHeaderLabels[8]:GetText(), "exports table should show the quantity stocked outside the target tab")
assert.truthy((mainFrame.tableColumnLayout[8].width or 0) >= 96, "exports should give Excess Qty enough width for the numeric value")
assert.equal(10, mainFrame.tableRowsData[1].excessQty, "exports rows should show the quantity stocked in another tab as excess quantity")
assert.equal("10", tostring(mainFrame.tableRowsData[1].excessQtyLabel or ""), "exports rows should keep only the excess count in the table cell text")
assert.equal("common-icon-forwardarrow", tostring(mainFrame.tableRowsData[1].excessQtyIconAtlas or ""), "exports rows should carry a drill-in icon atlas for the shared table renderer")
local excessCellLabel = (((mainFrame.tableRows or {})[1] or {}).columns or {})[8]
local excessCellIcon = (((mainFrame.tableRows or {})[1] or {}).columnIcons or {})[8]
local excessIconPoint = (((excessCellIcon or {}).points or {})[1] or {})
assert.equal("10", excessCellLabel and excessCellLabel:GetText() or "", "exports should render the excess count without the old drill-in text")
assert.equal("common-icon-forwardarrow", tostring((excessCellIcon or {}).atlas or ""), "exports should render a website-style drill-in icon in the excess cell")
assert.equal("TOPRIGHT", excessIconPoint[1], "exports should right-align the drill-in icon within the excess cell")
assert.truthy((excessIconPoint[4] or 0) >= 90, "exports should keep the drill-in icon anchored near the far-right edge of the excess cell")
assert.equal("Professions-ChatIcon-Quality-Tier3", mainFrame.tableRowsData[1].itemTierIconAtlas, "exports rows should show the crafted-quality icon instead of a raw tier number")
assert.equal("Professions-ChatIcon-Quality-12-Tier1", mainFrame.tableRowsData[2].itemTierIconAtlas, "exports rows should trust bundled crafted-tier metadata over stale saved row quality when a lower two-rank item has bad local data")
assert.truthy((mainFrame.tableColumnLayout[2].width or 0) >= 42, "exports should keep the Tier column visible while making room for the extra quantity columns")
assert.truthy(not mainFrame.exportPresetCustomButton:IsShown(), "exports should remove the custom option")
assert.truthy(mainFrame.exportPresetTsmButton:IsShown(), "exports should expose a TSM item-id import option when supported")
mainFrame:OpenExportStockedElsewhereModal(mainFrame.tableRowsData[1])
assert.truthy(mainFrame.exportStockedElsewhereModal:IsShown(), "clicking stocked elsewhere should open the tab quantity modal")
assert.equal("modal-sheet", mainFrame.exportStockedElsewhereModal.gbmSurfaceVariant, "stocked elsewhere details should use the cleaner floating-sheet modal surface")
assert.truthy(string.find(mainFrame.exportStockedElsewhereText:GetText() or "", "Total excess outside Raid Buffer: 10", 1, true) ~= nil, "stocked elsewhere modal should summarize the total excess outside the assigned bank tab")
assert.truthy(string.find(mainFrame.exportStockedElsewhereText:GetText() or "", "Freebiez: 10", 1, true) ~= nil, "stocked elsewhere modal should list other tabs and quantities")
mainFrame.exportStockedElsewhereCloseButton:GetScript("OnClick")(mainFrame.exportStockedElsewhereCloseButton)

mainFrame.exportPresetAuctionatorButton:GetScript("OnClick")(mainFrame.exportPresetAuctionatorButton)
assert.truthy(mainFrame.exportModal:IsShown(), "auctionator export should open a modal")
assert.equal("modal-sheet", mainFrame.exportModal.gbmSurfaceVariant, "exports should use the cleaner floating-sheet modal surface")
assert.truthy(mainFrame.exportModalBuyAllButton:IsShown(), "auctionator export should ask whether to buy all")
assert.truthy(mainFrame.exportModalMissingOnlyButton:IsShown(), "auctionator export should offer skipping items available in another tab")
assert.equal("Not In Guild Bank", mainFrame.exportModalMissingOnlyButton.labelText:GetText(), "auctionator export should label the missing-only path the same way as the exports table")
mainFrame.exportModalMissingOnlyButton:GetScript("OnClick")(mainFrame.exportModalMissingOnlyButton)
assert.equal("GBankManager^Flask of the Magisters", mainFrame.exportModalOutputInput:GetText(), "auctionator missing-only output should use the current import format and exclude stocked-elsewhere rows")

mainFrame.exportPresetSpreadsheetButton:GetScript("OnClick")(mainFrame.exportPresetSpreadsheetButton)
assert.truthy(mainFrame.exportModalOutputInput:IsShown(), "csv export should show the output box immediately")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText() or "", "Item ID,Tier,Item Name,Bank Tab,Min Qty,Qty In Stock,Qty To Buy,Excess Qty", 1, true) ~= nil, "csv export should include the visible table header row")
assert.truthy(type(mainFrame.exportModalOutputInput.EditBox) == "table", "export modal should use a real scrollable edit box for manual selection")
assert.truthy(type(mainFrame.exportModalOutputInput.EditBox:GetScript("OnTextChanged")) == "function", "export modal should bind text-change sizing on the embedded edit box")
assert.equal(nil, mainFrame.exportModalScrollFrame.backdrop, "export modal should remove the nested scroll-frame box around the output")
assert.equal(nil, mainFrame.exportModalOutputInput.backdrop, "export modal should remove the nested output-input box around the export text")
assert.truthy(not mainFrame.exportModalCopyButton:IsShown(), "export modal should remove the copy button because manual Ctrl+C is the supported path")
mainFrame.exportModalSelectAllButton:GetScript("OnClick")(mainFrame.exportModalSelectAllButton)
assert.truthy(mainFrame.exportModalOutputInput:HasFocus(), "select all should focus the scrollable edit box")
assert.equal(0, mainFrame.exportModalOutputInput.cursorPosition, "select all should rewind the cursor before highlighting")
assert.equal(0, mainFrame.exportModalOutputInput.highlightStart, "select all should highlight the full export output")
assert.equal(-1, mainFrame.exportModalOutputInput.highlightEnd, "select all should extend the highlight through the entire export output")
assert.equal("Selected all output. Press Ctrl+C to copy.", mainFrame.exportModalStatusText:GetText(), "select all should give the user visible copy guidance")

mainFrame.exportPresetTsmButton:GetScript("OnClick")(mainFrame.exportPresetTsmButton)
assert.truthy(mainFrame.exportModalBuyAllButton:IsShown(), "tsm export should use the same all-or-missing choice modal")
mainFrame.exportModalBuyAllButton:GetScript("OnClick")(mainFrame.exportModalBuyAllButton)
assert.equal("1001,241323", mainFrame.exportModalOutputInput:GetText(), "tsm export should build a comma-delimited item id import string")
assert.truthy(type(mainFrame.exportModalScrollFrame) == "table", "export modal should expose a scroll frame for long output")
assert.equal(mainFrame.exportModalOutputInput.EditBox, mainFrame.exportModalScrollFrame.scrollChild, "export modal should attach its edit box as the scroll child")
assert.equal(mainFrame.exportModalOutputInput.EditBox, mainFrame.exportModalScrollChild, "export modal should expose the edit box as the scroll child reference")
assert.truthy(mainFrame.exportModalScrollFrame.mouseWheelEnabled == true, "export modal should enable mouse-wheel scrolling")
assert.truthy(type(mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")) == "function", "export modal should wire a mouse-wheel scrolling handler")
assert.truthy(mainFrame.exportManualShoppingListButton ~= nil, "exports should expose the manual shopping-list helper button")
mainFrame.exportManualShoppingListButton:GetScript("OnClick")(mainFrame.exportManualShoppingListButton)
assert.truthy(mainFrame.exportManualShoppingListModal:IsShown(), "manual shopping list should open in a separate modal")
assert.truthy(mainFrame.exportManualShoppingListModal.mouseEnabled == true, "manual shopping list modal should be draggable")
assert.equal("LeftButton", (mainFrame.exportManualShoppingListModal.dragButtons or {})[1], "manual shopping list modal should register left-button dragging")
assert.equal(_G.UIParent, mainFrame.exportManualShoppingListModal.parent, "manual shopping list should live on UIParent so it can stay open independently of the shell")
assert.equal("Check off purchases as you work through the list.\nDoes not sync back to addon.", mainFrame.exportManualShoppingListHint:GetText(), "manual shopping list should line-break the local-only note for readability")
assert.truthy(#(mainFrame.exportManualShoppingListRows or {}) >= 2, "manual shopping list should build one checklist row per purchase row")
local manualShoppingRow = (mainFrame.exportManualShoppingListRows or {})[1]
assert.equal("UICheckButtonTemplate", (manualShoppingRow.checkButton or {}).template, "manual shopping list should use a clearer built-in checkbox control")
assert.truthy(string.find(manualShoppingRow.itemText:GetText() or "", "|A:", 1, true) ~= nil, "manual shopping list rows should render the crafted-quality icon inline")
assert.truthy(string.find(manualShoppingRow.itemText:GetText() or "", "T3", 1, true) == nil, "manual shopping list rows should stop falling back to raw T-tier text")
local missingSnapshotRow = (mainFrame.exportManualShoppingListRows or {})[2]
assert.truthy(string.find(missingSnapshotRow.itemText:GetText() or "", "Professions%-ChatIcon%-Quality%-12%-Tier1", 1) ~= nil, "manual shopping list rows should trust bundled lower-rank crafted-tier metadata over stale saved row quality when no live stock snapshot exists")
assert.truthy(manualShoppingRow.checkButton:GetChecked() ~= true, "manual shopping rows should start unchecked")
manualShoppingRow.checkButton:GetScript("OnClick")(manualShoppingRow.checkButton)
assert.truthy(manualShoppingRow.checkButton:GetChecked() == true, "checking a manual shopping row should toggle the built-in checkbox state")
assert.truthy(manualShoppingRow.strikeLine:IsShown(), "checking a manual shopping list row should strike it through for the current session")
mainFrame:SelectView("DASHBOARD")
assert.truthy(mainFrame.exportManualShoppingListModal:IsShown(), "manual shopping list should stay open when switching tabs")
local sawQtyToBuyText = false
for _, rowFrame in ipairs(mainFrame.exportManualShoppingListRows or {}) do
    if rowFrame:IsShown() and string.find(rowFrame.itemText:GetText() or "", "x3", 1, true) ~= nil then
        sawQtyToBuyText = true
        break
    end
end
assert.truthy(sawQtyToBuyText, "manual shopping list should show the purchase quantity from Qty To Buy")
mainFrame.exportManualShoppingListModal:ClearAllPoints()
mainFrame.exportManualShoppingListModal:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 40, -60)
mainFrame:PersistManualShoppingListPosition()
mainFrame.exportManualShoppingListModal:ClearAllPoints()
mainFrame:RestoreManualShoppingListPosition()
assert.equal(40, select(4, mainFrame.exportManualShoppingListModal:GetPoint(1)), "manual shopping list should restore its saved horizontal position")
assert.equal(-60, select(5, mainFrame.exportManualShoppingListModal:GetPoint(1)), "manual shopping list should restore its saved vertical position")
mainFrame.closeButton:GetScript("OnClick")(mainFrame.closeButton)
assert.truthy(mainFrame.exportManualShoppingListModal:IsShown(), "manual shopping list should stay visible when the main addon shell closes")
assert.truthy(not mainFrame.tableScrollBar:IsShown(), "exports should keep the shared table scrollbar hidden when the export rows fit without scrolling")
