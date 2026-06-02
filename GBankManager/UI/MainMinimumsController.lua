local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainMinimumsController = ns.modules.mainMinimumsController or {}
local craftedQualityUtil = ns.modules.craftedQuality or {}
local itemDisplay = ns.modules.itemDisplay or {}
local transport = ns.modules.syncTransport or {}
local permissions = ns.modules.permissions or ns.modules.auth or {}
local minimumsPortability = ns.modules.minimumsPortability or {}
if craftedQualityUtil.NormalizeDisplayAtlas == nil and type(_G.dofile) == "function" then
    craftedQualityUtil = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end
if itemDisplay.BuildDisplayPayload == nil and type(_G.dofile) == "function" then
    itemDisplay = _G.dofile("GBankManager/Domain/ItemDisplay.lua")
end
if minimumsPortability.Export == nil and type(_G.dofile) == "function" then
    minimumsPortability = _G.dofile("GBankManager/Domain/MinimumsPortability.lua")
end

local function non_inventory_atlas(itemID, atlasName, craftedQuality, maxQuality)
    if type(craftedQualityUtil.GetNonInventoryDisplayAtlasForItem) == "function" then
        return craftedQualityUtil.GetNonInventoryDisplayAtlasForItem(itemID, atlasName, craftedQuality, "reagent", maxQuality)
    end

    if type(craftedQualityUtil.GetDisplayAtlasForItem) == "function" then
        return craftedQualityUtil.GetDisplayAtlasForItem(itemID, atlasName, craftedQuality, "reagent", maxQuality)
    end

    if type(craftedQualityUtil.GetDisplayAtlas) == "function" then
        return craftedQualityUtil.GetDisplayAtlas(atlasName, craftedQuality, "reagent", maxQuality)
    end

    return tostring(atlasName or "")
end

local function build_item_display(item)
    local itemCatalog = ns.modules.itemCatalog or {}
    if type(itemCatalog.HydrateItem) == "function" then
        itemCatalog.HydrateItem(item)
    end
    if type(itemDisplay.BuildDisplayPayload) == "function" then
        return itemDisplay.BuildDisplayPayload(item)
    end

    return {
        visibleText = tostring((item or {}).itemName or (item or {}).name or "Unknown"),
    }
end

local function minimum_rule_key(rule)
    return table.concat({
        tostring((rule or {}).itemID or ""),
        tostring((rule or {}).scope or "GLOBAL"),
        tostring((rule or {}).tabName or ""),
    }, "|")
end

local function current_policy(db)
    local store = ns.data.store or ns.modules.store
    return store and type(store.GetAuthPolicy) == "function" and store.GetAuthPolicy(db) or (db or {}).auth or {}
end

local function active_guild_key(db)
    local store = ns.modules.store or ns.data.store
    local root = (ns.state or {}).dbRoot
    local rootGuildKey = type(root) == "table" and tostring(root.activeGuildKey or "") or ""
    if rootGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(rootGuildKey)) then
        return rootGuildKey
    end

    local dbGuildKey = tostring((((db or {}).meta or {}).guildName) or "")
    if dbGuildKey ~= "" and not (store and type(store.IsPlaceholderGuildName) == "function" and store.IsPlaceholderGuildName(dbGuildKey)) then
        return dbGuildKey
    end

    local context = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
    return tostring(context.guildName or "Unknown")
end

local function actor_can_manage_minimums(db)
    local context = type(permissions.GetLivePlayerContext) == "function" and permissions.GetLivePlayerContext(db) or {}
    local can = type(permissions.Can) == "function" and permissions.Can or nil
    if type(can) ~= "function" then
        return true, context
    end

    local policy = current_policy(db)
    return can(context, "minimum_add", policy)
        or can(context, "minimum_edit", policy)
        or can(context, "minimum_delete", policy),
        context
end

local function minimum_dropdown_width(tabOptions, minimumWidth, maximumWidth)
    local width = minimumWidth or 168
    local maxWidth = maximumWidth or 260

    for _, tabName in ipairs(tabOptions or {}) do
        local candidateWidth = (string.len(tostring(tabName or "")) * 8) + 28
        if candidateWidth > width then
            width = candidateWidth
        end
    end

    if width > maxWidth then
        return maxWidth
    end

    return width
end

local MINIMUM_DRAFT_ROW_COLORS = {
    added = { 0.12, 0.36, 0.16, 0.98 },
    changed = { 0.42, 0.34, 0.10, 0.98 },
    deleted = { 0.44, 0.12, 0.12, 0.98 },
    attention = { 0.62, 0.32, 0.08, 0.98 },
}

local MINIMUM_ACTION_BUTTON_BOTTOM_INSET = 32

local function count_lines(text)
    local lineCount = 1
    text = tostring(text or "")

    for _ in string.gmatch(text, "\n") do
        lineCount = lineCount + 1
    end

    return lineCount
end

