local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

_G.UnitName = function()
    return "SyncTester"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

local function load_vendored_ace3()
    local vendoredLibPaths = {
        "GBankManager/Libs/LibStub/LibStub.lua",
        "GBankManager/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
        "GBankManager/Libs/AceSerializer-3.0/AceSerializer-3.0.lua",
        "GBankManager/Libs/AceComm-3.0/ChatThrottleLib.lua",
        "GBankManager/Libs/AceComm-3.0/AceComm-3.0.lua",
    }

    for _, path in ipairs(vendoredLibPaths) do
        local chunk, loadError = loadfile(path)
        if not chunk then
            error(loadError)
        end

        chunk()
    end

    _G.AceCommStub.attach()
end

load_vendored_ace3()

local coordinator = dofile("GBankManager/Sync/Coordinator.lua")
local codec = dofile("GBankManager/Sync/Codec.lua")
local transport = dofile("GBankManager/Sync/Transport.lua")

local resolved = coordinator.ResolveConflict(
    { role = "MEMBER", updatedAt = 100, approval = "PENDING" },
    { role = "OFFICER", updatedAt = 90, approval = "APPROVED" }
)

assert.equal("APPROVED", resolved.approval, "officer authority should beat newer member record")

local authConflictWinner = coordinator.ResolveAuthConflict(
    {
        updatedAt = 200,
        updatedBy = "OfficerOne",
        updatedByRankIndex = 1,
        capabilities = { auth_manage = { [1] = true } },
    },
    {
        updatedAt = 150,
        updatedBy = "GuildLead",
        updatedByRankIndex = 0,
        capabilities = { auth_manage = {} },
    }
)

assert.equal("GuildLead", authConflictWinner.updatedBy, "guildmaster auth policy updates should beat newer delegated-admin policy updates")

local requestConflictWinner = coordinator.ResolveRequestConflict(
    {
        updatedAt = 220,
        updatedBy = "Stormrage-MemberOne",
        updatedByRankIndex = 2,
        approval = "CANCELED",
    },
    {
        updatedAt = 180,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
        approval = "APPROVED",
    }
)

assert.equal("APPROVED", requestConflictWinner.approval, "officer-authored request updates should beat newer member-authored updates")

local encoded = codec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 44,
    payload = "OfficerOne",
})

assert.equal("SYNC_HELLO|44|OfficerOne", encoded, "codec should serialize sync messages")

local decoded = codec.DecodeTable(encoded)
assert.equal("SYNC_HELLO", decoded.type, "codec should restore message type")
assert.equal(44, decoded.updatedAt, "codec should restore update timestamps")
assert.equal("OfficerOne", decoded.payload, "codec should restore message payload")

local encodedTablePayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 77,
    payload = {
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-sync-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 2,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 77,
        },
    },
})
local decodedTablePayload = codec.DecodeTable(encodedTablePayload)
assert.equal("REQUEST_CREATED", decodedTablePayload.type, "codec should preserve typed table payload messages")
assert.equal("req-sync-1", decodedTablePayload.payload.request.requestId, "codec should decode nested table payload request ids")
assert.equal("Stormrage-OfficerOne", decodedTablePayload.payload.actorContext.characterKey, "codec should decode nested actor contexts")

_G.AceCommStub.reset()
local whisperPayload = transport.Send("WHISPER", "OfficerOne", {
    type = "SYNC_HELLO",
    updatedAt = 55,
    payload = "Stormrage-GuildLead",
})

assert.equal("GBankManager", _G.AceCommStub.lastPrefix, "transport should register and send over the addon AceComm prefix")
assert.equal("WHISPER", _G.AceCommStub.lastDistribution, "transport should preserve AceComm distribution")
assert.equal("OfficerOne", _G.AceCommStub.lastTarget, "transport should preserve the whisper target")
assert.equal(whisperPayload, _G.AceCommStub.lastMessage, "transport should pass the encoded sync envelope to AceComm")

