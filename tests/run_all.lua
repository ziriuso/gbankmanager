package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")
local runner = require("tests.helpers.test_runner")

runner.run_lane("tests/run_unit.lua")
runner.run_lane("tests/run_ui.lua")
runner.run_lane("tests/run_integration.lua")

print("PASS tests/run_all.lua")
