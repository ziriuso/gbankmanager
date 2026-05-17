local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.state = ns.state or {}
ns.data = ns.data or {}

local inGameUnit = ns.modules.inGameUnit or {}

local function current_db()
    local store = ns.modules.store or ns.data.store
    if store and type(store.GetDatabase) == "function" then
        return store.GetDatabase()
    end

    local runtime = _G.GBankManagerDB or ns.state.db or {}
    _G.GBankManagerDB = runtime
    ns.state.db = runtime
    return runtime
end

local function current_time()
    local provider = _G.time or os.time
    if type(provider) == "function" then
        return provider()
    end

    return 0
end

local function push_chat_line(message)
    if type(_G.DEFAULT_CHAT_FRAME) == "table" and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(message)
        return
    end

    if type(_G.print) == "function" then
        _G.print(message)
    end
end

local function unit_result(id, ok, detail)
    return {
        id = id,
        passed = ok == true,
        detail = detail or "",
    }
end

local function persist_result(db, result)
    db.testing = db.testing or {}
    db.testing.inGameUnit = db.testing.inGameUnit or {}
    db.testing.inGameUnit.runAt = result.runAt or 0
    db.testing.inGameUnit.status = result.status or "FAIL"
    db.testing.inGameUnit.summary = result.summary or ""
    db.testing.inGameUnit.results = result.results or {}
    return db.testing.inGameUnit
end

local function run_auth_policy_round_trip()
    local codec = ns.modules.authPolicyCodec or {}
    local permissions = ns.modules.permissions or {}
    if type(codec.EncodePolicy) ~= "function" or type(codec.DecodePolicyString) ~= "function" then
        return unit_result("auth_policy_round_trip", false, "auth policy codec helpers missing")
    end

    local policy = {
        revision = 9,
        updatedAt = 1715523300,
        updatedBy = "Stormrage-OfficerOne",
        updatedByRankIndex = 1,
        restockDefault = 250,
        rankMetadata = {
            [0] = { order = 1 },
            [1] = { order = 2 },
        },
        capabilities = {
            full_ui = { [1] = true },
            request_approve = { [1] = true },
            request_delete = { [1] = true },
        },
        blacklist = {
            ["Stormrage-Troublemaker"] = {
                name = "Troublemaker",
            },
        },
    }

    local encoded = codec.EncodePolicy(policy)
    local decoded = codec.DecodePolicyString(encoded, policy.rankMetadata)
    if type(decoded) ~= "table" then
        return unit_result("auth_policy_round_trip", false, "encoded auth policy did not decode")
    end

    if string.find(encoded, "#", 1, true) == nil then
        return unit_result("auth_policy_round_trip", false, "encoded policy did not use compact updater hashing")
    end

    if decoded.restockDefault ~= 250 or tostring(decoded.updatedByHash or "") == "" then
        return unit_result("auth_policy_round_trip", false, "decoded policy lost restock default or updater hash")
    end

    if next(decoded.blacklistHashes or {}) ~= nil then
        return unit_result("auth_policy_round_trip", false, "decoded policy still carries blacklist membership from Guild Info")
    end

    return unit_result("auth_policy_round_trip", true, "auth policy codec preserved compact updater metadata, restock defaults, and officer-note-only blacklist sourcing")
end

