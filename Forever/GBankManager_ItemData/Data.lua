local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.data = ns.data or {}
ns.modules = ns.modules or {}

return ns.data.staticItemCatalog or ns.modules.staticItemCatalog or ns
