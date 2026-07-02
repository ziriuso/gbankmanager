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
local activeTheme = env.mainFrameShell.GetTheme()
local craftedQuality = env.ns.modules.craftedQuality
local itemCatalog = env.ns.modules.itemCatalog

local TRUSTED_ITEM_LINKS = {
    [241322] = "|cffffffff|Hitem:241322::::::::80:::::|h[Flask of the Magisters]|h|r",
    [241326] = "|cffffffff|Hitem:241326::::::::80:::::|h[Flask of the Shattered Sun]|h|r",
    [241327] = "|cffffffff|Hitem:241327::::::::80:::::|h[Flask of the Shattered Sun]|h|r",
    [243734] = "|cffffffff|Hitem:243734::::::::80:::::|h[Thalassian Phoenix Oil]|h|r",
}

local function trusted_item_string(itemID)
    return string.format("item:%d::::::::80:::::", tonumber(itemID) or 0)
end

local function apply_trusted_item_fields(item)
    item = type(item) == "table" and item or nil
    if not item then
        return nil
    end

    local itemID = tonumber(item.itemID)
    local itemLink = itemID and TRUSTED_ITEM_LINKS[itemID] or nil
    if itemLink then
        item.itemLink = itemLink
        item.itemString = trusted_item_string(itemID)
    end

    return item
end

for itemID, itemLink in pairs(TRUSTED_ITEM_LINKS) do
    local bundledItem = itemCatalog and type(itemCatalog.GetBundledItemByID) == "function" and itemCatalog.GetBundledItemByID(itemID) or nil
    if bundledItem then
        bundledItem.itemLink = itemLink
        bundledItem.itemString = trusted_item_string(itemID)
    end
end

local function color_distance(left, right)
    left = left or {}
    right = right or {}
    local total = 0
    for index = 1, 3 do
        total = total + math.abs((left[index] or 0) - (right[index] or 0))
    end
    return total
end

local function point_y(frame)
    return (frame.points[1] or {})[5]
end

local function assert_aligned(label, value, message)
    assert.same(mainFrame.requestDetailsModal, (label.points[1] or {})[2], message .. " label should anchor to the modal")
    assert.same(mainFrame.requestDetailsModal, (value.points[1] or {})[2], message .. " value should anchor to the modal")
    assert.equal(point_y(label), point_y(value), message .. " label and value should share one fixed row")
end

