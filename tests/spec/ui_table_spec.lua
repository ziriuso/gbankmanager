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
local activeTheme = env.mainFrameShell.GetTheme()

local function color_distance(left, right)
    left = left or {}
    right = right or {}
    local total = 0
    for index = 1, 3 do
        total = total + math.abs((left[index] or 0) - (right[index] or 0))
    end
    return total
end

_G.GBankManagerDB = {
    currentSnapshotId = "inventory-scroll",
    snapshots = {
        ["inventory-scroll"] = {
            items = {},
        },
    },
    minimums = {},
    requests = {},
    auditLog = {},
}

for index = 1, 30 do
    _G.GBankManagerDB.snapshots["inventory-scroll"].items[1000 + index] = {
        itemID = 1000 + index,
        name = string.format("Inventory Item %02d", index),
        totalCount = index,
        tabs = {
            Consumables = index,
        },
    }
end

_G.GBankManagerDB.snapshots["inventory-scroll"].items[2001] = {
    itemID = 2001,
    name = "Two-Rank Crafted Test",
    totalCount = 1,
    craftedQuality = 2,
    craftedQualityIcon = "Professions-ChatIcon-Quality-Tier2",
    tabs = {
        Consumables = 1,
    },
}

env.ns.state.db = _G.GBankManagerDB
mainFrame:SelectView("INVENTORY")

