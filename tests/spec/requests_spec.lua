local assert = require("tests.helpers.assert")
local requests = dofile("GBankManager/Domain/Requests.lua")

local memberRequest = requests.Create({
    role = "MEMBER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("PENDING", memberRequest.approval, "member requests should start pending")

local officerRequest = requests.Create({
    role = "OFFICER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("APPROVED", officerRequest.approval, "officer requests should auto-approve")
