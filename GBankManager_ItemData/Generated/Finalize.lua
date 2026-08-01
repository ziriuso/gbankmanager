local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
local bootstrap = ((ns.data or {}).staticItemSearchBootstrap)
if type(bootstrap) ~= "table" or type(bootstrap.Finalize) ~= "function" then
    return
end

bootstrap.Finalize({
    source = "local_client_item_db2",
    generatedAt = "2026-08-01",
    itemCount = 7809,
    tokenCount = 4638,
})
