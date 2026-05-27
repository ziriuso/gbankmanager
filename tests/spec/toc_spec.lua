local assert = require("tests.helpers.assert")

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

assert.equal("## Interface: 120005", interfaceLine, "toc should advertise the current retail interface version")
assert.equal("## Version: 0.9.0-beta", versionLine, "toc should advertise the current addon version for release metadata and the About panel")
assert.equal("## X-Release-Tag: v0.9.0-beta.2", releaseTagLine, "toc should advertise the latest tagged beta for the About panel")
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