assert.truthy(type(mainFrame.tableViewportFrame) == "table", "inventory should expose a dedicated viewport frame for the shared table shell")
assert.truthy(type(mainFrame.tableScrollBar) == "table", "inventory should expose a visible scroll bar")
assert.same(mainFrame.tableViewportFrame, (mainFrame.tableScrollBar.points[1] or {})[2], "shared table scrollbar should anchor to the viewport")
assert.equal(18, (mainFrame.tableScrollBar.points[1] or {})[4], "shared table scrollbar should sit just outside the table viewport")
assert.equal(18, (mainFrame.tableScrollBar.points[2] or {})[4], "shared table scrollbar bottom anchor should sit just outside the table viewport")
assert.equal(
    math.max(520, math.floor((mainFrame.content:GetWidth() or 0) - 56)),
    mainFrame.tableViewportWidth,
    "shared table viewport should follow the active shell width while still leaving room for the external scrollbar"
)
assert.equal(24, mainFrame.tableScrollbarGutterWidth, "shared table layout should reserve a gutter for the inset scrollbar")
assert.equal(mainFrame.tableViewportWidth, mainFrame.tableViewportInnerWidth, "shared table content should fill the table viewport before the external scrollbar")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableHeaderFrame:GetWidth(), "shared table header should stop before the scrollbar gutter")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableFilterFrame:GetWidth(), "shared table filters should stop before the scrollbar gutter")
assert.equal(mainFrame.tableViewportInnerWidth, mainFrame.tableRows[1]:GetWidth(), "shared table rows should stop before the scrollbar gutter")
assert.equal("table-header-flat", mainFrame.tableHeaderFrame.gbmSurfaceVariant, "inventory should use the flatter table-header surface")
assert.equal("table-filter-flat", mainFrame.tableFilterFrame.gbmSurfaceVariant, "inventory should use the flatter table-filter surface")
assert.equal("table-viewport-structured", mainFrame.tableViewportFrame.gbmSurfaceVariant, "inventory should preserve the structured table viewport surface")
assert.equal(0, ((mainFrame.tableHeaderFrame.backdropBorderColor or {})[4] or 0), "inventory table header should not rely on a full backdrop border")
assert.equal(0, ((mainFrame.tableFilterFrame.backdropBorderColor or {})[4] or 0), "inventory table filter band should not rely on a full backdrop border")
assert.equal(0, ((mainFrame.tableViewportFrame.backdropBorderColor or {})[4] or 0), "inventory table viewport should not rely on a full backdrop border")
assert.truthy(type((mainFrame.tableHeaderFrame.gbmArt or {}).headerBand) == "table", "inventory table header should expose the shared art-band treatment")
assert.truthy(not ((mainFrame.tableHeaderFrame.gbmArt or {}).topLine):IsShown(), "inventory table header should avoid a framed top edge")
assert.truthy(not ((mainFrame.tableHeaderFrame.gbmArt or {}).leftLine):IsShown(), "inventory table header should avoid a framed left edge")
assert.truthy(not ((mainFrame.tableHeaderFrame.gbmArt or {}).rightLine):IsShown(), "inventory table header should avoid a framed right edge")
assert.truthy(((mainFrame.tableHeaderFrame.gbmArt or {}).bottomLine):IsShown(), "inventory table header should keep a separator line below the labels")
assert.truthy(not ((mainFrame.tableHeaderFrame.gbmArt or {}).headerBand):IsShown(), "inventory table header should drop the old inset top strip")
assert.truthy(not ((mainFrame.tableFilterFrame.gbmArt or {}).topLine):IsShown(), "inventory filters should avoid a boxed top edge")
assert.truthy(not ((mainFrame.tableFilterFrame.gbmArt or {}).leftLine):IsShown(), "inventory filters should avoid a boxed left edge")
assert.truthy(not ((mainFrame.tableFilterFrame.gbmArt or {}).rightLine):IsShown(), "inventory filters should avoid a boxed right edge")
assert.truthy(((mainFrame.tableFilterFrame.gbmArt or {}).bottomLine):IsShown(), "inventory filters should keep a subtle separator below the search band")
assert.truthy(not ((mainFrame.tableViewportFrame.gbmArt or {}).topLine):IsShown(), "inventory viewport should avoid a boxed top edge")
assert.truthy(not ((mainFrame.tableViewportFrame.gbmArt or {}).leftLine):IsShown(), "inventory viewport should avoid a boxed left edge")
assert.truthy(not ((mainFrame.tableViewportFrame.gbmArt or {}).rightLine):IsShown(), "inventory viewport should avoid a boxed right edge")
assert.truthy(not ((mainFrame.tableViewportFrame.gbmArt or {}).bottomLine):IsShown(), "inventory viewport should avoid a boxed bottom edge")
assert.truthy(type((mainFrame.tableRows[1].gbmArt or {}).background) == "table", "inventory rows should expose reusable art backgrounds")
assert.equal((activeTheme.tokens.row or {})[1], (mainFrame.tableRows[1].gbmBackdropBaseColor or {})[1], "inventory odd rows should use the semantic row token instead of generic panel art")
assert.equal((activeTheme.tokens.rowAlt or {})[1], (mainFrame.tableRows[2].gbmBackdropBaseColor or {})[1], "inventory even rows should use the semantic alternating row token instead of generic panel art")
assert.truthy(color_distance(mainFrame.tableRows[1].gbmBackdropBaseColor, mainFrame.tableRows[2].gbmBackdropBaseColor) >= 0.09, "inventory alternating rows should stay visibly distinct after the flatter table pass")
assert.truthy(not ((mainFrame.tableRows[1].gbmArt or {}).topLine):IsShown(), "inventory rows should not draw a hard top border")
assert.truthy(((mainFrame.tableRows[1].gbmArt or {}).bottomLine):IsShown(), "inventory rows should keep a subtle bottom separator for structure")
assert.truthy(not ((mainFrame.tableRows[1].gbmArt or {}).leftLine):IsShown(), "inventory rows should not draw a boxed left edge")
assert.truthy(not ((mainFrame.tableRows[1].gbmArt or {}).rightLine):IsShown(), "inventory rows should not draw a boxed right edge")
assert.equal("Item ID", mainFrame.tableHeaderLabels[1]:GetText(), "inventory should use the minimums table layout starting with Item ID")
assert.equal("Item", mainFrame.tableHeaderLabels[2]:GetText(), "inventory should collapse the old tier slot into the shared item display column")
assert.equal("Bank Tab", mainFrame.tableHeaderLabels[3]:GetText(), "inventory should shift bank tab left after tier-column removal")
assert.equal("Current", mainFrame.tableHeaderLabels[4]:GetText(), "inventory should keep current stock visible after tier-column removal")
assert.equal("Restock", mainFrame.tableHeaderLabels[5]:GetText(), "inventory should keep restock visible after tier-column removal")
assert.equal("Minimum", mainFrame.tableHeaderLabels[6]:GetText(), "inventory should end the visible table at the minimum column")
assert.truthy(mainFrame.tableHeaderLabels[7] == nil or mainFrame.tableHeaderLabels[7].shown == false, "inventory should not render a ghost seventh header after tier-column removal")
assert.truthy((mainFrame.tableColumnLayout[2].width or 0) >= 320, "inventory item column should absorb the removed tier width for item names")
assert.truthy((mainFrame.tableColumnLayout[6].width or 0) >= 80, "inventory minimum column should leave enough room for the header near the right edge")
mainFrame.tableFilterInputs[1]:SetText("1015")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal(1, #mainFrame.tableRowsData, "inventory shared table filters should search by Item ID")
assert.equal("1015", mainFrame.tableRowsData[1].itemID, "inventory Item ID filter should keep the matching item row")
mainFrame.tableFilterInputs[1]:SetText("")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.truthy(type(mainFrame.tableScrollBar.thumb) == "table", "inventory scroll bar should expose a draggable thumb")
assert.equal(nil, mainFrame.tableScrollBar.scrollUpButton, "inventory should remove the old scroll-up button")
assert.equal(nil, mainFrame.tableScrollBar.scrollDownButton, "inventory should remove the old scroll-down button")
assert.equal(nil, mainFrame.tableScrollBar.valueText, "inventory should remove the old row-range text label")
assert.equal("minimal-scrollbar-track-top", mainFrame.tableScrollBar.track.Begin.atlas, "inventory should reuse the Blizzard-style track art")
assert.equal("minimal-scrollbar-small-thumb-top", mainFrame.tableScrollBar.thumb.Begin.atlas, "inventory should reuse the Blizzard-style thumb art")
assert.truthy(color_distance((mainFrame.tableFilterInputs[1].gbmArt or {}).background.color, (mainFrame.tableFilterFrame.gbmArt or {}).innerFill.color) >= 0.12, "inventory filter inputs should sit forward from the filter band with stronger contrast")
assert.truthy(((mainFrame.tableFilterInputs[1].gbmArt or {}).topLine):IsShown(), "inventory filter inputs should keep a visible top edge")
assert.truthy(((mainFrame.tableFilterInputs[1].gbmArt or {}).bottomLine):IsShown(), "inventory filter inputs should keep a visible bottom edge")
assert.truthy((((mainFrame.tableFilterInputs[2].points[1] or {})[4] or 0) - (((mainFrame.tableFilterInputs[1].points[1] or {})[4] or 0) + (mainFrame.tableFilterInputs[1]:GetWidth() or 0))) >= 4, "inventory filter inputs should keep visible spacing between boxes")
assert.truthy((mainFrame.tableFilterInputs[1]:GetWidth() or 0) < (mainFrame.tableColumnLayout[1].width or 0), "inventory filter inputs should inset slightly from the full column width for a softer box treatment")
mainFrame.tableFilterInputs[1]:SetText("2001")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])
assert.equal("", tostring(mainFrame.tableRowsData[1].tier or ""), "inventory should keep the tier text empty when the table path is rendering crafted quality through its dedicated visual slot")
mainFrame.tableFilterInputs[1]:SetText("")
mainFrame.tableFilterInputs[1]:GetScript("OnTextChanged")(mainFrame.tableFilterInputs[1])

