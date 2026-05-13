local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainExportsController = ns.modules.mainExportsController or {}

function mainExportsController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local makeExportOutputInput = options.makeExportOutputInput
    local theme = options.theme or {}
    local setFrameShown = options.setFrameShown
    local normalizeExportPresetName = options.normalizeExportPresetName
    local normalizeShoppingListName = options.normalizeShoppingListName
    local cloneExportTemplate = options.cloneExportTemplate
    local countLines = options.countLines

    mainFrame.exportsPanel = mainFrame.exportsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.exportsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.exportsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.exportsPanel:SetHeight(154)
    applyPanelStyle(mainFrame.exportsPanel, theme.colors.panel)
    mainFrame.exportsPanel:Hide()

    mainFrame.exportsTitle = mainFrame.exportsTitle or makeLabel(mainFrame.exportsPanel, "Export Output", "GameFontHighlight")
    mainFrame.exportsTitle:SetPoint("TOPLEFT", mainFrame.exportsPanel, "TOPLEFT", 16, -16)

    mainFrame.exportsHint = mainFrame.exportsHint or makeLabel(mainFrame.exportsPanel, "Generate preset text from the active procurement plan.", "GameFontHighlightSmall")
    mainFrame.exportsHint:SetPoint("TOPLEFT", mainFrame.exportsTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.exportPresetSpreadsheetButton = mainFrame.exportPresetSpreadsheetButton or makeButton(mainFrame.exportsPanel, 84, 28, "CSV")
    mainFrame.exportPresetSpreadsheetButton:SetPoint("TOPLEFT", mainFrame.exportsHint, "BOTTOMLEFT", 0, -14)
    mainFrame.exportPresetSpreadsheetButton.labelText:SetText("CSV")

    mainFrame.exportPresetAuctionatorButton = mainFrame.exportPresetAuctionatorButton or makeButton(mainFrame.exportsPanel, 84, 28, "Auctionator")
    mainFrame.exportPresetAuctionatorButton:SetPoint("LEFT", mainFrame.exportPresetSpreadsheetButton, "RIGHT", 8, 0)

    mainFrame.exportPresetCustomButton = mainFrame.exportPresetCustomButton or makeButton(mainFrame.exportsPanel, 68, 28, "Custom")
    mainFrame.exportPresetCustomButton:SetPoint("LEFT", mainFrame.exportPresetAuctionatorButton, "RIGHT", 8, 0)

    mainFrame.exportsPresetTitle = mainFrame.exportsPresetTitle or makeLabel(mainFrame.exportsPanel, "CSV", "GameFontHighlight")
    mainFrame.exportsPresetTitle:SetPoint("LEFT", mainFrame.exportPresetCustomButton, "RIGHT", 16, 0)

    mainFrame.exportsOutputText = mainFrame.exportsOutputText or makeLabel(mainFrame.exportsPanel, "", "GameFontNormal")
    mainFrame.exportsOutputText:SetPoint("TOPLEFT", mainFrame.exportPresetSpreadsheetButton, "BOTTOMLEFT", 0, -12)
    mainFrame.exportsOutputText:SetWidth(760)
    mainFrame.exportsOutputText:Hide()

    mainFrame.exportDelimiterInput = mainFrame.exportDelimiterInput or makeInput(mainFrame.exportsPanel, 42, 22)
    mainFrame.exportDelimiterInput:SetPoint("LEFT", mainFrame.exportsPresetTitle, "RIGHT", 16, 0)
    mainFrame.exportDelimiterInput:SetText((mainFrame.exportCustomTemplate or {}).delimiter or "|")

    mainFrame.exportAuctionatorListNameInput = mainFrame.exportAuctionatorListNameInput or makeInput(mainFrame.exportsPanel, 140, 22)
    mainFrame.exportAuctionatorListNameInput:SetPoint("LEFT", mainFrame.exportsPresetTitle, "RIGHT", 16, 0)
    mainFrame.exportAuctionatorListNameInput:SetText(mainFrame.exportShoppingListName or "GBankManager")
    mainFrame.exportAuctionatorListNameInput:Hide()

    mainFrame.exportFieldsInput = mainFrame.exportFieldsInput or makeInput(mainFrame.exportsPanel, 250, 22)
    mainFrame.exportFieldsInput:SetPoint("LEFT", mainFrame.exportDelimiterInput, "RIGHT", 8, 0)
    mainFrame.exportFieldsInput:SetText(table.concat((mainFrame.exportCustomTemplate or {}).fields or {}, ","))

    mainFrame.exportHeaderToggleButton = mainFrame.exportHeaderToggleButton or makeButton(mainFrame.exportsPanel, 88, 28, "Header: Yes")
    mainFrame.exportHeaderToggleButton:SetPoint("LEFT", mainFrame.exportFieldsInput, "RIGHT", 8, 0)

    mainFrame.exportApplyCustomButton = mainFrame.exportApplyCustomButton or makeButton(mainFrame.exportsPanel, 64, 28, "Apply")
    mainFrame.exportApplyCustomButton:SetPoint("LEFT", mainFrame.exportHeaderToggleButton, "RIGHT", 8, 0)

    mainFrame.exportModal = mainFrame.exportModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.exportModal:SetSize(760, 252)
    mainFrame.exportModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.exportModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.exportModal.SetFrameStrata) == "function" then
        mainFrame.exportModal:SetFrameStrata(mainFrame.exportModal.frameStrata)
    end
    mainFrame.exportModal.frameLevel = (mainFrame.frameLevel or 0) + 20
    if type(mainFrame.exportModal.SetFrameLevel) == "function" then
        mainFrame.exportModal:SetFrameLevel(mainFrame.exportModal.frameLevel)
    end
    applyPanelStyle(mainFrame.exportModal, theme.colors.panelAlt)
    mainFrame.exportModal:Hide()

    mainFrame.exportModalTitle = mainFrame.exportModalTitle or makeLabel(mainFrame.exportModal, "Export Output", "GameFontHighlight")
    mainFrame.exportModalTitle:SetPoint("TOPLEFT", mainFrame.exportModal, "TOPLEFT", 16, -16)

    mainFrame.exportModalHint = mainFrame.exportModalHint or makeLabel(mainFrame.exportModal, "Select all or copy the generated output into external tools.", "GameFontHighlightSmall")
    mainFrame.exportModalHint:SetPoint("TOPLEFT", mainFrame.exportModalTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.exportModalScrollFrame = mainFrame.exportModalScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.exportModal, "BackdropTemplate")
    mainFrame.exportModalScrollFrame:SetPoint("TOPLEFT", mainFrame.exportModalHint, "BOTTOMLEFT", 0, -12)
    mainFrame.exportModalScrollFrame:SetSize(728, 146)
    mainFrame.exportModalScrollFrame:EnableMouseWheel(true)
    mainFrame.exportModalScrollFrame.verticalScroll = mainFrame.exportModalScrollFrame.verticalScroll or 0
    mainFrame.exportModalScrollFrame.verticalScrollRange = mainFrame.exportModalScrollFrame.verticalScrollRange or 0
    if type(mainFrame.exportModalScrollFrame.SetVerticalScroll) ~= "function" then
        function mainFrame.exportModalScrollFrame:SetVerticalScroll(value)
            local clamped = math.max(0, math.min(tonumber(value or 0) or 0, self.verticalScrollRange or 0))
            self.verticalScroll = clamped
        end
    end

    mainFrame.exportModalScrollChild = mainFrame.exportModalScrollChild or _G.CreateFrame("Frame", nil, mainFrame.exportModalScrollFrame, "BackdropTemplate")
    mainFrame.exportModalScrollChild:SetSize(728, 146)
    mainFrame.exportModalScrollFrame:SetScrollChild(mainFrame.exportModalScrollChild)

    mainFrame.exportModalOutputInput = mainFrame.exportModalOutputInput or makeExportOutputInput(mainFrame.exportModalScrollChild, 712, 130)
    mainFrame.exportModalOutputInput:SetPoint("TOPLEFT", mainFrame.exportModalScrollChild, "TOPLEFT", 8, -8)

    mainFrame.exportModalSelectAllButton = mainFrame.exportModalSelectAllButton or makeButton(mainFrame.exportModal, 84, 28, "Select All")
    mainFrame.exportModalSelectAllButton:SetPoint("BOTTOMLEFT", mainFrame.exportModal, "BOTTOMLEFT", 16, 16)

    mainFrame.exportModalCopyButton = mainFrame.exportModalCopyButton or makeButton(mainFrame.exportModal, 64, 28, "Copy")
    mainFrame.exportModalCopyButton:SetPoint("LEFT", mainFrame.exportModalSelectAllButton, "RIGHT", 8, 0)

    mainFrame.exportModalCloseButton = mainFrame.exportModalCloseButton or makeButton(mainFrame.exportModal, 64, 28, "Close")
    mainFrame.exportModalCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.exportModal, "BOTTOMRIGHT", -16, 16)

    function mainFrame:GetExportUiState(db)
        db = db or current_db()
        db.ui = db.ui or {}
        db.ui.inventoryColumnWidths = db.ui.inventoryColumnWidths or {}
        db.ui.exportSettings = db.ui.exportSettings or {}
        db.ui.exportSettings.selectedPreset = normalizeExportPresetName(db.ui.exportSettings.selectedPreset)
        db.ui.exportSettings.shoppingListName = normalizeShoppingListName(db.ui.exportSettings.shoppingListName)
        db.ui.exportSettings.customTemplate = cloneExportTemplate(db.ui.exportSettings.customTemplate)
        return db.ui.exportSettings
    end

    function mainFrame:LoadExportSettingsFromDb(db)
        local exportSettings = self:GetExportUiState(db)
        self.exportSelectedPreset = normalizeExportPresetName(exportSettings.selectedPreset)
        self.exportShoppingListName = normalizeShoppingListName(exportSettings.shoppingListName)
        self.exportCustomTemplate = cloneExportTemplate(exportSettings.customTemplate)
        return exportSettings
    end

    function mainFrame:PersistExportSettings(db)
        local exportSettings = self:GetExportUiState(db)
        exportSettings.selectedPreset = normalizeExportPresetName(self.exportSelectedPreset)
        exportSettings.shoppingListName = normalizeShoppingListName(self.exportShoppingListName)
        exportSettings.customTemplate = cloneExportTemplate(self.exportCustomTemplate)
        return exportSettings
    end

    function mainFrame:RefreshExportControlVisibility()
        local showAuctionatorControls = normalizeExportPresetName(self.exportSelectedPreset) == "Auctionator"
        local showCustomControls = normalizeExportPresetName(self.exportSelectedPreset) == "Custom"

        setFrameShown(self.exportAuctionatorListNameInput, showAuctionatorControls)
        setFrameShown(self.exportDelimiterInput, showCustomControls)
        setFrameShown(self.exportFieldsInput, showCustomControls)
        setFrameShown(self.exportHeaderToggleButton, showCustomControls)
        setFrameShown(self.exportApplyCustomButton, showCustomControls)
    end

    function mainFrame:RefreshExportModalScrollMetrics()
        local scrollFrame = self.exportModalScrollFrame
        local scrollChild = self.exportModalScrollChild
        local outputInput = self.exportModalOutputInput
        local lineHeight = 14
        local padding = 16
        local minimumInputHeight = 130
        local lineCount = countLines(outputInput:GetText() or "")
        local contentHeight = math.max(minimumInputHeight, (lineCount * lineHeight) + 12)
        local childHeight = math.max(scrollFrame:GetHeight(), contentHeight + padding)

        outputInput:SetHeight(contentHeight)
        scrollChild:SetHeight(childHeight)
        scrollFrame.verticalScrollRange = math.max(0, childHeight - scrollFrame:GetHeight())
        scrollFrame:SetVerticalScroll(scrollFrame.verticalScroll or 0)
    end

    function mainFrame:RefreshExportOutput(rows)
        local exportDialog = ns.modules.exportDialog
        local exportState = {
            shoppingListName = normalizeShoppingListName(self.exportShoppingListName),
        }

        for key, value in pairs(self.exportCustomTemplate or {}) do
            exportState[key] = value
        end

        local state = exportDialog and type(exportDialog.BuildPresetState) == "function" and exportDialog.BuildPresetState(rows or {}, self.exportSelectedPreset, exportState) or {
            presetName = normalizeExportPresetName(self.exportSelectedPreset),
            shoppingListName = exportState.shoppingListName,
            text = "",
        }

        self.exportSelectedPreset = normalizeExportPresetName(state.presetName or self.exportSelectedPreset)
        self.exportShoppingListName = normalizeShoppingListName(state.shoppingListName or self.exportShoppingListName)
        self.exportsPresetTitle:SetText(self.exportSelectedPreset or "CSV")
        self.isRefreshingExportControls = true
        self.exportAuctionatorListNameInput:SetText(self.exportShoppingListName)
        self.isRefreshingExportControls = false
        self:RefreshExportControlVisibility()
        self.exportsOutputText:SetText("")
        self.exportsOutputText:Hide()
        self.exportModalTitle:SetText(string.format("%s Export", self.exportSelectedPreset or "CSV"))
        self.exportModalOutputInput:SetText(state.text or "")
        self:PersistExportSettings(ns.state.db or {})
        return state
    end

    function mainFrame:RefreshExportCustomControls()
        self.isRefreshingExportControls = true
        self.exportAuctionatorListNameInput:SetText(self.exportShoppingListName or "GBankManager")
        self.isRefreshingExportControls = false
        self.exportDelimiterInput:SetText(self.exportCustomTemplate.delimiter or "|")
        self.exportFieldsInput:SetText(table.concat(self.exportCustomTemplate.fields or {}, ","))
        self.exportHeaderToggleButton.labelText:SetText((self.exportCustomTemplate.includeHeader ~= false) and "Header: Yes" or "Header: No")
        self:RefreshExportControlVisibility()
    end

    function mainFrame:SelectExportPreset(presetName)
        self.exportSelectedPreset = normalizeExportPresetName(presetName)
        self:PersistExportSettings(ns.state.db or {})
        if self.activeView == "EXPORTS" then
            local rows = self.tableRowsData or {}
            self:RefreshExportOutput(rows)
            self.exportModal:Show()
        end
        return self.exportSelectedPreset
    end

    function mainFrame:BuildCustomExportTemplateFromControls()
        local fields = {}
        local rawFields = self.exportFieldsInput:GetText() or ""
        for token in string.gmatch(rawFields, "([^,]+)") do
            local field = token:gsub("^%s+", ""):gsub("%s+$", "")
            if field ~= "" then
                table.insert(fields, field)
            end
        end

        return {
            delimiter = (self.exportDelimiterInput:GetText() or "") ~= "" and (self.exportDelimiterInput:GetText() or "") or "|",
            includeHeader = self.exportCustomTemplate.includeHeader ~= false,
            fields = #fields > 0 and fields or { "itemID", "itemName", "totalToBuy" },
        }
    end

    function mainFrame:ToggleExportHeader()
        self.exportCustomTemplate.includeHeader = not (self.exportCustomTemplate.includeHeader ~= false)
        self.exportHeaderToggleButton.labelText:SetText((self.exportCustomTemplate.includeHeader ~= false) and "Header: Yes" or "Header: No")
        self:PersistExportSettings(ns.state.db or {})
        if self.activeView == "EXPORTS" and self.exportSelectedPreset == "Custom" then
            self:RefreshExportOutput(self.tableRowsData or {})
        end
        return self.exportCustomTemplate.includeHeader
    end

    function mainFrame:ApplyCustomExportTemplate()
        self.exportCustomTemplate = self:BuildCustomExportTemplateFromControls()
        self:PersistExportSettings(ns.state.db or {})
        self:RefreshExportCustomControls()
        if self.activeView == "EXPORTS" and self.exportSelectedPreset == "Custom" then
            self:RefreshExportOutput(self.tableRowsData or {})
        end
        return self.exportCustomTemplate
    end

    mainFrame.exportModalScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll((self.verticalScroll or 0) - ((delta or 0) * 24))
    end)

    mainFrame.exportModalOutputInput:SetScript("OnTextChanged", function()
        mainFrame:RefreshExportModalScrollMetrics()
    end)

    mainFrame.exportPresetSpreadsheetButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("CSV")
    end)

    mainFrame.exportPresetAuctionatorButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("Auctionator")
    end)

    mainFrame.exportPresetCustomButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("Custom")
    end)

    mainFrame.exportHeaderToggleButton:SetScript("OnClick", function()
        mainFrame:ToggleExportHeader()
    end)

    mainFrame.exportApplyCustomButton:SetScript("OnClick", function()
        mainFrame:ApplyCustomExportTemplate()
    end)

    mainFrame.exportModalSelectAllButton:SetScript("OnClick", function()
        mainFrame.exportModalOutputInput:HighlightText(0, -1)
        if type(mainFrame.exportModalOutputInput.SetFocus) == "function" then
            mainFrame.exportModalOutputInput:SetFocus()
        end
    end)

    mainFrame.exportModalCopyButton:SetScript("OnClick", function()
        mainFrame.exportModalOutputInput.lastCopiedText = mainFrame.exportModalOutputInput:GetText() or ""
        mainFrame.exportModalOutputInput:HighlightText(0, -1)
        if type(mainFrame.exportModalOutputInput.SetFocus) == "function" then
            mainFrame.exportModalOutputInput:SetFocus()
        end
    end)

    mainFrame.exportModalCloseButton:SetScript("OnClick", function()
        mainFrame.exportModal:Hide()
    end)

    mainFrame.exportAuctionatorListNameInput:SetScript("OnTextChanged", function()
        if mainFrame.isRefreshingExportControls then
            return
        end
        mainFrame.exportShoppingListName = normalizeShoppingListName(mainFrame.exportAuctionatorListNameInput:GetText())
        mainFrame:PersistExportSettings(ns.state.db or {})
        if mainFrame.activeView == "EXPORTS" and mainFrame.exportSelectedPreset == "Auctionator" then
            mainFrame:RefreshExportOutput(mainFrame.tableRowsData or {})
        end
    end)

    return mainFrame
end

ns.modules.mainExportsController = mainExportsController

return mainExportsController
