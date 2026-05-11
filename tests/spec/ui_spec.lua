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
assert.equal(7, #mainFrame.navItems, "task 6 should extend sidebar navigation")

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
