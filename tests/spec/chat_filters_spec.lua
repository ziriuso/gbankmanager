local assert = require("tests.helpers.assert")

dofile("tests/helpers/wow_stubs.lua")

local inaccessibleChatValue = nil
local originalCanAccessValue = _G.canaccessvalue
local originalNewTicker = _G.C_Timer.NewTicker
local originalChatBubbles = _G.C_ChatBubbles
local bubblePoll = nil
local bubbleText = ""
local bubble = {
    hidden = false,
}
local bubbleRegion = {
    hidden = false,
}

_G.canaccessvalue = function(value)
    return inaccessibleChatValue == nil or value ~= inaccessibleChatValue
end

_G.C_Timer.NewTicker = function(_, callback)
    bubblePoll = callback
    return {
        Cancel = function() end,
    }
end

function bubbleRegion:GetObjectType()
    return "FontString"
end

function bubbleRegion:GetText()
    return bubbleText
end

function bubbleRegion:SetAlpha(value)
    self.alpha = value
end

function bubbleRegion:Hide()
    self.hidden = true
end

function bubble:GetRegions()
    return bubbleRegion
end

function bubble:GetChildren()
    return nil
end

function bubble:SetAlpha(value)
    self.alpha = value
end

function bubble:Hide()
    self.hidden = true
end

function bubble:SetParent(parent)
    self.parent = parent
end

_G.C_ChatBubbles = {
    GetAllChatBubbles = function()
        return { bubble }
    end,
}

local function reset_bubble(text)
    bubbleText = text
    bubble.hidden = false
    bubble.alpha = 1
    bubble.parent = nil
    bubbleRegion.hidden = false
    bubbleRegion.alpha = 1
end

local _, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
local chatFilters = ns.modules.chatFilters
local db = ns.modules.store.GetDatabase()

db.ui.logsHistorySettings.muteSilvermoonCitizen = false
assert.truthy(chatFilters.IsMutedAmbientNPC("Silvermoon Citizen") ~= true, "ambient NPC filter should stay disabled until the user enables it")

db.ui.logsHistorySettings.muteSilvermoonCitizen = true
assert.truthy(chatFilters.IsMutedAmbientNPC("Silvermoon Citizen") == true, "ambient NPC filter should suppress Silvermoon Citizen once the user enables it")
assert.truthy(chatFilters.IsMutedAmbientNPC("Some Other NPC") ~= true, "ambient NPC filter should stay scoped to the curated NPC list")

inaccessibleChatValue = "Silvermoon Citizen"
local senderSafe, senderMuted = pcall(chatFilters.IsMutedAmbientNPC, inaccessibleChatValue)
assert.truthy(senderSafe, "ambient NPC filtering should not operate on an inaccessible sender")
assert.truthy(senderMuted ~= true, "ambient NPC filtering should fail open when the sender is inaccessible")

assert.truthy(type(bubblePoll) == "function", "ambient NPC filtering should register its bubble poller")

inaccessibleChatValue = nil
reset_bubble("Ordinary ambient line")
_G.FireEvent("CHAT_MSG_MONSTER_SAY", bubbleText, "Silvermoon Citizen")
bubblePoll()
assert.truthy(bubble.hidden == true, "accessible Silvermoon Citizen bubble text should still be suppressed")

inaccessibleChatValue = "Restricted ambient line"
reset_bubble(inaccessibleChatValue)
local messageSafe = pcall(_G.FireEvent, "CHAT_MSG_MONSTER_SAY", inaccessibleChatValue, "Silvermoon Citizen")
assert.truthy(messageSafe, "ambient NPC filtering should not operate on an inaccessible chat message")
local restrictedMessagePollSafe = pcall(bubblePoll)
assert.truthy(restrictedMessagePollSafe, "bubble polling should remain safe after an inaccessible chat message")
assert.truthy(bubble.hidden ~= true, "an inaccessible chat message should not be queued for bubble suppression")

inaccessibleChatValue = nil
reset_bubble("Restricted rendered bubble")
_G.FireEvent("CHAT_MSG_MONSTER_SAY", bubbleText, "Silvermoon Citizen")
inaccessibleChatValue = bubbleText
local restrictedBubblePollSafe = pcall(bubblePoll)
assert.truthy(restrictedBubblePollSafe, "bubble polling should not operate on inaccessible rendered text")
assert.truthy(bubble.hidden ~= true, "inaccessible rendered bubble text should not be matched or hidden")

_G.canaccessvalue = originalCanAccessValue
_G.C_Timer.NewTicker = originalNewTicker
_G.C_ChatBubbles = originalChatBubbles
