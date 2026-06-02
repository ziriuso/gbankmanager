local assert = require("tests.helpers.assert")

local portability = dofile("GBankManager/Domain/MinimumsPortability.lua")

local payload = portability.Export({
    guildName = "Guild Testers",
    minimums = {
        {
            itemID = 2001,
            itemName = "Potion Alpha",
            scope = "TAB",
            tabName = "Alchemy",
            quantity = 25,
            enabled = true,
            itemLink = "|cff1eff00|Hitem:2001::::::::|h[Potion Alpha]|h|r",
            itemString = "item:2001::::::::",
            craftedQuality = 2,
            craftedQualityIcon = "Professions-Icon-Quality-12-Tier2-Inv",
            craftedQualityDisplayAtlas = "Professions-Icon-Quality-12-Tier2-Inv",
            craftedQualityPreferredAtlas = "Professions-Icon-Quality-12-Tier2-Inv",
            craftedQualityMax = 2,
        },
    },
})

assert.truthy(type(payload) == "string" and payload ~= "", "minimums export should return a JSON payload string")
assert.truthy(string.find(payload, "\"schema\":\"gbankmanager.minimums\"", 1, true) ~= nil, "minimums export should include the portability schema marker")
assert.truthy(string.find(payload, "\"tabName\":\"Alchemy\"", 1, true) ~= nil, "minimums export should include the tab name for TAB-scoped rules")

local parsedReady = portability.Parse(payload, { "Alchemy", "Cooking" })
assert.truthy(parsedReady.ok, "minimums parser should accept exported payloads")
assert.equal(1, #(parsedReady.rows or {}), "minimums parser should return one parsed review row")
assert.equal("ready", parsedReady.rows[1].status, "matching local bank tabs should mark the imported row ready")
assert.equal("Alchemy", parsedReady.rows[1].resolvedTabName, "matching local bank tabs should resolve directly to the imported tab")
assert.equal(true, parsedReady.rows[1].enabled, "parser should preserve enabled state")
assert.equal(25, parsedReady.rows[1].quantity, "parser should preserve quantity")

local parsedMissingTab = portability.Parse(payload, { "Cooking" })
assert.truthy(parsedMissingTab.ok, "parser should still accept portable payloads whose imported tab is missing locally")
assert.equal("needs_tab", parsedMissingTab.rows[1].status, "missing local bank tabs should require reassignment before apply")
assert.equal("", tostring(parsedMissingTab.rows[1].resolvedTabName or ""), "missing local tabs should not auto-resolve to a local bank tab")

local parsedBadSchema = portability.Parse("{\"schema\":\"wrong\",\"version\":1,\"rules\":[]}", { "Alchemy" })
assert.truthy(not parsedBadSchema.ok, "parser should reject unsupported portability schema identifiers")
assert.truthy(type(parsedBadSchema.error) == "string" and parsedBadSchema.error ~= "", "schema parse failures should include an error message")

local parsedMalformed = portability.Parse("{not-json", { "Alchemy" })
assert.truthy(not parsedMalformed.ok, "parser should reject malformed JSON payloads")
assert.truthy(type(parsedMalformed.error) == "string" and parsedMalformed.error ~= "", "malformed payload failures should include an error message")
