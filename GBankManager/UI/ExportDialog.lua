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
    elseif selectedPreset == "TSM" then
        text = exports.BuildTsmItemIdList(rows or {})
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
            fields = { "Item ID", "Item Tier", "Item Name", "Bank Tab", "Amount to Stock", "Excess Stock In" },
            labels = {
                ["Item ID"] = "itemID",
                ["Item Tier"] = "itemTier",
                ["Item Name"] = "itemName",
                ["Bank Tab"] = "bankTab",
                ["Amount to Stock"] = "amountToStock",
                ["Excess Stock In"] = "excessStockIn",
            },
        })
    end

    return exportDialog.BuildState(text, selectedPreset, shoppingListName)
end

ns.modules.exportDialog = exportDialog

return exportDialog
