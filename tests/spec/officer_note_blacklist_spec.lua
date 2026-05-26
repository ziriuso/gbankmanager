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

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local officerNotes = ns.modules.officerNoteBlacklist
local permissions = ns.modules.permissions
local store = ns.modules.store

assert.truthy(type(officerNotes) == "table", "officer-note blacklist module should load from the addon toc")
assert.equal("[GBMBL]", officerNotes.TAG, "officer-note blacklist module should expose the shared guild tag")
assert.truthy(officerNotes.HasTag("[GBMBL]") == true, "officer-note blacklist tags should be detectable in a plain officer note")
assert.truthy(officerNotes.HasTag("Raid bench [GBMBL]") == true, "officer-note blacklist tags should be detectable when appended to freeform notes")
assert.truthy(officerNotes.HasTag("Raid bench") == false, "officer-note blacklist detection should ignore unrelated officer-note text")

local appendedNote, appendedReason = officerNotes.AppendTag("Raid bench")
assert.equal("Raid bench [GBMBL]", appendedNote, "officer-note blacklist append should preserve freeform note text and add the shared tag")
assert.equal("tagged", appendedReason, "officer-note blacklist append should report a successful tag write plan")

local appendedExistingNote, appendedExistingReason = officerNotes.AppendTag("[GBMBL]")
assert.equal("[GBMBL]", appendedExistingNote, "officer-note blacklist append should avoid duplicating an existing tag")
assert.equal("already_tagged", appendedExistingReason, "officer-note blacklist append should report when the tag already exists")

local tooLongNote, tooLongReason = officerNotes.AppendTag("123456789012345678901234")
assert.equal(nil, tooLongNote, "officer-note blacklist append should refuse to overflow Blizzard's 31-character officer-note limit")
assert.equal("note_too_long", tooLongReason, "officer-note blacklist append should report a note-length failure explicitly")

assert.equal("Raid bench", officerNotes.RemoveTag("Raid bench [GBMBL]"), "officer-note blacklist removal should keep the human-authored note text intact")
assert.equal("", officerNotes.RemoveTag("[GBMBL]"), "officer-note blacklist removal should clear a tag-only officer note")
assert.equal("Ziriously-Stormrage", officerNotes.BuildCharacterKeyFromRosterName("Ziriously-Stormrage", "Stormrage"), "officer-note blacklist roster parsing should preserve the addon's Character-Server blacklist key format")
assert.equal("Ziriously-Stormrage", officerNotes.BuildCharacterKeyFromRosterName("Ziriously", "Stormrage"), "officer-note blacklist roster parsing should use the current realm for same-realm roster rows")

local db = store.CreateFreshDatabase("Guild Testers")
db.auth.blacklistDirectory[permissions.HashCharacterKey("Stormrage-Ziriously")] = {
    characterKey = "Stormrage-Ziriously",
    name = "Ziriously",
    reason = "Abused System",
    updatedAt = 77,
    hash = permissions.HashCharacterKey("Stormrage-Ziriously"),
}

_G.C_GuildInfo.canViewOfficerNote = true
_G.GetNumGuildMembers = function()
    return 2
end
_G.GetGuildRosterInfo = function(index)
    if index == 1 then
        return "Ziriously-Stormrage", "Officer", 1, 70, "Mage", "Orgrimmar", "", "Abused System [GBMBL]", true, 0, nil, 0, 0, false, false, nil, "guid-ziriously"
    end

    return "Memberone-Stormrage", "Raider", 2, 70, "Warrior", "Orgrimmar", "", "Bench", true, 0, nil, 0, 0, false, false, nil, "guid-memberone"
end

permissions.RefreshPolicyFromGuild(db)
assert.equal(
    "Abused System",
    ((db.auth.blacklist or {})["Ziriously-Stormrage"] or {}).reason,
    "guild policy refresh should rebuild active blacklist entries from officer-note tags while preserving learned local reasons"
)
assert.truthy(
    ((db.auth.blacklist or {})["Stormrage-Memberone"] or nil) == nil,
    "guild policy refresh should ignore roster members whose officer note does not contain the shared blacklist tag"
)
assert.equal(
    1,
    (((db.auth.blacklistRosterDirectory or {})["Ziriously-Stormrage"] or {}).rosterIndex or 0),
    "guild policy refresh should remember the roster index for later officer-note updates"
)

_G.GuildRosterSetOfficerNoteCalls = {}
_G.C_GuildInfo.setNotes = {}
_G.GetGuildRosterInfo = function(index)
    if index == 1 then
        return "Ziriously-Stormrage", "Officer", 1, 70, "Mage", "Orgrimmar", "", "Raid bench", true, 0, nil, 0, 0, false, false, nil, "guid-ziriously"
    end

    return "Memberone-Stormrage", "Raider", 2, 70, "Warrior", "Orgrimmar", "", "Bench", true, 0, nil, 0, 0, false, false, nil, "guid-memberone"
end
local previousPolicy = {
    blacklist = {},
    blacklistHashes = {},
    blacklistDirectory = {},
    blacklistRosterDirectory = {
        ["Ziriously-Stormrage"] = {
            guid = "guid-ziriously",
            rosterIndex = 1,
            officerNote = "Raid bench",
            isBlacklisted = false,
            updatedAt = 77,
        },
    },
}
local desiredPolicy = {
    blacklist = {
        ["Ziriously-Stormrage"] = {
            name = "Ziriously",
            reason = "Abused System",
            updatedAt = 88,
        },
    },
    blacklistHashes = {},
    blacklistDirectory = {},
    blacklistRosterDirectory = previousPolicy.blacklistRosterDirectory,
}
local applied, reason = officerNotes.ApplyDesiredBlacklistChanges(previousPolicy, desiredPolicy)
assert.truthy(applied == true, "officer-note blacklist save should succeed when a roster-index note writer is available")
assert.equal("written", reason, "officer-note blacklist save should report a completed roster-note write")
assert.equal(0, #(_G.C_GuildInfo.setNotes or {}), "officer-note blacklist save should stop using the restricted guid-based note writer")
assert.equal(1, #(_G.GuildRosterSetOfficerNoteCalls or {}), "officer-note blacklist save should write through GuildRosterSetOfficerNote")
assert.equal(1, ((_G.GuildRosterSetOfficerNoteCalls or {})[1] or {}).index, "officer-note blacklist save should target the roster index of the member being tagged")
assert.equal("Raid bench [GBMBL]", ((_G.GuildRosterSetOfficerNoteCalls or {})[1] or {}).text, "officer-note blacklist save should preserve the existing officer note while appending the shared tag")
