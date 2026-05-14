local M = {}

function M.equal(expected, actual, message)
    if expected ~= actual then
        error((message or "values differ") .. string.format(" | expected=%s actual=%s", tostring(expected), tostring(actual)))
    end
end

function M.truthy(value, message)
    if not value then
        error(message or "expected truthy value")
    end
end

function M.same(expected, actual, message)
    if not rawequal(expected, actual) then
        error(message or "expected references to match")
    end
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function dirname(path)
    return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function addon_name_from_toc(path)
    return path:match("([^/\\]+)%.toc$") or "Addon"
end

local function toc_entries(path)
    local entries = {}
    local base = dirname(path)

    for line in io.lines(path) do
        local entry = trim(line)
        if entry ~= "" and not entry:match("^##") then
            table.insert(entries, string.format("%s/%s", base, entry))
        end
    end

    return entries
end

function M.load_addon_from_toc(path)
    local addonName = addon_name_from_toc(path)
    local ns = {}
    local loaded = {}
    local originalDofile = _G.dofile

    _G.dofile = nil

    local ok, resultAddonName, resultNamespace, resultLoaded = pcall(function()
        for _, filePath in ipairs(toc_entries(path)) do
            local chunk, loadError = loadfile(filePath)
            if not chunk then
                error(loadError)
            end

            local value = chunk(addonName, ns)
            table.insert(loaded, {
                path = filePath,
                value = value,
            })
        end

        return addonName, ns, loaded
    end)

    _G.dofile = originalDofile

    if not ok then
        error(resultAddonName)
    end

    return resultAddonName, resultNamespace, resultLoaded
end

return M
