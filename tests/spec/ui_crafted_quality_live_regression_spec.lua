package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrame = env.mainFrame

_G.C_TradeSkillUI = {
    GetItemReagentQualityInfo = function(itemInfo)
        local itemID = tonumber(itemInfo)
        if itemID == 241322 or itemID == 241326 then
            return {
                quality = 2,
                iconChat = "Live-Chat-TwoTier-Gold",
                iconSmall = "Live-Small-TwoTier-Gold",
                iconInventory = "Live-Inventory-TwoTier-Gold",
            }
        end

        return nil
    end,
}

_G.GBankManagerDB = {
    currentSnapshotId = "crafted-quality-live",
    snapshots = {
        ["crafted-quality-live"] = {
            items = {
                [241322] = {
                    itemID = 241322,
                    name = "Flask of the Magisters",
                    totalCount = 0,
                    tabs = { ["Raid Buffet"] = 0 },
                    craftedQuality = 1,
                    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
                },
                [241326] = {
                    itemID = 241326,
                    name = "Flask of the Shattered Sun",
                    totalCount = 0,
                    tabs = { ["Raid Buffet"] = 0 },
                    craftedQuality = 1,
                    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
                },
            },
        },
    },
    minimums = {
        {
            itemID = 241322,
            itemName = "Flask of the Magisters",
            quantity = 10,
            enabled = true,
            scope = "TAB",
            tabName = "Raid Buffet",
        },
    },
    requests = {
        {
            requestId = "request-live-tier",
            requester = "Zirleficent",
            itemID = 241326,
            itemName = "Flask of the Shattered Sun",
            quantity = 20,
            approval = "PENDING",
            fulfillment = "OPEN",
            createdAt = 1,
            craftedQuality = 1,
            craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
        },
    },
    auditLog = {},
    ui = {
        minimumSettings = {
            defaultQuantity = 100,
        },
    },
}
env.ns.state.db = _G.GBankManagerDB

mainFrame:SelectView("MINIMUMS")
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    (mainFrame.tableRowsData[1] or {}).tierIconAtlas,
    "minimums rows should keep bundled crafted-quality metadata authoritative when saved rows disagree"
)
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    (((((mainFrame.tableRows or {})[1] or {}).columnIcons or {})[2] or {}).atlas),
    "minimums should render the bundled authoritative two-rank atlas through the shared texture path"
)
assert.equal(
    "",
    tostring((((mainFrame.tableRows or {})[1] or {}).columns or {})[2] and ((((mainFrame.tableRows or {})[1] or {}).columns or {})[2]:GetText()) or ""),
    "minimums should not fall back to inline crafted-quality markup once the dedicated texture path is available"
)

mainFrame:SelectView("REQUESTS")
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    (mainFrame.tableRowsData[1] or {}).tierAtlas,
    "requests rows should rebuild two-rank icons from bundled item data even when saved request rows omit craftedQualityMax"
)
assert.equal(
    "",
    tostring((mainFrame.tableRowsData[1] or {}).tier or ""),
    "requests rows should keep the tier text empty when the dedicated texture atlas is available"
)

mainFrame:OpenRequestDetailsModal("request-live-tier")
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    mainFrame.requestDetailsQualityIcon.atlas,
    "request details should use the same bundled two-rank atlas family as inventory and requests rows even when the saved request row still carries the stale silver tier icon"
)
assert.truthy(
    (mainFrame.requestDetailsQualityIcon and mainFrame.requestDetailsQualityIcon:IsShown()) == true,
    "request details should render quality through the dedicated texture path"
)

mainFrame:SelectView("EXPORTS")
assert.equal(
    "Interface-Crafting-ReagentQuality-2-Med",
    (mainFrame.tableRowsData[1] or {}).itemTierAtlas,
    "exports rows should keep bundled crafted-quality metadata authoritative even when the live client reports a different atlas"
)
