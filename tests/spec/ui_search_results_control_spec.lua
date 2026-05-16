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
        name = string.format("Large Result %02d", index),
        craftedQuality = index == 1 and 5 or nil,
        craftedQualityIcon = index == 1 and "Professions-ChatIcon-Quality-Tier5" or nil,
    }
end

selector:ShowMatches(largeResultSet)

assert.truthy(type(selector.resultsScrollBox) == "table", "shared selector should expose a virtualized results scroll box")
assert.truthy(type(selector.resultsDataProvider) == "table", "shared selector should expose a results data provider")
assert.equal(#largeResultSet, selector.resultsDataProvider:GetSize(), "shared selector should keep the full result set in the data provider")
assert.truthy(#(selector.resultRows or {}) < selector.resultsDataProvider:GetSize(), "shared selector should recycle a smaller visible row pool than the full result set")
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "900001", 1, true) ~= nil, "shared selector rows should render the item id inline")
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "[T5]", 1, true) ~= nil, "shared selector rows should render the crafted tier label inline")
assert.equal("Professions-ChatIcon-Quality-Tier5", (((selector.resultRows or {})[1] or {}).qualityIcon or {}).atlas, "shared selector rows should render the crafted quality icon when present")

local scrollStride = (selector.resultRowHeight or 20) + (selector.resultRowSpacing or 0)
selector.resultsScrollController:SetOffset(scrollStride * 10, selector.resultsContentHeight, selector.resultsViewportHeight)
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "900011", 1, true) ~= nil, "shared selector should recycle visible rows after scrolling through a large result set")

selector.resultRows[1]:GetScript("OnClick")(selector.resultRows[1])
assert.equal(900011, (selector.selectedItem or {}).itemID, "shared selector should update selection from the visible row pool")
assert.truthy(type((selector.resultsList or {}).selectedKey) == "string", "shared selector should keep selection state on the reusable results control")
