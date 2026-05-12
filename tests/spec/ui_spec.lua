local assert = require("tests.helpers.assert")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local mainFrame = ns.modules.mainFrame
local dashboard = ns.modules.dashboardView
local inventory = ns.modules.inventoryView
local history = ns.modules.historyView
local exportsView = ns.modules.exportsView
local minimumsView = ns.modules.minimumsView
local targetsView = ns.modules.targetsView
local requestsView = ns.modules.requestsView
local requestDialog = ns.modules.requestDialog
local slash = ns.modules.slash
local scanner = ns.modules.scanner

assert.truthy(type(mainFrame) == "table", "main frame should load from the toc")
assert.truthy(type(dashboard) == "table", "dashboard view should load from the toc")
assert.truthy(type(inventory) == "table", "inventory view should load from the toc")
assert.truthy(type(history) == "table", "history view should load from the toc")
assert.truthy(type(exportsView) == "table", "exports view should load from the toc")
assert.truthy(type(minimumsView) == "table", "minimums view should load from the toc")
assert.truthy(type(targetsView) == "table", "targets view should load from the toc")
assert.truthy(type(requestsView) == "table", "requests view should load from the toc")
assert.truthy(type(requestDialog) == "table", "request dialog should load from the toc")

assert.equal("DASHBOARD", mainFrame.activeView, "main frame should default to dashboard")
assert.truthy(mainFrame.collapsedSidebar == false, "sidebar should start expanded")
assert.equal(8, #mainFrame.navItems, "history should be available in sidebar navigation once audit history work starts")
assert.truthy(not mainFrame:IsShown(), "main frame should start hidden")
assert.truthy(mainFrame.mouseEnabled == false, "main frame should not capture mouse before opening")
assert.equal(920, mainFrame.resizeBounds.minWidth, "main frame should use resize bounds for the minimum width")
assert.equal(560, mainFrame.resizeBounds.minHeight, "main frame should use resize bounds for the minimum height")
assert.equal(1280, mainFrame.resizeBounds.maxWidth, "main frame should use resize bounds for the maximum width")
assert.equal(760, mainFrame.resizeBounds.maxHeight, "main frame should use resize bounds for the maximum height")
assert.truthy(type(mainFrame.backdrop) == "table", "main frame should define a visible backdrop")
assert.equal("GameFontHighlightLarge", mainFrame.titleText.fontObject, "title text should inherit a real WoW font")
assert.equal("GameFontHighlightSmall", mainFrame.subtitleText.fontObject, "subtitle text should inherit a real WoW font")
assert.equal("GameFontNormal", mainFrame.statusText.fontObject, "status text should inherit a real WoW font")
assert.equal("GameFontNormal", mainFrame.viewTitle.fontObject, "view title should inherit a real WoW font")
assert.equal("LEFT", mainFrame.viewTitle.justifyH, "screen text should be left aligned")
assert.truthy(#(mainFrame.titleText.points or {}) > 0, "main frame title should be anchored into the top bar")
assert.truthy(type(mainFrame.closeButton) == "table", "main frame should expose a close button")
assert.truthy(type(mainFrame.closeButton:GetScript("OnClick")) == "function", "close button should be wired")
assert.truthy(type(mainFrame.sidebarButtons[1]:GetScript("OnClick")) == "function", "sidebar buttons should switch views when clicked")
assert.truthy(type(mainFrame.collapseButton) == "table", "main frame should expose a collapse control")
assert.truthy(type(mainFrame.scanButton) == "table", "main frame should expose a scan button")
assert.truthy(type(mainFrame.optionsPanel) == "table", "main frame should expose an options panel")
assert.truthy(type(mainFrame.tableHeaderFrame) == "table", "main frame should expose a table header frame")
assert.truthy(type(mainFrame.tableScrollFrame) == "table", "main frame should expose a table scroll frame")
assert.truthy(type(mainFrame.transparencyDownButton) == "table", "options panel should expose a transparency decrease button")
assert.truthy(type(mainFrame.transparencyUpButton) == "table", "options panel should expose a transparency increase button")
assert.truthy(type(mainFrame:GetScript("OnDragStart")) == "function", "main frame should be draggable")
assert.truthy(type(mainFrame:GetScript("OnDragStop")) == "function", "main frame should stop moving on drag stop")
assert.equal(0.96, mainFrame.currentAlpha, "main frame should start near opaque")

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "slash ui command should show the main frame")
assert.truthy(mainFrame.mouseEnabled == true, "opening the main frame should enable mouse capture")

mainFrame.collapseButton:GetScript("OnClick")(mainFrame.collapseButton)
assert.truthy(mainFrame.collapsedSidebar == true, "toggle should collapse the sidebar")
assert.equal(40, mainFrame.sidebarButtons[1]:GetWidth(), "collapsed sidebar should shrink nav button width")
assert.equal("", mainFrame.sidebarButtons[1].labelText:GetText(), "collapsed sidebar should hide nav labels instead of stacking characters")

scanner.scanInProgress = false
mainFrame.scanButton:GetScript("OnClick")(mainFrame.scanButton)
assert.truthy(scanner.scanInProgress == true, "scan button should begin a bank scan")
assert.equal("Scanning 0/2 tabs", mainFrame.statusText:GetText(), "scan button should surface current scan progress")

mainFrame:SelectView("OPTIONS")
assert.equal("OPTIONS", mainFrame.activeView, "options tab should be selectable")
assert.truthy(mainFrame.optionsPanel:IsShown(), "options panel should show in the options view")

local alphaAfterDown
mainFrame.transparencyDownButton:GetScript("OnClick")(mainFrame.transparencyDownButton)
alphaAfterDown = mainFrame.currentAlpha
assert.truthy(alphaAfterDown < 0.96, "transparency down should reduce alpha")

mainFrame.transparencyUpButton:GetScript("OnClick")(mainFrame.transparencyUpButton)
assert.truthy(mainFrame.currentAlpha > alphaAfterDown, "transparency up should increase alpha")

mainFrame:GetScript("OnDragStart")(mainFrame)
assert.truthy(mainFrame.moving == true, "drag start should begin moving the frame")
mainFrame:GetScript("OnDragStop")(mainFrame)
assert.truthy(mainFrame.moving == false, "drag stop should end frame movement")

ns.state.db = {
    meta = {
        updatedAt = 42,
    },
    currentSnapshotId = "scan-1",
    snapshots = {
        ["scan-1"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 2, tabs = { Potions = 2 } },
            },
        },
    },
    changeLog = {
        { type = "QUANTITY_INCREASED", name = "Flask Alpha", delta = 7, actor = "OfficerOne", scannedAt = 42 },
        { type = "QUANTITY_DECREASED", name = "Flask Alpha", delta = 7, actor = "OfficerTwo", scannedAt = 42 },
    },
    auditLog = {
        { type = "REQUEST_APPROVED", actor = "GuildLead", category = "REQUEST", itemName = "Flask Alpha", oldValue = "PENDING", newValue = "APPROVED", timestamp = 42 },
        { type = "MINIMUM_UPDATED", actor = "OfficerTwo", category = "MINIMUM", itemName = "Potion Beta", oldValue = "10", newValue = "25", timestamp = 43 },
    },
    requests = {
        { requester = "MemberOne", itemID = 1001, itemName = "Flask Alpha", quantity = 2, approval = "PENDING", fulfillment = "OPEN", note = "Raid night", createdAt = 42 },
        { requester = "MemberTwo", itemID = 2002, itemName = "Potion Beta", quantity = 1, approval = "APPROVED", fulfillment = "OPEN", note = "", createdAt = 43 },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL" },
    },
    oneTimeTargets = {},
}

