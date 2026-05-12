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
assert.equal("Inventory Management", mainFrame.subtitleText:GetText(), "top-bar subtitle should describe the addon as inventory management")
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
assert.truthy(type(mainFrame.requestActionsPanel) == "table", "main frame should expose a request actions panel")
assert.truthy(type(mainFrame.requestApproveButton) == "table", "main frame should expose a request approve button")
assert.truthy(type(mainFrame.requestRejectButton) == "table", "main frame should expose a request reject button")
assert.truthy(type(mainFrame.requestFulfillButton) == "table", "main frame should expose a request fulfill button")
assert.truthy(type(mainFrame.requestReopenButton) == "table", "main frame should expose a request reopen button")
assert.truthy(type(mainFrame.requestActionNoteInput) == "table", "main frame should expose a request note input")
assert.truthy(type(mainFrame.requestCreatePanel) == "table", "main frame should expose a request create panel")
assert.truthy(type(mainFrame.requestCreateButton) == "table", "main frame should expose a request create button")
assert.truthy(type(mainFrame.requestCreateItemNameInput) == "table", "main frame should expose a request item-name input")
assert.truthy(type(mainFrame.requestCreateQuantityInput) == "table", "main frame should expose a request quantity input")
assert.truthy(type(mainFrame.minimumsPanel) == "table", "main frame should expose a minimums editor panel")
assert.truthy(type(mainFrame.minimumSaveButton) == "table", "main frame should expose a minimum save button")
assert.truthy(type(mainFrame.minimumNewButton) == "table", "main frame should expose a minimum new button")
assert.truthy(type(mainFrame.minimumSaveAllButton) == "table", "main frame should expose a minimum undo button control")
assert.truthy(type(mainFrame.minimumAddModal) == "table", "main frame should expose a modal for adding new minimum items")
assert.truthy(type(mainFrame.minimumAddItemNameInput) == "table", "main frame should expose a modal minimum item-name input")
assert.truthy(type(mainFrame.minimumAddQuantityInput) == "table", "main frame should expose a modal or staged minimum quantity input")
assert.truthy(type(mainFrame.minimumShowAllToggleButton) == "table", "main frame should expose a minimum show-all toggle button")
assert.truthy(type(mainFrame.minimumSearchInput) == "table", "main frame should expose a minimum search input")
assert.truthy(type(mainFrame.minimumManualOnlyToggleButton) == "table", "main frame should expose a minimum manual-only toggle button")
assert.truthy(type(mainFrame.targetsPanel) == "table", "main frame should expose a targets editor panel")
assert.truthy(type(mainFrame.targetSaveButton) == "table", "main frame should expose a target save button")
assert.truthy(type(mainFrame.targetStatusButton) == "table", "main frame should expose a target status button")
assert.truthy(type(mainFrame.targetItemNameInput) == "table", "main frame should expose a target item-name input")
assert.truthy(type(mainFrame.targetQuantityInput) == "table", "main frame should expose a target quantity input")
assert.truthy(type(mainFrame.exportDelimiterInput) == "table", "exports panel should expose a custom delimiter input")
assert.truthy(type(mainFrame.exportFieldsInput) == "table", "exports panel should expose a custom fields input")
assert.truthy(type(mainFrame.exportHeaderToggleButton) == "table", "exports panel should expose a custom header toggle button")
assert.truthy(type(mainFrame.exportApplyCustomButton) == "table", "exports panel should expose an apply-custom button")
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
assert.equal("", mainFrame.contentBodyText:GetText(), "options view should rely on its panel copy instead of overlapping body text")

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

