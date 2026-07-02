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

local function normalize_spec_path(path)
    path = tostring(path or ""):gsub("\\", "/")
    if path ~= "" and not path:find("^tests/spec/") then
        path = "tests/spec/" .. path
    end
    return path
end

function M.collect_spec_files()
    local files = {}
    local slash = tostring(package.config or ""):sub(1, 1)
    local command = slash == "\\"
        and 'dir /b tests\\spec\\*_spec.lua 2>nul'
        or 'ls tests/spec/*_spec.lua 2>/dev/null'
    local handle = io.popen and io.popen(command)
    if handle then
        for file in handle:lines() do
            file = normalize_spec_path(file)
            if file ~= "" then
                files[#files + 1] = file
            end
        end
        handle:close()
    end
    table.sort(files)
    return files
end

function M.find_lane_coverage_gaps(lanes)
    local owned = {}
    local duplicates = {}
    for _, specs in pairs(lanes or {}) do
        for _, spec in ipairs(specs or {}) do
            spec = normalize_spec_path(spec)
            if owned[spec] then
                duplicates[#duplicates + 1] = spec
            end
            owned[spec] = true
        end
    end

    local missing = {}
    for _, spec in ipairs(M.collect_spec_files()) do
        if not owned[spec] then
            missing[#missing + 1] = spec
        end
    end

    table.sort(missing)
    table.sort(duplicates)
    return missing, duplicates
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
