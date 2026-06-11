local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local ledgerScanner = ns.modules.ledgerScanner or {}

local diagnostics = {
    finalizeMode = "",
    moneyQueryId = 0,
}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function transaction_item_id(itemLink)
    local itemID = tonumber(string.match(tostring(itemLink or ""), "item:(%d+)"))
    if itemID ~= nil then
        return itemID
    end
    return tonumber(itemLink)
end

local function fallback_tab_name(tabIndex)
    return "Tab " .. tostring(tabIndex or "?")
end

local function resolve_tab_name(resolver, tabIndex)
    if type(resolver) == "function" and tonumber(tabIndex) then
        local resolved = resolver(tabIndex)
        if trim(resolved) ~= "" then
            return tostring(resolved)
        end
    end

    if type(_G.GetGuildBankTabInfo) == "function" and tonumber(tabIndex) then
        local resolved = _G.GetGuildBankTabInfo(tabIndex)
        if trim(resolved) ~= "" then
            return tostring(resolved)
        end
    end

    return fallback_tab_name(tabIndex)
end

local function moved_from_tab(target, tabOne, tabTwo)
    local resolver = type(target) == "table" and target.currentTabName or nil
    local currentTabName = tostring((target or {}).label or "")
    tabOne = tonumber(tabOne) and resolve_tab_name(resolver, tabOne) or tostring(tabOne or "")
    tabTwo = tonumber(tabTwo) and resolve_tab_name(resolver, tabTwo) or tostring(tabTwo or "")
    if tabOne ~= "" and tabOne ~= currentTabName then
        return tabOne
    end
    if tabTwo ~= "" and tabTwo ~= currentTabName then
        return tabTwo
    end
    if tabOne ~= "" then
        return tabOne
    end
    if tabTwo ~= "" then
        return tabTwo
    end
    return "-"
end

local function get_crafted_quality_info(itemInfo)
    local tradeSkillUI = _G.C_TradeSkillUI
    if type(itemInfo) ~= "string" or tradeSkillUI == nil then
        return nil, nil
    end

    local info = nil
    if type(tradeSkillUI.GetItemReagentQualityInfo) == "function" then
        info = tradeSkillUI.GetItemReagentQualityInfo(itemInfo) or info
    end

    if info == nil and type(tradeSkillUI.GetItemCraftedQualityInfo) == "function" then
        info = tradeSkillUI.GetItemCraftedQualityInfo(itemInfo)
    end

    if type(info) == "table" then
        return info.quality, info.iconInventory or info.iconMixed or info.iconChat or info.iconSmall or info.icon
    end

    local quality = nil
    if type(tradeSkillUI.GetItemReagentQualityByItemInfo) == "function" then
        quality = tradeSkillUI.GetItemReagentQualityByItemInfo(itemInfo) or quality
    end

    if quality == nil and type(tradeSkillUI.GetItemCraftedQualityByItemInfo) == "function" then
        quality = tradeSkillUI.GetItemCraftedQualityByItemInfo(itemInfo)
    end

    return quality, nil
end

local function read_item_log_transactions(target)
    local transactions = {}
    if type(_G.GetNumGuildBankTransactions) ~= "function" or type(_G.GetGuildBankTransaction) ~= "function" then
        return transactions
    end

    local transactionCount = tonumber(_G.GetNumGuildBankTransactions(target.queryId) or 0) or 0
    for index = 1, transactionCount do
        local actionType, who, itemLink, count, tabOne, tabTwo, year, month, day, hour = _G.GetGuildBankTransaction(target.queryId, index)
        local itemID = transaction_item_id(itemLink)
        if itemID ~= nil then
            local itemName = tostring(itemID)
            if _G.C_Item and type(_G.C_Item.GetItemNameByID) == "function" then
                itemName = _G.C_Item.GetItemNameByID(itemID) or itemName
            end
            local craftedQuality, craftedQualityIcon = get_crafted_quality_info(itemLink)
            transactions[#transactions + 1] = {
                type = actionType,
                who = who,
                itemID = itemID,
                itemName = itemName,
                craftedQuality = craftedQuality,
                craftedQualityIcon = craftedQualityIcon,
                quantity = tonumber(count or 0) or 0,
                fromTabName = string.lower(tostring(actionType or "")) == "move" and moved_from_tab(target, tabOne, tabTwo) or nil,
                year = year,
                month = month,
                day = day,
                hour = hour,
            }
        end
    end

    return transactions
end

local function read_money_log_transactions()
    local transactions = {}
    if type(_G.GetNumGuildBankMoneyTransactions) ~= "function" or type(_G.GetGuildBankMoneyTransaction) ~= "function" then
        return transactions
    end

    local transactionCount = tonumber(_G.GetNumGuildBankMoneyTransactions() or 0) or 0
    for index = 1, transactionCount do
        local actionType, who, amount, year, month, day, hour = _G.GetGuildBankMoneyTransaction(index)
        transactions[#transactions + 1] = {
            type = actionType,
            who = who,
            amount = tonumber(amount or 0) or 0,
            year = year,
            month = month,
            day = day,
            hour = hour,
        }
    end

    return transactions
end

function ledgerScanner.ResetDiagnostics()
    diagnostics = {
        finalizeMode = "",
        moneyQueryId = 0,
    }
end

function ledgerScanner.GetDiagnostics()
    return {
        finalizeMode = diagnostics.finalizeMode,
        moneyQueryId = diagnostics.moneyQueryId,
    }
end

function ledgerScanner.RecordFinalizeMode(mode)
    diagnostics.finalizeMode = tostring(mode or "")
end

function ledgerScanner.BuildTargets(queueAccessibleTabs, currentTabName)
    local accessibleTabs = {}
    if type(queueAccessibleTabs) == "function" then
        accessibleTabs = queueAccessibleTabs() or {}
    elseif type(queueAccessibleTabs) == "table" then
        accessibleTabs = queueAccessibleTabs
    end

    local targets = {}
    for _, tabIndex in ipairs(accessibleTabs) do
        targets[#targets + 1] = {
            kind = "item",
            queryId = tabIndex,
            label = resolve_tab_name(currentTabName, tabIndex),
            currentTabName = currentTabName,
        }
    end

    local moneyLogQueryId = (tonumber(_G.MAX_GUILDBANK_TABS or 8) or 8) + 1
    diagnostics.moneyQueryId = moneyLogQueryId
    targets[#targets + 1] = {
        kind = "money",
        queryId = moneyLogQueryId,
        label = "Money Log",
    }

    return targets
end

function ledgerScanner.QueryTargets(targets)
    local queried = 0
    if type(_G.QueryGuildBankLog) ~= "function" then
        return queried
    end

    for _, target in ipairs(targets or {}) do
        _G.QueryGuildBankLog(target.queryId)
        queried = queried + 1
    end

    return queried
end

function ledgerScanner.ReadTarget(target)
    if not target then
        return {}
    end

    if target.kind == "money" then
        return read_money_log_transactions()
    end

    return read_item_log_transactions(target)
end

function ledgerScanner.ReadAllTargets(targets)
    local results = {}
    for _, target in ipairs(targets or {}) do
        results[#results + 1] = {
            target = target,
            transactions = ledgerScanner.ReadTarget(target),
        }
    end
    return results
end

ledgerScanner.ResetDiagnostics()

ns.modules.ledgerScanner = ledgerScanner

return ledgerScanner
