package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
local runner = require("tests.helpers.test_runner")
local lanes = require("tests.helpers.spec_lanes")
local specs = lanes.unit

runner.run_specs(specs)

print("PASS tests/run_unit.lua")
