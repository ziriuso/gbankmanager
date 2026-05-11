local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.modules.slash = ns.modules.slash or {}

local slash = ns.modules.slash
local mainFrame = ns.modules.mainFrame

local function trim(value)
    if type(_G.strtrim) == "function" then
        return _G.strtrim(value)
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

_G.SLASH_GBANKMANAGER1 = "/gbm"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList.GBANKMANAGER = function(msg)
    local scanner = ns.modules.scanner
    local command = trim(msg or ""):lower()

    if command == "ui" and type(mainFrame) == "table" and type(mainFrame.ShowDashboard) == "function" then
        mainFrame:ShowDashboard()
    elseif (command == "" or command == "scan") and type(scanner) == "table" then
        scanner.BeginScan()
    end
end

slash.command = _G.SlashCmdList.GBANKMANAGER
slash.alias = _G.SLASH_GBANKMANAGER1
slash.StartScan = slash.command

ns.modules.slash = slash

return slash
