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

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local permissions = ns.modules.permissions
local store = ns.modules.store
local slash = ns.modules.slash
local mainFrame = ns.modules.mainFrame
local scanner = ns.modules.scanner

local db = store.CreateFreshDatabase("Guild Testers")

assert.truthy(type(db.auth) == "table", "fresh databases should include an auth policy container")
assert.truthy(type(db.auth.capabilities) == "table", "fresh databases should include capability allowlists")
assert.truthy(type(db.auth.blacklist) == "table", "fresh databases should include a blacklist table")
assert.equal("GuildLead-Stormrage", permissions.DisplayCharacterKey("Stormrage-GuildLead"), "auth display formatting should render Character-Realm for UI text")
assert.equal("GuildLead-Stormrage", permissions.NormalizeEnteredCharacterKey("GuildLead-Stormrage", "Stormrage"), "blacklist entry normalization should store Character-Server values canonically")
assert.equal(permissions.HashCharacterKey("GuildLead-Stormrage"), permissions.HashCharacterKey("Stormrage-GuildLead"), "blacklist hashing should treat old and new key orderings as the same identity")
db.auth.rankMetadata[0] = { name = "Rank 0", order = 0 }
permissions.NormalizePolicy(db.auth, permissions.GetGuildRankMetadata())
assert.equal("Guild Master", db.auth.rankMetadata[0].name, "live guild rank metadata should overwrite stale saved rank labels")
db.auth.blacklist["Stormrage-Troublemaker"] = {
    name = "Troublemaker",
    reason = "Legacy order",
    updatedAt = 1,
}
permissions.NormalizePolicy(db.auth, permissions.GetGuildRankMetadata())
assert.truthy(db.auth.blacklist["Troublemaker-Stormrage"] ~= nil, "policy normalization should migrate legacy realm-character blacklist keys into Character-Server order")

local guildmasterContext = permissions.GetLivePlayerContext(db)

assert.equal("Stormrage-GuildLead", guildmasterContext.characterKey, "auth should derive a full character key from live player identity")
assert.truthy(guildmasterContext.isGuildMaster, "guildmaster context should be detected from the live rank index")
assert.truthy(permissions.Can(guildmasterContext, "full_ui", db.auth), "guildmaster should always have full ui access")
assert.truthy(permissions.Can(guildmasterContext, "auth_manage", db.auth), "guildmaster should always be able to manage auth")
assert.equal("full_shell", permissions.GetEffectiveAccessProfile(guildmasterContext, db.auth), "guildmaster should resolve to full-shell access")

db.auth.capabilities.auth_manage[1] = true
db.auth.capabilities.request_delete[1] = true
local delegatedAdminContext = {
    characterKey = "Stormrage-OfficerOne",
    name = "OfficerOne",
    guildName = "Guild Testers",
    guildRankName = "Officer",
    guildRankIndex = 1,
    isGuildMaster = false,
    inGuild = true,
}

assert.truthy(permissions.Can(delegatedAdminContext, "auth_manage", db.auth), "delegated admin ranks should be able to manage auth when configured")
assert.truthy(permissions.Can(delegatedAdminContext, "request_delete", db.auth), "delegated admin ranks should be able to delete requests when configured")
assert.truthy(permissions.Can(delegatedAdminContext, "full_ui", db.auth), "officer-equivalent fallback ranks should keep full ui access")

local memberContext = {
    characterKey = "Stormrage-MemberOne",
    name = "MemberOne",
    guildName = "Guild Testers",
    guildRankName = "Raider",
    guildRankIndex = 2,
    isGuildMaster = false,
    inGuild = true,
}

assert.truthy(permissions.Can(memberContext, "request_submit", db.auth), "members should be allowed to submit requests by default")
assert.truthy(not permissions.Can(memberContext, "full_ui", db.auth), "members should not have full shell access by default")
assert.equal("request_only", permissions.GetEffectiveAccessProfile(memberContext, db.auth), "non-blacklisted members should resolve to request-only access")

db.auth.blacklist[memberContext.characterKey] = {
    name = memberContext.name,
    reason = "No addon access",
    updatedAt = 44,
}

assert.truthy(permissions.IsBlacklisted(memberContext, db.auth), "blacklist entries should override normal capability grants")
assert.truthy(not permissions.Can(memberContext, "request_submit", db.auth), "blacklist should remove request submit access")
assert.equal("blocked", permissions.GetEffectiveAccessProfile(memberContext, db.auth), "blacklisted members should resolve to blocked access")

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB

_G.UnitName = function()
    return "MemberOne"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Raider", 2
end

slash.command("ui")
assert.truthy(mainFrame:IsShown(), "adaptive slash ui should still open a window for request-only members")
assert.truthy(mainFrame.requestOnlyMode == true, "adaptive slash ui should open lightweight request access for non-officer members")
assert.equal("REQUESTS", mainFrame.activeView, "adaptive slash ui should route request-only members into the requests surface")
assert.truthy(not mainFrame.requestActionsPanel:IsShown(), "request-only access should not expose officer workflow controls")

_G.GBankManagerDB.auth.capabilities.request_submit = {}
mainFrame:RefreshView()
assert.truthy(mainFrame.requestCreateButton:IsEnabled(), "request-only members should keep the lightweight submit flow when request-submit is allowed")

_G.GBankManagerDB.auth.capabilities.request_submit[1] = true
_G.GBankManagerDB.auth.capabilities.request_submit[2] = nil
mainFrame:RefreshView()
assert.truthy(not mainFrame.requestCreateButton:IsEnabled(), "request-only members should lose submit actions when their rank is not allowed")
assert.equal("You do not have permission to submit requests.", mainFrame.requestCreateStatusText:GetText(), "request-only denied submitters should see a clear read-only banner")

_G.GBankManagerDB.auth.blacklist["Stormrage-MemberOne"] = {
    name = "MemberOne",
    reason = "Blocked",
    updatedAt = 1,
}
mainFrame:Hide()
slash.command("request")
assert.truthy(not mainFrame:IsShown(), "blacklisted players should be denied both request and full ui access")
assert.equal("Access blocked", mainFrame.statusText:GetText(), "blocked access should surface a clear status message")

_G.GBankManagerDB = store.CreateFreshDatabase("Guild Testers")
ns.state.db = _G.GBankManagerDB
_G.UnitName = function()
    return "MemberOne"
end
_G.GetGuildInfo = function()
    return "Guild Testers", "Raider", 2
end
scanner.scanInProgress = false
scanner.BeginScan()
assert.truthy(not scanner.scanInProgress, "non-officer members should not be able to start a guild bank scan")
assert.equal("Permission denied", scanner.statusText, "denied scans should surface a clear status message")

_G.UnitName = function()
    return "GuildLead"
end

_G.GetRealmName = function()
    return "Stormrage"
end

_G.GetGuildInfo = function()
    return "Guild Testers", "Guild Master", 0
end
