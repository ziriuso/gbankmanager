local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local function toc_file_entries(path)
    local files = {}
    for line in io.lines(path) do
        local entry = tostring(line or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if entry ~= "" and not entry:match("^##") then
            files[#files + 1] = entry
        end
    end
    return files
end

local function load_toc_without_namespace_rebind(addonName, tocPath, ns)
    ns = ns or {}
    local basePath = tocPath:gsub("[^/\\]+$", "")
    for _, entry in ipairs(toc_file_entries(tocPath)) do
        local chunk, loadError = loadfile(basePath .. entry)
        if not chunk then
            error(loadError)
        end
        chunk(addonName, ns)
    end
    return ns
end

local interfaceLine
local versionLine
local releaseTagLine
local categoryLine
local entries = {}
local seenEntries = {}
local duplicateEntries = {}
for line in io.lines("GBankManager/GBankManager.toc") do
    if string.match(line, "^## Interface:") then
        interfaceLine = line
    elseif string.match(line, "^## Version:") then
        versionLine = line
    elseif string.match(line, "^## X%-Release%-Tag:") then
        releaseTagLine = line
    elseif string.match(line, "^## Category:") then
        categoryLine = line
    else
        local entry = tostring(line or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if entry ~= "" then
            entries[#entries + 1] = entry
            if seenEntries[entry] then
                duplicateEntries[#duplicateEntries + 1] = entry
            end
            seenEntries[entry] = true
        end
    end
end

local itemDataInterfaceLine
for line in io.lines("GBankManager_ItemData/GBankManager_ItemData.toc") do
    if string.match(line, "^## Interface:") then
        itemDataInterfaceLine = line
        break
    end
end

assert.equal("## Interface: 120007, 120005", interfaceLine, "toc should advertise the current retail interface versions")
assert.equal("## Interface: 120007, 120005", itemDataInterfaceLine, "item-data toc should advertise the current retail interface versions")
assert.equal("## Version: 1.3.1", versionLine, "toc should advertise the current addon version for release metadata and the About panel")
assert.equal("## X-Release-Tag: v1.3.1", releaseTagLine, "toc should advertise the current tagged release for the About panel")
assert.equal("## Category: Guild", categoryLine, "toc should place the addon under the Guild category in game")
assert.truthy(#duplicateEntries == 0, "toc should not contain duplicate file loads")

local positions = {}
for index, entry in ipairs(entries) do
    positions[entry] = index
end

assert.truthy(positions["Domain/Permissions.lua"] ~= nil, "toc should include the permissions module")
assert.truthy(positions["Domain/AuthPolicySource.lua"] ~= nil, "toc should include the auth policy source module")
assert.truthy(
    positions["Domain/Permissions.lua"] < positions["Domain/AuthPolicySource.lua"],
    "toc should load permissions before auth policy source so auth helpers exist on first load"
)

local originalNamespace = _G.GBankManagerNamespace
local originalDofile = _G.dofile
_G.GBankManagerNamespace = nil
_G.dofile = nil

local itemDataNamespace = load_toc_without_namespace_rebind(
    "GBankManager_ItemData",
    "GBankManager_ItemData/GBankManager_ItemData.toc",
    {}
)
local mainNamespace = load_toc_without_namespace_rebind(
    "GBankManager",
    "GBankManager/GBankManager.toc",
    {}
)

_G.GBankManagerNamespace = originalNamespace
_G.dofile = originalDofile

assert.truthy(itemDataNamespace ~= mainNamespace, "toc smoke should keep companion and main addon namespace tables distinct")
assert.truthy(type(mainNamespace.modules.craftedQuality) == "table", "main addon namespace should own craftedQuality")
assert.truthy(
    type(mainNamespace.modules.craftedQuality.GetNonInventoryDisplayAtlasForItem) == "function",
    "craftedQuality should expose non-inventory atlas resolution"
)
assert.truthy(type(mainNamespace.modules.itemDisplay) == "table", "main addon namespace should own itemDisplay")
assert.truthy(
    type(mainNamespace.modules.itemDisplay.BuildDisplayPayload) == "function",
    "itemDisplay should expose display payload builder"
)
