local assert = require("tests.helpers.assert")
local requests = dofile("GBankManager/Domain/Requests.lua")

local memberRequest = requests.Create({
    actorContext = {
        characterKey = "Stormrage-MemberOne",
        name = "MemberOne",
        guildRankName = "Member",
        guildRankIndex = 4,
        isGuildMaster = false,
        inGuild = true,
    },
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
    note = "Need for alt raid",
})

assert.equal("PENDING", memberRequest.approval, "member requests should start pending")
assert.equal("OPEN", memberRequest.fulfillment, "new requests should start open")
assert.equal("MemberOne", memberRequest.requester, "requester should be stored")
assert.equal("Stormrage-MemberOne", memberRequest.requesterCharacterKey, "requests should store the full requester character key")
assert.equal(4, memberRequest.requesterRankIndex, "requests should store the live requester rank index")
assert.equal("Need for alt raid", memberRequest.note, "request note should be preserved")

local officerRequest = requests.Create({
    actorContext = {
        characterKey = "Stormrage-OfficerOne",
        name = "OfficerOne",
        guildRankName = "Officer",
        guildRankIndex = 1,
        isGuildMaster = false,
        inGuild = true,
    },
    auth = {
        capabilities = {
            request_submit = {},
            request_approve = { [1] = true },
            request_reject = { [1] = true },
            request_edit = { [1] = true },
            request_fulfill = { [1] = true },
            request_reopen = { [1] = true },
            full_ui = { [1] = true },
            minimum_add = { [1] = true },
            minimum_edit = { [1] = true },
            minimum_delete = { [1] = true },
            auth_manage = {},
        },
        blacklist = {},
    },
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

local rejectedRequest = requests.Reject(memberRequest, "GuildLead", "Out of scope", 77)
assert.equal("REJECTED", rejectedRequest.approval, "reject should transition the request")
assert.equal("GuildLead", rejectedRequest.decidedBy, "reject should store actor identity")
assert.equal("Out of scope", rejectedRequest.decisionNote, "reject should preserve the decision note")
assert.equal(77, rejectedRequest.decidedAt, "reject should store decision timestamp")

local completedRequest = requests.MarkFulfilled(officerRequest, "OfficerOne", 144)
assert.equal("FULFILLED", completedRequest.fulfillment, "fulfill should transition the request to fulfilled")
assert.equal("OfficerOne", completedRequest.fulfilledBy, "fulfill should store who fulfilled the request")
assert.equal(144, completedRequest.fulfillmentUpdatedAt, "fulfill should store fulfillment timestamp")

local requestAudit = requests.BuildAuditEntry("REQUEST_APPROVED", approvedRequest, {
    actor = "GuildLead",
    timestamp = 88,
    oldValue = "PENDING",
    newValue = "APPROVED",
})

assert.equal("REQUEST", requestAudit.category, "request audit entries should be categorized for history")
assert.equal("REQUEST_APPROVED", requestAudit.type, "request audit entries should preserve the event type")
assert.equal("GuildLead", requestAudit.actor, "request audit entries should store the acting user")
assert.equal("PENDING", requestAudit.oldValue, "request audit entries should capture the previous state")
assert.equal("APPROVED", requestAudit.newValue, "request audit entries should capture the new state")

local requestDb = {
    requests = {},
    auditLog = {},
}

local storedRequest = requests.CreateAndStore(requestDb, {
    requester = "MemberOne",
    role = "MEMBER",
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 5,
    note = "Cauldrons",
})

assert.equal(1, #requestDb.requests, "create and store should append the request to the saved db")
assert.equal(1, #requestDb.auditLog, "create and store should add a request-created audit row")
assert.equal("REQUEST_CREATED", requestDb.auditLog[1].type, "create and store should audit request creation")

requests.ApproveStored(requestDb, storedRequest.requestId, "GuildLead", 91)
assert.equal("APPROVED", requestDb.requests[1].approval, "approve stored should update the saved request")
assert.equal("REQUEST_APPROVED", requestDb.auditLog[2].type, "approve stored should append an approval audit row")

requests.MarkFulfilledStored(requestDb, storedRequest.requestId, "OfficerOne", 95)
assert.equal("FULFILLED", requestDb.requests[1].fulfillment, "fulfill stored should update the saved request")
assert.equal("REQUEST_FULFILLED", requestDb.auditLog[3].type, "fulfill stored should append a fulfillment audit row")

local deniedDb = {
    auth = {
        capabilities = {
            full_ui = { [1] = true },
            request_submit = {},
            request_approve = { [1] = true },
            request_reject = { [1] = true },
            request_edit = { [1] = true },
            request_fulfill = { [1] = true },
            request_reopen = { [1] = true },
            minimum_add = { [1] = true },
            minimum_edit = { [1] = true },
            minimum_delete = { [1] = true },
            auth_manage = {},
        },
        blacklist = {},
    },
    requests = {
        {
            requestId = "request-1",
            requester = "MemberOne",
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 2,
            approval = "PENDING",
            fulfillment = "OPEN",
        },
    },
    auditLog = {},
}

local deniedApproval = requests.ApproveStored(deniedDb, "request-1", {
    characterKey = "Stormrage-MemberOne",
    name = "MemberOne",
    guildRankIndex = 2,
    guildRankName = "Raider",
    inGuild = true,
}, 111)

assert.truthy(deniedApproval == nil, "request approvals should be denied when the actor lacks request-approve permission")
assert.equal("PENDING", deniedDb.requests[1].approval, "denied request approvals should leave the saved request unchanged")
assert.equal(0, #deniedDb.auditLog, "denied request approvals should not write audit entries")
