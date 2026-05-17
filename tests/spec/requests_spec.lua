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

assert.equal("PENDING", officerRequest.approval, "officer requests should not auto-approve")
assert.equal(0, officerRequest.createdAt, "requests should store creation timestamp")

local guildMasterRequest = requests.Create({
    actorContext = {
        characterKey = "Stormrage-GuildLead",
        name = "GuildLead",
        guildRankName = "Guild Master",
        guildRankIndex = 0,
        isGuildMaster = true,
        inGuild = true,
    },
    auth = {
        capabilities = {
            request_submit = {},
            request_approve = { [0] = true },
        },
        blacklist = {},
    },
    itemID = 1001,
    itemName = "Flask Alpha",
    quantity = 3,
})

assert.equal("PENDING", guildMasterRequest.approval, "guildmaster requests should still start pending")

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

local selfApprovalDb = {
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
            requestId = "self-request-1",
            requester = "OfficerOne",
            requesterCharacterKey = "Stormrage-OfficerOne",
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 2,
            approval = "PENDING",
            fulfillment = "OPEN",
        },
    },
    auditLog = {},
}

local deniedSelfApproval = requests.ApproveStored(selfApprovalDb, "self-request-1", {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildRankIndex = 1,
    guildRankName = "Officer",
    inGuild = true,
    isGuildMaster = false,
}, 110)

assert.truthy(deniedSelfApproval == nil, "request approvers should not approve their own requests")
assert.equal("PENDING", selfApprovalDb.requests[1].approval, "denied self approvals should leave the request pending")
assert.equal(0, #selfApprovalDb.auditLog, "denied self approvals should not write audit entries")

local guildmasterSelfApproval = requests.ApproveStored(selfApprovalDb, "self-request-1", {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildRankIndex = 0,
    guildRankName = "Guild Master",
    inGuild = true,
    isGuildMaster = true,
}, 111)

assert.truthy(guildmasterSelfApproval ~= nil, "guildmasters should be able to manually approve their own request through workflow")
assert.equal("APPROVED", selfApprovalDb.requests[1].approval, "guildmaster self approvals should still require the explicit approval action")

local approvalMetadataDb = {
    auth = {
        capabilities = {
            request_approve = { [1] = true },
        },
        blacklist = {},
    },
    requests = {
        {
            requestId = "approval-metadata-request",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 243734,
            itemName = "Thalassian Phoenix Oil",
            quantity = 100,
            approval = "PENDING",
            fulfillment = "OPEN",
        },
    },
    auditLog = {},
}

local approvalWithMetadata = requests.ApproveStored(approvalMetadataDb, "approval-metadata-request", {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildRankIndex = 1,
    guildRankName = "Officer",
    inGuild = true,
}, "Approved for raid supplies", 130, "Raid Buffer")

assert.truthy(approvalWithMetadata ~= nil, "approve stored should accept decision note and bank tab metadata")
assert.equal("APPROVED", approvalMetadataDb.requests[1].approval, "approval metadata requests should approve")
assert.equal("Approved for raid supplies", approvalMetadataDb.requests[1].decisionNote, "approve stored should preserve the decision note")
assert.equal("Raid Buffer", approvalMetadataDb.requests[1].approvedBankTab, "approve stored should preserve the approver-selected bank tab")
assert.equal("Raid Buffer", approvalMetadataDb.requests[1].tabName, "approve stored should expose the selected bank tab for downstream request details")
assert.equal("OfficerOne", approvalMetadataDb.auditLog[1].actor, "approve stored should normalize actor tables to names for history rows")
assert.truthy(string.find(tostring(approvalMetadataDb.auditLog[1].actor or ""), "table:", 1, true) == nil, "request audit actor should never render Lua table identities")

local cancelDb = {
    auth = {
        capabilities = {
            request_submit = {},
            request_approve = { [1] = true },
        },
        blacklist = {},
    },
    requests = {
        {
            requestId = "cancel-request-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 2,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 10,
        },
        {
            requestId = "approved-request-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 1002,
            itemName = "Rune Delta",
            quantity = 1,
            approval = "APPROVED",
            fulfillment = "OPEN",
            updatedAt = 11,
        },
    },
    auditLog = {},
}

local canceledRequest = requests.CancelStored(cancelDb, "cancel-request-1", {
    characterKey = "Stormrage-MemberOne",
    name = "MemberOne",
    guildRankIndex = 4,
    guildRankName = "Member",
    inGuild = true,
}, "No longer needed", 120)

assert.truthy(canceledRequest ~= nil, "request authors should be able to cancel pending requests")
assert.equal("CANCELED", cancelDb.requests[1].approval, "canceled requests should move to canceled status")
assert.equal("No longer needed", cancelDb.requests[1].decisionNote, "request cancel should preserve the cancellation note")
assert.equal("REQUEST_CANCELED", cancelDb.auditLog[1].type, "cancel stored should append a cancel audit row")

local deniedApprovedCancel = requests.CancelStored(cancelDb, "approved-request-1", {
    characterKey = "Stormrage-MemberOne",
    name = "MemberOne",
    guildRankIndex = 4,
    guildRankName = "Member",
    inGuild = true,
}, "Too late", 121)

assert.truthy(deniedApprovedCancel == nil, "request authors should not cancel approved requests")
assert.equal("APPROVED", cancelDb.requests[2].approval, "denied approved-request cancels should leave status unchanged")

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

local invalidTransitionDb = {
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
            requestId = "request-pending",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 2,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 10,
        },
        {
            requestId = "request-open",
            requester = "MemberTwo",
            requesterCharacterKey = "Stormrage-MemberTwo",
            itemID = 1002,
            itemName = "Rune Delta",
            quantity = 1,
            approval = "APPROVED",
            fulfillment = "OPEN",
            updatedAt = 12,
        },
    },
    auditLog = {},
}

local invalidFulfill = requests.MarkFulfilledStored(invalidTransitionDb, "request-pending", {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildRankIndex = 1,
    guildRankName = "Officer",
    inGuild = true,
}, 200)
assert.truthy(invalidFulfill == nil, "pending requests should not be fulfillable before approval")
assert.equal("PENDING", invalidTransitionDb.requests[1].approval, "invalid fulfill attempts should not change approval state")
assert.equal("OPEN", invalidTransitionDb.requests[1].fulfillment, "invalid fulfill attempts should not change fulfillment state")
assert.equal(0, #invalidTransitionDb.auditLog, "invalid fulfill attempts should not write audit entries")

local invalidReopen = requests.ReopenStored(invalidTransitionDb, "request-open", {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildRankIndex = 1,
    guildRankName = "Officer",
    inGuild = true,
}, 201)
assert.truthy(invalidReopen == nil, "open requests should not reopen when they are not fulfilled")
assert.equal("OPEN", invalidTransitionDb.requests[2].fulfillment, "invalid reopen attempts should not change fulfillment state")
assert.equal(0, #invalidTransitionDb.auditLog, "invalid reopen attempts should not write audit entries")