local received
transport.SetReceiver(function(message, distribution, sender)
    received = {
        message = message,
        distribution = distribution,
        sender = sender,
    }
end)
_G.AceCommStub.fire("GBankManager", "SYNC_HELLO|55|Stormrage-OfficerOne", "GUILD", "OfficerOne")
assert.equal("OfficerOne", (received or {}).sender, "AceComm receive callback should be wired back into the addon transport")
local receivedMessage, receiveState = transport.Receive("SYNC_HELLO|55|Stormrage-OfficerOne", "GUILD", "OfficerOne")
assert.equal("complete", receiveState, "transport receive should surface AceComm-completed payloads")
assert.equal("SYNC_HELLO", (receivedMessage or {}).type, "transport receive should decode completed AceComm payloads")

_G.C_ChatInfo.sentMessages = {}
transport.Send("GUILD", "GUILD", {
    type = "SYNC_HELLO",
    updatedAt = 55,
    payload = "GuildLead",
})

assert.equal(1, #_G.C_ChatInfo.sentMessages, "transport should send addon messages through chat info")
assert.equal("GBankManager", _G.C_ChatInfo.sentMessages[1].prefix, "transport should use addon prefix")
assert.equal("SYNC_HELLO|55|GuildLead", _G.C_ChatInfo.sentMessages[1].payload, "transport should send encoded sync payload")

local oversizedRequestMessage = {
    type = "REQUEST_CREATED",
    updatedAt = 88,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 8,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-chunked-send-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            requesterRankName = "Raider",
            requesterRankIndex = 8,
            itemID = 2222,
            itemName = string.rep("Chunked Flask Alpha ", 12),
            quantity = 4,
            approval = "PENDING",
            fulfillment = "OPEN",
            note = string.rep("Need for raid night. ", 10),
            createdAt = 88,
            createdBy = "MemberOne",
            updatedAt = 88,
            updatedBy = "MemberOne",
        },
    },
}
local oversizedRequestEncoded = codec.EncodeTable(oversizedRequestMessage)
assert.truthy(#oversizedRequestEncoded > 255, "representative request sync payload should exceed the raw addon-message payload limit")

_G.C_ChatInfo.sentMessages = {}
local returnedOversizedPayload = transport.Send("GUILD", "GUILD", oversizedRequestMessage)
assert.equal(oversizedRequestEncoded, returnedOversizedPayload, "transport should still return the full encoded sync payload")
assert.truthy(#_G.C_ChatInfo.sentMessages > 1, "transport should split oversized sync payloads into multiple addon messages")
for _, sent in ipairs(_G.C_ChatInfo.sentMessages) do
    assert.truthy(#(sent.payload or "") <= 255, "transport should keep each addon-message payload within the base API size limit")
end

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local events = ns.modules.events
local syncEvents = ns.modules.syncEvents
local scannerEvents = ns.modules.guildBankScannerEvents
local function last_chat_message()
    return (_G.DEFAULT_CHAT_FRAME.messages or {})[#(_G.DEFAULT_CHAT_FRAME.messages or {})]
end

assert.truthy(type(events) == "table", "events module should load from the toc")
assert.truthy(type(events.GetScript) == "function", "events module should expose frame scripts")
assert.truthy(type(syncEvents) == "table", "sync events module should load from the toc")
assert.truthy(type(syncEvents.GetRegisteredEvents) == "function", "sync events module should expose its registered events")
assert.truthy(type(syncEvents.HandleEvent) == "function", "sync events module should expose a sync event handler")
assert.truthy(type(scannerEvents) == "table", "scanner events module should load from the toc")
assert.truthy(type(scannerEvents.GetRegisteredEvents) == "function", "scanner events module should expose its registered events")
assert.truthy(type(scannerEvents.HandleEvent) == "function", "scanner events module should expose a scanner event handler")

local scannerRegisteredEvents = scannerEvents.GetRegisteredEvents()
assert.equal("GUILDBANKFRAME_OPENED", scannerRegisteredEvents[1], "scanner event adapter should own the guild bank opened event")
assert.equal("GUILDBANKFRAME_CLOSED", scannerRegisteredEvents[2], "scanner event adapter should own the guild bank closed event")
assert.equal("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", scannerRegisteredEvents[3], "scanner event adapter should also listen for the player-interaction show event")
assert.equal("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", scannerRegisteredEvents[4], "scanner event adapter should also listen for the player-interaction hide event")
assert.equal("GUILDBANK_UPDATE_TABS", scannerRegisteredEvents[5], "scanner event adapter should own the guild bank tab update event")
assert.equal("GUILDBANKBAGSLOTS_CHANGED", scannerRegisteredEvents[6], "scanner event adapter should own the guild bank slot event")

local syncRegisteredEvents = syncEvents.GetRegisteredEvents()
assert.equal("ADDON_LOADED", syncRegisteredEvents[1], "sync event adapter should own addon initialization")
assert.equal("PLAYER_LOGIN", syncRegisteredEvents[2], "sync event adapter should own player login")
assert.equal("CHAT_MSG_ADDON", syncRegisteredEvents[3], "sync event adapter should own addon-message events")

local hasPlayerLogin = false
local hasChatMsgAddon = false
local hasAddonLoaded = false
local hasGuildBankTabUpdate = false
for _, eventName in ipairs(events.events or {}) do
    if eventName == "ADDON_LOADED" then
        hasAddonLoaded = true
    elseif eventName == "PLAYER_LOGIN" then
        hasPlayerLogin = true
    elseif eventName == "CHAT_MSG_ADDON" then
        hasChatMsgAddon = true
    elseif eventName == "GUILDBANK_UPDATE_TABS" then
        hasGuildBankTabUpdate = true
    end
end

assert.truthy(hasAddonLoaded, "task 7 events should listen for addon loaded initialization")
assert.truthy(hasPlayerLogin, "task 7 events should listen for player login")
assert.truthy(hasChatMsgAddon, "task 7 events should listen for addon messages")
assert.truthy(hasGuildBankTabUpdate, "scanner events should listen for guild bank tab updates")

_G.C_ChatInfo.sentMessages = {}
_G.C_ChatInfo.registeredPrefixes = {}

local onEvent = events:GetScript("OnEvent")
onEvent(events, "ADDON_LOADED", "GBankManager")
onEvent(events, "PLAYER_LOGIN")

assert.equal("GBankManager", _G.C_ChatInfo.registeredPrefixes[1], "player login should register the addon message prefix")
assert.equal(1, #_G.C_ChatInfo.sentMessages, "player login should send a sync hello")
assert.equal("SYNC_HELLO|0|Stormrage-SyncTester", _G.C_ChatInfo.sentMessages[1].payload, "sync hello should include the current player character key")
assert.equal("GBankManager: Sync hello sent for Stormrage-SyncTester.", last_chat_message(), "player login should report sync hello activity in chat")

local db = ns.state.db
db.requests = {}
db.auth.capabilities.request_submit = {}
db.auth.capabilities.request_approve = { [1] = true }
db.auth.capabilities.request_reject = { [1] = true }
db.auth.capabilities.request_edit = { [1] = true }
db.auth.capabilities.request_fulfill = { [1] = true }
db.auth.capabilities.request_reopen = { [1] = true }
db.auth.capabilities.request_delete = { [1] = true }
db.auth.capabilities.full_ui = { [1] = true }
db.auth.capabilities.minimum_add = { [1] = true }
db.auth.capabilities.minimum_edit = { [1] = true }
db.auth.capabilities.minimum_delete = { [1] = true }
db.auth.capabilities.auth_manage = { [1] = true }

_G.C_ChatInfo.sentMessages = {}
db.requests = {}
db.auditLog = {}

local chunkedRemoteRequestMessage = {
    type = "REQUEST_CREATED",
    updatedAt = 90,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 8,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-remote-chunked-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            requesterRankName = "Raider",
            requesterRankIndex = 8,
            itemID = 2001,
            itemName = string.rep("Potion Beta Remote ", 10),
            quantity = 4,
            approval = "PENDING",
            fulfillment = "OPEN",
            note = string.rep("Chunked guild sync verification. ", 8),
            createdAt = 90,
            createdBy = "MemberOne",
            updatedAt = 90,
            updatedBy = "MemberOne",
        },
    },
}
local chunkedRemoteRequestEncoded = codec.EncodeTable(chunkedRemoteRequestMessage)
assert.truthy(#chunkedRemoteRequestEncoded > 255, "end-to-end chunked request sync test should use an oversized encoded payload")
transport.Send("GUILD", "GUILD", chunkedRemoteRequestMessage)
assert.truthy(#_G.C_ChatInfo.sentMessages > 1, "chunked request sync test should exercise multi-message transport")
for index, sent in ipairs(_G.C_ChatInfo.sentMessages) do
    local accepted = _G.FireEvent("CHAT_MSG_ADDON", sent.prefix, sent.payload, sent.distribution, "MemberOne")
    assert.truthy(accepted, "chunked addon-message pieces should be treated as handled by the sync event adapter")
    if index < #_G.C_ChatInfo.sentMessages then
        assert.equal(0, #db.requests, "partial chunk sequences should not apply request state before reassembly completes")
    end
end
assert.equal(1, #db.requests, "sync events should reassemble chunked request payloads before applying them")
assert.equal("req-remote-chunked-1", db.requests[1].requestId, "chunked request sync should preserve the request identity")
assert.equal("GBankManager: Synced request req-remote-chunked-1 from MemberOne.", last_chat_message(), "chunked request sync should emit the normal accepted-request chat feedback once")

_G.C_ChatInfo.sentMessages = {}
db.requests = {}
db.auditLog = {}

local remoteRequestPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 91,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta",
            quantity = 4,
            note = "For raid",
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 91,
        },
    },
})
_G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteRequestPayload, "GUILD", "MemberOne")
assert.equal(1, #db.requests, "sync events should accept guild request-created payloads from allowed members")
assert.equal("req-remote-1", db.requests[1].requestId, "sync events should persist synced request ids")
assert.equal("REQUEST_CREATED", ((db.auditLog or {})[#(db.auditLog or {})] or {}).type, "accepted synced request creation should append local history")
assert.equal("GBankManager: Synced request req-remote-1 from MemberOne.", last_chat_message(), "accepted synced request creation should report chat feedback")

local forgedRequestPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 92,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-forged-1",
            requester = "OfficerOne",
            requesterCharacterKey = "Stormrage-OfficerOne",
            itemID = 2003,
            itemName = "Elixir Gamma",
            quantity = 1,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 92,
        },
    },
})
local forgedCreateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", forgedRequestPayload, "GUILD", "MemberOne")
assert.truthy(not forgedCreateAccepted, "sync events should reject request-created payloads whose requester identity does not match the actor context")
assert.equal(1, #db.requests, "forged request-created payloads should not append requests")

db.requests[1].itemName = "Potion Beta Local"
db.requests[1].updatedAt = 120
local staleDuplicateCreatePayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 91,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta Remote",
            quantity = 9,
            note = "Older remote copy",
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 91,
        },
    },
})
local staleCreateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", staleDuplicateCreatePayload, "GUILD", "MemberOne")
assert.truthy(staleCreateAccepted, "sync events should treat duplicate request-created payloads as handled even when they are stale")
assert.equal("Potion Beta Local", db.requests[1].itemName, "stale duplicate request-created payloads should not overwrite newer local request state")
assert.equal(120, db.requests[1].updatedAt, "stale duplicate request-created payloads should keep the newer local timestamp")

local missingUpdatePayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 130,
    payload = {
        action = "APPROVE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-missing-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2005,
            itemName = "Missing Request",
            quantity = 2,
            approval = "APPROVED",
            fulfillment = "OPEN",
            updatedAt = 130,
        },
    },
})
local missingUpdateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", missingUpdatePayload, "GUILD", "OfficerOne")
assert.truthy(not missingUpdateAccepted, "sync events should reject request updates for unknown request ids")
assert.equal(1, #db.requests, "request updates for unknown request ids should not create new rows")

local staleUpdatePayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 100,
    payload = {
        action = "APPROVE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta Stale Update",
            quantity = 4,
            approval = "APPROVED",
            fulfillment = "OPEN",
            updatedAt = 100,
        },
    },
})
local staleUpdateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", staleUpdatePayload, "GUILD", "OfficerOne")
assert.truthy(staleUpdateAccepted, "sync events should treat stale request updates as handled messages")
assert.equal("Potion Beta Local", db.requests[1].itemName, "stale request updates should not overwrite newer local request data")
assert.equal(120, db.requests[1].updatedAt, "stale request updates should keep the newer local timestamp")

local invalidTransitionUpdatePayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 140,
    payload = {
        action = "FULFILL",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta Invalid Fulfill",
            quantity = 4,
            approval = "PENDING",
            fulfillment = "FULFILLED",
            updatedAt = 140,
        },
    },
})
local invalidTransitionAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", invalidTransitionUpdatePayload, "GUILD", "OfficerOne")
assert.truthy(not invalidTransitionAccepted, "sync events should reject impossible request state transitions")
assert.equal("Potion Beta Local", db.requests[1].itemName, "invalid request updates should not overwrite local state")
assert.equal("OPEN", db.requests[1].fulfillment, "invalid request updates should not change fulfillment state")

local immutableFieldMutationPayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 141,
    payload = {
        action = "APPROVE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "DifferentRequester",
            requesterCharacterKey = "Stormrage-DifferentRequester",
            itemID = 9999,
            itemName = "Forged Identity Update",
            quantity = 4,
            approval = "APPROVED",
            fulfillment = "OPEN",
            createdAt = 1,
            createdBy = "Stormrage-OtherCreator",
            updatedAt = 141,
        },
    },
})
local immutableMutationAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", immutableFieldMutationPayload, "GUILD", "OfficerOne")
assert.truthy(not immutableMutationAccepted, "sync events should reject request updates that mutate immutable request identity fields")
assert.equal("MemberOne", db.requests[1].requester, "invalid sync updates should not rewrite requester identity")
assert.equal("Stormrage-MemberOne", db.requests[1].requesterCharacterKey, "invalid sync updates should not rewrite requester character keys")
assert.equal(2002, db.requests[1].itemID, "invalid sync updates should not rewrite item identity")

db.requests[2] = {
    requestId = "req-officer-own",
    requester = "OfficerOne",
    requesterCharacterKey = "Stormrage-OfficerOne",
    itemID = 2011,
    itemName = "Officer Request",
    quantity = 1,
    approval = "PENDING",
    fulfillment = "OPEN",
    updatedAt = 150,
}

local selfApprovalUpdatePayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 160,
    payload = {
        action = "APPROVE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-officer-own",
            requester = "OfficerOne",
            requesterCharacterKey = "Stormrage-OfficerOne",
            itemID = 2011,
            itemName = "Officer Request",
            quantity = 1,
            approval = "APPROVED",
            fulfillment = "OPEN",
            updatedAt = 160,
        },
    },
})
local selfApprovalUpdateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", selfApprovalUpdatePayload, "GUILD", "OfficerOne")
assert.truthy(not selfApprovalUpdateAccepted, "sync events should reject self-approval request updates from non-guildmasters")
assert.equal("PENDING", db.requests[2].approval, "rejected self-approval sync updates should leave approval pending")

local forgedCancelPayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 161,
    payload = {
        action = "CANCEL",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta Canceled By Officer",
            quantity = 4,
            approval = "CANCELED",
            fulfillment = "OPEN",
            updatedAt = 161,
        },
    },
})
local forgedCancelAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", forgedCancelPayload, "GUILD", "OfficerOne")
assert.truthy(not forgedCancelAccepted, "sync events should reject request cancel updates from non-authors")
assert.equal("PENDING", db.requests[1].approval, "forged cancel sync updates should leave approval pending")

local authorCancelPayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 162,
    payload = {
        action = "CANCEL",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-remote-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2002,
            itemName = "Potion Beta Canceled",
            quantity = 4,
            note = "For raid",
            approval = "CANCELED",
            fulfillment = "OPEN",
            decisionNote = "No longer needed",
            updatedAt = 162,
        },
    },
})
local authorCancelAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", authorCancelPayload, "GUILD", "MemberOne")
assert.truthy(authorCancelAccepted, "sync events should accept request cancel updates from the request author")
assert.equal("CANCELED", db.requests[1].approval, "accepted author cancel sync updates should persist the canceled status")
assert.equal("No longer needed", db.requests[1].decisionNote, "accepted author cancel sync updates should preserve the decision note")

