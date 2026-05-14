local assert = require("tests.helpers.assert")

local M = {}

local function apply_default_character_globals()
    _G.UnitName = function()
        return "OfficerOne"
    end

    _G.GetRealmName = function()
        return "Stormrage"
    end

    _G.GetGuildInfo = function()
        return "Guild Testers", "Officer", 1
    end

    _G.GuildControlGetNumRanks = function()
        return 3
    end

    _G.GuildControlGetRankName = function(index)
        local names = {
            [1] = "Guild Master",
            [2] = "Officer",
            [3] = "Raider",
        }

        return names[index]
    end
end

function M.load()
    apply_default_character_globals()

    local addonName, ns = assert.load_addon_from_toc("GBankManager/GBankManager.toc")
    local mainFrame = ns.modules.mainFrame

    return {
        addonName = addonName,
        ns = ns,
        mainFrame = mainFrame,
        mainFrameShell = ns.modules.mainFrameShell,
        mainTableController = ns.modules.mainTableController,
        mainRequestsController = ns.modules.mainRequestsController,
        mainExportsController = ns.modules.mainExportsController,
        mainMinimumsController = ns.modules.mainMinimumsController,
        dashboard = ns.modules.dashboardView,
        inventory = ns.modules.inventoryView,
        history = ns.modules.historyView,
        exportsView = ns.modules.exportsView,
        minimumsView = ns.modules.minimumsView,
        requestsView = ns.modules.requestsView,
        requestDialog = ns.modules.requestDialog,
        slash = ns.modules.slash,
        scanner = ns.modules.scanner,
    }
end

return M
