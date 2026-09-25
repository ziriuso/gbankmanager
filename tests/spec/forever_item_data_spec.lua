local assert = require("tests.helpers.assert")

local mainInterface
for line in io.lines("GBankManager/GBankManager.toc") do
    mainInterface = mainInterface or line:match("^## Interface:%s*(.+)$")
end
assert.truthy(mainInterface and mainInterface:find("16001", 1, true), "main addon should declare the Forever beta interface")

local retailInterface
for line in io.lines("GBankManager_ItemData/GBankManager_ItemData.toc") do
    retailInterface = retailInterface or line:match("^## Interface:%s*(.+)$")
end
assert.truthy(retailInterface and not retailInterface:find("16001", 1, true), "Retail item data should remain Retail only")

local foreverToc = "Forever/GBankManager_ItemData/GBankManager_ItemData.toc"
local foreverInterface
for line in io.lines(foreverToc) do
    foreverInterface = foreverInterface or line:match("^## Interface:%s*(.+)$")
end
assert.equal("16001", foreverInterface, "Forever item data should advertise only the Forever beta interface")

local previousNamespace = _G.GBankManagerNamespace
local previousPayload = _G.GBankManagerItemSearchPayload
_G.GBankManagerNamespace = nil
local _, ns = assert.load_addon_from_toc(foreverToc)
local payload = ((ns or {}).data or {}).staticItemSearch or _G.GBankManagerItemSearchPayload
assert.truthy(type(payload) == "table" and payload.metadata.ready == true, "Forever item data should load as a complete search index")
assert.equal("Forever", payload.metadata.target, "Forever item data should retain its source flavor")
assert.equal("1.60.1.70009", payload.metadata.build, "Forever item data should retain its source client build")
assert.truthy(payload.metadata.itemCount >= 1000, "Forever item data should contain a useful item set")
assert.equal("Linen Cloth", payload.itemsByID[2589].name, "Forever item data should include classic reagents")
assert.equal("Peacebloom", payload.itemsByID[2447].name, "Forever item data should include classic herbs")
assert.truthy(type(payload.tokenToItemIDs["linen"]) == "table", "Forever search tokens should index classic reagents")

assert.equal("Worn Shortsword", payload.itemsByID[25].name, "Forever item data should include the Classic Auction House Weapons group")
for _, item in pairs(payload.itemsByID) do
    assert.equal(nil, item.quality, "Forever item data should omit item quality")
    assert.equal(nil, item.qualityName, "Forever item data should omit item quality labels")
    assert.equal(nil, item.craftedQuality, "Forever item data should omit Retail crafted quality")
end

