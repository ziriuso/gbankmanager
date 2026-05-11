local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local permissions = ns.modules.permissions

if permissions == nil and type(_G.dofile) == "function" then
    permissions = _G.dofile("GBankManager/Domain/Permissions.lua")
end

permissions = permissions or {}

local requests = ns.modules.requests or {}

function requests.Create(input)
    input = input or {}

    local autoApproved = false
    if type(permissions.AutoApprovesOwnRequests) == "function" then
        autoApproved = permissions.AutoApprovesOwnRequests(input.role)
    end

    return {
        requestId = input.requestId or tostring(_G.time()),
        role = input.role,
        itemID = input.itemID,
        itemName = input.itemName,
        quantity = input.quantity,
        note = input.note or "",
        approval = autoApproved and "APPROVED" or "PENDING",
        fulfillment = "OPEN",
    }
end

ns.modules.requests = requests

return requests
