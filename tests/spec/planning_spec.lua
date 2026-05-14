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

local disabledMinimumPlan = planning.BuildDemandPlan({
    snapshot = {
        items = {
            [3003] = {
                itemID = 3003,
                name = "Feast Gamma",
                totalCount = 1,
                tabs = {
                    Food = 1,
                },
            },
        },
    },
    minimums = {
        { itemID = 3003, itemName = "Feast Gamma", quantity = 15, scope = "GLOBAL", enabled = false },
        { itemID = 4004, itemName = "Rune Delta", quantity = 7, scope = "GLOBAL", enabled = true },
    },
    oneTimeTargets = {},
    requests = {},
})

assert.truthy(disabledMinimumPlan[3003] == nil, "disabled minimum rules should not contribute to planning demand")
assert.equal(7, disabledMinimumPlan[4004].sources.RESTOCK, "enabled minimum rules should still contribute to planning demand")

local databasePlan, databaseSnapshot = planning.BuildDemandPlanFromDatabase({
    currentSnapshotId = "scan-1",
    snapshots = {
        ["scan-1"] = {
            items = {
                [5005] = {
                    itemID = 5005,
                    name = "Oil Epsilon",
                    totalCount = 1,
                    tabs = {
                        Oils = 1,
                    },
                },
            },
        },
    },
    minimums = {
        { itemID = 5005, itemName = "Oil Epsilon", quantity = 3, scope = "GLOBAL" },
    },
    oneTimeTargets = {},
    requests = {},
})

assert.equal(2, databasePlan[5005].totalToBuy, "database planning should derive shortages from persisted snapshots and rules")
assert.equal(1, databaseSnapshot.items[5005].totalCount, "database planning should return the snapshot used to build the plan")
