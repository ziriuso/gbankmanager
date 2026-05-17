package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
local runner = require("tests.helpers.test_runner")

local specs = {
    "tests/spec/toc_spec.lua",
    "tests/spec/live_smoke_spec.lua",
    "tests/spec/in_game_unit_spec.lua",
}

runner.run_specs(specs)

print("PASS tests/run_integration.lua")
