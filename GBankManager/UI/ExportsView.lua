local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local exports = ns.modules.exports
if exports == nil and type(_G.dofile) == "function" then
    exports = _G.dofile("GBankManager/Domain/Exports.lua")
end

local exportsView = ns.modules.exportsView or {}

function exportsView.BuildCsvText(rows)
    return exports.BuildDelimited(rows or {}, {
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

function exportsView.BuildSpreadsheetText(rows)
    return exportsView.BuildCsvText(rows)
end

function exportsView.BuildAuctionatorText(rows, shoppingListName)
    return exports.BuildAuctionator(rows or {}, shoppingListName)
end

function exportsView.BuildTsmItemIdText(rows)
    return exports.BuildTsmItemIdList(rows or {})
end

function exportsView.BuildCustomText(rows, template)
    return exports.BuildDelimited(rows or {}, template or {
        delimiter = "|",
        includeHeader = true,
        fields = { "itemID", "itemName", "totalToBuy" },
    })
end

function exportsView.BuildTableRows(plan, snapshot)
    return exports.MaterializePlanRows(plan, snapshot)
end

ns.modules.exportsView = exportsView

return exportsView
