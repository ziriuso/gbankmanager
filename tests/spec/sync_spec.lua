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
        guildKey = "Guild Testers",
    },
})
local decodedTablePayload = codec.DecodeTable(encodedTablePayload)
assert.equal("REQUEST_CREATED", decodedTablePayload.type, "codec should preserve typed table payload messages")
assert.equal("req-sync-1", decodedTablePayload.payload.request.requestId, "codec should decode nested table payload request ids")
assert.equal("Stormrage-OfficerOne", decodedTablePayload.payload.actorContext.characterKey, "codec should decode nested actor contexts")
assert.equal("Guild Testers", decodedTablePayload.payload.guildKey, "codec should preserve request guild identity inside the payload envelope")

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
            guildRankName = "Raider",
            inGuild = true,
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
assert.equal("SYNC_HELLO|0|SyncTester-Stormrage", _G.C_ChatInfo.sentMessages[1].payload, "sync hello should include the current player character key")
local loginChatText = table.concat(_G.DEFAULT_CHAT_FRAME.messages or {}, "\n")
assert.truthy(string.find(loginChatText, "GBankManager: Sync hello sent for SyncTester-Stormrage.", 1, true) == nil, "player login should not add self hello noise to chat")

local authPolicySource = ns.modules.authPolicySource
local originalPullPolicyFromGuildInfo = authPolicySource.PullPolicyFromGuildInfo
local originalIsInInstance = _G.IsInInstance
local passiveGuildInfoPulls = 0
authPolicySource.PullPolicyFromGuildInfo = function()
    passiveGuildInfoPulls = passiveGuildInfoPulls + 1
    return false, "missing_snippet"
end

_G.IsInInstance = function()
    return true, "party"
end
syncEvents.HandleEvent("ADDON_LOADED", "GBankManager")
assert.equal(0, passiveGuildInfoPulls, "addon load should not pull Guild Info text through protected GetInfoText while inside a dungeon")

_G.IsInInstance = function()
    return true, "raid"
end
syncEvents.HandleEvent("GUILD_ROSTER_UPDATE")
assert.equal(0, passiveGuildInfoPulls, "passive guild events should not pull Guild Info text through protected GetInfoText while inside a raid")

_G.IsInInstance = function()
    return false, "none"
end
syncEvents.HandleEvent("GUILD_MOTD")
assert.equal(1, passiveGuildInfoPulls, "passive guild events should still pull Guild Info text outside dungeon or raid instances")

authPolicySource.PullPolicyFromGuildInfo = originalPullPolicyFromGuildInfo
_G.IsInInstance = originalIsInInstance

local db = ns.state.db
db.ui = db.ui or {}
db.ui.chatSettings = db.ui.chatSettings or {}
db.ui.chatSettings.suppressRoutineMessages = false
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
db.requests = {
    {
        requestId = "req-hello-catchup-1",
        requester = "MemberOne",
        requesterCharacterKey = "MemberOne-Stormrage",
        itemID = 243734,
        itemName = "Hello Catch-up Oil",
        quantity = 2,
        approval = "PENDING",
        fulfillment = "OPEN",
        updatedAt = 88,
        createdAt = 88,
    },
}
db.minimums = {
    {
        itemID = 171276,
        itemName = "Spectral Flask",
        quantity = 20,
        scope = "TAB",
        tabName = "Alchemy",
        enabled = true,
        updatedAt = 89,
        updatedBy = "SyncTester-Stormrage",
        updatedByRankIndex = 1,
    },
}
db.auditLog = {
    {
        type = "REQUEST_CREATED",
        category = "REQUEST",
        itemName = "Hello Catch-up Oil",
        actor = "SyncTester-Stormrage",
        requestId = "req-hello-catchup-1",
        timestamp = 89,
    },
}
db.bankLedger = db.bankLedger or {}
db.bankLedger.itemLogs = {
    {
        timestamp = 1716573600,
        action = "deposit",
        who = "SyncTester-Stormrage",
        itemID = 243734,
        item = "Hello Catch-up Oil",
        quantity = 1,
        tabIndex = 1,
        tabName = "Alchemy",
    },
}
db.bankLedger.moneyLogs = {}
local helloDispatches = {}
local originalManualSyncHandlers = ns.modules.syncManualActionHandlers
ns.modules.syncManualActionHandlers = {
    requests = function()
        helloDispatches[#helloDispatches + 1] = "requests"
        return true, "ok"
    end,
    minimums = function()
        helloDispatches[#helloDispatches + 1] = "minimums"
        return true, "ok"
    end,
    history = function()
        helloDispatches[#helloDispatches + 1] = "history"
        return true, "ok"
    end,
    ledger = function()
        helloDispatches[#helloDispatches + 1] = "ledger"
        return true, "ok"
    end,
}

local remoteHelloPayload = codec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 90,
    payload = "Stormrage-MemberOne",
})
_G.C_ChatInfo.sentMessages = {}
_G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteHelloPayload, "GUILD", "MemberOne")
local helloPeerEntry = ((((db.syncState or {}).peers or {})["Guild Testers"] or {})["MemberOne-Stormrage"] or {})
assert.equal(90, tonumber(helloPeerEntry.lastSeen or 0), "sync hello traffic should update the peer last seen timestamp")
assert.equal(0, tonumber(helloPeerEntry.lastSynchronizedAt or 0), "sync hello presence should not mark a peer synchronized without an actual sync payload")
assert.equal("requests,minimums,history,ledger", table.concat(helloDispatches, ","), "full-shell sync hello should silently answer with catch-up sync families")

local originalFullUi = db.auth.capabilities.full_ui
local originalGetGuildInfo = _G.GetGuildInfo
db.auth.capabilities.full_ui = {}
_G.GetGuildInfo = function()
    return "Guild Testers", "Raider", 2
end
helloDispatches = {}
local requestOnlyHelloPayload = codec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 91,
    payload = "Stormrage-MemberTwo",
})
_G.FireEvent("CHAT_MSG_ADDON", "GBankManager", requestOnlyHelloPayload, "GUILD", "MemberTwo")
local requestOnlyPeerEntry = ((((db.syncState or {}).peers or {})["Guild Testers"] or {})["MemberTwo-Stormrage"] or {})
assert.equal(0, tonumber(requestOnlyPeerEntry.lastSynchronizedAt or 0), "sync hello presence should not mark request-only peers synchronized without an actual sync payload")
assert.equal("requests", table.concat(helloDispatches, ","), "request-only sync hello should only answer with request catch-up")
db.auth.capabilities.full_ui = originalFullUi
_G.GetGuildInfo = originalGetGuildInfo
ns.modules.syncManualActionHandlers = originalManualSyncHandlers

