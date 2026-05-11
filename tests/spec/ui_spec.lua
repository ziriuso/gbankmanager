local assert = require("tests.helpers.assert")

local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local mainFrame = ns.modules.mainFrame
local dashboard = ns.modules.dashboardView
local inventory = ns.modules.inventoryView
local history = ns.modules.historyView
local exportsView = ns.modules.exportsView
local slash = ns.modules.slash

assert.truthy(type(mainFrame) == "table", "main frame should load from the toc")
assert.truthy(type(dashboard) == "table", "dashboard view should load from the toc")
assert.truthy(type(inventory) == "table", "inventory view should load from the toc")
assert.truthy(type(history) == "table", "history view should load from the toc")
assert.truthy(type(exportsView) == "table", "exports view should load from the toc")

assert.equal("DASHBOARD", mainFrame.activeView, "main frame should default to dashboard")
assert.truthy(mainFrame.collapsedSidebar == false, "sidebar should start expanded")

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "slash ui command should show the main frame")

mainFrame:ToggleSidebar()
assert.truthy(mainFrame.collapsedSidebar == true, "toggle should collapse the sidebar")

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