mainFrame:ConfigureTable({
    { key = "itemDisplayText", label = "Item", width = 240 },
}, {
    {
        itemDisplayText = "Stale rendered quality row",
        itemDisplayTextIconAtlas = "Professions-Icon-Quality-Tier2-Inv",
    },
    {
        itemDisplayText = "Live debug chat quality row",
        itemDisplayTextIconAtlas = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityFamilySize = 2,
    },
    {
        itemDisplayText = "Five-rank quality row",
        itemDisplayTextIconAtlas = "Professions-ChatIcon-Quality-Tier2",
        craftedQualityFamilySize = 5,
    },
})
mainFrame:RefreshVisibleTableRows()
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    mainFrame.tableRows[1].columnIcons[1].atlas,
    "shared table rendering should normalize stale two-rank tier-two icon atlases at the final texture boundary"
)
assert.equal(
    "Professions-Icon-Quality-12-Tier2-Inv",
    mainFrame.tableRows[2].columnIcons[1].atlas,
    "shared table rendering should normalize live two-rank chat atlas inputs when row family metadata says the item has two ranks"
)
assert.equal(
    "Professions-ChatIcon-Quality-Tier2",
    mainFrame.tableRows[3].columnIcons[1].atlas,
    "shared table rendering should not rewrite five-rank chat atlas inputs"
)

