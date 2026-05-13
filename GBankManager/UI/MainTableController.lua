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

    mainFrame.tableFilterInputs = mainFrame.tableFilterInputs or {}
    for index = 1, 9 do
        local input = mainFrame.tableFilterInputs[index] or makeInput(mainFrame.tableFilterFrame, 80, 22)
        mainFrame.tableFilterInputs[index] = input
    end

    mainFrame.tableScrollFrame = mainFrame.tableScrollFrame or _G.CreateFrame("ScrollFrame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.tableScrollFrame:SetPoint("TOPLEFT", mainFrame.tableFilterFrame, "BOTTOMLEFT", 0, -4)
    mainFrame.tableScrollFrame:SetSize(mainFrame.tableViewportWidth, mainFrame.tableViewportHeight)
    applyPanelStyle(mainFrame.tableScrollFrame, theme.colors.background)
    mainFrame.tableScrollFrame:EnableMouseWheel(true)

    mainFrame.tableScrollChild = mainFrame.tableScrollChild or _G.CreateFrame("Frame", nil, mainFrame.tableScrollFrame, "BackdropTemplate")
    mainFrame.tableScrollChild:SetSize(mainFrame.tableViewportWidth, mainFrame.tableViewportHeight)
    mainFrame.tableScrollFrame:SetScrollChild(mainFrame.tableScrollChild)
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

    mainFrame.tableScrollBar = mainFrame.tableScrollBar or _G.CreateFrame("Frame", nil, mainFrame.content, "BackdropTemplate")
    mainFrame.tableScrollBar:SetPoint("TOPLEFT", mainFrame.tableHeaderFrame, "TOPRIGHT", 8, 0)
    mainFrame.tableScrollBar:SetPoint("BOTTOMLEFT", mainFrame.tableScrollFrame, "BOTTOMRIGHT", 8, 0)
    mainFrame.tableScrollBar:SetWidth(24)
    mainFrame.tableScrollBar.topButtonOffset = mainFrame.tableHeaderHeight
    applyPanelStyle(mainFrame.tableScrollBar, theme.colors.panel)

    mainFrame.tableScrollBar.scrollUpButton = mainFrame.tableScrollBar.scrollUpButton or makeButton(mainFrame.tableScrollBar, 24, 24, "^")
    mainFrame.tableScrollBar.scrollUpButton:SetPoint("TOPLEFT", mainFrame.tableScrollBar, "TOPLEFT", 0, 0)
    mainFrame.tableScrollBar.scrollDownButton = mainFrame.tableScrollBar.scrollDownButton or makeButton(mainFrame.tableScrollBar, 24, 24, "v")
    mainFrame.tableScrollBar.scrollDownButton:SetPoint("BOTTOMLEFT", mainFrame.tableScrollBar, "BOTTOMLEFT", 0, 0)
    mainFrame.tableScrollBar.valueText = mainFrame.tableScrollBar.valueText or makeLabel(mainFrame.tableScrollBar, "", "GameFontHighlightSmall")
    mainFrame.tableScrollBar.valueText:SetPoint("TOP", mainFrame.tableScrollBar.scrollUpButton, "BOTTOM", 0, -12)
    mainFrame.tableScrollBar.track = mainFrame.tableScrollBar.track or _G.CreateFrame("Frame", nil, mainFrame.tableScrollBar, "BackdropTemplate")
    mainFrame.tableScrollBar.track:SetPoint("TOPLEFT", mainFrame.tableScrollBar.scrollUpButton, "BOTTOMLEFT", 0, -30)
    mainFrame.tableScrollBar.track:SetPoint("BOTTOMLEFT", mainFrame.tableScrollBar.scrollDownButton, "TOPLEFT", 0, 30)
    mainFrame.tableScrollBar.track:SetWidth(24)
    applyPanelStyle(mainFrame.tableScrollBar.track, theme.colors.background)
    mainFrame.tableScrollBar.thumb = mainFrame.tableScrollBar.thumb or _G.CreateFrame("Button", nil, mainFrame.tableScrollBar.track, "BackdropTemplate")
    mainFrame.tableScrollBar.thumb:SetSize(18, 48)
    mainFrame.tableScrollBar.thumb:SetPoint("TOP", mainFrame.tableScrollBar.track, "TOP", 0, -2)
    applyPanelStyle(mainFrame.tableScrollBar.thumb, theme.colors.accent)
    mainFrame.tableScrollBar.thumb:EnableMouse(true)

    mainFrame.tableRows = mainFrame.tableRows or {}
    for rowIndex = 1, mainFrame.tableVisibleCount do
        local row = mainFrame.tableRows[rowIndex] or _G.CreateFrame("Button", nil, mainFrame.tableScrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", mainFrame.tableScrollChild, "TOPLEFT", 0, -((rowIndex - 1) * mainFrame.tableRowHeight))
        row:SetSize(mainFrame.tableViewportWidth, mainFrame.tableRowHeight - 2)
        row:EnableMouse(true)
        applyPanelStyle(row, rowIndex % 2 == 1 and theme.colors.panel or theme.colors.panelAlt)
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
    end

    function mainFrame:UpdateScrollThumb()
        local thumb = self.tableScrollBar and self.tableScrollBar.thumb
        local track = self.tableScrollBar and self.tableScrollBar.track

        if not thumb or not track then
            return
        end

        local totalRows = #self.tableRowsData
        local visibleRows = math.max(1, self.tableVisibleCount)
        local maxOffset = math.max(0, totalRows - visibleRows)
        local trackHeight = math.max(24, (track.height or self.tableViewportHeight or 0) - 4)
        local thumbHeight = math.max(24, math.floor(trackHeight * math.min(1, visibleRows / math.max(visibleRows, totalRows))))

        thumb:SetHeight(thumbHeight)

        local travel = math.max(0, trackHeight - thumbHeight)
        local progress = maxOffset > 0 and ((self.tableScrollOffset or 0) / maxOffset) or 0
        local yOffset = -2 - math.floor(travel * progress)

        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, yOffset)
        thumb.progress = progress
        thumb.travel = travel
    end

    function mainFrame:RefreshVisibleTableRows()
        local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
        self.tableScrollOffset = math.max(0, math.min(self.tableScrollOffset or 0, maxOffset))

        for rowIndex, rowFrame in ipairs(self.tableRows) do
            local row = self.tableRowsData[rowIndex + self.tableScrollOffset]
            for colIndex = 1, #self.tableHeaderLabels do
                local key = self.tableColumnKeys[colIndex]
                rowFrame.columns[colIndex]:SetText(row and key and (row[key] or "") or "")
            end

            rowFrame.rowData = row
            applyTableRowStyle(rowFrame, rowIndex, isSelectedTableRow(self, row))
            rowFrame:SetScript("OnClick", function(frame)
                handleTableRowClick(self, frame.rowData)
            end)

            if self.activeView == "MINIMUMS" then
                syncMinimumInlineRow(self, rowFrame, row, rowIndex)
            elseif type(hideMinimumInlineRow) == "function" then
                hideMinimumInlineRow(self, rowFrame)
            end
        end

        local maxRow = math.max(1, #self.tableRowsData)
        self.tableScrollBar.valueText:SetText(string.format("%d-%d", math.min(maxRow, self.tableScrollOffset + 1), math.min(maxRow, self.tableScrollOffset + self.tableVisibleCount)))
        self:UpdateScrollThumb()
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

    function mainFrame:DragScrollThumb(cursorY)
        local thumb = self.tableScrollBar and self.tableScrollBar.thumb

        if not thumb then
            return self.tableScrollOffset
        end

        local maxOffset = math.max(0, #self.tableRowsData - self.tableVisibleCount)
        local travel = math.max(1, thumb.travel or 1)
        local startCursorY = thumb.dragStartCursorY or cursorY or 0
        local startOffset = thumb.dragStartOffset or 0
        local deltaY = startCursorY - (cursorY or startCursorY)
        local progressDelta = deltaY / travel
        local nextOffset = startOffset + (maxOffset * progressDelta)

        return self:SetTableScrollOffset(math.floor(nextOffset + 0.5))
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

        self.tableScrollFrame:ClearAllPoints()
        if self:UsesInlineTableFilters() then
            self.tableScrollFrame:SetPoint("TOPLEFT", self.tableFilterFrame, "BOTTOMLEFT", 0, -4)
        else
            self.tableScrollFrame:SetPoint("TOPLEFT", self.tableHeaderFrame, "BOTTOMLEFT", 0, -4)
        end
        self.tableScrollFrame:SetSize(self.tableViewportWidth, self.tableViewportHeight)

        self.tableScrollBar:ClearAllPoints()
        self.tableScrollBar:SetPoint("TOPLEFT", self.tableHeaderFrame, "TOPRIGHT", 8, 0)
        self.tableScrollBar:SetPoint("BOTTOMLEFT", self.tableScrollFrame, "BOTTOMRIGHT", 8, 0)
        self.tableScrollBar.track:SetHeight(math.max(24, self.tableViewportHeight - 64))
        self.tableScrollBar.track.topY = self.tableScrollBar.track.height or 0

        self.minimumEmptyStateText:ClearAllPoints()
        self.minimumEmptyStateText:SetPoint("TOPLEFT", self.tableScrollFrame, "TOPLEFT", 12, -12)

        if self.activeView == "MINIMUMS" then
            self.minimumsPanel:ClearAllPoints()
            self.minimumsPanel:SetPoint("TOPLEFT", self.tableScrollFrame, "BOTTOMLEFT", 0, -16)
            self.minimumsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
        else
            self.minimumsPanel:ClearAllPoints()
            self.minimumsPanel:SetPoint("TOPLEFT", self.viewSubtitle, "BOTTOMLEFT", 0, -24)
            self.minimumsPanel:SetPoint("RIGHT", self.content, "RIGHT", -24, 0)
        end
    end

    mainFrame.tableScrollBar.scrollUpButton:SetScript("OnClick", function()
        mainFrame:ScrollTableRows(-1)
    end)

    mainFrame.tableScrollBar.scrollDownButton:SetScript("OnClick", function()
        mainFrame:ScrollTableRows(1)
    end)

    mainFrame.tableScrollBar.thumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartOffset = mainFrame.tableScrollOffset or 0
        if type(_G.GetCursorPosition) == "function" then
            local _, cursorY = _G.GetCursorPosition()
            self.dragStartCursorY = cursorY
        else
            self.dragStartCursorY = 0
        end
    end)

    mainFrame.tableScrollBar.thumb:SetScript("OnMouseUp", function(self)
        self.dragging = false
        self.dragStartOffset = nil
        self.dragStartCursorY = nil
    end)

    mainFrame.tableScrollBar.track:SetScript("OnMouseDown", function()
        return nil
    end)

    mainFrame.tableScrollBar:SetScript("OnUpdate", function()
        if mainFrame.tableScrollBar.thumb.dragging and type(_G.GetCursorPosition) == "function" then
            mainFrame:DragScrollThumb(select(2, _G.GetCursorPosition()))
        end
    end)

    mainFrame.tableScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        mainFrame:ScrollTableRows(-delta)
    end)

    return mainFrame
end

ns.modules.mainTableController = mainTableController

return mainTableController
