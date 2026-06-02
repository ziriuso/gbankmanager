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

local function current_runtime_db()
    return env.ns.state.db or _G.GBankManagerDB or {}
end

local function capture_sync_calls(callback)
    local transport = env.ns.modules.syncTransport
    local originalSend = transport and transport.Send
    local sendCalls = {}

    transport.Send = function(distribution, target, message)
        sendCalls[#sendCalls + 1] = {
            distribution = distribution,
            target = target,
            message = message,
        }

        if type(originalSend) == "function" then
            return originalSend(distribution, target, message)
        end

        return message
    end

    local ok, result = pcall(callback)
    transport.Send = originalSend
    if not ok then
        error(result)
    end

    return sendCalls, result
end

local db = current_runtime_db()
db.currentSnapshotId = "minimum-sync-ui"
db.snapshots = {
    ["minimum-sync-ui"] = {
        items = {
            [7007] = {
                itemID = 7007,
                name = "Algari Mana Oil",
                totalCount = 5,
                tabs = {
                    Alchemy = 4,
                    ["Gems and Enchants"] = 1,
                },
            },
        },
        itemRows = {
            {
                itemID = 7007,
                name = "Algari Mana Oil",
                quantity = 4,
                tabName = "Alchemy",
                rowKey = "7007|TAB|Alchemy",
            },
        },
    },
}
db.minimums = {}
db.requests = {}
db.ui = db.ui or {}
db.ui.minimumItemCatalog = {
    {
        itemID = 7007,
        name = "Algari Mana Oil",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        itemLink = "|cffffffff|Hitem:7007::::::::80:::::|h[Algari Mana Oil]|h|r",
        itemString = "item:7007::::::::80:::::",
    },
}

mainFrame.minimumPendingDb = nil
mainFrame.minimumPendingRules = {}
mainFrame.minimumPendingDirty = {}
mainFrame.minimumPendingDeleted = {}
mainFrame.selectedMinimumKey = nil
mainFrame:SelectView("MINIMUMS")
mainFrame:RefreshView()

mainFrame.minimumNewButton:GetScript("OnClick")(mainFrame.minimumNewButton)
mainFrame.minimumAddItemIDInput:SetText("7007")
mainFrame.minimumAddItemIDInput:GetScript("OnTextChanged")(mainFrame.minimumAddItemIDInput)
mainFrame.minimumAddButton:GetScript("OnClick")(mainFrame.minimumAddButton)
mainFrame.minimumDetailsBankTabDropdownButton:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownButton)
mainFrame.minimumDetailsBankTabDropdownOptions[1]:GetScript("OnClick")(mainFrame.minimumDetailsBankTabDropdownOptions[1])
mainFrame.minimumDetailsQuantityInput:SetText("100")
mainFrame.minimumDetailsConfirmButton:GetScript("OnClick")(mainFrame.minimumDetailsConfirmButton)

local minimumSyncCalls = capture_sync_calls(function()
    mainFrame.minimumSaveButton:GetScript("OnClick")(mainFrame.minimumSaveButton)
end)

assert.equal(1, #(current_runtime_db().minimums or {}), "saving a staged minimum should persist the new minimum row")
assert.truthy(#minimumSyncCalls >= 1, "saving minimum changes should publish the shared minimum snapshot")
assert.equal("MINIMUMS_SNAPSHOT", (((minimumSyncCalls[1] or {}).message) or {}).type, "minimum sync should use the dedicated minimum snapshot message family")
assert.equal("GUILD", (minimumSyncCalls[1] or {}).distribution, "minimum sync should publish to the guild addon audience")
assert.equal("Guild Testers", (((((minimumSyncCalls[1] or {}).message) or {}).payload or {}).guildKey), "minimum sync should stamp the active guild identity into the snapshot payload")