local runtimeBeforeGuildBootstrap = _G.GBankManagerDB
local stateDbBeforeGuildBootstrap = ns.state.db
local stateDbRootBeforeGuildBootstrap = ns.state.dbRoot
_G.GBankManagerDB = ns.modules.defaults.CreateDatabaseRoot("Unknown")
ns.state.db = nil
ns.state.dbRoot = nil

local bootstrappedGuildPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 90,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-bootstrap-guild-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2000,
            itemName = "Bootstrap Flask",
            quantity = 1,
            approval = "PENDING",
            fulfillment = "OPEN",
            createdAt = 90,
            createdBy = "MemberOne",
            updatedAt = 90,
            updatedBy = "MemberOne",
        },
    },
})

local bootstrappedGuildAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", bootstrappedGuildPayload, "GUILD", "MemberOne")
local bootstrappedDb = ns.modules.store.GetDatabase()
assert.truthy(bootstrappedGuildAccepted, "sync events should bootstrap the active guild identity before validating valid guild request traffic")
assert.equal("Guild Testers", tostring((((bootstrappedDb or {}).meta or {}).guildName) or ""), "bootstrapped sync traffic should promote the local database guild identity")
assert.equal("Guild Testers", tostring((((ns.state or {}).dbRoot or {}).activeGuildKey) or ""), "bootstrapped sync traffic should promote the active guild root key")
assert.equal(1, #(bootstrappedDb.requests or {}), "bootstrapped sync traffic should still append the incoming request")

local unknownHelloRoot = ns.modules.defaults.CreateDatabaseRoot("Unknown Guild")
_G.GBankManagerDB = unknownHelloRoot
ns.state.dbRoot = unknownHelloRoot
ns.state.db = unknownHelloRoot.guilds["Unknown Guild"]

local bootstrappedHelloPayload = codec.EncodeTable({
    type = "SYNC_HELLO",
    updatedAt = 91,
    payload = "Stormrage-MemberOne",
})
local bootstrappedHelloAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", bootstrappedHelloPayload, "GUILD", "MemberOne")
local bootstrappedHelloDb = ns.modules.store.GetDatabase()
local bootstrappedHelloPeer = ((((bootstrappedHelloDb.syncState or {}).peers or {})["Guild Testers"] or {})["MemberOne-Stormrage"] or {})
assert.truthy(bootstrappedHelloAccepted, "sync hello traffic should promote the active guild identity when the local root still points at Unknown")
assert.equal("Guild Testers", tostring((((ns.state or {}).dbRoot or {}).activeGuildKey) or ""), "sync hello traffic should promote the active guild root key from the live guild context")
assert.equal("MemberOne-Stormrage", tostring(bootstrappedHelloPeer.characterKey or ""), "sync hello traffic should canonicalize stored peer keys to Character-Server order")
assert.equal(91, tonumber(bootstrappedHelloPeer.lastSeen or 0), "sync hello traffic should record peers under the promoted live guild instead of Unknown")
assert.equal(nil, ((((bootstrappedHelloDb.syncState or {}).peers or {})["Unknown"] or {})["MemberOne-Stormrage"]), "sync hello traffic should stop recording peers under the Unknown guild bucket once the live guild is known")

local unknownSnapshotRoot = ns.modules.defaults.CreateDatabaseRoot("Unknown Guild")
_G.GBankManagerDB = unknownSnapshotRoot
ns.state.dbRoot = unknownSnapshotRoot
ns.state.db = unknownSnapshotRoot.guilds["Unknown Guild"]

local bootstrappedRequestsSnapshotPayload = codec.EncodeTable({
    type = "REQUESTS_SNAPSHOT",
    updatedAt = 92,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "OfficerOne-Stormrage",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        requests = {
            {
                requestId = "req-bootstrap-snapshot-1",
                requester = "MemberOne",
                requesterCharacterKey = "MemberOne-Stormrage",
                itemID = 2001,
                itemName = "Bootstrap Snapshot Oil",
                quantity = 2,
                approval = "PENDING",
                fulfillment = "OPEN",
                createdAt = 92,
                updatedAt = 92,
                createdBy = "OfficerOne",
                updatedBy = "OfficerOne",
            },
        },
    },
})
local bootstrappedRequestsSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", bootstrappedRequestsSnapshotPayload, "GUILD", "OfficerOne-Stormrage")
local bootstrappedRequestsSnapshotDb = ns.modules.store.GetDatabase()
assert.truthy(bootstrappedRequestsSnapshotAccepted, "request snapshot sync should promote the active guild identity before wrong-guild validation runs")
assert.equal("Guild Testers", tostring((((bootstrappedRequestsSnapshotDb or {}).meta or {}).guildName) or ""), "request snapshot sync should promote the local database guild identity from the payload guild key")
assert.equal("Guild Testers", tostring((((ns.state or {}).dbRoot or {}).activeGuildKey) or ""), "request snapshot sync should promote the active guild root key from the payload guild key")
assert.equal(1, #(bootstrappedRequestsSnapshotDb.requests or {}), "request snapshot sync should still replace the local request cache after guild promotion")
assert.equal("REQUEST_CREATED", ((bootstrappedRequestsSnapshotDb.auditLog or {})[#(bootstrappedRequestsSnapshotDb.auditLog or {})] or {}).type, "request snapshot sync should reconstruct created request history when the snapshot is what brings a client up to date")
assert.equal("OfficerOne", ((bootstrappedRequestsSnapshotDb.auditLog or {})[#(bootstrappedRequestsSnapshotDb.auditLog or {})] or {}).actor, "request snapshot history reconstruction should use the remote actor name")

_G.GBankManagerDB = runtimeBeforeGuildBootstrap
ns.state.db = stateDbBeforeGuildBootstrap
ns.state.dbRoot = stateDbRootBeforeGuildBootstrap

_G.C_ChatInfo.sentMessages = {}
db.requests = {}
db.auditLog = {}

db.requests = {
    {
        requestId = "req-local-newer-snapshot",
        requester = "MemberOne",
        requesterCharacterKey = "Stormrage-MemberOne",
        itemID = 2000,
        itemName = "Local Newer Snapshot Oil",
        quantity = 4,
        approval = "PENDING",
        fulfillment = "OPEN",
        createdAt = 100,
        updatedAt = 100,
        createdBy = "MemberOne",
        updatedBy = "MemberOne",
    },
}
local noChangeRequestSnapshotPayload = codec.EncodeTable({
    type = "REQUESTS_SNAPSHOT",
    updatedAt = 501,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        requests = {
            {
                requestId = "req-local-newer-snapshot",
                requester = "MemberOne",
                requesterCharacterKey = "Stormrage-MemberOne",
                itemID = 2000,
                itemName = "Older Snapshot Oil",
                quantity = 4,
                approval = "PENDING",
                fulfillment = "OPEN",
                createdAt = 99,
                updatedAt = 99,
                createdBy = "MemberOne",
                updatedBy = "MemberOne",
            },
        },
    },
})
local chatCountBeforeNoChangeRequestSnapshot = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local noChangeRequestSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", noChangeRequestSnapshotPayload, "GUILD", "OfficerOne")
local noChangeRequestSnapshotPeer = ((((db.syncState or {}).peers or {})["Guild Testers"] or {})["OfficerOne-Stormrage"] or {})
assert.truthy(noChangeRequestSnapshotAccepted, "no-change request snapshots should still be handled as successful sync payloads")
assert.equal("Local Newer Snapshot Oil", (db.requests[1] or {}).itemName, "no-change request snapshots should not overwrite newer local request state")
assert.equal(chatCountBeforeNoChangeRequestSnapshot, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "no-change request snapshots should update peer sync time without printing chat")
assert.equal(501, tonumber(noChangeRequestSnapshotPeer.lastSynchronizedAt or 0), "no-change request snapshots should still update the peer synchronized timestamp")
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
local syncedPeerEntry = ((((db.syncState or {}).peers or {})["Guild Testers"] or {})["MemberOne-Stormrage"] or {})
assert.truthy(tonumber(syncedPeerEntry.lastSynchronizedAt or 0) >= 91, "accepted sync payloads should mark the peer as synchronized")

local forgedRequestPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 92,
    payload = {
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
assert.equal("MemberOne-Stormrage", db.requests[1].requesterCharacterKey, "invalid sync updates should preserve canonical requester character keys")
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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
        guildKey = "Guild Testers",
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

local wrongGuildPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 151,
    payload = {
        guildKey = "Other Guild",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-wrong-guild-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2014,
            itemName = "Wrong Guild Flask",
            quantity = 1,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 151,
        },
    },
})
local wrongGuildAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", wrongGuildPayload, "WHISPER", "MemberOne")
assert.truthy(not wrongGuildAccepted, "sync events should reject request traffic for a different active guild")
assert.equal(requestCountBeforeForgedSender, #db.requests, "mismatched-guild request traffic should not append requests")

local requestCountBeforeWrongDistribution = #db.requests
local wrongDistributionRequestPayload = codec.EncodeTable({
    type = "REQUEST_CREATED",
    updatedAt = 152,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        request = {
            requestId = "req-wrong-distribution-1",
            requester = "MemberOne",
            requesterCharacterKey = "Stormrage-MemberOne",
            itemID = 2015,
            itemName = "Whisper Flask",
            quantity = 1,
            approval = "PENDING",
            fulfillment = "OPEN",
            updatedAt = 152,
        },
    },
})
local wrongDistributionRequestAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", wrongDistributionRequestPayload, "WHISPER", "MemberOne")
assert.truthy(not wrongDistributionRequestAccepted, "sync events should reject non-guild request traffic even when the guild key matches")
assert.equal(requestCountBeforeWrongDistribution, #db.requests, "wrong-distribution request traffic should not append requests")

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
local authAuditCountBefore = #(db.auditLog or {})
local previousDefaultQuantity = (((db.ui or {}).minimumSettings or {}).defaultQuantity)
local authSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteAuthPayload, "GUILD", "GuildLead")
assert.truthy(not authSnapshotAccepted, "sync events should ignore retired auth policy snapshot traffic from addon comms")
assert.truthy(
    (db.auth.blacklist["Stormrage-Troublemaker"] == nil)
        and (db.auth.blacklistHashes[ns.modules.permissions.HashCharacterKey("Stormrage-Troublemaker")] ~= true),
    "sync events should leave guild auth policy authority with Guild Info instead of addon comms"
)
assert.equal(previousDefaultQuantity, (((db.ui or {}).minimumSettings or {}).defaultQuantity), "ignored auth policy snapshots should not mutate shared restock defaults")
assert.equal(authAuditCountBefore, #(db.auditLog or {}), "ignored auth policy snapshots should not append auth-policy history")

db.minimums = {}
db.auditLog = {}
local remoteMinimumSnapshotPayload = codec.EncodeTable({
    type = "MINIMUMS_SNAPSHOT",
    updatedAt = 205,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        minimums = {
            {
                itemID = 243734,
                itemName = "Thalassian Phoenix Oil",
                quantity = 100,
                scope = "TAB",
                tabName = "Alchemy",
                enabled = true,
                updatedAt = 205,
                updatedBy = "Stormrage-OfficerOne",
                updatedByRankIndex = 1,
            },
        },
    },
})
local officerMinimumAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteMinimumSnapshotPayload, "GUILD", "OfficerOne")
assert.truthy(officerMinimumAccepted, "sync events should accept officer-authored minimum snapshots")
assert.equal(1, #(db.minimums or {}), "accepted minimum snapshots should replace the local minimum cache")
assert.equal(243734, ((db.minimums or {})[1] or {}).itemID, "accepted minimum snapshots should persist shared minimum item ids")
assert.equal("MINIMUM_CREATED", ((db.auditLog or {})[#(db.auditLog or {})] or {}).type, "accepted remote minimum snapshots should reconstruct created minimum history rows locally")
assert.equal("Thalassian Phoenix Oil", ((db.auditLog or {})[#(db.auditLog or {})] or {}).itemName, "accepted remote minimum snapshots should preserve the created minimum item name in history")
assert.equal("OfficerOne", ((db.auditLog or {})[#(db.auditLog or {})] or {}).actor, "accepted remote minimum snapshots should use the remote actor name in reconstructed history rows")
local minimumAuditCountBeforeDuplicateSnapshot = #(db.auditLog or {})
local chatCountBeforeDuplicateMinimumSnapshot = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local duplicateMinimumSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", remoteMinimumSnapshotPayload, "GUILD", "OfficerOne")
assert.truthy(duplicateMinimumSnapshotAccepted, "replayed minimum snapshots should still count as handled accepted messages")
assert.equal(minimumAuditCountBeforeDuplicateSnapshot, #(db.auditLog or {}), "replayed no-change minimum snapshots should not append duplicate history rows")
assert.equal(chatCountBeforeDuplicateMinimumSnapshot, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "replayed no-change minimum snapshots should update sync state without printing chat")

local originalMinimumSnapshotSend = ns.modules.syncTransport.Send
local reciprocalMinimumMessages = {}
ns.modules.syncTransport.Send = function(_, _, message)
    reciprocalMinimumMessages[#reciprocalMinimumMessages + 1] = message
    return codec.EncodeTable(message)
end
db.minimums = {
    {
        itemID = 23529,
        itemName = "Adamantite Sharpening Stone",
        quantity = 20,
        scope = "TAB",
        tabName = "Raid Buffet",
        enabled = true,
        updatedAt = 1780532026,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
    },
    {
        itemID = 240983,
        itemName = "Indecipherable Eversong Diamond",
        quantity = 5,
        scope = "TAB",
        tabName = "Gems and Chants",
        enabled = true,
        updatedAt = 1780669182,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
    },
    {
        itemID = 240971,
        itemName = "Stoic Eversong Diamond",
        quantity = 5,
        scope = "TAB",
        tabName = "Gems and Chants",
        enabled = false,
        updatedAt = 1780669182,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
    },
}
db.auditLog = {}
local staleMinimumSnapshotPayload = codec.EncodeTable({
    type = "MINIMUMS_SNAPSHOT",
    updatedAt = 1780670000,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        minimums = {
            {
                itemID = 23529,
                itemName = "Adamantite Sharpening Stone",
                quantity = 20,
                scope = "TAB",
                tabName = "Raid Buffet",
                enabled = true,
                updatedAt = 1780532026,
                updatedBy = "Stormrage-OfficerOne",
                updatedByRankIndex = 1,
            },
        },
    },
})
local staleMinimumSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", staleMinimumSnapshotPayload, "GUILD", "OfficerOne")
assert.truthy(staleMinimumSnapshotAccepted, "stale minimum snapshots should still be handled from authorized officers")
assert.equal(3, #(db.minimums or {}), "stale minimum snapshots should not erase newer local minimum rows that the sender is missing")
assert.equal(240983, ((db.minimums or {})[2] or {}).itemID, "newer local minimum rows should be preserved after stale snapshot receive")
assert.equal(1, #reciprocalMinimumMessages, "receiving a stale minimum snapshot should reply with the fuller local snapshot")
assert.equal("MINIMUMS_SNAPSHOT", reciprocalMinimumMessages[1].type, "minimum catch-up replies should use the existing snapshot family")
assert.truthy(((reciprocalMinimumMessages[1].payload or {}).syncReply == true), "minimum catch-up replies should be marked to avoid reply loops")
assert.equal(3, #(((reciprocalMinimumMessages[1].payload or {}).minimums) or {}), "minimum catch-up replies should include the fuller local rule set")

reciprocalMinimumMessages = {}
local staleMinimumReplyPayload = codec.EncodeTable({
    type = "MINIMUMS_SNAPSHOT",
    updatedAt = 1780670001,
    payload = {
        guildKey = "Guild Testers",
        syncReply = true,
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        minimums = {
            {
                itemID = 23529,
                itemName = "Adamantite Sharpening Stone",
                quantity = 20,
                scope = "TAB",
                tabName = "Raid Buffet",
                enabled = true,
                updatedAt = 1780532026,
                updatedBy = "Stormrage-OfficerOne",
                updatedByRankIndex = 1,
            },
        },
    },
})
local staleMinimumReplyAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", staleMinimumReplyPayload, "GUILD", "OfficerOne")
local staleMinimumReplyPeer = ((((db.syncState or {}).peers or {})["Guild Testers"] or {})["OfficerOne-Stormrage"] or {})
assert.truthy(staleMinimumReplyAccepted, "minimum sync replies should still be accepted")
assert.equal(0, #reciprocalMinimumMessages, "minimum sync replies should not trigger another reply loop")
assert.equal(1780670001, tonumber(staleMinimumReplyPeer.lastSynchronizedAt or 0), "no-change minimum replies should still update the peer synchronized timestamp")
ns.modules.syncTransport.Send = originalMinimumSnapshotSend
db.minimums = {
    {
        itemID = 243734,
        itemName = "Thalassian Phoenix Oil",
        quantity = 100,
        scope = "TAB",
        tabName = "Alchemy",
        enabled = true,
        updatedAt = 205,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
    },
}

db.auditLog = {
    { type = "LEDGER_IMPORTED", category = "LEDGER", itemName = "Hidden Ledger Row", actor = "Bank", timestamp = 150 },
}
local visibleHistorySnapshotPayload = codec.EncodeTable({
    type = "HISTORY_SNAPSHOT",
    updatedAt = 205,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        entries = {
            {
                category = "MINIMUM",
                type = "MINIMUM_CREATED",
                actor = "OfficerOne",
                itemID = 243734,
                itemName = "History Snapshot Oil",
                newValue = "100",
                timestamp = 205,
            },
            {
                category = "REQUEST",
                type = "REQUEST_CREATED",
                actor = "MemberOne",
                requestId = "req-history-snapshot-1",
                itemID = 243735,
                itemName = "History Snapshot Flask",
                quantity = 2,
                newValue = "PENDING",
                timestamp = 204,
            },
            {
                category = "LEDGER",
                type = "LEDGER_IMPORTED",
                actor = "Bank",
                itemName = "Hidden Ledger Row",
                timestamp = 203,
            },
        },
    },
})
local historySnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", visibleHistorySnapshotPayload, "GUILD", "OfficerOne")
assert.truthy(historySnapshotAccepted, "sync events should accept visible history snapshots from authorized guild peers")
assert.equal(3, #(db.auditLog or {}), "accepted history snapshots should append only the visible history rows and preserve local hidden audit rows")
assert.equal("MINIMUM_CREATED", ((db.auditLog or {})[2] or {}).type, "accepted history snapshots should append visible minimum history rows")
assert.equal("REQUEST_CREATED", ((db.auditLog or {})[3] or {}).type, "accepted history snapshots should append visible request history rows")
local historyAuditCountBeforeDuplicateSnapshot = #(db.auditLog or {})
local chatCountBeforeDuplicateHistorySnapshot = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local duplicateHistorySnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", visibleHistorySnapshotPayload, "GUILD", "OfficerOne")
assert.truthy(duplicateHistorySnapshotAccepted, "replayed history snapshots should still count as handled accepted messages")
assert.equal(historyAuditCountBeforeDuplicateSnapshot, #(db.auditLog or {}), "replayed no-change history snapshots should not append duplicate visible history rows")
assert.equal(chatCountBeforeDuplicateHistorySnapshot, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "replayed no-change history snapshots should update sync state without printing chat")

local memberMinimumPayload = codec.EncodeTable({
    type = "MINIMUMS_SNAPSHOT",
    updatedAt = 206,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        minimums = {
            {
                itemID = 7007,
                itemName = "Algari Mana Oil",
                quantity = 250,
                scope = "TAB",
                tabName = "Reagents",
                enabled = true,
                updatedAt = 206,
                updatedBy = "Stormrage-MemberOne",
                updatedByRankIndex = 2,
            },
        },
    },
})
local memberMinimumAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", memberMinimumPayload, "GUILD", "MemberOne")
assert.truthy(not memberMinimumAccepted, "sync events should reject member-authored minimum snapshots")
assert.equal(243734, ((db.minimums or {})[1] or {}).itemID, "rejected minimum snapshots should leave the local minimum cache unchanged")

local requestSnapshotCountBeforeSenderMismatch = #(db.requests or {})
local senderMismatchRequestsSnapshotPayload = codec.EncodeTable({
    type = "REQUESTS_SNAPSHOT",
    updatedAt = 206,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        requests = {
            {
                requestId = "req-sender-mismatch-snapshot-1",
                requester = "MemberOne",
                requesterCharacterKey = "Stormrage-MemberOne",
                itemID = 243734,
                itemName = "Snapshot Sender Mismatch Oil",
                quantity = 2,
                approval = "PENDING",
                fulfillment = "OPEN",
                updatedAt = 206,
                createdAt = 206,
            },
        },
    },
})
local senderMismatchRequestsSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", senderMismatchRequestsSnapshotPayload, "GUILD", "DifferentSender")
assert.truthy(not senderMismatchRequestsSnapshotAccepted, "sync events should reject request snapshots whose actor context does not match the sender")
assert.equal(requestSnapshotCountBeforeSenderMismatch, #(db.requests or {}), "sender-mismatch request snapshots should not mutate the local request cache")
assert.equal("requests_snapshot", tostring((((ns.state or {}).lastSyncDecision or {}).category) or ""), "rejected request snapshots should record the debug decision category")
assert.equal("actor_sender_mismatch", tostring((((ns.state or {}).lastSyncDecision or {}).reason) or ""), "rejected request snapshots should record the debug reject reason")

local wrongDistributionMinimumPayload = codec.EncodeTable({
    type = "MINIMUMS_SNAPSHOT",
    updatedAt = 206,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        minimums = {
            {
                itemID = 8888,
                itemName = "Whisper Minimum",
                quantity = 10,
                scope = "TAB",
                tabName = "Alchemy",
                enabled = true,
                updatedAt = 206,
                updatedBy = "Stormrage-OfficerOne",
                updatedByRankIndex = 1,
            },
        },
    },
})
local wrongDistributionMinimumAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", wrongDistributionMinimumPayload, "WHISPER", "OfficerOne")
assert.truthy(not wrongDistributionMinimumAccepted, "sync events should reject minimum snapshots delivered outside the guild channel")
assert.equal(243734, ((db.minimums or {})[1] or {}).itemID, "wrong-distribution minimum snapshots should leave the local minimum cache unchanged")

local requestSnapshotCountBeforeWrongDistribution = #(db.requests or {})
local wrongDistributionRequestsSnapshotPayload = codec.EncodeTable({
    type = "REQUESTS_SNAPSHOT",
    updatedAt = 206,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "OfficerOne",
        },
        requests = {
            {
                requestId = "req-wrong-distribution-snapshot-1",
                requester = "MemberOne",
                requesterCharacterKey = "Stormrage-MemberOne",
                itemID = 243734,
                itemName = "Snapshot Whisper Oil",
                quantity = 2,
                approval = "PENDING",
                fulfillment = "OPEN",
                updatedAt = 206,
                createdAt = 206,
            },
        },
    },
})
local wrongDistributionRequestsSnapshotAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", wrongDistributionRequestsSnapshotPayload, "WHISPER", "OfficerOne")
assert.truthy(not wrongDistributionRequestsSnapshotAccepted, "sync events should reject request snapshots delivered outside the guild channel")
assert.equal(requestSnapshotCountBeforeWrongDistribution, #(db.requests or {}), "wrong-distribution request snapshots should not mutate the local request cache")

db.bankLedger = db.bankLedger or {}
db.bankLedger.itemLogs = {}
db.bankLedger.moneyLogs = {}
db.bankLedger.lastScanAt = 999
local currentAddonVersion = tostring((ns.constants or {}).ADDON_VERSION or "1.1.1")
local currentLedgerProtocol = tonumber((ns.constants or {}).LEDGER_PROTOCOL_VERSION or 0) or 0
local oldLedgerManifestPayload = codec.EncodeTable({
    type = "LEDGER_MANIFEST",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = currentAddonVersion,
        ledgerProtocol = 1,
        manifest = {
            ledgerProtocol = 1,
            totalCount = 0,
            buckets = {},
        },
    },
})
local oldLedgerManifestAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", oldLedgerManifestPayload, "GUILD", "MemberOne")
assert.truthy(not oldLedgerManifestAccepted, "sync events should reject ledger manifests from older ledger protocols")
assert.equal("ledger_manifest", tostring(((ns.state or {}).lastSyncDecision or {}).category or ""), "old-protocol manifest rejection should record the manifest decision category")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "old-protocol manifest rejection should record the protocol reason")

local missingProtocolManifestPayload = codec.EncodeTable({
    type = "LEDGER_MANIFEST",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        version = currentAddonVersion,
        manifest = {
            totalCount = 0,
            buckets = {},
        },
    },
})
local missingProtocolManifestAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", missingProtocolManifestPayload, "GUILD", "MemberOne")
assert.truthy(not missingProtocolManifestAccepted, "sync events should reject ledger manifests that do not advertise a ledger protocol")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "missing-protocol manifest rejection should record the protocol reason")

local oldLedgerDeltaPayload = codec.EncodeTable({
    type = "LEDGER_DELTA",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        kind = "item",
        ledgerProtocol = currentLedgerProtocol,
        scanStartedAt = 1716573600,
        sourceTabIndex = 1,
        sourceTabName = "Alchemy",
        transactions = {
            {
                type = "deposit",
                who = "MemberOne-Stormrage",
                itemID = 243734,
                itemName = "Old Client Ledger Oil",
                quantity = 4,
                year = 2026,
                month = 5,
                day = 24,
                hour = 9,
            },
        },
    },
})
local ledgerRejectChatCount = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local oldLedgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", oldLedgerDeltaPayload, "GUILD", "MemberOne")
assert.truthy(not oldLedgerAccepted, "sync events should reject ledger deltas from older clients that do not advertise a compatible version")
assert.equal(0, #(db.bankLedger.itemLogs or {}), "older-client ledger deltas should not append remote item-log rows")
assert.equal("older_version", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "older-client ledger rejection should record the version reason")
assert.equal(ledgerRejectChatCount, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "rejected ledger deltas should not add routine ledger chat noise")

local staleProtocolLedgerDeltaPayload = codec.EncodeTable({
    type = "LEDGER_DELTA",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        kind = "item",
        version = currentAddonVersion,
        ledgerProtocol = 2,
        scanStartedAt = 1716573600,
        sourceTabIndex = 1,
        sourceTabName = "Alchemy",
        transactions = {
            {
                type = "deposit",
                who = "MemberOne-Stormrage",
                itemID = 243734,
                itemName = "Stale Protocol Ledger Oil",
                quantity = 4,
                year = 2026,
                month = 5,
                day = 24,
                hour = 9,
            },
        },
    },
})
local staleProtocolLedgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", staleProtocolLedgerDeltaPayload, "GUILD", "MemberOne")
assert.truthy(not staleProtocolLedgerAccepted, "sync events should reject ledger deltas from older protocol-2 clients even when addon versions match")
assert.equal(0, #(db.bankLedger.itemLogs or {}), "stale-protocol ledger deltas should not append remote item-log rows")
assert.equal("old_ledger_protocol", tostring(((ns.state or {}).lastSyncDecision or {}).reason or ""), "stale-protocol ledger delta rejection should record the protocol reason")

local ledgerDeltaPayload = codec.EncodeTable({
    type = "LEDGER_DELTA",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        kind = "item",
        version = currentAddonVersion,
        ledgerProtocol = currentLedgerProtocol,
        scanStartedAt = 1716573600,
        sourceTabIndex = 1,
        sourceTabName = "Alchemy",
        transactions = {
            {
                type = "deposit",
                who = "MemberOne-Stormrage",
                itemID = 243734,
                itemName = "Thalassian Phoenix Oil",
                quantity = 4,
                year = 2026,
                month = 5,
                day = 24,
                hour = 9,
            },
        },
    },
})
local ledgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", ledgerDeltaPayload, "GUILD", "MemberOne")
assert.truthy(ledgerAccepted, "sync events should accept guild ledger deltas from guild peers")
assert.equal(1, #(db.bankLedger.itemLogs or {}), "accepted ledger deltas should append remote item-log rows")
assert.equal(999, tonumber(db.bankLedger.lastScanAt or 0), "remote ledger deltas should not advance the local scan freshness clock")
assert.equal("GBankManager: Synced ledger delta from MemberOne.", last_chat_message(), "ledger deltas should report only when they write actual new rows")
local ledgerChatCountBeforeDuplicate = #(_G.DEFAULT_CHAT_FRAME.messages or {})
local duplicateLedgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", ledgerDeltaPayload, "GUILD", "MemberOne")
assert.truthy(duplicateLedgerAccepted, "duplicate ledger deltas should still be accepted for peer bookkeeping")
assert.equal(1, #(db.bankLedger.itemLogs or {}), "duplicate ledger deltas should not append duplicate ledger rows")
assert.equal(ledgerChatCountBeforeDuplicate, #(_G.DEFAULT_CHAT_FRAME.messages or {}), "duplicate ledger deltas should not spam chat when they merge no new rows")

local wrongDistributionLedgerPayload = codec.EncodeTable({
    type = "LEDGER_DELTA",
    updatedAt = 207,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "Stormrage-MemberOne",
            guildRankIndex = 2,
            guildRankName = "Raider",
            inGuild = true,
            isGuildMaster = false,
            name = "MemberOne",
        },
        kind = "item",
        version = currentAddonVersion,
        scanStartedAt = 1716573600,
        sourceTabIndex = 1,
        sourceTabName = "Alchemy",
        transactions = {
            {
                type = "deposit",
                who = "MemberOne-Stormrage",
                itemID = 243734,
                itemName = "Whisper Ledger Oil",
                quantity = 1,
                year = 2026,
                month = 5,
                day = 24,
                hour = 9,
            },
        },
    },
})
local wrongDistributionLedgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", wrongDistributionLedgerPayload, "WHISPER", "MemberOne")
assert.truthy(not wrongDistributionLedgerAccepted, "sync events should reject ledger deltas delivered outside the guild channel")
assert.equal(1, #(db.bankLedger.itemLogs or {}), "wrong-distribution ledger deltas should not append remote item-log rows")

local localLedgerPayload = codec.EncodeTable({
    type = "LEDGER_DELTA",
    updatedAt = 208,
    payload = {
        guildKey = "Guild Testers",
        actorContext = {
            characterKey = "SyncTester-Stormrage",
            guildRankIndex = 1,
            guildRankName = "Officer",
            inGuild = true,
            isGuildMaster = false,
            name = "SyncTester",
        },
        kind = "item",
        version = currentAddonVersion,
        scanStartedAt = 1716573610,
        sourceTabIndex = 1,
        sourceTabName = "Alchemy",
        transactions = {
            {
                type = "deposit",
                who = "SyncTester-Stormrage",
                itemID = 243734,
                itemName = "Thalassian Phoenix Oil",
                quantity = 1,
                year = 2026,
                month = 5,
                day = 24,
                hour = 9,
            },
        },
    },
})
local selfLedgerAccepted = _G.FireEvent("CHAT_MSG_ADDON", "GBankManager", localLedgerPayload, "GUILD", "SyncTester")
assert.truthy(selfLedgerAccepted == false, "sync events should ignore self-origin ledger deltas")
assert.equal(1, #(db.bankLedger.itemLogs or {}), "ignored self-origin ledger deltas should not append duplicate local item-log rows")
assert.equal(nil, (((db.syncState or {}).peers or {})["Guild Testers"] or {})["SyncTester-Stormrage"], "ignored self-origin sync payloads should not be recorded in peer history")
assert.truthy(string.find(last_chat_message() or "", "Synced ledger delta from SyncTester", 1, true) == nil, "ignored self-origin ledger deltas should not report accepted-sync chat noise")

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

local originalGetNumGuildBankTabs = _G.GetNumGuildBankTabs
local originalGetGuildBankTabInfo = _G.GetGuildBankTabInfo
local originalGuildBankFrame = _G.GuildBankFrame
local originalEnum = _G.Enum
local originalPlayerInteractionManager = _G.C_PlayerInteractionManager
local scannerStatusBeforeClosedBankNoise = scanner:GetStatusText()

_G.GetNumGuildBankTabs = function()
    return 8
end
_G.GetGuildBankTabInfo = function(tabIndex)
    return "Tab " .. tostring(tabIndex), nil, true
end
_G.GuildBankFrame = {
    IsShown = function()
        return false
    end,
}
_G.Enum = _G.Enum or {}
_G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {}
_G.Enum.PlayerInteractionType.GuildBanker = 10
_G.C_PlayerInteractionManager = {
    IsInteractingWithNpcOfType = function()
        return false
    end,
}

scanner.scanInProgress = false
scanner.pendingAutoScan = false
scanner.guildBankOpen = false
scanner.autoScanRetryCount = 0
_G.C_Timer.ClearPending()
onEvent(events, "GUILDBANK_UPDATE_TABS")
assert.equal(false, scanner.pendingAutoScan, "guild bank tab updates should not arm an auto scan when the bank is actually closed")
assert.equal(false, scanner.scanInProgress, "guild bank tab updates should not start a scan when the bank is actually closed")
assert.equal(scannerStatusBeforeClosedBankNoise, scanner:GetStatusText(), "closed-bank tab updates should not replace the scanner status with a fake scan")

onEvent(events, "GUILDBANKBAGSLOTS_CHANGED", 1)
assert.equal(false, scanner.pendingAutoScan, "guild bank slot updates should not arm an auto scan when the bank is actually closed")
assert.equal(false, scanner.scanInProgress, "guild bank slot updates should not start a scan when the bank is actually closed")

_G.GetNumGuildBankTabs = originalGetNumGuildBankTabs
_G.GetGuildBankTabInfo = originalGetGuildBankTabInfo
_G.GuildBankFrame = originalGuildBankFrame
_G.Enum = originalEnum
_G.C_PlayerInteractionManager = originalPlayerInteractionManager
