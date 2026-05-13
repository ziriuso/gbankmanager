local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainMinimumsController = ns.modules.mainMinimumsController or {}

local function minimum_rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local MINIMUM_DRAFT_ROW_COLORS = {
    added = { 0.16, 0.30, 0.18, 0.98 },
    changed = { 0.34, 0.31, 0.12, 0.98 },
    deleted = { 0.34, 0.14, 0.14, 0.98 },
}

function mainMinimumsController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local setButtonIcon = options.setButtonIcon
    local parseNumber = options.parseNumber
    local currentDb = options.currentDb
    local applyTableRowStyle = options.applyTableRowStyle
    local theme = options.theme or {}

    mainFrame.minimumsPanel = mainFrame.minimumsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.minimumsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.minimumsPanel:SetHeight(80)
    applyPanelStyle(mainFrame.minimumsPanel, theme.colors.panel)
    mainFrame.minimumsPanel:Hide()

    mainFrame.minimumsTitle = mainFrame.minimumsTitle or makeLabel(mainFrame.minimumsPanel, "Minimum Draft Actions", "GameFontHighlight")
    mainFrame.minimumsTitle:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -16)
    mainFrame.minimumsTitle:Hide()

    mainFrame.minimumsHint = mainFrame.minimumsHint or makeLabel(mainFrame.minimumsPanel, "Use Add to stage items, edit Bank Tab / Restock / Minimum inline, Save to commit, or Undo to discard draft changes.", "GameFontHighlightSmall")
    mainFrame.minimumsHint:SetPoint("TOPLEFT", mainFrame.minimumsTitle, "BOTTOMLEFT", 0, -8)
    mainFrame.minimumsHint:Hide()

    mainFrame.minimumEditorStateText = mainFrame.minimumEditorStateText or makeLabel(mainFrame.minimumsPanel, "No draft minimum changes yet.", "GameFontHighlightSmall")
    mainFrame.minimumEditorStateText:SetPoint("TOPLEFT", mainFrame.minimumsHint, "BOTTOMLEFT", 0, -14)
    mainFrame.minimumEditorStateText:Hide()

    mainFrame.minimumShowAllToggleButton = mainFrame.minimumShowAllToggleButton or makeButton(mainFrame.minimumsPanel, 110, 28, "Show All")
    mainFrame.minimumShowAllToggleButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumsPanel, "BOTTOMRIGHT", -16, 12)

    mainFrame.minimumSearchLabel = mainFrame.minimumSearchLabel or makeLabel(mainFrame.minimumsPanel, "Search", "GameFontHighlightSmall")
    mainFrame.minimumSearchLabel:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -14)

    mainFrame.minimumSearchInput = mainFrame.minimumSearchInput or makeInput(mainFrame.minimumsPanel, 120, 22)
    mainFrame.minimumSearchInput:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -32)

    mainFrame.minimumManualOnlyToggleButton = mainFrame.minimumManualOnlyToggleButton or makeButton(mainFrame.minimumsPanel, 86, 28, "Manual Only")
    mainFrame.minimumManualOnlyToggleButton:SetPoint("RIGHT", mainFrame.minimumSearchInput, "LEFT", -8, 0)
    mainFrame.minimumManualOnlyToggleButton:Hide()

    mainFrame.minimumNewButton = mainFrame.minimumNewButton or makeButton(mainFrame.minimumsPanel, 64, 28, "Add")
    mainFrame.minimumNewButton:SetPoint("BOTTOMLEFT", mainFrame.minimumsPanel, "BOTTOMLEFT", 16, 12)

    mainFrame.minimumSaveButton = mainFrame.minimumSaveButton or makeButton(mainFrame.minimumsPanel, 88, 28, "Save")
    mainFrame.minimumSaveButton:SetPoint("LEFT", mainFrame.minimumNewButton, "RIGHT", 8, 0)
    mainFrame.minimumSaveButton.labelText:SetText("Save All")

    mainFrame.minimumSaveAllButton = mainFrame.minimumSaveAllButton or makeButton(mainFrame.minimumsPanel, 84, 28, "Undo")
    mainFrame.minimumSaveAllButton:SetPoint("LEFT", mainFrame.minimumSaveButton, "RIGHT", 8, 0)
    mainFrame.minimumSaveAllButton:Hide()

    mainFrame.minimumAddModal = mainFrame.minimumAddModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumAddModal:SetSize(500, 300)
    mainFrame.minimumAddModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.minimumAddModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.minimumAddModal.SetFrameStrata) == "function" then
        mainFrame.minimumAddModal:SetFrameStrata(mainFrame.minimumAddModal.frameStrata)
    end
    mainFrame.minimumAddModal.frameLevel = (mainFrame.frameLevel or 0) + 20
    if type(mainFrame.minimumAddModal.SetFrameLevel) == "function" then
        mainFrame.minimumAddModal:SetFrameLevel(mainFrame.minimumAddModal.frameLevel)
    end
    applyPanelStyle(mainFrame.minimumAddModal, theme.colors.panelAlt)
    mainFrame.minimumAddModal:Hide()

    mainFrame.minimumAddModalTitle = mainFrame.minimumAddModalTitle or makeLabel(mainFrame.minimumAddModal, "Add Minimum Item", "GameFontHighlight")
    mainFrame.minimumAddModalTitle:SetPoint("TOPLEFT", mainFrame.minimumAddModal, "TOPLEFT", 16, -16)

    mainFrame.minimumAddModalHint = mainFrame.minimumAddModalHint or makeLabel(mainFrame.minimumAddModal, "Search by Item ID or Item Name, then add the item and finish Bank Tab / Restock / Minimum inline in the table.", "GameFontHighlightSmall")
    mainFrame.minimumAddModalHint:SetPoint("TOPLEFT", mainFrame.minimumAddModalTitle, "BOTTOMLEFT", 0, -8)
    mainFrame.minimumAddModalHint:SetWidth(452)

    mainFrame.minimumAddItemIDLabel = mainFrame.minimumAddItemIDLabel or makeLabel(mainFrame.minimumAddModal, "Item ID", "GameFontHighlightSmall")
    mainFrame.minimumAddItemIDLabel:SetPoint("TOPLEFT", mainFrame.minimumAddModalHint, "BOTTOMLEFT", 0, -14)

    mainFrame.minimumAddItemNameLabel = mainFrame.minimumAddItemNameLabel or makeLabel(mainFrame.minimumAddModal, "Item Name", "GameFontHighlightSmall")
    mainFrame.minimumAddItemNameLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDLabel, "TOPRIGHT", 96, 0)

    mainFrame.minimumAddQuantityLabel = mainFrame.minimumAddQuantityLabel or makeLabel(mainFrame.minimumAddModal, "Minimum", "GameFontHighlightSmall")
    mainFrame.minimumAddQuantityLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemNameLabel, "TOPRIGHT", 208, 0)

    mainFrame.minimumAddItemIDInput = mainFrame.minimumAddItemIDInput or makeInput(mainFrame.minimumAddModal, 84, 22)
    mainFrame.minimumAddItemIDInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumAddItemNameInput = mainFrame.minimumAddItemNameInput or makeInput(mainFrame.minimumAddModal, 196, 22)
    mainFrame.minimumAddItemNameInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemNameLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumAddQuantityInput = mainFrame.minimumAddQuantityInput or makeInput(mainFrame.minimumAddModal, 64, 22)
    mainFrame.minimumAddQuantityInput:SetPoint("TOPLEFT", mainFrame.minimumAddQuantityLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumAddButton = mainFrame.minimumAddButton or makeButton(mainFrame.minimumAddModal, 64, 28, "Add")
    mainFrame.minimumAddButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumAddModal, "BOTTOMRIGHT", -16, 16)

    mainFrame.minimumAddCancelButton = mainFrame.minimumAddCancelButton or makeButton(mainFrame.minimumAddModal, 72, 28, "Cancel")
    mainFrame.minimumAddCancelButton:SetPoint("RIGHT", mainFrame.minimumAddButton, "LEFT", -8, 0)

    mainFrame.minimumAddBankTabInput = mainFrame.minimumAddBankTabInput or makeInput(mainFrame.minimumAddModal, 110, 22)
    mainFrame.minimumAddBankTabInput:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDInput, "BOTTOMLEFT", 0, -12)
    mainFrame.minimumAddBankTabInput:Hide()

    mainFrame.minimumScopeInput = mainFrame.minimumScopeInput or makeInput(mainFrame.minimumAddModal, 88, 22)
    mainFrame.minimumScopeInput:SetPoint("LEFT", mainFrame.minimumAddBankTabInput, "RIGHT", 8, 0)
    mainFrame.minimumScopeInput:Hide()

    mainFrame.minimumItemIDInput = mainFrame.minimumItemIDInput or mainFrame.minimumAddItemIDInput
    mainFrame.minimumItemNameInput = mainFrame.minimumItemNameInput or mainFrame.minimumAddItemNameInput
    mainFrame.minimumQuantityInput = mainFrame.minimumQuantityInput or mainFrame.minimumAddQuantityInput
    mainFrame.minimumTabNameInput = mainFrame.minimumTabNameInput or mainFrame.minimumAddBankTabInput

    mainFrame.minimumRestockToggleButton = mainFrame.minimumRestockToggleButton or makeButton(mainFrame.minimumAddModal, 78, 28, "Restock: Yes")
    mainFrame.minimumRestockToggleButton:SetPoint("LEFT", mainFrame.minimumScopeInput, "RIGHT", 8, 0)
    mainFrame.minimumRestockToggleButton:Hide()

    mainFrame.minimumAddResultsLabel = mainFrame.minimumAddResultsLabel or makeLabel(mainFrame.minimumAddModal, "Matches", "GameFontHighlightSmall")
    mainFrame.minimumAddResultsLabel:SetPoint("TOPLEFT", mainFrame.minimumAddItemIDInput, "BOTTOMLEFT", 0, -16)

    mainFrame.minimumAddResultsPanel = mainFrame.minimumAddResultsPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumAddModal, "BackdropTemplate")
    mainFrame.minimumAddResultsPanel:SetPoint("TOPLEFT", mainFrame.minimumAddResultsLabel, "BOTTOMLEFT", 0, -6)
    mainFrame.minimumAddResultsPanel:SetSize(452, 86)
    applyPanelStyle(mainFrame.minimumAddResultsPanel, theme.colors.background)
    mainFrame.minimumAddResultsPanel:Hide()

    mainFrame.minimumAddMatchButtons = mainFrame.minimumAddMatchButtons or {}
    for index = 1, 3 do
        local button = mainFrame.minimumAddMatchButtons[index] or makeButton(mainFrame.minimumAddResultsPanel, 444, 22, "")
        button:SetPoint("TOPLEFT", mainFrame.minimumAddResultsPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
        button:SetWidth(444)
        button:Hide()
        mainFrame.minimumAddMatchButtons[index] = button
    end

    function mainFrame:GetMinimumSettings(db)
        local store = ns.data.store or ns.modules.store
        return store.GetMinimumSettings(db or currentDb())
    end

    function mainFrame:LoadMinimumSettingsFromDb(db)
        local settings = self:GetMinimumSettings(db)
        self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity or 100))
        if (self.minimumAddQuantityInput:GetText() or "") == "" then
            self.minimumAddQuantityInput:SetText(tostring(settings.defaultQuantity or 100))
        end
        return settings
    end

    function mainFrame:SaveDefaultMinimumSetting()
        local settings = self:GetMinimumSettings(currentDb())
        settings.defaultQuantity = parseNumber(self.defaultMinimumInput:GetText() or "") or 100
        self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity))
        return settings.defaultQuantity
    end

    function mainFrame:CloneMinimumRule(rule)
        rule = rule or {}
        return {
            itemID = rule.itemID,
            itemName = rule.itemName,
            quantity = rule.quantity,
            scope = rule.scope,
            tabName = rule.tabName,
            enabled = rule.enabled,
            craftedQuality = rule.craftedQuality,
            craftedQualityIcon = rule.craftedQualityIcon,
            draftKey = rule.draftKey,
            originalItemID = rule.originalItemID,
            originalScope = rule.originalScope,
            originalTabName = rule.originalTabName,
        }
    end

    function mainFrame:GetMinimumBaselineRule(rowOrKey)
        local rowKey = rowOrKey
        if type(rowOrKey) == "table" then
            rowKey = rowOrKey.rowKey or rowOrKey.draftKey or minimum_rule_key(rowOrKey)
        end

        for _, rule in ipairs(self.minimumSessionBaseline or {}) do
            local baselineKey = rule.draftKey or minimum_rule_key(rule)
            if baselineKey == rowKey then
                return self:CloneMinimumRule(rule)
            end
        end

        return nil
    end

    function mainFrame:BuildMinimumRuleFromRow(row)
        if not row then
            return nil
        end

        local quantity = tonumber(row.quantityValue or row.quantity or 0) or 0
        local scope = row.scope or "TAB"
        local tabName = row.tabKey
        if row.configured ~= true then
            quantity = self:GetMinimumSettings(currentDb()).defaultQuantity or 100
            scope = "TAB"
            tabName = nil
        end

        return {
            itemID = tonumber(row.itemID),
            itemName = row.itemName,
            quantity = quantity,
            scope = scope,
            tabName = (tabName and tabName ~= "" and tabName) or nil,
            enabled = row.restock == "Yes",
            craftedQuality = row.craftedQuality,
            craftedQualityIcon = row.craftedQualityIcon,
            draftKey = row.rowKey,
            originalItemID = row.originalItemID or tonumber(row.itemID),
            originalScope = row.originalScope or row.scope,
            originalTabName = row.originalTabName,
        }
    end

    function mainFrame:GetPendingMinimumDraft(row)
        if not row then
            return nil
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        local draft = self.minimumPendingRules[row.rowKey]
        if draft then
            return draft
        end

        draft = self:BuildMinimumRuleFromRow(row)
        self.minimumPendingRules[row.rowKey] = draft
        return draft
    end

    function mainFrame:GetMinimumDraftState(row)
        if not row then
            return nil
        end

        if (self.minimumPendingDeleted or {})[row.rowKey] then
            return "deleted"
        end

        if not (self.minimumPendingDirty or {})[row.rowKey] then
            return nil
        end

        if self:GetMinimumBaselineRule(row) then
            return "changed"
        end

        return "added"
    end

    function mainFrame:GetMergedMinimumRules(db)
        local minimumsView = ns.modules.minimumsView
        local merged = {}

        for _, rule in ipairs((db or {}).minimums or {}) do
            table.insert(merged, self:CloneMinimumRule(rule))
        end

        for _, pending in pairs(self.minimumPendingRules or {}) do
            merged = minimumsView.Upsert(merged, self:CloneMinimumRule(pending))
        end

        return merged
    end

    function mainFrame:ApplyMinimumFilters()
        local minimumsView = ns.modules.minimumsView
        local db = currentDb()
        local snapshot = self:GetCurrentSnapshot()
        self.minimumManualOnlyRows = false
        if self.minimumPendingDb ~= db then
            self.minimumPendingDb = db
            self.minimumPendingRules = {}
            self.minimumPendingDirty = {}
            self.minimumPendingDeleted = {}
            self.minimumSessionBaseline = {}
            for _, rule in ipairs(db.minimums or {}) do
                table.insert(self.minimumSessionBaseline, self:CloneMinimumRule(rule))
            end
            self.selectedMinimumKey = nil
        end
        local layout = minimumsView.GetDefaultColumns()
        local rows = minimumsView.BuildTableRows(self:GetMergedMinimumRules(db), snapshot, {
            showAll = self.minimumShowAllRows,
            search = self.minimumSearchInput:GetText() or "",
            manualOnly = false,
            columnFilters = self:GetSharedFilterState(),
        })

        rows = minimumsView.SortRows(rows, self.minimumSortState)
        self.tableColumnLayout = layout
        self.tableScrollOffset = 0
        self.cachedMinimumRows = rows
        self:ConfigureTable(layout, rows)
        self:RefreshVisibleTableRows()

        local emptyStateText = self:GetMinimumEmptyStateText(rows)
        self.minimumEmptyStateText:SetText(emptyStateText)
        if emptyStateText ~= "" then
            self.minimumEmptyStateText:Show()
        else
            self.minimumEmptyStateText:Hide()
        end
    end

    function mainFrame:HideMinimumInlineRow(rowFrame)
        if not rowFrame then
            return
        end

        if rowFrame.minimumValueInput then
            rowFrame.minimumValueInput:Hide()
        end
        if rowFrame.restockToggleButton then
            rowFrame.restockToggleButton:Hide()
        end
        if rowFrame.bankTabValueInput then
            rowFrame.bankTabValueInput:Hide()
        end
        if rowFrame.bankTabDropdownButton then
            rowFrame.bankTabDropdownButton:Hide()
        end
        if rowFrame.bankTabDropdownPanel then
            rowFrame.bankTabDropdownPanel:Hide()
        end
        if rowFrame.removeButton then
            rowFrame.removeButton:Hide()
        end
        if rowFrame.undoButton then
            rowFrame.undoButton:Hide()
        end
    end

    function mainFrame:ApplyMinimumDraftStyle(rowFrame, rowIndex, draftState)
        if not rowFrame then
            return
        end

        local tintByState = {
            added = "green",
            changed = "yellow",
            deleted = "red",
        }

        rowFrame.minimumDraftState = draftState
        rowFrame.minimumDraftTint = tintByState[draftState]
        rowFrame.minimumDraftIndicator = rowFrame.minimumDraftIndicator or _G.CreateFrame("Frame", nil, rowFrame, "BackdropTemplate")
        rowFrame.minimumDraftIndicator:ClearAllPoints()
        rowFrame.minimumDraftIndicator:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 1, -1)
        rowFrame.minimumDraftIndicator:SetPoint("BOTTOMLEFT", rowFrame, "BOTTOMLEFT", 1, 1)
        rowFrame.minimumDraftIndicator:SetWidth(8)

        if draftState and MINIMUM_DRAFT_ROW_COLORS[draftState] then
            applyPanelStyle(rowFrame, MINIMUM_DRAFT_ROW_COLORS[draftState])
            applyPanelStyle(rowFrame.minimumDraftIndicator, MINIMUM_DRAFT_ROW_COLORS[draftState])
            rowFrame.minimumDraftIndicator:Show()
            rowFrame.isSelected = self:IsSelectedTableRow(rowFrame.rowData)
            return
        end

        rowFrame.minimumDraftTint = nil
        rowFrame.minimumDraftIndicator:Hide()
        applyTableRowStyle(rowFrame, rowIndex, self:IsSelectedTableRow(rowFrame.rowData))
    end

    function mainFrame:UndoMinimumRow(row)
        if not row then
            return nil
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingRules[row.rowKey] = nil
        self.minimumPendingDirty[row.rowKey] = nil
        self.minimumPendingDeleted[row.rowKey] = nil

        if self.selectedMinimumKey == row.rowKey and not self:GetMinimumBaselineRule(row) then
            self.selectedMinimumKey = nil
        end

        self:ApplyMinimumFilters()
        return row
    end

    function mainFrame:MarkMinimumRowDeleted(row)
        if not row then
            return nil
        end

        if not self:GetMinimumBaselineRule(row) then
            return self:UndoMinimumRow(row)
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingRules[row.rowKey] = nil
        self.minimumPendingDirty[row.rowKey] = nil
        self.minimumPendingDeleted[row.rowKey] = true
        self.selectedMinimumKey = row.rowKey
        self:ApplyMinimumFilters()
        return row
    end

    function mainFrame:GetKnownMinimumBankTabs(row)
        local tabs = {}
        local seen = {}

        local function add_tab(tabName)
            tabName = tostring(tabName or "")
            if tabName == "" or seen[tabName] then
                return
            end
            seen[tabName] = true
            table.insert(tabs, tabName)
        end

        for _, rule in ipairs(self:GetMergedMinimumRules(currentDb()) or {}) do
            add_tab(rule.tabName)
        end

        for _, item in pairs((self:GetCurrentSnapshot() or {}).items or {}) do
            for tabName in pairs(item.tabs or {}) do
                add_tab(tabName)
            end
        end

        if type(row) == "table" then
            add_tab(row.tabName)
            add_tab(row.tabKey)
            add_tab(row.bankTab)
        end

        table.sort(tabs)
        return tabs
    end

    function mainFrame:RememberMinimumSearchItem(item)
        local db = currentDb()
        local store = ns.data.store or ns.modules.store
        local minimumItemCatalog = store.GetMinimumItemCatalog(db)

        local itemID = tonumber((item or {}).itemID)
        local itemName = tostring((item or {}).name or (item or {}).itemName or "")
        if not itemID or itemName == "" then
            return nil
        end

        for _, existing in ipairs(minimumItemCatalog) do
            if tonumber(existing.itemID) == itemID then
                existing.name = itemName
                existing.craftedQuality = (item or {}).craftedQuality or existing.craftedQuality
                existing.craftedQualityIcon = (item or {}).craftedQualityIcon or existing.craftedQualityIcon
                return existing
            end
        end

        local entry = {
            itemID = itemID,
            name = itemName,
            craftedQuality = (item or {}).craftedQuality,
            craftedQualityIcon = (item or {}).craftedQualityIcon,
        }
        table.insert(minimumItemCatalog, entry)
        return entry
    end

    function mainFrame:GetMinimumSearchSnapshot()
        local snapshot = self:GetCurrentSnapshot()
        local db = currentDb()
        local searchCatalog = {}

        local function append_catalog_item(item)
            if type(item) ~= "table" then
                return
            end

            local itemID = tonumber(item.itemID)
            local itemName = tostring(item.name or item.itemName or "")
            if not itemID or itemName == "" then
                return
            end

            searchCatalog[#searchCatalog + 1] = {
                itemID = itemID,
                name = itemName,
                craftedQuality = item.craftedQuality,
                craftedQualityIcon = item.craftedQualityIcon,
            }
        end

        local store = ns.data.store or ns.modules.store
        local minimumItemCatalog = store.GetMinimumItemCatalog(db)

        for _, item in ipairs(minimumItemCatalog) do
            append_catalog_item(item)
        end

        for _, item in ipairs(db.minimums or {}) do
            append_catalog_item(item)
        end

        for _, item in ipairs(db.requests or {}) do
            append_catalog_item(item)
        end

        for _, item in ipairs(db.oneTimeTargets or {}) do
            append_catalog_item(item)
        end

        snapshot.searchCatalog = searchCatalog
        return snapshot
    end

    function mainFrame:ConfigureMinimumBankTabDropdown(rowFrame, row, rowIndex, state)
        if not rowFrame or not row then
            return
        end

        rowFrame.bankTabDropdownButton = rowFrame.bankTabDropdownButton or makeButton(rowFrame, 104, 20, "")
        rowFrame.bankTabDropdownPanel = rowFrame.bankTabDropdownPanel or _G.CreateFrame("Frame", nil, rowFrame, "BackdropTemplate")
        applyPanelStyle(rowFrame.bankTabDropdownPanel, theme.colors.panelAlt)
        rowFrame.bankTabDropdownOptions = rowFrame.bankTabDropdownOptions or {}

        rowFrame.bankTabDropdownButton:ClearAllPoints()
        rowFrame.bankTabDropdownButton:SetPoint("LEFT", rowFrame.columns[4], "LEFT", -4, 0)
        rowFrame.bankTabDropdownButton:SetWidth(math.max(96, (self.tableColumnLayout[4] and self.tableColumnLayout[4].width or 110) - 12))
        rowFrame.bankTabDropdownButton.labelText:SetText(((state and state.tabName) and state.tabName ~= "") and state.tabName or "Select Bank Tab")

        rowFrame.bankTabDropdownPanel:ClearAllPoints()
        rowFrame.bankTabDropdownPanel:SetPoint("TOPLEFT", rowFrame.bankTabDropdownButton, "BOTTOMLEFT", 0, -2)

        local tabOptions = self:GetKnownMinimumBankTabs(row)
        rowFrame.bankTabDropdownPanel:SetSize(rowFrame.bankTabDropdownButton:GetWidth(), math.max(28, (#tabOptions * 24) + 8))

        for index, tabName in ipairs(tabOptions) do
            local option = rowFrame.bankTabDropdownOptions[index] or makeButton(rowFrame.bankTabDropdownPanel, rowFrame.bankTabDropdownButton:GetWidth() - 8, 22, "")
            option.value = tabName
            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", rowFrame.bankTabDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
            option:SetWidth(rowFrame.bankTabDropdownButton:GetWidth() - 8)
            option.labelText:SetText(tabName)
            option:SetScript("OnClick", function()
                local current = self:GetPendingMinimumDraft(row)
                current.tabName = tabName
                current.scope = "TAB"
                self.minimumPendingDirty = self.minimumPendingDirty or {}
                self.minimumPendingDeleted = self.minimumPendingDeleted or {}
                self.minimumPendingDirty[row.rowKey] = true
                self.minimumPendingDeleted[row.rowKey] = nil
                rowFrame.bankTabDropdownButton.labelText:SetText(tabName)
                rowFrame.bankTabDropdownPanel:Hide()
                self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
            end)
            option:Show()
            rowFrame.bankTabDropdownOptions[index] = option
        end

        for index = #tabOptions + 1, #(rowFrame.bankTabDropdownOptions or {}) do
            rowFrame.bankTabDropdownOptions[index]:Hide()
        end

        rowFrame.bankTabDropdownPanel:Hide()
        rowFrame.bankTabDropdownButton:SetScript("OnClick", function()
            if rowFrame.bankTabDropdownPanel:IsShown() then
                rowFrame.bankTabDropdownPanel:Hide()
            else
                rowFrame.bankTabDropdownPanel:Show()
            end
        end)
    end

    function mainFrame:SyncMinimumInlineRow(rowFrame, row, rowIndex)
        if not rowFrame then
            return
        end

        rowFrame.minimumValueInput = rowFrame.minimumValueInput or makeInput(rowFrame, 52, 18)
        rowFrame.restockToggleButton = rowFrame.restockToggleButton or makeButton(rowFrame, 58, 20, "Yes")
        rowFrame.bankTabValueInput = rowFrame.bankTabValueInput or makeInput(rowFrame, 74, 18)
        rowFrame.removeButton = rowFrame.removeButton or makeButton(rowFrame, 20, 20, "-")
        rowFrame.undoButton = rowFrame.undoButton or makeButton(rowFrame, 20, 20, "<")

        applyPanelStyle(rowFrame.minimumValueInput, theme.colors.background)
        applyPanelStyle(rowFrame.restockToggleButton, theme.colors.panel)
        applyPanelStyle(rowFrame.bankTabValueInput, theme.colors.background)
        applyPanelStyle(rowFrame.removeButton, MINIMUM_DRAFT_ROW_COLORS.deleted)
        applyPanelStyle(rowFrame.undoButton, theme.colors.panelAlt)
        setButtonIcon(rowFrame.removeButton, "remove")
        setButtonIcon(rowFrame.undoButton, "undo")

        rowFrame.bankTabValueInput:ClearAllPoints()
        rowFrame.bankTabValueInput:SetPoint("LEFT", rowFrame.columns[4], "LEFT", -4, 0)
        rowFrame.bankTabValueInput:SetWidth((self.tableColumnLayout[4] and self.tableColumnLayout[4].width or 110) - 12)

        rowFrame.minimumValueInput:ClearAllPoints()
        rowFrame.minimumValueInput:SetPoint("LEFT", rowFrame.columns[7], "LEFT", -4, 0)
        rowFrame.minimumValueInput:SetWidth((self.tableColumnLayout[7] and self.tableColumnLayout[7].width or 70) - 12)

        rowFrame.restockToggleButton:ClearAllPoints()
        rowFrame.restockToggleButton:SetPoint("LEFT", rowFrame.columns[6], "LEFT", -4, 0)
        rowFrame.restockToggleButton:SetWidth((self.tableColumnLayout[6] and self.tableColumnLayout[6].width or 70) - 12)

        rowFrame.removeButton:ClearAllPoints()
        rowFrame.removeButton:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -6, -1)

        rowFrame.undoButton:ClearAllPoints()
        rowFrame.undoButton:SetPoint("RIGHT", rowFrame.removeButton, "LEFT", -4, 0)

        if not row or self.selectedMinimumKey ~= row.rowKey then
            self:HideMinimumInlineRow(rowFrame)
            self:ApplyMinimumDraftStyle(rowFrame, rowIndex, row and self:GetMinimumDraftState(row) or nil)
            if row and self:GetMinimumBaselineRule(row) and row.restock == "Yes" and self:GetMinimumDraftState(row) ~= "added" then
                rowFrame.removeButton:Show()
            else
                rowFrame.removeButton:Hide()
            end
            if row and self:GetMinimumDraftState(row) ~= nil then
                rowFrame.undoButton:Show()
            else
                rowFrame.undoButton:Hide()
            end
            rowFrame.removeButton:SetScript("OnClick", function()
                self:MarkMinimumRowDeleted(row)
            end)
            rowFrame.undoButton:SetScript("OnClick", function()
                self:UndoMinimumRow(row)
            end)
            return
        end

        local state = self:GetPendingMinimumDraft(row)
        local draftState = self:GetMinimumDraftState(row)
        local isDeleted = draftState == "deleted"
        local baselineRule = self:GetMinimumBaselineRule(row)
        local allowBankTabSelection = baselineRule == nil
        rowFrame.syncingMinimumDraft = true
        rowFrame.bankTabValueInput:SetText(state.tabName or "")
        rowFrame.minimumValueInput:SetText(tostring(state.quantity or 0))
        rowFrame.syncingMinimumDraft = false
        rowFrame.restockToggleButton.labelText:SetText(state.enabled and "Yes" or "No")

        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, draftState)
        self:ConfigureMinimumBankTabDropdown(rowFrame, row, rowIndex, state)

        if isDeleted then
            rowFrame.columns[4]:SetText(state.tabName or "")
            rowFrame.columns[6]:SetText(state.enabled and "Yes" or "No")
            rowFrame.columns[7]:SetText(tostring(state.quantity or 0))
            rowFrame.bankTabValueInput:Hide()
            if rowFrame.bankTabDropdownButton then
                rowFrame.bankTabDropdownButton:Hide()
            end
            if rowFrame.bankTabDropdownPanel then
                rowFrame.bankTabDropdownPanel:Hide()
            end
            rowFrame.minimumValueInput:Hide()
            rowFrame.restockToggleButton:Hide()
        else
            rowFrame.columns[6]:SetText("")
            rowFrame.columns[7]:SetText("")
            if allowBankTabSelection then
                rowFrame.columns[4]:SetText("")
                rowFrame.bankTabValueInput:Hide()
                if rowFrame.bankTabDropdownButton then
                    rowFrame.bankTabDropdownButton:Show()
                end
            else
                rowFrame.columns[4]:SetText(state.tabName or "")
                rowFrame.bankTabValueInput:Hide()
                if rowFrame.bankTabDropdownButton then
                    rowFrame.bankTabDropdownButton:Hide()
                end
                if rowFrame.bankTabDropdownPanel then
                    rowFrame.bankTabDropdownPanel:Hide()
                end
            end
            rowFrame.minimumValueInput:Show()
            rowFrame.restockToggleButton:Show()
        end
        rowFrame.removeButton:Show()
        if draftState ~= nil then
            rowFrame.undoButton:Show()
        else
            rowFrame.undoButton:Hide()
        end

        rowFrame.removeButton:SetScript("OnClick", function()
            self:MarkMinimumRowDeleted(row)
        end)

        rowFrame.undoButton:SetScript("OnClick", function()
            self:UndoMinimumRow(row)
        end)

        rowFrame.restockToggleButton:SetScript("OnClick", function()
            local current = self:GetPendingMinimumDraft(row)
            current.enabled = not current.enabled
            self.minimumPendingDirty = self.minimumPendingDirty or {}
            self.minimumPendingDeleted = self.minimumPendingDeleted or {}
            self.minimumPendingDirty[row.rowKey] = true
            self.minimumPendingDeleted[row.rowKey] = nil
            rowFrame.restockToggleButton.labelText:SetText(current.enabled and "Yes" or "No")
            if self.selectedMinimumKey ~= row.rowKey then
                rowFrame.columns[6]:SetText(current.enabled and "Yes" or "No")
            end
            self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
        end)

        rowFrame.minimumValueInput:SetScript("OnTextChanged", function(input)
            if rowFrame.syncingMinimumDraft then
                return
            end
            local current = self:GetPendingMinimumDraft(row)
            current.quantity = parseNumber(input:GetText() or "") or current.quantity or 0
            self.minimumPendingDirty = self.minimumPendingDirty or {}
            self.minimumPendingDeleted = self.minimumPendingDeleted or {}
            self.minimumPendingDirty[row.rowKey] = true
            self.minimumPendingDeleted[row.rowKey] = nil
            if self.selectedMinimumKey ~= row.rowKey then
                rowFrame.columns[7]:SetText(tostring(current.quantity or 0))
            end
            self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
        end)

        rowFrame.bankTabValueInput:SetScript("OnTextChanged", function(input)
            if rowFrame.syncingMinimumDraft then
                return
            end
            local current = self:GetPendingMinimumDraft(row)
            current.tabName = input:GetText() or ""
            current.scope = "TAB"
            self.minimumPendingDirty = self.minimumPendingDirty or {}
            self.minimumPendingDeleted = self.minimumPendingDeleted or {}
            self.minimumPendingDirty[row.rowKey] = true
            self.minimumPendingDeleted[row.rowKey] = nil
            if self.selectedMinimumKey ~= row.rowKey then
                rowFrame.columns[4]:SetText(current.tabName or "")
            end
            self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(row))
        end)

        rowFrame.minimumValueInput:SetScript("OnEditFocusLost", function()
            self:ApplyMinimumFilters()
        end)

        rowFrame.bankTabValueInput:SetScript("OnEditFocusLost", function()
            self:ApplyMinimumFilters()
        end)
    end

    function mainFrame:HideMinimumVariantButtons()
        for _, button in ipairs(self.minimumAddMatchButtons or {}) do
            button:Hide()
        end
        if self.minimumAddResultsPanel then
            self.minimumAddResultsPanel:Hide()
        end
    end

    function mainFrame:ApplyMinimumResolvedItem(item)
        if not item then
            return nil
        end

        self:RememberMinimumSearchItem(item)
        self.isResolvingMinimumAdd = true
        self.minimumAddItemIDInput:SetText(tostring(item.itemID or ""))
        self.minimumAddItemNameInput:SetText(item.name or "")
        self.minimumScopeInput:SetText("TAB")
        self.isResolvingMinimumAdd = false

        return item
    end

    function mainFrame:ResolveMinimumAddByItemID()
        local minimumsView = ns.modules.minimumsView
        local resolution = minimumsView.ResolveItemQuery(self:GetMinimumSearchSnapshot(), self.minimumAddItemIDInput:GetText() or "")
        self:HideMinimumVariantButtons()

        if resolution.status == "resolved" then
            self:ApplyMinimumResolvedItem(resolution.item)
            return resolution.item
        end

        return nil
    end

    function mainFrame:ResolveMinimumAddByName()
        local minimumsView = ns.modules.minimumsView
        local resolution = minimumsView.ResolveItemQuery(self:GetMinimumSearchSnapshot(), self.minimumAddItemNameInput:GetText() or "")
        self.minimumAddResolvedMatches = resolution.matches or {}
        self:HideMinimumVariantButtons()

        if resolution.status == "resolved" then
            return self:ApplyMinimumResolvedItem(resolution.item)
        end

        if resolution.status == "multiple" then
            if self.minimumAddResultsPanel then
                self.minimumAddResultsPanel:Show()
            end
            for index, item in ipairs(self.minimumAddResolvedMatches) do
                local button = self.minimumAddMatchButtons[index]
                if button then
                    button.labelText:SetText(string.format("%s (%s)", item.name or "", tostring(item.itemID or "")))
                    button:SetScript("OnClick", function()
                        self:ApplyMinimumResolvedItem(item)
                        self:HideMinimumVariantButtons()
                    end)
                    button:Show()
                end
            end
        end

        return nil
    end

    function mainFrame:ResetMinimumAddRow()
        self.minimumAddItemIDInput:SetText("")
        self.minimumAddItemNameInput:SetText("")
        self.minimumAddBankTabInput:SetText("")
        self.minimumAddQuantityInput:SetText(tostring((self:GetMinimumSettings(currentDb()).defaultQuantity or 100)))
        self.minimumScopeInput:SetText("TAB")
        self.minimumRestockToggleButton.labelText:SetText("Restock: Yes")
        self.selectedMinimumEnabled = true
        self:HideMinimumVariantButtons()
    end

    function mainFrame:OpenMinimumAddModal()
        self:ResetMinimumAddRow()
        self.minimumAddModal.frameStrata = "FULLSCREEN_DIALOG"
        if type(self.minimumAddModal.SetFrameStrata) == "function" then
            self.minimumAddModal:SetFrameStrata(self.minimumAddModal.frameStrata)
        end
        self.minimumAddModal.frameLevel = (self.frameLevel or 0) + 20
        if type(self.minimumAddModal.SetFrameLevel) == "function" then
            self.minimumAddModal:SetFrameLevel(self.minimumAddModal.frameLevel)
        end
        self.minimumAddModal:Show()
        return self.minimumAddModal
    end

    function mainFrame:HideMinimumAddModal()
        self.minimumAddModal:Hide()
        self:ResetMinimumAddRow()
        return self.minimumAddModal
    end

    function mainFrame:CreateMinimumFromAddRow()
        local itemID = parseNumber(self.minimumAddItemIDInput:GetText() or "")
        local quantity = parseNumber(self.minimumAddQuantityInput:GetText() or "")
        local itemName = self.minimumAddItemNameInput:GetText() or ""

        if not itemID or itemName == "" or not quantity then
            return nil
        end

        local draftKey = table.concat({ "draft", tostring(itemID), tostring(_G.time()), tostring(math.random(1000, 9999)) }, "|")
        local rule = {
            itemID = itemID,
            itemName = itemName,
            quantity = quantity,
            scope = "TAB",
            tabName = nil,
            enabled = self.selectedMinimumEnabled ~= false,
            draftKey = draftKey,
            originalItemID = itemID,
            originalScope = "TAB",
            originalTabName = nil,
        }

        self:RememberMinimumSearchItem({
            itemID = itemID,
            name = itemName,
        })

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingRules[draftKey] = rule
        self.minimumPendingDirty[draftKey] = true
        self.minimumPendingDeleted[draftKey] = nil
        self.selectedMinimumKey = draftKey
        self:HideMinimumAddModal()
        self:ApplyMinimumFilters()
        return rule
    end

    function mainFrame:SaveAllMinimumChanges()
        local minimumsView = ns.modules.minimumsView
        local db = currentDb()
        local changed = false

        for key in pairs(self.minimumPendingDeleted or {}) do
            local pending = (self.minimumPendingRules or {})[key] or self:GetMinimumBaselineRule(key)
            if pending then
                minimumsView.RemoveWithAudit(db, self:CloneMinimumRule(pending), {
                    actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
                    timestamp = _G.time(),
                })
                changed = true
            end
        end

        for key, rule in pairs(self.minimumPendingRules or {}) do
            if not (self.minimumPendingDeleted or {})[key] and (self.minimumPendingDirty or {})[key] then
                local normalized = self:CloneMinimumRule(rule)
                if (tonumber(normalized.quantity or 0) or 0) <= 0 then
                    normalized.enabled = false
                end
                local scope = tostring(normalized.scope or "TAB")
                local hasRequiredTabName = scope ~= "TAB" or tostring(normalized.tabName or "") ~= ""
                if tonumber(normalized.itemID) and tostring(normalized.itemName or "") ~= "" and hasRequiredTabName then
                    minimumsView.UpsertWithAudit(db, normalized, {
                        actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
                        timestamp = _G.time(),
                    })
                    changed = true
                end
            end
        end

        if changed then
            self.minimumPendingRules = {}
            self.minimumPendingDirty = {}
            self.minimumPendingDeleted = {}
            self.minimumSessionBaseline = {}
            for _, rule in ipairs(db.minimums or {}) do
                table.insert(self.minimumSessionBaseline, self:CloneMinimumRule(rule))
            end
            self.selectedMinimumKey = nil
        end

        self:RefreshView()
        return changed
    end

    function mainFrame:UndoMinimumChanges()
        self.minimumPendingRules = {}
        self.minimumPendingDirty = {}
        self.minimumPendingDeleted = {}
        self.selectedMinimumKey = nil
        self:HideMinimumAddModal()
        self:RefreshView()
        return true
    end

    function mainFrame:ToggleMinimumShowAllRows()
        self.minimumShowAllRows = not self.minimumShowAllRows
        self.minimumShowAllToggleButton.labelText:SetText(self.minimumShowAllRows and "Enabled Only" or "Show All")
        self:RefreshView()
        return self.minimumShowAllRows
    end

    function mainFrame:ToggleMinimumManualOnlyRows()
        self.minimumManualOnlyRows = false
        self:ApplyMinimumFilters()
        return self.minimumManualOnlyRows
    end

    function mainFrame:GetMinimumEmptyStateText(rows)
        rows = rows or {}

        if #rows > 0 then
            return ""
        end

        if (self.minimumSearchInput:GetText() or "") ~= "" then
            return "No minimum rows match the current search and filters."
        end

        if not self.minimumShowAllRows then
            return "No enabled minimum rows yet. Toggle Show All or add a manual item."
        end

        return "No guild bank items or saved minimums are available yet."
    end

    function mainFrame:ToggleMinimumRestock()
        self.selectedMinimumEnabled = not self.selectedMinimumEnabled
        self.minimumRestockToggleButton.labelText:SetText(self.selectedMinimumEnabled and "Restock: Yes" or "Restock: No")
        return self.selectedMinimumEnabled
    end

    mainFrame.minimumNewButton:SetScript("OnClick", function()
        mainFrame:OpenMinimumAddModal()
    end)

    mainFrame.minimumRestockToggleButton:SetScript("OnClick", function()
        mainFrame:ToggleMinimumRestock()
    end)

    mainFrame.minimumShowAllToggleButton:SetScript("OnClick", function()
        mainFrame:ToggleMinimumShowAllRows()
    end)

    mainFrame.minimumManualOnlyToggleButton:SetScript("OnClick", function()
        mainFrame:ToggleMinimumManualOnlyRows()
    end)

    mainFrame.minimumSaveButton:SetScript("OnClick", function()
        mainFrame:SaveAllMinimumChanges()
    end)

    mainFrame.minimumSaveAllButton:SetScript("OnClick", function()
        mainFrame:UndoMinimumChanges()
    end)

    mainFrame.minimumAddButton:SetScript("OnClick", function()
        mainFrame:CreateMinimumFromAddRow()
    end)

    mainFrame.minimumAddCancelButton:SetScript("OnClick", function()
        mainFrame:HideMinimumAddModal()
    end)

    mainFrame.minimumSearchInput:SetScript("OnTextChanged", function()
        if mainFrame.activeView == "MINIMUMS" then
            mainFrame:ApplyMinimumFilters()
        end
    end)

    mainFrame.minimumAddItemIDInput:SetScript("OnTextChanged", function()
        if mainFrame.activeView == "MINIMUMS" and not mainFrame.isResolvingMinimumAdd then
            mainFrame:ResolveMinimumAddByItemID()
        end
    end)

    mainFrame.minimumAddItemNameInput:SetScript("OnTextChanged", function()
        if mainFrame.activeView == "MINIMUMS" and not mainFrame.isResolvingMinimumAdd then
            mainFrame:ResolveMinimumAddByName()
        end
    end)

    return mainFrame
end

ns.modules.mainMinimumsController = mainMinimumsController

return mainMinimumsController
