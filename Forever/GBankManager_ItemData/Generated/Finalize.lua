local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)
if type(bootstrap) ~= "table" or type(bootstrap.Finalize) ~= "function" then
    return
end

bootstrap.Finalize({
    source = "local_client_item_db2",
    generatedAt = "2026-09-25",
    target = "Forever",
    build = "1.60.1.70009",
    locale = "en_US",
    itemCount = 19041,
    tokenCount = 7541,
})
