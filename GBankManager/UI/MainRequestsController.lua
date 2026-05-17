local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainRequestsController = ns.modules.mainRequestsController or {}

local function current_db()
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    return ns.state.db or {}
end

local function current_context(db)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetLivePlayerContext) == "function" then
        return auth.GetLivePlayerContext(db)
    end

    return {}
end

local function current_policy(db)
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetAuthPolicy) == "function" then
        return store.GetAuthPolicy(db)
    end

    return (db or {}).auth or {}
end

local function can(context, capability, policy)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.Can) == "function" then
        return auth.Can(context, capability, policy)
    end

    return true
end

local function access_profile(context, policy)
    local auth = ns.modules.auth or ns.modules.permissions
    if auth and type(auth.GetEffectiveAccessProfile) == "function" then
        return auth.GetEffectiveAccessProfile(context, policy)
    end

    return "full_shell"
end

local function actor_summary(context)
    local name = tostring((context or {}).name or "Unknown")
    local rankName = tostring((context or {}).guildRankName or "")
    if rankName ~= "" then
        return string.format("Acting As: %s (%s)", name, rankName)
    end

    return string.format("Acting As: %s", name)
end

local function crafted_quality_markup(atlasName)
    if atlasName == nil or atlasName == "" then
        return "-"
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function actor_owns_request(request, actor)
    request = request or {}
    actor = type(actor) == "table" and actor or {}
    local actorKey = tostring(actor.characterKey or "")
    local requesterKey = tostring(request.requesterCharacterKey or "")
    if actorKey ~= "" and requesterKey ~= "" then
        return actorKey == requesterKey
    end

    local actorName = tostring(actor.name or "")
    local requesterName = tostring(request.requester or "")
    return actorName ~= "" and requesterName ~= "" and actorName == requesterName
end

local function format_request_status(request)
    local requestsView = ns.modules.requestsView
    if requestsView and type(requestsView.FormatStatus) == "function" then
        return requestsView.FormatStatus(request)
    end

    return tostring((request or {}).approval or "UNKNOWN")
end

local function format_request_time(request)
    local requestsView = ns.modules.requestsView
    if requestsView and type(requestsView.FormatLocalTimestamp) == "function" then
        return requestsView.FormatLocalTimestamp((request or {}).createdAt)
    end

    return tostring((request or {}).createdAt or "-")
end

local function format_timestamp(timestamp)
    if timestamp == nil or timestamp == "" then
        return "-"
    end

    local requestsView = ns.modules.requestsView
    if requestsView and type(requestsView.FormatLocalTimestamp) == "function" then
        return requestsView.FormatLocalTimestamp(timestamp)
    end

    return tostring(timestamp or "-")
end

local function set_shown(frame, shown)
    if not frame then
        return
    end

    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

