local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainExportsController = ns.modules.mainExportsController or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end

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
    local currentDb = options.currentDb
    local createPageOverflowViewport = options.createPageOverflowViewport
    local makeResizeGrip = options.makeResizeGrip

    mainFrame.exportsPanel = mainFrame.exportsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.exportsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.exportsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.exportsPanel:SetHeight(148)
    mainFrame.exportsPanel.transparentActions = true
    if type(mainFrame.exportsPanel.SetBackdrop) == "function" then
        mainFrame.exportsPanel:SetBackdrop(nil)
    end
    mainFrame.exportsPanel.backdrop = nil
    mainFrame.exportsPanel:Hide()

    mainFrame.exportsTitle = mainFrame.exportsTitle or makeLabel(mainFrame.exportsPanel, "Export Output", "GameFontHighlight")
    mainFrame.exportsTitle:SetPoint("TOPLEFT", mainFrame.exportsPanel, "TOPLEFT", 16, -16)
    mainFrame.exportsTitle:Hide()

    mainFrame.exportsHint = mainFrame.exportsHint or makeLabel(mainFrame.exportsPanel, "Generate preset text from the active procurement plan.", "GameFontHighlightSmall")
    mainFrame.exportsHint:SetPoint("TOPLEFT", mainFrame.exportsTitle, "BOTTOMLEFT", 0, -8)
    mainFrame.exportsHint:Hide()

    mainFrame.exportsFootnoteText = mainFrame.exportsFootnoteText or makeLabel(mainFrame.exportsPanel, "* Does not provide Quantity in Export.", "GameFontHighlightSmall")
    mainFrame.exportsFootnoteText:SetPoint("BOTTOMLEFT", mainFrame.exportsPanel, "BOTTOMLEFT", 0, 2)

    mainFrame.exportActionCards = mainFrame.exportActionCards or {}
    local actionCards = {
        { key = "Auctionator", title = "Auctionator*", description = "Generate Auctionator Shopping List.", icon = "Interface\\ICONS\\INV_Inscription_Tradeskill01" },
        { key = "TSM", title = "TSM*", description = "Export Group for TradeSkillMaster.", icon = "Interface\\ICONS\\INV_Misc_Gear_01" },
        { key = "CSV", title = "CSV", description = "Export to CSV.", icon = "Interface\\ICONS\\INV_Misc_Note_01" },
        { key = "MANUAL", title = "Shopping List", description = "Open a local checklist for items to shop manually.", icon = "Interface\\ICONS\\INV_Scroll_03" },
    }
    for index, config in ipairs(actionCards) do
        local card = mainFrame.exportActionCards[index] or _G.CreateFrame("Frame", nil, mainFrame.exportsPanel, "BackdropTemplate")
        card:SetSize(176, 108)
        if index == 1 then
            card:SetPoint("TOPLEFT", mainFrame.exportsPanel, "TOPLEFT", 0, 0)
        else
            card:SetPoint("LEFT", mainFrame.exportActionCards[index - 1], "RIGHT", 16, 0)
        end
        applyPanelStyle(card, theme.colors.panelAlt)

        card.iconTexture = card.iconTexture or card:CreateTexture()
        card.iconTexture:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -14)
        if type(card.iconTexture.SetSize) == "function" then
            card.iconTexture:SetSize(24, 24)
        end
        if type(card.iconTexture.SetTexture) == "function" then
            card.iconTexture:SetTexture(config.icon)
        end
        card.iconTexture.texture = config.icon

        card.titleText = card.titleText or makeLabel(card, config.title, "GameFontHighlight")
        card.titleText:SetPoint("TOPLEFT", card.iconTexture, "TOPRIGHT", 10, 2)
        if type(card.titleText.SetWidth) == "function" then
            card.titleText:SetWidth(124)
        end
        card.descriptionText = card.descriptionText or makeLabel(card, config.description, "GameFontHighlightSmall")
        card.descriptionText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -44)
        if type(card.descriptionText.SetWidth) == "function" then
            card.descriptionText:SetWidth(144)
        end
        card.actionKey = config.key
        mainFrame.exportActionCards[index] = card
    end

    function mainFrame:RelayoutExportActionCards()
        local cards = self.exportActionCards or {}
        if #cards == 0 then
            return
        end

        local availableWidth = math.max(0, (self.exportsPanel and self.exportsPanel:GetWidth() or 0))
        local gap = 16
        local minCardWidth = 156
        local maxCardWidth = 176
        local cardHeight = 108
        local columns = 4
        local contentWidth = math.max(0, availableWidth)

        if contentWidth > 0 then
            columns = math.max(1, math.min(4, math.floor((contentWidth + gap) / (minCardWidth + gap))))
            local computedWidth = math.floor((contentWidth - (gap * math.max(0, columns - 1))) / columns)
            if computedWidth < minCardWidth and columns > 1 then
                columns = columns - 1
                computedWidth = math.floor((contentWidth - (gap * math.max(0, columns - 1))) / columns)
            end
            maxCardWidth = math.max(minCardWidth, math.min(176, computedWidth))
        end

        for index, card in ipairs(cards) do
            local columnIndex = (index - 1) % columns
            local rowIndex = math.floor((index - 1) / columns)
            if type(card.ClearAllPoints) == "function" then
                card:ClearAllPoints()
            end
            card:SetSize(maxCardWidth, cardHeight)
            card:SetPoint("TOPLEFT", self.exportsPanel, "TOPLEFT", columnIndex * (maxCardWidth + gap), -(rowIndex * (cardHeight + gap)))
            if type(card.titleText.SetWidth) == "function" then
                card.titleText:SetWidth(math.max(92, maxCardWidth - 52))
            end
            if type(card.descriptionText.SetWidth) == "function" then
                card.descriptionText:SetWidth(math.min(144, math.max(110, maxCardWidth - 30)))
            end
        end

        local rows = math.max(1, math.ceil(#cards / columns))
        local panelHeight = (rows * cardHeight) + (math.max(0, rows - 1) * gap) + 32
        self.exportsPanel:SetHeight(panelHeight + 26)
        self.exportsFootnoteText:ClearAllPoints()
        self.exportsFootnoteText:SetPoint("TOPLEFT", self.exportsPanel, "TOPLEFT", 0, -(panelHeight + 8))
    end

    mainFrame.exportPresetSpreadsheetButton = mainFrame.exportPresetSpreadsheetButton or makeButton(mainFrame.exportsPanel, 84, 28, "Generate")
    mainFrame.exportPresetSpreadsheetButton:SetPoint("BOTTOMLEFT", mainFrame.exportActionCards[3], "BOTTOMLEFT", 14, 16)
    mainFrame.exportPresetSpreadsheetButton.labelText:SetText("Generate")

    mainFrame.exportPresetAuctionatorButton = mainFrame.exportPresetAuctionatorButton or makeButton(mainFrame.exportsPanel, 84, 28, "Generate")
    mainFrame.exportPresetAuctionatorButton:SetPoint("BOTTOMLEFT", mainFrame.exportActionCards[1], "BOTTOMLEFT", 14, 16)
    mainFrame.exportPresetAuctionatorButton.labelText:SetText("Generate")

    mainFrame.exportPresetTsmButton = mainFrame.exportPresetTsmButton or makeButton(mainFrame.exportsPanel, 84, 28, "Generate")
    mainFrame.exportPresetTsmButton:SetPoint("BOTTOMLEFT", mainFrame.exportActionCards[2], "BOTTOMLEFT", 14, 16)
    mainFrame.exportPresetTsmButton.labelText:SetText("Generate")

    mainFrame.exportManualShoppingListButton = mainFrame.exportManualShoppingListButton or makeButton(mainFrame.exportsPanel, 84, 28, "Open List")
    mainFrame.exportManualShoppingListButton:SetPoint("BOTTOMLEFT", mainFrame.exportActionCards[4], "BOTTOMLEFT", 14, 14)
    mainFrame.exportManualShoppingListButton.labelText:SetText("Open List")

    mainFrame.exportPresetCustomButton = mainFrame.exportPresetCustomButton or makeButton(mainFrame.exportsPanel, 68, 28, "Custom")
    mainFrame.exportPresetCustomButton:SetPoint("LEFT", mainFrame.exportManualShoppingListButton, "RIGHT", 8, 0)
    mainFrame.exportPresetCustomButton:Hide()

    mainFrame.exportsPresetTitle = mainFrame.exportsPresetTitle or makeLabel(mainFrame.exportsPanel, "CSV", "GameFontHighlight")
    mainFrame.exportsPresetTitle:SetPoint("LEFT", mainFrame.exportManualShoppingListButton, "RIGHT", 16, 0)
    mainFrame.exportsPresetTitle:Hide()

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
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.exportModal, 20, "FULLSCREEN_DIALOG")
    end

    mainFrame.exportModalTitle = mainFrame.exportModalTitle or makeLabel(mainFrame.exportModal, "Export Output", "GameFontHighlight")
    mainFrame.exportModalTitle:SetPoint("TOPLEFT", mainFrame.exportModal, "TOPLEFT", 16, -16)

    mainFrame.exportModalHint = mainFrame.exportModalHint or makeLabel(mainFrame.exportModal, "Select all or copy the generated output into external tools.", "GameFontHighlightSmall")
    mainFrame.exportModalHint:SetPoint("TOPLEFT", mainFrame.exportModalTitle, "BOTTOMLEFT", 0, -8)

    mainFrame.exportModalOutputInput = mainFrame.exportModalOutputInput or makeExportOutputInput(mainFrame.exportModal, 728, 146)
    mainFrame.exportModalOutputInput:SetPoint("TOPLEFT", mainFrame.exportModalHint, "BOTTOMLEFT", 0, -12)
    mainFrame.exportModalOutputInput:EnableMouseWheel(true)
    mainFrame.exportModalOutputInput.verticalScroll = mainFrame.exportModalOutputInput.verticalScroll or 0
    mainFrame.exportModalOutputInput.verticalScrollRange = mainFrame.exportModalOutputInput.verticalScrollRange or 0
    if type(mainFrame.exportModalOutputInput.SetVerticalScroll) ~= "function" then
        function mainFrame.exportModalOutputInput:SetVerticalScroll(value)
            local clamped = math.max(0, math.min(tonumber(value or 0) or 0, self.verticalScrollRange or 0))
            self.verticalScroll = clamped
        end
    end
    if type(mainFrame.exportModalOutputInput.SetBackdrop) == "function" then
        mainFrame.exportModalOutputInput:SetBackdrop(nil)
    end

    mainFrame.exportModalScrollFrame = mainFrame.exportModalOutputInput
    mainFrame.exportModalScrollChild = mainFrame.exportModalOutputInput.EditBox
    if type(mainFrame.exportModalScrollChild.SetBackdrop) == "function" then
        mainFrame.exportModalScrollChild:SetBackdrop(nil)
    end

    mainFrame.exportModalBuyAllButton = mainFrame.exportModalBuyAllButton or makeButton(mainFrame.exportModal, 96, 28, "Buy All")
    mainFrame.exportModalBuyAllButton:SetPoint("TOPLEFT", mainFrame.exportModalHint, "BOTTOMLEFT", 0, -18)

    mainFrame.exportModalMissingOnlyButton = mainFrame.exportModalMissingOnlyButton or makeButton(mainFrame.exportModal, 220, 28, "Not In Guild Bank")
    mainFrame.exportModalMissingOnlyButton:SetPoint("LEFT", mainFrame.exportModalBuyAllButton, "RIGHT", 8, 0)

    mainFrame.exportModalSelectAllButton = mainFrame.exportModalSelectAllButton or makeButton(mainFrame.exportModal, 84, 28, "Select All")
    mainFrame.exportModalSelectAllButton:SetPoint("BOTTOMLEFT", mainFrame.exportModal, "BOTTOMLEFT", 16, 16)

    mainFrame.exportModalStatusText = mainFrame.exportModalStatusText or makeLabel(mainFrame.exportModal, "", "GameFontHighlightSmall")
    mainFrame.exportModalStatusText:SetPoint("LEFT", mainFrame.exportModalSelectAllButton, "RIGHT", 12, 0)
    if type(mainFrame.exportModalStatusText.SetWidth) == "function" then
        mainFrame.exportModalStatusText:SetWidth(510)
    end

    mainFrame.exportModalCopyButton = mainFrame.exportModalCopyButton or makeButton(mainFrame.exportModal, 64, 28, "Copy")
    mainFrame.exportModalCopyButton:SetPoint("LEFT", mainFrame.exportModalSelectAllButton, "RIGHT", 8, 0)
    mainFrame.exportModalCopyButton:Hide()

    mainFrame.exportModalCloseButton = mainFrame.exportModalCloseButton or makeButton(mainFrame.exportModal, 64, 28, "Close")
    mainFrame.exportModalCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.exportModal, "BOTTOMRIGHT", -16, 16)

    mainFrame.exportStockedElsewhereModal = mainFrame.exportStockedElsewhereModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.exportStockedElsewhereModal:SetSize(360, 220)
    mainFrame.exportStockedElsewhereModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.exportStockedElsewhereModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.exportStockedElsewhereModal.SetFrameStrata) == "function" then
        mainFrame.exportStockedElsewhereModal:SetFrameStrata(mainFrame.exportStockedElsewhereModal.frameStrata)
    end
    mainFrame.exportStockedElsewhereModal.frameLevel = (mainFrame.frameLevel or 0) + 20
    if type(mainFrame.exportStockedElsewhereModal.SetFrameLevel) == "function" then
        mainFrame.exportStockedElsewhereModal:SetFrameLevel(mainFrame.exportStockedElsewhereModal.frameLevel)
    end
    mainFrame.exportStockedElsewhereModal:EnableMouse(true)
    applyPanelStyle(mainFrame.exportStockedElsewhereModal, theme.colors.panelAlt)
    mainFrame.exportStockedElsewhereModal:Hide()
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.exportStockedElsewhereModal, 20, "FULLSCREEN_DIALOG")
    end

    mainFrame.exportStockedElsewhereTitle = mainFrame.exportStockedElsewhereTitle or makeLabel(mainFrame.exportStockedElsewhereModal, "Stocked Elsewhere", "GameFontHighlight")
    mainFrame.exportStockedElsewhereTitle:SetPoint("TOPLEFT", mainFrame.exportStockedElsewhereModal, "TOPLEFT", 16, -16)
    mainFrame.exportStockedElsewhereText = mainFrame.exportStockedElsewhereText or makeLabel(mainFrame.exportStockedElsewhereModal, "", "GameFontNormal")
    mainFrame.exportStockedElsewhereText:SetPoint("TOPLEFT", mainFrame.exportStockedElsewhereTitle, "BOTTOMLEFT", 0, -14)
    mainFrame.exportStockedElsewhereText:SetWidth(320)
    mainFrame.exportStockedElsewhereCloseButton = mainFrame.exportStockedElsewhereCloseButton or makeButton(mainFrame.exportStockedElsewhereModal, 64, 28, "Close")
    mainFrame.exportStockedElsewhereCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.exportStockedElsewhereModal, "BOTTOMRIGHT", -16, 16)

    mainFrame.exportManualShoppingListModal = mainFrame.exportManualShoppingListModal or _G.CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
    mainFrame.exportManualShoppingListModal:SetSize(440, 320)
    mainFrame.exportManualShoppingListModal:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    mainFrame.exportManualShoppingListModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.exportManualShoppingListModal.SetFrameStrata) == "function" then
        mainFrame.exportManualShoppingListModal:SetFrameStrata(mainFrame.exportManualShoppingListModal.frameStrata)
    end
    mainFrame.exportManualShoppingListModal.frameLevel = (mainFrame.frameLevel or 0) + 20
    if type(mainFrame.exportManualShoppingListModal.SetFrameLevel) == "function" then
        mainFrame.exportManualShoppingListModal:SetFrameLevel(mainFrame.exportManualShoppingListModal.frameLevel)
    end
    mainFrame.exportManualShoppingListModal:SetMovable(true)
    mainFrame.exportManualShoppingListModal:SetResizable(true)
    mainFrame.exportManualShoppingListModal:SetResizeBounds(440, 320, 900, 700)
    mainFrame.exportManualShoppingListModal:SetClampedToScreen(true)
    mainFrame.exportManualShoppingListModal:EnableMouse(true)
    mainFrame.exportManualShoppingListModal:RegisterForDrag("LeftButton")
    mainFrame.exportManualShoppingListModal:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    mainFrame.exportManualShoppingListModal:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if type(mainFrame.PersistManualShoppingListPosition) == "function" then
            mainFrame:PersistManualShoppingListPosition()
        end
    end)
    applyPanelStyle(mainFrame.exportManualShoppingListModal, theme.colors.panelAlt)
    mainFrame.exportManualShoppingListModal:Hide()
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.exportManualShoppingListModal, 20, "FULLSCREEN_DIALOG")
    end

    mainFrame.exportManualShoppingListTitle = mainFrame.exportManualShoppingListTitle or makeLabel(mainFrame.exportManualShoppingListModal, "Manual Shopping List", "GameFontHighlight")
    mainFrame.exportManualShoppingListTitle:SetPoint("TOPLEFT", mainFrame.exportManualShoppingListModal, "TOPLEFT", 16, -16)

    mainFrame.exportManualShoppingListHint = mainFrame.exportManualShoppingListHint or makeLabel(mainFrame.exportManualShoppingListModal, "Check off purchases as you work through the list.\nShift-click an item name to fill an open Auction House search.\nDoes not sync back to addon.", "GameFontHighlightSmall")
    mainFrame.exportManualShoppingListHint:SetPoint("TOPLEFT", mainFrame.exportManualShoppingListTitle, "BOTTOMLEFT", 0, -8)
    if type(mainFrame.exportManualShoppingListHint.SetWidth) == "function" then
        mainFrame.exportManualShoppingListHint:SetWidth(420)
    end

    mainFrame.exportManualShoppingListRegion = mainFrame.exportManualShoppingListRegion or _G.CreateFrame("Frame", nil, mainFrame.exportManualShoppingListModal, "BackdropTemplate")
    mainFrame.exportManualShoppingListRegion:SetPoint("TOPLEFT", mainFrame.exportManualShoppingListHint, "BOTTOMLEFT", 0, -12)
    mainFrame.exportManualShoppingListRegion:SetPoint("BOTTOMRIGHT", mainFrame.exportManualShoppingListModal, "BOTTOMRIGHT", -16, 52)
    mainFrame.exportManualShoppingListRegion:SetSize(408, 166)
    if type(mainFrame.exportManualShoppingListRegion.SetBackdrop) == "function" then
        mainFrame.exportManualShoppingListRegion:SetBackdrop(nil)
    end

    local manualShoppingOverflow = mainFrame.exportManualShoppingListOverflow
    if not manualShoppingOverflow and type(createPageOverflowViewport) == "function" then
        manualShoppingOverflow = createPageOverflowViewport(mainFrame.exportManualShoppingListRegion, {
            viewportInsetLeft = 0,
            viewportInsetTop = 0,
            viewportInsetRight = 18,
            viewportInsetBottom = 0,
            scrollInsetLeft = 0,
            scrollInsetTop = 0,
            scrollInsetRight = 20,
            scrollInsetBottom = 0,
            scrollBarRightInset = 2,
            scrollBarTopInset = 2,
            scrollBarBottomInset = 2,
            controllerOptions = {
                wheelStep = 26,
            },
        })
        mainFrame.exportManualShoppingListOverflow = manualShoppingOverflow
    end

    mainFrame.exportManualShoppingListViewport = manualShoppingOverflow and manualShoppingOverflow.viewportFrame or mainFrame.exportManualShoppingListRegion
    mainFrame.exportManualShoppingListScrollFrame = manualShoppingOverflow and manualShoppingOverflow.scrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.exportManualShoppingListRegion)
    mainFrame.exportManualShoppingListContent = manualShoppingOverflow and manualShoppingOverflow.scrollChild or _G.CreateFrame("Frame", nil, mainFrame.exportManualShoppingListScrollFrame, "BackdropTemplate")
    mainFrame.exportManualShoppingListScrollBar = manualShoppingOverflow and manualShoppingOverflow.scrollBar or nil
    mainFrame.exportManualShoppingListScrollController = manualShoppingOverflow and manualShoppingOverflow.controller or nil
    mainFrame.exportManualShoppingListViewport:SetSize(390, 166)
    mainFrame.exportManualShoppingListScrollFrame:SetSize(354, 166)
    mainFrame.exportManualShoppingListContent:SetSize(354, 166)
    if type(mainFrame.exportManualShoppingListContent.SetBackdrop) == "function" then
        mainFrame.exportManualShoppingListContent:SetBackdrop(nil)
    end

    mainFrame.exportManualShoppingListEmptyText = mainFrame.exportManualShoppingListEmptyText or makeLabel(mainFrame.exportManualShoppingListContent, "No items currently need to be purchased.", "GameFontHighlightSmall")
    mainFrame.exportManualShoppingListEmptyText:SetPoint("TOPLEFT", mainFrame.exportManualShoppingListContent, "TOPLEFT", 0, 0)

    mainFrame.exportManualShoppingListCloseButton = mainFrame.exportManualShoppingListCloseButton or makeButton(mainFrame.exportManualShoppingListModal, 64, 28, "Close")
    mainFrame.exportManualShoppingListCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.exportManualShoppingListModal, "BOTTOMRIGHT", -16, 16)
    mainFrame.exportManualShoppingListRows = mainFrame.exportManualShoppingListRows or {}
    mainFrame.exportManualShoppingListEntries = mainFrame.exportManualShoppingListEntries or {}

    local function set_export_modal_status(text)
        mainFrame.exportModalStatusText:SetText(tostring(text or ""))
    end

    local function manual_shopping_quality_label(row)
        row = row or {}

        local markup = tostring(row.itemTier or "")
        if string.sub(markup, 1, 3) == "|A:" or string.sub(markup, 1, 2) == "|T" then
            return markup
        end

        local atlasName = tostring(
            row.craftedQualityDisplayAtlas
            or row.craftedQualityPreferredAtlas
            or row.itemDisplayTextIconAtlas
            or row.itemTierIconAtlas
            or row.craftedQualityIcon
            or ""
        )
        local resolvedQuality = tonumber(row.craftedQuality or row.quality or row.itemTierValue or 0) or 0
        local resolvedMaxQuality = tonumber(row.craftedQualityFamilySize or row.craftedQualityMax or 0) or 0
        local qualitySource = atlasName
        if qualitySource == "" and resolvedQuality > 0 then
            qualitySource = string.format("Professions-ChatIcon-Quality-Tier%d", resolvedQuality)
        end
        if type(craftedQuality.DisplayNonInventoryMarkupForItem) == "function" then
            local resolvedMarkup = craftedQuality.DisplayNonInventoryMarkupForItem(
                row.itemID,
                qualitySource,
                22,
                "reagent",
                resolvedQuality,
                resolvedMaxQuality
            )
            if resolvedMarkup ~= "" then
                return resolvedMarkup
            end
        end

        if atlasName ~= "" then
            if type(craftedQuality.ToMarkupForItem) == "function" then
                return craftedQuality.ToMarkupForItem(row.itemID, atlasName, 22, "reagent", resolvedQuality, resolvedMaxQuality)
            end
            if type(craftedQuality.ToMarkup) == "function" then
                return craftedQuality.ToMarkup(atlasName, 22, "reagent", resolvedQuality, resolvedMaxQuality)
            end
            return string.format("|A:%s:22:22|a", atlasName)
        end

        local quality = resolvedQuality
        if quality > 0 and type(craftedQuality.ToMarkupForItem) == "function" then
            return craftedQuality.ToMarkupForItem(row.itemID, string.format("Professions-ChatIcon-Quality-Tier%d", quality), 22, "reagent", quality, resolvedMaxQuality)
        end
        if quality > 0 and type(craftedQuality.ToMarkup) == "function" then
            return craftedQuality.ToMarkup(string.format("Professions-ChatIcon-Quality-Tier%d", quality), 22, "reagent", quality, resolvedMaxQuality)
        end
        if quality > 0 then
            return string.format("|A:Professions-ChatIcon-Quality-Tier%d:22:22|a", quality)
        end

        return ""
    end

    local function auction_house_is_visible()
        local auctionHouseFrame = _G.AuctionHouseFrame
        return type(auctionHouseFrame) == "table"
            and type(auctionHouseFrame.IsShown) == "function"
            and auctionHouseFrame:IsShown()
    end

    local function fill_auction_house_search(row)
        if type(_G.IsShiftKeyDown) ~= "function" or not _G.IsShiftKeyDown() or not auction_house_is_visible() then
            return false
        end

        local itemName = tostring((row or {}).itemName or "")
        local auctionHouseFrame = _G.AuctionHouseFrame
        if itemName == "" then
            return false
        end

        local function try_set_search_text()
            if type(auctionHouseFrame.SetSearchText) ~= "function" then
                return false
            end
            local ok, accepted = pcall(auctionHouseFrame.SetSearchText, auctionHouseFrame, itemName)
            return ok and accepted == true
        end

        if try_set_search_text() then
            return true
        end

        local displayModes = _G.AuctionHouseFrameDisplayMode
        if type(auctionHouseFrame.SetDisplayMode) == "function" and type(displayModes) == "table" and displayModes.Buy ~= nil then
            pcall(auctionHouseFrame.SetDisplayMode, auctionHouseFrame, displayModes.Buy)
            if try_set_search_text() then
                return true
            end
        end

        local searchBar = auctionHouseFrame.SearchBar
        if type(searchBar) == "table" and type(searchBar.SetSearchText) == "function" then
            local ok = pcall(searchBar.SetSearchText, searchBar, itemName)
            return ok
        end

        return false
    end

    local function manual_shopping_instruction(row)
        row = type(row) == "table" and row or {}
        local quantity = tonumber(row.qtyToBuy or row.totalToBuy or 0) or 0
        if quantity <= 0 then
            local restockTab = tostring(row.stockedElsewhere or (((row.stockedElsewhereTabs or {})[1] or {}).tabName) or "")
            if restockTab == "" or restockTab == "None" then
                restockTab = "another bank tab"
            end
            return "Restock from " .. restockTab
        end

        return "x" .. tostring(quantity)
    end

    local function manual_shopping_row_text(row)
        local qualityMarkup = manual_shopping_quality_label(row)
        local itemName = tostring((row or {}).itemName or "Unknown")
        local instruction = manual_shopping_instruction(row)
        if qualityMarkup ~= "" then
            return string.format("%s  %s  %s", qualityMarkup, itemName, instruction)
        end
        return string.format("%s  %s", itemName, instruction)
    end

    local layout_manual_shopping_rows

    local function ensure_manual_shopping_row(index)
        local rowFrame = mainFrame.exportManualShoppingListRows[index]
        if rowFrame then
            return rowFrame
        end

        rowFrame = _G.CreateFrame("Frame", nil, mainFrame.exportManualShoppingListContent, "BackdropTemplate")
        rowFrame:SetSize(350, 24)
        rowFrame.checkButton = _G.CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
        rowFrame.checkButton:SetSize(24, 24)
        if type(rowFrame.checkButton.SetChecked) ~= "function" then
            function rowFrame.checkButton:SetChecked(value)
                self.checked = value and true or false
            end
        end
        if type(rowFrame.checkButton.GetChecked) ~= "function" then
            function rowFrame.checkButton:GetChecked()
                return self.checked == true
            end
        end
        rowFrame.checkButton:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        rowFrame.checkButton.ownerRow = rowFrame
        rowFrame.itemButton = _G.CreateFrame("Button", nil, rowFrame)
        rowFrame.itemButton:SetPoint("LEFT", rowFrame.checkButton, "RIGHT", 8, 0)
        rowFrame.itemButton:SetSize(318, 24)
        rowFrame.itemButton.ownerRow = rowFrame
        rowFrame.itemText = makeLabel(rowFrame.itemButton, "", "GameFontNormal")
        rowFrame.itemText:SetPoint("LEFT", rowFrame.itemButton, "LEFT", 0, 0)
        if type(rowFrame.itemText.SetWidth) == "function" then
            rowFrame.itemText:SetWidth(318)
        end
        if type(rowFrame.itemText.SetWordWrap) == "function" then
            rowFrame.itemText:SetWordWrap(false)
        end
        if type(rowFrame.itemText.SetMaxLines) == "function" then
            rowFrame.itemText:SetMaxLines(1)
        end
        rowFrame.strikeLine = rowFrame.strikeLine or rowFrame.itemButton:CreateTexture()
        rowFrame.strikeLine:SetPoint("LEFT", rowFrame.itemText, "LEFT", 0, 0)
        rowFrame.strikeLine:SetPoint("RIGHT", rowFrame.itemText, "RIGHT", 0, 0)
        rowFrame.strikeLine:SetHeight(1)
        if type(rowFrame.strikeLine.SetColorTexture) == "function" then
            rowFrame.strikeLine:SetColorTexture(1, 0.82, 0, 0.95)
        end
        rowFrame.strikeLine:Hide()
        rowFrame.itemButton:SetScript("OnClick", function(self)
            local ownerRow = self.ownerRow
            return fill_auction_house_search(ownerRow and ownerRow.rowData)
        end)
        rowFrame.checkButton:SetScript("OnClick", function(self)
            local ownerRow = self.ownerRow
            local entry = ownerRow and ownerRow.shoppingEntry
            if not entry then
                return false
            end
            entry.checked = not entry.checked
            layout_manual_shopping_rows(false)
            return entry.checked
        end)
        mainFrame.exportManualShoppingListRows[index] = rowFrame
        return rowFrame
    end

    layout_manual_shopping_rows = function(resetScroll)
        local entries = mainFrame.exportManualShoppingListEntries or {}
        local modalWidth = math.max(440, tonumber(mainFrame.exportManualShoppingListModal:GetWidth() or 440) or 440)
        local modalHeight = math.max(320, tonumber(mainFrame.exportManualShoppingListModal:GetHeight() or 320) or 320)
        local regionWidth = math.max(408, modalWidth - 32)
        local regionHeight = math.max(166, modalHeight - 154)
        local viewportWidth = math.max(390, regionWidth - 18)
        local scrollWidth = math.max(354, viewportWidth - 36)
        local rowWidth = math.max(350, scrollWidth - 4)
        local itemWidth = math.max(318, rowWidth - 32)

        mainFrame.exportManualShoppingListHint:SetWidth(math.max(408, modalWidth - 32))
        mainFrame.exportManualShoppingListRegion:SetSize(regionWidth, regionHeight)
        mainFrame.exportManualShoppingListViewport:SetSize(viewportWidth, regionHeight)
        mainFrame.exportManualShoppingListScrollFrame:SetSize(scrollWidth, regionHeight)
        mainFrame.exportManualShoppingListContent:SetWidth(scrollWidth)

        local ordered = {}
        for _, entry in ipairs(entries) do
            if entry.checked ~= true then
                ordered[#ordered + 1] = entry
            end
        end
        for _, entry in ipairs(entries) do
            if entry.checked == true then
                ordered[#ordered + 1] = entry
            end
        end

        for displayIndex, entry in ipairs(ordered) do
            local rowFrame = entry.rowFrame
            rowFrame:SetWidth(rowWidth)
            rowFrame.itemButton:SetWidth(itemWidth)
            rowFrame.itemText:SetWidth(itemWidth)
            rowFrame:ClearAllPoints()
            rowFrame:SetPoint("TOPLEFT", mainFrame.exportManualShoppingListContent, "TOPLEFT", 0, -((displayIndex - 1) * 26))
            rowFrame.rowData = entry.rowData
            rowFrame.shoppingEntry = entry
            rowFrame.checked = entry.checked == true
            rowFrame.checkButton:SetChecked(rowFrame.checked)
            rowFrame.itemText:SetText(manual_shopping_row_text(entry.rowData))
            if rowFrame.checked then
                rowFrame.strikeLine:Show()
            else
                rowFrame.strikeLine:Hide()
            end
            rowFrame:Show()
        end

        local viewportHeight = math.max(1, tonumber(mainFrame.exportManualShoppingListScrollFrame:GetHeight() or 166) or 166)
        local contentHeight = math.max(viewportHeight, #entries * 26)
        mainFrame.exportManualShoppingListContent:SetHeight(contentHeight)
        local controller = mainFrame.exportManualShoppingListScrollController
        if controller then
            if resetScroll and type(controller.SetOffset) == "function" then
                controller:SetOffset(0, contentHeight, viewportHeight)
            elseif type(controller.Refresh) == "function" then
                controller:Refresh(contentHeight, viewportHeight)
            end
        else
            mainFrame.exportManualShoppingListScrollFrame.verticalScrollRange = math.max(0, contentHeight - viewportHeight)
        end
    end

    local function build_manual_shopping_rows(rows)
        rows = rows or {}
        local entries = {}
        for index, row in ipairs(rows) do
            local rowFrame = ensure_manual_shopping_row(index)
            entries[index] = {
                rowData = row,
                rowFrame = rowFrame,
                checked = false,
            }
        end
        mainFrame.exportManualShoppingListEntries = entries

        for index = #rows + 1, #(mainFrame.exportManualShoppingListRows or {}) do
            local rowFrame = mainFrame.exportManualShoppingListRows[index]
            rowFrame.shoppingEntry = nil
            rowFrame.rowData = nil
            rowFrame:Hide()
        end

        layout_manual_shopping_rows(true)
        if #rows > 0 then
            mainFrame.exportManualShoppingListEmptyText:Hide()
        else
            mainFrame.exportManualShoppingListEmptyText:Show()
        end
    end

    function mainFrame:RefreshManualShoppingListLayout()
        layout_manual_shopping_rows(false)
    end

    mainFrame.exportManualShoppingListModal:SetScript("OnSizeChanged", function()
        mainFrame:RefreshManualShoppingListLayout()
    end)
    if not mainFrame.exportManualShoppingListResizeGrip and type(makeResizeGrip) == "function" then
        mainFrame.exportManualShoppingListResizeGrip = makeResizeGrip(mainFrame.exportManualShoppingListModal, {
            minWidth = 440,
            minHeight = 320,
            maxWidth = 900,
            maxHeight = 700,
        })
    end
    mainFrame:RefreshManualShoppingListLayout()

    local function first_point(frame)
        if frame and type(frame.GetPoint) == "function" then
            return frame:GetPoint(1)
        end

        local point = frame and frame.points and frame.points[1]
        if point then
            return unpack(point)
        end

        return nil
    end

    function mainFrame:RestoreManualShoppingListPosition(db)
        local exportSettings = self:GetExportUiState(db)
        local saved = exportSettings.manualShoppingListPosition or {}
        local point = tostring(saved.point or "CENTER")
        local relativePoint = tostring(saved.relativePoint or point)
        local offsetX = tonumber(saved.x or 0) or 0
        local offsetY = tonumber(saved.y or 0) or 0

        self.exportManualShoppingListModal:ClearAllPoints()
        self.exportManualShoppingListModal:SetPoint(point, _G.UIParent, relativePoint, offsetX, offsetY)
        return saved
    end

    function mainFrame:PersistManualShoppingListPosition(db)
        local exportSettings = self:GetExportUiState(db)
        local point, _, relativePoint, offsetX, offsetY = first_point(self.exportManualShoppingListModal)
        exportSettings.manualShoppingListPosition = {
            point = point or "CENTER",
            relativePoint = relativePoint or point or "CENTER",
            x = tonumber(offsetX or 0) or 0,
            y = tonumber(offsetY or 0) or 0,
        }
        return exportSettings.manualShoppingListPosition
    end

    function mainFrame:GetExportUiState(db)
        db = db or currentDb()
        local store = ns.data.store or ns.modules.store
        local exportSettings = store.GetExportSettings(db)
        exportSettings.selectedPreset = normalizeExportPresetName(exportSettings.selectedPreset)
        exportSettings.shoppingListName = normalizeShoppingListName(exportSettings.shoppingListName)
        exportSettings.customTemplate = cloneExportTemplate(exportSettings.customTemplate)
        exportSettings.manualShoppingListPosition = exportSettings.manualShoppingListPosition or nil
        return exportSettings
    end

    function mainFrame:LoadExportSettingsFromDb(db)
        local exportSettings = self:GetExportUiState(db)
        self.exportSelectedPreset = normalizeExportPresetName(exportSettings.selectedPreset)
        self.exportShoppingListName = normalizeShoppingListName(exportSettings.shoppingListName)
        self.exportCustomTemplate = cloneExportTemplate(exportSettings.customTemplate)
        self:RestoreManualShoppingListPosition(db)
        self:RelayoutExportActionCards()
        return exportSettings
    end

    function mainFrame:PersistExportSettings(db)
        local exportSettings = self:GetExportUiState(db)
        exportSettings.selectedPreset = normalizeExportPresetName(self.exportSelectedPreset)
        exportSettings.shoppingListName = normalizeShoppingListName(self.exportShoppingListName)
        exportSettings.customTemplate = cloneExportTemplate(self.exportCustomTemplate)
        if self.exportManualShoppingListModal then
            local position = self:PersistManualShoppingListPosition(db)
            exportSettings.manualShoppingListPosition = position
        end
        return exportSettings
    end

    function mainFrame:RefreshExportControlVisibility()
        local showAuctionatorControls = false
        local showCustomControls = normalizeExportPresetName(self.exportSelectedPreset) == "Custom"

        setFrameShown(self.exportAuctionatorListNameInput, showAuctionatorControls)
        setFrameShown(self.exportDelimiterInput, showCustomControls)
        setFrameShown(self.exportFieldsInput, showCustomControls)
        setFrameShown(self.exportHeaderToggleButton, showCustomControls)
        setFrameShown(self.exportApplyCustomButton, showCustomControls)
        setFrameShown(self.exportPresetCustomButton, false)
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

        if type(scrollChild.SetWidth) == "function" then
            scrollChild:SetWidth(math.max(0, scrollFrame:GetWidth() - 12))
        end
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

    function mainFrame:ShowExportOutput(presetName, rows)
        local exportDialog = ns.modules.exportDialog
        local state = exportDialog and type(exportDialog.BuildPresetState) == "function"
            and exportDialog.BuildPresetState(rows or {}, presetName, {
                shoppingListName = normalizeShoppingListName(self.exportShoppingListName),
            })
            or { presetName = presetName, text = "" }

        self.exportSelectedPreset = normalizeExportPresetName(state.presetName or presetName)
        self.exportModalTitle:SetText(string.format("%s Export", self.exportSelectedPreset))
        self.exportModalHint:SetText("Select all or copy the generated output into external tools.")
        set_export_modal_status("")
        setFrameShown(self.exportModalBuyAllButton, false)
        setFrameShown(self.exportModalMissingOnlyButton, false)
        setFrameShown(self.exportModalScrollFrame, true)
        setFrameShown(self.exportModalSelectAllButton, true)
        setFrameShown(self.exportModalCopyButton, false)
        self.exportModalOutputInput:SetText(state.text or "")
        self:RefreshExportModalScrollMetrics()
        self.exportModal:Show()
        return state
    end

    function mainFrame:CompleteScopedExport(includeAll)
        local rows = self.exportPendingRows or self.tableRowsData or {}
        if not includeAll then
            local exportsModule = ns.modules.exports
            if exportsModule and type(exportsModule.FilterRowsUnavailableElsewhere) == "function" then
                rows = exportsModule.FilterRowsUnavailableElsewhere(rows)
            end
        end

        return self:ShowExportOutput(self.exportSelectedPreset or "Auctionator", rows)
    end

    function mainFrame:OpenExportStockedElsewhereModal(row)
        row = row or {}
        local lines = {}
        local totalExcess = tonumber(row.excessQtyValue or row.excessQty or 0) or 0
        local targetTab = tostring(row.bankTab or "")
        if totalExcess > 0 then
            if targetTab ~= "" and targetTab ~= "GLOBAL" then
                lines[#lines + 1] = string.format("Total excess outside %s: %d", targetTab, totalExcess)
            else
                lines[#lines + 1] = string.format("Total excess outside the assigned minimum tab: %d", totalExcess)
            end
            lines[#lines + 1] = ""
        end
        for _, tab in ipairs(row.stockedElsewhereTabs or {}) do
            table.insert(lines, string.format("%s: %s", tostring(tab.tabName or "Unknown"), tostring(tab.quantity or 0)))
        end
        self.exportStockedElsewhereTitle:SetText(tostring(row.itemName or "Stocked Elsewhere"))
        self.exportStockedElsewhereText:SetText(#lines > 0 and table.concat(lines, "\n") or "No other bank tabs found.")
        self.exportStockedElsewhereModal:Show()
        return self.exportStockedElsewhereModal
    end

    function mainFrame:OpenManualShoppingList(rows)
        build_manual_shopping_rows(rows or self.tableRowsData or {})
        self:RestoreManualShoppingListPosition(currentDb())
        self.exportManualShoppingListModal:Show()
        return self.exportManualShoppingListModal
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
            self:ShowExportOutput(self.exportSelectedPreset, rows)
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

    mainFrame.exportModalOutputInput.EditBox:SetScript("OnTextChanged", function()
        mainFrame:RefreshExportModalScrollMetrics()
    end)

    mainFrame.exportPresetSpreadsheetButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("CSV")
    end)

    mainFrame.exportPresetAuctionatorButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("Auctionator")
    end)

    mainFrame.exportPresetTsmButton:SetScript("OnClick", function()
        mainFrame:SelectExportPreset("TSM")
    end)

    mainFrame.exportManualShoppingListButton:SetScript("OnClick", function()
        mainFrame:OpenManualShoppingList(mainFrame.tableRowsData or {})
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
        if type(mainFrame.exportModalOutputInput.SetFocus) == "function" then
            mainFrame.exportModalOutputInput:SetFocus()
        end
        if type(mainFrame.exportModalOutputInput.SetCursorPosition) == "function" then
            mainFrame.exportModalOutputInput:SetCursorPosition(0)
        end
        mainFrame.exportModalOutputInput:HighlightText(0, -1)
        set_export_modal_status("Selected all output. Press Ctrl+C to copy.")
    end)

    mainFrame.exportModalCloseButton:SetScript("OnClick", function()
        mainFrame.exportModal:Hide()
    end)

    mainFrame.exportModalBuyAllButton:SetScript("OnClick", function()
        mainFrame:CompleteScopedExport(true)
    end)

    mainFrame.exportModalMissingOnlyButton:SetScript("OnClick", function()
        mainFrame:CompleteScopedExport(false)
    end)

    mainFrame.exportStockedElsewhereCloseButton:SetScript("OnClick", function()
        mainFrame.exportStockedElsewhereModal:Hide()
    end)

    mainFrame.exportManualShoppingListCloseButton:SetScript("OnClick", function()
        mainFrame.exportManualShoppingListModal:Hide()
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
