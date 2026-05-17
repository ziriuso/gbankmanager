local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

_G.UnitName = function()
    return "GuildLead"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Guild Master", 0
end

_G.GuildControlGetNumRanks = function()
    return 3
end

_G.GuildControlGetRankName = function(index)
    local names = {
        [1] = "Guild Master",
        [2] = "Officer",
        [3] = "Raider",
    }

    return names[index]
end

_G.guildInfoText = ""
_G.GetGuildInfoText = function()
    return _G.guildInfoText
end

_G.SetGuildInfoText = function(text)
    _G.guildInfoText = text
    return true
end

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local permissions = ns.modules.permissions
local source = ns.modules.authPolicySource
local store = ns.modules.store
local slash = ns.modules.slash

assert.truthy(type(source) == "table", "auth source module should load from the addon toc")

local db = store.CreateFreshDatabase("Guild Testers")
_G.GBankManagerDB = db
ns.state.db = db
local context = permissions.GetLivePlayerContext(db)

permissions.SetCapabilityRank(db.auth, "full_ui", 1, true)
permissions.SetCapabilityRank(db.auth, "auth_manage", 1, true)
permissions.SetCapabilityRank(db.auth, "request_delete", 1, true)
permissions.UpsertBlacklist(db.auth, "Stormrage-Troublemaker", "Troublemaker", "Blocked", 44)
db.auth.restockDefault = 250
permissions.StampPolicy(db.auth, context, 111)

local exportString = source.ExportPolicyString(db.auth)
assert.truthy(type(exportString) == "string" and (string.find(exportString, "[GBMAUTH:", 1, true) ~= nil or string.find(exportString, "gbm^", 1, true) ~= nil), "auth source export should generate a guild-info snippet")

local decodedPolicy = source.DecodePolicyString(exportString)
assert.equal(db.auth.revision, decodedPolicy.revision, "auth source export should preserve revisions")
assert.truthy(string.find(exportString, "Stormrage%-GuildLead", 1, false) == nil, "auth source export should not store the full updater name in the compact guild-info string")
assert.equal(permissions.HashCharacterKey("Stormrage-GuildLead"), decodedPolicy.updatedByHash, "auth source export should preserve the compact updater hash")
assert.equal(250, decodedPolicy.restockDefault, "auth source export should preserve the shared restock default")
assert.truthy(next(decodedPolicy.blacklistHashes or {}) == nil, "auth source export should no longer store blacklist membership in Guild Info")
assert.truthy(decodedPolicy.capabilities.full_ui[1] == true, "auth source export should preserve capability rank masks")
assert.truthy(decodedPolicy.capabilities.request_delete[1] == true, "auth source export should preserve the request-delete capability")

local olderGuildDb = store.CreateFreshDatabase("Guild Testers")
permissions.StampPolicy(olderGuildDb.auth, context, 90)
olderGuildDb.auth.revision = 0
local olderGuildString = source.ExportPolicyString(olderGuildDb.auth)

local appliedOlder, olderReason = source.ApplyPolicyString(db, olderGuildString)
assert.truthy(appliedOlder == false, "older durable revisions should not overwrite newer local auth state")
assert.equal("stale_revision", olderReason, "older durable revisions should report a stale-revision rejection")

db.auth.revision = 0
db.auth.capabilities.full_ui[1] = nil
db.auth.blacklist = {}
db.auth.blacklistHashes = {}
db.ui.minimumSettings.defaultQuantity = 100
db.auditLog = {}

local appliedNewer, newerReason = source.ApplyPolicyString(db, exportString)
assert.truthy(appliedNewer, "newer durable revisions should apply to the local cache")
assert.equal("applied", newerReason, "newer durable revisions should report a successful apply")
assert.equal(decodedPolicy.revision, db.auth.revision, "applied durable policy should set the local revision")
assert.equal("Stormrage-GuildLead", db.auth.updatedBy, "applied durable policy should restore the last-updated actor identity")
assert.equal(permissions.HashCharacterKey("Stormrage-GuildLead"), db.auth.updatedByHash, "applied durable policy should keep the updater hash alongside the local actor identity")
assert.equal(250, db.ui.minimumSettings.defaultQuantity, "applied durable policy should restore the shared restock default into options settings")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "applied durable policy should restore rank capability masks")
assert.truthy(next(db.auth.blacklistHashes or {}) == nil, "applied durable policy should not restore blacklist membership from Guild Info")
assert.equal("AUTH_POLICY_UPDATED", db.auditLog[1].type, "applying a newer durable policy should append an auth-policy history entry")
assert.equal("OPTIONS", db.auditLog[1].category, "auth-policy history entries should appear in the options category")

