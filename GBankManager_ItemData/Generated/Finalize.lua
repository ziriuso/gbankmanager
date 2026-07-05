local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)
if type(bootstrap) ~= "table" or type(bootstrap.Finalize) ~= "function" then
    return
end

bootstrap.Finalize({
    source = "local_client_item_db2",
    generatedAt = "2026-07-05",
    itemCount = 7754,
    tokenCount = 4619,
})
