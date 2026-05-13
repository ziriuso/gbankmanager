local assert = require("tests.helpers.assert")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local mainFrame = ns.modules.mainFrame
local dashboard = ns.modules.dashboardView
local inventory = ns.modules.inventoryView
local history = ns.modules.historyView
local exportsView = ns.modules.exportsView
local minimumsView = ns.modules.minimumsView
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
assert.truthy(type(requestsView) == "table", "requests view should load from the toc")
assert.truthy(type(requestDialog) == "table", "request dialog should load from the toc")

assert.equal("DASHBOARD", mainFrame.activeView, "main frame should default to dashboard")
assert.truthy(mainFrame.collapsedSidebar == false, "sidebar should start expanded")
local navKeys = {}
for _, item in ipairs(mainFrame.navItems or {}) do
    navKeys[item.key] = true
end
assert.truthy(navKeys.HISTORY and navKeys.ABOUT, "history and about should remain available after navigation updates")
assert.truthy(not mainFrame:IsShown(), "main frame should start hidden")
assert.truthy(mainFrame.mouseEnabled == false, "main frame should not capture mouse before opening")
assert.equal(920, mainFrame.resizeBounds.minWidth, "main frame should use resize bounds for the minimum width")
assert.equal(560, mainFrame.resizeBounds.minHeight, "main frame should use resize bounds for the minimum height")
assert.equal(1280, mainFrame.resizeBounds.maxWidth, "main frame should use resize bounds for the maximum width")
assert.equal(760, mainFrame.resizeBounds.maxHeight, "main frame should use resize bounds for the maximum height")
assert.truthy(type(mainFrame.backdrop) == "table", "main frame should define a visible backdrop")
assert.equal("GameFontHighlightLarge", mainFrame.titleText.fontObject, "title text should inherit a real WoW font")
assert.equal("GameFontHighlightSmall", mainFrame.subtitleText.fontObject, "subtitle text should inherit a real WoW font")
assert.equal("Guild Bank Management", mainFrame.subtitleText:GetText(), "top-bar subtitle should describe the shell branding rather than a specific view")
assert.equal("GameFontNormal", mainFrame.statusText.fontObject, "status text should inherit a real WoW font")
assert.equal("GameFontNormal", mainFrame.viewTitle.fontObject, "view title should inherit a real WoW font")
assert.equal("LEFT", mainFrame.viewTitle.justifyH, "screen text should be left aligned")
assert.truthy(mainFrame.viewDescriptions.TARGETS == nil, "targets should no longer appear in shell view descriptions")
assert.truthy(not navKeys.TARGETS, "targets should no longer appear in shell navigation")
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
assert.truthy(type(mainFrame.minimumSaveButton) == "table", "main frame should expose a minimum save-all button")
assert.truthy(type(mainFrame.minimumNewButton) == "table", "main frame should expose a minimum new button")
assert.truthy(type(mainFrame.minimumSaveAllButton) == "table", "main frame should still expose the legacy minimum secondary control for compatibility while the view hides global undo")
assert.truthy(type(mainFrame.minimumAddModal) == "table", "main frame should expose a modal for adding new minimum items")
assert.truthy(type(mainFrame.minimumAddItemNameInput) == "table", "main frame should expose a modal minimum item-name input")
assert.truthy(type(mainFrame.minimumAddQuantityInput) == "table", "main frame should expose a modal or staged minimum quantity input")
assert.truthy(type(mainFrame.minimumShowAllToggleButton) == "table", "main frame should expose a minimum show-all toggle button")
assert.truthy(type(mainFrame.minimumSearchInput) == "table", "main frame should expose a minimum search input")
assert.truthy(type(mainFrame.exportDelimiterInput) == "table", "exports panel should expose a custom delimiter input")
assert.truthy(type(mainFrame.exportFieldsInput) == "table", "exports panel should expose a custom fields input")
assert.truthy(type(mainFrame.exportHeaderToggleButton) == "table", "exports panel should expose a custom header toggle button")
assert.truthy(type(mainFrame.exportApplyCustomButton) == "table", "exports panel should expose an apply-custom button")
assert.truthy(type(mainFrame.exportAuctionatorListNameInput) == "table", "exports panel should expose an Auctionator shopping-list name input")
assert.truthy(type(mainFrame.exportModal) == "table", "exports view should expose an export modal")
assert.truthy(type(mainFrame.exportModalScrollFrame) == "table", "export modal should expose a scroll frame for long output")
assert.truthy(type(mainFrame.exportModalOutputInput) == "table", "export modal should expose a copy-friendly output input")
assert.truthy(type(mainFrame.exportModalSelectAllButton) == "table", "export modal should expose a select-all action")
assert.truthy(type(mainFrame.exportModalCopyButton) == "table", "export modal should expose a copy action")
assert.truthy(type(mainFrame.exportModalCloseButton) == "table", "export modal should expose a close action")
assert.truthy(type(mainFrame.optionsAppearancePanel) == "table", "options view should split appearance settings into a dedicated box")
assert.truthy(type(mainFrame.optionsRestockPanel) == "table", "options view should split minimum defaults into a dedicated box")
assert.truthy(type(mainFrame.transparencySlider) == "table", "options panel should expose an opacity slider")
assert.truthy(type(mainFrame.optionsRestockHint) == "table", "options panel should explain the saved minimum setting")
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
assert.equal("Options", mainFrame.viewTitle:GetText(), "options view title should render in title case")

local alphaAfterDown
mainFrame.transparencySlider:SetValue(88)
alphaAfterDown = mainFrame.currentAlpha
assert.truthy(alphaAfterDown < 0.96, "transparency down should reduce alpha")

mainFrame.transparencySlider:SetValue(94)
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
assert.truthy(mainFrame.viewDescriptions.ABOUT ~= nil, "about view should have a description once the tab is enabled")

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
assert.truthy(type(historyRows[1].date) == "string" and historyRows[1].date ~= "", "history should expose a visible timestamp value for audit rows")
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

local removedMinimums = minimumsView.RemoveWithAudit(minimumDb, {
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 10,
    scope = "GLOBAL",
    enabled = true,
}, {
    actor = "OfficerOne",
    timestamp = 102,
})

