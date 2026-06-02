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
        fields = { "Item ID", "Tier", "Item Name", "Bank Tab", "Min Qty", "Qty In Stock", "Qty To Buy", "Excess Qty" },
        labels = {
            ["Item ID"] = "itemID",
            ["Tier"] = "itemTierValue",
            ["Item Name"] = "itemName",
            ["Bank Tab"] = "bankTab",
            ["Min Qty"] = "minQty",
            ["Qty In Stock"] = "qtyInStock",
            ["Qty To Buy"] = "qtyToBuy",
            ["Excess Qty"] = "excessQtyValue",
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
