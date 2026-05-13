local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports
if exports == nil and type(_G.dofile) == "function" then
    exports = _G.dofile("GBankManager/Domain/Exports.lua")
end

exports = exports or {}
local exportDialog = ns.modules.exportDialog or {}

local function normalize_preset_name(presetName)
    if presetName == nil or presetName == "" or presetName == "Spreadsheet" then
        return "CSV"
    end

    return presetName
end

function exportDialog.BuildState(text, presetName, shoppingListName)
    return {
        presetName = normalize_preset_name(presetName),
        shoppingListName = shoppingListName or "GBankManager",
        text = text or "",
    }
end

function exportDialog.BuildPresetState(rows, presetName, template)
    local text = ""
    local selectedPreset = normalize_preset_name(presetName)
    local shoppingListName = (template and template.shoppingListName) or "GBankManager"

    if selectedPreset == "Auctionator" then
        text = exports.BuildAuctionator(rows or {}, shoppingListName)
    elseif selectedPreset == "Custom" then
        text = exports.BuildDelimited(rows or {}, template or {
            delimiter = "|",
            includeHeader = true,
            fields = { "itemID", "itemName", "totalToBuy" },
        })
    else
        text = exports.BuildDelimited(rows or {}, {
            delimiter = ",",
            includeHeader = true,
            fields = { "itemName", "itemID", "currentQuantity", "restockQuantity", "targetQuantity", "requestQuantity", "totalToBuy", "scopeSummary", "reason" },
        })
    end

    return exportDialog.BuildState(text, selectedPreset, shoppingListName)
end

ns.modules.exportDialog = exportDialog

return exportDialog
