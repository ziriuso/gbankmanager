local assert = require("tests.helpers.assert")
local requests = dofile("GBankManager/Domain/Requests.lua")

local memberRequest = requests.Create({
    requester = "MemberOne",
    role = "MEMBER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
    note = "Need for alt raid",
})

assert.equal("PENDING", memberRequest.approval, "member requests should start pending")
assert.equal("OPEN", memberRequest.fulfillment, "new requests should start open")
assert.equal("MemberOne", memberRequest.requester, "requester should be stored")
assert.equal("Need for alt raid", memberRequest.note, "request note should be preserved")

local officerRequest = requests.Create({
    requester = "OfficerOne",
    role = "OFFICER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("APPROVED", officerRequest.approval, "officer requests should auto-approve")
assert.equal(0, officerRequest.createdAt, "requests should store creation timestamp")

local approvedRequest = requests.Approve(memberRequest, "GuildLead", 55)
assert.equal("APPROVED", approvedRequest.approval, "approve should transition the request")
assert.equal("GuildLead", approvedRequest.approvedBy, "approve should store approver identity")
assert.equal(55, approvedRequest.decidedAt, "approve should store decision timestamp")

local fulfilledRequest = requests.MarkSuggestedFulfilled(approvedRequest, 99)
assert.equal("SUGGESTED_FULFILLED", fulfilledRequest.fulfillment, "requests should support suggested fulfillment")
assert.equal(99, fulfilledRequest.fulfillmentUpdatedAt, "fulfillment updates should track timestamps")

local reopenedRequest = requests.Reopen(fulfilledRequest, 123)
assert.equal("OPEN", reopenedRequest.fulfillment, "reopen should restore open fulfillment state")
assert.equal(123, reopenedRequest.fulfillmentUpdatedAt, "reopen should update fulfillment timestamp")
