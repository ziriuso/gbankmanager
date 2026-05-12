local assert = require("tests.helpers.assert")

local interfaceLine
local categoryLine
for line in io.lines("GBankManager/GBankManager.toc") do
    if string.match(line, "^## Interface:") then
        interfaceLine = line
    elseif string.match(line, "^## Category:") then
        categoryLine = line
    end
end

assert.equal("## Interface: 120005", interfaceLine, "toc should advertise the current retail interface version")
assert.equal("## Category: Guild", categoryLine, "toc should place the addon under the Guild category in game")
