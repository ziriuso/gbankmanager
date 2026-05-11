local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports
if exports == nil and type(_G.dofile) == "function" then
    exports = _G.dofile("GBankManager/Domain/Exports.lua")
end

local exportsView = ns.modules.exportsView or {}

function exportsView.BuildSpreadsheetText(rows)
    return exports.BuildDelimited(rows or {}, {
        delimiter = ",",
        includeHeader = true,
        fields = { "itemName", "totalToBuy", "reason" },
    })
end

ns.modules.exportsView = exportsView

return exportsView
