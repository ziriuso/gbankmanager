local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exportDialog = ns.modules.exportDialog or {}

function exportDialog.BuildState(text, presetName)
    return {
        presetName = presetName or "Spreadsheet",
        text = text or "",
    }
end

ns.modules.exportDialog = exportDialog

return exportDialog
