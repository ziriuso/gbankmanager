local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainRequestsController = ns.modules.mainRequestsController or {}

function mainRequestsController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local theme = options.theme or {}
    local parseNumber = options.parseNumber

    mainFrame.requestActionsPanel = mainFrame.requestActionsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestActionsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.requestActionsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestActionsPanel:SetHeight(92)
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

    mainFrame.requestCreatePanel = mainFrame.requestCreatePanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.requestCreatePanel:SetPoint("TOPLEFT", mainFrame.requestActionsPanel, "BOTTOMLEFT", 0, -12)
    mainFrame.requestCreatePanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.requestCreatePanel:SetHeight(92)
    applyPanelStyle(mainFrame.requestCreatePanel, theme.colors.panel)
    mainFrame.requestCreatePanel:Hide()

    mainFrame.requestCreateTitle = mainFrame.requestCreateTitle or makeLabel(mainFrame.requestCreatePanel, "Create Request", "GameFontHighlight")
    mainFrame.requestCreateTitle:SetPoint("TOPLEFT", mainFrame.requestCreatePanel, "TOPLEFT", 16, -16)

    mainFrame.requestCreateRequesterInput = mainFrame.requestCreateRequesterInput or makeInput(mainFrame.requestCreatePanel, 88, 22)
    mainFrame.requestCreateRequesterInput:SetPoint("TOPLEFT", mainFrame.requestCreateTitle, "BOTTOMLEFT", 0, -16)

    mainFrame.requestCreateRoleInput = mainFrame.requestCreateRoleInput or makeInput(mainFrame.requestCreatePanel, 84, 22)
    mainFrame.requestCreateRoleInput:SetPoint("LEFT", mainFrame.requestCreateRequesterInput, "RIGHT", 8, 0)

    mainFrame.requestCreateItemIDInput = mainFrame.requestCreateItemIDInput or makeInput(mainFrame.requestCreatePanel, 72, 22)
    mainFrame.requestCreateItemIDInput:SetPoint("LEFT", mainFrame.requestCreateRoleInput, "RIGHT", 8, 0)

    mainFrame.requestCreateItemNameInput = mainFrame.requestCreateItemNameInput or makeInput(mainFrame.requestCreatePanel, 160, 22)
    mainFrame.requestCreateItemNameInput:SetPoint("LEFT", mainFrame.requestCreateItemIDInput, "RIGHT", 8, 0)

    mainFrame.requestCreateQuantityInput = mainFrame.requestCreateQuantityInput or makeInput(mainFrame.requestCreatePanel, 56, 22)
    mainFrame.requestCreateQuantityInput:SetPoint("LEFT", mainFrame.requestCreateItemNameInput, "RIGHT", 8, 0)

    mainFrame.requestCreateNoteInput = mainFrame.requestCreateNoteInput or makeInput(mainFrame.requestCreatePanel, 116, 22)
    mainFrame.requestCreateNoteInput:SetPoint("LEFT", mainFrame.requestCreateQuantityInput, "RIGHT", 8, 0)

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

    function mainFrame:SelectRequestById(requestId)
        self.selectedRequestId = requestId
        self:RefreshRequestActionButtons()
        return self:GetSelectedRequest()
    end

    function mainFrame:SelectFirstActionableRequest()
        local requestsView = ns.modules.requestsView
        local queue = requestsView and requestsView.BuildOfficerQueue and requestsView.BuildOfficerQueue((ns.state.db or {}).requests or {}) or {}
        local first = queue[1]

        self.selectedRequestId = first and first.requestId or nil
        self:RefreshRequestActionButtons()
        return first
    end

    function mainFrame:RefreshRequestActionButtons()
        local request = self:GetSelectedRequest()
        local isPending = request and request.approval == "PENDING"
        local isApprovedOpen = request and request.approval == "APPROVED" and request.fulfillment == "OPEN"
        local isFulfilled = request and request.fulfillment == "FULFILLED"

        self.requestApproveButton:SetEnabled(isPending)
        self.requestRejectButton:SetEnabled(isPending)
        self.requestFulfillButton:SetEnabled(isApprovedOpen)
        self.requestReopenButton:SetEnabled(isFulfilled)
    end

    function mainFrame:ApplyRequestAction(action)
        local requestsModule = ns.modules.requests
        local db = ns.state.db or {}
        local request = self:GetSelectedRequest()

        if not request or type(requestsModule) ~= "table" then
            return nil
        end

        local actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown"
        local note = self.requestActionNoteInput:GetText() or ""

        if action == "APPROVE" and type(requestsModule.ApproveStored) == "function" then
            request = requestsModule.ApproveStored(db, request.requestId, actor, _G.time())
        elseif action == "REJECT" and type(requestsModule.RejectStored) == "function" then
            request = requestsModule.RejectStored(db, request.requestId, actor, note, _G.time())
        elseif action == "FULFILL" and type(requestsModule.MarkFulfilledStored) == "function" then
            request = requestsModule.MarkFulfilledStored(db, request.requestId, actor, _G.time())
        elseif action == "REOPEN" and type(requestsModule.ReopenStored) == "function" then
            request = requestsModule.ReopenStored(db, request.requestId, actor, _G.time())
        else
            return nil
        end

        self.requestActionNoteInput:SetText("")
        if request and requestsModule then
            self.selectedRequestId = request.requestId
        end
        self:RefreshRequestActionButtons()
        self:RefreshView()
        return request
    end

    function mainFrame:CreateRequestFromEditor()
        local requestsModule = ns.modules.requests
        local db = ns.state.db or {}
        local requester = self.requestCreateRequesterInput:GetText() or ""
        local role = self.requestCreateRoleInput:GetText() or "MEMBER"
        local itemID = parseNumber(self.requestCreateItemIDInput:GetText() or "")
        local itemName = self.requestCreateItemNameInput:GetText() or ""
        local quantity = parseNumber(self.requestCreateQuantityInput:GetText() or "")
        local note = self.requestCreateNoteInput:GetText() or ""

        if requester == "" or role == "" or not itemID or itemName == "" or not quantity or type(requestsModule) ~= "table" or type(requestsModule.CreateAndStore) ~= "function" then
            return nil
        end

        local request = requestsModule.CreateAndStore(db, {
            requester = requester,
            role = role,
            itemID = itemID,
            itemName = itemName,
            quantity = quantity,
            note = note,
        })

        self.selectedRequestId = request and request.requestId or nil
        self.requestCreateRequesterInput:SetText("")
        self.requestCreateRoleInput:SetText("")
        self.requestCreateItemIDInput:SetText("")
        self.requestCreateItemNameInput:SetText("")
        self.requestCreateQuantityInput:SetText("")
        self.requestCreateNoteInput:SetText("")
        self:RefreshRequestActionButtons()
        self:RefreshView()
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

    mainFrame.requestCreateButton:SetScript("OnClick", function()
        mainFrame:CreateRequestFromEditor()
    end)

    return mainFrame
end

ns.modules.mainRequestsController = mainRequestsController

return mainRequestsController