assert.equal(0, #removedMinimums, "minimum remove should delete the persisted minimum rule")
assert.equal(2, #minimumDb.auditLog, "minimum remove should append an audit row")
assert.equal("MINIMUM_REMOVED", minimumDb.auditLog[2].type, "minimum remove should record removal events")
assert.equal("10", minimumDb.auditLog[2].oldValue, "minimum remove should store the removed quantity as the old value")
assert.equal("REMOVED", minimumDb.auditLog[2].newValue, "minimum remove should store a removed marker as the new value")

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
assert.equal("When", mainFrame.tableHeaderLabels[1]:GetText(), "history should dedicate the first table column to the audit timestamp")
assert.truthy(mainFrame.tableRows[1].columns[1]:GetText() ~= "", "history should render audit timestamps in the shared table shell")
assert.equal("Request", mainFrame.tableRows[1].columns[2]:GetText(), "history should render request audit rows in the shared table shell")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[3]:GetText(), "history should render audit item names")

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
assert.equal("Rejected", mainFrame.tableRows[1].columns[4]:GetText(), "history should refresh to show rejected request audit events")
assert.equal("Request", mainFrame.tableRows[1].columns[2]:GetText(), "history should keep request actions in workflow audit history")

mainFrame.tableFilterInputs[2]:SetText("Request")
mainFrame.tableFilterInputs[5]:SetText("OfficerOne")
mainFrame.tableFilterInputs[3]:SetText("Rune")
assert.equal("Rune Delta", mainFrame.tableRows[1].columns[3]:GetText(), "history filters should narrow rows by category, actor, and item")
assert.equal("", mainFrame.tableRows[2].columns[3]:GetText(), "history filters should hide non-matching audit rows")
mainFrame.tableFilterInputs[2]:SetText("")
mainFrame.tableFilterInputs[5]:SetText("")
mainFrame.tableFilterInputs[3]:SetText("")
assert.equal("Flask Alpha", mainFrame.tableRows[1].columns[3]:GetText(), "clearing history filters should restore the full audit list")

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
assert.truthy(type(mainFrame.minimumSearchLabel) == "table", "minimums should expose a visible label for the search field")
assert.equal("Search", mainFrame.minimumSearchLabel:GetText(), "minimums should label the search field clearly")
assert.truthy(mainFrame.minimumShowAllToggleButton:GetWidth() >= 104, "minimums should widen the show-all toggle so Enabled Only fits without overflow")
assert.same(mainFrame.minimumsPanel, (mainFrame.minimumSearchInput.points[1] or {})[2], "minimums should anchor the search input to the panel instead of chaining it into the show-all button")
assert.same(mainFrame.minimumsPanel, (mainFrame.minimumSearchLabel.points[1] or {})[2], "minimums should anchor the search label to the panel instead of a neighboring control")
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
assert.truthy(type(mainFrame.tableRows[2].bankTabDropdownButton) == "table", "bank-only minimum rows should expose a bank-tab dropdown instead of a freeform input")
assert.truthy(mainFrame.tableRows[2].bankTabDropdownButton:IsShown(), "bank-only minimum rows should show the bank-tab dropdown while selected")
assert.equal("", mainFrame.tableRows[2].columns[4]:GetText(), "bank-only minimum rows should hide underlying bank-tab text while the dropdown is active")
assert.equal("", mainFrame.tableRows[2].columns[6]:GetText(), "bank-only minimum rows should hide underlying restock text while inline editors are active")
assert.equal("", mainFrame.tableRows[2].columns[7]:GetText(), "bank-only minimum rows should hide underlying quantity text while inline editors are active")

mainFrame.minimumSearchInput:SetText("feast")
assert.equal("Feast Gamma", mainFrame.tableRows[1].columns[3]:GetText(), "minimum search should narrow the expanded minimum list by item name")
assert.equal("", mainFrame.tableRows[2].columns[3]:GetText(), "minimum search should hide non-matching rows")

mainFrame.minimumSearchInput:SetText("")
assert.truthy(not mainFrame.minimumManualOnlyToggleButton:IsShown(), "minimums should remove the manual-only toggle from the panel")
assert.truthy(mainFrame.minimumManualOnlyRows == false, "minimums should keep all sources visible once the manual-only filter is removed")
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
assert.truthy(mainFrame.minimumShowAllRows == false, "minimum show-all toggle should collapse back to the enabled-only view")

mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
assert.truthy(mainFrame.tableRows[1].minimumValueInput:IsShown(), "clicking a configured minimum row should edit the minimum in place")
assert.truthy(mainFrame.tableRows[1].restockToggleButton:IsShown(), "clicking a configured minimum row should edit restock in place")
assert.truthy(mainFrame.tableRows[1].bankTabValueInput:IsShown() ~= true, "saved minimum rows should keep bank tab read-only in the table")
assert.truthy(mainFrame.tableRows[1].undoButton:IsShown() ~= true, "clicking a minimum row without edits should not mark it as undoable")
assert.equal("", mainFrame.tableRows[1].columns[6]:GetText(), "configured minimum rows should hide underlying restock text while inline editors are active")
assert.equal("", mainFrame.tableRows[1].columns[7]:GetText(), "configured minimum rows should hide underlying quantity text while inline editors are active")
mainFrame.tableRows[1].minimumValueInput:SetText("10")
mainFrame.tableRows[1].restockToggleButton:GetScript("OnClick")(mainFrame.tableRows[1].restockToggleButton)
assert.equal(8, ns.state.db.minimums[1].quantity, "minimum edits should stay pending until the minimum save button is clicked")
assert.truthy(ns.state.db.minimums[1].enabled == true, "restock edits should stay pending until the minimum save button is clicked")
assert.equal(nil, ns.state.db.minimums[1].tabName, "bank-tab edits should stay pending until the minimum save button is clicked")
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
local flaskAlphaCount = 0
for _, row in ipairs(mainFrame.cachedMinimumRows or {}) do
    if row.itemName == "Flask Alpha" then
        flaskAlphaCount = flaskAlphaCount + 1
    end
end
assert.equal(1, flaskAlphaCount, "minimum draft edits should replace the visible saved row instead of duplicating it when filters refresh")
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
assert.truthy(mainFrame.minimumAddModal:IsShown(), "minimum add button should open a clean modal instead of exposing a bottom add-row form")

mainFrame.minimumAddItemIDInput:SetText("2002")
assert.equal("Potion Beta", mainFrame.minimumAddItemNameInput:GetText(), "minimum add modal should resolve and fill item names from item ids")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "adding an item from the modal should close it")
assert.equal(1, #ns.state.db.minimums, "adding an item from the modal should stage the new minimum instead of saving immediately")
local stagedPotionRow = nil
for _, row in ipairs(mainFrame.cachedMinimumRows or {}) do
    if row.itemName == "Potion Beta" then
        stagedPotionRow = row
        break
    end
end
assert.equal("Potion Beta", stagedPotionRow and stagedPotionRow.itemName or nil, "the newly staged minimum should appear in the table immediately")
assert.equal(8, ns.state.db.minimums[1].quantity, "drafted row and inline edits should not persist before the minimum save button is clicked")

local stagedPotionRowIndex = nil
for index, rowFrame in ipairs(mainFrame.tableRows) do
    if rowFrame.columns[3]:GetText() == "Potion Beta" then
        stagedPotionRowIndex = index
        break
    end
end
mainFrame.tableRows[stagedPotionRowIndex]:GetScript("OnClick")(mainFrame.tableRows[stagedPotionRowIndex])
assert.truthy(type(mainFrame.tableRows[stagedPotionRowIndex].bankTabDropdownButton) == "table", "staged minimum rows should provide a bank-tab dropdown")
local stagedPotionOptionLabels = {}
for _, option in ipairs(mainFrame.tableRows[stagedPotionRowIndex].bankTabDropdownOptions or {}) do
    stagedPotionOptionLabels[#stagedPotionOptionLabels + 1] = option.value or (option.labelText and option.labelText:GetText()) or option:GetText()
end
local stagedPotionHasOverflowOption = false
for _, label in ipairs(stagedPotionOptionLabels) do
    if label == "Overflow" then
        stagedPotionHasOverflowOption = true
        break
    end
end
assert.truthy(stagedPotionHasOverflowOption, "staged minimum rows should offer known guild bank tabs in the dropdown")
mainFrame.tableRows[stagedPotionRowIndex].bankTabDropdownButton:GetScript("OnClick")(mainFrame.tableRows[stagedPotionRowIndex].bankTabDropdownButton)
for _, option in ipairs(mainFrame.tableRows[stagedPotionRowIndex].bankTabDropdownOptions or {}) do
    local label = option.value or (option.labelText and option.labelText:GetText()) or option:GetText()
    if label == "Overflow" then
        option:GetScript("OnClick")(option)
        break
    end
end
mainFrame.tableRows[stagedPotionRowIndex].minimumValueInput:SetText("16")
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(2, #ns.state.db.minimums, "minimum save should persist both edited rows and newly staged rows together")
assert.equal(10, ns.state.db.minimums[1].quantity, "minimum save should persist drafted minimum edits")
assert.truthy(ns.state.db.minimums[1].enabled == false, "minimum save should persist drafted restock edits")
assert.equal(nil, ns.state.db.minimums[1].tabName, "minimum save should keep saved rows on their original bank-tab scope when bank-tab editing is locked")
assert.truthy(ns.state.db.minimums[2].enabled == true, "minimum save should persist staged rows for shopping list inclusion")
assert.equal("Overflow", ns.state.db.minimums[2].tabName, "minimum save should persist the required bank tab on newly staged rows")
assert.equal(2, #ns.state.db.auditLog, "minimum save should audit each committed drafted row once")

mainFrame:SelectView("MINIMUMS")
mainFrame.minimumShowAllToggleButton:GetScript("OnClick")(mainFrame.minimumShowAllToggleButton)
assert.truthy(not mainFrame.minimumManualOnlyToggleButton:IsShown(), "minimums should no longer show a panel-level all-sources toggle after save")
assert.truthy(mainFrame.tableRows[1].columns[3]:GetText() ~= "", "minimums should keep showing tracked rows instead of filtering to manual-only sources")

mainFrame:SelectView("HISTORY")
assert.equal("Minimum", mainFrame.tableRows[1].columns[2]:GetText(), "history should refresh to show minimum workflow audit rows")
assert.equal("Updated", mainFrame.tableRows[1].columns[4]:GetText(), "history should keep earlier minimum workflow actions visible after later mutations")
mainFrame.tableFilterInputs[2]:SetText("Minimum")
mainFrame.tableFilterInputs[5]:SetText("TestPlayer")
mainFrame.tableFilterInputs[3]:SetText("Potion")
assert.equal("Potion Beta", mainFrame.tableRows[1].columns[3]:GetText(), "history filters should also work for minimum audit rows")
assert.equal("Created", mainFrame.tableRows[1].columns[4]:GetText(), "filtered history should show manual minimum creation actions from saved mutations")

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
assert.equal(1, #ns.state.db.minimums, "row undo scenario should keep staged changes out of saved minimums before save")
assert.truthy(type(mainFrame.tableRows[1].undoButton) == "table", "minimum rows should expose a per-row undo control next to delete")
mainFrame.tableRows[1].undoButton:GetScript("OnClick")(mainFrame.tableRows[1].undoButton)
assert.equal(1, #ns.state.db.minimums, "minimum row undo should keep unsaved row edits out of persisted minimums")
assert.equal(8, ns.state.db.minimums[1].quantity, "minimum row undo should restore the original quantity from when the view opened")
assert.equal("Flasks", ns.state.db.minimums[1].tabName, "minimum row undo should restore the original bank tab from when the view opened")

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
assert.equal("CSV", mainFrame.exportPresetSpreadsheetButton.labelText:GetText(), "exports view should rename the spreadsheet preset button to CSV")
assert.truthy(mainFrame.exportsOutputText.shown ~= true, "exports view should retire inline output text in favor of the export modal")
assert.truthy(not mainFrame.exportModal:IsShown(), "exports view should keep the modal hidden until a preset is selected")

mainFrame.exportPresetSpreadsheetButton:GetScript("OnClick")(mainFrame.exportPresetSpreadsheetButton)
assert.truthy(mainFrame.exportModal:IsShown(), "selecting the CSV preset should open the export modal")
assert.equal("CSV", mainFrame.exportsPresetTitle:GetText(), "csv preset should use the visible CSV title in the modal flow")
assert.truthy(string.find(mainFrame.exportModalOutputInput:GetText(), "itemName,itemID,currentQuantity", 1, true) ~= nil, "csv preset should route generated output into the export modal")
assert.truthy(not mainFrame.exportAuctionatorListNameInput:IsShown(), "csv preset should hide the Auctionator shopping-list field")
assert.truthy(not mainFrame.exportDelimiterInput:IsShown(), "csv preset should hide custom delimiter controls")
assert.truthy(not mainFrame.exportFieldsInput:IsShown(), "csv preset should hide custom field controls")
assert.truthy(not mainFrame.exportHeaderToggleButton:IsShown(), "csv preset should hide custom header controls")
assert.truthy(not mainFrame.exportApplyCustomButton:IsShown(), "csv preset should hide custom apply controls")

mainFrame.exportPresetAuctionatorButton:GetScript("OnClick")(mainFrame.exportPresetAuctionatorButton)
assert.equal("Auctionator", mainFrame.exportsPresetTitle:GetText(), "auctionator preset button should switch the active export preset")
assert.truthy(mainFrame.exportAuctionatorListNameInput:IsShown(), "auctionator preset should expose the shopping-list name field")
assert.truthy(not mainFrame.exportDelimiterInput:IsShown(), "auctionator preset should hide custom delimiter controls")
assert.truthy(not mainFrame.exportFieldsInput:IsShown(), "auctionator preset should hide custom field controls")
assert.truthy(not mainFrame.exportHeaderToggleButton:IsShown(), "auctionator preset should hide custom header controls")
assert.truthy(not mainFrame.exportApplyCustomButton:IsShown(), "auctionator preset should hide custom apply controls")
assert.equal("GBankManager", mainFrame.exportAuctionatorListNameInput:GetText(), "auctionator preset should default the shopping-list name reasonably")
assert.equal('GBankManager^"Flask Alpha";0;0;0;0;0;0;0;0;5^"Potion Beta";0;0;0;0;0;0;0;0;3', mainFrame.exportModalOutputInput:GetText(), "auctionator preset should use the approved caret-delimited shopping-list format")
mainFrame.exportAuctionatorListNameInput:SetText("Raid Prep")
assert.equal('Raid Prep^"Flask Alpha";0;0;0;0;0;0;0;0;5^"Potion Beta";0;0;0;0;0;0;0;0;3', mainFrame.exportModalOutputInput:GetText(), "editing the shopping-list name should refresh Auctionator modal output")

mainFrame.exportPresetCustomButton:GetScript("OnClick")(mainFrame.exportPresetCustomButton)
assert.equal("Custom", mainFrame.exportsPresetTitle:GetText(), "custom preset button should switch the active export preset")
assert.truthy(not mainFrame.exportAuctionatorListNameInput:IsShown(), "custom preset should hide the Auctionator shopping-list field")
assert.truthy(mainFrame.exportDelimiterInput:IsShown(), "custom preset should show the custom delimiter control")
assert.truthy(mainFrame.exportFieldsInput:IsShown(), "custom preset should show the custom field control")
assert.truthy(mainFrame.exportHeaderToggleButton:IsShown(), "custom preset should show the custom header control")
assert.truthy(mainFrame.exportApplyCustomButton:IsShown(), "custom preset should show the custom apply control")
assert.equal("itemID|itemName|totalToBuy\n1001|Flask Alpha|5\n2002|Potion Beta|3", mainFrame.exportModalOutputInput:GetText(), "custom preset should route compact custom-delimited output into the modal")
mainFrame.exportDelimiterInput:SetText(";")
mainFrame.exportFieldsInput:SetText("itemName,totalToBuy")
mainFrame.exportHeaderToggleButton:GetScript("OnClick")(mainFrame.exportHeaderToggleButton)
mainFrame.exportApplyCustomButton:GetScript("OnClick")(mainFrame.exportApplyCustomButton)
assert.equal("Flask Alpha;5\nPotion Beta;3", mainFrame.exportModalOutputInput:GetText(), "custom export controls should regenerate modal output using officer-selected delimiter, fields, and header setting")
assert.equal("Custom", ns.state.db.ui.exportSettings.selectedPreset, "exports should persist the selected preset in saved ui state")
assert.equal(";", ns.state.db.ui.exportSettings.customTemplate.delimiter, "exports should persist the selected custom delimiter")
assert.equal("itemName,totalToBuy", table.concat(ns.state.db.ui.exportSettings.customTemplate.fields, ","), "exports should persist custom field selection and order")
assert.truthy(ns.state.db.ui.exportSettings.customTemplate.includeHeader == false, "exports should persist header toggle state")
assert.equal(mainFrame.exportModalScrollChild, mainFrame.exportModalScrollFrame.scrollChild, "export modal should attach its content frame as the scroll child")
assert.truthy(mainFrame.exportModalScrollFrame.mouseWheelEnabled == true, "export modal should enable mouse-wheel scrolling")
assert.truthy(type(mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")) == "function", "export modal should wire a mouse-wheel scrolling handler")
assert.truthy(mainFrame.exportModalOutputInput.multiLine == true, "export modal output should be multiline for long exports")
mainFrame.exportModalSelectAllButton:GetScript("OnClick")(mainFrame.exportModalSelectAllButton)
assert.equal(0, mainFrame.exportModalOutputInput.highlightStart, "select-all should start highlighting from the beginning of the modal output")
assert.equal(-1, mainFrame.exportModalOutputInput.highlightEnd, "select-all should highlight the full modal output")
mainFrame.exportModalCopyButton:GetScript("OnClick")(mainFrame.exportModalCopyButton)
assert.equal(mainFrame.exportModalOutputInput:GetText(), mainFrame.exportModalOutputInput.lastCopiedText, "copy should stage the current modal output text for clipboard copy")
mainFrame.exportModalCloseButton:GetScript("OnClick")(mainFrame.exportModalCloseButton)
assert.truthy(not mainFrame.exportModal:IsShown(), "close should hide the export modal")

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
mainFrame.exportPresetCustomButton:GetScript("OnClick")(mainFrame.exportPresetCustomButton)
assert.equal("Flask Alpha;4", mainFrame.exportModalOutputInput:GetText(), "exports view should regenerate modal output from restored custom settings")

_G.GBankManagerDB = {
    ui = {
        exportSettings = {
            selectedPreset = "Spreadsheet",
            customTemplate = {
                delimiter = "|",
                includeHeader = true,
                fields = { "itemID", "itemName", "totalToBuy" },
            },
        },
    },
    currentSnapshotId = "export-legacy-spreadsheet",
    snapshots = {
        ["export-legacy-spreadsheet"] = {
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
assert.equal("CSV", mainFrame.exportSelectedPreset, "exports view should migrate legacy spreadsheet preset state to CSV on load")

mainFrame:SelectView("EXPORTS")
mainFrame:SelectExportPreset("Custom")
mainFrame.exportModalOutputInput:SetText(table.concat({
    "line 01",
    "line 02",
    "line 03",
    "line 04",
    "line 05",
    "line 06",
    "line 07",
    "line 08",
    "line 09",
    "line 10",
    "line 11",
    "line 12",
}, "\n"))
assert.truthy(mainFrame.exportModalScrollChild:GetHeight() > mainFrame.exportModalScrollFrame:GetHeight(), "export modal should grow scroll content height when output spans many lines")
mainFrame.exportModalScrollFrame:GetScript("OnMouseWheel")(mainFrame.exportModalScrollFrame, -1)
assert.truthy((mainFrame.exportModalScrollFrame.verticalScroll or 0) > 0, "export modal mouse-wheel scrolling should advance the vertical scroll position for long output")

_G.GBankManagerDB = {
    currentSnapshotId = "export-quality-missing-snapshot",
    snapshots = {
        ["export-quality-missing-snapshot"] = {
            items = {},
        },
    },
    minimums = {},
    oneTimeTargets = {
        { itemID = 7008, itemName = "Algari Mana Oil", quantity = 4, scope = "GLOBAL", status = "OPEN", craftedQuality = 2 },
    },
    requests = {},
    auditLog = {},
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("EXPORTS")
mainFrame.exportPresetAuctionatorButton:GetScript("OnClick")(mainFrame.exportPresetAuctionatorButton)
assert.equal('GBankManager^"Algari Mana Oil";0;0;0;0;0;0;0;2;4', mainFrame.exportModalOutputInput:GetText(), "auctionator export should preserve quality-specific rows even when the item is absent from the current snapshot")

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

local originalGetItemInfo = _G.GetItemInfo
_G.GetItemInfo = function(query)
    if query == "Algari Mana Oil" then
        return "Algari Mana Oil", "|cff1eff00|Hitem:9009:::::::::|h[Algari Mana Oil]|h|r"
    end
    if type(originalGetItemInfo) == "function" then
        return originalGetItemInfo(query)
    end
    return nil
end
local mixedMinimumResolution = minimumsView.ResolveItemQuery({
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
    searchCatalog = {
        { itemID = 9009, name = "Algari Mana Oil" },
    },
}, "Algari Mana Oil")
_G.GetItemInfo = originalGetItemInfo
assert.equal("multiple", mixedMinimumResolution.status, "minimum add search should keep multi-match behavior when bank variants exist")
local sawClientResolvedMatch = false
for _, item in ipairs(mixedMinimumResolution.matches or {}) do
    if tonumber(item.itemID) == 9009 then
        sawClientResolvedMatch = true
        break
    end
end
assert.truthy(sawClientResolvedMatch, "minimum add search should keep client-cached item matches available even when bank matches exist")

local catalogMinimumResolution = minimumsView.ResolveItemQuery({
    items = {},
    searchCatalog = {
        { itemID = 9010, name = "Flask of Tempered Swiftness" },
    },
}, "flask")
assert.equal("resolved", catalogMinimumResolution.status, "minimum add search should support non-bank partial-name matches from the local search catalog")
assert.equal(9010, catalogMinimumResolution.item.itemID, "minimum add search should return the catalog-backed item when the guild bank has no match")

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
                [7007] = {
                    itemID = 7007,
                    name = "Rune Oil Extra",
                    totalCount = 4,
                    tabs = {
                        Alchemy = 4,
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
mainFrame.minimumManualOnlyRows = true
mainFrame.minimumSearchInput:SetText("")
mainFrame:ClearTableFilters()
mainFrame:SelectView("MINIMUMS")
assert.equal("Manage Guild Bank Item Minimum Stock Levels", mainFrame.viewSubtitle:GetText(), "minimums subtitle should explain the stock-level workflow clearly")
assert.truthy(not mainFrame.tableFilterFrame:IsShown(), "minimums should hide the shared header filter row to avoid header crowding")
assert.equal("Tier", mainFrame.tableHeaderLabels[2]:GetText(), "minimums should add crafting tier as the second column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[4]:GetText(), "minimums should replace the old source column with bank tab")
assert.equal("", mainFrame.tableHeaderLabels[8]:GetText(), "minimums should hide the restock-source column for now")
assert.truthy(not mainFrame.tableFilterInputs[1]:IsShown(), "minimums should remove the shared header text filters")
assert.truthy(not mainFrame.tableFilterInputs[3]:IsShown(), "minimums should remove the shared header text filters for item columns too")
assert.truthy(not mainFrame.tableFilterInputs[8]:IsShown(), "minimums should remove the shared header text filters for restock source")
assert.truthy(not mainFrame.minimumManualOnlyToggleButton:IsShown(), "minimums should remove the all-sources toggle entirely")
assert.truthy(not mainFrame.minimumSaveAllButton:IsShown(), "minimums should not keep a panel-level undo button once row-level undo exists")
assert.truthy(mainFrame.minimumsTitle.shown == false, "minimums should remove the draft-actions title box")
assert.truthy(mainFrame.minimumEditorStateText.shown == false, "minimums should remove the draft-actions state box")
assert.equal("BOTTOMRIGHT", (mainFrame.minimumShowAllToggleButton.points[1] or {})[1], "minimums should anchor the show-all button under the table")
assert.equal("BOTTOMRIGHT", (mainFrame.minimumShowAllToggleButton.points[1] or {})[3], "minimums should keep the show-all button at the bottom-right edge")
local bottomShowAllRowCount = 0
for _, row in ipairs(mainFrame.cachedMinimumRows or {}) do
    if row.itemName ~= nil and row.itemName ~= "" then
        bottomShowAllRowCount = bottomShowAllRowCount + 1
    end
end
assert.truthy(bottomShowAllRowCount >= 2, "minimums should keep showing configured and bank rows even if an old all-sources flag was left on")
local redesignedMinimumCachedRow = nil
for _, row in ipairs(mainFrame.cachedMinimumRows or {}) do
    if row.itemName == "Potion Rank Two" then
        redesignedMinimumCachedRow = row
        break
    end
end

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
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].bankTabValueInput:IsShown() ~= true, "saved minimum rows should not expose inline bank-tab editing when selected")
assert.truthy(type(mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput:GetScript("OnEditFocusLost")) == "function", "minimum rows should keep pending inline values when the numeric field loses focus")
assert.truthy(type(mainFrame.tableRows[redesignedMinimumRowIndex].removeButton) == "table", "minimum rows should expose an explicit remove control at the far end of existing rows")
assert.truthy(type(mainFrame.tableRows[redesignedMinimumRowIndex].undoButton) == "table", "minimum rows should expose a per-row undo control beside delete")
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].removeButton:IsShown(), "minimum rows should keep the explicit remove control visible for existing enabled rows")
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].undoButton:IsShown() ~= true, "minimum rows should not expose undo until a real edit happens")
assert.equal("", mainFrame.tableRows[redesignedMinimumRowIndex].columns[7]:GetText(), "minimum rows should hide the underlying minimum text while editing")
assert.equal("", mainFrame.tableRows[redesignedMinimumRowIndex].columns[6]:GetText(), "minimum rows should hide the underlying restock text while editing")
assert.equal("", mainFrame.tableRows[redesignedMinimumRowIndex].removeButton.labelText:GetText(), "minimum rows should replace the remove placeholder glyph with an icon-only button")
assert.equal("", mainFrame.tableRows[redesignedMinimumRowIndex].undoButton.labelText:GetText(), "minimum rows should replace the undo placeholder glyph with an icon-only button")
assert.equal("remove", mainFrame.tableRows[redesignedMinimumRowIndex].removeButton.iconKind, "minimum rows should expose a remove icon")
assert.equal("undo", mainFrame.tableRows[redesignedMinimumRowIndex].undoButton.iconKind, "minimum rows should expose an undo icon")
assert.equal("LEFT", (mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput.points[1] or {})[1], "minimum quantity editor should align to the original text baseline instead of dropping lower in the cell")
assert.equal("LEFT", (mainFrame.tableRows[redesignedMinimumRowIndex].restockToggleButton.points[1] or {})[1], "minimum restock editor should align to the original text baseline instead of dropping lower in the cell")
mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput:SetText("8")
mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput:GetScript("OnEditFocusLost")(mainFrame.tableRows[redesignedMinimumRowIndex].minimumValueInput)
assert.equal("changed", mainFrame.tableRows[redesignedMinimumRowIndex].minimumDraftState, "minimum rows should mark edited drafts with a changed state")
assert.equal("yellow", mainFrame.tableRows[redesignedMinimumRowIndex].minimumDraftTint, "minimum rows should tint edited drafts yellow before save")
assert.truthy(type(mainFrame.tableRows[redesignedMinimumRowIndex].minimumDraftIndicator) == "table", "minimum rows should expose a dedicated draft indicator for stronger live-client highlighting")
assert.truthy(mainFrame.tableRows[redesignedMinimumRowIndex].minimumDraftIndicator:IsShown(), "minimum rows should keep the draft indicator visible once a row is dirty")
assert.equal(0.34, (mainFrame.tableRows[redesignedMinimumRowIndex].backdropColor or {})[1], "minimum rows should show a visible changed-row highlight tint in the live row frame")
assert.equal(0.31, (mainFrame.tableRows[redesignedMinimumRowIndex].backdropColor or {})[2], "minimum rows should show a visible changed-row highlight tint in the live row frame")
assert.equal(0.12, (mainFrame.tableRows[redesignedMinimumRowIndex].backdropColor or {})[3], "minimum rows should show a visible changed-row highlight tint in the live row frame")
assert.equal(0.98, (mainFrame.tableRows[redesignedMinimumRowIndex].backdropColor or {})[4], "minimum rows should show a visible changed-row highlight tint in the live row frame")
assert.equal(5, ns.state.db.minimums[1].quantity, "inline row edits should stay pending until the top save button is clicked")
assert.truthy(ns.state.db.minimums[1].enabled == true, "inline restock edits should stay pending until the top save button is clicked")
assert.equal("Potions", ns.state.db.minimums[1].tabName, "inline bank-tab edits should stay pending until the top save button is clicked")
local deletedMinimumRowIndex = nil
for index, rowFrame in ipairs(mainFrame.tableRows) do
    if rowFrame.columns[3]:GetText() == "Feast Delta" then
        deletedMinimumRowIndex = index
        break
    end
end
mainFrame.tableRows[deletedMinimumRowIndex]:GetScript("OnClick")(mainFrame.tableRows[deletedMinimumRowIndex])
assert.equal("8", mainFrame.tableRows[redesignedMinimumRowIndex].columns[7]:GetText(), "minimum rows should keep pending inline values visible after focus moves to another row")
assert.equal("Potions", mainFrame.tableRows[redesignedMinimumRowIndex].columns[4]:GetText(), "minimum rows should keep the saved bank tab visible after row focus changes")
mainFrame.tableRows[deletedMinimumRowIndex].removeButton:GetScript("OnClick")(mainFrame.tableRows[deletedMinimumRowIndex].removeButton)
assert.equal("deleted", mainFrame.tableRows[deletedMinimumRowIndex].minimumDraftState, "minimum rows should mark explicit removes as deleted drafts")
assert.equal("red", mainFrame.tableRows[deletedMinimumRowIndex].minimumDraftTint, "minimum rows should tint deleted drafts red before save")
assert.equal(0.34, (mainFrame.tableRows[deletedMinimumRowIndex].backdropColor or {})[1], "minimum rows should show a visible deleted-row highlight tint in the live row frame")
assert.equal(0.14, (mainFrame.tableRows[deletedMinimumRowIndex].backdropColor or {})[2], "minimum rows should show a visible deleted-row highlight tint in the live row frame")
assert.equal(0.14, (mainFrame.tableRows[deletedMinimumRowIndex].backdropColor or {})[3], "minimum rows should show a visible deleted-row highlight tint in the live row frame")
assert.equal(0.98, (mainFrame.tableRows[deletedMinimumRowIndex].backdropColor or {})[4], "minimum rows should show a visible deleted-row highlight tint in the live row frame")
assert.equal(2, #ns.state.db.minimums, "minimum remove should stay pending until save is clicked")
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(1, #ns.state.db.minimums, "minimum save should commit edited rows and explicit removals together")
assert.equal(8, ns.state.db.minimums[1].quantity, "minimum save should persist inline row quantity edits")
assert.equal("Potions", ns.state.db.minimums[1].tabName, "minimum save should keep saved rows on their configured bank tab after inline edits")
assert.equal(2, #ns.state.db.auditLog, "minimum save should write audit rows for changed and removed minimums")
local savedMinimumAuditTypes = {
    ns.state.db.auditLog[1].type,
    ns.state.db.auditLog[2].type,
}
table.sort(savedMinimumAuditTypes)
assert.equal("MINIMUM_REMOVED", savedMinimumAuditTypes[1], "minimum save should add removal audit rows for explicit deletes")
assert.equal("MINIMUM_UPDATED", savedMinimumAuditTypes[2], "minimum save should keep update audit rows for edited minimums")
mainFrame.tableRows[1]:GetScript("OnClick")(mainFrame.tableRows[1])
mainFrame.tableRows[1].minimumValueInput:SetText("0")
mainFrame.tableRows[1].restockToggleButton:GetScript("OnClick")(mainFrame.tableRows[1].restockToggleButton)
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(1, #ns.state.db.minimums, "minimum zeroing should not silently remove rows without using the explicit remove control")
assert.equal(0, ns.state.db.minimums[1].quantity, "minimum zeroing should persist the edited quantity instead of deleting the rule")
assert.truthy(ns.state.db.minimums[1].enabled == false, "minimum zeroing should not keep a zeroed row active after save")

mainFrame:SelectView("OPTIONS")
assert.equal("100", mainFrame.defaultMinimumInput:GetText(), "options should expose the saved default minimum value")
assert.equal("Opacity 94%", mainFrame.transparencyValueText:GetText(), "options should keep the shell opacity percentage visible after slider changes")
assert.equal("Save Min stores the maximum amount allowed for restock when new rows are staged.", mainFrame.optionsRestockHint:GetText(), "options should explain the saved minimum behavior in the split restock panel")
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
assert.equal("FULLSCREEN_DIALOG", mainFrame.minimumAddModal.frameStrata, "minimum add modal should render above the shared table and controls")
assert.equal("250", mainFrame.minimumAddQuantityInput:GetText(), "new minimum rows should start from the configured default minimum value")
assert.truthy(mainFrame.minimumAddModal:GetWidth() >= 480, "minimum add modal should widen to prevent field overflow")
assert.truthy(mainFrame.minimumAddModal:GetHeight() >= 280, "minimum add modal should grow taller to prevent hint and results overflow")
assert.truthy(type(mainFrame.minimumAddItemIDLabel) == "table", "minimum add modal should label the item-id field clearly")
assert.equal("Item ID", mainFrame.minimumAddItemIDLabel:GetText(), "minimum add modal should use a clearer item-id label")
assert.truthy(type(mainFrame.minimumAddItemNameLabel) == "table", "minimum add modal should label the item-name field clearly")
assert.equal("Item Name", mainFrame.minimumAddItemNameLabel:GetText(), "minimum add modal should use a clearer item-name label")
assert.truthy(type(mainFrame.minimumAddQuantityLabel) == "table", "minimum add modal should label the quantity field clearly")
assert.equal("Minimum", mainFrame.minimumAddQuantityLabel:GetText(), "minimum add modal should use a clearer minimum label")
assert.truthy(type(mainFrame.minimumAddResultsLabel) == "table", "minimum add modal should label the search results list clearly")
assert.equal("Matches", mainFrame.minimumAddResultsLabel:GetText(), "minimum add modal should expose a results label instead of unlabeled match buttons")
assert.truthy(type(mainFrame.minimumAddResultsPanel) == "table", "minimum add modal should render a dedicated results list panel")
assert.truthy(not mainFrame.minimumAddResultsPanel:IsShown(), "minimum add modal should keep the results list hidden until there are matches")
assert.equal((mainFrame.minimumAddItemIDInput.points[1] or {})[5], (mainFrame.minimumAddItemNameInput.points[1] or {})[5], "minimum add modal should keep the Item ID and Item Name inputs aligned on the same row")
assert.equal((mainFrame.minimumAddItemNameInput.points[1] or {})[5], (mainFrame.minimumAddQuantityInput.points[1] or {})[5], "minimum add modal should keep the Item Name and Minimum inputs aligned on the same row")
local originalGetItemInfo = _G.GetItemInfo
_G.GetItemInfo = function(query)
    if tonumber(query) == 9009 or query == "Deepstone Serum" then
        return "Deepstone Serum", "|cff1eff00|Hitem:9009:::::::::|h[Deepstone Serum]|h|r"
    end
    if query == "Algari Mana Oil" then
        return "Algari Mana Oil", "|cff1eff00|Hitem:9009:::::::::|h[Algari Mana Oil]|h|r"
    end
    if type(originalGetItemInfo) == "function" then
        return originalGetItemInfo(query)
    end
    return nil
end
mainFrame.minimumAddItemIDInput:SetText("9009")
assert.equal("Deepstone Serum", mainFrame.minimumAddItemNameInput:GetText(), "entering an item id should resolve from the WoW item database even when the item is not in the current snapshot")
mainFrame.minimumAddItemIDInput:SetText("")
mainFrame.minimumAddItemNameInput:SetText("Deepstone Serum")
assert.equal("9009", mainFrame.minimumAddItemIDInput:GetText(), "entering an item name should resolve from the WoW item database even when the item is not in the current snapshot")
_G.GetItemInfo = originalGetItemInfo
mainFrame.minimumAddItemIDInput:SetText("7007")
assert.equal("Algari Mana Oil", mainFrame.minimumAddItemNameInput:GetText(), "entering an item id should resolve and fill the item name")
mainFrame.minimumAddItemNameInput:SetText("Algari Mana Oil")
assert.truthy(mainFrame.minimumAddResultsPanel:IsShown(), "entering a name with multiple quality variants should show a clean results list")
assert.truthy(mainFrame.minimumAddMatchButtons[1]:IsShown(), "entering a name with multiple quality variants should offer selectable matches")
assert.equal("TOPLEFT", (mainFrame.minimumAddMatchButtons[2].points[1] or {})[1], "minimum add matches should stack vertically inside the results list")
assert.same(mainFrame.minimumAddResultsPanel, (mainFrame.minimumAddMatchButtons[2].points[1] or {})[2], "minimum add matches should anchor to the results list instead of scattering across the form")
mainFrame.minimumAddMatchButtons[2]:GetScript("OnClick")(mainFrame.minimumAddMatchButtons[2])
assert.equal("7008", mainFrame.minimumAddItemIDInput:GetText(), "selecting a quality variant should fill the chosen item id")
assert.equal("Algari Mana Oil", mainFrame.minimumAddItemNameInput:GetText(), "selecting a quality variant should keep the resolved item name")
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
assert.truthy(not mainFrame.minimumAddModal:IsShown(), "adding from the modal should close the modal")
assert.equal(0, #ns.state.db.minimums, "modal add should stage a new minimum instead of saving immediately")
assert.equal("Algari Mana Oil", mainFrame.cachedMinimumRows[1].itemName, "modal add should stage and highlight the new minimum row")
assert.equal("added", mainFrame.tableRows[1].minimumDraftState, "minimum rows should mark staged adds with an added state")
assert.equal("green", mainFrame.tableRows[1].minimumDraftTint, "minimum rows should tint staged adds green before save")
assert.equal(0.16, (mainFrame.tableRows[1].backdropColor or {})[1], "minimum rows should show a visible added-row highlight tint in the live row frame")
assert.equal(0.30, (mainFrame.tableRows[1].backdropColor or {})[2], "minimum rows should show a visible added-row highlight tint in the live row frame")
assert.equal(0.18, (mainFrame.tableRows[1].backdropColor or {})[3], "minimum rows should show a visible added-row highlight tint in the live row frame")
assert.equal(0.98, (mainFrame.tableRows[1].backdropColor or {})[4], "minimum rows should show a visible added-row highlight tint in the live row frame")
assert.truthy(type(mainFrame.tableRows[1].undoButton) == "table", "staged minimum rows should expose the per-row undo control")
mainFrame.tableRows[1].undoButton:GetScript("OnClick")(mainFrame.tableRows[1].undoButton)
assert.equal(0, #ns.state.db.minimums, "minimum row undo should discard staged add rows before save")
assert.truthy(mainFrame.tableRows[1].minimumDraftState ~= "added", "minimum row undo should remove the staged-add draft state from the table")
mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
mainFrame.minimumAddItemIDInput:SetText("7007")
mainFrame.minimumAddItemNameInput:SetText("Algari Mana Oil")
mainFrame.minimumAddMatchButtons[2]:GetScript("OnClick")(mainFrame.minimumAddMatchButtons[2])
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
local stagedMinimumRowIndex = nil
for index, rowFrame in ipairs(mainFrame.tableRows) do
    if rowFrame.columns[3]:GetText() == "Algari Mana Oil" then
        stagedMinimumRowIndex = index
        break
    end
end
mainFrame.tableRows[stagedMinimumRowIndex]:GetScript("OnClick")(mainFrame.tableRows[stagedMinimumRowIndex])
assert.truthy(type(mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownButton) == "table", "modal-staged minimum rows should expose a bank-tab dropdown")
assert.equal("", mainFrame.tableRows[stagedMinimumRowIndex].columns[4]:GetText(), "modal-staged minimum rows should hide underlying bank-tab text while the dropdown is active")
assert.truthy(mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownButton:GetWidth() >= 96, "modal-staged minimum rows should keep the bank-tab dropdown wide enough to remain visible")
assert.equal("Select Bank Tab", mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownButton.labelText:GetText(), "modal-staged minimum rows should use a clearer bank-tab dropdown label before selection")
mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownButton:GetScript("OnClick")(mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownButton)
for _, option in ipairs(mainFrame.tableRows[stagedMinimumRowIndex].bankTabDropdownOptions or {}) do
    local label = option.value or (option.labelText and option.labelText:GetText()) or option:GetText()
    if label == "Alchemy" then
        option:GetScript("OnClick")(option)
        break
    end
end
mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
assert.equal(1, #ns.state.db.minimums, "save should persist staged modal rows")
assert.equal("TAB", ns.state.db.minimums[1].scope, "new minimum rows should save as tab-scoped rules")
assert.equal("Alchemy", ns.state.db.minimums[1].tabName, "new minimum rows should require and persist the chosen bank tab")
assert.equal(250, ns.state.db.minimums[1].quantity, "new minimum rows should use the configured default minimum when the user keeps the seeded value")

_G.GBankManagerDB = {
    requests = {},
    currentSnapshotId = "history-shell-audit",
    snapshots = {
        ["history-shell-audit"] = {
            items = {},
        },
    },
    minimums = {},
    oneTimeTargets = {},
    auditLog = {
        { type = "OPTIONS_CHANGED", actor = "TestPlayer", category = "OPTIONS", itemName = "Window Opacity", oldValue = "94", newValue = "88", timestamp = 100 },
        { type = "MINIMUM_UPDATED", actor = "TestPlayer", category = "MINIMUM", itemName = "Potion Rank Two", oldValue = "5", newValue = "8", timestamp = 101 },
        { type = "REQUEST_APPROVED", actor = "GuildLead", category = "REQUEST", itemName = "Raid Flask", oldValue = "PENDING", newValue = "APPROVED", timestamp = 102 },
    },
}
ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("HISTORY")
local visibleHistoryCategories = {
    mainFrame.tableRows[1].columns[2]:GetText(),
    mainFrame.tableRows[2].columns[2]:GetText(),
}
table.sort(visibleHistoryCategories)
assert.equal("Minimum", visibleHistoryCategories[1], "history should keep minimum audit categories visible")
assert.equal("Request", visibleHistoryCategories[2], "history should keep request audit categories visible")
assert.equal("", mainFrame.tableRows[3].columns[2]:GetText(), "history should keep shell-only audit rows out of the procurement history table")

mainFrame:SelectView("ABOUT")
assert.equal("ABOUT", mainFrame.activeView, "about should be selectable from the shell")
assert.equal("About", mainFrame.viewTitle:GetText(), "about view title should render in title case")
assert.truthy(mainFrame.contentBodyText.shown == true, "about should render body copy in the shared shell content area")
assert.truthy(string.find(mainFrame.contentBodyText:GetText(), "Author: Zirleficent", 1, true) ~= nil, "about should list the addon author")
assert.truthy(string.find(mainFrame.contentBodyText:GetText(), "Server: Stormrage", 1, true) ~= nil, "about should list the home server")
assert.truthy(string.find(mainFrame.contentBodyText:GetText(), "Guild: Tyrrish Rebellion", 1, true) ~= nil, "about should list the guild")
assert.truthy(string.find(mainFrame.contentBodyText:GetText(), "Build: ", 1, true) ~= nil, "about should list the runtime build stamp")
assert.truthy(string.find(mainFrame.contentBodyText:GetText(), "Support:", 1, true) ~= nil, "about should include support placeholder copy")
assert.truthy(string.match(mainFrame.contentBodyText:GetText(), "Build: %d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%d%d") ~= nil, "about should format the build stamp as YYYY-MM-DD-HHMMSS")
