local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.data = ns.data or {}

local store = ns.data.store or ns.modules.store or {}

local defaults = ns.data.defaults or ns.modules.defaults
local migrations = ns.data.migrations or ns.modules.migrations

function store.CreateFreshDatabase(guildName)
    return migrations.Apply(defaults.CreateDatabase(guildName))
end

function store.Normalize(db, guildName)
    if db == nil then
        return store.CreateFreshDatabase(guildName)
    end

    if guildName ~= nil then
        db.meta = db.meta or {}
        db.meta.guildName = db.meta.guildName or guildName
    end

    return migrations.Apply(db)
end

ns.data.store = store
ns.modules.store = store

return store
