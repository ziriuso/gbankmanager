package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local mainFrameShell = env.mainFrameShell

_G.C_TradeSkillUI = {
    GetItemReagentQualityInfo = function(itemInfo)
        if tonumber(itemInfo) == 241320 then
            return {
                quality = 2,
                iconChat = "Live-Chat-TwoTier-Gold",
                iconSmall = "Live-Small-TwoTier-Gold",
            }
        end

        return nil
    end,
}

local host = _G.CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
host:SetSize(480, 320)

local selector = mainFrameShell.CreateItemSearchSelector(host, {
    width = 360,
    height = 156,
    resultsPanelHeight = 46,
    resultRowHeight = 20,
})

local largeResultSet = {}
for index = 1, 25 do
    largeResultSet[index] = {
        itemID = 900000 + index,
        name = index == 1 and "|cffaaaaaa[T2]|r Large Result 01" or string.format("Large Result %02d", index),
        craftedQuality = index == 1 and 5 or nil,
        craftedQualityIcon = index == 1 and "Professions-ChatIcon-Quality-Tier5" or nil,
    }
end

largeResultSet[2] = {
    itemID = 241320,
    name = "Flask of Thalassian Resistance",
    craftedQuality = 1,
    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
}

selector:ShowMatches(largeResultSet)

assert.truthy(type(selector.resultsScrollBox) == "table", "shared selector should expose a virtualized results scroll box")
assert.truthy(type(selector.resultsDataProvider) == "table", "shared selector should expose a results data provider")
assert.equal(#largeResultSet, selector.resultsDataProvider:GetSize(), "shared selector should keep the full result set in the data provider")
assert.truthy(#(selector.resultRows or {}) < selector.resultsDataProvider:GetSize(), "shared selector should recycle a smaller visible row pool than the full result set")
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "900001", 1, true) ~= nil, "shared selector rows should render the item id inline")
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "[T2]", 1, true) == nil, "shared selector rows should strip legacy crafted tier prefixes from visible match labels")
assert.equal("", ((((selector.resultRows or {})[1] or {}).tierText or {}):GetText() or ""), "shared selector rows should stop relying on inline atlas markup once the dedicated quality texture path is active")
assert.truthy(((((selector.resultRows or {})[1] or {}).qualityIcon or {}):IsShown() == true), "shared selector rows should render quality through the dedicated texture region")
assert.equal("LEFT", ((((selector.resultRows or {})[1] or {}).itemText or {}).justifyH), "shared selector rows should left-align the match text")
assert.equal(6, ((((((selector.resultRows or {})[1] or {}).itemText or {}).points or {})[1] or {})[4]), "shared selector rows should keep a small gutter between the tier slot and the item text")
assert.equal("Interface-Crafting-ReagentQuality-2-Med", (((selector.resultRows or {})[2] or {}).qualityIcon or {}).atlas, "shared selector rows should keep bundled crafted-quality data authoritative even when the live client reports a different atlas")

local scrollStride = (selector.resultRowHeight or 20) + (selector.resultRowSpacing or 0)
selector.resultsScrollController:SetOffset(scrollStride * 10, selector.resultsContentHeight, selector.resultsViewportHeight)
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "900011", 1, true) ~= nil, "shared selector should recycle visible rows after scrolling through a large result set")

selector.resultRows[1]:GetScript("OnClick")(selector.resultRows[1])
assert.equal(900011, (selector.selectedItem or {}).itemID, "shared selector should update selection from the visible row pool")
assert.truthy(type((selector.resultsList or {}).selectedKey) == "string", "shared selector should keep selection state on the reusable results control")