function mainRequestsController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local createItemSearchSelector = options.createItemSearchSelector
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local theme = options.theme or {}
    local parseNumber = options.parseNumber

    mainFrame.requestActionsPanel = mainFrame.requestActionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestActionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.requestActionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestActionsPanel:SetHeight(116)
    applyPanelStyle(mainFrame.requestActionsPanel, theme.colors.panel)
    mainFrame.requestActionsPanel:Hide()

    mainFrame.requestActionsTitle = mainFrame.requestActionsTitle or makeLabel(mainFrame.requestActionsPanel, "Workflow Actions", "GameFontHighlight")
    mainFrame.requestActionsTitle:SetPoint("TOPLEFT", mainFrame.requestActionsPanel, "TOPLEFT", 16, -16)

    mainFrame.requestActionHint = mainFrame.requestActionHint or makeLabel(mainFrame.requestActionsPanel, "Select a request, then approve, reject, fulfill, or reopen it.", "GameFontHighlightSmall")
    mainFrame.requestActionHint:SetPoint("TOPLEFT", mainFrame.requestActionsTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.requestApproveButton = mainFrame.requestApproveButton or makeButton(mainFrame.requestActionsPanel, 78, 28, "Approve")
    mainFrame.requestApproveButton:SetPoint("TOPLEFT", mainFrame.requestActionHint, "BOTTOMLEFT", 0, -16)

    mainFrame.requestRejectButton = mainFrame.requestRejectButton or makeButton(mainFrame.requestActionsPanel, 72, 28, "Reject")
    mainFrame.requestRejectButton:SetPoint("LEFT", mainFrame.requestApproveButton, "RIGHT", 8, 0)

    mainFrame.requestFulfillButton = mainFrame.requestFulfillButton or makeButton(mainFrame.requestActionsPanel, 72, 28, "Fulfill")
    mainFrame.requestFulfillButton:SetPoint("LEFT", mainFrame.requestRejectButton, "RIGHT", 8, 0)

    mainFrame.requestReopenButton = mainFrame.requestReopenButton or makeButton(mainFrame.requestActionsPanel, 72, 28, "Reopen")
    mainFrame.requestReopenButton:SetPoint("LEFT", mainFrame.requestFulfillButton, "RIGHT", 8, 0)

    mainFrame.requestActionNoteInput = mainFrame.requestActionNoteInput or makeInput(mainFrame.requestActionsPanel, 248, 22)
    mainFrame.requestActionNoteInput:SetPoint("LEFT", mainFrame.requestReopenButton, "RIGHT", 12, 0)
    mainFrame.requestActionNoteLabel = mainFrame.requestActionNoteLabel or makeLabel(mainFrame.requestActionsPanel, "Decision Note", "GameFontHighlightSmall")
    mainFrame.requestActionNoteLabel:SetPoint("BOTTOMLEFT", mainFrame.requestActionNoteInput, "TOPLEFT", 0, 4)
    mainFrame.requestActionStatusText = mainFrame.requestActionStatusText or makeLabel(mainFrame.requestActionsPanel, "", "GameFontHighlightSmall")
    mainFrame.requestActionStatusText:SetPoint("TOPLEFT", mainFrame.requestApproveButton, "BOTTOMLEFT", 0, -8)

    mainFrame.requestAdminFilterPanel = mainFrame.requestAdminFilterPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestAdminFilterPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.requestAdminFilterPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestAdminFilterPanel:SetHeight(64)
    mainFrame.requestAdminFilterPanel.transparentActions = true
    if type(mainFrame.requestAdminFilterPanel.SetBackdrop) == "function" then
        mainFrame.requestAdminFilterPanel:SetBackdrop(nil)
    end
    mainFrame.requestAdminFilterPanel:Hide()

    mainFrame.requestAdminFilterMode = mainFrame.requestAdminFilterMode or "ALL"
    mainFrame.requestAdminFilterAllButton = mainFrame.requestAdminFilterAllButton or makeButton(mainFrame.requestAdminFilterPanel, 64, 28, "All")
    mainFrame.requestAdminFilterAllButton:SetPoint("BOTTOMLEFT", mainFrame.requestAdminFilterPanel, "BOTTOMLEFT", 16, 30)
    mainFrame.requestAdminFilterPendingApprovalButton = mainFrame.requestAdminFilterPendingApprovalButton or makeButton(mainFrame.requestAdminFilterPanel, 134, 28, "Pending Approval")
    mainFrame.requestAdminFilterPendingApprovalButton:SetPoint("LEFT", mainFrame.requestAdminFilterAllButton, "RIGHT", 8, 0)
    mainFrame.requestAdminFilterPendingFulfillmentButton = mainFrame.requestAdminFilterPendingFulfillmentButton or makeButton(mainFrame.requestAdminFilterPanel, 152, 28, "Pending Fulfillment")
    mainFrame.requestAdminFilterPendingFulfillmentButton:SetPoint("LEFT", mainFrame.requestAdminFilterPendingApprovalButton, "RIGHT", 8, 0)

    mainFrame.requestWorkflowPanel = mainFrame.requestWorkflowPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestWorkflowPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.requestWorkflowPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestWorkflowPanel:SetHeight(72)
    applyPanelStyle(mainFrame.requestWorkflowPanel, theme.colors.panel)
    mainFrame.requestWorkflowPanel:Hide()

    mainFrame.requestWorkflowTitle = mainFrame.requestWorkflowTitle or makeLabel(mainFrame.requestWorkflowPanel, "My Requests", "GameFontHighlight")
    mainFrame.requestWorkflowTitle:SetPoint("TOPLEFT", mainFrame.requestWorkflowPanel, "TOPLEFT", 16, -14)

    mainFrame.requestWorkflowHint = mainFrame.requestWorkflowHint or makeLabel(mainFrame.requestWorkflowPanel, "Track your request statuses or start a new request.", "GameFontHighlightSmall")
    mainFrame.requestWorkflowHint:SetPoint("TOPLEFT", mainFrame.requestWorkflowTitle, "BOTTOMLEFT", 0, -6)

    mainFrame.requestWorkflowCreateButton = mainFrame.requestWorkflowCreateButton or makeButton(mainFrame.requestWorkflowPanel, 104, 28, "New Request")
    mainFrame.requestWorkflowCreateButton:SetPoint("RIGHT", mainFrame.requestWorkflowPanel, "RIGHT", -16, 0)

    mainFrame.requestWizardModal = mainFrame.requestWizardModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestWizardModal:SetSize(500, 300)
    mainFrame.requestWizardModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.requestWizardModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.requestWizardModal.SetFrameStrata) == "function" then
        mainFrame.requestWizardModal:SetFrameStrata(mainFrame.requestWizardModal.frameStrata)
    end
    mainFrame.requestWizardModal.frameLevel = (mainFrame.frameLevel or 0) + 22
    if type(mainFrame.requestWizardModal.SetFrameLevel) == "function" then
        mainFrame.requestWizardModal:SetFrameLevel(mainFrame.requestWizardModal.frameLevel)
    end
    mainFrame.requestWizardModal:EnableMouse(true)
    applyPanelStyle(mainFrame.requestWizardModal, theme.colors.panelAlt)
    if type(mainFrame.requestWizardModal.SetBackdropColor) == "function" then
        mainFrame.requestWizardModal:SetBackdropColor(0, 0, 0, 1)
    end
    mainFrame.requestWizardModal:Hide()

    mainFrame.requestWizardTitle = mainFrame.requestWizardTitle or makeLabel(mainFrame.requestWizardModal, "New Request", "GameFontHighlight")
    mainFrame.requestWizardTitle:SetPoint("TOPLEFT", mainFrame.requestWizardModal, "TOPLEFT", 16, -16)

    mainFrame.requestWizardStepText = mainFrame.requestWizardStepText or makeLabel(mainFrame.requestWizardModal, "Step 1 of 3: Choose Item", "GameFontHighlightSmall")
    mainFrame.requestWizardStepText:SetPoint("TOPLEFT", mainFrame.requestWizardTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.requestWizardStatusText = mainFrame.requestWizardStatusText or makeLabel(mainFrame.requestWizardModal, "Search for an item, then continue to quantity and review.", "GameFontNormal")
    mainFrame.requestWizardStatusText:SetPoint("TOPLEFT", mainFrame.requestWizardStepText, "BOTTOMLEFT", 0, -12)
    if type(mainFrame.requestWizardStatusText.SetWidth) == "function" then
        mainFrame.requestWizardStatusText:SetWidth(452)
    end

    mainFrame.requestWizardCancelButton = mainFrame.requestWizardCancelButton or makeButton(mainFrame.requestWizardModal, 72, 28, "Cancel")
    mainFrame.requestWizardCancelButton:SetPoint("BOTTOMRIGHT", mainFrame.requestWizardModal, "BOTTOMRIGHT", -16, 16)

    mainFrame.requestWizardSubmitButton = mainFrame.requestWizardSubmitButton or makeButton(mainFrame.requestWizardModal, 72, 28, "Submit")
    mainFrame.requestWizardSubmitButton:SetPoint("RIGHT", mainFrame.requestWizardCancelButton, "LEFT", -8, 0)

    mainFrame.requestWizardNextButton = mainFrame.requestWizardNextButton or makeButton(mainFrame.requestWizardModal, 72, 28, "Next")
    mainFrame.requestWizardNextButton:SetPoint("RIGHT", mainFrame.requestWizardSubmitButton, "LEFT", -8, 0)

    mainFrame.requestWizardBackButton = mainFrame.requestWizardBackButton or makeButton(mainFrame.requestWizardModal, 72, 28, "Back")
    mainFrame.requestWizardBackButton:SetPoint("RIGHT", mainFrame.requestWizardNextButton, "LEFT", -8, 0)

    mainFrame.requestWizardReviewItemNameLabel = mainFrame.requestWizardReviewItemNameLabel or makeLabel(mainFrame.requestWizardModal, "Item Name", "GameFontHighlightSmall")
    mainFrame.requestWizardReviewItemNameLabel:SetPoint("TOPLEFT", mainFrame.requestWizardStatusText, "BOTTOMLEFT", 0, -18)
    mainFrame.requestWizardReviewItemNameText = mainFrame.requestWizardReviewItemNameText or makeLabel(mainFrame.requestWizardModal, "", "GameFontNormal")
    if type(mainFrame.requestWizardReviewItemNameText.ClearAllPoints) == "function" then
        mainFrame.requestWizardReviewItemNameText:ClearAllPoints()
    end
    mainFrame.requestWizardReviewItemNameText:SetPoint("TOPLEFT", mainFrame.requestWizardModal, "TOPLEFT", 198, -104)

    mainFrame.requestWizardReviewQualityLabel = mainFrame.requestWizardReviewQualityLabel or makeLabel(mainFrame.requestWizardModal, "Quality", "GameFontHighlightSmall")
    mainFrame.requestWizardReviewQualityLabel:SetPoint("TOPLEFT", mainFrame.requestWizardReviewItemNameLabel, "BOTTOMLEFT", 0, -12)
    mainFrame.requestWizardReviewQualityText = mainFrame.requestWizardReviewQualityText or makeLabel(mainFrame.requestWizardModal, "", "GameFontNormal")
    if type(mainFrame.requestWizardReviewQualityText.ClearAllPoints) == "function" then
        mainFrame.requestWizardReviewQualityText:ClearAllPoints()
    end
    mainFrame.requestWizardReviewQualityText:SetPoint("TOPLEFT", mainFrame.requestWizardModal, "TOPLEFT", 198, -128)

    mainFrame.requestWizardReviewQuantityLabel = mainFrame.requestWizardReviewQuantityLabel or makeLabel(mainFrame.requestWizardModal, "Quantity", "GameFontHighlightSmall")
    mainFrame.requestWizardReviewQuantityLabel:SetPoint("TOPLEFT", mainFrame.requestWizardReviewQualityLabel, "BOTTOMLEFT", 0, -12)
    mainFrame.requestWizardReviewQuantityText = mainFrame.requestWizardReviewQuantityText or makeLabel(mainFrame.requestWizardModal, "", "GameFontNormal")
    if type(mainFrame.requestWizardReviewQuantityText.ClearAllPoints) == "function" then
        mainFrame.requestWizardReviewQuantityText:ClearAllPoints()
    end
    mainFrame.requestWizardReviewQuantityText:SetPoint("TOPLEFT", mainFrame.requestWizardModal, "TOPLEFT", 198, -152)

    mainFrame.requestWizardReviewReasonLabel = mainFrame.requestWizardReviewReasonLabel or makeLabel(mainFrame.requestWizardModal, "Reason", "GameFontHighlightSmall")
    mainFrame.requestWizardReviewReasonLabel:SetPoint("TOPLEFT", mainFrame.requestWizardReviewQuantityLabel, "BOTTOMLEFT", 0, -12)
    mainFrame.requestWizardReviewReasonText = mainFrame.requestWizardReviewReasonText or makeLabel(mainFrame.requestWizardModal, "", "GameFontNormal")
    if type(mainFrame.requestWizardReviewReasonText.ClearAllPoints) == "function" then
        mainFrame.requestWizardReviewReasonText:ClearAllPoints()
    end
    mainFrame.requestWizardReviewReasonText:SetPoint("TOPLEFT", mainFrame.requestWizardModal, "TOPLEFT", 198, -176)
    if type(mainFrame.requestWizardReviewReasonText.SetWidth) == "function" then
        mainFrame.requestWizardReviewReasonText:SetWidth(300)
    end

    mainFrame.requestDetailsModal = mainFrame.requestDetailsModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestDetailsModal:SetSize(600, 430)
    mainFrame.requestDetailsModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.requestDetailsModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.requestDetailsModal.SetFrameStrata) == "function" then
        mainFrame.requestDetailsModal:SetFrameStrata(mainFrame.requestDetailsModal.frameStrata)
    end
    mainFrame.requestDetailsModal.frameLevel = (mainFrame.frameLevel or 0) + 24
    if type(mainFrame.requestDetailsModal.SetFrameLevel) == "function" then
        mainFrame.requestDetailsModal:SetFrameLevel(mainFrame.requestDetailsModal.frameLevel)
    end
    mainFrame.requestDetailsModal:EnableMouse(true)
    applyPanelStyle(mainFrame.requestDetailsModal, theme.colors.panelAlt)
    if type(mainFrame.requestDetailsModal.SetBackdropColor) == "function" then
        mainFrame.requestDetailsModal:SetBackdropColor(0, 0, 0, 1)
    end
    mainFrame.requestDetailsModal:Hide()

    mainFrame.requestDetailsTitle = mainFrame.requestDetailsTitle or makeLabel(mainFrame.requestDetailsModal, "Request Details", "GameFontHighlight")
    mainFrame.requestDetailsTitle:SetPoint("TOPLEFT", mainFrame.requestDetailsModal, "TOPLEFT", 16, -16)

    local function placeRequestDetailRow(label, value, y)
        if type(label.ClearAllPoints) == "function" then
            label:ClearAllPoints()
        end
        if type(value.ClearAllPoints) == "function" then
            value:ClearAllPoints()
        end
        label:SetPoint("TOPLEFT", mainFrame.requestDetailsModal, "TOPLEFT", 24, y)
        value:SetPoint("TOPLEFT", mainFrame.requestDetailsModal, "TOPLEFT", 160, y)
        if type(label.SetWidth) == "function" then
            label:SetWidth(118)
        end
        if type(value.SetWidth) == "function" then
            value:SetWidth(400)
        end
    end

    mainFrame.requestDetailsItemNameLabel = mainFrame.requestDetailsItemNameLabel or makeLabel(mainFrame.requestDetailsModal, "Item Name", "GameFontHighlightSmall")
    mainFrame.requestDetailsItemNameText = mainFrame.requestDetailsItemNameText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsItemNameLabel, mainFrame.requestDetailsItemNameText, -58)

    mainFrame.requestDetailsQualityLabel = mainFrame.requestDetailsQualityLabel or makeLabel(mainFrame.requestDetailsModal, "Quality", "GameFontHighlightSmall")
    mainFrame.requestDetailsQualityText = mainFrame.requestDetailsQualityText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsQualityLabel, mainFrame.requestDetailsQualityText, -82)

    mainFrame.requestDetailsQuantityLabel = mainFrame.requestDetailsQuantityLabel or makeLabel(mainFrame.requestDetailsModal, "Quantity", "GameFontHighlightSmall")
    mainFrame.requestDetailsQuantityText = mainFrame.requestDetailsQuantityText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsQuantityLabel, mainFrame.requestDetailsQuantityText, -106)

    mainFrame.requestDetailsSubmissionNoteLabel = mainFrame.requestDetailsSubmissionNoteLabel or makeLabel(mainFrame.requestDetailsModal, "Submission Note", "GameFontHighlightSmall")
    mainFrame.requestDetailsSubmissionNoteText = mainFrame.requestDetailsSubmissionNoteText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsSubmissionNoteLabel, mainFrame.requestDetailsSubmissionNoteText, -130)

    mainFrame.requestDetailsStatusLabel = mainFrame.requestDetailsStatusLabel or makeLabel(mainFrame.requestDetailsModal, "Status", "GameFontHighlightSmall")
    mainFrame.requestDetailsStatusText = mainFrame.requestDetailsStatusText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsStatusLabel, mainFrame.requestDetailsStatusText, -154)

    mainFrame.requestDetailsRequesterLabel = mainFrame.requestDetailsRequesterLabel or makeLabel(mainFrame.requestDetailsModal, "Requested By", "GameFontHighlightSmall")
    mainFrame.requestDetailsRequesterLabel:SetText("Requested By")
    mainFrame.requestDetailsRequesterText = mainFrame.requestDetailsRequesterText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsRequesterLabel, mainFrame.requestDetailsRequesterText, -178)

    mainFrame.requestDetailsRequestedAtLabel = mainFrame.requestDetailsRequestedAtLabel or makeLabel(mainFrame.requestDetailsModal, "Date Requested", "GameFontHighlightSmall")
    mainFrame.requestDetailsRequestedAtText = mainFrame.requestDetailsRequestedAtText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsRequestedAtLabel, mainFrame.requestDetailsRequestedAtText, -202)

    mainFrame.requestDetailsApprovedByLabel = mainFrame.requestDetailsApprovedByLabel or makeLabel(mainFrame.requestDetailsModal, "Updated By", "GameFontHighlightSmall")
    mainFrame.requestDetailsApprovedByLabel:SetText("Updated By")
    mainFrame.requestDetailsApprovedByText = mainFrame.requestDetailsApprovedByText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsApprovedByLabel, mainFrame.requestDetailsApprovedByText, -226)

    mainFrame.requestDetailsApprovedAtLabel = mainFrame.requestDetailsApprovedAtLabel or makeLabel(mainFrame.requestDetailsModal, "Date Updated", "GameFontHighlightSmall")
    mainFrame.requestDetailsApprovedAtLabel:SetText("Date Updated")
    mainFrame.requestDetailsApprovedAtText = mainFrame.requestDetailsApprovedAtText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsApprovedAtLabel, mainFrame.requestDetailsApprovedAtText, -250)

    mainFrame.requestDetailsFulfilledAtLabel = mainFrame.requestDetailsFulfilledAtLabel or makeLabel(mainFrame.requestDetailsModal, "Date Fulfilled", "GameFontHighlightSmall")
    mainFrame.requestDetailsFulfilledAtText = mainFrame.requestDetailsFulfilledAtText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsFulfilledAtLabel, mainFrame.requestDetailsFulfilledAtText, -274)

    mainFrame.requestDetailsDecisionNoteLabel = mainFrame.requestDetailsDecisionNoteLabel or makeLabel(mainFrame.requestDetailsModal, "Decision Note", "GameFontHighlightSmall")
    mainFrame.requestDetailsDecisionNoteText = mainFrame.requestDetailsDecisionNoteText or makeLabel(mainFrame.requestDetailsModal, "", "GameFontNormal")
    placeRequestDetailRow(mainFrame.requestDetailsDecisionNoteLabel, mainFrame.requestDetailsDecisionNoteText, -298)

    mainFrame.requestDetailsBankTabLabel = mainFrame.requestDetailsBankTabLabel or makeLabel(mainFrame.requestDetailsModal, "Approval Bank Tab", "GameFontHighlightSmall")
    mainFrame.requestDetailsBankTabLabel:SetPoint("TOPLEFT", mainFrame.requestDetailsModal, "TOPLEFT", 24, -314)
    mainFrame.requestDetailsBankTabDropdownButton = mainFrame.requestDetailsBankTabDropdownButton or makeButton(mainFrame.requestDetailsModal, 180, 22, "Select Bank Tab")
    mainFrame.requestDetailsBankTabDropdownButton:SetPoint("TOPLEFT", mainFrame.requestDetailsBankTabLabel, "BOTTOMLEFT", 0, -4)
    mainFrame.requestDetailsBankTabDropdownPanel = mainFrame.requestDetailsBankTabDropdownPanel or _G.CreateFrame("Frame", nil, mainFrame.requestDetailsModal, "BackdropTemplate")
    mainFrame.requestDetailsBankTabDropdownPanel:EnableMouse(true)
    applyPanelStyle(mainFrame.requestDetailsBankTabDropdownPanel, theme.colors.panelAlt)
    mainFrame.requestDetailsBankTabDropdownOptions = mainFrame.requestDetailsBankTabDropdownOptions or {}
    mainFrame.requestDetailsBankTabDropdownPanel:Hide()

    mainFrame.requestDetailsActionNoteLabel = mainFrame.requestDetailsActionNoteLabel or makeLabel(mainFrame.requestDetailsModal, "Decision Note", "GameFontHighlightSmall")
    mainFrame.requestDetailsActionNoteLabel:SetPoint("TOPLEFT", mainFrame.requestDetailsModal, "TOPLEFT", 240, -314)
    mainFrame.requestDetailsActionNoteInput = mainFrame.requestDetailsActionNoteInput or makeInput(mainFrame.requestDetailsModal, 260, 22)
    mainFrame.requestDetailsActionNoteInput:SetPoint("TOPLEFT", mainFrame.requestDetailsActionNoteLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.requestDetailsApproveButton = mainFrame.requestDetailsApproveButton or makeButton(mainFrame.requestDetailsModal, 72, 26, "Approve")
    mainFrame.requestDetailsApproveButton:SetPoint("TOPLEFT", mainFrame.requestDetailsBankTabDropdownButton, "BOTTOMLEFT", 0, -18)
    mainFrame.requestDetailsRejectButton = mainFrame.requestDetailsRejectButton or makeButton(mainFrame.requestDetailsModal, 66, 26, "Reject")
    mainFrame.requestDetailsRejectButton:SetPoint("LEFT", mainFrame.requestDetailsApproveButton, "RIGHT", 8, 0)
    mainFrame.requestDetailsFulfillButton = mainFrame.requestDetailsFulfillButton or makeButton(mainFrame.requestDetailsModal, 66, 26, "Fulfill")
    mainFrame.requestDetailsFulfillButton:SetPoint("LEFT", mainFrame.requestDetailsRejectButton, "RIGHT", 8, 0)
    mainFrame.requestDetailsReopenButton = mainFrame.requestDetailsReopenButton or makeButton(mainFrame.requestDetailsModal, 66, 26, "Reopen")
    mainFrame.requestDetailsReopenButton:SetPoint("LEFT", mainFrame.requestDetailsFulfillButton, "RIGHT", 8, 0)
    mainFrame.requestDetailsCancelRequestButton = mainFrame.requestDetailsCancelRequestButton or makeButton(mainFrame.requestDetailsModal, 96, 26, "Cancel Request")
    mainFrame.requestDetailsCancelRequestButton:SetPoint("LEFT", mainFrame.requestDetailsReopenButton, "RIGHT", 8, 0)

    mainFrame.requestDetailsCloseButton = mainFrame.requestDetailsCloseButton or makeButton(mainFrame.requestDetailsModal, 72, 28, "Close")
    mainFrame.requestDetailsCloseButton:SetPoint("TOPRIGHT", mainFrame.requestDetailsModal, "TOPRIGHT", -24, -366)

    mainFrame.requestCreatePanel = mainFrame.requestCreatePanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestCreatePanel:SetPoint("TOPLEFT", mainFrame.requestActionsPanel, "BOTTOMLEFT", 0, -12)
    mainFrame.requestCreatePanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestCreatePanel:SetHeight(286)
    applyPanelStyle(mainFrame.requestCreatePanel, theme.colors.panel)
    mainFrame.requestCreatePanel:Hide()

    mainFrame.requestCreateTitle = mainFrame.requestCreateTitle or makeLabel(mainFrame.requestCreatePanel, "Create Request", "GameFontHighlight")
    mainFrame.requestCreateTitle:SetPoint("TOPLEFT", mainFrame.requestCreatePanel, "TOPLEFT", 16, -16)

    mainFrame.requestCreateActorText = mainFrame.requestCreateActorText or makeLabel(mainFrame.requestCreatePanel, "", "GameFontHighlightSmall")
    mainFrame.requestCreateActorText:SetPoint("TOPLEFT", mainFrame.requestCreateTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.requestCreateRequesterLabel = mainFrame.requestCreateRequesterLabel or makeLabel(mainFrame.requestCreatePanel, "Requester", "GameFontHighlightSmall")
    mainFrame.requestCreateRequesterLabel:SetPoint("TOPLEFT", mainFrame.requestCreateActorText, "BOTTOMLEFT", 0, -8)

    mainFrame.requestCreateRequesterValueText = mainFrame.requestCreateRequesterValueText or makeLabel(mainFrame.requestCreatePanel, "", "GameFontNormal")
    mainFrame.requestCreateRequesterValueText:SetPoint("LEFT", mainFrame.requestCreateRequesterLabel, "RIGHT", 8, 0)

    mainFrame.requestCreateRoleLabel = mainFrame.requestCreateRoleLabel or makeLabel(mainFrame.requestCreatePanel, "Role", "GameFontHighlightSmall")
    mainFrame.requestCreateRoleLabel:SetPoint("LEFT", mainFrame.requestCreateRequesterValueText, "RIGHT", 18, 0)

    mainFrame.requestCreateRoleValueText = mainFrame.requestCreateRoleValueText or makeLabel(mainFrame.requestCreatePanel, "", "GameFontNormal")
    mainFrame.requestCreateRoleValueText:SetPoint("LEFT", mainFrame.requestCreateRoleLabel, "RIGHT", 8, 0)

    mainFrame.requestCreateStatusText = mainFrame.requestCreateStatusText or makeLabel(mainFrame.requestCreatePanel, "", "GameFontHighlightSmall")
    mainFrame.requestCreateStatusText:SetPoint("TOPLEFT", mainFrame.requestCreateRequesterLabel, "BOTTOMLEFT", 0, -10)

    mainFrame.requestCreateRequesterInput = mainFrame.requestCreateRequesterInput or makeInput(mainFrame.requestCreatePanel, 88, 22)
    mainFrame.requestCreateRequesterInput:SetPoint("TOPLEFT", mainFrame.requestCreateTitle, "BOTTOMLEFT", 0, -16)
    mainFrame.requestCreateRequesterInput:Hide()

    mainFrame.requestCreateRoleInput = mainFrame.requestCreateRoleInput or makeInput(mainFrame.requestCreatePanel, 84, 22)
    mainFrame.requestCreateRoleInput:SetPoint("LEFT", mainFrame.requestCreateRequesterInput, "RIGHT", 8, 0)
    mainFrame.requestCreateRoleInput:Hide()

    mainFrame.requestCreateSearchSelector = mainFrame.requestCreateSearchSelector or createItemSearchSelector(mainFrame.requestWizardModal, {
        width = 520,
        itemIDInputWidth = 92,
        itemNameInputWidth = 240,
        selectedItemTextWidth = 488,
        resultsPanelWidth = 520,
        resultsPanelHeight = 74,
        minimumNameQueryLength = 2,
        resolveQuery = function(query)
            local itemCatalog = ns.modules.itemCatalog
            return itemCatalog and type(itemCatalog.ResolveSearchSessionQuery) == "function"
                and itemCatalog.ResolveSearchSessionQuery(mainFrame:GetRequestSearchSession(), query)
                or { status = "missing", matches = {} }
        end,
        onResolved = function(item)
            if not item then
                return
            end

            local db = current_db()
            local itemCatalog = ns.modules.itemCatalog
            if itemCatalog and type(itemCatalog.StoreResolvedItem) == "function" then
                itemCatalog.StoreResolvedItem(db, item)
                mainFrame.requestSearchSession = nil
                mainFrame.minimumSearchSession = nil
            end
        end,
        onSelectionChanged = function(item)
            mainFrame.requestCreateSelectedCatalogItem = item
            if item and mainFrame.requestCreateUserMessage == "Select an item from the catalog first." then
                mainFrame.requestCreateUserMessage = nil
                if type(mainFrame.RefreshRequestEditorState) == "function" then
                    mainFrame:RefreshRequestEditorState()
                end
            end
            if type(mainFrame.UpdateRequestCreateButtonState) == "function" then
                mainFrame:UpdateRequestCreateButtonState()
            end
        end,
    })
    mainFrame.requestCreateSearchSelector:SetPoint("TOPLEFT", mainFrame.requestWizardStatusText, "BOTTOMLEFT", 0, -14)

    mainFrame.requestCreateItemIDLabel = mainFrame.requestCreateSearchSelector.itemIDLabel
    mainFrame.requestCreateItemNameLabel = mainFrame.requestCreateSearchSelector.itemNameLabel
    mainFrame.requestCreateItemIDInput = mainFrame.requestCreateSearchSelector.itemIDInput
    mainFrame.requestCreateItemNameInput = mainFrame.requestCreateSearchSelector.itemNameInput
    mainFrame.requestCreateSelectedItemLabel = mainFrame.requestCreateSearchSelector.selectedItemLabel
    mainFrame.requestCreateSelectedItemNameText = mainFrame.requestCreateSearchSelector.selectedItemNameText
    mainFrame.requestCreateSelectedItemQualityIcon = mainFrame.requestCreateSearchSelector.selectedItemQualityIcon
    mainFrame.requestCreateMatchesLabel = mainFrame.requestCreateSearchSelector.resultsLabel
    mainFrame.requestCreateResultsPanel = mainFrame.requestCreateSearchSelector.resultsPanel
    mainFrame.requestCreateMatchButtons = mainFrame.requestCreateSearchSelector.matchButtons

    mainFrame.requestCreateQuantityLabel = mainFrame.requestCreateQuantityLabel or makeLabel(mainFrame.requestWizardModal, "Quantity", "GameFontHighlightSmall")
    mainFrame.requestCreateQuantityLabel:SetPoint("TOPLEFT", mainFrame.requestWizardStatusText, "BOTTOMLEFT", 0, -22)

    mainFrame.requestCreateNoteLabel = mainFrame.requestCreateNoteLabel or makeLabel(mainFrame.requestWizardModal, "Reason for Request", "GameFontHighlightSmall")
    mainFrame.requestCreateNoteLabel:SetPoint("LEFT", mainFrame.requestCreateQuantityLabel, "RIGHT", 92, 0)

    mainFrame.requestCreateQuantityInput = mainFrame.requestCreateQuantityInput or makeInput(mainFrame.requestWizardModal, 72, 22)
    mainFrame.requestCreateQuantityInput:SetPoint("TOPLEFT", mainFrame.requestCreateQuantityLabel, "BOTTOMLEFT", 0, -6)

    mainFrame.requestCreateNoteInput = mainFrame.requestCreateNoteInput or makeInput(mainFrame.requestWizardModal, 296, 22)
    mainFrame.requestCreateNoteInput:SetPoint("TOPLEFT", mainFrame.requestCreateNoteLabel, "BOTTOMLEFT", 0, -6)

    mainFrame.requestCreateButton = mainFrame.requestCreateButton or makeButton(mainFrame.requestCreatePanel, 68, 28, "Create")
    mainFrame.requestCreateButton:SetPoint("LEFT", mainFrame.requestCreateNoteInput, "RIGHT", 12, 0)

    function mainFrame:GetSelectedRequest()
        local db = ns.state.db or {}

        for _, request in ipairs(db.requests or {}) do
            if request.requestId == self.selectedRequestId then
                return request
            end
        end

        return nil
    end

    function mainFrame:SetRequestWizardStep(step)
        self.requestWizardStep = step or 1
        local isStep1 = self.requestWizardStep == 1
        local isStep2 = self.requestWizardStep == 2
        local isStep3 = self.requestWizardStep == 3

        self.requestWizardStepText:SetText(isStep1 and "Step 1 of 3: New Request" or (isStep2 and "Step 2 of 3: Quantity and Reason" or "Step 3 of 3: Review Request"))
        self.requestWizardStatusText:SetText(isStep1 and "Search for an item, then continue to quantity and review." or (isStep2 and "Set the quantity and reason for this request." or "Review the request before submitting."))

        set_shown(self.requestCreateSearchSelector, isStep1)
        set_shown(self.requestCreateQuantityLabel, isStep2)
        set_shown(self.requestCreateNoteLabel, isStep2)
        set_shown(self.requestCreateQuantityInput, isStep2)
        set_shown(self.requestCreateNoteInput, isStep2)

        set_shown(self.requestWizardReviewItemNameLabel, isStep3)
        set_shown(self.requestWizardReviewItemNameText, isStep3)
        set_shown(self.requestWizardReviewQualityLabel, isStep3)
        set_shown(self.requestWizardReviewQualityText, isStep3)
        set_shown(self.requestWizardReviewQuantityLabel, isStep3)
        set_shown(self.requestWizardReviewQuantityText, isStep3)
        set_shown(self.requestWizardReviewReasonLabel, isStep3)
        set_shown(self.requestWizardReviewReasonText, isStep3)

        set_shown(self.requestWizardBackButton, not isStep1)
        set_shown(self.requestWizardNextButton, not isStep3)
        set_shown(self.requestWizardSubmitButton, isStep3)
        self:UpdateRequestCreateButtonState()

        if isStep3 then
            local item = self:GetConfirmedRequestCreateItem() or {}
            self.requestWizardReviewItemNameText:SetText(tostring(item.name or item.itemName or ""))
            self.requestWizardReviewQualityText:SetText(crafted_quality_markup(item.craftedQualityIcon))
            self.requestWizardReviewQuantityText:SetText(tostring(self.requestCreateQuantityInput:GetText() or ""))
            self.requestWizardReviewReasonText:SetText(tostring(self.requestCreateNoteInput:GetText() or ""))
        end
    end

    function mainFrame:RefreshRequestDetailsActionState(request)
        request = request or self:GetSelectedRequest()
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local requestsModule = ns.modules.requests
        local canActorApply = requestsModule and type(requestsModule.CanActorApplyAction) == "function" and requestsModule.CanActorApplyAction or nil
        local canApprove = request ~= nil
            and can(context, "request_approve", policy)
            and (not canActorApply or canActorApply(request, "APPROVE", context))
        local hasApprovalBankTab = tostring(self.requestApprovalBankTab or "") ~= ""

        if self.requestDetailsApproveButton then
            self.requestDetailsApproveButton:SetEnabled(canApprove and hasApprovalBankTab)
        end
    end

    function mainFrame:ConfigureRequestApprovalBankTabDropdown(request, canApprove)
        local tabOptions = type(self.GetKnownMinimumBankTabs) == "function" and self:GetKnownMinimumBankTabs(request) or {}
        self.requestApprovalBankTab = tostring((request or {}).approvedBankTab or (request or {}).tabName or "")

        set_shown(self.requestDetailsBankTabLabel, canApprove)
        set_shown(self.requestDetailsBankTabDropdownButton, canApprove)
        if not canApprove then
            self.requestDetailsBankTabDropdownPanel:Hide()
            return
        end

        self.requestDetailsBankTabDropdownButton.labelText:SetText(self.requestApprovalBankTab ~= "" and self.requestApprovalBankTab or "Select Bank Tab")
        self.requestDetailsBankTabDropdownPanel:ClearAllPoints()
        self.requestDetailsBankTabDropdownPanel:SetPoint("TOPLEFT", self.requestDetailsBankTabDropdownButton, "BOTTOMLEFT", 0, -2)
        self.requestDetailsBankTabDropdownPanel:SetSize(180, math.max(28, (#tabOptions * 24) + 8))

        for index, tabName in ipairs(tabOptions) do
            local option = self.requestDetailsBankTabDropdownOptions[index] or makeButton(self.requestDetailsBankTabDropdownPanel, 172, 22, "")
            option.value = tabName
            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", self.requestDetailsBankTabDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
            option:SetSize(172, 22)
            option.labelText:SetText(tabName)
            option:SetScript("OnClick", function()
                self.requestApprovalBankTab = tabName
                self.requestDetailsBankTabDropdownButton.labelText:SetText(tabName)
                self.requestDetailsBankTabDropdownPanel:Hide()
                self:RefreshRequestDetailsActionState(request)
            end)
            option:Show()
            self.requestDetailsBankTabDropdownOptions[index] = option
        end

        for index = #tabOptions + 1, #(self.requestDetailsBankTabDropdownOptions or {}) do
            self.requestDetailsBankTabDropdownOptions[index]:Hide()
        end

        self.requestDetailsBankTabDropdownButton:SetEnabled(#tabOptions > 0)
        self.requestDetailsBankTabDropdownButton:SetScript("OnClick", function()
            if self.requestDetailsBankTabDropdownPanel:IsShown() then
                self.requestDetailsBankTabDropdownPanel:Hide()
            else
                self.requestDetailsBankTabDropdownPanel:Show()
            end
        end)
        self.requestDetailsBankTabDropdownPanel:Hide()
        self:RefreshRequestDetailsActionState(request)
    end

    function mainFrame:LayoutRequestDetailsActionControls(canApprove, actionButtons)
        local actionX = canApprove and 240 or 24

        self.requestDetailsActionNoteLabel:ClearAllPoints()
        self.requestDetailsActionNoteLabel:SetPoint("TOPLEFT", self.requestDetailsModal, "TOPLEFT", actionX, -314)
        self.requestDetailsActionNoteInput:ClearAllPoints()
        self.requestDetailsActionNoteInput:SetPoint("TOPLEFT", self.requestDetailsActionNoteLabel, "BOTTOMLEFT", 0, -4)

        self.requestDetailsCloseButton:ClearAllPoints()
        self.requestDetailsCloseButton:SetPoint("TOPRIGHT", self.requestDetailsModal, "TOPRIGHT", -24, -366)

        local previousButton = nil
        for _, button in ipairs(actionButtons or {}) do
            button:ClearAllPoints()
            if previousButton then
                button:SetPoint("LEFT", previousButton, "RIGHT", 8, 0)
            else
                button:SetPoint("TOPLEFT", self.requestDetailsModal, "TOPLEFT", 24, -366)
            end
            previousButton = button
        end
    end

    function mainFrame:SaveMinimumForApprovedRequest(request, bankTab, actor)
        local minimumsView = ns.modules.minimumsView
        local db = current_db()
        if type(minimumsView) ~= "table" or type(minimumsView.UpsertWithAudit) ~= "function" then
            return nil
        end

        local itemID = tonumber((request or {}).itemID)
        local itemName = tostring((request or {}).itemName or "")
        local quantity = tonumber((request or {}).quantity)
        bankTab = tostring(bankTab or "")
        if not itemID or itemName == "" or not quantity or quantity <= 0 or bankTab == "" then
            return nil
        end

        local rule = {
            itemID = itemID,
            itemName = itemName,
            quantity = quantity,
            scope = "TAB",
            tabName = bankTab,
            enabled = true,
            craftedQuality = request.craftedQuality,
            craftedQualityIcon = request.craftedQualityIcon,
        }

        minimumsView.UpsertWithAudit(db, rule, {
            actor = actor_summary(actor):gsub("^Acting As: ", ""),
            timestamp = request.decidedAt or (_G.time and _G.time() or 0),
        })
        request.minimumRuleKey = table.concat({ tostring(itemID), "TAB", bankTab }, "|")
        return rule
    end

    function mainFrame:OpenRequestDetailsModal(requestId)
        local request = requestId and self:SelectRequestById(requestId) or self:GetSelectedRequest()
        if not request then
            return nil
        end

        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local requestsModule = ns.modules.requests
        local canActorApply = requestsModule and type(requestsModule.CanActorApplyAction) == "function" and requestsModule.CanActorApplyAction or nil
        local canApprove = can(context, "request_approve", policy) and (not canActorApply or canActorApply(request, "APPROVE", context))
        local canReject = can(context, "request_reject", policy) and (not canActorApply or canActorApply(request, "REJECT", context))
        local canReopen = can(context, "request_reopen", policy) and (not canActorApply or canActorApply(request, "REOPEN", context))
        local canCancel = actor_owns_request(request, context) and (not canActorApply or canActorApply(request, "CANCEL", context))

        self.requestDetailsItemNameText:SetText(tostring(request.itemName or ""))
        self.requestDetailsQualityText:SetText(crafted_quality_markup(request.craftedQualityIcon))
        self.requestDetailsQuantityText:SetText(tostring(request.quantity or ""))
        self.requestDetailsSubmissionNoteText:SetText(tostring(request.note or ""))
        self.requestDetailsStatusText:SetText(format_request_status(request))
        self.requestDetailsRequesterText:SetText(tostring(request.requester or request.createdBy or "-"))
        if request.approval == "APPROVED" then
            self.requestDetailsApprovedByText:SetText(tostring(request.approvedBy or request.decidedBy or "-"))
            self.requestDetailsApprovedAtText:SetText(format_timestamp(request.decidedAt))
        else
            self.requestDetailsApprovedByText:SetText("-")
            self.requestDetailsApprovedAtText:SetText("-")
        end
        self.requestDetailsDecisionNoteText:SetText(tostring(request.decisionNote or ""))
        self.requestDetailsRequestedAtText:SetText(format_request_time(request))
        self.requestDetailsFulfilledAtText:SetText(format_timestamp(request.fulfillmentUpdatedAt))

        self:ConfigureRequestApprovalBankTabDropdown(request, canApprove)
        local visibleActionButtons = {}
        local function show_action_button(button, shouldShow)
            set_shown(button, shouldShow)
            if shouldShow then
                table.insert(visibleActionButtons, button)
            end
        end

        show_action_button(self.requestDetailsApproveButton, canApprove)
        show_action_button(self.requestDetailsRejectButton, canReject)
        show_action_button(self.requestDetailsFulfillButton, false)
        show_action_button(self.requestDetailsReopenButton, canReopen)
        show_action_button(self.requestDetailsCancelRequestButton, canCancel)
        local needsDecisionNote = canApprove or canReject or canCancel
        set_shown(self.requestDetailsActionNoteLabel, needsDecisionNote)
        set_shown(self.requestDetailsActionNoteInput, needsDecisionNote)
        self:LayoutRequestDetailsActionControls(canApprove, visibleActionButtons)
        self:RefreshRequestDetailsActionState(request)
        self.requestDetailsModal:Show()
        return self.requestDetailsModal
    end

    function mainFrame:SelectRequestById(requestId)
        self.selectedRequestId = requestId
        self:RefreshRequestActionButtons()
        return self:GetSelectedRequest()
    end

    function mainFrame:SelectFirstActionableRequest()
        local requestsView = ns.modules.requestsView
        local db = current_db()
        local context = current_context(db)
        local queue = requestsView and requestsView.BuildVisibleRows and requestsView.BuildVisibleRows((db or {}).requests or {}, context, access_profile(context, current_policy(db))) or {}
        local first = queue[1]

        self.selectedRequestId = first and first.requestId or nil
        self:RefreshRequestActionButtons()
        return first
    end

    function mainFrame:RefreshRequestEditorState()
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local profile = access_profile(context, policy)
        local canSubmit = can(context, "request_submit", policy)

        self.requestCreateActorText:SetText(actor_summary(context))
        self.requestCreateRequesterValueText:SetText(tostring(context.name or "Unknown"))
        self.requestCreateRoleValueText:SetText(tostring(context.guildRankName or ""))

        if self.requestCreateUserMessage and self.requestCreateUserMessage ~= "" then
            self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
        elseif profile == "request_only" and not canSubmit then
            self.requestCreateStatusText:SetText("You do not have permission to submit requests.")
        elseif profile == "request_only" then
            self.requestCreateStatusText:SetText("Lightweight request access. Officers and guildmaster handle approvals.")
        else
            self.requestCreateStatusText:SetText("Submit requests using your live guild identity.")
        end

        if self.requestCreateSearchSelector then
            self.requestCreateSearchSelector:SetSearchEnabled(canSubmit)
        else
            self.requestCreateItemIDInput:SetEnabled(canSubmit)
            self.requestCreateItemNameInput:SetEnabled(canSubmit)
        end
        self.requestCreateQuantityInput:SetEnabled(canSubmit)
        self.requestCreateNoteInput:SetEnabled(canSubmit)
        self:UpdateRequestCreateButtonState()
    end

    function mainFrame:GetConfirmedRequestCreateItem()
        if self.requestCreateSelectedCatalogItem then
            return self.requestCreateSelectedCatalogItem
        end

        if self.requestCreateSearchSelector then
            return self.requestCreateSearchSelector.selectedItem
        end

        return nil
    end

    function mainFrame:UpdateRequestCreateButtonState()
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local canSubmit = can(context, "request_submit", policy)
        local hasConfirmedSelection = self:GetConfirmedRequestCreateItem() ~= nil
        local profile = access_profile(context, policy)
        local shouldEnable = canSubmit and (hasConfirmedSelection or profile == "request_only")
        self.requestCreateButton:SetEnabled(shouldEnable)
        if self.requestWizardNextButton then
            if self.requestWizardStep == 2 then
                local quantity = parseNumber(self.requestCreateQuantityInput:GetText() or "")
                self.requestWizardNextButton:SetEnabled(quantity ~= nil and quantity > 0)
            else
                self.requestWizardNextButton:SetEnabled(canSubmit and hasConfirmedSelection)
            end
        end
        return self.requestCreateButton.enabled
    end

    function mainFrame:HideRequestVariantButtons()
        if self.requestCreateSearchSelector then
            self.requestCreateSearchSelector:HideMatches()
        end
    end

    function mainFrame:GetRequestSearchSnapshot()
        local db = current_db()
        local snapshot = type(self.GetCurrentSnapshot) == "function" and self:GetCurrentSnapshot() or { items = {} }
        local itemCatalog = ns.modules.itemCatalog
        snapshot.searchCatalog = itemCatalog and type(itemCatalog.BuildSearchCatalog) == "function"
            and itemCatalog.BuildSearchCatalog(db, snapshot, {
                includeBundled = false,
            })
            or {}
        return snapshot
    end

    function mainFrame:GetRequestSearchSession()
        local itemCatalog = ns.modules.itemCatalog
        if type(itemCatalog) ~= "table" or type(itemCatalog.CreateSearchSession) ~= "function" then
            return nil
        end

        local bundledReady = type(itemCatalog.IsBundledDataLoaded) == "function" and itemCatalog.IsBundledDataLoaded() or false
        local sessionIndexedReady = type(itemCatalog.IsSearchSessionIndexedReady) == "function"
            and itemCatalog.IsSearchSessionIndexedReady(self.requestSearchSession)
            or false

        if self.requestSearchSession == nil or (bundledReady and not sessionIndexedReady) then
            self.requestSearchSession = itemCatalog.CreateSearchSession(self:GetRequestSearchSnapshot())
        end

        return self.requestSearchSession
    end

    function mainFrame:ApplyRequestResolvedItem(item)
        if not item then
            return nil
        end

        if self.requestCreateSearchSelector then
            self.requestCreateSearchSelector:ApplySelectedItem(item, true)
            return item
        end

        self.isResolvingRequestCreate = true
        self.requestCreateItemIDInput:SetText(tostring(item.itemID or ""))
        self.requestCreateItemNameInput:SetText(item.name or item.itemName or "")
        self.isResolvingRequestCreate = false
        return item
    end

    function mainFrame:ResolveRequestCreateByItemID()
        if self.requestCreateSearchSelector then
            return self.requestCreateSearchSelector:ResolveQuery(self.requestCreateItemIDInput:GetText() or "")
        end

        return nil
    end

    function mainFrame:ResolveRequestCreateByName()
        if self.requestCreateSearchSelector then
            return self.requestCreateSearchSelector:ResolveQuery(self.requestCreateItemNameInput:GetText() or "")
        end

        return nil
    end

    function mainFrame:RefreshRequestActionButtons()
        self:RefreshRequestEditorState()

        local request = self:GetSelectedRequest()
        local isPending = request and request.approval == "PENDING"
        local isFulfilled = request and request.fulfillment == "FULFILLED"
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local requestsModule = ns.modules.requests
        local canActorApply = requestsModule and type(requestsModule.CanActorApplyAction) == "function" and requestsModule.CanActorApplyAction or nil

        self.requestApproveButton:SetEnabled(isPending and can(context, "request_approve", policy) and (not canActorApply or canActorApply(request, "APPROVE", context)))
        self.requestRejectButton:SetEnabled(isPending and can(context, "request_reject", policy))
        self.requestFulfillButton:SetEnabled(false)
        self.requestReopenButton:SetEnabled(isFulfilled and can(context, "request_reopen", policy))
    end

    function mainFrame:SetRequestAdminFilterMode(mode)
        self.requestAdminFilterMode = tostring(mode or "ALL")
        if self.activeView == "REQUESTS" and self.requestOnlyMode ~= true then
            self:RefreshView()
        end
        return self.requestAdminFilterMode
    end

    function mainFrame:ApplyRequestAction(action)
        local requestsModule = ns.modules.requests
        local transport = ns.modules.syncTransport
        local db = current_db()
        local request = self:GetSelectedRequest()

        if not request or type(requestsModule) ~= "table" then
            self.requestActionStatusText:SetText("Select a request first.")
            return nil
        end

        local actor = current_context(db)
        local note = self.requestDetailsModal and self.requestDetailsModal:IsShown() and (self.requestDetailsActionNoteInput:GetText() or "") or (self.requestActionNoteInput:GetText() or "")
        local approvalBankTab = tostring(self.requestApprovalBankTab or "")
        local wasDetailsOpen = self.requestDetailsModal and self.requestDetailsModal:IsShown()

        if action == "APPROVE" and type(requestsModule.ApproveStored) == "function" then
            if approvalBankTab == "" then
                self.requestActionStatusText:SetText("Choose a bank tab before approving.")
                if self.requestWizardStatusText then
                    self.requestWizardStatusText:SetText("Choose a bank tab before approving.")
                end
                return nil
            end
            request = requestsModule.ApproveStored(db, request.requestId, actor, note, _G.time(), approvalBankTab)
        elseif action == "REJECT" and type(requestsModule.RejectStored) == "function" then
            request = requestsModule.RejectStored(db, request.requestId, actor, note, _G.time())
        elseif action == "FULFILL" and type(requestsModule.MarkFulfilledStored) == "function" then
            request = requestsModule.MarkFulfilledStored(db, request.requestId, actor, _G.time())
        elseif action == "REOPEN" and type(requestsModule.ReopenStored) == "function" then
            request = requestsModule.ReopenStored(db, request.requestId, actor, _G.time())
        elseif action == "CANCEL" and type(requestsModule.CancelStored) == "function" then
            request = requestsModule.CancelStored(db, request.requestId, actor, note, _G.time())
        else
            return nil
        end

        if not request then
            self.requestActionStatusText:SetText("Action is not available for this request.")
            return nil
        end

        self.requestActionNoteInput:SetText("")
        if self.requestDetailsActionNoteInput then
            self.requestDetailsActionNoteInput:SetText("")
        end
        self.requestActionStatusText:SetText(string.format("%s updated.", tostring(request.itemName or "Request")))
        if request and requestsModule then
            self.selectedRequestId = request.requestId
        end
        if action == "APPROVE" then
            self:SaveMinimumForApprovedRequest(request, approvalBankTab, actor)
        end
        if request and transport and type(transport.Send) == "function" then
            transport.Send("GUILD", "GUILD", {
                type = "REQUEST_UPDATED",
                updatedAt = request.updatedAt or (_G.time and _G.time() or 0),
                payload = {
                    action = action,
                    actorContext = actor,
                    note = note,
                    request = request,
                },
            })
        end
        self:RefreshRequestActionButtons()
        self:RefreshView()
        if wasDetailsOpen then
            self:OpenRequestDetailsModal(request.requestId)
        end
        return request
    end

    function mainFrame:CreateRequestFromEditor()
        local requestsModule = ns.modules.requests
        local transport = ns.modules.syncTransport
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)
        local selectedItem = self:GetConfirmedRequestCreateItem()
        local itemID = tonumber((selectedItem or {}).itemID)
        local itemName = tostring((selectedItem or {}).name or (selectedItem or {}).itemName or "")
        local quantity = parseNumber(self.requestCreateQuantityInput:GetText() or "")
        local note = self.requestCreateNoteInput:GetText() or ""

        if not can(context, "request_submit", policy) then
            self.requestCreateUserMessage = "You do not have permission to submit requests."
            self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
            return nil
        end

        if not selectedItem or not itemID or itemName == "" then
            self.requestCreateUserMessage = "Select an item from the catalog first."
            self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
            return nil
        end

        if not quantity or quantity <= 0 then
            self.requestCreateUserMessage = "Enter a Quantity greater than 0."
            self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
            return nil
        end

        if type(requestsModule) ~= "table" or type(requestsModule.CreateAndStore) ~= "function" then
            self.requestCreateUserMessage = "Request module is unavailable."
            self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
            return nil
        end

        local request = requestsModule.CreateAndStore(db, {
            actorContext = context,
            itemID = itemID,
            itemName = itemName,
            craftedQuality = selectedItem.craftedQuality,
            craftedQualityIcon = selectedItem.craftedQualityIcon,
            quantity = quantity,
            note = note,
        })

        if request and transport and type(transport.Send) == "function" then
            transport.Send("GUILD", "GUILD", {
                type = "REQUEST_CREATED",
                updatedAt = request.updatedAt or (_G.time and _G.time() or 0),
                payload = {
                    actorContext = context,
                    request = request,
                },
            })
        end

        self.selectedRequestId = request and request.requestId or nil
        self.requestCreateRequesterInput:SetText("")
        self.requestCreateRoleInput:SetText("")
        self.requestCreateSelectedCatalogItem = nil
        if self.requestCreateSearchSelector then
            self.requestCreateSearchSelector.isResolving = true
            self.requestCreateItemIDInput:SetText("")
            self.requestCreateItemNameInput:SetText("")
            self.requestCreateSearchSelector.isResolving = false
            self.requestCreateSearchSelector:ClearSelection()
        else
            self.requestCreateItemIDInput:SetText("")
            self.requestCreateItemNameInput:SetText("")
        end
        self.requestCreateQuantityInput:SetText("")
        self.requestCreateNoteInput:SetText("")
        self:HideRequestVariantButtons()
        self.requestSearchSession = nil
        self.requestCreateUserMessage = request and string.format("Created request for %s x%d.", itemName, quantity) or "Unable to create request."
        self.requestCreateStatusText:SetText(self.requestCreateUserMessage)
        self:UpdateRequestCreateButtonState()
        self:RefreshRequestActionButtons()
        self:RefreshView()
        return request
    end

    function mainFrame:OpenRequestWizard()
        if self.requestDetailsModal then
            self.requestDetailsModal:Hide()
        end
        if self.requestCreateSearchSelector then
            self.requestCreateSearchSelector:ClearSelection()
        end
        self.requestCreateQuantityInput:SetText("")
        self.requestCreateNoteInput:SetText("")
        self:SetRequestWizardStep(1)
        self.requestWizardModal:Show()
        return self.requestWizardModal
    end

    function mainFrame:HideRequestWizard()
        self.requestWizardModal:Hide()
        return self.requestWizardModal
    end

    function mainFrame:AdvanceRequestWizard()
        if self.requestWizardStep == 1 then
            if not self:GetConfirmedRequestCreateItem() then
                self.requestWizardStatusText:SetText("Select an item from the catalog first.")
                self:UpdateRequestCreateButtonState()
                return nil
            end
            self:SetRequestWizardStep(2)
            return self.requestWizardStep
        end

        if self.requestWizardStep == 2 then
            local quantity = parseNumber(self.requestCreateQuantityInput:GetText() or "")
            if not quantity or quantity <= 0 then
                self.requestWizardStatusText:SetText("Enter a Quantity greater than 0.")
                self:UpdateRequestCreateButtonState()
                return nil
            end
            self:SetRequestWizardStep(3)
            return self.requestWizardStep
        end

        return self.requestWizardStep
    end

    function mainFrame:BackRequestWizard()
        self:SetRequestWizardStep(math.max(1, (self.requestWizardStep or 1) - 1))
        return self.requestWizardStep
    end

    function mainFrame:SubmitRequestWizard()
        local request = self:CreateRequestFromEditor()
        if request then
            self:HideRequestWizard()
        else
            self.requestWizardStatusText:SetText(self.requestCreateStatusText:GetText() or "Unable to create request.")
        end
        return request
    end

    mainFrame.requestApproveButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("APPROVE")
    end)

    mainFrame.requestRejectButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("REJECT")
    end)

    mainFrame.requestFulfillButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("FULFILL")
    end)

    mainFrame.requestReopenButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("REOPEN")
    end)

    mainFrame.requestAdminFilterAllButton:SetScript("OnClick", function()
        mainFrame:SetRequestAdminFilterMode("ALL")
    end)

    mainFrame.requestAdminFilterPendingApprovalButton:SetScript("OnClick", function()
        mainFrame:SetRequestAdminFilterMode("PENDING_APPROVAL")
    end)

    mainFrame.requestAdminFilterPendingFulfillmentButton:SetScript("OnClick", function()
        mainFrame:SetRequestAdminFilterMode("PENDING_FULFILLMENT")
    end)

    mainFrame.requestCreateButton:SetScript("OnClick", function()
        mainFrame:CreateRequestFromEditor()
    end)

    mainFrame.requestCreateQuantityInput:SetScript("OnTextChanged", function()
        mainFrame:UpdateRequestCreateButtonState()
    end)

    mainFrame.requestWorkflowCreateButton:SetScript("OnClick", function()
        mainFrame:OpenRequestWizard()
    end)

    mainFrame.requestWizardCancelButton:SetScript("OnClick", function()
        mainFrame:HideRequestWizard()
    end)

    mainFrame.requestWizardNextButton:SetScript("OnClick", function()
        mainFrame:AdvanceRequestWizard()
    end)

    mainFrame.requestWizardBackButton:SetScript("OnClick", function()
        mainFrame:BackRequestWizard()
    end)

    mainFrame.requestWizardSubmitButton:SetScript("OnClick", function()
        mainFrame:SubmitRequestWizard()
    end)

    mainFrame.requestDetailsCloseButton:SetScript("OnClick", function()
        mainFrame.requestDetailsModal:Hide()
    end)

    mainFrame.requestDetailsApproveButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("APPROVE")
    end)

    mainFrame.requestDetailsRejectButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("REJECT")
    end)

    mainFrame.requestDetailsFulfillButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("FULFILL")
    end)

    mainFrame.requestDetailsReopenButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("REOPEN")
    end)

    mainFrame.requestDetailsCancelRequestButton:SetScript("OnClick", function()
        mainFrame:ApplyRequestAction("CANCEL")
    end)

    return mainFrame
end

ns.modules.mainRequestsController = mainRequestsController

return mainRequestsController
