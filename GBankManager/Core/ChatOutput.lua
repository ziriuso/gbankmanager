local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local chatOutput = ns.modules.chatOutput or {}

local function current_db()
    local store = ns.modules.store or ns.data and ns.data.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    return (ns.state or {}).db or _G.GBankManagerDB or {}
end

local function ensure_chat_settings(db)
    db = type(db) == "table" and db or {}
    db.ui = type(db.ui) == "table" and db.ui or {}
    db.ui.chatSettings = type(db.ui.chatSettings) == "table" and db.ui.chatSettings or {}
    db.ui.chatSettings.suppressRoutineMessages = db.ui.chatSettings.suppressRoutineMessages == true
    return db.ui.chatSettings
end

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(tostring(message or ""))
        return true
    end

    if type(_G.print) == "function" then
        _G.print(message)
        return true
    end

    return false
end

function chatOutput.GetSettings(db)
    return ensure_chat_settings(db or current_db())
end

function chatOutput.IsRoutineMuted(db)
    return ensure_chat_settings(db or current_db()).suppressRoutineMessages == true
end

function chatOutput.Send(message, options)
    options = type(options) == "table" and options or {}
    if tostring(options.category or "") == "routine" and chatOutput.IsRoutineMuted(options.db) then
        return false, "suppressed"
    end

    return push_chat_line(message), "sent"
end

ns.modules.chatOutput = chatOutput

return chatOutput