local cachedBlacklistDb = store.CreateFreshDatabase("Guild Testers")
cachedBlacklistDb.auth.blacklist = {}
cachedBlacklistDb.auth.blacklistHashes = {}
cachedBlacklistDb.auth.blacklistDirectory = {
    [permissions.HashCharacterKey("Ziriously-Stormrage")] = {
        characterKey = "Ziriously-Stormrage",
        name = "Ziriously",
        reason = "Abused System",
        updatedAt = 77,
        hash = permissions.HashCharacterKey("Ziriously-Stormrage"),
    },
}
cachedBlacklistDb.ui.minimumSettings.defaultQuantity = 100
cachedBlacklistDb.auditLog = {}

local cachedPolicyDb = store.CreateFreshDatabase("Guild Testers")
permissions.UpsertBlacklist(cachedPolicyDb.auth, "Ziriously-Stormrage", "Ziriously", "Abused System", 77)
permissions.StampPolicy(cachedPolicyDb.auth, context, 222)
local cachedPolicyString = source.ExportPolicyString(cachedPolicyDb.auth)

local cachedApplied, cachedReason = source.ApplyPolicyString(cachedBlacklistDb, cachedPolicyString)
assert.truthy(cachedApplied, "compact policy import should rehydrate blacklist details from the learned local hash directory")
assert.equal("applied", cachedReason, "compact policy import should report a successful apply when it uses the learned local hash directory")
assert.truthy(next(cachedBlacklistDb.auth.blacklist or {}) == nil, "compact policy import should not restore active blacklist membership from Guild Info now that officer notes are the shared source of truth")

_G.guildInfoText = "Guild rules\n" .. exportString .. "\nHave fun"
_G.C_GuildInfo.infoText = _G.guildInfoText
db.auth.revision = 0
db.auth.capabilities.full_ui[1] = nil
db.auth.blacklist = {}
db.auth.blacklistHashes = {}
db.ui.minimumSettings.defaultQuantity = 100

local pulled, pullReason = source.PullPolicyFromGuildInfo(db)
assert.truthy(pulled, "guild-info pull should apply an embedded auth snippet")
assert.equal("applied", pullReason, "guild-info pull should report a successful apply")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "guild-info pull should restore capability state")
assert.equal(250, db.ui.minimumSettings.defaultQuantity, "guild-info pull should restore the shared restock default into options settings")

local slashExport = slash.command("auth export")
assert.truthy(type(slashExport) == "string" and string.find(slashExport, "[GBMAUTH:", 1, true) ~= nil, "slash auth export should return the durable guild-info snippet")

local pushed = slash.command("auth push")
assert.truthy(type(pushed) == "string" and string.find(_G.guildInfoText, pushed, 1, true) ~= nil, "slash auth push should write or refresh the durable snippet in guild info text")

local originalCGuildInfo = _G.C_GuildInfo
local originalSetGuildInfoText = _G.SetGuildInfoText
_G.C_GuildInfo = nil
_G.SetGuildInfoText = function(text)
    _G.guildInfoText = text
end

local legacyWriteOk, legacyWriteReason, legacyPolicyString = source.PushPolicyToGuildInfo(db)
assert.truthy(legacyWriteOk == true, "auth source push should treat the legacy Guild Info write shim as a successful write when it does not return false")
assert.equal("written", legacyWriteReason, "auth source push should report a successful legacy Guild Info write")
assert.truthy(type(legacyPolicyString) == "string" and string.find(_G.guildInfoText, legacyPolicyString, 1, true) ~= nil, "auth source push should still refresh guild info text through the legacy write shim")

_G.C_GuildInfo = originalCGuildInfo
_G.SetGuildInfoText = originalSetGuildInfoText

_G.guildInfoText = "Guild rules only"
_G.C_GuildInfo.infoText = _G.guildInfoText
local beforeBlockedWrite = _G.guildInfoText
_G.C_GuildInfo.SetInfoText = function(_text)
end
_G.SetGuildInfoText = function(_text)
end

local blockedWriteOk, blockedWriteReason = source.PushPolicyToGuildInfo(db)
assert.truthy(blockedWriteOk == false, "auth source push should fail when the Guild Info write API call does not actually change the live guild info text")
assert.equal("write_failed", blockedWriteReason, "auth source push should report an unverified Guild Info write as a write failure")
assert.equal(beforeBlockedWrite, _G.guildInfoText, "auth source push should leave guild info text unchanged when the live write call is ignored")

_G.C_GuildInfo.SetInfoText = function(text)
    _G.C_GuildInfo.infoText = text or ""
end
_G.SetGuildInfoText = originalSetGuildInfoText

db.auth.revision = 0
db.auth.capabilities.full_ui[1] = nil
db.auth.blacklist = {}
db.auth.blacklistHashes = {}

local slashApplied = slash.command("auth apply " .. exportString)
assert.equal("applied", slashApplied, "slash auth apply should report success for a newer durable snippet")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "slash auth apply should update the local auth policy")
