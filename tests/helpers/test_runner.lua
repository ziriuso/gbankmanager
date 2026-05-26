local M = {}

local function emit(status, label)
    print(string.format("%s %s", status, tostring(label or "")))
    if io and io.stdout and type(io.stdout.flush) == "function" then
        io.stdout:flush()
    end
end

function M.run_file(path)
    emit("RUN", path)

    local ok, err = pcall(dofile, path)
    if not ok then
        emit("FAIL", path)
        error(err, 0)
    end

    emit("PASS", path)
end

function M.run_specs(specs)
    for _, path in ipairs(specs or {}) do
        M.run_file(path)
    end
end

function M.run_lane(path)
    emit("RUN", path)

    local ok, err = pcall(dofile, path)
    if not ok then
        emit("FAIL", path)
        error(err, 0)
    end
end

return M
