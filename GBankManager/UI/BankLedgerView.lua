local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local bankLedger = ns.modules.bankLedger or {}
local craftedQuality = ns.modules.craftedQuality or {}
if craftedQuality.ToMarkup == nil and type(_G.dofile) == "function" then
    craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
end

local bankLedgerView = ns.modules.bankLedgerView or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize_timestamp(timestamp)
    local numeric = tonumber(timestamp)
    if numeric ~= nil then
        return numeric
    end

    return 0
end

local function abbreviate_timezone_name(displayText)
    local prefix, timezoneName = string.match(tostring(displayText or ""), "^(.-)([A-Za-z][A-Za-z%s]+)$")
    if not timezoneName or string.find(timezoneName, " ", 1, true) == nil then
        return tostring(displayText or "")
    end

    local known = {
        ["Eastern Daylight Time"] = "EDT",
        ["Eastern Standard Time"] = "EST",
        ["Central Daylight Time"] = "CDT",
        ["Central Standard Time"] = "CST",
        ["Mountain Daylight Time"] = "MDT",
        ["Mountain Standard Time"] = "MST",
        ["Pacific Daylight Time"] = "PDT",
        ["Pacific Standard Time"] = "PST",
        ["Greenwich Mean Time"] = "GMT",
        ["Coordinated Universal Time"] = "UTC",
    }

    local abbreviation = known[timezoneName]
    if not abbreviation then
        abbreviation = timezoneName:gsub("(%a)[%a']*", "%1"):gsub("%s+", ""):upper()
    end

    return string.format("%s%s", prefix or "", abbreviation)
end

local function format_timestamp(timestamp)
    timestamp = normalize_timestamp(timestamp)
    if timestamp == 0 then
        return "-"
    end

    local formatter = type(_G.date) == "function" and _G.date or (type(os) == "table" and type(os.date) == "function" and os.date or nil)
    if type(formatter) == "function" then
        return formatter("%Y-%m-%d", timestamp)
    end

    return tostring(timestamp)
end

local function crafted_quality_markup(atlasName)
    if type(craftedQuality.ToMarkup) == "function" then
        return craftedQuality.ToMarkup(atlasName, 22)
    end

    if atlasName == nil or atlasName == "" then
        return ""
    end

    return string.format("|A:%s:22:22|a", tostring(atlasName))
end

local function format_copper(amount)
    amount = tonumber(amount or 0) or 0
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100

    if gold > 0 then
        return string.format("%dg %02ds %02dc", gold, silver, copper)
    end
    if silver > 0 then
        return string.format("%ds %02dc", silver, copper)
    end
    return string.format("%dc", copper)
end

local ITEM_COLUMNS = {
    { key = "date", label = "Date", width = 92, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "who", label = "Who", width = 120, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "action", label = "Action", width = 82, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "tier", label = "Tier", width = 52, justifyH = "CENTER", filterMode = "none", sortable = true },
    { key = "item", label = "Item", width = 214, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "quantity", label = "Quantity", width = 70, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "tab", label = "Tab", width = 110, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "fromTab", label = "Moved From", width = 110, justifyH = "LEFT", filterMode = "text", sortable = true },
}

local MONEY_COLUMNS = {
    { key = "date", label = "Date/Time", width = 168, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "who", label = "Who", width = 198, justifyH = "LEFT", filterMode = "text", sortable = true },
    { key = "action", label = "Action", width = 124, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "amount", label = "Amount", width = 120, justifyH = "LEFT", filterMode = "none", sortable = true },
    { key = "empty1", label = "", width = 0, justifyH = "LEFT", filterMode = "none", sortable = false },
    { key = "empty2", label = "", width = 0, justifyH = "LEFT", filterMode = "none", sortable = false },
    { key = "empty3", label = "", width = 0, justifyH = "LEFT", filterMode = "none", sortable = false },
    { key = "empty4", label = "", width = 0, justifyH = "LEFT", filterMode = "none", sortable = false },
}

local ITEM_ACTION_CHOICES = {
    { value = "", label = "All Actions" },
    { value = "deposit", label = "Deposits" },
    { value = "withdraw", label = "Withdrawals" },
    { value = "move", label = "Moved" },
}

local MONEY_ACTION_CHOICES = {
    { value = "", label = "All Actions" },
    { value = "deposit", label = "Deposits" },
    { value = "withdraw", label = "Withdrawals" },
    { value = "repair", label = "Repairs" },
}

local DATE_RANGE_CHOICES = {
    { value = "1_day", label = "1 Day" },
    { value = "7_days", label = "7 Days" },
    { value = "30_days", label = "30 Days" },
    { value = "90_days", label = "90 Days" },
    { value = "6_months", label = "6 Months" },
    { value = "1_year", label = "1 Year" },
    { value = "all", label = "All" },
}

local DATE_RANGE_SECONDS = {
    ["1_day"] = 1 * 24 * 60 * 60,
    ["7_days"] = 7 * 24 * 60 * 60,
    ["30_days"] = 30 * 24 * 60 * 60,
    ["90_days"] = 90 * 24 * 60 * 60,
    ["6_months"] = 180 * 24 * 60 * 60,
    ["1_year"] = 365 * 24 * 60 * 60,
}

local function copy_columns(columns)
    local out = {}
    for index, column in ipairs(columns or {}) do
        out[index] = {
            key = column.key,
            label = column.label,
            width = column.width,
            justifyH = column.justifyH,
            filterMode = column.filterMode,
            sortable = column.sortable,
        }
    end
    return out
