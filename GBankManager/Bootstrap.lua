local addonName, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.addonName = ns.addonName or addonName or "GBankManager"
ns.modules = ns.modules or {}
ns.state = ns.state or {}
ns.data = ns.data or {}
_G.GBankManagerNamespace = ns

local store = ns.data.store or ns.modules.store

return ns
