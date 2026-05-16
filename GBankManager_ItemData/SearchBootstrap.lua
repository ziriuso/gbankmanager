local _, ns = ...

ns = _G.GBankManagerNamespace or ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local payload = {
    metadata = {
        ready = false,
        itemCount = 0,
        tokenCount = 0,
    },
    itemsByID = {},
    tokenToItemIDs = {},
}

local legacyCatalog = {
    metadata = payload.metadata,
    items = {},
}

local function publish_globals()
    _G.GBankManagerItemSearchPayload = payload
    _G.GBankManagerItemCatalogData = legacyCatalog
end

local bootstrap = {}

function bootstrap.AppendItemChunk(chunk)
    if type(chunk) ~= "table" then
        return
    end

    for index = 1, #chunk do
        local item = chunk[index]
        local itemID = tonumber(item and item.itemID)
        if itemID then
            payload.itemsByID[itemID] = item
            legacyCatalog.items[#legacyCatalog.items + 1] = item
        end
    end
end

function bootstrap.AppendTokenChunk(chunk)
    if type(chunk) ~= "table" then
        return
    end

    for token, itemIDs in pairs(chunk) do
        payload.tokenToItemIDs[token] = itemIDs
    end
end

function bootstrap.Finalize(metadata)
    metadata = metadata or {}

    payload.metadata.source = metadata.source
    payload.metadata.generatedAt = metadata.generatedAt
    payload.metadata.itemCount = tonumber(metadata.itemCount) or #legacyCatalog.items
    payload.metadata.tokenCount = tonumber(metadata.tokenCount) or 0
    payload.metadata.ready = (#legacyCatalog.items == payload.metadata.itemCount)
        and (payload.metadata.tokenCount > 0)

    legacyCatalog.metadata = payload.metadata

    ns.data.staticItemSearch = payload
    ns.modules.staticItemSearch = payload
    ns.data.staticItemCatalog = legacyCatalog
    ns.modules.staticItemCatalog = legacyCatalog
    publish_globals()

    return payload.metadata.ready
end

ns.data.staticItemSearch = payload
ns.modules.staticItemSearch = payload
ns.data.staticItemCatalog = legacyCatalog
ns.modules.staticItemCatalog = legacyCatalog
ns.data.staticItemSearchBootstrap = bootstrap
publish_globals()

return bootstrap
