package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local specs = {
    "tests/spec/toc_spec.lua",
    "tests/spec/live_smoke_spec.lua",
}

for _, path in ipairs(specs) do
    dofile(path)
end

print("PASS tests/run_integration.lua")
