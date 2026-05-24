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
    },
    {
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
    },
    {
        requestId = "req-approve-bank-tab",
        requester = "RaiderThree",
        requesterCharacterKey = "Stormrage-RaiderThree",
        itemName = "Thalassian Phoenix Oil",
        itemID = 243734,
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        quantity = 100,
        approval = "PENDING",
        fulfillment = "OPEN",
        note = "We should have better oil",
        createdAt = 300,
    },
    {
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
    },
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
assert.equal("BOTTOMRIGHT", (mainFrame.requestAdminFilterPendingFulfillmentButton.points[1] or {})[1], "request admin rightmost filter should anchor from the right edge")
assert.equal("RIGHT", (mainFrame.requestAdminFilterPendingApprovalButton.points[1] or {})[1], "request admin middle filter should chain left from the rightmost filter")
assert.equal("RIGHT", (mainFrame.requestAdminFilterCompletedButton.points[1] or {})[1], "request admin Completed filter should chain left from the rightmost filter")
assert.equal("RIGHT", (mainFrame.requestAdminFilterPendingApprovalButton.points[1] or {})[1], "request admin Pending Approval should chain left from Completed")
assert.equal("RIGHT", (mainFrame.requestAdminFilterAllButton.points[1] or {})[1], "request admin All filter should chain left from Pending Approval")
assert.equal("Date Requested", mainFrame.tableHeaderLabels[1]:GetText(), "request admin table should expose the request date")
assert.equal("Requestor", mainFrame.tableHeaderLabels[2]:GetText(), "request admin table should expose Requestor")
assert.equal("Item ID", mainFrame.tableHeaderLabels[3]:GetText(), "request admin table should expose Item ID")
assert.equal("Item Name", mainFrame.tableHeaderLabels[4]:GetText(), "request admin table should expose item name")
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
assert.equal("990001", mainFrame.tableRowsData[1].itemID, "request admin rows should include item id")
assert.equal("Raid Flask", mainFrame.tableRowsData[1].itemName, "request admin rows should include item name")
assert.equal("Pending", mainFrame.tableRowsData[1].status, "request admin rows should expose a readable combined status")
assert.equal(4, #mainFrame.tableRowsData, "request admin All filter should include fulfilled and rejected requests")
mainFrame.requestAdminFilterPendingApprovalButton:GetScript("OnClick")(mainFrame.requestAdminFilterPendingApprovalButton)
assert.truthy(mainFrame.requestAdminFilterPendingApprovalButton.filterActive == true, "request admin should highlight Pending Approval when selected")
assert.truthy(mainFrame.requestAdminFilterAllButton.filterActive ~= true, "request admin should clear the All highlight when another filter is selected")
assert.equal(2, #mainFrame.tableRowsData, "request admin Pending Approval should only show pending requests")
assert.equal((activeTheme.colors.accentStrong or {})[1], (mainFrame.requestAdminFilterPendingApprovalButton.backdropBorderColor or {})[1], "request admin should move the stronger glow to the newly selected filter")
mainFrame.requestAdminFilterPendingFulfillmentButton:GetScript("OnClick")(mainFrame.requestAdminFilterPendingFulfillmentButton)
assert.truthy(mainFrame.requestAdminFilterPendingFulfillmentButton.filterActive == true, "request admin should highlight Pending Fulfillment when selected")
assert.equal(1, #mainFrame.tableRowsData, "request admin Pending Fulfillment should only show approved open requests")
mainFrame.requestAdminFilterCompletedButton:GetScript("OnClick")(mainFrame.requestAdminFilterCompletedButton)
assert.truthy(mainFrame.requestAdminFilterCompletedButton.filterActive == true, "request admin should highlight Completed when selected")
assert.equal(1, #mainFrame.tableRowsData, "request admin Completed should show closed-out requests")
assert.equal("Denied Flask", mainFrame.tableRowsData[1].itemName, "request admin Completed should surface the completed or rejected request row")
mainFrame.requestAdminFilterAllButton:GetScript("OnClick")(mainFrame.requestAdminFilterAllButton)
assert.equal(4, #mainFrame.tableRowsData, "request admin All should restore the full admin list")
mainFrame.requestAdminAddButton:GetScript("OnClick")(mainFrame.requestAdminAddButton)
assert.truthy(mainFrame.requestWizardModal:IsShown(), "request admin Add should launch the shared request wizard")
mainFrame.requestWizardCancelButton:GetScript("OnClick")(mainFrame.requestWizardCancelButton)
mainFrame.tableFilterInputs[4]:SetText("Arcane")
mainFrame.tableFilterInputs[4]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[4])
assert.equal(1, #mainFrame.tableRowsData, "request admin shared filters should search by item name")
assert.equal("Arcane Oil", mainFrame.tableRowsData[1].itemName, "request admin item-name filter should keep the matching row")
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
assert.truthy(not mainFrame.sidebar:IsShown(), "request-only mode should hide the sidebar")
assert.same(mainFrame.viewSubtitle, (mainFrame.requestWorkflowPanel.points[1] or {})[2], "request-only mode should place the request workflow directly below the request subtitle")
assert.equal("Guild Bank Manager", mainFrame.titleText:GetText(), "request-only header should keep the addon title visible")
assert.truthy(mainFrame.titleText:IsShown(), "request-only header should show the addon title")
assert.truthy((mainFrame:GetWidth() or 0) < 1040, "request-only window should be slightly smaller than the full officer shell")
assert.truthy((mainFrame:GetHeight() or 0) < 640, "request-only window should be slightly shorter than the full officer shell")
assert.equal("action-slim", mainFrame.requestWorkflowCreateButton.gbmButtonFamily, "request-only launcher should use the slimmer action family")
assert.equal("primary", mainFrame.requestWorkflowCreateButton.gbmButtonVariant, "request-only launcher should use the shared primary CTA styling")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "request-only workflow should start with item id")
assert.equal("Item Name", mainFrame.tableHeaderLabels[2]:GetText(), "request-only workflow should include the requested item name")
assert.equal("Quantity", mainFrame.tableHeaderLabels[3]:GetText(), "request-only workflow should include quantity")
assert.equal("Status", mainFrame.tableHeaderLabels[4]:GetText(), "request-only workflow should expose combined status")
assert.equal("990001", mainFrame.tableRowsData[1].itemID, "request-only rows should include item id")
assert.equal("Raid Flask", mainFrame.tableRowsData[1].itemName, "request-only rows should include item name")
assert.equal("5", mainFrame.tableRowsData[1].quantity, "request-only rows should include quantity")
assert.equal("Pending", mainFrame.tableRowsData[1].status, "request-only rows should include status")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.requestDetailsModal:IsShown(), "clicking a request row should open the shared request details modal")
assert.equal("modal-sheet", mainFrame.requestDetailsModal.gbmSurfaceVariant, "request details should use the cleaner floating-sheet surface")
assert.truthy(mainFrame.requestDetailsModal.mouseEnabled == true, "request details modal should block clicks from reaching the request table behind it")
assert.truthy((mainFrame.requestDetailsModal.frameLevel or 0) > (mainFrame.frameLevel or 0), "request details modal should render above table rows")
assert.equal("Raid Flask", mainFrame.requestDetailsItemNameText:GetText(), "request details should show item name")
assert.equal("|A:Professions-ChatIcon-Quality-Tier5:22:22|a", mainFrame.requestDetailsQualityText:GetText(), "request details should show crafted quality")
assert.equal("5", mainFrame.requestDetailsQuantityText:GetText(), "request details should show quantity")
assert.equal("Raid night", mainFrame.requestDetailsSubmissionNoteText:GetText(), "request details should show submission note")
assert.equal("Pending", mainFrame.requestDetailsStatusText:GetText(), "request details should show readable status")
assert.truthy(type(mainFrame.requestDetailsApprovedByText) == "table", "request details should expose Approved By")
assert.equal("-", mainFrame.requestDetailsApprovedByText:GetText(), "pending request details should show no approver")
assert.truthy(type(mainFrame.requestDetailsApprovedAtText) == "table", "request details should expose Date Approved")
assert.equal("-", mainFrame.requestDetailsApprovedAtText:GetText(), "pending request details should show no approval date")
assert.truthy(string.find(mainFrame.requestDetailsRequestedAtText:GetText() or "", "(Local)", 1, true) == nil, "request details should remove the local suffix from dates")
assert.equal("Requested By", mainFrame.requestDetailsRequesterLabel:GetText(), "request details should show who requested the item")
assert.equal("OfficerOne", mainFrame.requestDetailsRequesterText:GetText(), "request details should show the requester above Date Requested")
assert.equal("select", mainFrame.requestDetailsBankTabDropdownButton.gbmButtonVariant, "request details bank-tab chooser should use the shared select control styling")
assert.truthy(color_distance(((mainFrame.requestDetailsBankTabDropdownButton.gbmArt or {}).innerFill or {}).color, ((mainFrame.requestDetailsModal.gbmArt or {}).innerFill or {}).color) >= 0.10, "request details bank-tab chooser should contrast from the modal background")
assert.equal("Updated By", mainFrame.requestDetailsApprovedByLabel:GetText(), "request details should use Updated By instead of Approved By")
assert.equal("Date Updated", mainFrame.requestDetailsApprovedAtLabel:GetText(), "request details should use Date Updated instead of Date Approved")
assert.equal(160, (mainFrame.requestDetailsItemNameText.points[1] or {})[4], "request details values should sit closer to labels")
assert_aligned(mainFrame.requestDetailsItemNameLabel, mainFrame.requestDetailsItemNameText, "item name")
assert_aligned(mainFrame.requestDetailsQualityLabel, mainFrame.requestDetailsQualityText, "quality")
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
assert.truthy(mainFrame.requestDetailsCancelRequestButton:IsShown(), "request authors should see cancel in details for pending requests")
assert.truthy(not ((mainFrame.requestDetailsDeleteButton and mainFrame.requestDetailsDeleteButton:IsShown()) == true), "request-only authors should not see request delete in details")
mainFrame.requestDetailsCloseButton:GetScript("OnClick")(mainFrame.requestDetailsCloseButton)

mainFrame:ShowDashboard()
mainFrame:SelectView("REQUESTS")
mainFrame:OpenRequestDetailsModal("req-approve-bank-tab")
assert.truthy(mainFrame.requestDetailsModal:IsShown(), "admin approval should use the shared details modal")
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
assert.equal(1, #_G.GBankManagerDB.minimums, "approving a request should immediately save a minimum rule")
assert.equal(243734, _G.GBankManagerDB.minimums[1].itemID, "approval-created minimum should use the request item id")
assert.equal("Thalassian Phoenix Oil", _G.GBankManagerDB.minimums[1].itemName, "approval-created minimum should use the request item name")
assert.equal(100, _G.GBankManagerDB.minimums[1].quantity, "approval-created minimum should use the requested quantity")
assert.equal("Raid Buffer", _G.GBankManagerDB.minimums[1].tabName, "approval-created minimum should use the selected bank tab")
assert.truthy(_G.GBankManagerDB.minimums[1].enabled == true, "approval-created minimum should be enabled")

mainFrame:OpenRequestDetailsModal("req-denied-note-hidden")
assert.equal("Rejected", mainFrame.requestDetailsStatusText:GetText(), "denied request details should show rejected status")
assert.equal("Not needed", mainFrame.requestDetailsDecisionNoteText:GetText(), "denied request details should still show the saved decision note")
assert.truthy(not mainFrame.requestDetailsActionNoteLabel:IsShown(), "denied requests should not show a decision note editor")
assert.truthy(not mainFrame.requestDetailsActionNoteInput:IsShown(), "denied requests should not accept another decision note")

table.insert(_G.GBankManagerDB.requests, {
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
mainFrame.requestDetailsDeleteButton:GetScript("OnClick")(mainFrame.requestDetailsDeleteButton)
assert.truthy(not mainFrame.requestDetailsModal:IsShown(), "deleting a request should close the request details modal")
assert.equal(nil, mainFrame:SelectRequestById("req-delete-target"), "deleting a request should remove it from the saved request list")
assert.equal(1, #_G.C_ChatInfo.sentMessages, "deleting a request should sync the request update to guild clients")
assert.truthy(string.find(_G.C_ChatInfo.sentMessages[1].payload or "", "DELETE", 1, true) ~= nil, "request delete sync should send a delete action payload")

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
assert.truthy(mainFrame.requestWizardNextButton.enabled ~= false, "request wizard should enable Next after a catalog item is selected")

mainFrame.requestCreateItemNameInput:SetText("flask of")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.equal("", mainFrame.requestCreateItemIDInput:GetText(), "requests view should clear the stale item-id field when a broader name search invalidates the prior selection")
assert.equal("No item selected.", mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should clear the selected item display when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should reopen the matches panel when a broader name search invalidates the prior selection")
assert.truthy(mainFrame.requestCreateSearchSelector.resultsScrollController ~= nil, "requests view should use the shared shell scroll controller for result rows")
assert.truthy(mainFrame.requestCreateSearchSelector.resultsScrollBar ~= nil, "requests view should expose the shared shell scrollbar for result rows")
assert.truthy(mainFrame.requestWizardNextButton.enabled == false, "request wizard should disable Next again when a broader search clears the confirmed selection")

mainFrame.requestCreateSearchSelector:ClearSelection()
mainFrame.requestCreateItemNameInput:SetText("test variant flask")
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
assert.truthy(mainFrame.requestCreateResultsPanel:IsShown(), "requests view should keep duplicate-name quality variants in the results list")
assert.equal("[T5]", ((((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).tierText or {}):GetText() or ""), "requests result rows should show the higher crafted tier first for duplicate-name variants")
assert.equal("[T2]", ((((mainFrame.requestCreateSearchSelector.resultRows or {})[2] or {}).tierText or {}):GetText() or ""), "requests result rows should keep lower crafted tiers visible as separate entries")
assert.equal("Professions-ChatIcon-Quality-Tier5", (((mainFrame.requestCreateSearchSelector.resultRows or {})[1] or {}).qualityIcon or {}).atlas, "requests result rows should show the crafted quality icon for the higher-tier entry")
local selectedRequestVariantRow = mainFrame.requestCreateMatchButtons[2]
local selectedRequestVariantItem = selectedRequestVariantRow.resolvedItem
mainFrame.requestCreateMatchButtons[2]:GetScript("OnClick")(mainFrame.requestCreateMatchButtons[2])
mainFrame.requestCreateItemNameInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemNameInput)
mainFrame.requestCreateItemIDInput:GetScript("OnTextChanged")(mainFrame.requestCreateItemIDInput)
assert.equal(tostring((selectedRequestVariantItem or {}).itemID or ""), mainFrame.requestCreateItemIDInput:GetText(), "requests view should preserve the explicitly selected duplicate-name item id after delayed input callbacks")
assert.equal(tostring((selectedRequestVariantItem or {}).name or (selectedRequestVariantItem or {}).itemName or ""), mainFrame.requestCreateSelectedItemNameText:GetText(), "requests view should keep the selected item display after delayed input callbacks")
assert.equal("Professions-ChatIcon-Quality-Tier2", mainFrame.requestCreateSelectedItemQualityIcon.atlas, "requests view should keep the selected duplicate-name tier after delayed input callbacks")
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
assert.equal("Test Variant Flask", mainFrame.requestWizardPreviewItemText:GetText(), "request wizard preview should read back item name")
assert.equal("|A:Professions-ChatIcon-Quality-Tier2:22:22|a", mainFrame.requestWizardPreviewQualityText:GetText(), "request wizard preview should normalize two-rank quality icons to the shared visible icon family")
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
_G.C_ChatInfo.sentMessages = {}
mainFrame.requestWizardSubmitButton:GetScript("OnClick")(mainFrame.requestWizardSubmitButton)
assert.truthy(not mainFrame.requestWizardModal:IsShown(), "request wizard should close after submit")
assert.equal("PENDING", _G.GBankManagerDB.requests[#_G.GBankManagerDB.requests].approval, "wizard-created requests should remain pending")
assert.truthy(_G.GBankManagerDB.requests[#_G.GBankManagerDB.requests].tabName == nil or _G.GBankManagerDB.requests[#_G.GBankManagerDB.requests].tabName == "", "wizard-created requests should no longer require a preferred bank tab from a removed wizard step")
assert.equal(1, #_G.C_ChatInfo.sentMessages, "wizard submit should sync the created request to guild clients")
assert.truthy(string.find(_G.C_ChatInfo.sentMessages[1].payload or "", "REQUEST_CREATED", 1, true) ~= nil, "wizard submit should send a request-created sync payload")

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
