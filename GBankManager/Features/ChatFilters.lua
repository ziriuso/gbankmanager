local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}

local chatFilters = ns.modules.chatFilters or {}

local CHAT_EVENTS = {
    "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_EMOTE",
}

local BUBBLE_EVENTS = {
    "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_YELL",
}

local MUTED_AMBIENT_NPCS = {
    ["Silvermoon Citizen"] = true,
}

local PENDING_BUBBLE_TTL = 4.0
local BUBBLE_POLL_INTERVAL = 0.05
local BUBBLE_WALK_DEPTH = 4
local pendingBubbleTexts = {}
local bubbleFrame = nil
local hiddenBubbleParent = nil

local function current_db()
    local store = ns.modules.store or ns.data and ns.data.store or nil
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    return _G.GBankManagerDB or ns.state.db or {}
end

local function mute_enabled()
    local settings = ((((current_db() or {}).ui or {}).logsHistorySettings) or {})
    return settings.muteSilvermoonCitizen == true
end

function chatFilters.IsMutedAmbientNPC(sender)
    if not mute_enabled() or type(sender) ~= "string" then
        return false
    end

    return MUTED_AMBIENT_NPCS[sender] == true
end

local function strip_chat_formatting(text)
    if not text or text == "" then
        return ""
    end

    text = tostring(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H[^|]*|h", "")
    text = text:gsub("|h", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function queue_bubble_suppression(text)
    if text == nil or text == "" or type(_G.GetTime) ~= "function" then
        return
    end

    pendingBubbleTexts[strip_chat_formatting(text)] = (_G.GetTime() or 0) + PENDING_BUBBLE_TTL
end

local function expire_pending_bubbles()
    if type(_G.GetTime) ~= "function" then
        return
    end

    local now = _G.GetTime() or 0
    for text, expiresAt in pairs(pendingBubbleTexts) do
        if now > (tonumber(expiresAt or 0) or 0) then
            pendingBubbleTexts[text] = nil
        end
    end
end

local function bubble_text_matches(text)
    text = strip_chat_formatting(text)
    if text == "" then
        return false
    end

    if pendingBubbleTexts[text] then
        return true
    end

    for queued in pairs(pendingBubbleTexts) do
        if queued ~= "" and (string.find(text, queued, 1, true) ~= nil or string.find(queued, text, 1, true) ~= nil) then
            return true
        end
    end

    return false
end

local function collect_font_strings(frame, out, depth)
    if not frame or depth <= 0 then
        return out
    end

    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            if type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
                local text = type(region.GetText) == "function" and region:GetText() or nil
                if text and text ~= "" then
                    out[#out + 1] = text
                end
            end
        end
    end

    if type(frame.GetChildren) == "function" then
        for _, child in ipairs({ frame:GetChildren() }) do
            collect_font_strings(child, out, depth - 1)
        end
    end

    return out
end

local function get_hidden_bubble_parent()
    if hiddenBubbleParent then
        return hiddenBubbleParent
    end

    if type(_G.CreateFrame) ~= "function" then
        return nil
    end

    hiddenBubbleParent = _G.CreateFrame("Frame")
    if hiddenBubbleParent.Hide then
        hiddenBubbleParent:Hide()
    end
    return hiddenBubbleParent
end

local function hide_bubble(bubble)
    if not bubble then
        return
    end

    if type(bubble.SetAlpha) == "function" then
        bubble:SetAlpha(0)
    end
    if type(bubble.Hide) == "function" then
        bubble:Hide()
    end
    if type(bubble.GetRegions) == "function" then
        for _, region in ipairs({ bubble:GetRegions() }) do
            if type(region.SetAlpha) == "function" then
                region:SetAlpha(0)
            end
            if type(region.Hide) == "function" then
                region:Hide()
            end
        end
    end

    local parent = get_hidden_bubble_parent()
    if parent and type(bubble.SetParent) == "function" then
        bubble:SetParent(parent)
    end
end

local function poll_bubbles()
    expire_pending_bubbles()
    if next(pendingBubbleTexts) == nil then
        return
    end

    local chatBubbles = _G.C_ChatBubbles
    if type(chatBubbles) ~= "table" or type(chatBubbles.GetAllChatBubbles) ~= "function" then
        return
    end

    for _, bubble in ipairs(chatBubbles.GetAllChatBubbles() or {}) do
        for _, text in ipairs(collect_font_strings(bubble, {}, BUBBLE_WALK_DEPTH)) do
            if bubble_text_matches(text) then
                hide_bubble(bubble)
                break
            end
        end
    end
end

local function handle_ambient_monster_chat(_, message, sender)
    if chatFilters.IsMutedAmbientNPC(sender) then
        queue_bubble_suppression(message)
    end
end

local function chat_message_filter(_, _, _, sender)
    return chatFilters.IsMutedAmbientNPC(sender)
end

if type(_G.ChatFrame_AddMessageEventFilter) == "function" then
    for _, eventName in ipairs(CHAT_EVENTS) do
        _G.ChatFrame_AddMessageEventFilter(eventName, chat_message_filter)
    end
end

if type(_G.CreateFrame) == "function" then
    bubbleFrame = _G.CreateFrame("Frame")
    for _, eventName in ipairs(BUBBLE_EVENTS) do
        if type(bubbleFrame.RegisterEvent) == "function" then
            bubbleFrame:RegisterEvent(eventName)
        end
    end
    if type(bubbleFrame.SetScript) == "function" then
        bubbleFrame:SetScript("OnEvent", function(_, eventName, message, sender)
            handle_ambient_monster_chat(eventName, message, sender)
        end)
    end
end

if type(_G.C_Timer) == "table" and type(_G.C_Timer.NewTicker) == "function" then
    _G.C_Timer.NewTicker(BUBBLE_POLL_INTERVAL, poll_bubbles)
end

chatFilters._StripChatFormatting = strip_chat_formatting
chatFilters._MutedAmbientNPCs = MUTED_AMBIENT_NPCS

ns.modules.chatFilters = chatFilters

return chatFilters