local function run_request_contracts()
    local requests = ns.modules.requests or {}
    if type(requests.Create) ~= "function" or type(requests.ApproveStored) ~= "function" then
        return unit_result("request_contracts", false, "request helpers missing")
    end

    local created = requests.Create({
        actorContext = {
            characterKey = "Stormrage-OfficerOne",
            name = "OfficerOne",
            guildRankName = "Officer",
            guildRankIndex = 1,
            inGuild = true,
            isGuildMaster = false,
        },
        itemID = 1001,
        itemName = "Flask Alpha",
        quantity = 3,
    })

    if created.approval ~= "PENDING" then
        return unit_result("request_contracts", false, "new requests no longer start pending")
    end

    local db = {
        auth = {
            capabilities = {
                request_approve = { [1] = true },
            },
            blacklist = {},
        },
        requests = {
            {
                requestId = "self-request",
                requester = "OfficerOne",
                requesterCharacterKey = "Stormrage-OfficerOne",
                itemID = 1001,
                itemName = "Flask Alpha",
                quantity = 3,
                approval = "PENDING",
                fulfillment = "OPEN",
            },
        },
        auditLog = {},
    }

    local denied = requests.ApproveStored(db, "self-request", {
        characterKey = "Stormrage-OfficerOne",
        name = "OfficerOne",
        guildRankIndex = 1,
        guildRankName = "Officer",
        inGuild = true,
        isGuildMaster = false,
    }, 100)

    if denied ~= nil or db.requests[1].approval ~= "PENDING" then
        return unit_result("request_contracts", false, "self-approval guard regressed")
    end

    return unit_result("request_contracts", true, "request creation and self-approval guard still hold")
end

local function run_crafted_quality_normalization()
    local sharedNamespace = _G.GBankManagerNamespace or ns or {}
    local craftedQuality = ns.modules.craftedQuality
        or (type(sharedNamespace.modules) == "table" and sharedNamespace.modules.craftedQuality)
        or {}
    if type(craftedQuality.NormalizeDisplayAtlas) ~= "function" and type(_G.dofile) == "function" then
        craftedQuality = _G.dofile("GBankManager/Domain/CraftedQuality.lua")
    end
    if type(craftedQuality.NormalizeDisplayAtlas) ~= "function" then
        return unit_result("crafted_quality_normalization", false, "crafted-quality normalization helper missing")
    end

    local lowTier = craftedQuality.NormalizeDisplayAtlas("Professions-ChatIcon-Quality-Tier1")
    local highTier = craftedQuality.NormalizeDisplayAtlas("Professions-ChatIcon-Quality-Tier2")
    if lowTier ~= "Professions-ChatIcon-Quality-Tier1" or highTier ~= "Professions-ChatIcon-Quality-Tier2" then
        return unit_result("crafted_quality_normalization", false, "crafted-quality fallback icons no longer normalize to shared display atlases")
    end

    return unit_result("crafted_quality_normalization", true, "crafted-quality fallback icons normalize to the shared visible atlas family")
end

local function run_dashboard_stocking_history()
    local dashboard = ns.modules.dashboardView or {}
    if type(dashboard.BuildCards) ~= "function" then
        return unit_result("dashboard_stocking_history", false, "dashboard card builder missing")
    end

    local cards = dashboard.BuildCards({
        minimums = {
            { itemID = 1001, itemName = "Flask Alpha", quantity = 100, scope = "GLOBAL", enabled = true },
            { itemID = 2002, itemName = "Potion Beta", quantity = 50, scope = "GLOBAL", enabled = true },
        },
        snapshots = {
            scan1 = {
                scanId = "scan1",
                scannedAt = 10,
                items = {
                    [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 120, tabs = { Alchemy = 120 } },
                    [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 55, tabs = { Potions = 55 } },
                },
            },
            scan2 = {
                scanId = "scan2",
                scannedAt = 20,
                items = {
                    [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 35, tabs = { Alchemy = 35 } },
                    [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 45, tabs = { Potions = 45 } },
                },
            },
            scan3 = {
                scanId = "scan3",
                scannedAt = 30,
                items = {
                    [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 140, tabs = { Alchemy = 140 } },
                    [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 40, tabs = { Potions = 40 } },
                },
            },
            scan4 = {
                scanId = "scan4",
                scannedAt = 40,
                items = {
                    [1001] = { itemID = 1001, name = "Flask Alpha", totalCount = 30, tabs = { Alchemy = 30 } },
                    [2002] = { itemID = 2002, name = "Potion Beta", totalCount = 70, tabs = { Potions = 70 } },
                },
            },
        },
        changeLog = {
            {
                type = "QUANTITY_DECREASED",
                itemID = 9009,
                name = "Mega Feast",
                delta = 800,
            },
        },
        requests = {},
    }, {})

    local firstLine = (((cards or {})[4] or {}).lines or {})[1] or ""
    if string.find(firstLine, "Flask Alpha", 1, true) == nil or string.find(firstLine, "2 restocks", 1, true) == nil then
        return unit_result("dashboard_stocking_history", false, "dashboard top-five card no longer prioritizes repeated shortage cycles")
    end

    return unit_result("dashboard_stocking_history", true, "dashboard top-five card prefers stocking-history shortage cycles")
