local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local chatFilters = ns.modules.chatFilters

_G.GBankManagerDB.ui.logsHistorySettings.muteSilvermoonCitizen = false
assert.truthy(chatFilters.IsMutedAmbientNPC("Silvermoon Citizen") ~= true, "ambient NPC filter should stay disabled until the user enables it")

_G.GBankManagerDB.ui.logsHistorySettings.muteSilvermoonCitizen = true
assert.truthy(chatFilters.IsMutedAmbientNPC("Silvermoon Citizen") == true, "ambient NPC filter should suppress Silvermoon Citizen once the user enables it")
assert.truthy(chatFilters.IsMutedAmbientNPC("Some Other NPC") ~= true, "ambient NPC filter should stay scoped to the curated NPC list")
