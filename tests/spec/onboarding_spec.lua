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
local mainFrame = env.mainFrame
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
assert.truthy(string.find(managerSteps[6].description or "", "Replay", 1, true) ~= nil, "manager onboarding finish step should point users to replaying the guide from Options")
assert.equal("OPTIONS", managerSteps[2].targetView, "permissions step should route to options")
assert.equal("PERMISSIONS", managerSteps[2].optionsTab, "permissions step should target the permissions options tab")
assert.equal("Open Permissions", managerSteps[2].primaryActionLabel, "permissions step should expose the expected action label")
assert.truthy(string.find(managerSteps[2].description or "", "Guild Info", 1, true) ~= nil, "permissions onboarding should name Guild Info as the policy source")
assert.truthy(string.find(managerSteps[2].description or "", "Refresh Guild Policy", 1, true) ~= nil, "permissions onboarding should point players to Refresh Guild Policy")
assert.equal("OPTIONS", managerSteps[3].targetView, "blacklist step should route to options")
assert.equal("BLACKLIST", managerSteps[3].optionsTab, "blacklist step should target the blacklist options tab")
assert.equal("Open Blacklist", managerSteps[3].primaryActionLabel, "blacklist step should expose the expected action label")
assert.truthy(string.find(managerSteps[3].description or "", "read-only", 1, true) ~= nil, "blacklist onboarding should explain why parsed blacklist results are read-only")
assert.equal("REQUESTS", managerSteps[4].targetView, "manager requests step should route to requests")
assert.equal("Open Requests", managerSteps[4].primaryActionLabel, "manager requests step should expose the expected action label")
assert.truthy(string.find(managerSteps[4].description or "", "online addon users", 1, true) ~= nil, "manager request onboarding should explain request synchronization between online addon users")
assert.equal("DASHBOARD", managerSteps[5].targetView, "setup order step should route back to dashboard")
assert.equal("Open Dashboard", managerSteps[5].primaryActionLabel, "setup order step should expose the expected action label")
assert.equal("welcome", requestSteps[1].id, "request onboarding should start with welcome")
assert.equal("request_flow", requestSteps[2].id, "request onboarding should cover the request flow after welcome")
assert.equal("blacklist", requestSteps[3].id, "request onboarding should cover blacklist before finish")
assert.equal("finish", requestSteps[4].id, "request onboarding should end with finish")
assert.equal("REQUESTS", requestSteps[2].targetView, "request flow step should route to requests")
assert.equal("open_request_wizard", requestSteps[2].primaryAction, "request flow step should expose the request wizard action")
assert.equal("Open New Request", requestSteps[2].primaryActionLabel, "request flow step should expose the expected action label")
assert.truthy(string.find(requestSteps[2].description or "", "online addon users", 1, true) ~= nil, "request-only onboarding should explain request synchronization between online addon users")

assert.truthy(type(mainFrame.OpenOnboarding) == "function", "main frame should expose onboarding open behavior")
assert.truthy(type(mainFrame.AdvanceOnboardingStep) == "function", "main frame should expose onboarding advance behavior")
assert.truthy(type(mainFrame.RunOnboardingPrimaryAction) == "function", "main frame should expose onboarding primary action behavior")
assert.truthy(type(mainFrame.CloseOnboarding) == "function", "main frame should expose onboarding close behavior")

local openedModal = mainFrame:OpenOnboarding("manager", {
    auto = false,
    reason = "spec_manager",
})