local function visible_sidebar_keys(frame)
    local keys = {}
    for _, button in ipairs((frame or {}).sidebarButtons or {}) do
        if button:IsShown() then
            keys[#keys + 1] = button.key
        end
    end
    return keys
end

local function visible_options_tab_keys(frame)
    local keys = {}
    for _, button in ipairs((frame or {}).optionsTabButtons or {}) do
        if button:IsShown() then
            keys[#keys + 1] = button.key
        end
    end
    return keys
end

local function decode_outbound_sync_message(sentMessages, senderKey)
    local transport = env.ns.modules.syncTransport
    local decodedMessage
    senderKey = tostring(senderKey or "ui-requests-test")

    for _, sent in ipairs(sentMessages or {}) do
        local message = type(transport.Receive) == "function" and transport.Receive(sent.payload, sent.distribution, senderKey) or nil
        if type(message) == "table" then
            decodedMessage = message
        end
    end

    return decodedMessage
end

local function capture_request_sync_calls(callback)
    local transport = env.ns.modules.syncTransport
    local originalSend = transport.Send
    local sendCalls = {}

    transport.Send = function(distribution, target, message)
        sendCalls[#sendCalls + 1] = {
            distribution = distribution,
            target = target,
            message = message,
        }

        if type(originalSend) == "function" then
            return originalSend(distribution, target, message)
        end

        return message
    end

    local ok, result = pcall(callback, sendCalls)
    transport.Send = originalSend
    if not ok then
        error(result)
    end

    return sendCalls, result
end

local function current_runtime_db()
    return env.ns.state.db or _G.GBankManagerDB or {}
end

_G.GBankManagerDB = _G.GBankManagerDB or {}
_G.GBankManagerDB.ui = _G.GBankManagerDB.ui or {}
_G.GBankManagerDB.ui.minimumItemCatalog = {
    apply_trusted_item_fields({
        itemID = 990001,
        name = "Test Crafted Widget",
        craftedQuality = 5,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
    }),
    apply_trusted_item_fields({
        itemID = 990010,
        name = "[T2] Test Variant Flask",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    }),
    apply_trusted_item_fields({
        itemID = 990011,
        name = "[T5] Test Variant Flask",
        craftedQuality = 5,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
    }),
}
_G.GBankManagerDB.requests = {
    apply_trusted_item_fields({
        requestId = "req-1",
        requester = "OfficerOne",
        requesterCharacterKey = "Stormrage-OfficerOne",
        itemName = "Raid Flask",
        itemID = 990001,
        craftedQuality = 5,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
        quantity = 5,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "Raid night",
        createdAt = 100,
    }),
    apply_trusted_item_fields({
        requestId = "req-2",
        requester = "RaiderTwo-Stormrage",
        itemName = "Arcane Oil",
        itemID = 990010,
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        quantity = 2,
        approval = "APPROVED",
        fulfillment = "OPEN",
        note = "Alt raid",
        createdAt = 200,
    }),
    apply_trusted_item_fields({
        requestId = "req-approve-bank-tab",
        requester = "RaiderThree",
        requesterCharacterKey = "Stormrage-RaiderThree",
        itemName = "Thalassian Phoenix Oil",
        itemID = 243734,
        craftedQuality = 2,
        craftedQualityIcon = "|A:Professions-ChatIcon-Quality-Tier2:22:22|a",
        quantity = 100,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "We should have better oil",
        createdAt = 300,
    }),
    apply_trusted_item_fields({
        requestId = "req-stale-tier",
        requester = "RaiderFive",
        requesterCharacterKey = "Stormrage-RaiderFive",
        itemName = "Flask of the Shattered Sun",
        itemID = 241326,
        craftedQuality = 1,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
        quantity = 20,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "Need specific flask",
        createdAt = 325,
    }),
    apply_trusted_item_fields({
        requestId = "req-denied-note-hidden",
        requester = "RaiderFour",
        requesterCharacterKey = "Stormrage-RaiderFour",
        itemName = "Denied Flask",
        itemID = 990011,
        craftedQuality = 5,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
        quantity = 1,
        approval = "REJECTED",
        fulfillment = "OPEN",
        note = "Maybe later",
        decisionNote = "Not needed",
        decidedBy = "OfficerOne",
        decidedAt = 400,
        createdAt = 350,
    }),
}
_G.GBankManagerDB.minimums = {}
_G.GBankManagerDB.currentSnapshotId = "request-approval-snapshot"
_G.GBankManagerDB.snapshots = {
    ["request-approval-snapshot"] = {
        scanId = "request-approval-snapshot",
        scannedAt = 300,
        items = {
            [243734] = {
                itemID = 243734,
                itemName = "Thalassian Phoenix Oil",
                itemLink = TRUSTED_ITEM_LINKS[243734],
                itemString = trusted_item_string(243734),
                totalCount = 0,
                tabs = {
                    ["Raid Buffer"] = 0,
                    ["Gems and Chants"] = 0,
                },
            },
        },
    },
}
env.ns.state.db = _G.GBankManagerDB
env.ns.state.db.auth.capabilities.request_delete = { [1] = true }

mainFrame:SelectView("REQUESTS")
assert.equal("REQUESTS", mainFrame.activeView, "requests tab should be selectable")
assert.equal("Requests", mainFrame.viewTitle:GetText(), "full-shell requests tab should be named Requests")
assert.equal("Requests", mainFrame.sidebarButtons[4].labelText:GetText(), "sidebar should label the request tab as Requests")
assert.truthy(not mainFrame.requestCreatePanel:IsShown(), "request admin should not expose inline request creation")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request admin should remove the old workflow actions box")
assert.same(mainFrame.viewSubtitle, (mainFrame.tableHeaderFrame.points[1] or {})[2], "request admin table should scale directly below the page subtitle")
assert.truthy(mainFrame.tableViewportFrame:IsShown(), "requests view should show the shared table viewport")
assert.truthy(mainFrame.tableFilterFrame:IsShown(), "request admin table should use shared search controls like inventory")
assert.truthy(mainFrame.requestAdminFilterPanel:IsShown(), "request admin should expose the bottom status filter strip")
assert.equal("panel-flat", mainFrame.requestAdminFilterPanel.gbmSurfaceVariant, "request admin footer strip should now match the bank ledger footer surface variant")
assert.equal(((((mainFrame.bankLedgerPanel or {}).gbmArt or {}).innerFill or {}).color or {})[1], (((mainFrame.requestAdminFilterPanel.gbmArt or {}).innerFill or {}).color or {})[1], "request admin footer strip should reuse the bank ledger footer fill value")
assert.equal(((((mainFrame.bankLedgerPanel or {}).gbmArt or {}).innerFill or {}).color or {})[4], (((mainFrame.requestAdminFilterPanel.gbmArt or {}).innerFill or {}).color or {})[4], "request admin footer strip should reuse the bank ledger footer opacity")
assert.truthy(mainFrame.requestAdminAddButton:IsShown(), "request admin should expose an Add action on the bottom strip")
assert.truthy(mainFrame.requestAdminRefreshButton:IsShown(), "request admin should expose a Refresh action on the bottom strip")
assert.equal("Add Request", mainFrame.requestAdminAddButton.labelText:GetText(), "request admin bottom strip should label the create action clearly")
assert.equal("Refresh", mainFrame.requestAdminRefreshButton.labelText:GetText(), "request admin bottom strip should label refresh clearly")
assert.equal("BOTTOMLEFT", (mainFrame.requestAdminAddButton.points[1] or {})[1], "request admin Add should anchor from the far left of the bottom strip")
assert.equal("LEFT", (mainFrame.requestAdminRefreshButton.points[1] or {})[1], "request admin Refresh should chain after Add Request on the left edge")
assert.equal("All", mainFrame.requestAdminFilterAllButton.labelText:GetText(), "request admin should have an All filter")
assert.equal("Pending Approval", mainFrame.requestAdminFilterPendingApprovalButton.labelText:GetText(), "request admin should have a Pending Approval filter")
assert.equal("Pending Fulfillment", mainFrame.requestAdminFilterPendingFulfillmentButton.labelText:GetText(), "request admin should have a Pending Fulfillment filter")
assert.equal("Completed", mainFrame.requestAdminFilterCompletedButton.labelText:GetText(), "request admin should have a Completed filter")
assert.equal("BOTTOMRIGHT", (mainFrame.requestAdminFilterCompletedButton.points[1] or {})[1], "request admin rightmost filter should now anchor Completed on the right edge")
assert.equal("RIGHT", (mainFrame.requestAdminFilterPendingFulfillmentButton.points[1] or {})[1], "request admin Pending Fulfillment should chain left from Completed")
assert.equal("RIGHT", (mainFrame.requestAdminFilterPendingApprovalButton.points[1] or {})[1], "request admin Pending Approval should chain left from Pending Fulfillment")
assert.equal("RIGHT", (mainFrame.requestAdminFilterAllButton.points[1] or {})[1], "request admin All should chain left from Pending Approval")
assert.same(mainFrame.requestAdminFilterCompletedButton, (mainFrame.requestAdminFilterPendingFulfillmentButton.points[1] or {})[2], "request admin Pending Fulfillment should anchor from Completed")
assert.same(mainFrame.requestAdminFilterPendingFulfillmentButton, (mainFrame.requestAdminFilterPendingApprovalButton.points[1] or {})[2], "request admin Pending Approval should anchor from Pending Fulfillment")
assert.same(mainFrame.requestAdminFilterPendingApprovalButton, (mainFrame.requestAdminFilterAllButton.points[1] or {})[2], "request admin All should anchor from Pending Approval")
assert.equal("Date Requested", mainFrame.tableHeaderLabels[1]:GetText(), "request admin table should expose the request date")
assert.equal("Requestor", mainFrame.tableHeaderLabels[2]:GetText(), "request admin table should expose Requestor")
assert.equal("Item ID", mainFrame.tableHeaderLabels[3]:GetText(), "request admin table should expose Item ID")
assert.equal("Item", mainFrame.tableHeaderLabels[4]:GetText(), "request admin table should expose the shared item display column")
assert.equal("Quantity", mainFrame.tableHeaderLabels[5]:GetText(), "request admin table should expose quantity")
assert.equal("Status", mainFrame.tableHeaderLabels[6]:GetText(), "request admin table should expose combined status")
assert.equal("Date Fulfilled", mainFrame.tableHeaderLabels[7]:GetText(), "request admin table should expose date fulfilled")
assert.truthy((mainFrame.tableViewportHeight or 0) > 0, "request admin table should keep a positive shared table height")
assert.truthy((mainFrame.tableViewportHeight or 0) <= (mainFrame.defaultTableViewportHeight or 364), "request admin table should clamp within the shared shell instead of forcing the footer strip offscreen")
assert.truthy((mainFrame.tableFilterInputs[7]:GetWidth() or 0) <= 120, "request admin Date Fulfilled filter should stay compact enough to fit inside the shared table width")
assert.truthy(not mainFrame.tableScrollBar:IsShown(), "request admin should hide the shared table scrollbar when there is nothing to scroll")
assert.equal((activeTheme.tokens.rowAlt or {})[1], (mainFrame.tableRows[2].gbmBackdropBaseColor or {})[1], "request admin visible unselected rows should use the shared alternating row token")
assert.equal((activeTheme.tokens.row or {})[1], (mainFrame.tableRows[3].gbmBackdropBaseColor or {})[1], "request admin visible unselected rows should continue the shared row token cadence")
assert.truthy(color_distance(mainFrame.tableRows[2].gbmBackdropBaseColor, mainFrame.tableRows[3].gbmBackdropBaseColor) >= 0.09, "request admin alternating rows should keep the same stronger contrast as the other shared tables")
assert.truthy(not ((mainFrame.tableRows[2].gbmArt or {}).topLine):IsShown(), "request admin rows should avoid a hard top border")
assert.truthy(((mainFrame.tableRows[2].gbmArt or {}).bottomLine):IsShown(), "request admin rows should keep the shared subtle bottom separator")
assert.truthy(mainFrame.requestAdminFilterAllButton.filterActive == true, "request admin should highlight the active All filter")
assert.truthy(mainFrame.requestAdminFilterPendingApprovalButton.filterActive ~= true, "request admin should not highlight inactive filters")
assert.equal((activeTheme.colors.accentStrong or {})[1], (mainFrame.requestAdminFilterAllButton.backdropBorderColor or {})[1], "request admin should give the active filter a stronger glow")
assert.equal("action-slim", mainFrame.requestAdminAddButton.gbmButtonFamily, "request admin Add should use the slimmer shared action family")
assert.equal("action-slim", mainFrame.requestAdminRefreshButton.gbmButtonFamily, "request admin Refresh should use the slimmer shared action family")
assert.equal("segmented-soft", mainFrame.requestAdminFilterAllButton.gbmTabStyle, "request admin filters should use the softer segmented-tab treatment")
assert.equal("segmented-soft", mainFrame.requestAdminFilterPendingApprovalButton.gbmTabStyle, "request admin filters should use the softer segmented-tab treatment")
assert.equal("secondary", mainFrame.requestAdminAddButton.gbmButtonVariant, "request admin Add should use the shared secondary action styling")
assert.equal("secondary", mainFrame.requestAdminRefreshButton.gbmButtonVariant, "request admin Refresh should use the shared secondary action styling")
assert.truthy(color_distance(((mainFrame.requestAdminAddButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.requestAdminFilterPanel.gbmArt or {}).innerFill or {}).color) >= 0.10, "request admin Add should contrast from the footer strip")
assert.truthy(color_distance(((mainFrame.requestAdminRefreshButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.requestAdminFilterPanel.gbmArt or {}).innerFill or {}).color) >= 0.10, "request admin Refresh should contrast from the footer strip")
assert.equal("tab", mainFrame.requestAdminFilterAllButton.gbmButtonVariant, "request admin filters should use shared tab-pill styling")
assert.equal("tab", mainFrame.requestAdminFilterPendingApprovalButton.gbmButtonVariant, "request admin filters should share the tab-pill styling")
assert.equal("tab", mainFrame.requestAdminFilterPendingFulfillmentButton.gbmButtonVariant, "request admin filters should share the tab-pill styling")
assert.equal("tab", mainFrame.requestAdminFilterCompletedButton.gbmButtonVariant, "request admin filters should share the tab-pill styling")
assert.truthy(string.match(mainFrame.tableRowsData[1].createdAt or "", "^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$") ~= nil, "request admin rows should include formatted date requested")
assert.equal("241326", mainFrame.tableRowsData[1].itemID, "request admin rows should include item id")
assert.equal(TRUSTED_ITEM_LINKS[241326], mainFrame.tableRowsData[1].itemDisplayText, "request rows should render the shared hyperlink-style item display when a trusted link is available")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", mainFrame.tableRowsData[1].itemDisplayTextIconAtlas, "request rows should render bundled two-rank crafted consumables through the canonical gold-pentagram atlas in the shared item display column")
assert.equal(2, tonumber(mainFrame.tableRowsData[1].craftedQualityFamilySize or 0), "request rows should keep two-rank crafted-quality family metadata so the shared table can normalize live chat atlases")
assert.equal(2, tonumber(mainFrame.tableRowsData[1].craftedQualityMax or 0), "request rows should keep semantic crafted-quality max as a fallback for live render normalization")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", mainFrame.tableRowsData[1].craftedQualityDisplayAtlas, "request rows should carry the canonical non-inventory quality display atlas for downstream renderers")
assert.equal("Flask of the Shattered Sun", mainFrame.tableRowsData[1].itemName, "request admin rows should preserve a plain-text item name alongside the shared display payload")
assert.equal("Pending", mainFrame.tableRowsData[1].status, "request admin rows should expose a readable combined status")
assert.equal(5, #mainFrame.tableRowsData, "request admin All filter should include fulfilled and rejected requests")
local originalGetRequestSearchSnapshot = mainFrame.GetRequestSearchSnapshot
local requestSearchSnapshotBuildCount = 0
mainFrame.GetRequestSearchSnapshot = function(self, ...)
    requestSearchSnapshotBuildCount = requestSearchSnapshotBuildCount + 1
    return originalGetRequestSearchSnapshot(self, ...)
end
mainFrame:RefreshView()
mainFrame.GetRequestSearchSnapshot = originalGetRequestSearchSnapshot
assert.equal(1, requestSearchSnapshotBuildCount, "request refresh should build the item search snapshot once and reuse it for row backfill")
mainFrame.requestAdminFilterPendingApprovalButton:GetScript("OnClick")(mainFrame.requestAdminFilterPendingApprovalButton)
assert.truthy(mainFrame.requestAdminFilterPendingApprovalButton.filterActive == true, "request admin should highlight Pending Approval when selected")
assert.truthy(mainFrame.requestAdminFilterAllButton.filterActive ~= true, "request admin should clear the All highlight when another filter is selected")
assert.equal(3, #mainFrame.tableRowsData, "request admin Pending Approval should only show pending requests")
assert.equal((activeTheme.colors.accentStrong or {})[1], (mainFrame.requestAdminFilterPendingApprovalButton.backdropBorderColor or {})[1], "request admin should move the stronger glow to the newly selected filter")
mainFrame.requestAdminFilterPendingFulfillmentButton:GetScript("OnClick")(mainFrame.requestAdminFilterPendingFulfillmentButton)
assert.truthy(mainFrame.requestAdminFilterPendingFulfillmentButton.filterActive == true, "request admin should highlight Pending Fulfillment when selected")
assert.equal(1, #mainFrame.tableRowsData, "request admin Pending Fulfillment should only show approved open requests")
mainFrame.requestAdminFilterCompletedButton:GetScript("OnClick")(mainFrame.requestAdminFilterCompletedButton)
assert.truthy(mainFrame.requestAdminFilterCompletedButton.filterActive == true, "request admin should highlight Completed when selected")
assert.equal(1, #mainFrame.tableRowsData, "request admin Completed should show closed-out requests")
assert.equal("Denied Flask", mainFrame.tableRowsData[1].itemName, "request admin Completed should surface the completed or rejected request row")
mainFrame.requestAdminFilterAllButton:GetScript("OnClick")(mainFrame.requestAdminFilterAllButton)
assert.equal(5, #mainFrame.tableRowsData, "request admin All should restore the full admin list")
mainFrame.requestAdminAddButton:GetScript("OnClick")(mainFrame.requestAdminAddButton)
assert.truthy(mainFrame.requestWizardModal:IsShown(), "request admin Add should launch the shared request wizard")
mainFrame.requestWizardCancelButton:GetScript("OnClick")(mainFrame.requestWizardCancelButton)
local requestFilterSnapshotBuildCount = 0
mainFrame.GetRequestSearchSnapshot = function(self, ...)
    requestFilterSnapshotBuildCount = requestFilterSnapshotBuildCount + 1
    return originalGetRequestSearchSnapshot(self, ...)
end
mainFrame.tableFilterInputs[4]:SetText("Arcane")
mainFrame.tableFilterInputs[4]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[4])
mainFrame.GetRequestSearchSnapshot = originalGetRequestSearchSnapshot
assert.equal(1, #mainFrame.tableRowsData, "request admin shared filters should search by item name")
assert.equal("Arcane Oil", mainFrame.tableRowsData[1].itemName, "request admin item-name filter should keep the matching row")
assert.equal(0, requestFilterSnapshotBuildCount, "request admin filter typing should update visible rows without rebuilding item search snapshots")
mainFrame.tableFilterInputs[4]:SetText("")
mainFrame.tableFilterInputs[4]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[4])
mainFrame.tableFilterInputs[3]:SetText("990001")
mainFrame.tableFilterInputs[3]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[3])
assert.equal(1, #mainFrame.tableRowsData, "request admin shared filters should search by item id")
assert.equal("990001", mainFrame.tableRowsData[1].itemID, "request admin item-id filter should keep the matching row")
mainFrame.tableFilterInputs[3]:SetText("")
mainFrame.tableFilterInputs[3]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[3])

mainFrame:ShowRequestOnly()
assert.equal("REQUESTS", mainFrame.activeView, "request-only mode should stay on the requests view")
assert.truthy(mainFrame.requestOnlyMode == true, "request-only mode should be tracked on the shell")
assert.truthy(mainFrame.requestWorkflowPanel:IsShown(), "request-only mode should show the separate end-user request workflow")
assert.equal("panel-alt", mainFrame.requestWorkflowPanel.gbmSurfaceVariant, "request-only summary should use the elevated workflow panel styling")
assert.truthy(not mainFrame.requestCreatePanel:IsShown(), "request-only workflow should not use the old inline create panel")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request-only mode should hide officer action controls")
assert.truthy(mainFrame.sidebar:IsShown(), "request-only mode should keep the sidebar visible")
assert.equal("REQUESTS,OPTIONS,ABOUT", table.concat(visible_sidebar_keys(mainFrame), ","), "request-only mode should only expose requests, options, and about navigation")
assert.same(mainFrame.viewSubtitle, (mainFrame.requestWorkflowPanel.points[1] or {})[2], "request-only mode should place the request workflow directly below the request subtitle")
assert.equal("Guild Bank Manager", mainFrame.titleText:GetText(), "request-only header should keep the addon title visible")
assert.truthy(mainFrame.titleText:IsShown(), "request-only header should show the addon title")
assert.truthy((mainFrame:GetWidth() or 0) < 1040, "request-only window should be slightly smaller than the full officer shell")
assert.truthy((mainFrame:GetHeight() or 0) < 640, "request-only window should be slightly shorter than the full officer shell")
assert.equal("action-slim", mainFrame.requestWorkflowCreateButton.gbmButtonFamily, "request-only launcher should use the slimmer action family")
assert.equal("primary", mainFrame.requestWorkflowCreateButton.gbmButtonVariant, "request-only launcher should use the shared primary CTA styling")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "request-only workflow should start with item id")
assert.equal("Item", mainFrame.tableHeaderLabels[2]:GetText(), "request-only workflow should include the shared item display column")
assert.equal("Quantity", mainFrame.tableHeaderLabels[3]:GetText(), "request-only workflow should include quantity")
assert.equal("Status", mainFrame.tableHeaderLabels[4]:GetText(), "request-only workflow should expose combined status")
assert.truthy(tostring(mainFrame.tableRowsData[1].itemID or "") ~= "", "request-only rows should include item id")
assert.truthy(tostring(mainFrame.tableRowsData[1].itemDisplayText or "") ~= "", "request-only rows should include the shared item display text")
assert.truthy(tostring(mainFrame.tableRowsData[1].quantity or "") ~= "", "request-only rows should include quantity")
assert.equal("Pending", mainFrame.tableRowsData[1].status, "request-only rows should include status")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.requestDetailsModal:IsShown(), "clicking a request row should open the shared request details modal")
local selectedRequest = mainFrame:GetSelectedRequest()
assert.equal("modal-sheet", mainFrame.requestDetailsModal.gbmSurfaceVariant, "request details should use the cleaner floating-sheet surface")
assert.truthy(mainFrame.requestDetailsModal.mouseEnabled == true, "request details modal should block clicks from reaching the request table behind it")
assert.truthy((mainFrame.requestDetailsModal.frameLevel or 0) > (mainFrame.frameLevel or 0), "request details modal should render above table rows")
assert.equal(TRUSTED_ITEM_LINKS[(selectedRequest or {}).itemID], mainFrame.requestDetailsItemNameText:GetText(), "request details should show the shared hyperlink-style item display")
assert.truthy(mainFrame.requestDetailsQualityIcon and mainFrame.requestDetailsQualityIcon:IsShown(), "request details should show the crafted-quality icon inline beside the shared item display")
assert.equal((mainFrame.requestDetailsItemNameText.points[1] or {})[5], (mainFrame.requestDetailsQualityIcon.points[1] or {})[5], "request details quality icon should sit on the same row as the item name")
assert.truthy(not (mainFrame.requestDetailsQualityLabel and mainFrame.requestDetailsQualityLabel:IsShown()), "request details should hide the separate quality label once the shared item-display contract is in place")
assert.truthy(not (mainFrame.requestDetailsQualityText and mainFrame.requestDetailsQualityText:IsShown()), "request details should hide the separate quality text once the shared item-display contract is in place")
assert.equal(tostring(mainFrame.tableRowsData[1].quantity or ""), mainFrame.requestDetailsQuantityText:GetText(), "request details should show quantity")
assert.equal(tostring((selectedRequest or {}).note or ""), mainFrame.requestDetailsSubmissionNoteText:GetText(), "request details should show submission note")
assert.equal("Pending", mainFrame.requestDetailsStatusText:GetText(), "request details should show readable status")
assert.truthy(type(mainFrame.requestDetailsApprovedByText) == "table", "request details should expose Approved By")
assert.equal("-", mainFrame.requestDetailsApprovedByText:GetText(), "pending request details should show no approver")
assert.truthy(type(mainFrame.requestDetailsApprovedAtText) == "table", "request details should expose Date Approved")
assert.equal("-", mainFrame.requestDetailsApprovedAtText:GetText(), "pending request details should show no approval date")
assert.truthy(string.find(mainFrame.requestDetailsRequestedAtText:GetText() or "", "(Local)", 1, true) == nil, "request details should remove the local suffix from dates")
assert.equal("Requested By", mainFrame.requestDetailsRequesterLabel:GetText(), "request details should show who requested the item")
assert.equal(tostring((selectedRequest or {}).requester or (selectedRequest or {}).createdBy or "-"), mainFrame.requestDetailsRequesterText:GetText(), "request details should show the requester above Date Requested")
assert.equal("select", mainFrame.requestDetailsBankTabDropdownButton.gbmButtonVariant, "request details bank-tab chooser should use the shared select control styling")
assert.truthy(color_distance(((mainFrame.requestDetailsBankTabDropdownButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.requestDetailsModal.gbmArt or {}).innerFill or {}).color) >= 0.10, "request details bank-tab chooser should contrast from the modal background")
assert.equal("Updated By", mainFrame.requestDetailsApprovedByLabel:GetText(), "request details should use Updated By instead of Approved By")
assert.equal("Date Updated", mainFrame.requestDetailsApprovedAtLabel:GetText(), "request details should use Date Updated instead of Date Approved")
assert.truthy(type(mainFrame.requestDetailsCancelRequestButton) == "table", "request details should expose a cancel-request action control")
assert.truthy(not ((mainFrame.requestDetailsDeleteButton and mainFrame.requestDetailsDeleteButton:IsShown()) == true), "request-only authors should not see request delete in details")
assert.equal(184, (mainFrame.requestDetailsItemNameText.points[1] or {})[4], "request details item name should make room for the inline quality icon")
assert.equal(160, (mainFrame.requestDetailsQuantityText.points[1] or {})[4], "request details non-item values should keep the fixed modal value column")
assert_aligned(mainFrame.requestDetailsItemNameLabel, mainFrame.requestDetailsItemNameText, "item name")
assert.truthy(point_y(mainFrame.requestDetailsItemNameLabel) > point_y(mainFrame.requestDetailsQuantityLabel), "quantity should sit directly below the item row with no retired quality-row gap")
assert_aligned(mainFrame.requestDetailsQuantityLabel, mainFrame.requestDetailsQuantityText, "quantity")
assert_aligned(mainFrame.requestDetailsSubmissionNoteLabel, mainFrame.requestDetailsSubmissionNoteText, "submission note")
assert_aligned(mainFrame.requestDetailsStatusLabel, mainFrame.requestDetailsStatusText, "status")
assert_aligned(mainFrame.requestDetailsRequesterLabel, mainFrame.requestDetailsRequesterText, "requested by")
assert_aligned(mainFrame.requestDetailsRequestedAtLabel, mainFrame.requestDetailsRequestedAtText, "date requested")
assert_aligned(mainFrame.requestDetailsApprovedByLabel, mainFrame.requestDetailsApprovedByText, "updated by")
assert_aligned(mainFrame.requestDetailsApprovedAtLabel, mainFrame.requestDetailsApprovedAtText, "date updated")
assert_aligned(mainFrame.requestDetailsFulfilledAtLabel, mainFrame.requestDetailsFulfilledAtText, "date fulfilled")
assert_aligned(mainFrame.requestDetailsDecisionNoteLabel, mainFrame.requestDetailsDecisionNoteText, "decision note")
assert.truthy(point_y(mainFrame.requestDetailsStatusLabel) > point_y(mainFrame.requestDetailsRequesterLabel), "requested by should be below status")
assert.truthy(point_y(mainFrame.requestDetailsRequesterLabel) > point_y(mainFrame.requestDetailsRequestedAtLabel), "date requested should be below requested by")
assert.truthy(point_y(mainFrame.requestDetailsRequestedAtLabel) > point_y(mainFrame.requestDetailsApprovedByLabel), "updated by should be below date requested")
assert.truthy(point_y(mainFrame.requestDetailsApprovedByLabel) > point_y(mainFrame.requestDetailsApprovedAtLabel), "date updated should be below updated by")
assert.truthy(point_y(mainFrame.requestDetailsApprovedAtLabel) > point_y(mainFrame.requestDetailsDecisionNoteLabel), "decision note should be at the bottom of the detail list")
assert.truthy((point_y(mainFrame.requestDetailsDecisionNoteLabel) - point_y(mainFrame.requestDetailsBankTabLabel)) >= 28, "approval bank tab should have a little breathing room below the decision note row")
assert.equal("Decision Note", mainFrame.requestDetailsActionNoteLabel:GetText(), "request details action note should be explicitly labeled")
assert.same(mainFrame.requestDetailsModal, (mainFrame.requestDetailsItemNameText.points[1] or {})[2], "request details values should align to a fixed modal column")
assert.equal("danger", mainFrame.requestDetailsDeleteButton.gbmButtonVariant, "request details delete should use the destructive shared button styling")

mainFrame.requestDetailsCloseButton:GetScript("OnClick")(mainFrame.requestDetailsCloseButton)
mainFrame.requestWorkflowCreateButton:GetScript("OnClick")(mainFrame.requestWorkflowCreateButton)
assert.truthy(mainFrame.requestWizardModal:IsShown(), "new request should open the three-step wizard")
assert.equal("modal-sheet", mainFrame.requestWizardModal.gbmSurfaceVariant, "request wizard should use the cleaner floating-sheet surface")
assert.equal("panel-alt", mainFrame.requestWizardProgressPanel.gbmSurfaceVariant, "request wizard progress rail should use a dedicated elevated panel style")
assert.equal("panel", mainFrame.requestWizardPrimaryPanel.gbmSurfaceVariant, "request wizard primary stage should use the carved main panel style")
assert.equal("panel-alt", mainFrame.requestWizardPreviewPanel.gbmSurfaceVariant, "request wizard preview should use the elevated side card style")
assert.equal("secondary", mainFrame.requestWizardBackButton.gbmButtonVariant, "request wizard Back should use shared secondary action styling")
assert.equal("primary", mainFrame.requestWizardNextButton.gbmButtonVariant, "request wizard Next should use shared primary action styling")
assert.equal("primary", mainFrame.requestWizardSubmitButton.gbmButtonVariant, "request wizard Submit should use shared primary action styling")
assert.equal("secondary", mainFrame.requestWizardCancelButton.gbmButtonVariant, "request wizard Cancel should use shared secondary action styling")
assert.equal("action-slim", mainFrame.requestWizardBackButton.gbmButtonFamily, "request wizard Back should use the slimmer shared action family")
assert.equal("action-slim", mainFrame.requestWizardNextButton.gbmButtonFamily, "request wizard Next should use the slimmer shared action family")
assert.equal("action-slim", mainFrame.requestWizardSubmitButton.gbmButtonFamily, "request wizard Submit should use the slimmer shared action family")
assert.equal("action-slim", mainFrame.requestWizardCancelButton.gbmButtonFamily, "request wizard Cancel should use the slimmer shared action family")
assert.equal("select", mainFrame.requestWizardBankTabDropdownButton.gbmButtonVariant, "request wizard bank-tab chooser should use the shared select control styling")
assert.same(mainFrame.requestDetailsModal, (mainFrame.requestDetailsSubmissionNoteText.points[1] or {})[2], "long request details values should use the same fixed modal column")
assert.same(mainFrame.requestDetailsModal, (mainFrame.requestDetailsActionNoteLabel.points[1] or {})[2], "request detail action controls should align to fixed modal positions")
mainFrame.requestWizardCancelButton:GetScript("OnClick")(mainFrame.requestWizardCancelButton)

mainFrame:SelectView("INVENTORY")
assert.equal("REQUESTS", mainFrame.activeView, "request-only mode should keep manager-only views inaccessible")

mainFrame:SelectView("OPTIONS")
assert.equal("OPTIONS", mainFrame.activeView, "request-only mode should allow the options view")
assert.equal(true, mainFrame.requestOnlyMode == true, "request-only mode should stay active while visiting options")
assert.equal("REQUESTS,OPTIONS,ABOUT", table.concat(visible_sidebar_keys(mainFrame), ","), "request-only options should keep the restricted sidebar navigation")
assert.equal("APPEARANCE,SYNC,LOGS_HISTORY", table.concat(visible_options_tab_keys(mainFrame), ","), "request-only options should only expose appearance, sync, and data tabs")
assert.equal("APPEARANCE", mainFrame.optionsActiveTab, "request-only options should default to appearance")
assert.truthy(mainFrame.optionsAppearancePanel:IsShown(), "request-only options should show appearance by default")
assert.truthy(not mainFrame.optionsStockSettingsPanel:IsShown(), "request-only options should hide stock settings")
assert.truthy(not mainFrame.optionsPermissionsPanel:IsShown(), "request-only options should hide permissions")
assert.truthy(not mainFrame.optionsBlacklistPanel:IsShown(), "request-only options should hide blacklist")
mainFrame:SetOptionsTab("PERMISSIONS")
assert.equal("APPEARANCE", mainFrame.optionsActiveTab, "request-only options should normalize disallowed tabs back to appearance")
mainFrame:SetOptionsTab("SYNC")
assert.equal("SYNC", mainFrame.optionsActiveTab, "request-only options should still allow the sync tab")
assert.truthy(mainFrame.optionsSyncPanel:IsShown(), "request-only options should show sync controls")
mainFrame:SetOptionsTab("LOGS_HISTORY")
assert.equal("LOGS_HISTORY", mainFrame.optionsActiveTab, "request-only options should still allow the data tab")
assert.truthy(mainFrame.optionsLogsHistoryPanel:IsShown(), "request-only options should show data controls")

mainFrame:SelectView("ABOUT")
assert.equal("ABOUT", mainFrame.activeView, "request-only mode should allow the about view")
assert.equal(true, mainFrame.requestOnlyMode == true, "request-only mode should stay active while visiting about")
assert.truthy(mainFrame.aboutPanel:IsShown(), "request-only about should show the shared about panel")
assert.equal("REQUESTS,OPTIONS,ABOUT", table.concat(visible_sidebar_keys(mainFrame), ","), "request-only about should keep the restricted sidebar navigation")

mainFrame:ShowDashboard()
mainFrame:SelectView("REQUESTS")
mainFrame:OpenRequestDetailsModal("req-approve-bank-tab")
assert.truthy(mainFrame.requestDetailsModal:IsShown(), "admin approval should use the shared details modal")
assert.equal(TRUSTED_ITEM_LINKS[243734], mainFrame.requestDetailsItemNameText:GetText(), "request details should keep using the shared hyperlink-style item display for two-rank crafted items")
assert.truthy(mainFrame.requestDetailsQualityIcon and mainFrame.requestDetailsQualityIcon:IsShown(), "request details should show the two-rank crafted-quality icon inline with the item name")
assert.truthy(mainFrame.requestDetailsBankTabLabel:IsShown(), "approving a request should prompt for a bank tab")
assert.equal("Approval Bank Tab", mainFrame.requestDetailsBankTabLabel:GetText(), "approval bank tab prompt should be labeled")
assert.truthy(mainFrame.requestDetailsApproveButton.enabled == false, "approve should stay disabled until the approver chooses a bank tab")
mainFrame.requestDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.requestDetailsBankTabDropdownButton)
assert.truthy(mainFrame.requestDetailsBankTabDropdownPanel:IsShown(), "approval bank tab button should open tab choices")
assert.equal("Raid Buffer", mainFrame.requestDetailsBankTabDropdownOptions[2].value, "approval bank tab prompt should include known bank tabs")
mainFrame.requestDetailsBankTabDropdownOptions[2]:GetScript("OnClick")(mainFrame.requestDetailsBankTabDropdownOptions[2])
assert.equal("Raid Buffer", mainFrame.requestDetailsBankTabDropdownButton.labelText:GetText(), "selected approval bank tab should show on the button")
assert.truthy(mainFrame.requestDetailsApproveButton.enabled ~= false, "approve should enable after choosing a bank tab")
mainFrame.requestDetailsActionNoteInput:SetText("Approved for raid supplies")
local originalTime = _G.time
_G.time = function()
    return 301
end
mainFrame.requestDetailsApproveButton:GetScript("OnClick")(mainFrame.requestDetailsApproveButton)
_G.time = originalTime
local approvedRequest = mainFrame:GetSelectedRequest()
assert.equal("APPROVED", approvedRequest.approval, "details approve should approve the request")
assert.equal("Approved for raid supplies", approvedRequest.decisionNote, "details approve should store the decision note")
assert.equal("Raid Buffer", approvedRequest.approvedBankTab, "details approve should store the chosen bank tab")
assert.truthy(mainFrame.requestDetailsModal:IsShown(), "request details should stay open after status updates")
assert.equal("Approved", mainFrame.requestDetailsStatusText:GetText(), "request details should refresh status after approval")
assert.equal("Approved for raid supplies", mainFrame.requestDetailsDecisionNoteText:GetText(), "request details should refresh the decision note after approval")
assert.equal(approvedRequest.approvedBy, mainFrame.requestDetailsApprovedByText:GetText(), "request details should refresh Approved By after approval")
assert.truthy(string.find(mainFrame.requestDetailsApprovedAtText:GetText() or "", "(Local)", 1, true) == nil, "request details should refresh Date Updated without the local suffix")
assert.truthy(not mainFrame.requestDetailsActionNoteLabel:IsShown(), "approved requests should not show a decision note editor")
assert.truthy(not mainFrame.requestDetailsActionNoteInput:IsShown(), "approved requests should not accept another decision note")
assert.truthy(not mainFrame.requestDetailsFulfillButton:IsShown(), "request details should remove manual fulfill from the workflow")
assert.equal(-366, point_y(mainFrame.requestDetailsCloseButton), "request details Close should stay on the workflow button row")
assert.equal(1, #(current_runtime_db().minimums or {}), "approving a request should immediately save a minimum rule")
assert.equal(243734, ((current_runtime_db().minimums or {})[1] or {}).itemID, "approval-created minimum should use the request item id")
assert.equal("Thalassian Phoenix Oil", ((current_runtime_db().minimums or {})[1] or {}).itemName, "approval-created minimum should use the request item name")
assert.equal(100, ((current_runtime_db().minimums or {})[1] or {}).quantity, "approval-created minimum should use the requested quantity")
assert.equal("Raid Buffer", ((current_runtime_db().minimums or {})[1] or {}).tabName, "approval-created minimum should use the selected bank tab")
assert.truthy(((current_runtime_db().minimums or {})[1] or {}).enabled == true, "approval-created minimum should be enabled")

mainFrame:OpenRequestDetailsModal("req-stale-tier")
assert.equal(TRUSTED_ITEM_LINKS[241326], mainFrame.requestDetailsItemNameText:GetText(), "request details should restore bundled trusted hyperlinks when stale saved request data lacks them")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", (mainFrame.requestDetailsQualityIcon or {}).atlas, "request details should restore the canonical higher two-rank quality icon after stale crafted-tier backfill")

mainFrame:OpenRequestDetailsModal("req-denied-note-hidden")
assert.equal("Rejected", mainFrame.requestDetailsStatusText:GetText(), "denied request details should show rejected status")
assert.equal("Not needed", mainFrame.requestDetailsDecisionNoteText:GetText(), "denied request details should still show the saved decision note")
assert.truthy(not mainFrame.requestDetailsActionNoteLabel:IsShown(), "denied requests should not show a decision note editor")
assert.truthy(not mainFrame.requestDetailsActionNoteInput:IsShown(), "denied requests should not accept another decision note")

table.insert((current_runtime_db().requests or {}), {
    requestId = "req-delete-target",
    requester = "RaiderDelete",
    requesterCharacterKey = "Stormrage-RaiderDelete",
    itemName = "Cleanup Flask",
    itemID = 990012,
    quantity = 9,
    approval = "REJECTED",
    fulfillment = "OPEN",
    note = "Remove after review",
    createdAt = 450,
})

_G.C_ChatInfo.sentMessages = {}
mainFrame:ShowDashboard()
mainFrame:SelectView("REQUESTS")
mainFrame:OpenRequestDetailsModal("req-delete-target")
assert.truthy(mainFrame.requestDetailsDeleteButton:IsShown(), "request admins should see a Delete action in request details when request-delete is allowed")
local requestDeleteCalls = capture_request_sync_calls(function()
    mainFrame.requestDetailsDeleteButton:GetScript("OnClick")(mainFrame.requestDetailsDeleteButton)
end)
assert.truthy(not mainFrame.requestDetailsModal:IsShown(), "deleting a request should close the request details modal")
assert.equal(nil, mainFrame:SelectRequestById("req-delete-target"), "deleting a request should remove it from the saved request list")
assert.equal(2, #requestDeleteCalls, "deleting a request should publish the request update plus the paired visible-history snapshot")
assert.equal("REQUEST_UPDATED", ((((requestDeleteCalls[1] or {}).message) or {}).type), "request delete sync should keep the request-updated message type")
assert.equal("DELETE", (((((requestDeleteCalls[1] or {}).message) or {}).payload or {}).action), "request delete sync should send a delete action payload")
assert.equal("GUILD", (requestDeleteCalls[1] or {}).distribution, "request delete sync should publish once to the guild addon audience")
assert.equal("GUILD", (requestDeleteCalls[1] or {}).target, "request delete sync should route through the guild addon audience target")
assert.equal("Guild Testers", (((((requestDeleteCalls[1] or {}).message) or {}).payload or {}).guildKey), "request delete sync should carry the active guild identity inside the payload envelope")
assert.equal("HISTORY_SNAPSHOT", ((((requestDeleteCalls[2] or {}).message) or {}).type), "request delete should also publish the visible-history snapshot family")

assert.equal("New Request", mainFrame.requestWorkflowCreateButton.labelText:GetText(), "request-only workflow should expose a wizard launch button")
mainFrame.requestWorkflowCreateButton:GetScript("OnClick")(mainFrame.requestWorkflowCreateButton)
assert.truthy(mainFrame.requestWizardModal:IsShown(), "request-only workflow create button should open the request wizard")
assert.truthy(mainFrame.requestWizardModal.mouseEnabled == true, "request wizard modal should block clicks from reaching the request table behind it")
assert.equal(3, #(mainFrame.requestWizardProgressCards or {}), "request wizard should expose a three-step progress rail")
assert.truthy(((mainFrame.requestWizardProgressCards or {})[1] or {}).gbmWizardActive == true, "request wizard should highlight the first progress step on open")
assert.truthy(not mainFrame.requestWizardPreviewPanel:IsShown(), "request wizard should keep the preview panel hidden on the initial selection step")
assert.truthy(not mainFrame.requestDetailsModal:IsShown(), "opening a new request wizard should close any request details modal")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(not mainFrame.requestDetailsModal:IsShown(), "request table row clicks should be ignored while the new request wizard is open")
assert.equal("Step 1 of 3: Choose Item", mainFrame.requestWizardStepText:GetText(), "request wizard should start on the item selection step")
assert.equal("Search for the item you would like stocked. Current expansion items only, no gear.", mainFrame.requestWizardStatusText:GetText(), "request wizard should explain current-expansion non-gear request scope")
assert.equal("Search Item ID", mainFrame.requestCreateItemIDLabel:GetText(), "requests view should clearly label the item-id search box")
assert.equal("Search Item Name", mainFrame.requestCreateItemNameLabel:GetText(), "requests view should clearly label the item-name search box")
assert.equal("Selected Item", mainFrame.requestCreateSelectedItemLabel:GetText(), "requests view should clearly label the selected item display")
assert.truthy(mainFrame.requestWizardNextButton.enabled == false, "request wizard should keep Next disabled until a catalog item is selected")

local originalGetRequestSearchSnapshot = mainFrame.GetRequestSearchSnapshot
local requestSearchSnapshotCalls = 0
function mainFrame:GetRequestSearchSnapshot()
    requestSearchSnapshotCalls = requestSearchSnapshotCalls + 1
    return originalGetRequestSearchSnapshot(self)
end

local requestPersistedSnapshot = mainFrame:GetCurrentSnapshot()
if type(requestPersistedSnapshot) == "table" then
    requestPersistedSnapshot.searchCatalog = nil
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
assert.equal(nil, (requestPersistedSnapshot or {}).searchCatalog, "requests view should not persist generated search catalogs onto the saved inventory snapshot")
mainFrame.GetRequestSearchSnapshot = originalGetRequestSearchSnapshot
mainFrame.requestCreateSearchSelector:ClearSelection()

mainFrame.requestCreateItemNameInput:SetText("Test Crafted ")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.equal("Test Crafted ", mainFrame.requestCreateItemNameInput:GetText(), "requests view should not overwrite an in-progress partial name search when whitespace is typed")
assert.equal("No item selected.", mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should wait for explicit selection on partial name matches")

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateItemNameInput:SetText("flask of")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should show a scrollable result panel for broad token queries")
assert.truthy(type(mainFrame.requestCreateSearchSelector.resultsScrollBox) == "table", "requests selector should expose a virtualized results scroll box")
assert.truthy(type(mainFrame.requestCreateSearchSelector.resultsDataProvider) == "table", "requests selector should expose a results data provider")
assert.truthy((mainFrame.requestCreateSearchSelector.resultsDataProvider:GetSize() or 0) > 0, "requests selector should populate the results data provider for broad searches")
assert.truthy((mainFrame.requestCreateSearchSelector.resultsScrollFrame or {}).scrollChild ~= nil, "requests view should wire a scroll child for result rows")
local requestBroadResultRow = (mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}
assert.truthy(tostring((requestBroadResultRow.itemText or {}):GetText() or "") ~= "", "request result rows should render shared item-display text for broad searches")
assert.truthy(string.find((requestBroadResultRow.itemText or {}):GetText() or "", tostring(((requestBroadResultRow.resolvedItem or {}).itemID or "")), 1, true) == nil, "request result rows should stop showing the item id inline once the shared item display owns the visible label")
assert.truthy(((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}):IsShown() == true), "request wizard result rows should show the shared item-display quality icon when crafted-quality metadata exists")

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateItemNameInput:SetText("flask of the shattered sun")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests search should show duplicate-name quality variants for the Shattered Sun family")
assert.equal(TRUSTED_ITEM_LINKS[241326], ((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).itemText or {}):GetText() or ""), "requests search should render the higher Shattered Sun variant through the shared hyperlink-style item display")
assert.equal(TRUSTED_ITEM_LINKS[241327], ((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).itemText or {}):GetText() or ""), "requests search should render the lower Shattered Sun variant through the shared hyperlink-style item display")
assert.equal(241326, tonumber((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).resolvedItem or {}).itemID or 0), "requests search should keep the higher two-rank Shattered Sun variant first")
assert.equal(241327, tonumber((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).resolvedItem or {}).itemID or 0), "requests search should keep the lower two-rank Shattered Sun variant second")
assert.equal(2, tonumber((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).resolvedItem or {}).craftedQualityFamilySize or 0), "request search results should carry two-rank family metadata for the higher Shattered Sun variant")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", ((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).resolvedItem or {}).craftedQualityDisplayAtlas or ""), "request search results should carry the canonical gold-pentagram display atlas")
assert.equal("Professions-Icon-Quality-12-Tier2-Inv", ((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}).atlas or ""), "requests search should show the canonical gold-pentagon icon for the higher Shattered Sun variant")
assert.equal("Professions-Icon-Quality-12-Tier1-Inv", ((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).qualityIcon or {}).atlas or ""), "requests search should show the canonical single-silver icon for the lower Shattered Sun variant")
assert.truthy(((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}):IsShown() == true), "requests search should show the shared item-display quality icon for the higher Shattered Sun variant")
assert.truthy(((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).qualityIcon or {}):IsShown() == true), "requests search should show the shared item-display quality icon for the lower Shattered Sun variant")
assert.truthy(string.find(((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).itemText or {}):GetText() or ""), "[T", 1, true) == nil, "requests search should not leak raw [Tn] tags into the visible Shattered Sun result label")
local selectedRequestVariantRow = mainFrame.requestCreateMatchButtons[2]
local selectedRequestVariantItem = selectedRequestVariantRow.resolvedItem
mainFrame.requestCreateMatchButtons[2]:GetScript("OnClick")(mainFrame.requestCreateMatchButtons[2])
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
assert.equal(tostring((selectedRequestVariantItem or {}).itemID or ""), mainFrame.requestCreateItemIDInput:GetText(), "requests view should preserve the explicitly selected duplicate-name item id after delayed input callbacks")
assert.equal(TRUSTED_ITEM_LINKS[(selectedRequestVariantItem or {}).itemID], mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should keep the selected item display on the shared hyperlink contract after delayed input callbacks")
assert.equal("Professions-Icon-Quality-12-Tier1-Inv", (mainFrame.requestCreateSelectedItemQualityIcon or {}).atlas, "requests view should keep the selected duplicate-name tier in the canonical single-silver two-rank family when lower ranks are chosen explicitly")
assert.truthy(mainFrame.requestCreateSelectedItemQualityIcon and mainFrame.requestCreateSelectedItemQualityIcon:IsShown(), "requests view should show the selected-item shared quality icon beside the selected item label")
assert.truthy(not mainFrame.requestCreateResultsPanel:IsShown(), "requests view should keep the matches panel hidden after a duplicate-name selection survives delayed input callbacks")
assert.truthy(mainFrame.requestWizardNextButton.enabled ~= false, "request wizard should keep Next enabled after delayed callbacks on a valid selection")

mainFrame.requestWizardNextButton:GetScript("OnClick")(mainFrame.requestWizardNextButton)
assert.equal("Step 2 of 3: Set Quantity", mainFrame.requestWizardStepText:GetText(), "request wizard should advance to quantity and reason")
assert.truthy(mainFrame.requestCreateQuantityInput:IsShown(), "request wizard step 2 should show quantity input")
assert.truthy(mainFrame.requestCreateNoteInput:IsShown(), "request wizard step 2 should show reason input")
assert.equal("Quantity", mainFrame.requestCreateQuantityLabel:GetText(), "request wizard should label the quantity field explicitly")
assert.equal("Reason", mainFrame.requestCreateNoteLabel:GetText(), "request wizard should label the reason field explicitly")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateQuantityLabel.parent, "request wizard should parent the quantity label inside the left content panel")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateNoteLabel.parent, "request wizard should parent the reason label inside the left content panel")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateQuantityInput.parent, "request wizard should parent the quantity input inside the left content panel")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateNoteInput.parent, "request wizard should parent the reason input inside the left content panel")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateQuantityDecreaseButton.parent, "request wizard should parent the decrement button inside the left content panel")
assert.same(mainFrame.requestWizardPrimaryPanel, mainFrame.requestCreateQuantityIncreaseButton.parent, "request wizard should parent the increment button inside the left content panel")
assert.equal(mainFrame.requestCreateQuantityDecreaseButton:GetWidth(), mainFrame.requestCreateQuantityIncreaseButton:GetWidth(), "request wizard quantity stepper buttons should share the same width")
assert.equal(mainFrame.requestCreateQuantityDecreaseButton:GetHeight(), mainFrame.requestCreateQuantityIncreaseButton:GetHeight(), "request wizard quantity stepper buttons should share the same height")
assert.truthy(mainFrame.requestWizardPreviewPanel:IsShown(), "request wizard should show the request preview after moving past item selection")
assert.truthy(((mainFrame.requestWizardProgressCards or {})[2] or {}).gbmWizardActive == true, "request wizard should move the active progress highlight to step two")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardBackButton.points[1] or {})[2], "request wizard Back should anchor inside the primary panel instead of the preview box")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardNextButton.points[1] or {})[2], "request wizard Next should anchor inside the primary panel instead of the preview box")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardCancelButton.points[1] or {})[2], "request wizard Cancel should anchor inside the primary panel instead of the preview box")
assert.equal("BOTTOMLEFT", (mainFrame.requestWizardBackButton.points[1] or {})[1], "request wizard Back should start from the left-side action rail")
assert.equal("BOTTOMLEFT", (mainFrame.requestWizardNextButton.points[1] or {})[1], "request wizard Next should share the same left action rail baseline")
assert.equal("BOTTOMLEFT", (mainFrame.requestWizardCancelButton.points[1] or {})[1], "request wizard Cancel should share the same left action rail baseline")
assert.truthy((((mainFrame.requestWizardNextButton.points[1] or {})[4] or 0) > (((mainFrame.requestWizardBackButton.points[1] or {})[4] or 0))), "request wizard Next should sit to the right of Back")
assert.truthy((((mainFrame.requestWizardCancelButton.points[1] or {})[4] or 0) > (((mainFrame.requestWizardNextButton.points[1] or {})[4] or 0))), "request wizard Cancel should sit to the right of Next")
mainFrame.requestCreateQuantityInput:SetText("4")
mainFrame.requestCreateQuantityIncreaseButton:GetScript("OnClick")(mainFrame.requestCreateQuantityIncreaseButton)
assert.equal("5", mainFrame.requestCreateQuantityInput:GetText(), "request wizard quantity increment should step the requested amount up")
mainFrame.requestCreateQuantityDecreaseButton:GetScript("OnClick")(mainFrame.requestCreateQuantityDecreaseButton)
assert.equal("4", mainFrame.requestCreateQuantityInput:GetText(), "request wizard quantity decrement should step the requested amount back down")
mainFrame.requestCreateNoteInput:SetText("Need four")
mainFrame.requestWizardNextButton:GetScript("OnClick")(mainFrame.requestWizardNextButton)
assert.equal("Step 3 of 3: Confirm Request", mainFrame.requestWizardStepText:GetText(), "request wizard should advance directly to review")
assert.truthy(((mainFrame.requestWizardProgressCards or {})[3] or {}).gbmWizardActive == true, "request wizard should move the active progress highlight to the review step")
assert.truthy(not mainFrame.requestWizardBankTabDropdownButton:IsShown(), "request wizard should remove the dedicated bank-tab step from the end-user flow")
assert.truthy(not mainFrame.requestWizardReviewItemNameLabel:IsShown(), "request wizard should not duplicate review detail labels under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewItemNameText:IsShown(), "request wizard should not duplicate review detail values under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewQualityLabel:IsShown(), "request wizard should remove the extra quality readback under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewQualityText:IsShown(), "request wizard should remove the extra quality value under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewQuantityLabel:IsShown(), "request wizard should remove the extra quantity readback under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewQuantityText:IsShown(), "request wizard should remove the extra quantity value under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewBankTabLabel:IsShown(), "request wizard should remove the extra bank-tab readback under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewBankTabText:IsShown(), "request wizard should remove the extra bank-tab value under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewReasonLabel:IsShown(), "request wizard should remove the extra reason readback under the progress rail")
assert.truthy(not mainFrame.requestWizardReviewReasonText:IsShown(), "request wizard should remove the extra reason value under the progress rail")
assert.equal(TRUSTED_ITEM_LINKS[241327], mainFrame.requestWizardPreviewItemText:GetText(), "request wizard preview should read back the selected item through the shared hyperlink-style item display")
assert.equal("Professions-Icon-Quality-12-Tier1-Inv", (mainFrame.requestWizardPreviewQualityIcon or {}).atlas, "request wizard preview should show the canonical single-silver icon for the selected lower two-rank variant")
assert.truthy(mainFrame.requestWizardPreviewQualityIcon and mainFrame.requestWizardPreviewQualityIcon:IsShown(), "request wizard preview should show the selected item quality icon beside the shared item display")
assert.equal("4", mainFrame.requestWizardPreviewRequestedQuantityText:GetText(), "request wizard preview should read back quantity")
assert.equal("Need four", mainFrame.requestWizardPreviewReasonText:GetText(), "request wizard preview should read back reason")
assert.truthy(mainFrame.requestWizardPreviewSuggestedMinimumText == nil or not mainFrame.requestWizardPreviewSuggestedMinimumText:IsShown(), "request wizard should remove Suggested Minimum from the preview")
assert.truthy(mainFrame.requestWizardPreviewBankTabText == nil or not mainFrame.requestWizardPreviewBankTabText:IsShown(), "request wizard preview should not expose a bank-tab field after that step is removed")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardBackButton.points[1] or {})[2], "request wizard Back should stay in the left action rail on review")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardSubmitButton.points[1] or {})[2], "request wizard Submit should stay in the left action rail on review")
assert.same(mainFrame.requestWizardPrimaryPanel, (mainFrame.requestWizardCancelButton.points[1] or {})[2], "request wizard Cancel should stay in the left action rail on review")
assert.equal("BOTTOMLEFT", (mainFrame.requestWizardSubmitButton.points[1] or {})[1], "request wizard Submit should share the same left action rail baseline on review")
assert.equal("BOTTOMLEFT", (mainFrame.requestWizardCancelButton.points[1] or {})[1], "request wizard Cancel should share the same left action rail baseline on review")
assert.truthy((((mainFrame.requestWizardSubmitButton.points[1] or {})[4] or 0) > (((mainFrame.requestWizardBackButton.points[1] or {})[4] or 0))), "request wizard Submit should sit to the right of Back on review")
assert.truthy((((mainFrame.requestWizardCancelButton.points[1] or {})[4] or 0) > (((mainFrame.requestWizardSubmitButton.points[1] or {})[4] or 0))), "request wizard Cancel should sit to the right of Submit on review")
_G.GetNumGuildMembers = function()
    return 3
