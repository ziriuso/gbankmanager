local assert = require("tests.helpers.assert")
local planning = dofile("GBankManager/Domain/Planning.lua")

local plan = planning.BuildDemandPlan({
    snapshot = {
        items = {
            [1001] = {
                itemID = 1001,
                name = "Flask Alpha",
                totalCount = 6,
                tabs = {
                    Flasks = 6,
                },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 10, scope = "GLOBAL" },
    },
    oneTimeTargets = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 12, scope = "GLOBAL", status = "OPEN" },
    },
    requests = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 2, approval = "APPROVED", fulfillment = "OPEN" },
    },
})

assert.equal(12, plan[1001].totalToBuy, "plan should merge minimums, targets, and requests")
assert.equal(4, plan[1001].sources.RESTOCK, "restock shortage should be included")
assert.equal(6, plan[1001].sources.ONE_TIME_TARGET, "one-time target gap should be included")
assert.equal(2, plan[1001].sources.REQUEST, "approved request should be included")

local scopedPlan = planning.BuildDemandPlan({
    snapshot = {
        items = {
            [1001] = {
                itemID = 1001,
                name = "Flask Alpha",
                totalCount = 12,
                tabs = {
                    Flasks = 8,
                    Potions = 4,
                },
            },
        },
    },
    minimums = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 10, scope = "TAB", tabName = "Flasks" },
    },
    oneTimeTargets = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 6, scope = "TAB", tabName = "Potions", status = "OPEN" },
        { itemID = 1001, itemName = "Flask Alpha", quantity = 20, scope = "GLOBAL", status = "CLOSED" },
    },
    requests = {
        { itemID = 1001, itemName = "Flask Alpha", quantity = 1, approval = "APPROVED", fulfillment = "OPEN", note = "Raid night" },
        { itemID = 1001, itemName = "Flask Alpha", quantity = 3, approval = "PENDING", fulfillment = "OPEN" },
    },
})

assert.equal(5, scopedPlan[1001].totalToBuy, "scoped planning should ignore inactive demand and respect tab counts")
assert.equal(2, scopedPlan[1001].sources.RESTOCK, "tab-scoped minimum should use the tab quantity")
assert.equal(2, scopedPlan[1001].sources.ONE_TIME_TARGET, "tab-scoped target should use the tab quantity")
assert.equal(1, scopedPlan[1001].sources.REQUEST, "only approved open requests should contribute demand")
assert.equal(3, #scopedPlan[1001].details, "plan should keep drill-down attribution details")
assert.equal("TAB", scopedPlan[1001].details[1].scope, "detail rows should preserve scope")
assert.equal("Raid night", scopedPlan[1001].details[3].note, "request details should preserve notes")
