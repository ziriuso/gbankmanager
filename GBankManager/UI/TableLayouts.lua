local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local tableLayouts = ns.modules.tableLayouts or {}

local INVENTORY_MINIMUM_COLUMNS = {
    { key = "itemID", label = "Item ID", width = 78, minWidth = 72, maxWidth = 96, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "tier", label = "Tier", width = 56, minWidth = 56, maxWidth = 72, justifyH = "CENTER", filterMode = "none", sortable = true },
    { key = "itemName", label = "Item", width = 288, minWidth = 240, maxWidth = 360, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "bankTab", label = "Bank Tab", width = 136, minWidth = 118, maxWidth = 190, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "current", label = "Current", width = 68, minWidth = 64, maxWidth = 88, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "restock", label = "Restock", width = 76, minWidth = 72, maxWidth = 98, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "quantity", label = "Minimum", width = 70, minWidth = 66, maxWidth = 92, justifyH = "LEFT", filterMode = "none", sortable = true },
}

local REQUEST_ADMIN_COLUMNS = {
    { key = "createdAt", label = "Date Requested", width = 110, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "requester", label = "Requestor", width = 92, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "itemID", label = "Item ID", width = 68, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "itemName", label = "Item Name", width = 226, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "quantity", label = "Quantity", width = 68, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "status", label = "Status", width = 88, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "fulfilledAt", label = "Date Fulfilled", width = 120, justifyH = "LEFT", filterMode = "text", sortable = true },
}

local REQUEST_STATUS_COLUMNS = {
    { key = "itemID", label = "Item ID", width = 90, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "itemName", label = "Item Name", width = 360, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "quantity", label = "Quantity", width = 90, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "status", label = "Status", width = 132, justifyH = "LEFT", filterMode = "none", sortable = true },
}

local function copy_columns(columns)
    local out = {}

    for index, column in ipairs(columns or {}) do
        out[index] = {
            key = column.key,
            label = column.label,
            width = column.width,
            minWidth = column.minWidth,
            maxWidth = column.maxWidth,
            justifyH = column.justifyH,
            filterMode = column.filterMode,
            sortable = column.sortable,
        }
    end

    return out
end

function tableLayouts.GetInventoryMinimumColumns()
    return copy_columns(INVENTORY_MINIMUM_COLUMNS)
end

function tableLayouts.GetRequestAdminColumns()
    return copy_columns(REQUEST_ADMIN_COLUMNS)
end

function tableLayouts.GetRequestStatusColumns()
    return copy_columns(REQUEST_STATUS_COLUMNS)
end

ns.modules.tableLayouts = tableLayouts

return tableLayouts