end
_G.GetGuildRosterInfo = function(index)
    if index == 1 then
        return "GuildLead-Stormrage", "Guild Master", 0, 70, "Paladin", "Orgrimmar", "", "", true, 0, nil, 0, 0, false, false, nil, "guid-guildlead"
    end

    if index == 2 then
        return "OfficerOne-Stormrage", "Officer", 1, 70, "Mage", "Orgrimmar", "", "", true, 0, nil, 0, 0, false, false, nil, "guid-officer"
    end

    return "MemberOne-Stormrage", "Raider", 2, 70, "Warrior", "Orgrimmar", "", "", true, 0, nil, 0, 0, false, false, nil, "guid-member"
end
_G.C_ChatInfo.sentMessages = {}
local requestCreateCalls = capture_request_sync_calls(function()
    mainFrame.requestWizardSubmitButton:GetScript("OnClick")(mainFrame.requestWizardSubmitButton)
end)
assert.truthy(not mainFrame.requestWizardModal:IsShown(), "request wizard should close after submit")
local createdRequest = ((current_runtime_db().requests or {})[#(current_runtime_db().requests or {})] or {})
assert.equal("PENDING", createdRequest.approval, "wizard-created requests should remain pending")
assert.equal(TRUSTED_ITEM_LINKS[241327], createdRequest.itemLink, "wizard-created requests should persist the trusted hyperlink for later shared item-display surfaces")
assert.equal(trusted_item_string(241327), createdRequest.itemString, "wizard-created requests should persist the trusted item string for later shared item-display surfaces")
assert.equal(2, tonumber(createdRequest.craftedQualityFamilySize or 0), "wizard-created requests should persist two-rank crafted-quality family metadata for request table rendering")
assert.equal("Professions-Icon-Quality-12-Tier1-Inv", createdRequest.craftedQualityDisplayAtlas, "wizard-created requests should persist the canonical single-silver display atlas for lower two-rank variants")
assert.truthy(createdRequest.tabName == nil or createdRequest.tabName == "", "wizard-created requests should no longer require a preferred bank tab from a removed wizard step")
assert.equal(nil, mainFrame.selectedRequestId, "creating a request should not leave the new request row highlighted in the officer table by default")
assert.equal(2, #requestCreateCalls, "wizard submit should publish the request sync plus the paired visible-history snapshot")
assert.equal("REQUEST_CREATED", (((requestCreateCalls[1] or {}).message) or {}).type, "wizard submit should send a request-created sync payload")
assert.equal("GUILD", (requestCreateCalls[1] or {}).distribution, "wizard submit should publish once to the guild addon audience")
assert.equal("GUILD", (requestCreateCalls[1] or {}).target, "wizard submit should route through the guild addon audience target")
assert.equal("Guild Testers", (((((requestCreateCalls[1] or {}).message) or {}).payload or {}).guildKey), "wizard submit should stamp outbound request sync with the active guild key")
assert.equal("HISTORY_SNAPSHOT", (((requestCreateCalls[2] or {}).message) or {}).type, "wizard submit should also publish the visible-history snapshot family")

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

local permissions = env.ns.modules.permissions
local originalRefreshPolicyFromGuild = permissions.RefreshPolicyFromGuild
permissions.RefreshPolicyFromGuild = function(db)
    db.auth.blacklist = db.auth.blacklist or {}
    db.auth.blacklist["OfficerOne-Stormrage"] = {
        name = "OfficerOne",
        updatedAt = 999,
    }
    return db.auth
end
mainFrame.requestCreateItemIDInput:SetText("990001")
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
mainFrame.requestCreateQuantityInput:SetText("4")
mainFrame.requestCreateNoteInput:SetText("Need four")
local blacklistedRequest = mainFrame:CreateRequestFromEditor()
assert.truthy(blacklistedRequest == nil, "requests view should reparse guild blacklist state before creating a request")
assert.equal("You do not have permission to submit requests.", mainFrame.requestCreateStatusText:GetText(), "requests view should deny request creation when the refreshed guild policy marks the actor as blacklisted")
permissions.RefreshPolicyFromGuild = originalRefreshPolicyFromGuild

local onboardingEnv = fixture.load()
local onboardingMainFrame = onboardingEnv.mainFrame

assert.truthy(type(onboardingMainFrame.OpenOnboarding) == "function", "main frame should expose onboarding open behavior for request-only users")
assert.truthy(type(onboardingMainFrame.RunOnboardingPrimaryAction) == "function", "main frame should expose onboarding primary actions for request-only users")
assert.truthy(type(onboardingMainFrame.AdvanceOnboardingStep) == "function", "main frame should expose onboarding advance behavior for request-only users")

local onboardingModal = onboardingMainFrame:OpenOnboarding("requestOnly", {
    auto = false,
    reason = "spec_request_only",
})

assert.same(onboardingMainFrame.onboardingModal, onboardingModal, "request-only onboarding should reuse the shared onboarding modal")
assert.truthy(onboardingMainFrame.onboardingModal and onboardingMainFrame.onboardingModal:IsShown(), "request-only onboarding should show its modal shell")
assert.equal("REQUESTS", onboardingMainFrame.activeView, "request-only onboarding should stay on the requests view")
assert.equal(true, onboardingMainFrame.requestOnlyMode == true, "request-only onboarding should keep the compact request surface active")
assert.truthy(onboardingMainFrame.requestWorkflowPanel and onboardingMainFrame.requestWorkflowPanel:IsShown(), "request-only onboarding should keep the compact request workflow panel visible")
assert.truthy(not (onboardingMainFrame.requestAdminFilterPanel and onboardingMainFrame.requestAdminFilterPanel:IsShown()), "request-only onboarding should not promote the user into the manager request surface")

onboardingMainFrame:AdvanceOnboardingStep()
assert.equal("request_flow", (onboardingMainFrame.onboardingCurrentStep or {}).id, "request-only onboarding should advance to the request flow step")
onboardingMainFrame:RunOnboardingPrimaryAction()

assert.equal("REQUESTS", onboardingMainFrame.activeView, "request flow onboarding should remain on the requests view")
assert.equal(true, onboardingMainFrame.requestOnlyMode == true, "request flow onboarding should preserve request-only mode")
assert.truthy(onboardingMainFrame.requestWizardModal and onboardingMainFrame.requestWizardModal:IsShown(), "request flow onboarding should launch the request wizard from the compact request surface")
