package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
dofile("tests/run_unit.lua")
dofile("tests/run_ui.lua")
dofile("tests/run_integration.lua")

print("PASS tests/run_all.lua")