local originalRowHeight = mainFrame.tableRowHeight
local originalVisibleCount = mainFrame.tableVisibleCount
mainFrame:SetTableDensity(1.15)
assert.truthy(mainFrame.tableRowHeight > originalRowHeight, "table density should increase shared table row height")
assert.truthy(mainFrame.tableVisibleCount > 0, "table density should keep a positive visible row count while the linked shell relayout runs")
assert.equal(mainFrame.tableRowHeight, mainFrame.tableScrollController.options.wheelStep, "table density should keep the table wheel step aligned to the active row height")
assert.equal(mainFrame.tableRowHeight, math.abs((((mainFrame.tableRows[2].points[1] or {})[5] or 0) - ((mainFrame.tableRows[1].points[1] or {})[5] or 0))), "table density should keep shared rows spaced to the active row height")

mainFrame.tableScrollFrame:GetScript("OnMouseWheel")(mainFrame.tableScrollFrame, -1)
assert.truthy((mainFrame.tableScrollOffset or 0) > 0, "inventory mouse-wheel scrolling should advance the shared table offset")
assert.truthy((mainFrame.tableScrollBar.thumb.progress or 0) > 0, "inventory scroll thumb should move forward when the table scrolls")

mainFrame.tableScrollFrame.height = 0
mainFrame.tableScrollChild.height = 0
mainFrame.tableScrollFrame:GetScript("OnMouseWheel")(mainFrame.tableScrollFrame, -1)
assert.truthy(mainFrame.tableScrollBar:IsShown(), "inventory scrollbar should stay visible while scrolling even if the live client reports a transient zero height")

local originalViewportWidth = mainFrame.tableViewportWidth
mainFrame:SetShellScale(0.85)
local shrunkenTotalWidth = 0
for _, column in ipairs(mainFrame.tableColumnLayout or {}) do
    shrunkenTotalWidth = shrunkenTotalWidth + (column.width or 0)
end
assert.truthy(mainFrame.tableViewportWidth < originalViewportWidth, "shell scale should shrink the shared table viewport when the shell gets smaller")
assert.truthy(shrunkenTotalWidth <= (mainFrame.tableViewportWidth or 0), "shell scale should keep shared table columns inside the available viewport width")
assert.truthy((mainFrame.tableViewportHeight or 0) <= ((mainFrame.content:GetHeight() or 0) - 120), "smaller shell scale should clamp the viewport height so footer buttons stay inside the shell")

mainFrame:SetShellScale(1.2)
local expandedTotalWidth = 0
for _, column in ipairs(mainFrame.tableColumnLayout or {}) do
    expandedTotalWidth = expandedTotalWidth + (column.width or 0)
end
assert.truthy(mainFrame.tableViewportWidth > originalViewportWidth, "shell scale should expand the shared table viewport when the shell gets larger")
assert.truthy(expandedTotalWidth <= (mainFrame.tableViewportWidth or 0), "expanded shell scale should still keep shared table columns inside the available viewport width")
assert.truthy((mainFrame.tableViewportHeight or 0) <= ((mainFrame.content:GetHeight() or 0) - 120), "larger shell scale should still clamp the viewport height so footer buttons stay inside the shell")
