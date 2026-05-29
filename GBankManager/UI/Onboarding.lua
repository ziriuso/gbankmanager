local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}
ns.ui = ns.ui or {}

local onboarding = ns.modules.onboarding or {}

local MANAGER_STEPS = {
    {
        id = "welcome",
        title = "Welcome",
        description = "GBankManager helps scan guild-bank inventory, manage requests, manage minimums, and guide guild setup through permissions.",
    },
    {
        id = "permissions",
        title = "Permissions and Guild Info",
        description = "Guild access comes from the Guild Info policy. Use Options -> Permissions to review and manage rank access.",
        targetView = "OPTIONS",
        optionsTab = "PERMISSIONS",
        primaryActionLabel = "Open Permissions",
    },
    {
        id = "blacklist",
        title = "Blacklist",
        description = "Blacklist membership blocks request-system usage for tagged players. The addon reads [GBMBL] from officer notes and shows the result read-only.",
        targetView = "OPTIONS",
        optionsTab = "BLACKLIST",
        primaryActionLabel = "Open Blacklist",
    },
    {
        id = "requests",
        title = "Request System",
        description = "Members create requests and review status. Managers review, approve or deny, and choose bank tabs when approving.",
        targetView = "REQUESTS",
        primaryActionLabel = "Open Requests",
    },
    {
        id = "setup_order",
        title = "Recommended First Setup Order",
        description = "Review permissions, verify blacklist guidance, test a request flow, then scan the bank.",
        targetView = "DASHBOARD",
        primaryActionLabel = "Open Dashboard",
    },
    {
        id = "finish",
        title = "You're Ready",
        description = "Choose the next area you want to open, or close the walkthrough and continue later.",
    },
}

local REQUEST_ONLY_STEPS = {
    {
        id = "welcome",
        title = "Welcome",
        description = "You have access to the lightweight request workflow rather than the full management shell.",
    },
    {
        id = "request_flow",
        title = "How Requests Work",
        description = "Create requests, review their status, and let guild managers handle approvals.",
        targetView = "REQUESTS",
        primaryAction = "open_request_wizard",
        primaryActionLabel = "Open New Request",
    },
    {
        id = "blacklist",
        title = "Blacklist",
        description = "If guild leadership marks a player as blocked for requests, new request submission will be denied.",
    },
    {
        id = "finish",
        title = "You're Ready",
        description = "Open the request wizard or close the walkthrough and return later.",
    },
}

local function ensure_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

local function copy_steps(source)
    local copied = {}

    for index, step in ipairs(source or {}) do
        local clonedStep = {}
        for key, value in pairs(step or {}) do
            clonedStep[key] = value
        end
        copied[index] = clonedStep
    end

    return copied
end

local function state_table(db)
    db = ensure_table(db)
    db.ui = ensure_table(db.ui)
    db.ui.onboarding = ensure_table(db.ui.onboarding)
    db.ui.onboarding.completed = ensure_table(db.ui.onboarding.completed)
    db.ui.onboarding.doNotShowAgain = ensure_table(db.ui.onboarding.doNotShowAgain)
    return db.ui.onboarding
end

local function mutable_state_table(db)
    if type(db) ~= "table" then
        return nil
    end

    if type(db.ui) ~= "table" then
        return nil
    end

    if type(db.ui.onboarding) ~= "table" then
        return nil
    end

    if type(db.ui.onboarding.completed) ~= "table" then
        return nil
    end

    if type(db.ui.onboarding.doNotShowAgain) ~= "table" then
        return nil
    end

    return db.ui.onboarding
end

local function normalized_flow_key(flowKey)
    flowKey = tostring(flowKey or "")
    if flowKey == "manager" or flowKey == "requestOnly" then
        return flowKey
    end

    return nil
end

local function current_onboarding_version()
    local addonName = tostring((ns and ns.addonName) or "GBankManager")
    local getMetadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getMetadata) ~= "function" then
        return nil
    end

    local releaseTag = getMetadata(addonName, "X-Release-Tag")
    if tostring(releaseTag or "") ~= "" then
        return tostring(releaseTag)
    end

    local version = getMetadata(addonName, "Version")
    if tostring(version or "") ~= "" then
        return tostring(version)
    end

    return nil
end

function onboarding.GetFlowForAccessProfile(accessProfile)
    if accessProfile == "full_shell" then
        return "manager"
    end

    if accessProfile == "request_only" then
        return "requestOnly"
    end

    return nil
end

function onboarding.GetSteps(flowKey)
    flowKey = normalized_flow_key(flowKey)
    if flowKey == "manager" then
        return copy_steps(MANAGER_STEPS)
    end

    if flowKey == "requestOnly" then
        return copy_steps(REQUEST_ONLY_STEPS)
    end

    return {}
end

function onboarding.ShouldAutoOpen(db, flowKey)
    flowKey = normalized_flow_key(flowKey)
    if not flowKey then
        return false
    end

    local state = state_table(db)
    if state.completed[flowKey] == true then
        return false
    end

    if state.doNotShowAgain[flowKey] == true then
        return false
    end

    return true
end

function onboarding.MarkCompleted(db, flowKey)
    flowKey = normalized_flow_key(flowKey)
    if not flowKey then
        return false
    end

    local state = mutable_state_table(db)
    if not state then
        return false
    end

    state.completed[flowKey] = true
    state.lastShownVersion = current_onboarding_version()
    return true
end

function onboarding.MarkDoNotShowAgain(db, flowKey)
    flowKey = normalized_flow_key(flowKey)
    if not flowKey then
        return false
    end

    local state = mutable_state_table(db)
    if not state then
        return false
    end

    state.doNotShowAgain[flowKey] = true
    return true
end

ns.modules.onboarding = onboarding

return onboarding
