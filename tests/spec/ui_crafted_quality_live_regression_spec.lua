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
    "Professions-Icon-Quality-12-Tier2-Inv",
    (mainFrame.tableRowsData[1] or {}).tierIconAtlas,
    "minimums rows should keep the canonical bundled gold-pentagram atlas even when the client reports a different live reagent-quality family"
)
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    (((((mainFrame.tableRows or {})[1] or {}).columnIcons or {})[2] or {}).atlas),
    "minimums should render the canonical bundled gold-pentagram atlas through the shared texture path when live reagent-quality data disagrees"
)
assert.equal(
    "Flask of the Magisters",
    tostring((((mainFrame.tableRows or {})[1] or {}).columns or {})[2] and ((((mainFrame.tableRows or {})[1] or {}).columns or {})[2]:GetText()) or ""),
    "minimums should keep the shared item display text visible while the crafted-quality icon renders through the dedicated texture path"
)

mainFrame:SelectView("REQUESTS")
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    (mainFrame.tableRowsData[1] or {}).tierAtlas,
    "requests rows should rebuild two-rank icons from the canonical bundled gold-pentagram atlas when saved request rows omit craftedQualityMax"
)
assert.equal(
    "",
    tostring((mainFrame.tableRowsData[1] or {}).tier or ""),
    "requests rows should keep the tier text empty when the dedicated texture atlas is available"
)

mainFrame:OpenRequestDetailsModal("request-live-tier")
assert.equal(
    "Flask of the Shattered Sun",
    mainFrame.requestDetailsItemNameText:GetText(),
    "request details should keep the item name visible after live crafted-quality backfill"
)
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    (mainFrame.requestDetailsQualityIcon or {}).atlas,
    "request details should render the canonical bundled gold-pentagram atlas beside the shared item display"
)
assert.truthy(
    mainFrame.requestDetailsQualityIcon and mainFrame.requestDetailsQualityIcon:IsShown(),
    "request details should show the crafted-quality icon inline beside the shared item display"
)

mainFrame:SelectView("EXPORTS")
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    (mainFrame.tableRowsData[1] or {}).itemTierAtlas,
    "exports rows should prefer the canonical bundled gold-pentagram atlas when the live reagent-quality payload exposes a different family"
)
