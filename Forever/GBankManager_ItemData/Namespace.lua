local addonName, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.addonName = ns.addonName or "GBankManager"
ns.modules = ns.modules or {}
ns.state = ns.state or {}
ns.data = ns.data or {}

_G.GBankManagerNamespace = ns

return ns
