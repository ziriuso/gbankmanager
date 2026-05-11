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
