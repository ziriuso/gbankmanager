package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local specs = {
    "tests/spec/diff_spec.lua",
    "tests/spec/auth_spec.lua",
    "tests/spec/auth_source_spec.lua",
    "tests/spec/exports_spec.lua",
    "tests/spec/history_spec.lua",
    "tests/spec/inventory_quality_spec.lua",
    "tests/spec/planning_spec.lua",
    "tests/spec/requests_spec.lua",
    "tests/spec/sync_spec.lua",
    "tests/spec/store_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_unit.lua")
