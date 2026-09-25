local addonName, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.addonName = ns.addonName or addonName or "GBankManager"
ns.modules = ns.modules or {}
ns.state = ns.state or {}
ns.data = ns.data or {}
ns.IsForever = function()
    local payload = ns.data.staticItemSearch or ns.modules.staticItemSearch or _G.GBankManagerItemSearchPayload
    return type(payload) == "table" and type(payload.metadata) == "table" and payload.metadata.target == "Forever"
end
_G.GBankManagerNamespace = ns

return ns
