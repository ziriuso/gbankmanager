package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local function load_shared_chunk(path, addonName, ns)
    local chunk, loadError = loadfile(path)
    if not chunk then
        error(loadError)
    end

    return chunk(addonName, ns)
end

local addonName = "GBankManager"
local ns = {}

for _, path in ipairs({
    "GBankManager/Core/Namespace.lua",
    "GBankManager/Core/Constants.lua",
    "GBankManager/Bootstrap.lua",
    "GBankManager/Core/Events.lua",
    "GBankManager/Core/SlashCommands.lua",
    "GBankManager/Data/Defaults.lua",
    "GBankManager/Data/Migrations.lua",
    "GBankManager/Data/Store.lua",
    "GBankManager/Domain/Permissions.lua",
}) do
    load_shared_chunk(path, addonName, ns)
end

_G.GBankManagerTestContext = {
    addonName = addonName,
    ns = ns,
    store = (ns.data and ns.data.store) or (ns.modules and ns.modules.store),
    permissions = (ns.domain and ns.domain.permissions) or (ns.modules and ns.modules.permissions),
}

local specs = {
    "tests/spec/store_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_all.lua")
