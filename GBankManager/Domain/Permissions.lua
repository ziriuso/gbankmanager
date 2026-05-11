local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.domain = ns.domain or {}

local permissions = ns.domain.permissions or ns.modules.permissions or {}

local APPROVER_ROLES = {
    OFFICER = true,
    GUILDMASTER = true,
}

function permissions.CanApproveRequests(role)
    return APPROVER_ROLES[role] == true
end

function permissions.CanViewInventory(role)
    return permissions.CanApproveRequests(role)
end

function permissions.AutoApprovesOwnRequests(role)
    return permissions.CanApproveRequests(role)
end

ns.domain.permissions = permissions
ns.modules.permissions = permissions

return permissions
