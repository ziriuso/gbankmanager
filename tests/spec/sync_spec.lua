local assert = require("tests.helpers.assert")

_G.UnitName = function()
    return "SyncTester"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Officer", 1
end

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

_G.C_ChatInfo.sentMessages = {}
transport.Send("GUILD", "GUILD", {
    type = "SYNC_HELLO",
    updatedAt = 55,
    payload = "GuildLead",
})

assert.equal(1, #_G.C_ChatInfo.sentMessages, "transport should send addon messages through chat info")
assert.equal("GBankManager", _G.C_ChatInfo.sentMessages[1].prefix, "transport should use addon prefix")
assert.equal("SYNC_HELLO|55|GuildLead", _G.C_ChatInfo.sentMessages[1].payload, "transport should send encoded sync payload")

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local events = ns.modules.events
local syncEvents = ns.modules.syncEvents
local scannerEvents = ns.modules.guildBankScannerEvents

assert.truthy(type(events) == "table", "events module should load from the toc")
assert.truthy(type(events.GetScript) == "function", "events module should expose frame scripts")
assert.truthy(type(syncEvents) == "table", "sync events module should load from the toc")
assert.truthy(type(syncEvents.GetRegisteredEvents) == "function", "sync events module should expose its registered events")
assert.truthy(type(syncEvents.HandleEvent) == "function", "sync events module should expose a sync event handler")
assert.truthy(type(scannerEvents) == "table", "scanner events module should load from the toc")
assert.truthy(type(scannerEvents.GetRegisteredEvents) == "function", "scanner events module should expose its registered events")
assert.truthy(type(scannerEvents.HandleEvent) == "function", "scanner events module should expose a scanner event handler")

local scannerRegisteredEvents = scannerEvents.GetRegisteredEvents()
assert.equal("GUILDBANKBAGSLOTS_CHANGED", scannerRegisteredEvents[1], "scanner event adapter should own the guild bank slot event")

local syncRegisteredEvents = syncEvents.GetRegisteredEvents()
assert.equal("ADDON_LOADED", syncRegisteredEvents[1], "sync event adapter should own addon initialization")
assert.equal("PLAYER_LOGIN", syncRegisteredEvents[2], "sync event adapter should own player login")
assert.equal("CHAT_MSG_ADDON", syncRegisteredEvents[3], "sync event adapter should own addon-message events")

local hasPlayerLogin = false
local hasChatMsgAddon = false
local hasAddonLoaded = false
for _, eventName in ipairs(events.events or {}) do
    if eventName == "ADDON_LOADED" then
        hasAddonLoaded = true
    elseif eventName == "PLAYER_LOGIN" then
        hasPlayerLogin = true
    elseif eventName == "CHAT_MSG_ADDON" then
        hasChatMsgAddon = true
    end
end

assert.truthy(hasAddonLoaded, "task 7 events should listen for addon loaded initialization")
assert.truthy(hasPlayerLogin, "task 7 events should listen for player login")
assert.truthy(hasChatMsgAddon, "task 7 events should listen for addon messages")

_G.C_ChatInfo.sentMessages = {}
_G.C_ChatInfo.registeredPrefixes = {}

local onEvent = events:GetScript("OnEvent")
onEvent(events, "ADDON_LOADED", "GBankManager")
onEvent(events, "PLAYER_LOGIN")

assert.equal("GBankManager", _G.C_ChatInfo.registeredPrefixes[1], "player login should register the addon message prefix")
assert.equal(1, #_G.C_ChatInfo.sentMessages, "player login should send a sync hello")
assert.equal("SYNC_HELLO|0|Stormrage-SyncTester", _G.C_ChatInfo.sentMessages[1].payload, "sync hello should include the current player character key")

local db = ns.state.db
db.requests = {}
db.auth.capabilities.request_submit = {}
db.auth.capabilities.request_approve = { [1] = true }
db.auth.capabilities.request_reject = { [1] = true }
db.auth.capabilities.request_edit = { [1] = true }
db.auth.capabilities.request_fulfill = { [1] = true }
db.auth.capabilities.request_reopen = { [1] = true }
db.auth.capabilities.full_ui = { [1] = true }
db.auth.capabilities.minimum_add = { [1] = true }
db.auth.capabilities.minimum_edit = { [1] = true }
db.auth.capabilities.minimum_delete = { [1] = true }
db.auth.capabilities.auth_manage = { [1] = true }

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
onEvent(events, "CHAT_MSG_ADDON", "GBankManager", remoteRequestPayload, "GUILD", "MemberOne")
assert.equal(1, #db.requests, "sync events should accept guild request-created payloads from allowed members")
assert.equal("req-remote-1", db.requests[1].requestId, "sync events should persist synced request ids")

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
local forgedCreateAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", forgedRequestPayload, "GUILD", "MemberOne")
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
local staleCreateAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", staleDuplicateCreatePayload, "GUILD", "MemberOne")
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
local missingUpdateAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", missingUpdatePayload, "GUILD", "OfficerOne")
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
local staleUpdateAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", staleUpdatePayload, "GUILD", "OfficerOne")
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
local invalidTransitionAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", invalidTransitionUpdatePayload, "GUILD", "OfficerOne")
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
local immutableMutationAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", immutableFieldMutationPayload, "GUILD", "OfficerOne")
assert.truthy(not immutableMutationAccepted, "sync events should reject request updates that mutate immutable request identity fields")
assert.equal("MemberOne", db.requests[1].requester, "invalid sync updates should not rewrite requester identity")
assert.equal("Stormrage-MemberOne", db.requests[1].requesterCharacterKey, "invalid sync updates should not rewrite requester character keys")
assert.equal(2002, db.requests[1].itemID, "invalid sync updates should not rewrite item identity")

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
local forgedSenderAccepted = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", forgedSenderPayload, "GUILD", "DifferentSender")
assert.truthy(not forgedSenderAccepted, "sync events should reject payloads whose actor context does not match the addon-message sender")
assert.equal(1, #db.requests, "forged sender payloads should not append requests")

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
            updatedAt = 101,
            updatedBy = "Stormrage-GuildLead",
            updatedByRankIndex = 0,
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
onEvent(events, "CHAT_MSG_ADDON", "GBankManager", remoteAuthPayload, "GUILD", "GuildLead")
assert.truthy(
    (db.auth.blacklist["Stormrage-Troublemaker"] and db.auth.blacklist["Stormrage-Troublemaker"].reason == "Blocked")
        or db.auth.blacklistHashes[ns.modules.permissions.HashCharacterKey("Stormrage-Troublemaker")] == true,
    "sync events should accept guildmaster auth policy snapshots"
)

local scanner = ns.modules.scanner
local scannerCalls = 0
local originalOnGuildBankSlotsChanged = scanner.OnGuildBankSlotsChanged
scanner.OnGuildBankSlotsChanged = function(...)
    scannerCalls = scannerCalls + 1
    return originalOnGuildBankSlotsChanged(...)
end
scanner.scanInProgress = true
onEvent(events, "GUILDBANKBAGSLOTS_CHANGED", 2)
scanner.OnGuildBankSlotsChanged = originalOnGuildBankSlotsChanged

assert.equal(1, scannerCalls, "central event dispatcher should forward guild bank slot events to the scanner event adapter")
