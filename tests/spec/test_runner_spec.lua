local assert = require("tests.helpers.assert")
local runner = require("tests.helpers.test_runner")

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