assert.same(mainFrame.onboardingModal, openedModal, "opening onboarding should return the shared onboarding modal")
assert.truthy(mainFrame.onboardingModal and mainFrame.onboardingModal:IsShown(), "manager onboarding should show its modal shell")
assert.equal("LeftButton", ((mainFrame.onboardingModal.dragButtons or {})[1]), "onboarding modal should be draggable with the left mouse button")
assert.same(mainFrame.onboardingModal.nextButton, (((mainFrame.onboardingModal.doNotShowAgainButton.points or {})[1] or {})[2]), "step-one do-not-show-again should anchor from Next so Next owns the far-right corner")
assert.same(mainFrame.onboardingModal.doNotShowAgainButton, (((mainFrame.onboardingModal.primaryActionButton.points or {})[1] or {})[2]), "step-one primary action should anchor from do-not-show-again so the footer row stays grouped on the right")
assert.equal("BOTTOMRIGHT", (((mainFrame.onboardingModal.nextButton.points or {})[1] or {})[1]), "step-one Next should anchor to the modal's bottom-right corner")
assert.equal("RIGHT", (((mainFrame.onboardingModal.doNotShowAgainButton.points or {})[1] or {})[1]), "step-one do-not-show-again should anchor to the left side of Next")
assert.truthy((mainFrame.onboardingModal.doNotShowAgainButton:GetWidth() or 0) >= 164, "do-not-show-again should remain a wide readable footer action")
assert.truthy(mainFrame.onboardingModal.skipButton == nil or not mainFrame.onboardingModal.skipButton:IsShown(), "onboarding should no longer expose a skip footer action")
assert.truthy(mainFrame.onboardingModal.doNotShowAgainButton:IsShown(), "step one should keep the do-not-show-again suppression action visible")
assert.equal("manager", mainFrame.onboardingFlowKey, "manager onboarding should track its active flow key")
assert.equal(1, mainFrame.onboardingStepIndex, "manager onboarding should start at the first step")
assert.equal("welcome", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should start on the welcome step")

mainFrame.onboardingModal:ClearAllPoints()
mainFrame.onboardingModal:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 24, -24)
mainFrame:CloseOnboarding()
mainFrame:OpenOnboarding("manager", {
    auto = false,
    reason = "spec_manager_reopen",
})
assert.equal("CENTER", ((mainFrame.onboardingModal.points[1] or {})[1]), "reopened onboarding should recenter instead of preserving a dragged point")
assert.same(mainFrame.content, (mainFrame.onboardingModal.points[1] or {})[2], "reopened onboarding should recenter against the shell content frame")

mainFrame:AdvanceOnboardingStep()
assert.truthy(mainFrame.onboardingModal.backButton:IsShown(), "back should appear on later onboarding steps")
assert.truthy(not mainFrame.onboardingModal.doNotShowAgainButton:IsShown(), "later onboarding steps should hide the do-not-show-again suppression action")
assert.truthy(mainFrame.onboardingModal.skipButton == nil or not mainFrame.onboardingModal.skipButton:IsShown(), "later onboarding steps should also keep skip hidden")
assert.same(mainFrame.onboardingModal.nextButton, (((mainFrame.onboardingModal.backButton.points or {})[1] or {})[2]), "later-step back should chain from next in the right-aligned footer row")
assert.same(mainFrame.onboardingModal.backButton, (((mainFrame.onboardingModal.primaryActionButton.points or {})[1] or {})[2]), "later-step primary actions should join the same right-aligned footer group")
assert.equal("RIGHT", (((mainFrame.onboardingModal.backButton.points or {})[1] or {})[1]), "later-step back should anchor to the left side of Next")
assert.equal("RIGHT", (((mainFrame.onboardingModal.primaryActionButton.points or {})[1] or {})[1]), "later-step primary actions should anchor to the left side of Back")
assert.equal("permissions", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should advance to permissions after welcome")
mainFrame:RunOnboardingPrimaryAction()
assert.equal("OPTIONS", mainFrame.activeView, "manager permissions onboarding should route to options")
assert.equal("PERMISSIONS", mainFrame.optionsActiveTab, "manager permissions onboarding should open the permissions tab")

mainFrame:AdvanceOnboardingStep()
assert.equal("blacklist", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should advance to blacklist after permissions")
mainFrame:RunOnboardingPrimaryAction()
assert.equal("BLACKLIST", mainFrame.optionsActiveTab, "manager blacklist onboarding should open the blacklist tab")

mainFrame:AdvanceOnboardingStep()
assert.equal("requests", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should advance to requests after blacklist")
mainFrame:RunOnboardingPrimaryAction()
assert.equal("REQUESTS", mainFrame.activeView, "manager requests onboarding should route to requests")
assert.equal(false, mainFrame.requestOnlyMode == true, "manager onboarding should keep the full shell routing")

mainFrame:AdvanceOnboardingStep()
assert.equal("setup_order", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should advance to setup order before finish")
mainFrame:RunOnboardingPrimaryAction()
assert.equal("DASHBOARD", mainFrame.activeView, "setup order onboarding should route back to dashboard")

mainFrame:AdvanceOnboardingStep()
assert.equal("finish", (mainFrame.onboardingCurrentStep or {}).id, "manager onboarding should end on the finish step")
mainFrame:AdvanceOnboardingStep()
assert.truthy(mainFrame.onboardingModal and not mainFrame.onboardingModal:IsShown(), "completing manager onboarding should hide the modal")
assert.equal(nil, mainFrame.onboardingFlowKey, "completing manager onboarding should clear the active flow key")
assert.equal(nil, mainFrame.onboardingCurrentStep, "completing manager onboarding should clear the current step state")
assert.equal(true, (((db.ui or {}).onboarding or {}).completed or {}).manager, "completing manager onboarding should persist completion")
assert.equal(false, onboarding.ShouldAutoOpen(db, "manager"), "completed manager onboarding should not auto-open again")