_G.GBankManagerDB = {
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
ns.state.db = _G.GBankManagerDB

scanner.scanInProgress = false
mainFrame:SelectView("DASHBOARD")
assert.truthy(type(mainFrame.dashboardCards[4]) == "table", "dashboard should render a fourth card for export readiness")
assert.truthy(mainFrame.dashboardCards[1].valueText:GetText() ~= "42", "dashboard should format last scan timestamps into readable text")
assert.equal("1", mainFrame.dashboardCards[2].valueText:GetText(), "dashboard should show pending request totals in a card")
assert.equal("3", mainFrame.dashboardCards[3].valueText:GetText(), "dashboard should show total purchase quantity in a dedicated card")
assert.truthy(string.find(mainFrame.dashboardCards[4].linesText:GetText(), "1. Flask Alpha x7", 1, true) ~= nil, "dashboard should show top withdrawal items")
assert.truthy(string.find(mainFrame.statusText:GetText(), "Last scan", 1, true) ~= nil, "dashboard should restore saved last scan status after reload")
assert.truthy(string.find(mainFrame.statusText:GetText(), "|", 1, true) == nil, "dashboard status should stay focused on scan state instead of crowding the top bar")
do
    local originalBuildTableRows = inventory.BuildTableRows
    inventory.BuildTableRows = function(...)
        assert.truthy(not mainFrame.dashboardCards[1]:IsShown(), "inventory refresh should clear dashboard cards before inventory row building begins")
        return originalBuildTableRows(...)
    end
    mainFrame.sidebarButtons[2]:GetScript("OnClick")(mainFrame.sidebarButtons[2])
    inventory.BuildTableRows = originalBuildTableRows
end
mainFrame.sidebarButtons[2]:GetScript("OnClick")(mainFrame.sidebarButtons[2])
assert.equal("INVENTORY", mainFrame.activeView, "inventory sidebar button should switch the shell into inventory view")
assert.truthy(not mainFrame.dashboardCards[1]:IsShown(), "inventory view should hide dashboard cards after switching tabs")
assert.truthy(mainFrame.tableHeaderFrame:IsShown(), "inventory view should show the shared table header after switching tabs")
assert.truthy(mainFrame.tableScrollFrame:IsShown(), "inventory view should show the shared table body after switching tabs")

assert.equal("Tier", mainFrame.tableHeaderLabels[1]:GetText(), "inventory should label the crafted quality column clearly")
assert.equal("Name", mainFrame.tableHeaderLabels[2]:GetText(), "inventory should render a table header")
assert.equal("", mainFrame.tableRows[1].columns[1]:GetText(), "inventory should leave the quality column blank when quality is unknown")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "inventory should render item names in table rows")
assert.equal("Flasks", mainFrame.tableRows[1].columns[3]:GetText(), "inventory should render tab names in table rows")
assert.equal("Yes", mainFrame.tableRows[1].columns[4]:GetText(), "inventory should show whether an item needs restock")
assert.equal("10", mainFrame.tableRows[1].columns[5]:GetText(), "inventory should render quantities in table rows")
assert.equal("12", mainFrame.tableRows[1].columns[6]:GetText(), "inventory should show minimum restock values")
assert.equal(238, mainFrame.tableHeaderLabels[2].width, "inventory name column should allocate wider space for long item names")
assert.equal(152, mainFrame.tableHeaderLabels[3].width, "inventory tab column should leave enough room for tab names")
assert.equal(90, mainFrame.tableHeaderLabels[4].width, "inventory restock column should keep its header visible")
assert.equal(84, mainFrame.tableHeaderLabels[5].width, "inventory quantity column should stay compact with the abbreviated header")
assert.equal(92, mainFrame.tableHeaderLabels[6].width, "inventory minimum column should keep its header visible")
assert.truthy(#mainFrame.tableHeaderLabels >= 6, "inventory should render a dedicated quality column")
assert.truthy(type(mainFrame.tableFilterInputs[1]) == "table", "inventory should expose inline column filters")
assert.truthy(type(mainFrame.tableHeaderButtons[1]) == "table", "inventory should expose clickable header controls for sorting")
assert.equal("GameFontHighlightSmall", mainFrame.tableFilterInputs[1].fontObject, "inventory filters should use a visible font")
assert.truthy(type(mainFrame.tableFilterInputs[1].textColor) == "table", "inventory filters should set an explicit visible text color")
assert.truthy(not mainFrame.tableFilterInputs[1]:IsShown(), "inventory should hide the tier text filter in favor of header sorting")
assert.truthy(mainFrame.tableFilterInputs[2]:IsShown(), "inventory should keep the name text filter visible")
assert.truthy(mainFrame.tableFilterInputs[3]:IsShown(), "inventory should keep the tab text filter visible")
assert.truthy(mainFrame.tableFilterInputs[4]:IsShown(), "inventory should keep the restock text filter visible")
assert.truthy(not mainFrame.tableFilterInputs[5]:IsShown(), "inventory should hide the quantity text filter in favor of header sorting")
assert.truthy(not mainFrame.tableFilterInputs[6]:IsShown(), "inventory should hide the minimum text filter in favor of header sorting")
assert.truthy(mainFrame.tableViewportWidth == mainFrame.tableViewportInnerWidth, "inventory rows should match the header width exactly")
assert.truthy(mainFrame.tableVisibleCount < 20, "inventory should size visible rows to the viewport instead of overflowing the bottom")
assert.equal("Qty", mainFrame.tableHeaderLabels[5]:GetText(), "inventory should use the abbreviated quantity header before any sort is clicked")

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
assert.equal(720, resizedLayout[1].width + resizedLayout[2].width + resizedLayout[3].width + resizedLayout[4].width + resizedLayout[5].width + resizedLayout[6].width, "column resize should preserve total table width")

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
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, craftedQuality = 3, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3", tabs = { Flasks = 10 } },
        [1002] = { itemID = 1002, name = "Bronze Alloy", totalCount = 5, craftedQuality = 99, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1", tabs = { Metals = 5 } },
        [1003] = { itemID = 1003, name = "Silver Alloy", totalCount = 5, craftedQuality = 0, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2", tabs = { Metals = 5 } },
        [1004] = { itemID = 1004, name = "Azure Alloy", totalCount = 5, craftedQuality = 1, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier4", tabs = { Metals = 5 } },
        [1005] = { itemID = 1005, name = "Prismatic Alloy", totalCount = 5, craftedQuality = 2, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5", tabs = { Metals = 5 } },
        [1006] = { itemID = 1006, name = "Potion Bomb of Speed", totalCount = 5, craftedQuality = 0, craftedQualityIcon = "Interface-Crafting-ReagentQuality-Tier1-Med", tabs = { Potions = 5 } },
        [1007] = { itemID = 1007, name = "Algari Mana Potion", totalCount = 5, craftedQuality = 8, craftedQualityIcon = "Professions-Icon-Quality-Tier3-Inv", tabs = { Potions = 5 } },
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

assert.truthy(string.find(qualityByName["Flask Alpha"].quality, "Professions%-ChatIcon%-Quality%-Tier3") ~= nil, "inventory should emit the crafted quality icon markup when tier data is known")
assert.truthy(string.find(qualityByName["Flask Alpha"].quality, ":22:22", 1, true) ~= nil, "inventory should render larger crafted quality icons for faster scanning")
assert.equal("", qualityByName["Basic Thread"].quality, "inventory should leave the quality column blank when crafted tier is unknown")
assert.equal(1, qualityByName["Bronze Alloy"].qualityValue, "inventory should derive tier 1 from the atlas name even if the raw quality value is noisy")
assert.equal(2, qualityByName["Silver Alloy"].qualityValue, "inventory should derive tier 2 from the atlas name")
assert.equal(4, qualityByName["Azure Alloy"].qualityValue, "inventory should derive tier 4 from the atlas name")
assert.equal(5, qualityByName["Prismatic Alloy"].qualityValue, "inventory should derive tier 5 from the atlas name")
assert.equal(1, qualityByName["Potion Bomb of Speed"].qualityValue, "inventory should derive tier 1 from older atlas naming variants")
assert.equal(3, qualityByName["Algari Mana Potion"].qualityValue, "inventory should derive tier 3 from expansion-specific atlas naming variants")

local tierSortedRows = inventory.SortRows(qualityRows, {
    key = "quality",
    direction = "asc",
})

assert.equal("Bronze Alloy", tierSortedRows[1].name, "inventory tier sorting should treat tier 1 as the first crafted tier")
assert.equal("Potion Bomb of Speed", tierSortedRows[2].name, "inventory tier sorting should keep other tier 1 items alongside the first rank")
assert.equal("Silver Alloy", tierSortedRows[3].name, "inventory tier sorting should place tier 2 after tier 1")
assert.equal("Algari Mana Potion", tierSortedRows[4].name, "inventory tier sorting should place derived tier 3 items with other rank 3 entries")
assert.equal("Flask Alpha", tierSortedRows[5].name, "inventory tier sorting should keep rank 3 items together")
assert.equal("Azure Alloy", tierSortedRows[6].name, "inventory tier sorting should place tier 4 after tier 3")
assert.equal("Prismatic Alloy", tierSortedRows[7].name, "inventory tier sorting should place tier 5 last among ranked items when ascending")
assert.equal("Basic Thread", tierSortedRows[8].name, "inventory tier sorting should push unranked rows after the crafted tiers")

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
    { itemName = "Flask Alpha", itemID = 1001, currentQuantity = 10, restockQuantity = 4, targetQuantity = 0, requestQuantity = 0, totalToBuy = 4, scopeSummary = "GLOBAL", reason = "RESTOCK:4" },
})

assert.equal("itemName,itemID,currentQuantity,restockQuantity,targetQuantity,requestQuantity,totalToBuy,scopeSummary,reason\nFlask Alpha,1001,10,4,0,0,4,GLOBAL,RESTOCK:4", spreadsheetText, "exports view should build spreadsheet text from rows")

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
    enabled = true,
}, {
    actor = "OfficerOne",
    timestamp = 101,
})

assert.equal(1, #updatedMinimums, "minimum audit upsert should still replace matching rules")
assert.equal(1, #minimumDb.auditLog, "minimum audit upsert should append an audit row")
assert.equal("MINIMUM_UPDATED", minimumDb.auditLog[1].type, "minimum audit upsert should record update events")
assert.equal("8", minimumDb.auditLog[1].oldValue, "minimum audit upsert should store the previous minimum value")
assert.equal("10", minimumDb.auditLog[1].newValue, "minimum audit upsert should store the new minimum value")

local minimumRows = minimumsView.BuildTableRows({
    { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", enabled = true },
    { itemID = 2002, itemName = "Potion Beta", quantity = 4, scope = "GLOBAL", enabled = false },
}, {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
        [3003] = { itemID = 3003, name = "Feast Gamma", totalCount = 2, tabs = { Food = 2 } },
    },
})

assert.equal("Flask Alpha", minimumRows[1].itemName, "enabled minimum rows should sort to the top of the merged table")
assert.equal("Yes", minimumRows[1].restock, "enabled minimum rows should show restock enabled")
assert.equal("10", minimumRows[1].current, "minimum rows should show current bank quantity from the snapshot")
assert.equal("Potion Beta", minimumRows[2].itemName, "saved manual or disabled minimums should stay ahead of raw bank-only rows in the merged table")
assert.equal("No", minimumRows[2].restock, "disabled minimum rows should show restock disabled")
assert.equal("0", minimumRows[2].current, "manual-only minimum rows should show zero current quantity when absent from the bank")
assert.equal("Feast Gamma", minimumRows[3].itemName, "bank items without saved minimums should still appear in the merged minimums table after saved rules")
assert.equal("No", minimumRows[3].restock, "bank-only rows should default to disabled restock")

local defaultMinimumRows = minimumsView.BuildTableRows({
    { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", enabled = true },
    { itemID = 2002, itemName = "Potion Beta", quantity = 4, scope = "GLOBAL", enabled = false },
}, {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
        [3003] = { itemID = 3003, name = "Feast Gamma", totalCount = 2, tabs = { Food = 2 } },
    },
}, {
    showAll = false,
})

assert.equal(1, #defaultMinimumRows, "minimum rows should default to enabled rules only when show-all is off")
assert.equal("Flask Alpha", defaultMinimumRows[1].itemName, "minimum rows should keep enabled entries visible by default")

local filteredMinimumRows = minimumsView.BuildTableRows({
    { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", enabled = true },
    { itemID = 2002, itemName = "Potion Beta", quantity = 4, scope = "GLOBAL", enabled = false },
}, {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
        [3003] = { itemID = 3003, name = "Feast Gamma", totalCount = 2, tabs = { Food = 2 } },
    },
}, {
    showAll = true,
    search = "potion",
    manualOnly = true,
})

assert.equal(1, #filteredMinimumRows, "minimum rows should support combined search and manual-only filters")
assert.equal("Potion Beta", filteredMinimumRows[1].itemName, "minimum row filters should keep matching manual entries")

local target = targetsView.MarkSuggestedFulfilled({
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 12,
    status = "OPEN",
}, 12)

assert.equal("SUGGESTED_FULFILLED", target.status, "targets view should suggest fulfillment when counts meet the target")

local targetDb = {
    oneTimeTargets = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", status = "OPEN" },
    },
    auditLog = {},
}

targetsView.UpsertWithAudit(targetDb, {
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 14,
    scope = "GLOBAL",
    status = "OPEN",
}, {
    actor = "OfficerOne",
    timestamp = 201,
})
targetsView.SetStatusWithAudit(targetDb, {
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 14,
    scope = "GLOBAL",
    status = "OPEN",
}, "CLOSED", {
    actor = "OfficerOne",
    timestamp = 202,
})

assert.equal(2, #targetDb.auditLog, "targets workflows should append audit rows for updates and status changes")
assert.equal("TARGET_UPDATED", targetDb.auditLog[1].type, "targets upsert should audit updates")
assert.equal("TARGET_CLOSED", targetDb.auditLog[2].type, "targets status changes should audit close events")

local targetRows = targetsView.BuildTableRows({
    { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", status = "OPEN" },
    { itemID = 2002, itemName = "Potion Beta", quantity = 4, scope = "GLOBAL", status = "CLOSED" },
}, {
    items = {
        [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 12, tabs = { Flasks = 12 } },
        [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 1, tabs = { Potions = 1 } },
    },
})

assert.equal("Flask Alpha", targetRows[1].itemName, "targets rows should sort actionable open targets to the top")
assert.equal("Suggested", targetRows[1].status, "targets rows should surface suggested fulfillment when bank quantity meets the target")
assert.equal("Closed", targetRows[2].status, "targets rows should preserve explicit closed status")

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

_G.GBankManagerDB = {
    requests = {
        { requestId = "req-1", requester = "MemberOne", itemID = 1001, itemName = "Flask Alpha", quantity = 2, approval = "PENDING", fulfillment = "OPEN", note = "Raid night", createdAt = 10 },
        { requestId = "req-2", requester = "MemberTwo", itemID = 2002, itemName = "Potion Beta", quantity = 1, approval = "APPROVED", fulfillment = "OPEN", note = "", createdAt = 11 },
        { requestId = "req-3", requester = "MemberThree", itemID = 3003, itemName = "Feast Gamma", quantity = 4, approval = "PENDING", fulfillment = "OPEN", note = "Weekend raid", createdAt = 12 },
    },
    auditLog = {},
    minimums = {},
    oneTimeTargets = {},
    snapshots = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("REQUESTS")
assert.truthy(mainFrame.requestActionsPanel:IsShown(), "request controls should show in the requests view")
assert.truthy(not mainFrame.minimumsPanel:IsShown(), "minimum editor should stay hidden outside the minimums view")
assert.truthy(mainFrame.requestCreatePanel:IsShown(), "request create controls should show in the requests view")
assert.equal("req-3", mainFrame.selectedRequestId, "requests view should auto-select the first actionable request")
assert.truthy(mainFrame.requestApproveButton:IsEnabled(), "pending requests should allow approval")
assert.truthy(mainFrame.requestRejectButton:IsEnabled(), "pending requests should allow rejection")
assert.truthy(not mainFrame.requestFulfillButton:IsEnabled(), "pending requests should not allow fulfillment")
assert.truthy(not mainFrame.requestReopenButton:IsEnabled(), "pending requests should not allow reopening")

mainFrame.tableRows[2]:GetScript("OnClick")(mainFrame.tableRows[2])
assert.equal("req-1", mainFrame.selectedRequestId, "clicking a request row should select that saved request")
assert.truthy(mainFrame.requestApproveButton:IsEnabled(), "pending requests should still allow approval after row selection")
assert.truthy(mainFrame.requestRejectButton:IsEnabled(), "pending requests should still allow rejection after row selection")
assert.truthy(not mainFrame.requestFulfillButton:IsEnabled(), "pending requests should not allow fulfillment after row selection")
assert.truthy(not mainFrame.requestReopenButton:IsEnabled(), "pending requests should not allow reopening before fulfillment")

mainFrame.tableRows[3]:GetScript("OnClick")(mainFrame.tableRows[3])
assert.equal("req-2", mainFrame.selectedRequestId, "clicking an approved row should select that saved request")
assert.truthy(not mainFrame.requestApproveButton:IsEnabled(), "approved open requests should not allow re-approval")
assert.truthy(not mainFrame.requestRejectButton:IsEnabled(), "approved open requests should not allow rejection")
assert.truthy(mainFrame.requestFulfillButton:IsEnabled(), "approved open requests should allow fulfillment")
assert.truthy(not mainFrame.requestReopenButton:IsEnabled(), "approved open requests should not allow reopening before fulfillment")

mainFrame:SelectRequestById("req-1")
mainFrame.requestActionNoteInput:SetText("Out of scope")
mainFrame.requestRejectButton:GetScript("OnClick")(mainFrame.requestRejectButton)
assert.equal("REJECTED", ns.state.db.requests[1].approval, "reject button should persist request rejection into the saved db")
assert.equal("Out of scope", ns.state.db.requests[1].decisionNote, "reject button should persist the decision note")

mainFrame:SelectRequestById("req-2")
mainFrame.requestFulfillButton:GetScript("OnClick")(mainFrame.requestFulfillButton)
assert.equal("FULFILLED", ns.state.db.requests[2].fulfillment, "fulfill button should persist request fulfillment into the saved db")
assert.truthy(mainFrame.requestReopenButton:IsEnabled(), "fulfilled requests should allow reopening after mutation refresh")

mainFrame:SelectRequestById("req-2")
mainFrame.requestReopenButton:GetScript("OnClick")(mainFrame.requestReopenButton)
assert.equal("OPEN", ns.state.db.requests[2].fulfillment, "reopen button should persist request reopening into the saved db")

mainFrame:SelectRequestById("req-3")
mainFrame.requestApproveButton:GetScript("OnClick")(mainFrame.requestApproveButton)
assert.equal("APPROVED", ns.state.db.requests[3].approval, "approve button should persist request approval into the saved db")
assert.equal(4, #ns.state.db.auditLog, "request action buttons should append workflow audit rows")

mainFrame:SelectView("REQUESTS")
assert.equal("Feast Gamma", mainFrame.tableRows[1].columns[2]:GetText(), "requests view should refresh from saved state after request actions")
assert.equal("APPROVED", mainFrame.tableRows[1].columns[4]:GetText(), "requests view should show updated approval state after stored mutations")
assert.equal("Potion Beta", mainFrame.tableRows[2].columns[2]:GetText(), "requests view should keep reopened approved requests in the officer queue")

mainFrame.requestCreateRequesterInput:SetText("OfficerOne")
mainFrame.requestCreateRoleInput:SetText("OFFICER")
mainFrame.requestCreateItemIDInput:SetText("4004")
mainFrame.requestCreateItemNameInput:SetText("Rune Delta")
mainFrame.requestCreateQuantityInput:SetText("6")
mainFrame.requestCreateNoteInput:SetText("Emergency stock")
mainFrame.requestCreateButton:GetScript("OnClick")(mainFrame.requestCreateButton)
assert.equal(4, #ns.state.db.requests, "request create button should append a saved request")
assert.equal("APPROVED", ns.state.db.requests[4].approval, "officer-created requests should auto-approve through the stored create flow")
assert.equal("Rune Delta", ns.state.db.requests[4].itemName, "request create button should persist new request item names")
assert.equal("REQUEST_CREATED", ns.state.db.auditLog[5].type, "request create button should append a request-created audit row")

mainFrame:SelectView("REQUESTS")
assert.equal("Potion Beta", mainFrame.tableRows[2].columns[2]:GetText(), "request create flow should preserve approved-row sort order when refreshing")
assert.equal("Rune Delta", mainFrame.tableRows[3].columns[2]:GetText(), "request create flow should refresh the officer queue immediately")

mainFrame:SelectView("HISTORY")
assert.equal("Rejected", mainFrame.tableRows[1].columns[3]:GetText(), "history should refresh to show rejected request audit events")
assert.equal("Request", mainFrame.tableRows[1].columns[1]:GetText(), "history should keep request actions in workflow audit history")

mainFrame.tableFilterInputs[1]:SetText("Request")
mainFrame.tableFilterInputs[4]:SetText("OfficerOne")
mainFrame.tableFilterInputs[2]:SetText("Rune")
assert.equal("Rune Delta", mainFrame.tableRows[1].columns[2]:GetText(), "history filters should narrow rows by category, actor, and item")
assert.equal("", mainFrame.tableRows[2].columns[2]:GetText(), "history filters should hide non-matching audit rows")
mainFrame.tableFilterInputs[1]:SetText("")
mainFrame.tableFilterInputs[4]:SetText("")
mainFrame.tableFilterInputs[2]:SetText("")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "clearing history filters should restore the full audit list")

_G.GBankManagerDB = {
    requests = {},
    auditLog = {},
    currentSnapshotId = "minimum-scan",
    snapshots = {
        ["minimum-scan"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 2, tabs = { Overflow = 2 } },
                [3003] = { itemID = 3003, name = "Feast Gamma", totalCount = 2, tabs = { Food = 2 } },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 8, scope = "GLOBAL", enabled = true },
    },
    oneTimeTargets = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("MINIMUMS")
assert.truthy(mainFrame.minimumsPanel:IsShown(), "minimum editor should show in the minimums view")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request controls should hide outside the requests view")
assert.truthy(not mainFrame.requestCreatePanel:IsShown(), "request create controls should hide outside the requests view")
assert.truthy(mainFrame.minimumShowAllRows == false, "minimums view should default to showing only enabled rows")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[3]:GetText(), "minimums view should sort enabled bank-backed rows to the top")
assert.equal("", mainFrame.tableRows[2].columns[3]:GetText(), "minimums view should hide bank-only rows while show-all is off")
assert.equal("10", mainFrame.tableRows[1].columns[5]:GetText(), "minimums view should show current quantity from the latest snapshot")
assert.equal("Yes", mainFrame.tableRows[1].columns[6]:GetText(), "minimums view should show enabled restock state")
assert.equal("", mainFrame.minimumEmptyStateText:GetText(), "minimums view should not show empty-state copy while rows are visible")

mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
assert.truthy(mainFrame.minimumShowAllRows == true, "minimum show-all toggle should reveal the full bank-backed minimum list")
assert.equal("Feast Gamma", mainFrame.tableRows[2].columns[3]:GetText(), "minimum show-all toggle should reveal bank-only rows")
mainFrame.tableRows[2]:GetScript("OnClick")(mainFrame.tableRows[2])
assert.truthy(mainFrame.tableRows[2].restockToggleButton:IsShown(), "bank-only minimum rows should still be editable directly from show-all mode")
assert.truthy(mainFrame.tableRows[2].minimumValueInput:IsShown(), "bank-only minimum rows should expose direct quantity editing in the row")
assert.truthy(mainFrame.tableRows[2].bankTabValueInput:IsShown(), "bank-only minimum rows should expose direct bank-tab editing in the row")

mainFrame.minimumSearchInput:SetText("feast")
assert.equal("Feast Gamma", mainFrame.tableRows[1].columns[3]:GetText(), "minimum search should narrow the expanded minimum list by item name")
assert.equal("", mainFrame.tableRows[2].columns[3]:GetText(), "minimum search should hide non-matching rows")

mainFrame.minimumSearchInput:SetText("")
mainFrame.minimumManualOnlyToggleButton:GetScript("OnClick")(mainFrame.minimumManualOnlyToggleButton)
assert.truthy(mainFrame.minimumManualOnlyRows == true, "minimum manual-only toggle should switch the tab into manual-only mode")
assert.equal("", mainFrame.tableRows[1].columns[3]:GetText(), "manual-only filter should hide bank-backed rows when no manual rows exist yet")
assert.equal("No manual items match the current minimum filters.", mainFrame.minimumEmptyStateText:GetText(), "manual-only filter should explain why the minimums table is empty")

mainFrame.minimumManualOnlyToggleButton:GetScript("OnClick")(mainFrame.minimumManualOnlyToggleButton)
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
assert.truthy(mainFrame.minimumShowAllRows == false, "minimum show-all toggle should collapse back to the enabled-only view")
assert.truthy(mainFrame.minimumManualOnlyRows == false, "minimum manual-only toggle should return to all-source mode")

mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.tableRows[1].minimumValueInput:IsShown(), "clicking a configured minimum row should edit the minimum in place")
assert.truthy(mainFrame.tableRows[1].restockToggleButton:IsShown(), "clicking a configured minimum row should edit restock in place")
assert.truthy(mainFrame.tableRows[1].bankTabValueInput:IsShown(), "clicking a configured minimum row should edit bank tab in place")
mainFrame.tableRows[1].minimumValueInput:SetText("10")
mainFrame.tableRows[1].bankTabValueInput:SetText("Overflow")
mainFrame.tableRows[1].restockToggleButton:GetScript("OnClick")(mainFrame.tableRows[1].restockToggleButton)
assert.equal(8, ns.state.db.minimums[1].quantity, "minimum edits should stay pending until the minimum save button is clicked")
assert.truthy(ns.state.db.minimums[1].enabled == true, "restock edits should stay pending until the minimum save button is clicked")
assert.equal(nil, ns.state.db.minimums[1].tabName, "bank-tab edits should stay pending until the minimum save button is clicked")

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
assert.truthy(mainFrame.minimumAddModal:IsShown(), "minimum add button should open a clean modal instead of exposing a bottom add-row form")

mainFrame.minimumAddItemIDInput:SetText("2002")
assert.equal("Potion Beta", mainFrame.minimumAddItemNameInput:GetText(), "minimum add modal should resolve and fill item names from item ids")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "adding an item from the modal should close it")
assert.equal(1, #ns.state.db.minimums, "adding an item from the modal should stage the new minimum instead of saving immediately")
assert.equal("Potion Beta", mainFrame.cachedMinimumRows[2].itemName, "the newly staged minimum should appear in the table immediately")
assert.equal(8, ns.state.db.minimums[1].quantity, "drafted row and inline edits should not persist before the minimum save button is clicked")

mainFrame.tableRows[2]:GetScript("OnClick")(mainFrame.tableRows[2])
mainFrame.tableRows[2].bankTabValueInput:SetText("Overflow")
mainFrame.tableRows[2].minimumValueInput:SetText("16")
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(2, #ns.state.db.minimums, "minimum save should persist both edited rows and newly staged rows together")
assert.equal(10, ns.state.db.minimums[1].quantity, "minimum save should persist drafted minimum edits")
assert.truthy(ns.state.db.minimums[1].enabled == false, "minimum save should persist drafted restock edits")
assert.equal("Overflow", ns.state.db.minimums[1].tabName, "minimum save should persist drafted bank-tab edits")
assert.truthy(ns.state.db.minimums[2].enabled == true, "minimum save should persist staged rows for shopping list inclusion")
assert.equal("Overflow", ns.state.db.minimums[2].tabName, "minimum save should persist the required bank tab on newly staged rows")
assert.equal(2, #ns.state.db.auditLog, "minimum save should audit each committed drafted row once")

mainFrame:SelectView("MINIMUMS")
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
mainFrame.minimumManualOnlyToggleButton:GetScript("OnClick")(mainFrame.minimumManualOnlyToggleButton)
assert.equal("", mainFrame.tableRows[1].columns[3]:GetText(), "manual-only filter should hide bank-backed rows when the staged save resolved to tracked snapshot items")
assert.equal("No manual items match the current minimum filters.", mainFrame.minimumEmptyStateText:GetText(), "minimums view should explain when no manual-only rows remain after save")

mainFrame:SelectView("HISTORY")
assert.equal("Minimum", mainFrame.tableRows[1].columns[1]:GetText(), "history should refresh to show minimum workflow audit rows")
assert.equal("Updated", mainFrame.tableRows[1].columns[3]:GetText(), "history should keep earlier minimum workflow actions visible after later mutations")
mainFrame.tableFilterInputs[1]:SetText("Minimum")
mainFrame.tableFilterInputs[4]:SetText("TestPlayer")
mainFrame.tableFilterInputs[2]:SetText("Potion")
assert.equal("Potion Beta", mainFrame.tableRows[1].columns[2]:GetText(), "history filters should also work for minimum audit rows")
assert.equal("Created", mainFrame.tableRows[1].columns[3]:GetText(), "filtered history should show manual minimum creation actions from saved mutations")

_G.GBankManagerDB = {
    requests = {},
    auditLog = {},
    currentSnapshotId = "minimum-highlight",
    snapshots = {
        ["minimum-highlight"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
                [3003] = { itemID = 3003, name = "Feast Gamma", totalCount = 2, tabs = { Food = 2 } },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 8, scope = "GLOBAL", enabled = true },
    },
    oneTimeTargets = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame.minimumSearchInput:SetText("")
mainFrame.minimumShowAllRows = false
mainFrame.minimumManualOnlyRows = false
mainFrame:SelectView("MINIMUMS")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.tableRows[1].isSelected == true, "minimum row selection should visibly mark the selected row")
assert.truthy(mainFrame.tableRows[2].isSelected ~= true, "minimum row selection should leave non-selected rows unmarked")

mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
assert.truthy(mainFrame.tableRows[1].isSelected == true, "minimum row selection should survive refreshes that keep the selected row visible")

mainFrame.minimumSearchInput:SetText("elixir")
assert.truthy(mainFrame.tableRows[1].isSelected ~= true, "minimum row selection should clear from the visible table when filters hide the selected row")
assert.equal("No minimum rows match the current search and filters.", mainFrame.minimumEmptyStateText:GetText(), "minimum search should explain when filters hide every row")

_G.GBankManagerDB = {
    requests = {},
    auditLog = {},
    currentSnapshotId = "minimum-undo",
    snapshots = {
        ["minimum-undo"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 8, scope = "TAB", tabName = "Flasks", enabled = true },
    },
    oneTimeTargets = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame.minimumSearchInput:SetText("")
mainFrame.minimumShowAllRows = false
mainFrame.minimumManualOnlyRows = false
mainFrame:SelectView("MINIMUMS")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
mainFrame.tableRows[1].minimumValueInput:SetText("15")
mainFrame.tableRows[1].bankTabValueInput:SetText("Overflow")
mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
mainFrame.minimumAddItemIDInput:SetText("1001")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.equal(1, #ns.state.db.minimums, "undo scenario should keep staged changes out of saved minimums before save")
mainFrame.minimumSaveAllButton:GetScript("OnClick")(mainFrame.minimumSaveAllButton)
assert.equal(1, #ns.state.db.minimums, "minimum undo should discard staged new rows")
assert.equal(8, ns.state.db.minimums[1].quantity, "minimum undo should restore the original quantity from when the view opened")
assert.equal("Flasks", ns.state.db.minimums[1].tabName, "minimum undo should restore the original bank tab from when the view opened")

_G.GBankManagerDB = {
    currentSnapshotId = "export-scan",
    snapshots = {
        ["export-scan"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 0, tabs = {} },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 14, scope = "GLOBAL", enabled = true },
    },
    oneTimeTargets = {
        { itemID = 2002, itemName = "Potion Beta", quantity = 3, scope = "GLOBAL", status = "OPEN" },
        { itemID = 3003, itemName = "Feast Gamma", quantity = 0, scope = "GLOBAL", status = "OPEN" },
    },
    requests = {
        { requestId = "req-export-1", requester = "MemberOne", itemID = 1001, itemName = "Flask Alpha", quantity = 1, approval = "APPROVED", fulfillment = "OPEN", note = "" },
        { requestId = "req-export-2", requester = "MemberTwo", itemID = 4004, itemName = "Rune Delta", quantity = 2, approval = "PENDING", fulfillment = "OPEN", note = "" },
    },
    auditLog = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
assert.truthy(mainFrame.exportsPanel:IsShown(), "exports controls should show in the exports view")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[1]:GetText(), "exports view should materialize planning-backed item rows")
assert.equal("Potion Beta", mainFrame.tableRows[2].columns[1]:GetText(), "exports view should include one-time target shortages")
assert.equal("", mainFrame.tableRows[3].columns[1]:GetText(), "exports view should hide zero-demand rows")
assert.equal("Spreadsheet", mainFrame.exportsPresetTitle:GetText(), "exports view should default to the spreadsheet preset")
assert.truthy(string.find(mainFrame.exportsOutputText:GetText(), "itemName,itemID,currentQuantity", 1, true) ~= nil, "exports view should generate spreadsheet text by default")

mainFrame.exportPresetAuctionatorButton:GetScript("OnClick")(mainFrame.exportPresetAuctionatorButton)
assert.equal("Auctionator", mainFrame.exportsPresetTitle:GetText(), "auctionator preset button should switch the active export preset")
assert.equal("Flask Alpha x5; Potion Beta x3", mainFrame.exportsOutputText:GetText(), "auctionator preset should use the materialized plan rows")

mainFrame.exportPresetCustomButton:GetScript("OnClick")(mainFrame.exportPresetCustomButton)
assert.equal("Custom", mainFrame.exportsPresetTitle:GetText(), "custom preset button should switch the active export preset")
assert.equal("itemID|itemName|totalToBuy\n1001|Flask Alpha|5\n2002|Potion Beta|3", mainFrame.exportsOutputText:GetText(), "custom preset should use a compact custom-delimited output")
mainFrame.exportDelimiterInput:SetText(";")
mainFrame.exportFieldsInput:SetText("itemName,totalToBuy")
mainFrame.exportHeaderToggleButton:GetScript("OnClick")(mainFrame.exportHeaderToggleButton)
mainFrame.exportApplyCustomButton:GetScript("OnClick")(mainFrame.exportApplyCustomButton)
assert.equal("Flask Alpha;5\nPotion Beta;3", mainFrame.exportsOutputText:GetText(), "custom export controls should regenerate output using officer-selected delimiter, fields, and header setting")
assert.equal("Custom", ns.state.db.ui.exportSettings.selectedPreset, "exports should persist the selected preset in saved ui state")
assert.equal(";", ns.state.db.ui.exportSettings.customTemplate.delimiter, "exports should persist the selected custom delimiter")
assert.equal("itemName,totalToBuy", table.concat(ns.state.db.ui.exportSettings.customTemplate.fields, ","), "exports should persist custom field selection and order")
assert.truthy(ns.state.db.ui.exportSettings.customTemplate.includeHeader == false, "exports should persist header toggle state")

_G.GBankManagerDB = {
    currentSnapshotId = "target-scan",
    snapshots = {
        ["target-scan"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 9, tabs = { Flasks = 9 } },
                [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 5, tabs = { Potions = 5 } },
            },
        },
    },
    minimums = {},
    oneTimeTargets = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", status = "OPEN" },
    },
    requests = {},
    auditLog = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("TARGETS")
assert.truthy(mainFrame.targetsPanel:IsShown(), "targets controls should show in the targets view")
assert.truthy(not mainFrame.minimumsPanel:IsShown(), "minimum controls should hide outside the minimums view")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[2]:GetText(), "targets view should render saved targets in the shared table")
assert.equal("Open", mainFrame.tableRows[1].columns[4]:GetText(), "targets view should show open target status")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.equal("1001", mainFrame.targetItemIDInput:GetText(), "clicking a target row should load its item id into the editor")
assert.equal("Editing saved target.", mainFrame.targetEditorStateText:GetText(), "saved targets should show an editing-state cue")
mainFrame.targetQuantityInput:SetText("14")
mainFrame.targetSaveButton:GetScript("OnClick")(mainFrame.targetSaveButton)
assert.equal(14, ns.state.db.oneTimeTargets[1].quantity, "target save button should persist edited quantities into the saved db")
assert.equal("TARGET_UPDATED", ns.state.db.auditLog[1].type, "target save button should append update audit rows")
mainFrame.targetStatusButton:GetScript("OnClick")(mainFrame.targetStatusButton)
assert.equal("CLOSED", ns.state.db.oneTimeTargets[1].status, "target status button should persist closed state")
assert.equal("TARGET_CLOSED", ns.state.db.auditLog[2].type, "target status button should append close audit rows")
mainFrame.targetNewButton:GetScript("OnClick")(mainFrame.targetNewButton)
assert.equal("Status: Open", mainFrame.targetStatusButton.labelText:GetText(), "new target editor should default to an active procurement state")
mainFrame.targetItemIDInput:SetText("2002")
mainFrame.targetItemNameInput:SetText("Potion Beta")
mainFrame.targetQuantityInput:SetText("4")
mainFrame.targetScopeInput:SetText("GLOBAL")
mainFrame.targetSaveButton:GetScript("OnClick")(mainFrame.targetSaveButton)
assert.equal(2, #ns.state.db.oneTimeTargets, "target save button should create new one-time targets from editor input")
assert.equal("OPEN", ns.state.db.oneTimeTargets[2].status, "new targets should start in an active export state without an extra reopen step")

mainFrame:SelectView("TARGETS")
assert.equal("Potion Beta", mainFrame.tableRows[1].columns[2]:GetText(), "targets view should refresh and sort suggested targets ahead of closed ones")
assert.equal("Suggested", mainFrame.tableRows[1].columns[4]:GetText(), "targets view should surface suggested fulfillment when current stock meets an open target")
assert.equal("Closed", mainFrame.tableRows[2].columns[4]:GetText(), "targets view should keep closed targets visible after refresh")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.equal("Inventory currently meets this target. Close it when the procurement work is done.", mainFrame.targetEditorStateText:GetText(), "suggested targets should explain why they are still open in the editor")

mainFrame:SelectView("HISTORY")
mainFrame.tableFilterInputs[1]:SetText("Target")
mainFrame.tableFilterInputs[2]:SetText("Potion")
assert.equal("Potion Beta", mainFrame.tableRows[1].columns[2]:GetText(), "history should include one-time target audit rows")
assert.equal("Created", mainFrame.tableRows[1].columns[3]:GetText(), "target history should surface target creation actions")

_G.GBankManagerDB = {
    ui = {
        exportSettings = {
            selectedPreset = "Custom",
            customTemplate = {
                delimiter = ";",
                includeHeader = false,
                fields = { "itemName", "totalToBuy" },
            },
        },
    },
    currentSnapshotId = "export-persisted",
    snapshots = {
        ["export-persisted"] = {
            items = {
                [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 10, tabs = { Flasks = 10 } },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 14, scope = "GLOBAL", enabled = true },
    },
    oneTimeTargets = {},
    requests = {},
    auditLog = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
assert.equal("Custom", mainFrame.exportsPresetTitle:GetText(), "exports view should restore the saved preset from ui state on refresh")
assert.equal(";", mainFrame.exportDelimiterInput:GetText(), "exports view should restore the saved custom delimiter")
assert.equal("itemName,totalToBuy", mainFrame.exportFieldsInput:GetText(), "exports view should restore the saved custom field list")
assert.equal("Flask Alpha;4", mainFrame.exportsOutputText:GetText(), "exports view should regenerate output from restored custom settings")

_G.GBankManagerDB = {
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
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("INVENTORY")
assert.truthy(type(mainFrame.tableScrollBar) == "table", "inventory should expose a visible scroll bar")
assert.truthy(type(mainFrame.tableScrollBar.scrollUpButton) == "table", "inventory scroll bar should expose an up button")
assert.truthy(type(mainFrame.tableScrollBar.scrollDownButton) == "table", "inventory scroll bar should expose a down button")
assert.truthy(type(mainFrame.tableScrollBar.thumb) == "table", "inventory scroll bar should expose a draggable thumb")
assert.equal(0, mainFrame.tableScrollOffset, "inventory should start scrolled to the top")
assert.truthy(string.sub(mainFrame.tableRows[1].columns[2]:GetText(), -3) == "...", "inventory should clip long visible name text")
assert.truthy(type(mainFrame.tableColumnResizeHandles[2]) == "table", "inventory should expose a resize handle for user-adjustable columns")
assert.truthy(type(mainFrame.tableRows[1].backdrop) == "table", "inventory rows should render with visible framing")
assert.equal(mainFrame.tableHeaderFrame.height, mainFrame.tableScrollBar.topButtonOffset, "inventory scrollbar should align with the table header")
assert.truthy(mainFrame.tableScrollChild.height <= mainFrame.tableViewportHeight + (mainFrame.tableRowHeight * math.max(0, #mainFrame.tableRowsData - mainFrame.tableVisibleCount)), "inventory table body should stay inside the viewport without a clipped overhang")

mainFrame:ResizeInventoryColumn(2, 40)
assert.equal(278, mainFrame.tableHeaderLabels[2].width, "inventory resize should update the name column width")
assert.equal(40, ns.state.db.ui.inventoryColumnWidths[2], "inventory should persist the user width delta for manual testing")

mainFrame.tableFilterInputs[3]:SetText("Tab 03")
mainFrame:ApplyInventoryFilters()
assert.equal("Item 03", mainFrame.tableRows[1].columns[2]:GetText(), "inventory filters should update the visible rows using the table inputs")

mainFrame.tableFilterInputs[3]:SetText("")
mainFrame:ApplyInventoryFilters()
mainFrame:ScrollTableRows(2)
assert.equal(2, mainFrame.tableScrollOffset, "inventory should track scroll offset")
assert.equal("Item 03", mainFrame.tableRows[1].columns[2]:GetText(), "inventory scrolling should advance visible rows")
assert.truthy((mainFrame.tableScrollBar.thumb.progress or 0) > 0, "inventory scroll thumb should move forward when the table scrolls")

mainFrame.tableHeaderButtons[5]:GetScript("OnClick")(mainFrame.tableHeaderButtons[5])
assert.equal("Item 02", mainFrame.tableRows[1].columns[2]:GetText(), "quantity header click should sort rows from smallest to largest")
assert.equal("Qty ^", mainFrame.tableHeaderLabels[5]:GetText(), "inventory should mark the active quantity sort as ascending")
mainFrame.tableHeaderButtons[5]:GetScript("OnClick")(mainFrame.tableHeaderButtons[5])
assert.equal("48", mainFrame.tableRows[1].columns[5]:GetText(), "second quantity header click should reverse the sort order")
assert.equal("Qty v", mainFrame.tableHeaderLabels[5]:GetText(), "inventory should mark the active quantity sort as descending")

mainFrame.tableHeaderButtons[6]:GetScript("OnClick")(mainFrame.tableHeaderButtons[6])
assert.equal("-", mainFrame.tableRows[1].columns[6]:GetText(), "minimum header click should sort rows from smallest to largest first")
assert.equal("Min ^", mainFrame.tableHeaderLabels[6]:GetText(), "inventory should move the sort marker when a different header becomes active")
mainFrame.tableHeaderButtons[6]:GetScript("OnClick")(mainFrame.tableHeaderButtons[6])
assert.equal("120", mainFrame.tableRows[1].columns[6]:GetText(), "minimum header click should sort rows using the saved minimum value")
assert.equal("Min v", mainFrame.tableHeaderLabels[6]:GetText(), "inventory should mark descending minimum sort in the header")

mainFrame.tableHeaderButtons[2]:GetScript("OnClick")(mainFrame.tableHeaderButtons[2])
assert.equal("Chromatically Tempered Everlasting Flask of the Mountain Sage", mainFrame.cachedInventoryRows[1].name, "name header click should sort inventory rows alphabetically ascending")
assert.equal("Name ^", mainFrame.tableHeaderLabels[2]:GetText(), "name sort should show an ascending marker")
mainFrame.tableHeaderButtons[2]:GetScript("OnClick")(mainFrame.tableHeaderButtons[2])
assert.equal("Item 22", mainFrame.cachedInventoryRows[1].name, "second name header click should reverse alphabetical sort")
assert.equal("Name v", mainFrame.tableHeaderLabels[2]:GetText(), "name sort should show a descending marker")

mainFrame.tableFilterInputs[2]:SetText("Item 1")
mainFrame:ApplyInventoryFilters()
assert.equal("Item 19", mainFrame.cachedInventoryRows[1].name, "name sorting should continue to apply after name text filtering narrows the rows")
mainFrame.tableFilterInputs[2]:SetText("")
mainFrame:ApplyInventoryFilters()

mainFrame.tableHeaderButtons[3]:GetScript("OnClick")(mainFrame.tableHeaderButtons[3])
assert.equal("Emergency Reserves, Experimental Shelf, Flasks, Overflow", mainFrame.cachedInventoryRows[1].tab, "tab header click should sort visible rows by tab label ascending")
assert.equal("Tab ^", mainFrame.tableHeaderLabels[3]:GetText(), "tab sort should show an ascending marker")
mainFrame.tableHeaderButtons[3]:GetScript("OnClick")(mainFrame.tableHeaderButtons[3])
assert.equal("Tab 22", mainFrame.cachedInventoryRows[1].tab, "second tab header click should reverse the tab sort")
assert.equal("Tab v", mainFrame.tableHeaderLabels[3]:GetText(), "tab sort should show a descending marker")

mainFrame.tableFilterInputs[3]:SetText("Tab 0")
mainFrame:ApplyInventoryFilters()
assert.equal("Tab 09", mainFrame.cachedInventoryRows[1].tab, "tab sorting should continue to work after tab text filtering narrows the rows")
mainFrame.tableFilterInputs[3]:SetText("")
mainFrame:ApplyInventoryFilters()

mainFrame.tableHeaderButtons[4]:GetScript("OnClick")(mainFrame.tableHeaderButtons[4])
assert.equal("No", mainFrame.cachedInventoryRows[1].restock, "restock header click should sort rows with non-restock rows first when ascending")
assert.equal("Restock ^", mainFrame.tableHeaderLabels[4]:GetText(), "restock sort should show an ascending marker")
mainFrame.tableHeaderButtons[4]:GetScript("OnClick")(mainFrame.tableHeaderButtons[4])
assert.equal("Yes", mainFrame.cachedInventoryRows[1].restock, "second restock header click should reverse the restock sort")
assert.equal("Restock v", mainFrame.tableHeaderLabels[4]:GetText(), "restock sort should show a descending marker")

mainFrame.tableFilterInputs[4]:SetText("yes")
mainFrame:ApplyInventoryFilters()
assert.equal("Yes", mainFrame.cachedInventoryRows[1].restock, "restock sorting should continue to work after restock text filtering narrows the rows")
mainFrame.tableFilterInputs[4]:SetText("")
mainFrame:ApplyInventoryFilters()

_G.GBankManagerDB = {
    meta = {
        updatedAt = 88,
    },
    currentSnapshotId = "persisted-ui-scan",
    snapshots = {
        ["persisted-ui-scan"] = {
            items = {
                [7777] = {
                    itemID = 7777,
                    name = "Persisted Flask",
                    totalCount = 11,
                    craftedQuality = 5,
                    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier5",
                    tabs = { Vault = 11 },
                },
            },
        },
    },
    minimums = {},
    oneTimeTargets = {},
    requests = {},
    auditLog = {},
    ui = {
        inventoryColumnWidths = {},
        exportSettings = {
            selectedPreset = "Spreadsheet",
            customTemplate = {
                delimiter = "|",
                includeHeader = true,
                fields = { "itemID", "itemName", "totalToBuy" },
            },
        },
    },
}
ns.state.db = {
    currentSnapshotId = "detached-runtime",
    snapshots = {},
}
mainFrame:SelectView("INVENTORY")
assert.same(_G.GBankManagerDB, ns.state.db, "inventory view should rebind to the saved-variables database before rendering")
assert.equal("Persisted Flask", mainFrame.tableRows[1].columns[2]:GetText(), "inventory view should render the saved snapshot after reload instead of detached runtime state")

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

local tabAwareMinimumRows = minimumsView.BuildTableRows({
    { itemID = 5005, itemName = "Potion Rank Two", quantity = 5, scope = "TAB", tabName = "Potions", enabled = true },
    { itemID = 6006, itemName = "Feast Delta", quantity = 7, scope = "TAB", tabName = "Feasts", enabled = true },
}, {
    items = {
        [5005] = {
            itemID = 5005,
            name = "Potion Rank Two",
            craftedQuality = 2,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
            totalCount = 9,
            tabs = {
                Potions = 3,
                Overflow = 6,
            },
        },
        [6006] = {
            itemID = 6006,
            name = "Feast Delta",
            totalCount = 1,
            tabs = {
                Feasts = 1,
            },
        },
    },
})

local tabAwareRowsByName = {}
for _, row in ipairs(tabAwareMinimumRows) do
    tabAwareRowsByName[row.itemName] = row
end

assert.equal("|A:Professions-ChatIcon-Quality-Tier2:22:22|a", tabAwareRowsByName["Potion Rank Two"].tier, "minimum rows should surface crafted quality tier icons")
assert.equal("Potions", tabAwareRowsByName["Potion Rank Two"].bankTab, "minimum rows should show the configured bank tab")
assert.equal("3", tabAwareRowsByName["Potion Rank Two"].current, "minimum rows should use the configured bank-tab quantity instead of the global total")
assert.equal("Overflow", tabAwareRowsByName["Potion Rank Two"].restockFrom, "minimum rows should point to another bank tab before the auction house when stock exists elsewhere")
assert.equal("Auction", tabAwareRowsByName["Feast Delta"].restockFrom, "minimum rows should fall back to the auction house when no other bank tab has stock")

_G.GBankManagerDB = {
    requests = {},
    auditLog = {},
    currentSnapshotId = "minimums-redesign",
    snapshots = {
        ["minimums-redesign"] = {
            items = {
                [5005] = {
                    itemID = 5005,
                    name = "Potion Rank Two",
                    craftedQuality = 2,
                    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
                    totalCount = 9,
                    tabs = {
                        Potions = 3,
                        Overflow = 6,
                    },
                },
                [6006] = {
                    itemID = 6006,
                    name = "Feast Delta",
                    totalCount = 1,
                    tabs = {
                        Feasts = 1,
                    },
                },
            },
        },
    },
    minimums = {
        { itemID = 5005, itemName = "Potion Rank Two", quantity = 5, scope = "TAB", tabName = "Potions", enabled = true },
        { itemID = 6006, itemName = "Feast Delta", quantity = 7, scope = "TAB", tabName = "Feasts", enabled = true },
    },
    oneTimeTargets = {},
    ui = {
        inventoryColumnWidths = {},
        exportSettings = {
            selectedPreset = "Spreadsheet",
            customTemplate = {
                delimiter = "|",
                includeHeader = true,
                fields = { "itemID", "itemName", "totalToBuy" },
            },
        },
        minimumSettings = {
            defaultQuantity = 100,
        },
    },
}
ns.state.db = _G.GBankManagerDB

mainFrame.minimumShowAllRows = true
mainFrame.minimumManualOnlyRows = false
mainFrame.minimumSearchInput:SetText("")
mainFrame:ClearTableFilters()
mainFrame:SelectView("MINIMUMS")
assert.equal("Manage Guild Bank Item Minimum Stock Levels", mainFrame.viewSubtitle:GetText(), "minimums subtitle should explain the stock-level workflow clearly")
assert.equal("Tier", mainFrame.tableHeaderLabels[2]:GetText(), "minimums should add crafting tier as the second column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "minimums should replace the old source column with bank tab")
assert.equal("Restock\nSource", mainFrame.tableHeaderLabels[8]:GetText(), "minimums should rename restock-from to a wrapped restock-source header")
assert.truthy(not mainFrame.tableFilterInputs[5]:IsShown(), "minimums should not expose a text filter for the current column")
assert.truthy(not mainFrame.tableFilterInputs[7]:IsShown(), "minimums should not expose a text filter for the minimum column")
local redesignedMinimumCachedRow = nil
for _, row in ipairs(mainFrame.cachedMinimumRows or {}) do
    if row.itemName == "Potion Rank Two" then
        redesignedMinimumCachedRow = row
        break
    end
end
assert.equal("Overflow", redesignedMinimumCachedRow and redesignedMinimumCachedRow.restockFrom or nil, "minimums table should render restock-from values from row shaping")

local redesignedMinimumRowIndex = nil
for index, rowFrame in ipairs(mainFrame.tableRows) do
    if rowFrame.columns[3]:GetText() == "Potion Rank Two" then
        redesignedMinimumRowIndex = index
        break
    end
end
mainFrame.tableRows[redesignedMinimumRowIndex]:GetScript("OnClick")(mainFrame.tableRows[redesignedMinimumRowIndex])
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput:IsShown(), "minimum rows should expose inline numeric editing when selected for editing")
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].restockToggleButton:IsShown(), "minimum rows should expose inline restock editing when selected for editing")
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].bankTabValueInput:IsShown(), "minimum rows should expose inline bank-tab editing when selected for editing")
assert.equal("5", mainFrame.tableRows[redesignedMinimumRowIndex].columns[7]:GetText(), "minimum rows should keep the minimum value in the same cell position while editing")
assert.equal("Yes", mainFrame.tableRows[redesignedMinimumRowIndex].columns[6]:GetText(), "minimum rows should keep the restock value in the same cell position while editing")
mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput:SetText("8")
mainFrame.tableRows[redesignedMinimumRowIndex].bankTabValueInput:SetText("Overflow")
mainFrame.tableRows[redesignedMinimumRowIndex].restockToggleButton:GetScript("OnClick")(mainFrame.tableRows[redesignedMinimumRowIndex].restockToggleButton)
assert.equal(5, ns.state.db.minimums[1].quantity, "inline row edits should stay pending until the top save button is clicked")
assert.truthy(ns.state.db.minimums[1].enabled == true, "inline restock edits should stay pending until the top save button is clicked")
assert.equal("Potions", ns.state.db.minimums[1].tabName, "inline bank-tab edits should stay pending until the top save button is clicked")

mainFrame:SelectView("OPTIONS")
assert.equal("100", mainFrame.defaultMinimumInput:GetText(), "options should expose the saved default minimum value")
mainFrame.defaultMinimumInput:SetText("250")
mainFrame.defaultMinimumSaveButton:GetScript("OnClick")(mainFrame.defaultMinimumSaveButton)
assert.equal(250, ns.state.db.ui.minimumSettings.defaultQuantity, "options should persist the configured default minimum value")

_G.GBankManagerDB.currentSnapshotId = "minimum-add"
_G.GBankManagerDB.snapshots["minimum-add"] = {
    items = {
        [7007] = {
            itemID = 7007,
            name = "Algari Mana Oil",
            craftedQuality = 1,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
            totalCount = 4,
            tabs = {
                Alchemy = 4,
            },
        },
        [7008] = {
            itemID = 7008,
            name = "Algari Mana Oil",
            craftedQuality = 2,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
            totalCount = 2,
            tabs = {
                Alchemy = 2,
            },
        },
    },
}
_G.GBankManagerDB.minimums = {}
ns.state.db = _G.GBankManagerDB
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.selectedMinimumKey = nil

mainFrame:SelectView("MINIMUMS")
mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
assert.truthy(mainFrame.minimumAddModal:IsShown(), "add should open the minimum modal for the next-phase workflow")
assert.equal("250", mainFrame.minimumAddQuantityInput:GetText(), "new minimum rows should start from the configured default minimum value")
mainFrame.minimumAddItemIDInput:SetText("7007")
assert.equal("Algari Mana Oil", mainFrame.minimumAddItemNameInput:GetText(), "entering an item id should resolve and fill the item name")
mainFrame.minimumAddItemNameInput:SetText("Algari Mana Oil")
assert.truthy(mainFrame.minimumAddMatchButtons[1]:IsShown(), "entering a name with multiple quality variants should offer selectable matches")
mainFrame.minimumAddMatchButtons[2]:GetScript("OnClick")(mainFrame.minimumAddMatchButtons[2])
assert.equal("7008", mainFrame.minimumAddItemIDInput:GetText(), "selecting a quality variant should fill the chosen item id")
assert.equal("Algari Mana Oil", mainFrame.minimumAddItemNameInput:GetText(), "selecting a quality variant should keep the resolved item name")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "adding from the modal should close the modal")
assert.equal(0, #ns.state.db.minimums, "modal add should stage a new minimum instead of saving immediately")
assert.equal("Algari Mana Oil", mainFrame.cachedMinimumRows[1].itemName, "modal add should stage and highlight the new minimum row")
local stagedMinimumRowIndex = nil
for index, rowFrame in ipairs(mainFrame.tableRows) do
    if rowFrame.columns[3]:GetText() == "Algari Mana Oil" then
        stagedMinimumRowIndex = index
        break
    end
end
mainFrame.tableRows[stagedMinimumRowIndex]:GetScript("OnClick")(mainFrame.tableRows[stagedMinimumRowIndex])
mainFrame.tableRows[stagedMinimumRowIndex].bankTabValueInput:SetText("Alchemy")
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(1, #ns.state.db.minimums, "save should persist staged modal rows")
assert.equal("TAB", ns.state.db.minimums[1].scope, "new minimum rows should save as tab-scoped rules")
assert.equal("Alchemy", ns.state.db.minimums[1].tabName, "new minimum rows should require and persist the chosen bank tab")
assert.equal(250, ns.state.db.minimums[1].quantity, "new minimum rows should use the configured default minimum when the user keeps the seeded value")
