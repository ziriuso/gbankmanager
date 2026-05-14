local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local events = ns.modules.events or {}
local registeredEventNames = {}
local eventHandlers = {
    ns.modules.guildBankScannerEvents,
    ns.modules.syncEvents,
}

local function register_handler_events(frame, handler)
    if type(frame) ~= "table" or type(frame.RegisterEvent) ~= "function" then
        return
    end

    if type(handler) ~= "table" or type(handler.GetRegisteredEvents) ~= "function" then
        return
    end

    for _, eventName in ipairs(handler.GetRegisteredEvents() or {}) do
        if not registeredEventNames[eventName] then
            frame:RegisterEvent(eventName)
            registeredEventNames[eventName] = true
        end
    end
end

local function dispatch_event(_, event, ...)
    for _, handler in ipairs(eventHandlers) do
        if type(handler) == "table" and type(handler.HandleEvent) == "function" then
            local handled = handler.HandleEvent(event, ...)
            if handled then
                return true
            end
        end
    end

    return false
end

if type(_G.CreateFrame) == "function" and type(events.RegisterEvent) ~= "function" then
    events = _G.CreateFrame("Frame")

    for _, handler in ipairs(eventHandlers) do
        register_handler_events(events, handler)
    end

    events:SetScript("OnEvent", dispatch_event)
end

ns.modules.events = events

return events