end

function bankLedgerView.GetColumns(mode)
    if tostring(mode or "ITEM") == "MONEY" then
        return copy_columns(MONEY_COLUMNS)
    end
    return copy_columns(ITEM_COLUMNS)
end

function bankLedgerView.GetActionChoices(mode)
    if tostring(mode or "ITEM") == "MONEY" then
        return MONEY_ACTION_CHOICES
    end
    return ITEM_ACTION_CHOICES
end

function bankLedgerView.GetActionChoiceLabel(mode, currentValue)
    local current = trim(currentValue)
    for _, choice in ipairs(bankLedgerView.GetActionChoices(mode)) do
        if trim(choice.value) == current then
            return choice.label
        end
    end
    return (bankLedgerView.GetActionChoices(mode)[1] or {}).label or "All Actions"
end

function bankLedgerView.GetDateRangeChoices()
    return DATE_RANGE_CHOICES
end

function bankLedgerView.GetDateRangeChoiceLabel(currentValue)
    local current = trim(currentValue)
    for _, choice in ipairs(DATE_RANGE_CHOICES) do
        if trim(choice.value) == current then
            return choice.label
        end
    end
    return "All"
end

local function resolve_date_range(currentValue)
    local current = trim(currentValue)
    local nowProvider = type(_G.time) == "function" and _G.time or (type(os) == "table" and type(os.time) == "function" and os.time or nil)
    local now = type(nowProvider) == "function" and (tonumber(nowProvider()) or 0) or 0
    local seconds = DATE_RANGE_SECONDS[current]
    if seconds == nil or now <= 0 then
        return 0, 0
    end
    return math.max(0, now - seconds), now
end

function bankLedgerView.CycleActionFilter(mode, currentValue)
    local choices = bankLedgerView.GetActionChoices(mode)
    local current = trim(currentValue)
    local nextIndex = 1
    for index, choice in ipairs(choices) do
        if trim(choice.value) == current then
            nextIndex = index + 1
            break
        end
    end
    if nextIndex > #choices then
        nextIndex = 1
    end
    return (choices[nextIndex] or {}).value or ""
end

function bankLedgerView.BuildFilters(mode, tableFilters, actionValue, dateRangeValue)
    local filters = tableFilters or {}
    local dateFrom, dateTo = resolve_date_range(dateRangeValue)
    filters = {
        who = filters.who or "",
        item = filters.item or filters.itemName or "",
        bankTab = filters.tab or filters.fromTab or filters.bankTab or "",
        action = actionValue or "",
        dateFrom = dateFrom,
        dateTo = dateTo,
    }
    if tostring(mode or "ITEM") == "MONEY" then
        filters.item = ""
        filters.bankTab = ""
    end
    return filters
end

function bankLedgerView.BuildDisplayRows(db, mode, filters)
    local rows = {}
    for _, entry in ipairs(bankLedger.BuildTableRows(db, mode, filters)) do
        if tostring(mode or "ITEM") == "MONEY" then
            rows[#rows + 1] = {
                date = format_timestamp(entry.timestamp),
                who = tostring(entry.who or "-"),
                action = tostring(entry.action or "-"),
                amount = format_copper(entry.amountCopper or entry.amount or 0),
                empty1 = "",
                empty2 = "",
                empty3 = "",
                empty4 = "",
                rawEntry = entry,
            }
        else
            rows[#rows + 1] = {
                date = format_timestamp(entry.timestamp),
                who = tostring(entry.who or "-"),
                action = tostring(entry.action or "-"),
                tier = crafted_quality_markup(entry.craftedQualityIcon),
                item = tostring(entry.item or "-"),
                quantity = tostring(entry.quantity or 0),
                tab = tostring(entry.tabName or "-"),
                fromTab = tostring(entry.fromTabName or "-"),
                rawEntry = entry,
            }
        end
    end
    return rows
end

function bankLedgerView.BuildSummaryTexts(db, mode, filters)
    local rangeFilters = {
        dateFrom = filters and filters.dateFrom or 0,
        dateTo = filters and filters.dateTo or 0,
    }

    local summary = bankLedger.BuildItemSummary(db, rangeFilters)
    local totalDeposits = 0
    local totalWithdrawals = 0
    local totalMoved = 0
    for _, itemSummary in pairs(summary.byItem or {}) do
        totalDeposits = totalDeposits + (tonumber(itemSummary.deposited or 0) or 0)
        totalWithdrawals = totalWithdrawals + (tonumber(itemSummary.withdrawn or 0) or 0)
        totalMoved = totalMoved + (tonumber(itemSummary.moved or 0) or 0)
    end

    local moneySummary = bankLedger.BuildMoneySummary(db, rangeFilters)

    return {
        string.format("Deposits %d | Withdrawals %d | Moved %d", totalDeposits, totalWithdrawals, totalMoved),
        string.format(
            "Gold In %s | Gold Out %s | Repairs %s",
            format_copper(moneySummary.deposits or 0),
            format_copper(moneySummary.withdrawals or 0),
            format_copper(moneySummary.repairs or 0)
        ),
        "",
    }
end

function bankLedgerView.BuildCsvText(db, mode, filters)
    return bankLedger.ExportRowsToCsv(db, mode, filters)
end

ns.modules.bankLedgerView = bankLedgerView

return bankLedgerView
