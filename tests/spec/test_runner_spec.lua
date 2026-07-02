local assert = require("tests.helpers.assert")
local runner = require("tests.helpers.test_runner")
local lanes = require("tests.helpers.spec_lanes")

local captured = {}
local originalPrint = print
local originalStdout = io and io.stdout

print = function(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end
    table.insert(captured, table.concat(parts, "\t"))
end

if io then
    io.stdout = {
        flushed = false,
        flush = function(self)
            self.flushed = true
        end,
    }
end

local ok, err = pcall(function()
    runner.run_specs({
        "tests/fixtures/progress_pass_spec.lua",
    })
end)

print = originalPrint
if io then
    io.stdout = originalStdout
end

if not ok then
    error(err)
end

assert.equal("RUN tests/fixtures/progress_pass_spec.lua", captured[1], "runner should print before executing each spec")
assert.equal("PASS tests/fixtures/progress_pass_spec.lua", captured[2], "runner should print after each successful spec")

local missing, duplicates = runner.find_lane_coverage_gaps(lanes)
assert.equal(nil, missing[1], "all spec files should be owned by a test lane; first missing: " .. tostring(missing[1]))
assert.equal(nil, duplicates[1], "spec files should be owned by only one test lane; first duplicate: " .. tostring(duplicates[1]))