local function pretty_print_json(text)
    text = tostring(text or "")
    if text == "" then
        return ""
    end

    local parts = {}
    local indentLevel = 0
    local inString = false
    local isEscaped = false

    local function append_indent()
        if indentLevel <= 0 then
            return
        end
        parts[#parts + 1] = string.rep("  ", indentLevel)
    end

    for index = 1, #text do
        local char = text:sub(index, index)

        if inString then
            parts[#parts + 1] = char
            if isEscaped then
                isEscaped = false
            elseif char == "\\" then
                isEscaped = true
            elseif char == "\"" then
                inString = false
            end
        else
            if char == "\"" then
                inString = true
                parts[#parts + 1] = char
            elseif char == "{" or char == "[" then
                parts[#parts + 1] = char
                indentLevel = indentLevel + 1
                parts[#parts + 1] = "\n"
                append_indent()
            elseif char == "}" or char == "]" then
                indentLevel = math.max(0, indentLevel - 1)
                parts[#parts + 1] = "\n"
                append_indent()
                parts[#parts + 1] = char
            elseif char == "," then
                parts[#parts + 1] = char
                parts[#parts + 1] = "\n"
                append_indent()
            elseif char == ":" then
                parts[#parts + 1] = ": "
            elseif char ~= " " and char ~= "\n" and char ~= "\r" and char ~= "\t" then
                parts[#parts + 1] = char
            end
        end
    end

    return table.concat(parts)
end

function mainMinimumsController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local makeExportOutputInput = options.makeExportOutputInput or makeInput
    local setButtonIcon = options.setButtonIcon
    local parseNumber = options.parseNumber
    local currentDb = options.currentDb
    local applyTableRowStyle = options.applyTableRowStyle
    local createItemSearchSelector = options.createItemSearchSelector
    local theme = options.theme or {}

    mainFrame.minimumsPanel = mainFrame.minimumsPanel or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumsPanel:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.minimumsPanel:SetPoint("RIGHT", mainFrame.content, "RIGHT", -24, 0)
    mainFrame.minimumsPanel:SetHeight(72)
    applyPanelStyle(mainFrame.minimumsPanel, theme.colors.panel)
    mainFrame.minimumsPanel.transparentActions = true
    if type(mainFrame.minimumsPanel.SetBackdrop) == "function" then
        mainFrame.minimumsPanel:SetBackdrop(nil)
    end
    mainFrame.minimumsPanel:Hide()

    mainFrame.minimumsTitle = mainFrame.minimumsTitle or makeLabel(mainFrame.minimumsPanel, "Minimum Draft Actions", "GameFontHighlight")
    mainFrame.minimumsTitle:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -16)
    mainFrame.minimumsTitle:Hide()

    mainFrame.minimumsHint = mainFrame.minimumsHint or makeLabel(mainFrame.minimumsPanel, "Use Add to stage items, edit Bank Tab / Restock / Minimum inline, Save to commit, or Undo to discard draft changes.", "GameFontHighlightSmall")
    mainFrame.minimumsHint:SetPoint("TOPLEFT", mainFrame.minimumsTitle, "BOTTOMLEFT", 0, -8)
    mainFrame.minimumsHint:Hide()

    mainFrame.minimumEditorStateText = mainFrame.minimumEditorStateText or makeLabel(mainFrame.minimumsPanel, "No draft minimum changes yet.", "GameFontHighlightSmall")
    if type(mainFrame.minimumEditorStateText.ClearAllPoints) == "function" then
        mainFrame.minimumEditorStateText:ClearAllPoints()
    end
    mainFrame.minimumEditorStateText:SetPoint("BOTTOMLEFT", mainFrame.minimumsPanel, "BOTTOMLEFT", 16, 8)
    mainFrame.minimumEditorStateText:Hide()

    mainFrame.minimumEnabledOnlyButton = mainFrame.minimumEnabledOnlyButton or makeButton(mainFrame.minimumsPanel, 110, 28, "Enabled Only")
    mainFrame.minimumEnabledOnlyButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumsPanel, "BOTTOMRIGHT", -16, MINIMUM_ACTION_BUTTON_BOTTOM_INSET)

    mainFrame.minimumShowAllButton = mainFrame.minimumShowAllButton or makeButton(mainFrame.minimumsPanel, 92, 28, "Show All")
    mainFrame.minimumShowAllButton:SetPoint("RIGHT", mainFrame.minimumEnabledOnlyButton, "LEFT", -8, 0)
    mainFrame.minimumShowAllToggleButton = mainFrame.minimumEnabledOnlyButton

    mainFrame.minimumSearchLabel = mainFrame.minimumSearchLabel or makeLabel(mainFrame.minimumsPanel, "Search", "GameFontHighlightSmall")
    mainFrame.minimumSearchLabel:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 16, -16)
    mainFrame.minimumSearchLabel:Hide()

    mainFrame.minimumSearchInput = mainFrame.minimumSearchInput or makeInput(mainFrame.minimumsPanel, 120, 22)
    mainFrame.minimumSearchInput:SetPoint("TOPLEFT", mainFrame.minimumSearchLabel, "BOTTOMLEFT", 0, -4)
    mainFrame.minimumSearchInput:Hide()

    mainFrame.minimumManualOnlyToggleButton = mainFrame.minimumManualOnlyToggleButton or makeButton(mainFrame.minimumsPanel, 86, 28, "Manual Only")
    mainFrame.minimumManualOnlyToggleButton:SetPoint("RIGHT", mainFrame.minimumSearchInput, "LEFT", -8, 0)
    mainFrame.minimumManualOnlyToggleButton:Hide()

    mainFrame.minimumNewButton = mainFrame.minimumNewButton or makeButton(mainFrame.minimumsPanel, 64, 28, "Add")
    mainFrame.minimumNewButton:SetPoint("BOTTOMLEFT", mainFrame.minimumsPanel, "BOTTOMLEFT", 16, MINIMUM_ACTION_BUTTON_BOTTOM_INSET)

    mainFrame.minimumSaveButton = mainFrame.minimumSaveButton or makeButton(mainFrame.minimumsPanel, 88, 28, "Save")
    mainFrame.minimumSaveButton:SetPoint("LEFT", mainFrame.minimumNewButton, "RIGHT", 8, 0)
    mainFrame.minimumSaveButton.labelText:SetText("Save All")

    mainFrame.minimumExportButton = mainFrame.minimumExportButton or makeButton(mainFrame.minimumsPanel, 70, 28, "Export")
    mainFrame.minimumExportButton:SetPoint("LEFT", mainFrame.minimumSaveButton, "RIGHT", 8, 0)

    mainFrame.minimumImportButton = mainFrame.minimumImportButton or makeButton(mainFrame.minimumsPanel, 70, 28, "Import")
    mainFrame.minimumImportButton:SetPoint("LEFT", mainFrame.minimumExportButton, "RIGHT", 8, 0)

    mainFrame.minimumSaveAllButton = mainFrame.minimumSaveAllButton or makeButton(mainFrame.minimumsPanel, 84, 28, "Undo")
    mainFrame.minimumSaveAllButton:SetPoint("LEFT", mainFrame.minimumImportButton, "RIGHT", 8, 0)
    mainFrame.minimumSaveAllButton:Hide()

    mainFrame.minimumEditorPanel = mainFrame.minimumEditorPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumsPanel, "BackdropTemplate")
    mainFrame.minimumEditorPanel:SetPoint("TOPLEFT", mainFrame.minimumsPanel, "TOPLEFT", 220, -12)
    mainFrame.minimumEditorPanel:SetPoint("BOTTOMRIGHT", mainFrame.minimumsPanel, "BOTTOMRIGHT", -140, 12)
    applyPanelStyle(mainFrame.minimumEditorPanel, theme.colors.background)
    mainFrame.minimumEditorPanel:Hide()

    mainFrame.minimumEditorTitle = mainFrame.minimumEditorTitle or makeLabel(mainFrame.minimumEditorPanel, "Selected Row", "GameFontHighlightSmall")
    mainFrame.minimumEditorTitle:SetPoint("TOPLEFT", mainFrame.minimumEditorPanel, "TOPLEFT", 12, -10)

    mainFrame.minimumEditorItemText = mainFrame.minimumEditorItemText or makeLabel(mainFrame.minimumEditorPanel, "Select a minimum row to edit it here.", "GameFontHighlightSmall")
    mainFrame.minimumEditorItemText:SetPoint("TOPLEFT", mainFrame.minimumEditorTitle, "BOTTOMLEFT", 0, -6)
    if type(mainFrame.minimumEditorItemText.SetWidth) == "function" then
        mainFrame.minimumEditorItemText:SetWidth(300)
    end

    mainFrame.minimumEditorBankTabLabel = mainFrame.minimumEditorBankTabLabel or makeLabel(mainFrame.minimumEditorPanel, "Bank Tab", "GameFontHighlightSmall")
    mainFrame.minimumEditorBankTabLabel:SetPoint("TOPLEFT", mainFrame.minimumEditorItemText, "BOTTOMLEFT", 0, -10)

    mainFrame.minimumEditorBankTabValueText = mainFrame.minimumEditorBankTabValueText or makeLabel(mainFrame.minimumEditorPanel, "-", "GameFontHighlightSmall")
    mainFrame.minimumEditorBankTabValueText:SetPoint("TOPLEFT", mainFrame.minimumEditorBankTabLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumEditorBankTabDropdownButton = mainFrame.minimumEditorBankTabDropdownButton or makeButton(mainFrame.minimumEditorPanel, 168, 22, "Select Bank Tab")
    mainFrame.minimumEditorBankTabDropdownButton:SetPoint("TOPLEFT", mainFrame.minimumEditorBankTabLabel, "BOTTOMLEFT", 0, -2)
    mainFrame.minimumEditorBankTabDropdownPanel = mainFrame.minimumEditorBankTabDropdownPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumEditorPanel, "BackdropTemplate")
    applyPanelStyle(mainFrame.minimumEditorBankTabDropdownPanel, theme.colors.panelAlt)
    mainFrame.minimumEditorBankTabDropdownOptions = mainFrame.minimumEditorBankTabDropdownOptions or {}

    mainFrame.minimumEditorRestockLabel = mainFrame.minimumEditorRestockLabel or makeLabel(mainFrame.minimumEditorPanel, "Restock", "GameFontHighlightSmall")
    mainFrame.minimumEditorRestockLabel:SetPoint("LEFT", mainFrame.minimumEditorBankTabLabel, "RIGHT", 180, 0)

    mainFrame.minimumEditorRestockToggleButton = mainFrame.minimumEditorRestockToggleButton or makeButton(mainFrame.minimumEditorPanel, 88, 22, "Yes")
    mainFrame.minimumEditorRestockToggleButton:SetPoint("TOPLEFT", mainFrame.minimumEditorRestockLabel, "BOTTOMLEFT", 0, -2)

    mainFrame.minimumEditorQuantityLabel = mainFrame.minimumEditorQuantityLabel or makeLabel(mainFrame.minimumEditorPanel, "Minimum", "GameFontHighlightSmall")
    mainFrame.minimumEditorQuantityLabel:SetPoint("LEFT", mainFrame.minimumEditorRestockLabel, "RIGHT", 110, 0)

    mainFrame.minimumEditorQuantityInput = mainFrame.minimumEditorQuantityInput or makeInput(mainFrame.minimumEditorPanel, 78, 22)
    mainFrame.minimumEditorQuantityInput:SetPoint("TOPLEFT", mainFrame.minimumEditorQuantityLabel, "BOTTOMLEFT", 0, -2)

    mainFrame.minimumEditorRemoveButton = mainFrame.minimumEditorRemoveButton or makeButton(mainFrame.minimumEditorPanel, 26, 22, "-")
    mainFrame.minimumEditorRemoveButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumEditorPanel, "BOTTOMRIGHT", -12, 10)
    setButtonIcon(mainFrame.minimumEditorRemoveButton, "remove")

    mainFrame.minimumEditorUndoButton = mainFrame.minimumEditorUndoButton or makeButton(mainFrame.minimumEditorPanel, 26, 22, "<")
    mainFrame.minimumEditorUndoButton:SetPoint("RIGHT", mainFrame.minimumEditorRemoveButton, "LEFT", -6, 0)
    setButtonIcon(mainFrame.minimumEditorUndoButton, "undo")

    mainFrame.minimumAddModal = mainFrame.minimumAddModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumAddModal:SetSize(500, 340)
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
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.minimumAddModal, 20, "FULLSCREEN_DIALOG")
    end

    mainFrame.minimumAddModalTitle = mainFrame.minimumAddModalTitle or makeLabel(mainFrame.minimumAddModal, "Add Minimum Item", "GameFontHighlight")
    mainFrame.minimumAddModalTitle:SetPoint("TOPLEFT", mainFrame.minimumAddModal, "TOPLEFT", 16, -16)

    mainFrame.minimumAddModalHint = mainFrame.minimumAddModalHint or makeLabel(mainFrame.minimumAddModal, "Search by Item ID or Item Name, then add the item and finish Bank Tab / Restock / Minimum inline in the table.", "GameFontHighlightSmall")
    mainFrame.minimumAddModalHint:SetPoint("TOPLEFT", mainFrame.minimumAddModalTitle, "BOTTOMLEFT", 0, -8)
    mainFrame.minimumAddModalHint:SetWidth(452)

    mainFrame.minimumAddSearchSelector = mainFrame.minimumAddSearchSelector or createItemSearchSelector(mainFrame.minimumAddModal, {
        width = 452,
        itemIDInputWidth = 92,
        itemNameInputWidth = 196,
        selectedItemTextWidth = 420,
        resultsPanelWidth = 452,
        resultsPanelHeight = 74,
        minimumNameQueryLength = 2,
        showQualityIcon = true,
        resolveQuery = function(query)
            local itemCatalog = ns.modules.itemCatalog
            return itemCatalog and type(itemCatalog.ResolveSearchSessionQuery) == "function"
                and itemCatalog.ResolveSearchSessionQuery(mainFrame:GetMinimumSearchSession(), query)
                or { status = "missing", matches = {} }
        end,
        onResolved = function(item)
            if item then
                mainFrame:RememberMinimumSearchItem(item)
            end
        end,
        onSelectionChanged = function(item)
            mainFrame.minimumAddSelectedCatalogItem = item
            if mainFrame.minimumAddButton then
                mainFrame.minimumAddButton:SetEnabled(item ~= nil)
            end
        end,
    })
    mainFrame.minimumAddSearchSelector:SetPoint("TOPLEFT", mainFrame.minimumAddModalHint, "BOTTOMLEFT", 0, -14)

    mainFrame.minimumAddItemIDLabel = mainFrame.minimumAddSearchSelector.itemIDLabel
    mainFrame.minimumAddItemNameLabel = mainFrame.minimumAddSearchSelector.itemNameLabel
    mainFrame.minimumAddItemIDInput = mainFrame.minimumAddSearchSelector.itemIDInput
    mainFrame.minimumAddItemNameInput = mainFrame.minimumAddSearchSelector.itemNameInput
    mainFrame.minimumAddSelectedItemLabel = mainFrame.minimumAddSearchSelector.selectedItemLabel
    mainFrame.minimumAddSelectedItemNameText = mainFrame.minimumAddSearchSelector.selectedItemNameText
    mainFrame.minimumAddSelectedItemQualityIcon = mainFrame.minimumAddSearchSelector.selectedItemQualityIcon
    mainFrame.minimumAddResultsLabel = mainFrame.minimumAddSearchSelector.resultsLabel
    mainFrame.minimumAddResultsPanel = mainFrame.minimumAddSearchSelector.resultsPanel
    mainFrame.minimumAddMatchButtons = mainFrame.minimumAddSearchSelector.matchButtons

    mainFrame.minimumAddQuantityLabel = mainFrame.minimumAddQuantityLabel or makeLabel(mainFrame.minimumAddModal, "Minimum", "GameFontHighlightSmall")
    mainFrame.minimumAddQuantityLabel:SetPoint("TOPLEFT", mainFrame.minimumAddSearchSelector.resultsPanel, "BOTTOMLEFT", 0, -14)

    mainFrame.minimumAddQuantityInput = mainFrame.minimumAddQuantityInput or makeInput(mainFrame.minimumAddModal, 64, 22)
    mainFrame.minimumAddQuantityInput:SetPoint("TOPLEFT", mainFrame.minimumAddQuantityLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumAddButton = mainFrame.minimumAddButton or makeButton(mainFrame.minimumAddModal, 64, 28, "Add")
    mainFrame.minimumAddButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumAddModal, "BOTTOMRIGHT", -16, 16)
    mainFrame.minimumAddButton:SetEnabled(false)

    mainFrame.minimumAddCancelButton = mainFrame.minimumAddCancelButton or makeButton(mainFrame.minimumAddModal, 72, 28, "Cancel")
    mainFrame.minimumAddCancelButton:SetPoint("RIGHT", mainFrame.minimumAddButton, "LEFT", -8, 0)

    mainFrame.minimumImportModal = mainFrame.minimumImportModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumImportModal:SetSize(520, 360)
    mainFrame.minimumImportModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    applyPanelStyle(mainFrame.minimumImportModal, theme.colors.panelAlt)
    mainFrame.minimumImportModal:Hide()
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.minimumImportModal, 22, "FULLSCREEN_DIALOG")
    end

    mainFrame.minimumImportModalTitle = mainFrame.minimumImportModalTitle or makeLabel(mainFrame.minimumImportModal, "Import Minimums", "GameFontHighlight")
    mainFrame.minimumImportModalTitle:SetPoint("TOPLEFT", mainFrame.minimumImportModal, "TOPLEFT", 16, -16)

    mainFrame.minimumImportStatusText = mainFrame.minimumImportStatusText or makeLabel(mainFrame.minimumImportModal, "", "GameFontHighlightSmall")
    mainFrame.minimumImportStatusText:SetPoint("TOPLEFT", mainFrame.minimumImportModalTitle, "BOTTOMLEFT", 0, -8)
    if type(mainFrame.minimumImportStatusText.SetWidth) == "function" then
        mainFrame.minimumImportStatusText:SetWidth(480)
    end

    mainFrame.minimumImportInput = mainFrame.minimumImportInput or makeInput(mainFrame.minimumImportModal, 488, 120)
    mainFrame.minimumImportInput:SetPoint("TOPLEFT", mainFrame.minimumImportStatusText, "BOTTOMLEFT", 0, -10)

    mainFrame.minimumImportReviewPanel = mainFrame.minimumImportReviewPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumImportModal, "BackdropTemplate")
    mainFrame.minimumImportReviewPanel:SetPoint("TOPLEFT", mainFrame.minimumImportInput, "BOTTOMLEFT", 0, -10)
    mainFrame.minimumImportReviewPanel:SetPoint("RIGHT", mainFrame.minimumImportModal, "RIGHT", -16, 0)
    mainFrame.minimumImportReviewPanel:SetHeight(150)
    applyPanelStyle(mainFrame.minimumImportReviewPanel, theme.colors.panel)
    mainFrame.minimumImportReviewRowsFrames = mainFrame.minimumImportReviewRowsFrames or {}

    mainFrame.minimumImportApplyButton = mainFrame.minimumImportApplyButton or makeButton(mainFrame.minimumImportModal, 88, 28, "Apply")
    mainFrame.minimumImportApplyButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumImportModal, "BOTTOMRIGHT", -16, 16)
    mainFrame.minimumImportApplyButton:SetEnabled(false)

    mainFrame.minimumImportPreviewButton = mainFrame.minimumImportPreviewButton or makeButton(mainFrame.minimumImportModal, 88, 28, "Preview")
    mainFrame.minimumImportPreviewButton:SetPoint("RIGHT", mainFrame.minimumImportApplyButton, "LEFT", -8, 0)

    mainFrame.minimumImportCancelButton = mainFrame.minimumImportCancelButton or makeButton(mainFrame.minimumImportModal, 72, 28, "Cancel")
    mainFrame.minimumImportCancelButton:SetPoint("RIGHT", mainFrame.minimumImportPreviewButton, "LEFT", -8, 0)

    mainFrame.minimumExportModal = mainFrame.minimumExportModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumExportModal:SetSize(520, 320)
    mainFrame.minimumExportModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    applyPanelStyle(mainFrame.minimumExportModal, theme.colors.panelAlt)
    mainFrame.minimumExportModal:Hide()
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.minimumExportModal, 23, "FULLSCREEN_DIALOG")
    end

    mainFrame.minimumExportModalTitle = mainFrame.minimumExportModalTitle or makeLabel(mainFrame.minimumExportModal, "Export Minimums", "GameFontHighlight")
    mainFrame.minimumExportModalTitle:SetPoint("TOPLEFT", mainFrame.minimumExportModal, "TOPLEFT", 16, -16)

    mainFrame.minimumExportStatusText = mainFrame.minimumExportStatusText or makeLabel(mainFrame.minimumExportModal, "Select all or copy the portable Minimums payload for later import.", "GameFontHighlightSmall")
    mainFrame.minimumExportStatusText:SetPoint("TOPLEFT", mainFrame.minimumExportModalTitle, "BOTTOMLEFT", 0, -8)
    if type(mainFrame.minimumExportStatusText.SetWidth) == "function" then
        mainFrame.minimumExportStatusText:SetWidth(480)
    end

    mainFrame.minimumExportOutput = mainFrame.minimumExportOutput or makeExportOutputInput(mainFrame.minimumExportModal, 488, 200)
    mainFrame.minimumExportOutput:SetPoint("TOPLEFT", mainFrame.minimumExportStatusText, "BOTTOMLEFT", 0, -10)
    mainFrame.minimumExportOutput:EnableMouseWheel(true)
    mainFrame.minimumExportOutput.verticalScroll = mainFrame.minimumExportOutput.verticalScroll or 0
    mainFrame.minimumExportOutput.verticalScrollRange = mainFrame.minimumExportOutput.verticalScrollRange or 0
    if type(mainFrame.minimumExportOutput.SetVerticalScroll) ~= "function" then
        function mainFrame.minimumExportOutput:SetVerticalScroll(value)
            local clamped = math.max(0, math.min(tonumber(value or 0) or 0, self.verticalScrollRange or 0))
            self.verticalScroll = clamped
        end
    end
    if type(mainFrame.minimumExportOutput.SetBackdrop) == "function" then
        mainFrame.minimumExportOutput:SetBackdrop(nil)
    end
    mainFrame.minimumExportScrollFrame = mainFrame.minimumExportOutput
    mainFrame.minimumExportScrollChild = mainFrame.minimumExportOutput.EditBox
    if type(mainFrame.minimumExportScrollChild.SetBackdrop) == "function" then
        mainFrame.minimumExportScrollChild:SetBackdrop(nil)
    end

    mainFrame.minimumExportSelectAllButton = mainFrame.minimumExportSelectAllButton or makeButton(mainFrame.minimumExportModal, 84, 28, "Select All")
    mainFrame.minimumExportSelectAllButton:SetPoint("BOTTOMLEFT", mainFrame.minimumExportModal, "BOTTOMLEFT", 16, 16)

    mainFrame.minimumExportCloseButton = mainFrame.minimumExportCloseButton or makeButton(mainFrame.minimumExportModal, 72, 28, "Close")
    mainFrame.minimumExportCloseButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumExportModal, "BOTTOMRIGHT", -16, 16)

    mainFrame.minimumDetailsModal = mainFrame.minimumDetailsModal or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.minimumDetailsModal:SetSize(500, 260)
    mainFrame.minimumDetailsModal:SetPoint("CENTER", mainFrame.content, "CENTER", 0, 0)
    mainFrame.minimumDetailsModal.frameStrata = "FULLSCREEN_DIALOG"
    if type(mainFrame.minimumDetailsModal.SetFrameStrata) == "function" then
        mainFrame.minimumDetailsModal:SetFrameStrata(mainFrame.minimumDetailsModal.frameStrata)
    end
    mainFrame.minimumDetailsModal.frameLevel = (mainFrame.frameLevel or 0) + 21
    if type(mainFrame.minimumDetailsModal.SetFrameLevel) == "function" then
        mainFrame.minimumDetailsModal:SetFrameLevel(mainFrame.minimumDetailsModal.frameLevel)
    end
    applyPanelStyle(mainFrame.minimumDetailsModal, theme.colors.panelAlt)
    mainFrame.minimumDetailsModal:Hide()
    if type(mainFrame.RegisterModalFrame) == "function" then
        mainFrame:RegisterModalFrame(mainFrame.minimumDetailsModal, 21, "FULLSCREEN_DIALOG")
    end

    mainFrame.minimumDetailsModalTitle = mainFrame.minimumDetailsModalTitle or makeLabel(mainFrame.minimumDetailsModal, "Minimum Details", "GameFontHighlight")
    mainFrame.minimumDetailsModalTitle:SetPoint("TOPLEFT", mainFrame.minimumDetailsModal, "TOPLEFT", 16, -16)

    mainFrame.minimumDetailsItemQualityIcon = mainFrame.minimumDetailsItemQualityIcon or mainFrame.minimumDetailsModal:CreateTexture()
    mainFrame.minimumDetailsItemQualityIcon:SetPoint("TOPLEFT", mainFrame.minimumDetailsModalTitle, "BOTTOMLEFT", 0, -14)
    if type(mainFrame.minimumDetailsItemQualityIcon.SetWidth) == "function" then
        mainFrame.minimumDetailsItemQualityIcon:SetWidth(18)
    end
    if type(mainFrame.minimumDetailsItemQualityIcon.SetHeight) == "function" then
        mainFrame.minimumDetailsItemQualityIcon:SetHeight(18)
    end
    mainFrame.minimumDetailsItemQualityIcon:Hide()

    mainFrame.minimumDetailsItemNameText = mainFrame.minimumDetailsItemNameText or makeLabel(mainFrame.minimumDetailsModal, "No item selected.", "GameFontNormal")
    mainFrame.minimumDetailsItemNameText:SetPoint("TOPLEFT", mainFrame.minimumDetailsModalTitle, "BOTTOMLEFT", 0, -14)
    if type(mainFrame.minimumDetailsItemNameText.SetWidth) == "function" then
        mainFrame.minimumDetailsItemNameText:SetWidth(320)
    end

    mainFrame.minimumDetailsItemQualityText = mainFrame.minimumDetailsItemQualityText or makeLabel(mainFrame.minimumDetailsModal, "", "GameFontHighlightSmall")
    mainFrame.minimumDetailsItemQualityText:SetPoint("LEFT", mainFrame.minimumDetailsItemNameText, "RIGHT", 6, 0)
    mainFrame.minimumDetailsItemQualityText:Hide()

    mainFrame.minimumDetailsItemIDText = mainFrame.minimumDetailsItemIDText or makeLabel(mainFrame.minimumDetailsModal, "", "GameFontHighlightSmall")
    mainFrame.minimumDetailsItemIDText:SetPoint("TOPLEFT", mainFrame.minimumDetailsItemNameText, "BOTTOMLEFT", 0, -8)

    mainFrame.minimumDetailsStatusText = mainFrame.minimumDetailsStatusText or makeLabel(mainFrame.minimumDetailsModal, "Edit Minimum details here.", "GameFontHighlightSmall")
    mainFrame.minimumDetailsStatusText:SetPoint("TOPLEFT", mainFrame.minimumDetailsItemIDText, "BOTTOMLEFT", 0, -12)
    if type(mainFrame.minimumDetailsStatusText.SetWidth) == "function" then
        mainFrame.minimumDetailsStatusText:SetWidth(452)
    end

    mainFrame.minimumDetailsBankTabLabel = mainFrame.minimumDetailsBankTabLabel or makeLabel(mainFrame.minimumDetailsModal, "Bank Tab", "GameFontHighlightSmall")
    mainFrame.minimumDetailsBankTabLabel:SetPoint("TOPLEFT", mainFrame.minimumDetailsStatusText, "BOTTOMLEFT", 0, -16)
    mainFrame.minimumDetailsBankTabValueText = mainFrame.minimumDetailsBankTabValueText or makeLabel(mainFrame.minimumDetailsModal, "-", "GameFontNormal")
    mainFrame.minimumDetailsBankTabValueText:SetPoint("TOPLEFT", mainFrame.minimumDetailsBankTabLabel, "BOTTOMLEFT", 0, -4)
    mainFrame.minimumDetailsBankTabDropdownButton = mainFrame.minimumDetailsBankTabDropdownButton or makeButton(mainFrame.minimumDetailsModal, 188, 22, "Select Bank Tab")
    mainFrame.minimumDetailsBankTabDropdownButton:SetPoint("TOPLEFT", mainFrame.minimumDetailsBankTabLabel, "BOTTOMLEFT", 0, -4)
    mainFrame.minimumDetailsBankTabDropdownPanel = mainFrame.minimumDetailsBankTabDropdownPanel or _G.CreateFrame("Frame", nil, mainFrame.minimumDetailsModal, "BackdropTemplate")
    applyPanelStyle(mainFrame.minimumDetailsBankTabDropdownPanel, theme.colors.panelAlt)
    mainFrame.minimumDetailsBankTabDropdownOptions = mainFrame.minimumDetailsBankTabDropdownOptions or {}

    mainFrame.minimumDetailsRestockLabel = mainFrame.minimumDetailsRestockLabel or makeLabel(mainFrame.minimumDetailsModal, "Restock", "GameFontHighlightSmall")
    mainFrame.minimumDetailsRestockLabel:SetPoint("LEFT", mainFrame.minimumDetailsBankTabLabel, "RIGHT", 176, 0)
    mainFrame.minimumDetailsRestockToggleButton = mainFrame.minimumDetailsRestockToggleButton or makeButton(mainFrame.minimumDetailsModal, 88, 22, "Yes")
    mainFrame.minimumDetailsRestockToggleButton:SetPoint("TOPLEFT", mainFrame.minimumDetailsRestockLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumDetailsQuantityLabel = mainFrame.minimumDetailsQuantityLabel or makeLabel(mainFrame.minimumDetailsModal, "Minimum", "GameFontHighlightSmall")
    mainFrame.minimumDetailsQuantityLabel:SetPoint("LEFT", mainFrame.minimumDetailsRestockLabel, "RIGHT", 116, 0)
    mainFrame.minimumDetailsQuantityInput = mainFrame.minimumDetailsQuantityInput or makeInput(mainFrame.minimumDetailsModal, 78, 22)
    mainFrame.minimumDetailsQuantityInput:SetPoint("TOPLEFT", mainFrame.minimumDetailsQuantityLabel, "BOTTOMLEFT", 0, -4)

    mainFrame.minimumDetailsConfirmButton = mainFrame.minimumDetailsConfirmButton or makeButton(mainFrame.minimumDetailsModal, 28, 24, "")
    mainFrame.minimumDetailsConfirmButton:SetPoint("BOTTOMRIGHT", mainFrame.minimumDetailsModal, "BOTTOMRIGHT", -16, 16)
    setButtonIcon(mainFrame.minimumDetailsConfirmButton, "add")
    mainFrame.minimumDetailsConfirmButton:SetEnabled(false)

    mainFrame.minimumDetailsRemoveButton = mainFrame.minimumDetailsRemoveButton or makeButton(mainFrame.minimumDetailsModal, 28, 24, "")
    mainFrame.minimumDetailsRemoveButton:SetPoint("RIGHT", mainFrame.minimumDetailsConfirmButton, "LEFT", -8, 0)
    setButtonIcon(mainFrame.minimumDetailsRemoveButton, "remove")
    mainFrame.minimumDetailsRemoveButton:SetEnabled(false)

    mainFrame.minimumDetailsUndoButton = mainFrame.minimumDetailsUndoButton or makeButton(mainFrame.minimumDetailsModal, 28, 24, "")
    mainFrame.minimumDetailsUndoButton:SetPoint("RIGHT", mainFrame.minimumDetailsRemoveButton, "LEFT", -8, 0)
    setButtonIcon(mainFrame.minimumDetailsUndoButton, "undo")
    mainFrame.minimumDetailsUndoButton:SetEnabled(false)

    mainFrame.minimumDetailsCancelButton = mainFrame.minimumDetailsCancelButton or makeButton(mainFrame.minimumDetailsModal, 72, 28, "Cancel")
    mainFrame.minimumDetailsCancelButton:SetPoint("RIGHT", mainFrame.minimumDetailsUndoButton, "LEFT", -8, 0)

    mainFrame.minimumAddBankTabInput = mainFrame.minimumAddBankTabInput or makeInput(mainFrame.minimumAddModal, 110, 22)
    mainFrame.minimumAddBankTabInput:SetPoint("TOPLEFT", mainFrame.minimumAddQuantityInput, "BOTTOMLEFT", 0, -12)
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

    function mainFrame:GetMinimumSettings(db)
        local store = ns.data.store or ns.modules.store
        return store.GetMinimumSettings(db or currentDb())
    end

    function mainFrame:LoadMinimumSettingsFromDb(db)
        local settings = self:GetMinimumSettings(db)
        self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity or 100))
        if self.optionsCriticalThresholdInput then
            self.optionsCriticalThresholdInput:SetText(tostring(settings.criticalThresholdPercent or 50))
        end
        if (self.minimumAddQuantityInput:GetText() or "") == "" then
            self.minimumAddQuantityInput:SetText(tostring(settings.defaultQuantity or 100))
        end
        return settings
    end

    function mainFrame:SaveStockSettings()
        local db = currentDb()
        local settings = self:GetMinimumSettings(db)
        settings.defaultQuantity = parseNumber(self.defaultMinimumInput:GetText() or "") or 100
        settings.criticalThresholdPercent = math.max(0, math.min(100, parseNumber((self.optionsCriticalThresholdInput and self.optionsCriticalThresholdInput:GetText()) or "") or 50))
        self.defaultMinimumInput:SetText(tostring(settings.defaultQuantity))
        if self.optionsCriticalThresholdInput then
            self.optionsCriticalThresholdInput:SetText(tostring(settings.criticalThresholdPercent))
        end
        db.auth = db.auth or {}
        db.auth.restockDefault = settings.defaultQuantity
        if self.authDraftPolicy then
            self.authDraftPolicy.restockDefault = settings.defaultQuantity
        end
        return settings
    end

    function mainFrame:SaveDefaultMinimumSetting()
        local settings = self:SaveStockSettings()
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
            craftedQualityMax = rule.craftedQualityMax,
            draftKey = rule.draftKey,
            originalItemID = rule.originalItemID,
            originalScope = rule.originalScope,
            originalTabName = rule.originalTabName,
            isNewlyAdded = rule.isNewlyAdded == true,
            sourceRequestId = rule.sourceRequestId,
            sourceRequestBackfill = rule.sourceRequestBackfill == true,
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
        local tabName = row.tabKey or row.tabName or row.bankTab
        if row.needsBankTab == true or tabName == "GLOBAL" then
            tabName = nil
        end
        if row.configured ~= true then
            quantity = self:GetMinimumSettings(currentDb()).defaultQuantity or 100
            scope = "TAB"
            if row.needsBankTab == true then
                tabName = nil
            else
                tabName = row.tabKey or row.tabName or row.bankTab
            end
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
            craftedQualityMax = row.craftedQualityMax,
            draftKey = row.rowKey,
            originalItemID = row.originalItemID or tonumber(row.itemID),
            originalScope = row.originalScope or row.scope,
            originalTabName = row.originalTabName,
            sourceRequestId = row.sourceRequestId,
            sourceRequestBackfill = row.sourceRequestBackfill == true,
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

        if self:IsSnapshotBackedMinimumRow(row) then
            return "changed"
        end

        if self:GetMinimumBaselineRule(row) then
            return "changed"
        end

        return "added"
    end

    function mainFrame:IsSnapshotBackedMinimumRow(row)
        if type(row) ~= "table" then
            return false
        end

        local rowKey = tostring(row.rowKey or "")
        if rowKey == "" then
            return false
        end

        for _, itemRow in ipairs((self:GetCurrentSnapshot() or {}).itemRows or {}) do
            local snapshotKey = tostring(itemRow.rowKey or table.concat({
                tostring(itemRow.itemID or ""),
                "TAB",
                tostring(itemRow.tabName or "-"),
            }, "|"))
            if snapshotKey == rowKey then
                return true
            end
        end

        return false
    end

    function mainFrame:GetMergedMinimumRules(db)
        local minimumsView = ns.modules.minimumsView
        local merged = {}

        for _, rule in ipairs((db or {}).minimums or {}) do
            table.insert(merged, self:CloneMinimumRule(rule))
        end

        for _, request in ipairs((db or {}).requests or {}) do
            local bankTab = tostring((request or {}).approvedBankTab or (request or {}).tabName or "")
            if request.approval == "APPROVED"
                and request.fulfillment == "OPEN"
                and not request.minimumRuleKey
                and bankTab == "" then
                table.insert(merged, self:CloneMinimumRule({
                    itemID = request.itemID,
                    itemName = request.itemName,
                    quantity = request.quantity,
                    scope = "GLOBAL",
                    tabName = nil,
                    enabled = true,
                    craftedQuality = request.craftedQuality,
                    craftedQualityIcon = request.craftedQualityIcon,
                    craftedQualityMax = request.craftedQualityMax,
                    draftKey = table.concat({ "request", tostring(request.requestId or request.itemID or ""), "GLOBAL" }, "|"),
                    originalItemID = request.itemID,
                    originalScope = "GLOBAL",
                    originalTabName = nil,
                    sourceRequestId = request.requestId,
                    sourceRequestBackfill = true,
                }))
            end
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
            search = "",
            manualOnly = false,
            columnFilters = self:GetSharedFilterState(),
        })

        for _, row in ipairs(rows or {}) do
            self:BackfillMinimumCraftedTier(row, snapshot)
            row.tierValue = tonumber(row.craftedQuality or 0) or 0
            local tierAtlas = row.craftedQualityIcon or row.craftedQualityPreferredAtlas or row.craftedQualityDisplayAtlas
            local tierMax = row.craftedQualityFamilySize or row.craftedQualityMax
            row.tierIconAtlas = non_inventory_atlas(row.itemID, tierAtlas, row.craftedQuality, tierMax)
            row.tierAtlas = row.tierIconAtlas
            if tostring(row.tierIconAtlas or "") ~= "" then
                row.tier = ""
            end
        end

        rows = minimumsView.SortRows(rows, self.minimumSortState)
        rows = self:DecorateAndPrioritizeMinimumRows(rows)
        self.tableColumnLayout = layout
        self.tableScrollOffset = 0
        self.cachedMinimumRows = rows
        self:ConfigureTable(layout, rows)
        self:RefreshVisibleTableRows()
        self:UpdateMinimumEditorState(rows)

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

        local function neutralize_inline_widget(widget)
            if not widget then
                return
            end

            if type(widget.Hide) == "function" then
                widget:Hide()
            end
            if type(widget.ClearAllPoints) == "function" then
                widget:ClearAllPoints()
            end
            if type(widget.SetScript) == "function" then
                widget:SetScript("OnClick", nil)
                widget:SetScript("OnMouseDown", nil)
                widget:SetScript("OnMouseUp", nil)
                widget:SetScript("OnTextChanged", nil)
                widget:SetScript("OnEditFocusLost", nil)
            end
            if type(widget.SetEnabled) == "function" then
                widget:SetEnabled(false)
            end
            widget.inlineArtifactHidden = true
        end

        neutralize_inline_widget(rowFrame.minimumValueInput)
        neutralize_inline_widget(rowFrame.restockToggleButton)
        neutralize_inline_widget(rowFrame.bankTabValueInput)
        neutralize_inline_widget(rowFrame.bankTabDropdownButton)
        neutralize_inline_widget(rowFrame.bankTabDropdownPanel)
        neutralize_inline_widget(rowFrame.removeButton)
        neutralize_inline_widget(rowFrame.undoButton)
        neutralize_inline_widget(rowFrame.minimumDraftIndicator)
        if rowFrame.bankTabDropdownOptions then
            for _, option in ipairs(rowFrame.bankTabDropdownOptions) do
                neutralize_inline_widget(option)
            end
        end

        rowFrame.minimumInlineArtifactsHidden = true
    end

    local function style_dropdown_button_text(button)
        if not button or not button.labelText then
            return
        end

        if type(button.labelText.ClearAllPoints) == "function" then
            button.labelText:ClearAllPoints()
        end
        button.labelText:SetPoint("LEFT", button, "LEFT", 8, 0)
        if type(button.labelText.SetJustifyH) == "function" then
            button.labelText:SetJustifyH("LEFT")
        end
        if type(button.labelText.SetWidth) == "function" then
            button.labelText:SetWidth(math.max(0, (button:GetWidth() or 0) - 16))
        end
    end

    function mainFrame:GetMinimumRowByKey(rowKey)
        for _, row in ipairs(self.tableRowsData or {}) do
            if row.rowKey == rowKey then
                return row
            end
        end

        return nil
    end

    function mainFrame:GetMinimumStagedCounts(rows)
        local counts = {
            total = 0,
            added = 0,
            changed = 0,
            deleted = 0,
        }

        for _, row in ipairs(rows or self.tableRowsData or {}) do
            local draftState = self:GetMinimumDraftState(row)
            if draftState == "added" or draftState == "changed" or draftState == "deleted" then
                counts.total = counts.total + 1
                counts[draftState] = (counts[draftState] or 0) + 1
            end
        end

        return counts
    end

    function mainFrame:DecorateAndPrioritizeMinimumRows(rows)
        local added = {}
        local changed = {}
        local deleted = {}
        local attention = {}
        local rest = {}
        local badgeByState = {
            added = "ADD",
            changed = "EDIT",
            deleted = "DELETE",
        }

        for _, row in ipairs(rows or {}) do
            local draftState = self:GetMinimumDraftState(row)
            row.minimumDraftState = draftState
            row.draftBadge = badgeByState[draftState]

            if draftState == "added" then
                table.insert(added, row)
            elseif draftState == "changed" then
                table.insert(changed, row)
            elseif draftState == "deleted" then
                table.insert(deleted, row)
            elseif row.needsBankTab == true then
                row.draftBadge = "FIX"
                table.insert(attention, row)
            else
                row.draftBadge = nil
                table.insert(rest, row)
            end
        end

        local ordered = {}
        for _, group in ipairs({ added, changed, deleted, attention, rest }) do
            for _, row in ipairs(group) do
                table.insert(ordered, row)
            end
        end

        return ordered
    end

    function mainFrame:ConfigureMinimumEditorBankTabDropdown(row, state)
        local tabOptions = self:GetKnownMinimumBankTabs(row)
        local dropdownWidth = minimum_dropdown_width(tabOptions, 188, 260)

        self.minimumEditorBankTabDropdownButton:SetWidth(dropdownWidth)
        style_dropdown_button_text(self.minimumEditorBankTabDropdownButton)
        self.minimumEditorBankTabDropdownButton.labelText:SetText(((state and state.tabName) and state.tabName ~= "") and state.tabName or "Select Bank Tab")
        self.minimumEditorBankTabDropdownPanel:ClearAllPoints()
        self.minimumEditorBankTabDropdownPanel:SetPoint("TOPLEFT", self.minimumEditorBankTabDropdownButton, "BOTTOMLEFT", 0, -2)
        self.minimumEditorBankTabDropdownPanel:SetSize(dropdownWidth, math.max(28, (#tabOptions * 24) + 8))

        for index, tabName in ipairs(tabOptions) do
            local option = self.minimumEditorBankTabDropdownOptions[index] or makeButton(self.minimumEditorBankTabDropdownPanel, dropdownWidth - 8, 22, "")
            option.value = tabName
            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", self.minimumEditorBankTabDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
            option:SetWidth(dropdownWidth - 8)
            style_dropdown_button_text(option)
            option.labelText:SetText(tabName)
            option:SetScript("OnClick", function()
                local current = self:GetPendingMinimumDraft(row)
                current.tabName = tabName
                current.scope = "TAB"
                self.minimumPendingDirty = self.minimumPendingDirty or {}
                self.minimumPendingDeleted = self.minimumPendingDeleted or {}
                self.minimumPendingDirty[row.rowKey] = true
                self.minimumPendingDeleted[row.rowKey] = nil
                self.minimumEditorBankTabDropdownButton.labelText:SetText(tabName)
                self.minimumEditorBankTabDropdownPanel:Hide()
                self:ApplyMinimumFilters()
            end)
            option:Show()
            self.minimumEditorBankTabDropdownOptions[index] = option
        end

        for index = #tabOptions + 1, #(self.minimumEditorBankTabDropdownOptions or {}) do
            self.minimumEditorBankTabDropdownOptions[index]:Hide()
        end

        self.minimumEditorBankTabDropdownPanel:Hide()
        self.minimumEditorBankTabDropdownButton:SetScript("OnClick", function()
            if self.minimumEditorBankTabDropdownPanel:IsShown() then
                self.minimumEditorBankTabDropdownPanel:Hide()
            else
                self.minimumEditorBankTabDropdownPanel:Show()
            end
        end)
    end

    function mainFrame:UpdateMinimumEditorState()
        self.minimumEditorPanel:Hide()
        local counts = self:GetMinimumStagedCounts()
        if counts.total > 0 then
            local label = counts.total == 1 and "1 staged change" or string.format("%d staged changes", counts.total)
            self.minimumEditorStateText:SetText(label)
            self.minimumEditorStateText:Show()
            self.minimumSaveAllButton.labelText:SetText("Revert All")
            self.minimumSaveAllButton:Show()
        else
            self.minimumEditorStateText:SetText("")
            self.minimumEditorStateText:Hide()
            self.minimumSaveAllButton:Hide()
        end
    end

    function mainFrame:UpdateMinimumDetailsActionState(row, state)
        state = state or self.minimumDetailsWorkingState or {}
        local warningColor = theme.colors.warning or { 1, 0.82, 0, 1 }
        local dangerColor = { 1, 0.35, 0.35, 1 }
        if type(self.minimumDetailsStatusText.SetTextColor) == "function" then
            self.minimumDetailsStatusText:SetTextColor(unpack(warningColor))
        end

        local quantity = parseNumber(self.minimumDetailsQuantityInput:GetText() or "")
        local itemID = tonumber(state.itemID)
        local itemName = tostring(state.itemName or "")
        local tabName = tostring(state.tabName or "")
        local draftState = row and self:GetMinimumDraftState(row) or nil
        local hasBankTab = tabName ~= ""

        self.minimumDetailsConfirmButton:SetEnabled(itemID ~= nil and itemName ~= "" and hasBankTab and quantity ~= nil)
        self.minimumDetailsRemoveButton:SetEnabled(row ~= nil)
        self.minimumDetailsUndoButton:SetEnabled(row ~= nil and draftState ~= nil)

        if draftState == "deleted" then
            self.minimumDetailsConfirmButton:SetEnabled(false)
            self.minimumDetailsRemoveButton:SetEnabled(false)
            self.minimumDetailsUndoButton:SetEnabled(row ~= nil)
            self.minimumDetailsStatusText:SetText("This minimum is marked for removal. Undo to restore it before Save All.")
            return
        end

        if not hasBankTab then
            self.minimumDetailsStatusText:SetText("Select a Bank Tab to continue.")
            if type(self.minimumDetailsStatusText.SetTextColor) == "function" then
                self.minimumDetailsStatusText:SetTextColor(unpack(dangerColor))
            end
            return
        end

        if quantity == nil then
            self.minimumDetailsStatusText:SetText("Enter a valid Minimum to continue.")
            if type(self.minimumDetailsStatusText.SetTextColor) == "function" then
                self.minimumDetailsStatusText:SetTextColor(unpack(dangerColor))
            end
            return
        end

        if draftState == "changed" then
            self.minimumDetailsStatusText:SetText("Draft changes are pending for this minimum. Confirm to keep editing, Remove to mark deleted, or Undo to restore it.")
            return
        end

        if draftState == "added" then
            self.minimumDetailsStatusText:SetText("This minimum is staged as a new draft row. Confirm to update it or Remove to discard it before Save All.")
            return
        end

        if row then
            self.minimumDetailsStatusText:SetText("Edit this minimum and confirm to stage draft changes.")
            return
        end

        self.minimumDetailsStatusText:SetText("Set the details and confirm to stage this minimum.")
    end

    function mainFrame:IsMinimumDetailsBankTabLocked(row)
        if not row then
            return false
        end

        if row.needsBankTab == true then
            return false
        end

        local draftState = self:GetMinimumDraftState(row)
        if draftState == "added" or draftState == "changed" then
            return false
        end

        return tostring(row.bankTab or row.tabName or "") ~= ""
    end

    function mainFrame:ConfigureMinimumDetailsBankTabDropdown(row, state)
        local tabOptions = self:GetKnownMinimumBankTabs(state or row)
        local dropdownWidth = minimum_dropdown_width(tabOptions, 188, 260)
        local selectedTab = ((state and state.tabName) and state.tabName ~= "") and state.tabName or ((row and row.needsBankTab) and "Select Bank Tab") or (row and row.bankTab) or "Select Bank Tab"
        local isLocked = self:IsMinimumDetailsBankTabLocked(row)

        self.minimumDetailsBankTabDropdownButton:SetWidth(dropdownWidth)
        style_dropdown_button_text(self.minimumDetailsBankTabDropdownButton)
        self.minimumDetailsBankTabDropdownButton.labelText:SetText(selectedTab)
        self.minimumDetailsBankTabDropdownPanel:ClearAllPoints()
        self.minimumDetailsBankTabDropdownPanel:SetPoint("TOPLEFT", self.minimumDetailsBankTabDropdownButton, "BOTTOMLEFT", 0, -2)
        self.minimumDetailsBankTabDropdownPanel:SetSize(dropdownWidth, math.max(28, (#tabOptions * 24) + 8))

        for index, tabName in ipairs(tabOptions) do
            local option = self.minimumDetailsBankTabDropdownOptions[index] or makeButton(self.minimumDetailsBankTabDropdownPanel, dropdownWidth - 8, 22, "")
            option.value = tabName
            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", self.minimumDetailsBankTabDropdownPanel, "TOPLEFT", 4, -4 - ((index - 1) * 24))
            option:SetWidth(dropdownWidth - 8)
            style_dropdown_button_text(option)
            option.labelText:SetText(tabName)
            option:SetScript("OnClick", function()
                self.minimumDetailsWorkingState = self.minimumDetailsWorkingState or {}
                self.minimumDetailsWorkingState.tabName = tabName
                self.minimumDetailsWorkingState.scope = "TAB"
                self.minimumDetailsBankTabValueText:SetText(tabName)
                self.minimumDetailsBankTabDropdownButton.labelText:SetText(tabName)
                self.minimumDetailsBankTabDropdownPanel:Hide()
                self:UpdateMinimumDetailsActionState(self.minimumDetailsSourceRow, self.minimumDetailsWorkingState)
            end)
            option:Show()
            self.minimumDetailsBankTabDropdownOptions[index] = option
        end

        for index = #tabOptions + 1, #(self.minimumDetailsBankTabDropdownOptions or {}) do
            self.minimumDetailsBankTabDropdownOptions[index]:Hide()
        end

        self.minimumDetailsBankTabDropdownPanel:Hide()
        self.minimumDetailsBankTabValueText:SetText(selectedTab == "Select Bank Tab" and "-" or selectedTab)
        if isLocked then
            self.minimumDetailsBankTabValueText:Show()
            self.minimumDetailsBankTabDropdownButton:Hide()
            self.minimumDetailsBankTabDropdownButton:SetEnabled(false)
            return
        end

        self.minimumDetailsBankTabValueText:Hide()
        self.minimumDetailsBankTabDropdownButton:SetEnabled(true)
        self.minimumDetailsBankTabDropdownButton:Show()
        self.minimumDetailsBankTabDropdownButton:SetScript("OnClick", function()
            if self.minimumDetailsBankTabDropdownPanel:IsShown() then
                self.minimumDetailsBankTabDropdownPanel:Hide()
            else
                self.minimumDetailsBankTabDropdownPanel:Show()
            end
        end)
    end

    function mainFrame:SyncMinimumDetailsModal(row, state)
        state = state or (row and self:GetPendingMinimumDraft(row)) or nil
        local display = build_item_display(state or row or {})
        local itemName = tostring(display.visibleText or (row and row.itemName) or (state and state.itemName) or "Unknown")
        local itemID = tonumber((row and row.itemID) or (state and state.itemID) or 0) or 0
        local tabName = (state and state.tabName and state.tabName ~= "") and state.tabName or ((row and row.needsBankTab) and "-") or (row and row.bankTab) or "-"

        self.minimumDetailsItemNameText:SetText(itemName)
        self.minimumDetailsItemIDText:SetText(tostring(itemID > 0 and itemID or ""))
        self.minimumDetailsBankTabValueText:SetText(tabName)
        self.minimumDetailsQuantityInput:SetText(tostring((state and state.quantity) or (row and row.quantityValue) or (row and row.quantity) or 0))
        self.minimumDetailsRestockToggleButton.labelText:SetText((state and state.enabled ~= false) and "Yes" or "No")
        self:ConfigureMinimumDetailsBankTabDropdown(row, state)
        self:UpdateMinimumDetailsActionState(row, state)
        self.minimumDetailsItemQualityIcon.atlas = nil
        self.minimumDetailsItemQualityIcon:Hide()
        self.minimumDetailsItemQualityText:SetText("")
        self.minimumDetailsItemQualityText:Hide()
    end

    function mainFrame:OpenMinimumDetailsModal(row, state)
        state = state or (row and self:GetPendingMinimumDraft(row)) or nil
        if not row and not state then
            return nil
        end

        self.minimumDetailsSourceRow = row
        self.minimumDetailsWorkingState = state or (row and self:BuildMinimumRuleFromRow(row)) or nil
        self:BackfillMinimumCraftedTier(self.minimumDetailsWorkingState)
        self.minimumEditorPanel:Hide()
        self.minimumDetailsConfirmButton:SetEnabled(false)
        self.minimumDetailsRemoveButton:SetEnabled(false)
        self.minimumDetailsUndoButton:SetEnabled(false)
        self:SyncMinimumDetailsModal(row, self.minimumDetailsWorkingState)
        self.minimumDetailsModal:Show()
        return self.minimumDetailsModal
    end

    function mainFrame:HideMinimumDetailsModal()
        if self.minimumDetailsBankTabDropdownPanel then
            self.minimumDetailsBankTabDropdownPanel:Hide()
        end
        self.minimumDetailsModal:Hide()
        return self.minimumDetailsModal
    end

    function mainFrame:FindMinimumBankTabValidationRow()
        local minimumsView = ns.modules.minimumsView
        local snapshot = self:GetCurrentSnapshot()
        local rows = minimumsView.BuildTableRows(self:GetMergedMinimumRules(currentDb()), snapshot, {
            showAll = true,
            search = "",
            manualOnly = false,
            columnFilters = {},
        })

        for _, row in ipairs(rows or {}) do
            if row.needsBankTab == true then
                self:BackfillMinimumCraftedTier(row, snapshot)
                return row
            end
        end

        return nil
    end

    function mainFrame:BindMinimumRuleToApprovedRequest(rule)
        local requestId = tostring((rule or {}).sourceRequestId or "")
        local bankTab = tostring((rule or {}).tabName or "")
        local itemID = tonumber((rule or {}).itemID)
        if requestId == "" or bankTab == "" or not itemID then
            return nil
        end

        local db = currentDb()
        for _, request in ipairs((db or {}).requests or {}) do
            if tostring((request or {}).requestId or "") == requestId then
                request.minimumRuleKey = table.concat({ tostring(itemID), "TAB", bankTab }, "|")
                request.tabName = bankTab
                request.approvedBankTab = bankTab
                return request
            end
        end

        return nil
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
        rowFrame.minimumDraftBackground = rowFrame.minimumDraftBackground or rowFrame:CreateTexture(nil, "ARTWORK", nil, 1)
        if type(rowFrame.minimumDraftBackground.SetAllPoints) == "function" then
            rowFrame.minimumDraftBackground:SetAllPoints(rowFrame)
        end

        if not draftState and rowFrame.rowData and rowFrame.rowData.needsBankTab == true then
            applyTableRowStyle(rowFrame, rowIndex, self:IsSelectedTableRow(rowFrame.rowData))
            rowFrame.minimumDraftState = "attention"
            rowFrame.minimumDraftTint = "orange"
            if type(rowFrame.minimumDraftBackground.SetColorTexture) == "function" then
                rowFrame.minimumDraftBackground:SetColorTexture(unpack(MINIMUM_DRAFT_ROW_COLORS.attention))
            end
            rowFrame.minimumDraftBackground.color = MINIMUM_DRAFT_ROW_COLORS.attention
            if type(rowFrame.minimumDraftBackground.Show) == "function" then
                rowFrame.minimumDraftBackground:Show()
            end
            rowFrame.isSelected = self:IsSelectedTableRow(rowFrame.rowData)
            return
        end

        if draftState and MINIMUM_DRAFT_ROW_COLORS[draftState] then
            applyTableRowStyle(rowFrame, rowIndex, self:IsSelectedTableRow(rowFrame.rowData))
            if type(rowFrame.minimumDraftBackground.SetColorTexture) == "function" then
                rowFrame.minimumDraftBackground:SetColorTexture(unpack(MINIMUM_DRAFT_ROW_COLORS[draftState]))
            end
            rowFrame.minimumDraftBackground.color = MINIMUM_DRAFT_ROW_COLORS[draftState]
            if type(rowFrame.minimumDraftBackground.Show) == "function" then
                rowFrame.minimumDraftBackground:Show()
            end
            rowFrame.isSelected = self:IsSelectedTableRow(rowFrame.rowData)
            return
        end

        rowFrame.minimumDraftTint = nil
        rowFrame.minimumDraftBackground.color = nil
        if type(rowFrame.minimumDraftBackground.Hide) == "function" then
            rowFrame.minimumDraftBackground:Hide()
        end
        applyTableRowStyle(rowFrame, rowIndex, self:IsSelectedTableRow(rowFrame.rowData))
    end

    function mainFrame:RefreshSelectedMinimumDraftStyle()
        local selectedKey = self.selectedMinimumKey
        if not selectedKey then
            return
        end

        for rowIndex, rowFrame in ipairs(self.tableRows or {}) do
            if rowFrame.rowData and rowFrame.rowData.rowKey == selectedKey then
                self:ApplyMinimumDraftStyle(rowFrame, rowIndex, self:GetMinimumDraftState(rowFrame.rowData))
                return
            end
        end
    end

    function mainFrame:UndoMinimumRow(row)
        if not row then
            return nil
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        local hasBaseline = self:GetMinimumBaselineRule(row) ~= nil
        local snapshotBacked = self:IsSnapshotBackedMinimumRow(row)

        if snapshotBacked and not hasBaseline then
            local restored = self:BuildMinimumRuleFromRow(row)
            restored.draftKey = row.rowKey
            self.minimumPendingRules[row.rowKey] = restored
        else
            self.minimumPendingRules[row.rowKey] = nil
        end
        self.minimumPendingDirty[row.rowKey] = nil
        self.minimumPendingDeleted[row.rowKey] = nil

        if self.selectedMinimumKey == row.rowKey and not hasBaseline then
            self.selectedMinimumKey = nil
        end

        self:ApplyMinimumFilters()
        return row
    end

    function mainFrame:MarkMinimumRowDeleted(row)
        if not row then
            return nil
        end

        if not self:GetMinimumBaselineRule(row) and not self:IsSnapshotBackedMinimumRow(row) then
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
            if tabName == "" or tabName == "GLOBAL" or seen[tabName] then
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
        local itemCatalog = ns.modules.itemCatalog
        if itemCatalog and type(itemCatalog.StoreResolvedItem) == "function" then
            local stored = itemCatalog.StoreResolvedItem(db, item)
            self.minimumSearchSession = nil
            self.requestSearchSession = nil
            return stored
        end

        return nil
    end

    function mainFrame:GetMinimumSearchSnapshot()
        local snapshot = self:GetCurrentSnapshot()
        local db = currentDb()
        local itemCatalog = ns.modules.itemCatalog
        snapshot.searchCatalog = itemCatalog and type(itemCatalog.BuildSearchCatalog) == "function"
            and itemCatalog.BuildSearchCatalog(db, snapshot, {
                includeBundled = false,
            })
            or {}
        return snapshot
    end

    function mainFrame:GetMinimumCatalogItemByID(itemID, snapshot)
        local numericID = tonumber(itemID)
        local itemCatalog = ns.modules.itemCatalog
        if not numericID or type(itemCatalog) ~= "table" then
            return nil
        end

        local sourceSnapshot = snapshot or self:GetCurrentSnapshot() or {}
        for _, item in pairs(sourceSnapshot.items or {}) do
            if tonumber((item or {}).itemID) == numericID then
                return item
            end
        end

        for _, item in ipairs(sourceSnapshot.searchCatalog or {}) do
            if tonumber((item or {}).itemID) == numericID then
                return item
            end
        end

        local bundledPayload = type(itemCatalog.GetBundledSearchPayload) == "function" and itemCatalog.GetBundledSearchPayload() or nil
        return type((bundledPayload or {}).itemsByID) == "table" and bundledPayload.itemsByID[numericID] or nil
    end

    function mainFrame:BackfillMinimumCraftedTier(item, snapshot)
        if type(item) ~= "table" then
            return item
        end

        local numericID = tonumber(item.itemID)
        if not numericID then
            return item
        end

        local catalogItem = self:GetMinimumCatalogItemByID(numericID, snapshot)
        local itemCatalog = ns.modules.itemCatalog
        local bundledItem = type(itemCatalog) == "table" and type(itemCatalog.GetBundledItemByID) == "function"
            and itemCatalog.GetBundledItemByID(numericID)
            or nil
        local authoritativeItem = bundledItem or catalogItem
        if not authoritativeItem then
            return item
        end

        if tonumber(authoritativeItem.craftedQuality or 0) > 0 then
            item.craftedQuality = authoritativeItem.craftedQuality
        end
        if tostring(authoritativeItem.craftedQualityIcon or "") ~= "" then
            item.craftedQualityIcon = authoritativeItem.craftedQualityIcon
        end
        if tonumber(authoritativeItem.craftedQualityMax or 0) > 0 then
            item.craftedQualityMax = authoritativeItem.craftedQualityMax
        end
        if tonumber(authoritativeItem.craftedQualityFamilySize or 0) > 0 then
            item.craftedQualityFamilySize = authoritativeItem.craftedQualityFamilySize
        end
        if tostring(authoritativeItem.craftedQualityDisplayAtlas or "") ~= "" then
            item.craftedQualityDisplayAtlas = authoritativeItem.craftedQualityDisplayAtlas
        end
        if tostring(authoritativeItem.craftedQualityPreferredAtlas or "") ~= "" then
            item.craftedQualityPreferredAtlas = authoritativeItem.craftedQualityPreferredAtlas
        end
        if tostring(authoritativeItem.itemLink or "") ~= "" then
            item.itemLink = authoritativeItem.itemLink
        end
        if tostring(authoritativeItem.itemString or "") ~= "" then
            item.itemString = authoritativeItem.itemString
        end

        return item
    end

    function mainFrame:GetMinimumSearchSession()
        local itemCatalog = ns.modules.itemCatalog
        if type(itemCatalog) ~= "table" or type(itemCatalog.CreateSearchSession) ~= "function" then
            return nil
        end

        if type(itemCatalog.EnsureBundledDataLoaded) == "function" then
            itemCatalog.EnsureBundledDataLoaded()
        end
        local bundledReady = type(itemCatalog.IsBundledDataLoaded) == "function" and itemCatalog.IsBundledDataLoaded() or false
        local sessionIndexedReady = type(itemCatalog.IsSearchSessionIndexedReady) == "function"
            and itemCatalog.IsSearchSessionIndexedReady(self.minimumSearchSession)
            or false

        if self.minimumSearchSession == nil or (bundledReady and not sessionIndexedReady) then
            self.minimumSearchSession = itemCatalog.CreateSearchSession(self:GetMinimumSearchSnapshot())
        end

        return self.minimumSearchSession
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
        self:HideMinimumInlineRow(rowFrame)
        self:ApplyMinimumDraftStyle(rowFrame, rowIndex, row and self:GetMinimumDraftState(row) or nil)
    end

    function mainFrame:HideMinimumVariantButtons()
        if self.minimumAddSearchSelector then
            self.minimumAddSearchSelector:HideMatches()
        end
    end

    function mainFrame:GetConfirmedMinimumAddItem()
        if self.minimumAddSelectedCatalogItem then
            return self.minimumAddSelectedCatalogItem
        end

        if self.minimumAddSearchSelector then
            return self.minimumAddSearchSelector.selectedItem
        end

        return nil
    end

    function mainFrame:ApplyMinimumResolvedItem(item)
        if not item then
            return nil
        end

        if self.minimumAddSearchSelector then
            self.minimumAddSearchSelector:ApplySelectedItem(item, true)
        end
        self.minimumScopeInput:SetText("TAB")
        return item
    end

    function mainFrame:ResolveMinimumAddByItemID()
        if self.minimumAddSearchSelector then
            return self.minimumAddSearchSelector:ResolveQuery(self.minimumAddItemIDInput:GetText() or "")
        end
        return nil
    end

    function mainFrame:ResolveMinimumAddByName()
        if self.minimumAddSearchSelector then
            return self.minimumAddSearchSelector:ResolveQuery(self.minimumAddItemNameInput:GetText() or "")
        end
        return nil
    end

    function mainFrame:ResetMinimumAddRow()
        self.minimumAddSelectedCatalogItem = nil
        if self.minimumAddSearchSelector then
            self.minimumAddSearchSelector.isResolving = true
            self.minimumAddItemIDInput:SetText("")
            self.minimumAddItemNameInput:SetText("")
            self.minimumAddSearchSelector.isResolving = false
            self.minimumAddSearchSelector:ClearSelection()
        else
            self.minimumAddItemIDInput:SetText("")
            self.minimumAddItemNameInput:SetText("")
        end
        self.minimumAddButton:SetEnabled(false)
        self.minimumAddBankTabInput:SetText("")
        self.minimumAddQuantityInput:SetText(tostring((self:GetMinimumSettings(currentDb()).defaultQuantity or 100)))
        self.minimumScopeInput:SetText("TAB")
        self.minimumRestockToggleButton.labelText:SetText("Restock: Yes")
        self.selectedMinimumEnabled = true
        self:HideMinimumVariantButtons()
    end

    function mainFrame:ResetMinimumImportReview()
        self.minimumImportPayloadText = ""
        self.minimumImportReviewRows = {}
        self.minimumImportParsedPayload = nil
        self.minimumImportDropdownOwner = nil
        if self.minimumImportApplyButton then
            self.minimumImportApplyButton:SetEnabled(false)
        end
        if self.minimumImportStatusText then
            self.minimumImportStatusText:SetText("")
        end
        for _, rowFrame in ipairs(self.minimumImportReviewRowsFrames or {}) do
            rowFrame:Hide()
            if rowFrame.tabDropdownPanel then
                rowFrame.tabDropdownPanel:Hide()
            end
        end
    end

    function mainFrame:UpdateMinimumImportApplyState()
        local ready = #(self.minimumImportReviewRows or {}) > 0
        for _, row in ipairs(self.minimumImportReviewRows or {}) do
            if tostring(row.status or "") == "needs_tab" or tostring(row.status or "") == "invalid" then
                ready = false
                break
            end
        end
        if self.minimumImportApplyButton then
            self.minimumImportApplyButton:SetEnabled(ready)
        end
        return ready
    end

    function mainFrame:GetMinimumImportTabOptions(row)
        return self:GetKnownMinimumBankTabs(row)
    end

    function mainFrame:RefreshMinimumImportReviewRows()
        if self.isRefreshingMinimumImportReview == true then
            return
        end
        self.isRefreshingMinimumImportReview = true
        local rowHeight = 48
        local visibleRows = #(self.minimumImportReviewRows or {})
        self.minimumImportReviewPanel:SetHeight(math.max(48, (visibleRows * rowHeight) + 8))

        for rowIndex, row in ipairs(self.minimumImportReviewRows or {}) do
            local rowFrame = self.minimumImportReviewRowsFrames[rowIndex]
            if not rowFrame then
                rowFrame = _G.CreateFrame("Frame", nil, self.minimumImportReviewPanel, "BackdropTemplate")
                applyPanelStyle(rowFrame, theme.colors.panelAlt)
                rowFrame.itemText = makeLabel(rowFrame, "", "GameFontHighlightSmall")
                rowFrame.itemText:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 8, -6)
                if type(rowFrame.itemText.SetWidth) == "function" then
                    rowFrame.itemText:SetWidth(188)
                end

                rowFrame.importedTabText = makeLabel(rowFrame, "", "GameFontHighlightSmall")
                rowFrame.importedTabText:SetPoint("TOPLEFT", rowFrame.itemText, "BOTTOMLEFT", 0, -4)
                if type(rowFrame.importedTabText.SetWidth) == "function" then
                    rowFrame.importedTabText:SetWidth(188)
                end

                rowFrame.statusText = makeLabel(rowFrame, "", "GameFontHighlightSmall")
                rowFrame.statusText:SetPoint("LEFT", rowFrame, "LEFT", 206, 10)

                rowFrame.tabButton = makeButton(rowFrame, 116, 22, "Select Bank Tab")
                rowFrame.tabButton:SetPoint("LEFT", rowFrame, "LEFT", 206, -10)
                rowFrame.tabDropdownPanel = _G.CreateFrame("Frame", nil, rowFrame, "BackdropTemplate")
                applyPanelStyle(rowFrame.tabDropdownPanel, theme.colors.panelAlt)
                rowFrame.tabDropdownOptions = {}

                rowFrame.quantityInput = makeInput(rowFrame, 48, 22)
                rowFrame.quantityInput:SetPoint("LEFT", rowFrame.tabButton, "RIGHT", 8, 0)

                rowFrame.enabledButton = makeButton(rowFrame, 68, 22, "Yes")
                rowFrame.enabledButton:SetPoint("LEFT", rowFrame.quantityInput, "RIGHT", 8, 0)

                rowFrame.removeButton = makeButton(rowFrame, 26, 22, "")
                rowFrame.removeButton:SetPoint("LEFT", rowFrame.enabledButton, "RIGHT", 8, 0)
                setButtonIcon(rowFrame.removeButton, "remove")

                self.minimumImportReviewRowsFrames[rowIndex] = rowFrame
            end

            rowFrame:ClearAllPoints()
            rowFrame:SetPoint("TOPLEFT", self.minimumImportReviewPanel, "TOPLEFT", 4, -4 - ((rowIndex - 1) * rowHeight))
            rowFrame:SetPoint("RIGHT", self.minimumImportReviewPanel, "RIGHT", -4, 0)
            rowFrame:SetHeight(rowHeight - 2)
            rowFrame:Show()

            rowFrame.itemText:SetText(build_item_display(row).visibleText)
            rowFrame.importedTabText:SetText(string.format("Imported Tab: %s", tostring(row.importedTabName or "-")))
            rowFrame.statusText:SetText(string.format("Status: %s", tostring(row.status or "invalid")))
            rowFrame.tabButton.labelText:SetText((tostring(row.resolvedTabName or "") ~= "" and tostring(row.resolvedTabName)) or "Select Bank Tab")
            rowFrame.quantityInput:SetText(tostring(tonumber(row.quantity or 0) or 0))
            rowFrame.enabledButton.labelText:SetText(row.enabled ~= false and "Yes" or "No")
            rowFrame.enabledButton.gbmButtonVariant = row.enabled ~= false and "primary" or "secondary"

            local tabOptions = self:GetMinimumImportTabOptions(row)
            local dropdownWidth = minimum_dropdown_width(tabOptions, 116, 180)
            rowFrame.tabButton:SetWidth(dropdownWidth)
            rowFrame.tabDropdownPanel:ClearAllPoints()
            rowFrame.tabDropdownPanel:SetPoint("TOPLEFT", rowFrame.tabButton, "BOTTOMLEFT", 0, -2)
            rowFrame.tabDropdownPanel:SetSize(dropdownWidth, math.max(28, (#tabOptions * 24) + 8))
            for optionIndex, tabName in ipairs(tabOptions) do
                local option = rowFrame.tabDropdownOptions[optionIndex] or makeButton(rowFrame.tabDropdownPanel, dropdownWidth - 8, 22, "")
                option.value = tabName
                option:ClearAllPoints()
                option:SetPoint("TOPLEFT", rowFrame.tabDropdownPanel, "TOPLEFT", 4, -4 - ((optionIndex - 1) * 24))
                option:SetWidth(dropdownWidth - 8)
                option.labelText:SetText(tabName)
                option:SetScript("OnClick", function()
                    self:SetImportedMinimumRowTab(rowIndex, tabName)
                    rowFrame.tabDropdownPanel:Hide()
                    self:RefreshMinimumImportReviewRows()
                end)
                option:Show()
                rowFrame.tabDropdownOptions[optionIndex] = option
            end
            for optionIndex = #tabOptions + 1, #(rowFrame.tabDropdownOptions or {}) do
                rowFrame.tabDropdownOptions[optionIndex]:Hide()
            end

            rowFrame.tabButton:SetScript("OnClick", function()
                if rowFrame.tabDropdownPanel:IsShown() then
                    rowFrame.tabDropdownPanel:Hide()
                else
                    rowFrame.tabDropdownPanel:Show()
                end
            end)
            rowFrame.quantityInput:SetScript("OnTextChanged", function(selfInput)
                if self.isRefreshingMinimumImportReview == true then
                    return
                end
                self:SetImportedMinimumRowQuantity(rowIndex, selfInput:GetText() or "")
            end)
            rowFrame.enabledButton:SetScript("OnClick", function()
                self:SetImportedMinimumRowEnabled(rowIndex, row.enabled == false)
                self:RefreshMinimumImportReviewRows()
            end)
            rowFrame.removeButton:SetScript("OnClick", function()
                self:RemoveImportedMinimumRow(rowIndex)
                self:RefreshMinimumImportReviewRows()
            end)
            rowFrame.tabDropdownPanel:Hide()
        end

        for rowIndex = visibleRows + 1, #(self.minimumImportReviewRowsFrames or {}) do
            self.minimumImportReviewRowsFrames[rowIndex]:Hide()
            if self.minimumImportReviewRowsFrames[rowIndex].tabDropdownPanel then
                self.minimumImportReviewRowsFrames[rowIndex].tabDropdownPanel:Hide()
            end
        end
        self.isRefreshingMinimumImportReview = false
    end

    function mainFrame:PreviewImportedMinimums(payloadText)
        self.minimumImportPayloadText = tostring(payloadText or "")
        local parsed = type(minimumsPortability.Parse) == "function"
            and minimumsPortability.Parse(self.minimumImportPayloadText, self:GetKnownMinimumBankTabs())
            or { ok = false, error = "minimum import parsing is unavailable", rows = {} }
        self.minimumImportParsedPayload = parsed
        self.minimumImportReviewRows = {}

        if not parsed.ok then
            if self.minimumImportStatusText then
                self.minimumImportStatusText:SetText(tostring(parsed.error or "Unable to parse imported Minimums payload."))
            end
            self:RefreshMinimumImportReviewRows()
            self:UpdateMinimumImportApplyState()
            return parsed
        end

        for index, row in ipairs(parsed.rows or {}) do
            local cloned = {}
            for key, value in pairs(row or {}) do
                cloned[key] = value
            end
            cloned.reviewRowIndex = index
            self.minimumImportReviewRows[index] = cloned
        end

        if self.minimumImportStatusText then
            self.minimumImportStatusText:SetText(string.format("Previewing %d imported Minimum row(s).", #(self.minimumImportReviewRows or {})))
        end
        self:RefreshMinimumImportReviewRows()
        self:UpdateMinimumImportApplyState()
        return parsed
    end

    function mainFrame:SetImportedMinimumRowTab(rowIndex, tabName)
        local row = (self.minimumImportReviewRows or {})[rowIndex]
        if not row then
            return nil
        end
        row.resolvedTabName = tostring(tabName or "")
        if row.scope == "TAB" then
            row.status = row.resolvedTabName ~= "" and "ready" or "needs_tab"
        end
        self:RefreshMinimumImportReviewRows()
        self:UpdateMinimumImportApplyState()
        return row
    end

    function mainFrame:SetImportedMinimumRowQuantity(rowIndex, quantity)
        local row = (self.minimumImportReviewRows or {})[rowIndex]
        if not row then
            return nil
        end
        row.quantity = parseNumber(tostring(quantity or "")) or tonumber(quantity)
        if row.quantity == nil then
            row.status = "invalid"
        elseif row.scope ~= "TAB" or tostring(row.resolvedTabName or "") ~= "" then
            row.status = "ready"
        end
        self:RefreshMinimumImportReviewRows()
        self:UpdateMinimumImportApplyState()
        return row
    end

    function mainFrame:SetImportedMinimumRowEnabled(rowIndex, enabled)
        local row = (self.minimumImportReviewRows or {})[rowIndex]
        if not row then
            return nil
        end
        row.enabled = enabled == true
        self:RefreshMinimumImportReviewRows()
        self:UpdateMinimumImportApplyState()
        return row
    end

    function mainFrame:RemoveImportedMinimumRow(rowIndex)
        if type(self.minimumImportReviewRows) ~= "table" then
            return false
        end
        table.remove(self.minimumImportReviewRows, rowIndex)
        self:RefreshMinimumImportReviewRows()
        self:UpdateMinimumImportApplyState()
        return true
    end

    function mainFrame:BuildMinimumDraftFromImportedRow(row)
        row = type(row) == "table" and row or {}
        local itemID = tonumber(row.itemID)
        local itemName = tostring(row.itemName or "")
        local scope = tostring(row.scope or "TAB")
        local tabName = scope == "TAB" and tostring(row.resolvedTabName or "") or tostring(row.importedTabName or "")
        local quantity = tonumber(row.quantity)
        if not itemID or itemName == "" or quantity == nil or (scope == "TAB" and tabName == "") then
            return nil
        end

        return {
            itemID = itemID,
            itemName = itemName,
            itemLink = row.itemLink,
            itemString = row.itemString,
            quantity = quantity,
            scope = scope,
            tabName = tabName,
            enabled = row.enabled ~= false,
            craftedQuality = row.craftedQuality,
            craftedQualityIcon = row.craftedQualityIcon,
            craftedQualityDisplayAtlas = row.craftedQualityDisplayAtlas,
            craftedQualityPreferredAtlas = row.craftedQualityPreferredAtlas,
            craftedQualityMax = row.craftedQualityMax,
            isNewlyAdded = true,
            draftKey = table.concat({ "import", tostring(itemID), scope, tabName, tostring(row.reviewRowIndex or 0) }, "|"),
            originalItemID = itemID,
            originalScope = scope,
            originalTabName = tabName,
        }
    end

    function mainFrame:BuildPortableMinimumsExportPayload()
        local db = currentDb()
        if type(minimumsPortability.Export) ~= "function" then
            return ""
        end
        local exportMinimums = {}
        for _, rule in ipairs(db.minimums or {}) do
            exportMinimums[#exportMinimums + 1] = self:CloneMinimumRule(rule)
        end
        return minimumsPortability.Export({
            guildName = active_guild_key(db),
            exportedAt = _G.time and _G.time() or 0,
            minimums = exportMinimums,
        })
    end

    function mainFrame:RefreshMinimumExportScrollMetrics()
        local scrollFrame = self.minimumExportScrollFrame
        local scrollChild = self.minimumExportScrollChild
        local outputInput = self.minimumExportOutput
        if not scrollFrame or not scrollChild or not outputInput then
            return
        end

        local lineHeight = 14
        local padding = 16
        local minimumInputHeight = 130
        local lineCount = count_lines(outputInput:GetText() or "")
        local contentHeight = math.max(minimumInputHeight, (lineCount * lineHeight) + 12)
        local childHeight = math.max(scrollFrame:GetHeight(), contentHeight + padding)

        if type(scrollChild.SetWidth) == "function" then
            scrollChild:SetWidth(math.max(0, scrollFrame:GetWidth() - 12))
        end
        scrollChild:SetHeight(childHeight)
        scrollFrame.verticalScrollRange = math.max(0, childHeight - scrollFrame:GetHeight())
        scrollFrame:SetVerticalScroll(scrollFrame.verticalScroll or 0)
    end

    function mainFrame:ApplyReviewedImportedMinimums()
        if not self:UpdateMinimumImportApplyState() then
            return false
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        for _, row in ipairs(self.minimumImportReviewRows or {}) do
            local draftRule = self:BuildMinimumDraftFromImportedRow(row)
            if draftRule then
                self.minimumPendingRules[draftRule.draftKey] = draftRule
                self.minimumPendingDirty[draftRule.draftKey] = true
                self.minimumPendingDeleted[draftRule.draftKey] = nil
            end
        end

        self.selectedMinimumKey = nil
        self.minimumImportModal:Hide()
        self:ResetMinimumImportReview()
        self:ApplyMinimumFilters()
        return true
    end

    function mainFrame:OpenMinimumExportModal()
        if self.minimumExportOutput then
            self.minimumExportOutput:SetText(pretty_print_json(self:BuildPortableMinimumsExportPayload()))
        end
        if self.minimumExportStatusText then
            self.minimumExportStatusText:SetText("Select all or copy the portable Minimums payload for later import.")
        end
        self:RefreshMinimumExportScrollMetrics()
        self.minimumExportModal:Show()
        return self.minimumExportModal
    end

    function mainFrame:OpenMinimumAddModal()
        self.minimumSearchSession = nil
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

    function mainFrame:BeginMinimumDraftFromSelectedItem()
        local item = self:GetConfirmedMinimumAddItem()
        if not item then
            return nil
        end

        local itemID = tonumber(item.itemID)
        local itemName = tostring(item.name or item.itemName or "")
        local quantity = parseNumber(self.minimumAddQuantityInput:GetText() or "")
        if not itemID or itemName == "" then
            return nil
        end

        local workingState = {
            itemID = itemID,
            itemName = itemName,
            itemLink = item.itemLink,
            itemString = item.itemString,
            quantity = quantity or self:GetMinimumSettings(currentDb()).defaultQuantity or 100,
            scope = "TAB",
            tabName = nil,
            enabled = true,
            craftedQuality = item.craftedQuality,
            craftedQualityIcon = item.craftedQualityIcon,
            craftedQualityMax = item.craftedQualityMax,
            isNewlyAdded = true,
        }

        self.minimumDetailsSourceRow = nil
        self.minimumDetailsWorkingState = nil
        self.selectedMinimumKey = nil
        self:RememberMinimumSearchItem(item)
        self:HideMinimumAddModal()
        return self:OpenMinimumDetailsModal(nil, workingState)
    end

    function mainFrame:StageMinimumDraftFromState(state)
        if not state then
            return nil
        end

        local sourceRow = self.minimumDetailsSourceRow
        local itemID = tonumber(state.itemID)
        local itemName = tostring(state.itemName or "")
        local quantity = parseNumber(self.minimumDetailsQuantityInput:GetText() or "")
        local tabName = tostring(state.tabName or "")
        local scope = tostring(state.scope or "TAB")

        if not itemID or itemName == "" or quantity == nil or (scope == "TAB" and tabName == "") then
            self:UpdateMinimumDetailsActionState(sourceRow, state)
            return nil
        end

        local draftKey = state.draftKey or (sourceRow and sourceRow.rowKey)
        if not draftKey then
            draftKey = table.concat({ "draft", tostring(itemID), tostring(_G.time()), tostring(math.random(1000, 9999)) }, "|")
        end

        local staged = self:CloneMinimumRule(state)
        staged.itemID = itemID
        staged.itemName = itemName
        staged.quantity = quantity
        staged.scope = scope
        staged.tabName = tabName
        staged.enabled = state.enabled ~= false
        staged.draftKey = draftKey

        if sourceRow then
            staged.originalItemID = sourceRow.originalItemID or state.originalItemID or tonumber(sourceRow.itemID)
            staged.originalScope = sourceRow.originalScope or state.originalScope or sourceRow.scope or scope
            staged.originalTabName = sourceRow.originalTabName or state.originalTabName or sourceRow.tabKey or sourceRow.tabName
            staged.isNewlyAdded = self:GetMinimumBaselineRule(sourceRow) == nil
        else
            staged.originalItemID = state.originalItemID or itemID
            staged.originalScope = state.originalScope or scope
            staged.originalTabName = state.originalTabName
            staged.isNewlyAdded = true
        end

        self.minimumPendingRules = self.minimumPendingRules or {}
        self.minimumPendingDirty = self.minimumPendingDirty or {}
        self.minimumPendingDeleted = self.minimumPendingDeleted or {}
        self.minimumPendingRules[draftKey] = staged
        self.minimumPendingDirty[draftKey] = true
        self.minimumPendingDeleted[draftKey] = nil
        self.selectedMinimumKey = draftKey
        self.minimumDetailsWorkingState = staged
        return staged
    end

    function mainFrame:ConfirmMinimumDetailsModal()
        local sourceRow = self.minimumDetailsSourceRow
        if sourceRow and self:GetMinimumDraftState(sourceRow) == "deleted" then
            return nil
        end

        local staged = self:StageMinimumDraftFromState(self.minimumDetailsWorkingState)
        if not staged then
            return nil
        end

        self:HideMinimumDetailsModal()
        self:ApplyMinimumFilters()
        return staged
    end

    function mainFrame:RemoveMinimumDetailsDraft()
        local row = self.minimumDetailsSourceRow
        if not row then
            return nil
        end

        local currentRow = self:GetMinimumRowByKey(row.rowKey) or row
        local removed = self:MarkMinimumRowDeleted(currentRow)
        self:HideMinimumDetailsModal()
        return removed
    end

    function mainFrame:UndoMinimumDetailsDraft()
        local row = self.minimumDetailsSourceRow
        if not row then
            return nil
        end

        local currentRow = self:GetMinimumRowByKey(row.rowKey) or row
        local restored = self:UndoMinimumRow(currentRow)
        self:HideMinimumDetailsModal()
        return restored
    end

    function mainFrame:CreateMinimumFromAddRow()
        local selectedItem = self:GetConfirmedMinimumAddItem()
        local itemID = tonumber((selectedItem or {}).itemID)
        local quantity = parseNumber(self.minimumAddQuantityInput:GetText() or "")
        local itemName = tostring((selectedItem or {}).name or (selectedItem or {}).itemName or "")

        if not selectedItem or not itemID or itemName == "" or not quantity then
            return nil
        end

        local draftKey = table.concat({ "draft", tostring(itemID), tostring(_G.time()), tostring(math.random(1000, 9999)) }, "|")
        local rule = {
            itemID = itemID,
            itemName = itemName,
            itemLink = selectedItem.itemLink,
            itemString = selectedItem.itemString,
            quantity = quantity,
            scope = "TAB",
            tabName = nil,
            enabled = self.selectedMinimumEnabled ~= false,
            craftedQuality = selectedItem.craftedQuality,
            craftedQualityIcon = selectedItem.craftedQualityIcon,
            craftedQualityMax = selectedItem.craftedQualityMax,
            isNewlyAdded = true,
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
        self.selectedMinimumKey = nil
        self:HideMinimumAddModal()
        self:ApplyMinimumFilters()
        return rule
    end

    function mainFrame:SaveAllMinimumChanges()
        local minimumsView = ns.modules.minimumsView
        local db = currentDb()
        local changed = false
        local invalidRow = self:FindMinimumBankTabValidationRow()

        if invalidRow then
            self.selectedMinimumKey = invalidRow.rowKey
            self:ApplyMinimumFilters()
            invalidRow = self:GetMinimumRowByKey(invalidRow.rowKey) or invalidRow
            self:OpenMinimumDetailsModal(invalidRow)
            self.minimumDetailsStatusText:SetText("Bank Tab must be set on Orange Rows.")
            if type(self.minimumDetailsStatusText.SetTextColor) == "function" then
                self.minimumDetailsStatusText:SetTextColor(1, 0.35, 0.35, 1)
            end
            return false
        end

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
                normalized.isNewlyAdded = nil
                local scope = tostring(normalized.scope or "TAB")
                local hasRequiredTabName = scope ~= "TAB" or tostring(normalized.tabName or "") ~= ""
                if tonumber(normalized.itemID) and tostring(normalized.itemName or "") ~= "" and hasRequiredTabName then
                    minimumsView.UpsertWithAudit(db, normalized, {
                        actor = type(_G.UnitName) == "function" and _G.UnitName("player") or "Unknown",
                        timestamp = _G.time(),
                    })
                    self:BindMinimumRuleToApprovedRequest(normalized)
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

            local canPublish, actorContext = actor_can_manage_minimums(db)
            if canPublish and type(transport.Send) == "function" then
                local minimumSnapshot = {}
                for _, rule in ipairs(db.minimums or {}) do
                    minimumSnapshot[#minimumSnapshot + 1] = self:CloneMinimumRule(rule)
                end
                transport.Send("GUILD", "GUILD", {
                    type = "MINIMUMS_SNAPSHOT",
                    updatedAt = _G.time and _G.time() or 0,
                    payload = {
                        guildKey = active_guild_key(db),
                        actorContext = actorContext,
                        minimums = minimumSnapshot,
                    },
                })
            end
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

    local function set_filter_button_visual(button, active)
        if not button then
            return
        end

        button.filterActive = active == true
        applyPanelStyle(button, button.filterActive and theme.colors.accent or theme.colors.panel)
        if type(button.SetBackdropBorderColor) == "function" then
            if button.filterActive then
                button:SetBackdropBorderColor(unpack(theme.colors.accentStrong))
            else
                button:SetBackdropBorderColor(unpack(theme.colors.border))
            end
        end
        if button.labelText and type(button.labelText.SetTextColor) == "function" then
            button.labelText:SetTextColor(unpack(theme.colors.accentStrong))
        end
    end

    function mainFrame:RefreshMinimumFilterButtons()
        set_filter_button_visual(self.minimumShowAllButton, self.minimumShowAllRows == true)
        set_filter_button_visual(self.minimumEnabledOnlyButton, self.minimumShowAllRows ~= true)
    end

    function mainFrame:SetMinimumShowAllRows(showAll)
        self.minimumShowAllRows = showAll == true
        self:RefreshMinimumFilterButtons()
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

        for _, value in pairs(self:GetSharedFilterState() or {}) do
            if tostring(value or "") ~= "" then
                return "No minimum rows match the current search and filters."
            end
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

    mainFrame.minimumEnabledOnlyButton:SetScript("OnClick", function()
        mainFrame:SetMinimumShowAllRows(false)
    end)

    mainFrame.minimumShowAllButton:SetScript("OnClick", function()
        mainFrame:SetMinimumShowAllRows(true)
    end)

    mainFrame.minimumManualOnlyToggleButton:SetScript("OnClick", function()
        mainFrame:ToggleMinimumManualOnlyRows()
    end)

    mainFrame.minimumSaveButton:SetScript("OnClick", function()
        mainFrame:SaveAllMinimumChanges()
    end)

    mainFrame:RefreshMinimumFilterButtons()

    mainFrame.minimumSaveAllButton:SetScript("OnClick", function()
        mainFrame:UndoMinimumChanges()
    end)

    mainFrame.minimumAddButton:SetScript("OnClick", function()
        mainFrame:BeginMinimumDraftFromSelectedItem()
    end)

    mainFrame.minimumAddCancelButton:SetScript("OnClick", function()
        mainFrame:HideMinimumAddModal()
    end)

    mainFrame.minimumImportButton:SetScript("OnClick", function()
        mainFrame.minimumImportModal:Show()
    end)

    mainFrame.minimumExportButton:SetScript("OnClick", function()
        return mainFrame:OpenMinimumExportModal()
    end)

    mainFrame.minimumImportCancelButton:SetScript("OnClick", function()
        mainFrame.minimumImportModal:Hide()
        mainFrame:ResetMinimumImportReview()
    end)

    mainFrame.minimumImportPreviewButton:SetScript("OnClick", function()
        return mainFrame:PreviewImportedMinimums((mainFrame.minimumImportInput and mainFrame.minimumImportInput:GetText()) or "")
    end)

    mainFrame.minimumImportApplyButton:SetScript("OnClick", function()
        return mainFrame:ApplyReviewedImportedMinimums()
    end)

    mainFrame.minimumExportOutput.EditBox:SetScript("OnTextChanged", function()
        mainFrame:RefreshMinimumExportScrollMetrics()
    end)

    mainFrame.minimumExportScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll((self.verticalScroll or 0) - ((delta or 0) * 24))
    end)

    mainFrame.minimumExportSelectAllButton:SetScript("OnClick", function()
        if type(mainFrame.minimumExportOutput.SetFocus) == "function" then
            mainFrame.minimumExportOutput:SetFocus()
        end
        if type(mainFrame.minimumExportOutput.SetCursorPosition) == "function" then
            mainFrame.minimumExportOutput:SetCursorPosition(0)
        end
        mainFrame.minimumExportOutput:HighlightText(0, -1)
        mainFrame.minimumExportStatusText:SetText("Selected all output. Press Ctrl+C to copy.")
    end)

    mainFrame.minimumExportCloseButton:SetScript("OnClick", function()
        mainFrame.minimumExportModal:Hide()
    end)

    mainFrame.minimumDetailsCancelButton:SetScript("OnClick", function()
        mainFrame:HideMinimumDetailsModal()
    end)

    mainFrame.minimumDetailsRestockToggleButton:SetScript("OnClick", function()
        mainFrame.minimumDetailsWorkingState = mainFrame.minimumDetailsWorkingState or {}
        mainFrame.minimumDetailsWorkingState.enabled = mainFrame.minimumDetailsWorkingState.enabled == false
        mainFrame.minimumDetailsRestockToggleButton.labelText:SetText(mainFrame.minimumDetailsWorkingState.enabled ~= false and "Yes" or "No")
        mainFrame:UpdateMinimumDetailsActionState(mainFrame.minimumDetailsSourceRow, mainFrame.minimumDetailsWorkingState)
        return mainFrame.minimumDetailsWorkingState.enabled
    end)

    mainFrame.minimumDetailsQuantityInput:SetScript("OnTextChanged", function(self)
        if mainFrame.minimumDetailsWorkingState then
            mainFrame.minimumDetailsWorkingState.quantity = parseNumber(self:GetText() or "")
        end
        mainFrame:UpdateMinimumDetailsActionState(mainFrame.minimumDetailsSourceRow, mainFrame.minimumDetailsWorkingState)
    end)

    mainFrame.minimumDetailsConfirmButton:SetScript("OnClick", function()
        return mainFrame:ConfirmMinimumDetailsModal()
    end)

    mainFrame.minimumDetailsRemoveButton:SetScript("OnClick", function()
        return mainFrame:RemoveMinimumDetailsDraft()
    end)

    mainFrame.minimumDetailsUndoButton:SetScript("OnClick", function()
        return mainFrame:UndoMinimumDetailsDraft()
    end)

    mainFrame.minimumSearchInput:SetScript("OnTextChanged", function()
        if mainFrame.activeView == "MINIMUMS" then
            mainFrame:ApplyMinimumFilters()
        end
    end)

    return mainFrame
end

ns.modules.mainMinimumsController = mainMinimumsController

return mainMinimumsController
