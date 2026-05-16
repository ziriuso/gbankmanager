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

_G.GBankManagerDB = _G.GBankManagerDB or {}
_G.GBankManagerDB.ui = _G.GBankManagerDB.ui or {}
_G.GBankManagerDB.ui.minimumItemCatalog = {
    {
        itemID = 990001,
        name = "Test Crafted Widget",
        craftedQuality = 5,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
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
}
_G.GBankManagerDB.requests = {
    {
        requestId = "req-1",
        requester = "OfficerOne-Stormrage",
        itemName = "Raid Flask",
        quantity = 5,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "Raid night",
        createdAt = 100,
    },
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("REQUESTS")
assert.equal("REQUESTS", mainFrame.activeView, "requests tab should be selectable")
assert.truthy(mainFrame.requestCreatePanel:IsShown(), "request create controls should show in the requests view")
assert.truthy(mainFrame.requestActionsPanel:IsShown(), "officer request actions should show in the full requests view")
assert.same(mainFrame.requestCreatePanel, (mainFrame.tableHeaderFrame.points[1] or {})[2], "requests view should anchor the shared table directly beneath the create panel")
assert.truthy(mainFrame.tableViewportFrame:IsShown(), "requests view should show the shared table viewport")
assert.truthy((mainFrame.requestCreatePanel:GetHeight() or 0) >= 190, "requests view should leave room for bundled item search matches")
assert.equal("Search Item ID", mainFrame.requestCreateItemIDLabel:GetText(), "requests view should clearly label the item-id search box")
assert.equal("Search Item Name", mainFrame.requestCreateItemNameLabel:GetText(), "requests view should clearly label the item-name search box")
assert.equal("Selected Item", mainFrame.requestCreateSelectedItemLabel:GetText(), "requests view should clearly label the selected item display")
assert.truthy(mainFrame.requestCreateButton.enabled == false, "requests view should keep Create disabled until a catalog item is selected")

local originalGetRequestSearchSnapshot = mainFrame.GetRequestSearchSnapshot
local requestSearchSnapshotCalls = 0
function mainFrame:GetRequestSearchSnapshot()
    requestSearchSnapshotCalls = requestSearchSnapshotCalls + 1
    return originalGetRequestSearchSnapshot(self)
end

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestSearchSession = nil
mainFrame.requestCreateItemNameInput:SetText("f")
assert.equal(0, mainFrame.requestCreateSearchSelector.resultsDataProvider:GetSize(), "requests view should not activate name search before two typed characters")
assert.truthy(not mainFrame.requestCreateResultsPanel:IsShown(), "requests view should keep the results list hidden before two typed characters")
mainFrame.requestCreateItemNameInput:SetText("fl")
assert.truthy((mainFrame.requestCreateSearchSelector.resultsDataProvider:GetSize() or 0) > 0, "requests view should activate name search once two characters are typed")
mainFrame.requestCreateItemNameInput:SetText("fla")
assert.equal(1, requestSearchSnapshotCalls, "requests view should build the shared search session once and reuse it across follow-up name queries")
mainFrame.GetRequestSearchSnapshot = originalGetRequestSearchSnapshot
mainFrame.requestCreateSearchSelector:ClearSelection()

mainFrame.requestCreateItemNameInput:SetText("Test Crafted ")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.equal("Test Crafted ", mainFrame.requestCreateItemNameInput:GetText(), "requests view should not overwrite an in-progress partial name search when whitespace is typed")
assert.equal("No item selected.", mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should wait for explicit selection on partial name matches")
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should show matches for a partial name search")
mainFrame.requestCreateMatchButtons[1]:GetScript("OnClick")(mainFrame.requestCreateMatchButtons[1])

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateItemNameInput:SetText("flask of")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should show a scrollable result panel for broad token queries")
assert.truthy(type(mainFrame.requestCreateSearchSelector.resultsScrollBox) == "table", "requests selector should expose a virtualized results scroll box")
assert.truthy(type(mainFrame.requestCreateSearchSelector.resultsDataProvider) == "table", "requests selector should expose a results data provider")
assert.truthy((mainFrame.requestCreateSearchSelector.resultsDataProvider:GetSize() or 0) > 0, "requests selector should populate the results data provider for broad searches")
assert.truthy((mainFrame.requestCreateSearchSelector.resultsScrollFrame or {}).scrollChild ~= nil, "requests view should wire a scroll child for result rows")
local requestBroadResultRow = (mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}
assert.truthy(string.find((requestBroadResultRow.itemText or {}):GetText() or "", tostring(((requestBroadResultRow.resolvedItem or {}).itemID or "")), 1, true) ~= nil, "request result rows should show the item id inline")
assert.truthy(((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon ~= nil, "request result rows should expose a crafting quality icon region")

mainFrame.requestCreateItemIDInput:SetText("990001")
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
assert.equal("990001", mainFrame.requestCreateItemIDInput:GetText(), "requests view should resolve catalog items by item id")
assert.equal("Test Crafted Widget", mainFrame.requestCreateItemNameInput:GetText(), "requests view should populate catalog item names after resolution")
assert.equal("Test Crafted Widget", mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should show the selected item name after resolution")
assert.equal("Professions-ChatIcon-Quality-Tier5", mainFrame.requestCreateSelectedItemQualityIcon.atlas, "requests view should show the selected item crafting quality icon when available")
assert.truthy(mainFrame.requestCreateButton.enabled ~= false, "requests view should enable Create after a catalog item is selected")

mainFrame.requestCreateItemNameInput:SetText("flask of")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.equal("", mainFrame.requestCreateItemIDInput:GetText(), "requests view should clear the stale item-id field when a broader name search invalidates the prior selection")
assert.equal("No item selected.", mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should clear the selected item display when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should reopen the matches panel when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.requestCreateSearchSelector.resultsScrollController ~= nil, "requests view should use the shared shell scroll controller for result rows")
assert.truthy(mainFrame.requestCreateSearchSelector.resultsScrollBar ~= nil, "requests view should expose the shared shell scrollbar for result rows")
assert.truthy(mainFrame.requestCreateButton.enabled == false, "requests view should disable Create again when a broader search clears the confirmed selection")

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateItemNameInput:SetText("test variant flask")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should keep duplicate-name quality variants in the results list")
assert.truthy(string.find((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "[T5]", 1, true) ~= nil, "requests result rows should show the higher crafted tier first for duplicate-name variants")
assert.truthy(string.find((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).itemText or {}):GetText() or "", "[T2]", 1, true) ~= nil, "requests result rows should keep lower crafted tiers visible as separate entries")
assert.equal("Professions-ChatIcon-Quality-Tier5", (((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}).atlas, "requests result rows should show the crafted quality icon for the higher-tier entry")
local selectedRequestVariantRow = mainFrame.requestCreateMatchButtons[2]
local selectedRequestVariantItem = selectedRequestVariantRow.resolvedItem
mainFrame.requestCreateMatchButtons[2]:GetScript("OnClick")(mainFrame.requestCreateMatchButtons[2])
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
assert.equal(tostring((selectedRequestVariantItem or {}).itemID or ""), mainFrame.requestCreateItemIDInput:GetText(), "requests view should preserve the explicitly selected duplicate-name item id after delayed input callbacks")
assert.equal(tostring((selectedRequestVariantItem or {}).name or (selectedRequestVariantItem or {}).itemName or ""), mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should keep the selected item display after delayed input callbacks")
assert.equal((selectedRequestVariantItem or {}).craftedQualityIcon, mainFrame.requestCreateSelectedItemQualityIcon.atlas, "requests view should keep the selected duplicate-name tier after delayed input callbacks")
assert.truthy(not mainFrame.requestCreateResultsPanel:IsShown(), "requests view should keep the matches panel hidden after a duplicate-name selection survives delayed input callbacks")
assert.truthy(mainFrame.requestCreateButton.enabled ~= false, "requests view should keep Create enabled after delayed callbacks on a valid selection")

mainFrame.requestCreateItemIDInput:SetText("990001")
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateQuantityInput:SetText("4")
mainFrame.requestCreateNoteInput:SetText("Need four")
local requestWithoutSelection = mainFrame:CreateRequestFromEditor()
assert.truthy(requestWithoutSelection == nil, "requests view should reject creating a request from raw text fields without a confirmed selected catalog item")
assert.equal("Select an item from the catalog first.", mainFrame.requestCreateStatusText:GetText(), "requests view should explain that catalog selection is required before creating a request")
mainFrame.requestCreateItemIDInput:SetText("990001")
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
assert.truthy(mainFrame.requestCreateButton.enabled ~= false, "requests view should re-enable Create after a valid catalog item is reselected")
assert.truthy(mainFrame.requestCreateStatusText:GetText() ~= "Select an item from the catalog first.", "requests view should clear the stale selection error after a valid catalog item is reselected")

mainFrame:ShowRequestOnly()
assert.equal("REQUESTS", mainFrame.activeView, "request-only mode should stay on the requests view")
assert.truthy(mainFrame.requestOnlyMode == true, "request-only mode should be tracked on the shell")
assert.truthy(mainFrame.requestCreatePanel:IsShown(), "request-only mode should still show the request entry panel")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request-only mode should hide officer action controls")
assert.truthy(not mainFrame.sidebar:IsShown(), "request-only mode should hide the sidebar")
assert.same(mainFrame.viewSubtitle, (mainFrame.requestCreatePanel.points[1] or {})[2], "request-only mode should place request entry directly below the request subtitle")
assert.truthy(mainFrame.requestCreateButton.enabled ~= false, "request-only mode should keep the lightweight create affordance enabled when request submit is allowed")