db.requests[3] = {
    requestId = "req-approve-sync",
    requester = "MemberTwo",
    requesterCharacterKey = "Stormrage-MemberTwo",
    itemID = 2013,
    itemName = "Approval Sync Flask",
    quantity = 3,
    approval = "PENDING",
    fulfillment = "OPEN",
    updatedAt = 165,
}

local approveSyncPayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 180,
    payload = {
        action = "APPROVE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-approve-sync",
            requester = "MemberTwo",
            requesterCharacterKey = "Stormrage-MemberTwo",
            itemID = 2013,
            itemName = "Approval Sync Flask",
            quantity = 3,
            approval = "APPROVED",
            fulfillment = "OPEN",
            approvedBankTab = "Alchemy",
            tabName = "Alchemy",
            decidedAt = 180,
            updatedAt = 180,
            updatedBy = "Stormrage-OfficerOne",
            updatedByRankIndex = 1,
        },
    },
})
local approveSyncAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", approveSyncPayload, "GUILD", "OfficerOne")
assert.truthy(approveSyncAccepted, "sync events should accept officer approval updates for existing requests")
assert.equal("APPROVED", db.requests[3].approval, "accepted synced approval should update the local request state")
assert.truthy(db.requests[3].minimumRuleKey ~= nil, "accepted synced approval should recreate the local minimum side effect")
assert.equal("Alchemy", ((db.minimums or {})[1] or {}).tabName, "accepted synced approval should upsert the approved request minimum on the receiving client")
local foundApprovedAudit = false
for _, entry in ipairs(db.auditLog or {}) do
    if entry.type == "REQUEST_APPROVED" and entry.requestId == "req-approve-sync" then
        foundApprovedAudit = true
        break
    end
end
assert.truthy(foundApprovedAudit, "accepted synced approval should append local request history")

db.requests[3] = {
    requestId = "req-delete-sync",
    requester = "MemberThree",
    requesterCharacterKey = "Stormrage-MemberThree",
    itemID = 2012,
    itemName = "Delete Sync Flask",
    quantity = 2,
    approval = "REJECTED",
    fulfillment = "OPEN",
    updatedAt = 170,
}

local deleteUpdatePayload = codec.EncodeTable({
    type = "REQUEST_UPDATED",
    updatedAt = 171,
    payload = {
        action = "DELETE",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        request = {
            requestId = "req-delete-sync",
            requester = "MemberThree",
            requesterCharacterKey = "Stormrage-MemberThree",
            itemID = 2012,
            itemName = "Delete Sync Flask",
            quantity = 2,
            approval = "REJECTED",
            fulfillment = "OPEN",
            updatedAt = 171,
        },
    },
})
local deleteUpdateAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", deleteUpdatePayload, "GUILD", "OfficerOne")
assert.truthy(deleteUpdateAccepted, "sync events should accept request delete updates from actors with request-delete permission")
assert.equal(nil, db.requests[3], "accepted request delete sync updates should remove the request from the local cache")

