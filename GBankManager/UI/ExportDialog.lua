local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports
if exports == nil and type(_G.dofile) == "function" then
    exports = _G.dofile("GBankManager/Domain/Exports.lua")
end

exports = exports or {}
local exportDialog = ns.modules.exportDialog or {}

function exportDialog.BuildState(text, presetName)
    return {
        presetName = presetName or "Spreadsheet",
        text = text or "",
    }
end

function exportDialog.BuildPresetState(rows, presetName, template)
    local text = ""
    local selectedPreset = presetName or "Spreadsheet"

    if selectedPreset == "Auctionator" then
        text = exports.BuildAuctionator(rows or {})
    elseif selectedPreset == "Custom" then
        text = exports.BuildDelimited(rows or {}, template or {
            delimiter = ",",
            includeHeader = true,
            fields = { "itemName", "totalToBuy", "reason" },
        })
    else
        text = exports.BuildDelimited(rows or {}, {
            delimiter = ",",
            includeHeader = true,
            fields = { "itemName", "totalToBuy", "reason" },
        })
    end

    return exportDialog.BuildState(text, selectedPreset)
end

ns.modules.exportDialog = exportDialog

return exportDialog