local namespace = loadfile("GBankManager/Core/Namespace.lua")("GBankManager", ns)
assert.equal(true, namespace.IsForever(), "main addon should recognize the Forever data variant")
local itemDisplay = loadfile("GBankManager/Domain/ItemDisplay.lua")("GBankManager", namespace)
local craftedQuality = loadfile("GBankManager/Domain/CraftedQuality.lua")("GBankManager", namespace)
local itemCatalog = loadfile("GBankManager/Domain/ItemCatalog.lua")("GBankManager", namespace)
local snapshots = loadfile("GBankManager/Domain/Snapshots.lua")("GBankManager", namespace)
local snapshot = snapshots.FromTabScan({ scannedAt = 1, scannedTabs = { { name = "Herbs", slots = { { itemID = 2589, name = "Linen Cloth", count = 2, quality = 4, craftedQuality = 3, craftedQualityIcon = "old" } } } } })
assert.equal(nil, snapshot.items[2589].quality, "Forever snapshots should ignore client item quality")
assert.equal(nil, snapshot.items[2589].craftedQuality, "Forever snapshots should ignore crafted quality")
assert.equal(nil, snapshot.itemRows[1].craftedQualityIcon, "Forever inventory rows should omit old quality icons")
local scanner = loadfile("GBankManager/Features/GuildBankScanner.lua")("GBankManager", namespace)
local previousItemInfo, previousItemLink, previousTabInfo = _G.GetGuildBankItemInfo, _G.GetGuildBankItemLink, _G.GetGuildBankTabInfo
local previousItemAPI, previousTradeAPI = _G.C_Item, _G.C_TradeSkillUI
_G.GetGuildBankItemInfo = function(_, slot) return nil, slot == 1 and 2 or 0 end
_G.GetGuildBankItemLink = function() return "item:2589" end
_G.GetGuildBankTabInfo = function() return "Herbs" end
_G.C_Item = { GetItemNameByID = function() return "Linen Cloth" end, GetItemQualityByID = function() error("Forever should not query quality") end }
_G.C_TradeSkillUI = { GetItemReagentQualityInfo = function() error("Forever should not query crafted quality") end }
local scannedTab = scanner.ReadCurrentTab(1)
assert.equal(nil, scannedTab.slots[1].quality, "Forever scans should omit client quality")
assert.equal(nil, scannedTab.slots[1].craftedQuality, "Forever scans should omit crafted quality")
_G.GetGuildBankItemInfo, _G.GetGuildBankItemLink, _G.GetGuildBankTabInfo = previousItemInfo, previousItemLink, previousTabInfo
_G.C_Item, _G.C_TradeSkillUI = previousItemAPI, previousTradeAPI
assert.equal(0, itemDisplay.BuildDisplayPayload({ itemID = 2589, name = "Linen Cloth", craftedQuality = 3 }).tierValue, "Forever item display should ignore saved Retail quality tiers")
assert.equal("", craftedQuality.GetDisplayAtlasForItem(2589, "Professions-ChatIcon-Quality-Tier3", 3, "reagent", 5), "Forever should suppress crafted quality icons")
assert.equal("", craftedQuality.DisplayMarkupForItem(2589, "Professions-ChatIcon-Quality-Tier3", 22, "reagent", 3, 5), "Forever should suppress crafted quality markup")
local oldQualityItem = { itemID = 2589, name = "Linen Cloth", craftedQuality = 3, craftedQualityIcon = "Professions-ChatIcon-Quality-Tier3" }
itemCatalog.ApplyCanonicalCraftedQuality(oldQualityItem)
assert.equal(nil, oldQualityItem.craftedQuality, "Forever should clear saved Retail crafted quality from selected items")
assert.equal(nil, oldQualityItem.craftedQualityIcon, "Forever should clear saved Retail crafted quality icons from selected items")
local exports = loadfile("GBankManager/Domain/Exports.lua")("GBankManager", namespace)
local stalePlanRow = { itemID = 2589, itemName = "Linen Cloth", totalToBuy = 1, sources = { RESTOCK = 1 }, quality = 3, qualityTierMax = 5 }
local materialized = exports.MaterializePlanRows({ [2589] = stalePlanRow }, { items = {} }, {})
assert.equal(0, materialized[1].itemTierValue, "Forever export rows should ignore old quality tier values")
assert.equal(0, materialized[1].craftedQualityMax, "Forever export rows should ignore old quality tier limits")
local exportsView = loadfile("GBankManager/UI/ExportsView.lua")("GBankManager", namespace)
local exportDialog = loadfile("GBankManager/UI/ExportDialog.lua")("GBankManager", namespace)
local rows = { { itemID = 2589, itemName = "Linen Cloth", itemTierValue = 3 } }
assert.truthy(not exportsView.BuildCsvText(rows):find("Tier", 1, true), "Forever CSV export should omit the Retail quality tier column")
assert.truthy(not exportDialog.BuildPresetState(rows, "CSV").text:find("Tier", 1, true), "Forever export dialog should omit the Retail quality tier column")
local inventoryView = loadfile("GBankManager/UI/InventoryView.lua")("GBankManager", namespace)
assert.truthy(not inventoryView.BuildCsvText({ { itemID = 2589, itemName = "Linen Cloth", tierValue = 3 } }):find("Tier", 1, true), "Forever inventory CSV should omit quality tier")
local bankLedger = loadfile("GBankManager/Domain/BankLedger.lua")("GBankManager", namespace)
local bankLedgerView = loadfile("GBankManager/UI/BankLedgerView.lua")("GBankManager", namespace)
for _, column in ipairs(bankLedgerView.GetColumns("ITEM")) do
    assert.truthy(column.key ~= "tier", "Forever bank ledger should omit quality tier column")
end
assert.truthy(not bankLedger.ExportRowsToCsv({}, "ITEM"):find("Quality Tier", 1, true), "Forever bank ledger CSV should omit quality tier")
_G.GBankManagerNamespace = previousNamespace
_G.GBankManagerItemSearchPayload = previousPayload
