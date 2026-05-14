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
permissions.UpsertBlacklist(db.auth, "Stormrage-Troublemaker", "Troublemaker", "Blocked", 44)
permissions.StampPolicy(db.auth, context, 111)

local exportString = source.ExportPolicyString(db.auth)
assert.truthy(type(exportString) == "string" and (string.find(exportString, "[GBMAUTH:", 1, true) ~= nil or string.find(exportString, "gbm^", 1, true) ~= nil), "auth source export should generate a guild-info snippet")

local decodedPolicy = source.DecodePolicyString(exportString)
assert.equal(db.auth.revision, decodedPolicy.revision, "auth source export should preserve revisions")
assert.truthy(decodedPolicy.blacklistHashes[permissions.HashCharacterKey("Stormrage-Troublemaker")] == true, "auth source export should preserve hashed blacklist entries")
assert.truthy(decodedPolicy.capabilities.full_ui[1] == true, "auth source export should preserve capability rank masks")

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

local appliedNewer, newerReason = source.ApplyPolicyString(db, exportString)
assert.truthy(appliedNewer, "newer durable revisions should apply to the local cache")
assert.equal("applied", newerReason, "newer durable revisions should report a successful apply")
assert.equal(decodedPolicy.revision, db.auth.revision, "applied durable policy should set the local revision")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "applied durable policy should restore rank capability masks")
assert.truthy(db.auth.blacklistHashes[permissions.HashCharacterKey("Stormrage-Troublemaker")] == true, "applied durable policy should restore blacklist hashes")

_G.guildInfoText = "Guild rules\n" .. exportString .. "\nHave fun"
_G.C_GuildInfo.infoText = _G.guildInfoText
db.auth.revision = 0
db.auth.capabilities.full_ui[1] = nil
db.auth.blacklist = {}
db.auth.blacklistHashes = {}

local pulled, pullReason = source.PullPolicyFromGuildInfo(db)
assert.truthy(pulled, "guild-info pull should apply an embedded auth snippet")
assert.equal("applied", pullReason, "guild-info pull should report a successful apply")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "guild-info pull should restore capability state")

local slashExport = slash.command("auth export")
assert.truthy(type(slashExport) == "string" and string.find(slashExport, "[GBMAUTH:", 1, true) ~= nil, "slash auth export should return the durable guild-info snippet")

local pushed = slash.command("auth push")
assert.truthy(type(pushed) == "string" and string.find(_G.guildInfoText, pushed, 1, true) ~= nil, "slash auth push should write or refresh the durable snippet in guild info text")

db.auth.revision = 0
db.auth.capabilities.full_ui[1] = nil
db.auth.blacklist = {}
db.auth.blacklistHashes = {}

local slashApplied = slash.command("auth apply " .. exportString)
assert.equal("applied", slashApplied, "slash auth apply should report success for a newer durable snippet")
assert.truthy(db.auth.capabilities.full_ui[1] == true, "slash auth apply should update the local auth policy")
