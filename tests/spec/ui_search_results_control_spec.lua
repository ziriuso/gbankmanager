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
        itemLink = index == 1 and "|cff0070dd|Hitem:900001::::::::80:::::|h[Large Result 01]|h|r" or nil,
        itemString = index == 1 and "item:900001::::::::80:::::" or nil,
        craftedQuality = index == 1 and 5 or nil,
        craftedQualityIcon = index == 1 and "Professions-ChatIcon-Quality-Tier5" or nil,
    }
end

largeResultSet[2] = {
    itemID = 241320,
    name = "Flask of Thalassian Resistance",
    itemLink = "|cffffffff|Hitem:241320::::::::80:::::|h[Flask of Thalassian Resistance]|h|r",
    itemString = "item:241320::::::::80:::::",
    craftedQuality = 1,
    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier1",
}

selector:ShowMatches(largeResultSet)

assert.truthy(type(selector.resultsScrollBox) == "table", "shared selector should expose a virtualized results scroll box")
assert.truthy(type(selector.resultsDataProvider) == "table", "shared selector should expose a results data provider")
assert.equal(#largeResultSet, selector.resultsDataProvider:GetSize(), "shared selector should keep the full result set in the data provider")
assert.truthy(#(selector.resultRows or {}) < selector.resultsDataProvider:GetSize(), "shared selector should recycle a smaller visible row pool than the full result set")
assert.equal("|cff0070dd|Hitem:900001::::::::80:::::|h[Large Result 01]|h|r", (((selector.resultRows or {})[1] or {}).itemText or {}):GetText(), "shared selector rows should render trusted hyperlink-style item text when a stored item link is available")
assert.truthy(string.find((((selector.resultRows or {})[1] or {}).itemText or {}):GetText() or "", "[T2]", 1, true) == nil, "shared selector rows should strip legacy crafted tier prefixes from visible match labels")
assert.equal("", ((((selector.resultRows or {})[1] or {}).tierText or {}):GetText() or ""), "shared selector rows should stop relying on inline atlas markup once the shared item display owns the visible label")
assert.truthy(((((selector.resultRows or {})[1] or {}).qualityIcon or {}):IsShown() == false), "shared selector rows should stop depending on a separate visible quality icon once the shared item display owns the visible label")
assert.equal("LEFT", ((((selector.resultRows or {})[1] or {}).itemText or {}).justifyH), "shared selector rows should left-align the match text")
assert.equal(8, ((((((selector.resultRows or {})[1] or {}).itemText or {}).points or {})[1] or {})[4]), "shared selector rows should anchor hyperlink-style item text directly from the row edge once the quality icon is no longer visible")
assert.equal("|cffffffff|Hitem:241320::::::::80:::::|h[Flask of Thalassian Resistance]|h|r", (((selector.resultRows or {})[2] or {}).itemText or {}):GetText(), "shared selector rows should use trusted stored hyperlinks for bundled crafted items too")
assert.truthy(((((selector.resultRows or {})[2] or {}).qualityIcon or {}):IsShown() == false), "shared selector rows should not show a dedicated quality icon even when bundled crafted-quality metadata is available")

local scrollStride = (selector.resultRowHeight or 20) + (selector.resultRowSpacing or 0)
selector.resultsScrollController:SetOffset(scrollStride * 10, selector.resultsContentHeight, selector.resultsViewportHeight)
assert.equal("Large Result 11", (((selector.resultRows or {})[1] or {}).itemText or {}):GetText(), "shared selector should recycle visible rows after scrolling through a large result set")

selector.resultRows[1]:GetScript("OnClick")(selector.resultRows[1])
assert.equal(900011, (selector.selectedItem or {}).itemID, "shared selector should update selection from the visible row pool")
assert.truthy(type((selector.resultsList or {}).selectedKey) == "string", "shared selector should keep selection state on the reusable results control")

local iconHost = _G.CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
iconHost:SetSize(480, 180)
local iconSelector = mainFrameShell.CreateItemSearchSelector(iconHost, {
    width = 360,
    height = 120,
    resultsPanelHeight = 46,
    resultRowHeight = 20,
    showQualityIcon = true,
})

iconSelector:ShowMatches({
    {
        itemID = 241326,
        name = "Flask of the Shattered Sun",
        craftedQuality = 2,
        craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityDisplayAtlas = "Professions-Icon-Quality-12-Tier2-Inv",
        craftedQualityPreferredAtlas = "Professions-Icon-Quality-12-Tier2-Inv",
        craftedQualityMax = 2,
        craftedQualityFamilySize = 2,
        quality = 1,
    },
})

assert.equal("Professions-Icon-Quality-12-Tier2-Inv", (((iconSelector.resultRows or {})[1] or {}).qualityIcon or {}).atlas, "opt-in selector quality icons should prefer canonical display atlases over stale chat atlases")