end

local function run_sync_sender_guard()
    local syncEvents = ns.modules.syncEvents or {}
    local codec = ns.modules.syncCodec or {}
    if type(syncEvents.HandleEvent) ~= "function" or type(codec.EncodeTable) ~= "function" then
        return unit_result("sync_sender_guard", false, "sync helpers missing")
    end

    local db = current_db()
    db.requests = {}
    db.auth = db.auth or {}
    db.auth.capabilities = db.auth.capabilities or {}
    db.auth.blacklist = db.auth.blacklist or {}
    db.auth.blacklistHashes = db.auth.blacklistHashes or {}
    db.auth.capabilities.request_submit = db.auth.capabilities.request_submit or {}

    local forgedPayload = codec.EncodeTable({
        type = "REQUEST_CREATED",
        updatedAt = 77,
        payload = {
            actorContext = {
                characterKey = "Stormrage-MemberOne",
                guildRankIndex = 2,
                guildRankName = "Raider",
                inGuild = true,
                isGuildMaster = false,
                name = "MemberOne",
            },
            request = {
                requestId = "unit-forged-1",
                requester = "MemberOne",
                requesterCharacterKey = "Stormrage-MemberOne",
                itemID = 2002,
                itemName = "Potion Beta",
                quantity = 1,
                approval = "PENDING",
                fulfillment = "OPEN",
                updatedAt = 77,
            },
        },
    })

    local accepted = syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", forgedPayload, "GUILD", "DifferentSender")
    if accepted or #(db.requests or {}) ~= 0 then
        return unit_result("sync_sender_guard", false, "sync sender validation regressed")
    end

    return unit_result("sync_sender_guard", true, "sync sender validation still rejects forged sender payloads")
end

local function run_blacklist_normalization()
    local permissions = ns.modules.permissions or {}
    if type(permissions.NormalizePolicy) ~= "function"
        or type(permissions.RemoveBlacklist) ~= "function"
        or type(permissions.HashCharacterKey) ~= "function" then
        return unit_result("blacklist_normalization", false, "permissions blacklist helpers missing")
    end

    local policy = permissions.NormalizePolicy({
        blacklist = {
            ["Stormrage-Troublemaker"] = {
                name = "Troublemaker",
                reason = "No reason",
            },
        },
    })

    if policy.blacklist["Troublemaker-Stormrage"] == nil or policy.blacklist["Stormrage-Troublemaker"] ~= nil then
        return unit_result("blacklist_normalization", false, "legacy blacklist keys no longer migrate into Character-Server order")
    end

    if permissions.HashCharacterKey("Troublemaker-Stormrage") ~= permissions.HashCharacterKey("Stormrage-Troublemaker") then
        return unit_result("blacklist_normalization", false, "blacklist hashing no longer treats old and new key orderings as the same identity")
    end

    local removed = permissions.RemoveBlacklist(policy, "Stormrage-Troublemaker")
    if removed == nil or policy.blacklist["Troublemaker-Stormrage"] ~= nil then
        return unit_result("blacklist_normalization", false, "legacy-order blacklist removal no longer clears canonical Character-Server entries")
    end

    return unit_result("blacklist_normalization", true, "blacklist normalization still migrates and removes legacy key orderings safely")
end

