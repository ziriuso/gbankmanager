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
    mainFrame.requestActionNoteLabel = mainFrame.requestActionNoteLabel or makeLabel(mainFrame.requestActionsPanel, "Decision Note", "GameFontHighlightSmall")
    mainFrame.requestActionNoteLabel:SetPoint("BOTTOMLEFT", mainFrame.requestActionNoteInput, "TOPLEFT", 0, 4)
    mainFrame.requestActionStatusText = mainFrame.requestActionStatusText or makeLabel(mainFrame.requestActionsPanel, "", "GameFontHighlightSmall")
    mainFrame.requestActionStatusText:SetPoint("TOPLEFT", mainFrame.requestApproveButton, "BOTTOMLEFT", 0, -8)

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

    mainFrame.requestCreateSearchSelector = mainFrame.requestCreateSearchSelector or createItemSearchSelector(mainFrame.requestCreatePanel, {
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
    mainFrame.requestCreateSearchSelector:SetPoint("TOPLEFT", mainFrame.requestCreateStatusText, "BOTTOMLEFT", 0, -12)

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

    mainFrame.requestCreateQuantityLabel = mainFrame.requestCreateQuantityLabel or makeLabel(mainFrame.requestCreatePanel, "Quantity", "GameFontHighlightSmall")
    mainFrame.requestCreateQuantityLabel:SetPoint("TOPLEFT", mainFrame.requestCreateSearchSelector.resultsPanel, "BOTTOMLEFT", 0, -12)

    mainFrame.requestCreateNoteLabel = mainFrame.requestCreateNoteLabel or makeLabel(mainFrame.requestCreatePanel, "Note", "GameFontHighlightSmall")
    mainFrame.requestCreateNoteLabel:SetPoint("LEFT", mainFrame.requestCreateQuantityLabel, "RIGHT", 92, 0)

    mainFrame.requestCreateQuantityInput = mainFrame.requestCreateQuantityInput or makeInput(mainFrame.requestCreatePanel, 72, 22)
    mainFrame.requestCreateQuantityInput:SetPoint("TOPLEFT", mainFrame.requestCreateQuantityLabel, "BOTTOMLEFT", 0, -6)

    mainFrame.requestCreateNoteInput = mainFrame.requestCreateNoteInput or makeInput(mainFrame.requestCreatePanel, 296, 22)
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
        local isApprovedOpen = request and request.approval == "APPROVED" and request.fulfillment == "OPEN"
        local isFulfilled = request and request.fulfillment == "FULFILLED"
        local db = current_db()
        local context = current_context(db)
        local policy = current_policy(db)

        self.requestApproveButton:SetEnabled(isPending and can(context, "request_approve", policy))
        self.requestRejectButton:SetEnabled(isPending and can(context, "request_reject", policy))
        self.requestFulfillButton:SetEnabled(isApprovedOpen and can(context, "request_fulfill", policy))
        self.requestReopenButton:SetEnabled(isFulfilled and can(context, "request_reopen", policy))
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
        self.requestActionStatusText:SetText(string.format("%s updated.", tostring(request.itemName or "Request")))
        if request and requestsModule then
            self.selectedRequestId = request.requestId
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
