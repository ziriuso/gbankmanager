local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local mainTableController = ns.modules.mainTableController or {}

function mainTableController.Attach(mainFrame, options)
    options = options or {}
    local applyPanelStyle = options.applyPanelStyle
    local makeLabel = options.makeLabel
    local makeButton = options.makeButton
    local makeInput = options.makeInput
    local createTableOverflowViewport = options.createTableOverflowViewport
    local attachScrollBehavior = options.attachScrollBehavior
    local theme = options.theme or {}
    local labelWithSortMarker = options.labelWithSortMarker
    local applyTableRowStyle = options.applyTableRowStyle
    local usesInlineFilters = options.usesInlineFilters
    local getActiveSortState = options.getActiveSortState
    local isSelectedTableRow = options.isSelectedTableRow
    local handleTableRowClick = options.handleTableRowClick
    local syncMinimumInlineRow = options.syncMinimumInlineRow
    local hideMinimumInlineRow = options.hideMinimumInlineRow

    mainFrame.tableHeaderFrame = mainFrame.tableHeaderFrame or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.tableHeaderFrame:SetPoint("TOPLEFT", mainFrame.viewSubtitle, "BOTTOMLEFT", 0, -24)
    mainFrame.tableHeaderFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableHeaderHeight)
    applyPanelStyle(mainFrame.tableHeaderFrame, theme.colors.panel)
    mainFrame.tableHeaderFrame:Hide()

    mainFrame.tableHeaderLabels = mainFrame.tableHeaderLabels or {}
    for index = 1, 9 do
        local label = mainFrame.tableHeaderLabels[index] or makeLabel(mainFrame.tableHeaderFrame, "", "GameFontHighlight")
        mainFrame.tableHeaderLabels[index] = label
    end
    mainFrame.tableHeaderButtons = mainFrame.tableHeaderButtons or {}

    mainFrame.tableFilterFrame = mainFrame.tableFilterFrame or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.tableFilterFrame:SetPoint("TOPLEFT", mainFrame.tableHeaderFrame, "BOTTOMLEFT", 0, -4)
    mainFrame.tableFilterFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableFilterHeight)
    applyPanelStyle(mainFrame.tableFilterFrame, theme.colors.background)
    mainFrame.tableFilterFrame:Hide()

    mainFrame.tableFilterInputs = mainFrame.tableFilterInputs or {}
    for index = 1, 9 do
        local input = mainFrame.tableFilterInputs[index] or makeInput(mainFrame.tableFilterFrame, 80, 22)
        mainFrame.tableFilterInputs[index] = input
    end

    local tableOverflow = createTableOverflowViewport and createTableOverflowViewport(mainFrame.content, {
        viewportFrame = mainFrame.tableViewportFrame,
        scrollFrame = mainFrame.tableScrollFrame,
        scrollChild = mainFrame.tableScrollChild,
        scrollBar = mainFrame.tableScrollBar,
        viewportParent = mainFrame.content,
        scrollBarParent = mainFrame.content,
        viewportInsetRight = 28,
        scrollBarRightInset = 4,
        controllerOptions = {
            wheelStep = mainFrame.tableRowHeight or 24,
            normalizeOffset = function(_, offset)
                local rowHeight = math.max(1, mainFrame.tableRowHeight or 24)
                return math.floor((offset / rowHeight) + 0.5) * rowHeight
            end,
            onOffsetChanged = function(_, offset)
                if mainFrame.tableSyncingScroll then
                    return
                end

                local rowHeight = math.max(1, mainFrame.tableRowHeight or 24)
                local nextOffset = math.floor((offset / rowHeight) + 0.5)
                if nextOffset ~= (mainFrame.tableScrollOffset or 0) then
                    mainFrame.tableScrollOffset = nextOffset
                    if type(mainFrame.RefreshVisibleTableRows) == "function" then
                        mainFrame:RefreshVisibleTableRows(true)
                    end
                end
            end,
        },
    }) or nil

    mainFrame.tableViewportFrame = tableOverflow and tableOverflow.viewportFrame or mainFrame.tableViewportFrame
    mainFrame.tableScrollFrame = tableOverflow and tableOverflow.scrollFrame or mainFrame.tableScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.content)
    mainFrame.tableScrollChild = tableOverflow and tableOverflow.scrollChild or mainFrame.tableScrollChild or _G.CreateFrame("Frame", nil, mainFrame.tableScrollFrame, "BackdropTemplate")
    mainFrame.tableScrollBar = tableOverflow and tableOverflow.scrollBar or mainFrame.tableScrollBar
    mainFrame.tableScrollController = tableOverflow and tableOverflow.controller or mainFrame.tableScrollController
    mainFrame.tableViewportFrame:Hide()
    mainFrame.tableScrollFrame:Hide()
    applyPanelStyle(mainFrame.tableViewportFrame, theme.colors.background)
    applyPanelStyle(mainFrame.tableScrollFrame, theme.colors.background)
    mainFrame.tableScrollOffset = mainFrame.tableScrollOffset or 0
    mainFrame.tableRowsData = mainFrame.tableRowsData or {}
    mainFrame.tableColumnLayout = mainFrame.tableColumnLayout or {}
    mainFrame.tableColumnResizeHandles = mainFrame.tableColumnResizeHandles or {}
    mainFrame.cachedInventoryRows = mainFrame.cachedInventoryRows or {}
    mainFrame.inventorySortState = mainFrame.inventorySortState or {
        key = nil,
        direction = "asc",
    }
    mainFrame.minimumSortState = mainFrame.minimumSortState or {
        key = nil,
        direction = "asc",
    }

    mainFrame.tableScrollBar:Hide()

    mainFrame.tableRows = mainFrame.tableRows or {}
    for rowIndex = 1, mainFrame.tableVisibleCount do
        local row = mainFrame.tableRows[rowIndex] or _G.CreateFrame("Button", nil, mainFrame.tableScrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", mainFrame.tableScrollChild, "TOPLEFT", 0, -((rowIndex - 1) * mainFrame.tableRowHeight))
        row:SetSize(mainFrame.tableViewportWidth, mainFrame.tableRowHeight - 2)
        row:EnableMouse(true)
        applyPanelStyle(row, rowIndex % 2 == 1 and theme.colors.panel or theme.colors.panelAlt)
        row:Hide()
        row.columns = row.columns or {}

        for columnIndex = 1, 9 do
            local column = row.columns[columnIndex] or makeLabel(row, "", "GameFontNormal")
            row.columns[columnIndex] = column
        end

        mainFrame.tableRows[rowIndex] = row
    end

    function mainFrame:UsesInlineTableFilters()
        return usesInlineFilters(self)
    end

    function mainFrame:ConfigureTable(columns, rows)
        self.isConfiguringTable = true
        self.tableColumnLayout = columns or {}
        self.tableColumnKeys = {}
        local offset = 4
        local activeSortState = getActiveSortState(self)

        for index = 1, #self.tableHeaderLabels do
            local label = self.tableHeaderLabels[index]
            local columnLayout = self.tableColumnLayout[index] or {}
            local width = columnLayout.key and (columnLayout.width or 120) or 0
            self.tableColumnKeys[index] = columnLayout.key

            local headerButton = self.tableHeaderButtons[index] or _G.CreateFrame("Button", nil, self.tableHeaderFrame, "BackdropTemplate")
            headerButton:ClearAllPoints()
            headerButton:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset, 0)
            headerButton:SetSize(width, self.tableHeaderHeight)
            headerButton:SetScript("OnClick", function()
                mainFrame:HandleHeaderClick(index)
            end)
            if width == 0 then
                headerButton:Hide()
            else
                headerButton:Show()
            end
            self.tableHeaderButtons[index] = headerButton

            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset + 6, -8)
            label:SetWidth(width)
            label:SetText(labelWithSortMarker(columnLayout, activeSortState))
            if type(label.SetJustifyH) == "function" then
                label:SetJustifyH(columnLayout.justifyH or "LEFT")
            end

            local input = self.tableFilterInputs[index]
            input:ClearAllPoints()
            input:SetPoint("TOPLEFT", self.tableFilterFrame, "TOPLEFT", offset, -3)
            input:SetWidth(width)
            if not self:UsesInlineTableFilters() or columnLayout.filterMode == "none" or width == 0 then
                input:SetText("")
                input:Hide()
            else
                input:Show()
            end

            for _, rowFrame in ipairs(self.tableRows) do
                local column = rowFrame.columns[index]
                column:ClearAllPoints()
                column:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", offset + 6, -4)
                column:SetWidth(width)
                if type(column.SetJustifyH) == "function" then
                    column:SetJustifyH(columnLayout.justifyH or "LEFT")
                end
            end

            if index < #self.tableHeaderLabels and width > 0 then
                local handle = self.tableColumnResizeHandles[index] or _G.CreateFrame("Button", nil, self.tableHeaderFrame, "BackdropTemplate")
                handle:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPLEFT", offset + width - 2, 4)
                handle:SetSize(4, self.tableHeaderHeight - 8)
                if type(handle.SetBackdrop) == "function" then
                    handle:SetBackdrop(nil)
                end
                handle:SetScript("OnClick", function()
                    mainFrame:ResizeInventoryColumn(index, 24)
                end)
                self.tableColumnResizeHandles[index] = handle
                handle:Show()
            elseif self.tableColumnResizeHandles[index] then
                self.tableColumnResizeHandles[index]:Hide()
            end

            offset = offset + width
        end

        self.tableRowsData = rows or {}
        self.tableViewportInnerWidth = self.tableViewportWidth
        self.tableScrollChild:SetSize(self.tableViewportInnerWidth, math.max(self.tableViewportHeight, (#self.tableRowsData * self.tableRowHeight)))
        self.isConfiguringTable = false
        if self.tableScrollController then
            self.tableSyncingScroll = true
            self.tableScrollController:Refresh(#self.tableRowsData * self.tableRowHeight, self.tableViewportHeight)
            self.tableSyncingScroll = false
        end
    end

    function mainFrame:RefreshVisibleTableRows(fromScrollController)
        local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
        self.tableScrollOffset = math.max(0, math.min(self.tableScrollOffset or 0, maxOffset))
        local pixelOffset = self.tableScrollOffset * self.tableRowHeight

        if self.tableScrollController and not fromScrollController then
            self.tableSyncingScroll = true
            self.tableScrollController:SetOffset(pixelOffset, #self.tableRowsData * self.tableRowHeight, self.tableViewportHeight)
            self.tableSyncingScroll = false
        elseif self.tableScrollFrame then
            self.tableScrollFrame.verticalScroll = pixelOffset
            self.tableScrollFrame.verticalScrollRange = math.max(0, (#self.tableRowsData * self.tableRowHeight) - self.tableViewportHeight)
            self.tableScrollFrame:SetVerticalScroll(pixelOffset)
        end

        for rowIndex, rowFrame in ipairs(self.tableRows) do
            local dataIndex = rowIndex + self.tableScrollOffset
            local row = self.tableRowsData[dataIndex]
            for colIndex = 1, #self.tableHeaderLabels do
                local key = self.tableColumnKeys[colIndex]
                rowFrame.columns[colIndex]:SetText(row and key and (row[key] or "") or "")
            end

            rowFrame.rowData = row
            if row then
                rowFrame:ClearAllPoints()
                rowFrame:SetPoint("TOPLEFT", self.tableScrollChild, "TOPLEFT", 0, -((dataIndex - 1) * self.tableRowHeight))
                rowFrame:Show()
                applyTableRowStyle(rowFrame, rowIndex, isSelectedTableRow(self, row))
                rowFrame:SetScript("OnClick", function(frame)
                    handleTableRowClick(self, frame.rowData)
                end)
            else
                rowFrame:Hide()
            end

            if self.activeView == "MINIMUMS" then
                syncMinimumInlineRow(self, rowFrame, row, rowIndex)
            elseif type(hideMinimumInlineRow) == "function" then
                hideMinimumInlineRow(self, rowFrame)
            end
        end
    end

    function mainFrame:ScrollTableRows(delta)
        self.tableScrollOffset = (self.tableScrollOffset or 0) + (delta or 0)
        self:RefreshVisibleTableRows()
        return self.tableScrollOffset
    end

    function mainFrame:SetTableScrollOffset(offset)
        local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
        self.tableScrollOffset = math.max(0, math.min(offset or 0, maxOffset))
        self:RefreshVisibleTableRows()
        return self.tableScrollOffset
    end

    function mainFrame:GetSharedFilterState()
        local filters = {}

        for index, label in ipairs(self.tableHeaderLabels or {}) do
            local input = self.tableFilterInputs[index]
            local key = self.tableColumnKeys and self.tableColumnKeys[index]
            if key and input and label and label:GetText() ~= "" then
                filters[key] = input:GetText() or ""
            end
        end

        return filters
    end

    function mainFrame:ClearTableFilters()
        for _, input in ipairs(self.tableFilterInputs or {}) do
            input:SetText("")
        end
    end

    function mainFrame:UpdateSharedTableLayout()
        local anchor = self.viewSubtitle
        local offsetY = -24
        local viewportHeight = self.defaultTableViewportHeight

        if self.activeView == "REQUESTS" then
            anchor = self.requestCreatePanel
            offsetY = -16
            viewportHeight = 220
        elseif self.activeView == "MINIMUMS" then
            anchor = self.viewSubtitle
            offsetY = -24
            viewportHeight = 320
        elseif self.activeView == "EXPORTS" then
            anchor = self.exportsPanel
            offsetY = -16
            viewportHeight = 224
        elseif self.activeView == "OPTIONS" then
            anchor = self.optionsPanel
            offsetY = -16
            viewportHeight = 0
        end

        self.tableViewportHeight = viewportHeight
        self.tableVisibleCount = math.max(1, math.floor(math.max(0, viewportHeight) / self.tableRowHeight))

        self.tableHeaderFrame:ClearAllPoints()
        self.tableHeaderFrame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)

        self.tableFilterFrame:ClearAllPoints()
        self.tableFilterFrame:SetPoint("TOPLEFT", self.tableHeaderFrame, "BOTTOMLEFT", 0, -4)

        self.tableViewportFrame:ClearAllPoints()
        if self:UsesInlineTableFilters() then
            self.tableViewportFrame:SetPoint("TOPLEFT", self.tableFilterFrame, "BOTTOMLEFT", 0, -4)
        else
            self.tableViewportFrame:SetPoint("TOPLEFT", self.tableHeaderFrame, "BOTTOMLEFT", 0, -4)
        end
        self.tableViewportFrame:SetSize(self.tableViewportWidth, self.tableViewportHeight)

        self.tableScrollFrame:ClearAllPoints()
        self.tableScrollFrame:SetPoint("TOPLEFT", self.tableViewportFrame, "TOPLEFT", 0, 0)
        self.tableScrollFrame:SetPoint("BOTTOMRIGHT", self.tableViewportFrame, "BOTTOMRIGHT", 0, 0)
        self.tableScrollFrame:SetSize(self.tableViewportWidth, self.tableViewportHeight)

        self.tableScrollBar:ClearAllPoints()
        self.tableScrollBar:SetPoint("TOPRIGHT", self.tableViewportFrame, "TOPRIGHT", 18, 0)
        self.tableScrollBar:SetPoint("BOTTOMRIGHT", self.tableViewportFrame, "BOTTOMRIGHT", 18, 0)

        self.minimumEmptyStateText:ClearAllPoints()
        self.minimumEmptyStateText:SetPoint("TOPLEFT", self.tableViewportFrame, "TOPLEFT", 12, -12)

        if self.activeView == "MINIMUMS" then
            self.minimumsPanel:ClearAllPoints()
            self.minimumsPanel:SetPoint("TOPLEFT", self.tableViewportFrame, "BOTTOMLEFT", 0, -16)
            self.minimumsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
        else
            self.minimumsPanel:ClearAllPoints()
            self.minimumsPanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
            self.minimumsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
        end
        if self.tableScrollController then
            self.tableSyncingScroll = true
            self.tableScrollController:Refresh(#self.tableRowsData * self.tableRowHeight, self.tableViewportHeight)
            self.tableSyncingScroll = false
        end
    end

    return mainFrame
end

ns.modules.mainTableController = mainTableController

return mainTableController
