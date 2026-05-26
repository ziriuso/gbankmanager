local M = {}
local addonTocRegistry = {}
local loadedAddons = {}
local addonMetadataRegistry = {}

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

local function toc_metadata(path)
    local metadata = {}

    for line in io.lines(path) do
        local key, value = tostring(line or ""):match("^##%s*([^:]+):%s*(.-)%s*$")
        if key and value then
            metadata[trim(key)] = trim(value)
        end
    end

    return metadata
end

function M.load_addon_from_toc(path)
    local addonName = addon_name_from_toc(path)
    addonTocRegistry[addonName] = path
    addonMetadataRegistry[addonName] = toc_metadata(path)
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
            if type(value) == "table" and type(value.modules) == "table" and type(value.state) == "table" then
                ns = value
            end
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

function M.register_addon_toc(addonName, path)
    addonTocRegistry[addonName] = path
    addonMetadataRegistry[addonName] = toc_metadata(path)
end

_G.EnableAddOn = _G.EnableAddOn or function()
    return true
end

_G.LoadAddOn = _G.LoadAddOn or function(addonName)
    local path = addonTocRegistry[addonName]
    if path == nil then
        local derivedPath = string.format("%s/%s.toc", tostring(addonName), tostring(addonName))
        local file = io.open(derivedPath, "r")
        if file then
            file:close()
            path = derivedPath
            addonTocRegistry[addonName] = path
        end
    end

    if path == nil then
        return false
    end

    M.load_addon_from_toc(path)
    loadedAddons[addonName] = true
    return true
end

_G.C_AddOns = _G.C_AddOns or {}
_G.C_AddOns.LoadAddOn = _G.C_AddOns.LoadAddOn or function(addonName)
    return _G.LoadAddOn(addonName)
end
_G.C_AddOns.IsAddOnLoaded = _G.C_AddOns.IsAddOnLoaded or function(addonName)
    return loadedAddons[addonName] == true
end
_G.GetAddOnMetadata = _G.GetAddOnMetadata or function(addonName, fieldName)
    local metadata = addonMetadataRegistry[tostring(addonName or "")] or {}
    return metadata[tostring(fieldName or "")]
end
_G.C_AddOns.GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata or function(addonName, fieldName)
    return _G.GetAddOnMetadata(addonName, fieldName)
end

return M