local requestCountBeforeForgedSender = #db.requests
local forgedSenderPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 150,
    payload = {
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-forged-sender-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2010,
            itemName = "Sender Forgery",
            quantity = 1,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 150,
        },
    },
})
local forgedSenderAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", forgedSenderPayload, "GUILD", "DifferentSender")
assert.truthy(not forgedSenderAccepted, "sync events should reject payloads whose actor context does not match the addon-message sender")
assert.equal(requestCountBeforeForgedSender, #db.requests, "forged sender payloads should not append requests")
assert.equal("GBankManager: Ignored synced request create from DifferentSender.", last_chat_message(), "rejected synced request creates should report chat feedback")

local remoteAuthPayload = codec.EncodeTable({
    type = "AUTH_POLICY_SNAPSHOT",
    updatedAt = 101,
    payload = {
        actorContext = {
            characterKey = "Stormrage-GuildLead",
            guildRankIndex = 0,
            guildRankName = "Guild Master",
            inGuild = true,
            isGuildMaster = true,
            name = "GuildLead",
        },
        policy = {
            revision = 3,
            updatedAt = 101,
            updatedBy = "Stormrage-GuildLead",
            updatedByRankIndex = 0,
            restockDefault = 275,
            rankMetadata = db.auth.rankMetadata,
            blacklist = {
                ["Stormrage-Troublemaker"] = {
                    name = "Troublemaker",
                    reason = "Blocked",
                    updatedAt = 101,
                },
            },
            capabilities = db.auth.capabilities,
        },
    },
})
_G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteAuthPayload, "GUILD", "GuildLead")
assert.truthy(
    (db.auth.blacklist["Stormrage-Troublemaker"] and db.auth.blacklist["Stormrage-Troublemaker"].reason == "Blocked")
        or db.auth.blacklistHashes[ns.modules.permissions.HashCharacterKey("Stormrage-Troublemaker")] == true,
    "sync events should accept guildmaster auth policy snapshots"
)
assert.equal(275, db.ui.minimumSettings.defaultQuantity, "sync auth policy snapshots should also update the shared restock default")
assert.equal("AUTH_POLICY_UPDATED", ((db.auditLog or {})[#(db.auditLog or {})] or {}).type, "sync auth policy snapshots should append auth-policy history")
assert.equal("GuildLead-Stormrage", ((db.auditLog or {})[#(db.auditLog or {})] or {}).actor, "sync auth policy history should attribute the remote updater")
assert.equal("GBankManager: Synced auth policy from GuildLead.", last_chat_message(), "accepted synced auth policy snapshots should report chat feedback")

local scanner = ns.modules.scanner
local scannerCalls = 0
local originalOnGuildBankSlotsChanged = scanner.OnGuildBankSlotsChanged
local originalOnGuildBankOpened = scanner.OnGuildBankOpened
local scannerOpenedCalls = 0
scanner.OnGuildBankSlotsChanged = function(...)
    scannerCalls = scannerCalls + 1
    return originalOnGuildBankSlotsChanged(...)
end
scanner.OnGuildBankOpened = function(...)
    scannerOpenedCalls = scannerOpenedCalls + 1
    if originalOnGuildBankOpened then
        return originalOnGuildBankOpened(...)
    end
end
scanner.scanInProgress = true
scanner.pendingAutoScan = true
scanner.guildBankOpen = false
onEvent(events, "GUILDBANKFRAME_OPENED")
onEvent(events, "GUILDBANKBAGSLOTS_CHANGED", 2)
scanner.OnGuildBankSlotsChanged = originalOnGuildBankSlotsChanged
scanner.OnGuildBankOpened = originalOnGuildBankOpened

assert.equal(1, scannerOpenedCalls, "central event dispatcher should forward guild bank opened events to the scanner event adapter")
assert.equal(1, scannerCalls, "central event dispatcher should forward guild bank slot events to the scanner event adapter")