local function run_request_admin_queue()
    local requestsView = ns.modules.requestsView or {}
    if type(requestsView.BuildOfficerQueue) ~= "function" then
        return unit_result("request_admin_queue", false, "request queue builder missing")
    end

    local queue = requestsView.BuildOfficerQueue({
        {
            requestId = "fulfilled",
            itemName = "Banquet",
            approval = "APPROVED",
            fulfillment = "FULFILLED",
        },
        {
            requestId = "approved-open",
            itemName = "Flask Alpha",
            approval = "APPROVED",
            fulfillment = "OPEN",
        },
        {
            requestId = "pending-z",
            itemName = "Zesty Feast",
            approval = "PENDING",
            fulfillment = "OPEN",
        },
        {
            requestId = "pending-a",
            itemName = "Arcane Flask",
            approval = "PENDING",
            fulfillment = "OPEN",
        },
    }, "ALL")

    if queue[1] == nil
        or queue[2] == nil
        or queue[3] == nil
        or queue[4] == nil
        or queue[1].requestId ~= "pending-a"
        or queue[2].requestId ~= "pending-z"
        or queue[3].requestId ~= "approved-open"
        or queue[4].requestId ~= "fulfilled" then
        return unit_result("request_admin_queue", false, "request admin queue no longer prioritizes pending then approved-open rows deterministically")
    end

    local pendingFulfillment = requestsView.BuildOfficerQueue(queue, "PENDING_FULFILLMENT")
    if #pendingFulfillment ~= 1 or pendingFulfillment[1].requestId ~= "approved-open" then
        return unit_result("request_admin_queue", false, "request admin pending-fulfillment filtering regressed")
    end

    return unit_result("request_admin_queue", true, "request admin queue still prioritizes pending and approved-open rows correctly")
end

local function run_minimum_orphan_ordering()
    local minimumsView = ns.modules.minimumsView or {}
    if type(minimumsView.BuildTableRows) ~= "function" then
        return unit_result("minimum_orphan_ordering", false, "minimums table builder missing")
    end

    local rows = minimumsView.BuildTableRows({
        {
            itemID = 2002,
            itemName = "Potion Beta",
            quantity = 10,
            scope = "TAB",
            tabName = "Alchemy",
            enabled = true,
        },
        {
            itemID = 1001,
            itemName = "Flask Alpha",
            quantity = 5,
            scope = "GLOBAL",
            tabName = "",
            enabled = true,
        },
    }, {
        items = {
            [1001] = {
                itemID = 1001,
                name = "Flask Alpha",
                totalCount = 1,
                tabs = {
                    Alchemy = 1,
                },
            },
            [2002] = {
                itemID = 2002,
                name = "Potion Beta",
                totalCount = 20,
                tabs = {
                    Alchemy = 20,
                },
            },
        },
    }, {
        showAll = true,
    })

    local firstRow = rows[1]
    if firstRow == nil
        or tostring(firstRow.itemID or "") ~= "1001"
        or tostring(firstRow.bankTab or "") ~= "GLOBAL"
        or firstRow.needsBankTab ~= true then
        return unit_result("minimum_orphan_ordering", false, "unresolved GLOBAL minimum rows no longer sort to the top with repair state")
    end

    return unit_result("minimum_orphan_ordering", true, "unresolved GLOBAL minimum rows still surface first for repair")
end

function inGameUnit.Run()
    local db = current_db()
    local results = {
        run_auth_policy_round_trip(),
        run_request_contracts(),
        run_crafted_quality_normalization(),
        run_dashboard_stocking_history(),
        run_sync_sender_guard(),
        run_blacklist_normalization(),
        run_request_admin_queue(),
        run_minimum_orphan_ordering(),
    }

    local passed = true
    for _, result in ipairs(results) do
        if result.passed ~= true then
            passed = false
            break
        end
    end

    local status = passed and "PASS" or "FAIL"
    local summary = string.format("%s /gbm test unit (%d checks)", status, #results)
    local persisted = {
        runAt = current_time(),
        status = status,
        summary = summary,
        results = results,
    }

    persist_result(db, persisted)
    push_chat_line(summary)
    for _, result in ipairs(results) do
        push_chat_line(string.format("%s %s: %s", result.passed and "PASS" or "FAIL", result.id, result.detail))
    end

    return summary, persisted
end

ns.modules.inGameUnit = inGameUnit

return inGameUnit
