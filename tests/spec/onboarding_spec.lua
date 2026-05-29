package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
    package.path,
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local onboarding = env.ns.modules.onboarding
local migrations = env.ns.modules.migrations
local db = env.ns.state.db or _G.GBankManagerDB or {}
local addonName = tostring((env.ns and env.ns.addonName) or "GBankManager")
local getMetadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
local expectedLastShownVersion = nil

if type(getMetadata) == "function" then
    expectedLastShownVersion = getMetadata(addonName, "X-Release-Tag") or getMetadata(addonName, "Version")
end

assert.truthy(type(onboarding) == "table", "onboarding module should be registered")
assert.truthy(type(onboarding.GetFlowForAccessProfile) == "function", "onboarding should expose flow selection")
assert.truthy(type(onboarding.GetSteps) == "function", "onboarding should expose step lookup")
assert.truthy(type(onboarding.ShouldAutoOpen) == "function", "onboarding should expose auto-open checks")
assert.truthy(type(onboarding.MarkCompleted) == "function", "onboarding should expose completion helpers")
assert.truthy(type(onboarding.MarkDoNotShowAgain) == "function", "onboarding should expose suppression helpers")

assert.equal("manager", onboarding.GetFlowForAccessProfile("full_shell"), "full-shell access should map to the manager onboarding flow")
assert.equal("requestOnly", onboarding.GetFlowForAccessProfile("request_only"), "request-only access should map to the request onboarding flow")
assert.equal(nil, onboarding.GetFlowForAccessProfile("blocked"), "blocked access should not map to an onboarding flow")
assert.equal(false, onboarding.MarkCompleted(nil, "manager"), "completing onboarding should fail safely when db is missing")
assert.equal(false, onboarding.MarkCompleted({}, "manager"), "completing onboarding should fail safely when db shape is malformed")
assert.equal(false, onboarding.MarkDoNotShowAgain(nil, "requestOnly"), "suppressing onboarding should fail safely when db is missing")
assert.equal(false, onboarding.MarkDoNotShowAgain({}, "requestOnly"), "suppressing onboarding should fail safely when db shape is malformed")

local migratedDb = migrations.ApplyDatabase({
    meta = {
        guildName = "Guild Testers",
    },
    ui = {
        onboarding = {
            completed = {
                manager = true,
            },
            doNotShowAgain = {
                manager = "yes",
                requestOnly = true,
            },
            lastShownVersion = "v0.8.0-beta.1",
        },
    },
}, "Guild Testers")

assert.equal(true, (((migratedDb.ui or {}).onboarding or {}).completed or {}).manager, "migration should preserve completed manager onboarding")
assert.equal(false, (((migratedDb.ui or {}).onboarding or {}).completed or {}).requestOnly, "migration should default missing request-only completion state to false")
assert.equal(false, (((migratedDb.ui or {}).onboarding or {}).doNotShowAgain or {}).manager, "migration should normalize malformed manager suppression state to false")
assert.equal(true, (((migratedDb.ui or {}).onboarding or {}).doNotShowAgain or {}).requestOnly, "migration should preserve request-only suppression state")
assert.equal("v0.8.0-beta.1", (((migratedDb.ui or {}).onboarding or {}).lastShownVersion), "migration should preserve onboarding last shown version")

assert.equal(true, onboarding.ShouldAutoOpen(db, "manager"), "manager onboarding should auto-open by default")
onboarding.MarkCompleted(db, "manager")
assert.equal(false, onboarding.ShouldAutoOpen(db, "manager"), "completed manager onboarding should stop auto-open")
assert.equal(expectedLastShownVersion, (((db.ui or {}).onboarding or {}).lastShownVersion), "completed onboarding should record the last shown addon version")

assert.equal(true, onboarding.ShouldAutoOpen(db, "requestOnly"), "request onboarding should auto-open by default")
onboarding.MarkDoNotShowAgain(db, "requestOnly")
assert.equal(false, onboarding.ShouldAutoOpen(db, "requestOnly"), "suppressed request onboarding should stop auto-open")

local managerSteps = onboarding.GetSteps("manager")
local requestSteps = onboarding.GetSteps("requestOnly")
assert.truthy(type(managerSteps) == "table" and #managerSteps >= 5, "manager onboarding should define a short multi-step walkthrough")
assert.truthy(type(requestSteps) == "table" and #requestSteps >= 3, "request onboarding should define a shorter walkthrough")
assert.equal("welcome", managerSteps[1].id, "manager onboarding should start with welcome")
assert.equal("permissions", managerSteps[2].id, "manager onboarding should cover permissions immediately after welcome")
assert.equal("blacklist", managerSteps[3].id, "manager onboarding should cover blacklist after permissions")
assert.equal("requests", managerSteps[4].id, "manager onboarding should cover requests before setup order")
assert.equal("setup_order", managerSteps[5].id, "manager onboarding should include the recommended setup order step")
assert.equal("finish", managerSteps[6].id, "manager onboarding should end with finish")
assert.equal("OPTIONS", managerSteps[2].targetView, "permissions step should route to options")
assert.equal("PERMISSIONS", managerSteps[2].optionsTab, "permissions step should target the permissions options tab")
assert.equal("Open Permissions", managerSteps[2].primaryActionLabel, "permissions step should expose the expected action label")
assert.equal("OPTIONS", managerSteps[3].targetView, "blacklist step should route to options")
assert.equal("BLACKLIST", managerSteps[3].optionsTab, "blacklist step should target the blacklist options tab")
assert.equal("Open Blacklist", managerSteps[3].primaryActionLabel, "blacklist step should expose the expected action label")
assert.equal("REQUESTS", managerSteps[4].targetView, "manager requests step should route to requests")
assert.equal("Open Requests", managerSteps[4].primaryActionLabel, "manager requests step should expose the expected action label")
assert.equal("DASHBOARD", managerSteps[5].targetView, "setup order step should route back to dashboard")
assert.equal("Open Dashboard", managerSteps[5].primaryActionLabel, "setup order step should expose the expected action label")
assert.equal("welcome", requestSteps[1].id, "request onboarding should start with welcome")
assert.equal("request_flow", requestSteps[2].id, "request onboarding should cover the request flow after welcome")
assert.equal("blacklist", requestSteps[3].id, "request onboarding should cover blacklist before finish")
assert.equal("finish", requestSteps[4].id, "request onboarding should end with finish")
assert.equal("REQUESTS", requestSteps[2].targetView, "request flow step should route to requests")
assert.equal("open_request_wizard", requestSteps[2].primaryAction, "request flow step should expose the request wizard action")
assert.equal("Open New Request", requestSteps[2].primaryActionLabel, "request flow step should expose the expected action label")