scanner.scanInProgress = false
mainFrame:SelectView("DASHBOARD")
assert.truthy(type(mainFrame.dashboardCards[4]) == "table", "dashboard should render a fourth card for export readiness")
assert.truthy(mainFrame.dashboardCards[1].valueText:GetText() ~= "42", "dashboard should format last scan timestamps into readable text")
assert.equal("1", mainFrame.dashboardCards[2].valueText:GetText(), "dashboard should show pending request totals in a card")
assert.equal("3", mainFrame.dashboardCards[3].valueText:GetText(), "dashboard should show total purchase quantity in a dedicated card")
assert.truthy(string.find(mainFrame.dashboardCards[4].linesText:GetText(), "1. Flask Alpha x7", 1, true) ~= nil, "dashboard should show top withdrawal items")
assert.truthy(string.find(mainFrame.statusText:GetText(), "Last scan", 1, true) ~= nil, "dashboard should restore saved last scan status after reload")

mainFrame:SelectView("INVENTORY")
assert.equal("Name", mainFrame.tableHeaderLabels[2]:GetText(), "inventory should render a table header")
assert.equal("", mainFrame.tableRows[1].columns[1]:GetText(), "inventory should leave the quality column blank when quality is unknown")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "inventory should render item names in table rows")
assert.equal("10", mainFrame.tableRows[1].columns[3]:GetText(), "inventory should render quantities in table rows")
assert.equal("Flasks", mainFrame.tableRows[1].columns[4]:GetText(), "inventory should render tab names in table rows")
assert.equal("Yes", mainFrame.tableRows[1].columns[5]:GetText(), "inventory should show whether an item needs restock")
assert.equal("12", mainFrame.tableRows[1].columns[6]:GetText(), "inventory should show minimum restock values")
assert.equal(220, mainFrame.tableHeaderLabels[2].width, "inventory name column should allocate wider space for long item names")
assert.equal(80, mainFrame.tableHeaderLabels[3].width, "inventory quantity column should stay compact")
assert.equal(6, #mainFrame.tableHeaderLabels, "inventory should render a dedicated quality column")
assert.truthy(type(mainFrame.tableFilterInputs[1]) == "table", "inventory should expose inline column filters")
assert.truthy(mainFrame.tableViewportWidth == mainFrame.tableViewportInnerWidth, "inventory rows should match the header width exactly")
assert.truthy(mainFrame.tableVisibleCount < 20, "inventory should size visible rows to the viewport instead of overflowing the bottom")

assert.truthy(mainFrame.viewDescriptions.HISTORY ~= nil, "history view should have a description once the tab is enabled")

local summary = dashboard.BuildSummary({
    meta = {
        updatedAt = 42,
    },
    requests = {
        { approval = "PENDING", fulfillment = "OPEN" },
        { approval = "APPROVED", fulfillment = "SUGGESTED_FULFILLED" },
        { approval = "APPROVED", fulfillment = "OPEN" },
    },
}, {
    { totalToBuy = 12 },
    { totalToBuy = 5 },
})

assert.equal(42, summary.lastScanAt, "dashboard should expose last scan metadata")
assert.equal(1, summary.pendingRequestCount, "dashboard should count pending requests only")
assert.equal(1, summary.suggestedFulfillmentCount, "dashboard should count suggested fulfillments")
assert.equal(2, summary.exportReadyCount, "dashboard should count export rows")
assert.equal(17, summary.totalPurchaseQuantity, "dashboard should total export-ready quantity")

local filteredInventory = inventory.FilterItems({
    { name = "Flask Alpha", totalCount = 6 },
    { name = "Potion Beta", totalCount = 2 },
}, "flask")

assert.equal(1, #filteredInventory, "inventory filter should match by lowercase substring")
assert.equal("Flask Alpha", filteredInventory[1].name, "inventory filter should return matching item")

local columnLayout = inventory.GetColumnLayout({}, 720)
assert.equal(6, #columnLayout, "inventory should expose six table columns")
assert.equal("quality", columnLayout[1].key, "inventory layout should start with the quality column")
assert.equal("LEFT", columnLayout[2].justifyH, "inventory text columns should stay left aligned")

local resizedLayout = inventory.ResizeColumnLayout(columnLayout, 2, 40, 720)
assert.equal(columnLayout[2].width + 40, resizedLayout[2].width, "column resize should widen the dragged column")
assert.truthy(resizedLayout[3].width < columnLayout[3].width, "column resize should borrow width from later columns")
assert.equal(690, resizedLayout[1].width + resizedLayout[2].width + resizedLayout[3].width + resizedLayout[4].width + resizedLayout[5].width + resizedLayout[6].width, "column resize should preserve total table width")

local filteredRows = inventory.ApplyColumnFilters({
    { quality = "", name = "Flask Alpha", quantity = "6", tab = "Flasks", restock = "Yes", minimum = "12" },
    { quality = "", name = "Potion Beta", quantity = "2", tab = "Potions", restock = "No", minimum = "-" },
}, {
    name = "flask",
    restock = "yes",
})

assert.equal(1, #filteredRows, "column filters should narrow rows using per-column text")
assert.equal("Flask Alpha", filteredRows[1].name, "column filters should keep matching rows only")

local clippedRows = inventory.BuildDisplayRows({
    {
        quality = "",
        name = "Chromatically Tempered Everlasting Flask of the Mountain Sage",
        quantity = "48",
        tab = "Flasks, Overflow, Emergency Reserves, Experimental Shelf",
        restock = "Yes",
        minimum = "120",
    },
}, columnLayout)

assert.truthy(string.sub(clippedRows[1].name, -3) == "...", "long inventory item names should clip with an ellipsis")
assert.truthy(string.sub(clippedRows[1].tab, -3) == "...", "long tab lists should clip with an ellipsis")

local qualityRows = inventory.BuildTableRows({
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, quality = 3, tabs = { Flasks = 10 } },
        [2002] = { itemID = 2002, name = "Basic Thread", totalCount = 4, tabs = { Cloth = 4 } },
    },
}, {
    minimums = {},
}, {
    name = "",
})

local qualityByName = {}
for _, row in ipairs(qualityRows) do
    qualityByName[row.name] = row
end

assert.truthy(qualityByName["Flask Alpha"].quality ~= "", "inventory should emit a quality marker when item quality is known")
assert.equal("", qualityByName["Basic Thread"].quality, "inventory should leave the quality column blank when quality is unknown")

local filteredHistory = history.Filter({
    { type = "REQUEST_APPROVED", actor = "OfficerOne", requester = "MemberOne", itemName = "Flask Alpha", category = "REQUEST" },
    { type = "MINIMUM_UPDATED", actor = "OfficerTwo", itemName = "Potion Beta", category = "MINIMUM", oldValue = "10", newValue = "25" },
}, {
    changeType = "MINIMUM_UPDATED",
    actor = "OfficerTwo",
})

assert.equal(1, #filteredHistory, "history filter should combine change type and actor filters")
assert.equal("Potion Beta", filteredHistory[1].itemName, "history filter should keep matching rows")

local historyRows = history.BuildTableRows({
    {
        type = "REQUEST_APPROVED",
        actor = "GuildLead",
        category = "REQUEST",
        itemName = "Flask Alpha",
        requester = "MemberOne",
        oldValue = "PENDING",
        newValue = "APPROVED",
        timestamp = 42,
    },
    {
        type = "MINIMUM_UPDATED",
        actor = "OfficerTwo",
        category = "MINIMUM",
        itemName = "Potion Beta",
        oldValue = "10",
        newValue = "25",
        timestamp = 43,
    },
}, {})

assert.equal("Request", historyRows[1].category, "history should label request audit rows by category")
assert.equal("PENDING", historyRows[1].oldValue, "history should expose old values for audit changes")
assert.equal("APPROVED", historyRows[1].newValue, "history should expose new values for audit changes")
assert.equal("10", historyRows[2].oldValue, "history should keep previous minimum values")
assert.equal("25", historyRows[2].newValue, "history should keep new minimum values")

local spreadsheetText = exportsView.BuildSpreadsheetText({
    { itemName = "Flask Alpha", totalToBuy = 4, reason = "RESTOCK:4" },
})

assert.equal("itemName,totalToBuy,reason\nFlask Alpha,4,RESTOCK:4", spreadsheetText, "exports view should build spreadsheet text from rows")

local minimums = minimumsView.Upsert({
    { itemID = 1001, itemName = "Flask Alpha", quantity = 8, scope = "GLOBAL" },
}, {
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 10,
    scope = "GLOBAL",
})

assert.equal(1, #minimums, "minimum upsert should replace matching rules")
assert.equal(10, minimums[1].quantity, "minimum upsert should keep the latest quantity")

local minimumDb = {
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 8, scope = "GLOBAL" },
    },
    auditLog = {},
}

local updatedMinimums = minimumsView.UpsertWithAudit(minimumDb, {
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 10,
    scope = "GLOBAL",
}, {
    actor = "OfficerOne",
    timestamp = 101,
})

assert.equal(1, #updatedMinimums, "minimum audit upsert should still replace matching rules")
assert.equal(1, #minimumDb.auditLog, "minimum audit upsert should append an audit row")
assert.equal("MINIMUM_UPDATED", minimumDb.auditLog[1].type, "minimum audit upsert should record update events")
assert.equal("8", minimumDb.auditLog[1].oldValue, "minimum audit upsert should store the previous minimum value")
assert.equal("10", minimumDb.auditLog[1].newValue, "minimum audit upsert should store the new minimum value")

local target = targetsView.MarkSuggestedFulfilled({
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 12,
    status = "OPEN",
}, 12)

assert.equal("SUGGESTED_FULFILLED", target.status, "targets view should suggest fulfillment when counts meet the target")

local resolvedMatches = requestDialog.ResolveMatches({
    { itemID = 1001, name = "Flask Alpha" },
    { itemID = 2002, name = "Potion Beta" },
}, "1001")

assert.equal(1, #resolvedMatches, "request dialog should match by item id")
assert.equal("Flask Alpha", resolvedMatches[1].name, "request dialog should return the matching item")

local officerRequest = requestDialog.Submit({
    requester = "OfficerOne",
    role = "OFFICER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("APPROVED", officerRequest.approval, "request dialog should auto-approve officer requests")

local ownRequests = requestsView.FilterOwnRequests({
    { requester = "MemberOne", itemName = "Flask Alpha" },
    { requester = "OfficerOne", itemName = "Potion Beta" },
    { requester = "MemberOne", itemName = "Feast Gamma" },
}, "MemberOne")

assert.equal(2, #ownRequests, "requests view should keep only the player's own request rows")
assert.equal("Flask Alpha", ownRequests[1].itemName, "requests view should preserve matching row order")

local requestQueue = requestsView.BuildOfficerQueue({
    { requester = "MemberOne", itemName = "Flask Alpha", quantity = 2, approval = "PENDING", fulfillment = "OPEN" },
    { requester = "MemberTwo", itemName = "Potion Beta", quantity = 1, approval = "APPROVED", fulfillment = "OPEN" },
    { requester = "MemberThree", itemName = "Feast Gamma", quantity = 4, approval = "REJECTED", fulfillment = "OPEN" },
})

assert.equal(2, #requestQueue, "request queue should keep actionable requests only")
assert.equal("PENDING", requestQueue[1].approval, "request queue should prioritize pending approvals")
assert.equal("APPROVED", requestQueue[2].approval, "request queue should keep approved open requests")

local requestRows = requestsView.BuildTableRows({
    { requester = "MemberOne", itemName = "Flask Alpha", quantity = 2, approval = "PENDING", fulfillment = "OPEN", note = "Raid night", createdAt = 42 },
    { requester = "MemberTwo", itemName = "Potion Beta", quantity = 1, approval = "APPROVED", fulfillment = "OPEN", note = "", createdAt = 43 },
})

assert.equal("MemberOne", requestRows[1].requester, "request table rows should expose requester names")
assert.equal("PENDING", requestRows[1].approval, "request table rows should expose approval state")
assert.equal("Raid night", requestRows[1].note, "request table rows should preserve notes")

mainFrame:SelectView("REQUESTS")
assert.equal("REQUESTS", mainFrame.activeView, "task 6 views should be selectable from the shell")
assert.equal("MemberOne", mainFrame.tableRows[1].columns[1]:GetText(), "requests tab should render requester names in the shared table shell")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "requests tab should render requested items")
assert.equal("PENDING", mainFrame.tableRows[1].columns[4]:GetText(), "requests tab should render approval state")
mainFrame:SelectView("HISTORY")
assert.equal("HISTORY", mainFrame.activeView, "history should be selectable from the shell once re-enabled")
assert.equal("Request", mainFrame.tableRows[1].columns[1]:GetText(), "history should render request audit rows in the shared table shell")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "history should render audit item names")

ns.state.db = {
    meta = {
        updatedAt = 42,
    },
    currentSnapshotId = "scan-scroll",
    snapshots = {
        ["scan-scroll"] = {
            items = {
                [1001] = {
                    itemID = 1001,
                    name = "Chromatically Tempered Everlasting Flask of the Mountain Sage",
                    totalCount = 48,
                    tabs = {
                        ["Flasks"] = 12,
                        ["Overflow"] = 20,
                        ["Emergency Reserves"] = 8,
                        ["Experimental Shelf"] = 8,
                    },
                },
                [1002] = { itemID = 1002, name = "Item 02", totalCount = 2, tabs = { ["Tab 02"] = 2 } },
                [1003] = { itemID = 1003, name = "Item 03", totalCount = 3, tabs = { ["Tab 03"] = 3 } },
                [1004] = { itemID = 1004, name = "Item 04", totalCount = 4, tabs = { ["Tab 04"] = 4 } },
                [1005] = { itemID = 1005, name = "Item 05", totalCount = 5, tabs = { ["Tab 05"] = 5 } },
                [1006] = { itemID = 1006, name = "Item 06", totalCount = 6, tabs = { ["Tab 06"] = 6 } },
                [1007] = { itemID = 1007, name = "Item 07", totalCount = 7, tabs = { ["Tab 07"] = 7 } },
                [1008] = { itemID = 1008, name = "Item 08", totalCount = 8, tabs = { ["Tab 08"] = 8 } },
                [1009] = { itemID = 1009, name = "Item 09", totalCount = 9, tabs = { ["Tab 09"] = 9 } },
                [1010] = { itemID = 1010, name = "Item 10", totalCount = 10, tabs = { ["Tab 10"] = 10 } },
                [1011] = { itemID = 1011, name = "Item 11", totalCount = 11, tabs = { ["Tab 11"] = 11 } },
                [1012] = { itemID = 1012, name = "Item 12", totalCount = 12, tabs = { ["Tab 12"] = 12 } },
                [1013] = { itemID = 1013, name = "Item 13", totalCount = 13, tabs = { ["Tab 13"] = 13 } },
                [1014] = { itemID = 1014, name = "Item 14", totalCount = 14, tabs = { ["Tab 14"] = 14 } },
                [1015] = { itemID = 1015, name = "Item 15", totalCount = 15, tabs = { ["Tab 15"] = 15 } },
                [1016] = { itemID = 1016, name = "Item 16", totalCount = 16, tabs = { ["Tab 16"] = 16 } },
                [1017] = { itemID = 1017, name = "Item 17", totalCount = 17, tabs = { ["Tab 17"] = 17 } },
                [1018] = { itemID = 1018, name = "Item 18", totalCount = 18, tabs = { ["Tab 18"] = 18 } },
                [1019] = { itemID = 1019, name = "Item 19", totalCount = 19, tabs = { ["Tab 19"] = 19 } },
                [1020] = { itemID = 1020, name = "Item 20", totalCount = 20, tabs = { ["Tab 20"] = 20 } },
                [1021] = { itemID = 1021, name = "Item 21", totalCount = 21, tabs = { ["Tab 21"] = 21 } },
                [1022] = { itemID = 1022, name = "Item 22", totalCount = 22, tabs = { ["Tab 22"] = 22 } },
            },
        },
    },
    requests = {},
    minimums = {
        { itemID = 1001, itemName = "Chromatically Tempered Everlasting Flask of the Mountain Sage", quantity = 120, scope = "GLOBAL" },
    },
    oneTimeTargets = {},
}

mainFrame:SelectView("INVENTORY")
assert.truthy(type(mainFrame.tableScrollBar) == "table", "inventory should expose a visible scroll bar")
assert.truthy(type(mainFrame.tableScrollBar.scrollUpButton) == "table", "inventory scroll bar should expose an up button")
assert.truthy(type(mainFrame.tableScrollBar.scrollDownButton) == "table", "inventory scroll bar should expose a down button")
assert.equal(0, mainFrame.tableScrollOffset, "inventory should start scrolled to the top")
assert.truthy(string.sub(mainFrame.tableRows[1].columns[2]:GetText(), -3) == "...", "inventory should clip long visible name text")
assert.truthy(type(mainFrame.tableColumnResizeHandles[2]) == "table", "inventory should expose a resize handle for user-adjustable columns")
assert.truthy(type(mainFrame.tableRows[1].backdrop) == "table", "inventory rows should render with visible framing")
assert.equal(mainFrame.tableHeaderFrame.height, mainFrame.tableScrollBar.topButtonOffset, "inventory scrollbar should align with the table header")
assert.truthy(mainFrame.tableScrollChild.height <= mainFrame.tableViewportHeight + (mainFrame.tableRowHeight * math.max(0, #mainFrame.tableRowsData - mainFrame.tableVisibleCount)), "inventory table body should stay inside the viewport without a clipped overhang")

mainFrame:ResizeInventoryColumn(2, 40)
assert.equal(260, mainFrame.tableHeaderLabels[2].width, "inventory resize should update the name column width")
assert.equal(40, ns.state.db.ui.inventoryColumnWidths[2], "inventory should persist the user width delta for manual testing")

mainFrame.tableFilterInputs[4]:SetText("Tab 03")
mainFrame:ApplyInventoryFilters()
assert.equal("Item 03", mainFrame.tableRows[1].columns[2]:GetText(), "inventory filters should update the visible rows using the table inputs")

mainFrame.tableFilterInputs[4]:SetText("")
mainFrame:ApplyInventoryFilters()
mainFrame:ScrollTableRows(2)
assert.equal(2, mainFrame.tableScrollOffset, "inventory should track scroll offset")
assert.equal("Item 03", mainFrame.tableRows[1].columns[2]:GetText(), "inventory scrolling should advance visible rows")

mainFrame.closeButton:GetScript("OnClick")(mainFrame.closeButton)
assert.truthy(not mainFrame:IsShown(), "close button should hide the main frame")
assert.truthy(mainFrame.mouseEnabled == false, "closing the main frame should release mouse capture")

local replacementFrame = {
    shown = false,
    ShowDashboard = function(self)
        self.shown = true
    end,
}

ns.modules.mainFrame = replacementFrame
slash.command("ui")
assert.truthy(replacementFrame.shown == true, "slash command should resolve the current main frame module at call time")
