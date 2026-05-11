local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.modules.events = ns.modules.events or {}

local events = ns.modules.events

if type(_G.CreateFrame) == "function" and type(events.RegisterEvent) ~= "function" then
    events = _G.CreateFrame("Frame")
    events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    events:SetScript("OnEvent", function(_, event, ...)
        local scanner = ns.modules.scanner

        if event == "GUILDBANKBAGSLOTS_CHANGED" and type(scanner) == "table" and scanner.scanInProgress then
            scanner.OnGuildBankSlotsChanged(...)
        end
    end)
end

ns.modules.events = events

return events
