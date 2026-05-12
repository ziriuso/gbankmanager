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
assert.equal(7, #mainFrame.navItems, "history should be hidden from sidebar navigation for now")
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
    requests = {
        { approval = "PENDING", fulfillment = "OPEN" },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL" },
    },
    oneTimeTargets = {},
}

mainFrame:SelectView("DASHBOARD")
assert.truthy(mainFrame.dashboardCards[1].valueText:GetText() ~= "42", "dashboard should format last scan timestamps into readable text")
assert.equal("1", mainFrame.dashboardCards[2].valueText:GetText(), "dashboard should show pending request totals in a card")
assert.truthy(string.find(mainFrame.dashboardCards[3].linesText:GetText(), "1. Flask Alpha x7", 1, true) ~= nil, "dashboard should show top withdrawal items")

mainFrame:SelectView("INVENTORY")
assert.equal("Name", mainFrame.tableHeaderLabels[1]:GetText(), "inventory should render a table header")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[1]:GetText(), "inventory should render item names in table rows")
assert.equal("10", mainFrame.tableRows[1].columns[2]:GetText(), "inventory should render quantities in table rows")
assert.equal("Flasks", mainFrame.tableRows[1].columns[3]:GetText(), "inventory should render tab names in table rows")
assert.equal("Yes", mainFrame.tableRows[1].columns[4]:GetText(), "inventory should show whether an item needs restock")
assert.equal("12", mainFrame.tableRows[1].columns[5]:GetText(), "inventory should show minimum restock values")
assert.equal(240, mainFrame.tableHeaderLabels[1].width, "inventory name column should allocate wider space for long item names")
assert.equal(80, mainFrame.tableHeaderLabels[2].width, "inventory quantity column should stay compact")

assert.truthy(mainFrame.viewDescriptions.HISTORY == nil, "history view description should be hidden when the tab is disabled")

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

local filteredHistory = history.Filter({
    { type = "QUANTITY_DECREASED", actor = "OfficerOne", name = "Flask Alpha" },
    { type = "ITEM_ADDED", actor = "OfficerTwo", name = "Potion Beta" },
}, {
    changeType = "ITEM_ADDED",
    actor = "OfficerTwo",
})

assert.equal(1, #filteredHistory, "history filter should combine change type and actor filters")
assert.equal("Potion Beta", filteredHistory[1].name, "history filter should keep matching rows")

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

mainFrame:SelectView("REQUESTS")
assert.equal("REQUESTS", mainFrame.activeView, "task 6 views should be selectable from the shell")

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
