# GBankManager First-Run Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a role-aware first-run onboarding walkthrough that auto-opens the first time a player opens the UI they can access from `/gbm` or the minimap button, supports `Skip` and `Do not show again`, and can be replayed from `Options` for full-shell users.

**Architecture:** Keep onboarding state local in SavedVariables under `db.ui`, add one focused onboarding helper module for step definitions plus state evaluation, and let `MainFrame.lua` own the actual modal frame plus view-switch behavior. Reuse the existing accessible-UI entry points instead of building a second launcher path, and keep the implementation split across persistence, trigger integration, modal rendering, and focused tests.

**Tech Stack:** Lua 5.1 WoW addon runtime, existing `MainFrame` UI shell, current slash-command and minimap entry paths, local Lua test runner specs in `tests/spec`.

---

## File Structure

### Files to create

- `GBankManager/UI/Onboarding.lua`
  - Own the onboarding step data, state helpers, flow selection, and controller-facing callbacks.
- `tests/spec/onboarding_spec.lua`
  - Cover onboarding state, flow selection, skip, completion, and suppression behavior.
- `docs/superpowers/plans/2026-05-29-gbankmanager-first-run-onboarding-implementation.md`
  - This implementation plan.

### Files to modify

- `GBankManager/GBankManager.toc`
  - Load the new onboarding module in the correct order before `MainFrame.lua`.
- `GBankManager/Data/Defaults.lua`
  - Add default onboarding state under `db.ui`.
- `GBankManager/Data/Migrations.lua`
  - Normalize and backfill onboarding state for existing databases.
- `GBankManager/Core/SlashCommands.lua`
  - Route `/gbm` and `/gbm ui` through onboarding-aware accessible UI entry.
- `GBankManager/UI/MinimapButton.lua`
  - Route minimap-open behavior through the same onboarding-aware path.
- `GBankManager/UI/MainFrame.lua`
  - Build the onboarding modal, wire step actions, and add the `Options` replay entry.
- `tests/spec/slash_commands_spec.lua`
  - Cover `/gbm` and `/gbm ui` onboarding trigger behavior.
- `tests/spec/ui_shell_spec.lua`
  - Cover minimap-triggered onboarding behavior.
- `tests/spec/ui_options_spec.lua`
  - Cover replay from `Options`.
- `tests/spec/ui_requests_spec.lua`
  - Cover request-only onboarding staying inside the compact request surface.
- `docs/manual-test-checklist.md`
  - Add manual verification steps for first-run onboarding.
- `docs/superpowers/handoffs/latest-handoff.md`
  - Keep the resume guidance current once implementation lands.

### Boundary decisions

- Keep onboarding flow definitions out of `MainFrame.lua` by storing them in `UI/Onboarding.lua`.
- Keep persistence shape in `db.ui` because this is local UX state, not guild-shared data.
- Do not add a second “welcome screen” mode. The onboarding modal should overlay the UI the player already has access to.

---

### Task 1: Add onboarding persistence and flow definitions

**Files:**
- Create: `GBankManager/UI/Onboarding.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Data/Defaults.lua`
- Modify: `GBankManager/Data/Migrations.lua`
- Test: `tests/spec/onboarding_spec.lua`

- [ ] **Step 1: Write the failing onboarding state spec**

```lua
package.path = table.concat({
    "./?.lua",
    "./tests/?.lua",
}, ";")

dofile("tests/helpers/wow_stubs.lua")

local assert = require("tests.helpers.assert")
local fixture = require("tests.helpers.ui_fixture")

local env = fixture.load()
local onboarding = env.ns.modules.onboarding
local db = env.store.GetDatabase()

assert.truthy(type(onboarding.GetFlowForAccessProfile) == "function", "onboarding should expose flow selection")
assert.truthy(type(onboarding.ShouldAutoOpen) == "function", "onboarding should expose auto-open checks")
assert.truthy(type(onboarding.MarkCompleted) == "function", "onboarding should expose completion helpers")
assert.truthy(type(onboarding.MarkDoNotShowAgain) == "function", "onboarding should expose suppression helpers")

assert.equal("manager", onboarding.GetFlowForAccessProfile("full_shell"), "full-shell access should map to the manager onboarding flow")
assert.equal("requestOnly", onboarding.GetFlowForAccessProfile("request_only"), "request-only access should map to the request onboarding flow")
assert.equal(nil, onboarding.GetFlowForAccessProfile("blocked"), "blocked access should not map to an onboarding flow")

assert.equal(true, onboarding.ShouldAutoOpen(db, "manager"), "manager onboarding should auto-open by default")
onboarding.MarkCompleted(db, "manager")
assert.equal(false, onboarding.ShouldAutoOpen(db, "manager"), "completed manager onboarding should stop auto-open")

assert.equal(true, onboarding.ShouldAutoOpen(db, "requestOnly"), "request onboarding should auto-open by default")
onboarding.MarkDoNotShowAgain(db, "requestOnly")
assert.equal(false, onboarding.ShouldAutoOpen(db, "requestOnly"), "suppressed request onboarding should stop auto-open")

local managerSteps = onboarding.GetSteps("manager")
local requestSteps = onboarding.GetSteps("requestOnly")
assert.truthy(type(managerSteps) == "table" and #managerSteps >= 5, "manager onboarding should define a short multi-step walkthrough")
assert.truthy(type(requestSteps) == "table" and #requestSteps >= 3, "request onboarding should define a shorter walkthrough")
assert.equal("welcome", managerSteps[1].id, "manager onboarding should start with welcome")
assert.equal("welcome", requestSteps[1].id, "request onboarding should start with welcome")
```

- [ ] **Step 2: Run the onboarding state spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua`

Expected: `FAIL` because `ns.modules.onboarding` and its helpers do not exist yet.

- [ ] **Step 3: Add onboarding defaults and migration shape**

```lua
-- GBankManager/Data/Defaults.lua inside defaults.CreateDatabase(...).ui
onboarding = {
    completed = {
        manager = false,
        requestOnly = false,
    },
    doNotShowAgain = {
        manager = false,
        requestOnly = false,
    },
    lastShownVersion = nil,
},
```

```lua
-- GBankManager/Data/Migrations.lua inside ensure_v1_shape(db, guildName)
db.ui.onboarding = ensure_table(db.ui.onboarding)
db.ui.onboarding.completed = ensure_table(db.ui.onboarding.completed)
db.ui.onboarding.completed.manager = db.ui.onboarding.completed.manager == true
db.ui.onboarding.completed.requestOnly = db.ui.onboarding.completed.requestOnly == true
db.ui.onboarding.doNotShowAgain = ensure_table(db.ui.onboarding.doNotShowAgain)
db.ui.onboarding.doNotShowAgain.manager = db.ui.onboarding.doNotShowAgain.manager == true
db.ui.onboarding.doNotShowAgain.requestOnly = db.ui.onboarding.doNotShowAgain.requestOnly == true
db.ui.onboarding.lastShownVersion = db.ui.onboarding.lastShownVersion or nil
```

```lua
-- GBankManager/UI/Onboarding.lua
local _, ns = ...

ns = ns or {}
ns.modules = ns.modules or {}

local onboarding = ns.modules.onboarding or {}

local MANAGER_STEPS = {
    { id = "welcome", title = "Welcome", description = "GBankManager helps scan guild-bank inventory, manage requests, manage minimums, and guide guild setup through permissions." },
    { id = "permissions", title = "Permissions and Guild Info", description = "Guild access comes from the Guild Info policy. Use Options -> Permissions to review and manage rank access.", targetView = "OPTIONS", optionsTab = "PERMISSIONS", primaryActionLabel = "Open Permissions" },
    { id = "blacklist", title = "Blacklist", description = "Blacklist membership blocks request-system usage for tagged players. The addon reads [GBMBL] from officer notes and shows the result read-only.", targetView = "OPTIONS", optionsTab = "BLACKLIST", primaryActionLabel = "Open Blacklist" },
    { id = "requests", title = "Request System", description = "Members create requests and review status. Managers review, approve or deny, and choose bank tabs when approving.", targetView = "REQUESTS", primaryActionLabel = "Open Requests" },
    { id = "setup_order", title = "Recommended First Setup Order", description = "Review permissions, verify blacklist guidance, test a request flow, then scan the bank.", targetView = "DASHBOARD", primaryActionLabel = "Open Dashboard" },
    { id = "finish", title = "You're Ready", description = "Choose the next area you want to open, or close the walkthrough and continue later." },
}

local REQUEST_ONLY_STEPS = {
    { id = "welcome", title = "Welcome", description = "You have access to the lightweight request workflow rather than the full management shell." },
    { id = "request_flow", title = "How Requests Work", description = "Create requests, review their status, and let guild managers handle approvals.", targetView = "REQUESTS", primaryActionLabel = "Open New Request", primaryAction = "open_request_wizard" },
    { id = "blacklist", title = "Blacklist", description = "If guild leadership marks a player as blocked for requests, new request submission will be denied." },
    { id = "finish", title = "You're Ready", description = "Open the request wizard or close the walkthrough and return later." },
}

local function state_table(db)
    db.ui = db.ui or {}
    db.ui.onboarding = db.ui.onboarding or {}
    db.ui.onboarding.completed = db.ui.onboarding.completed or {}
    db.ui.onboarding.doNotShowAgain = db.ui.onboarding.doNotShowAgain or {}
    return db.ui.onboarding
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
    if flowKey == "manager" then
        return MANAGER_STEPS
    end
    if flowKey == "requestOnly" then
        return REQUEST_ONLY_STEPS
    end
    return {}
end

function onboarding.ShouldAutoOpen(db, flowKey)
    local state = state_table(db)
    if flowKey == nil then
        return false
    end
    if state.completed[flowKey] == true then
        return false
    end
    if state.doNotShowAgain[flowKey] == true then
        return false
    end
    return true
end

function onboarding.MarkCompleted(db, flowKey)
    local state = state_table(db)
    state.completed[flowKey] = true
    state.lastShownVersion = state.lastShownVersion or "v1"
end

function onboarding.MarkDoNotShowAgain(db, flowKey)
    local state = state_table(db)
    state.doNotShowAgain[flowKey] = true
end

ns.modules.onboarding = onboarding

return onboarding
```

```toc
# GBankManager/GBankManager.toc
UI/Onboarding.lua
UI/MainFrame.lua
```

- [ ] **Step 4: Run the onboarding state spec to verify it passes**

Run: `.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua`

Expected: `PASS`

- [ ] **Step 5: Commit the persistence and flow-definition slice**

```bash
git add GBankManager/GBankManager.toc GBankManager/Data/Defaults.lua GBankManager/Data/Migrations.lua GBankManager/UI/Onboarding.lua tests/spec/onboarding_spec.lua
git commit -m "feat: add onboarding state and flow definitions"
```

### Task 2: Add onboarding-aware UI entry triggers

**Files:**
- Modify: `GBankManager/Core/SlashCommands.lua`
- Modify: `GBankManager/UI/MinimapButton.lua`
- Test: `tests/spec/slash_commands_spec.lua`
- Test: `tests/spec/ui_shell_spec.lua`

- [ ] **Step 1: Extend the slash command spec with onboarding trigger coverage**

```lua
-- tests/spec/slash_commands_spec.lua
local onboarding = env.ns.modules.onboarding
local originalShouldAutoOpen = onboarding.ShouldAutoOpen

local openedFlow
mainFrame.OpenOnboarding = function(self, flowKey, options)
    openedFlow = {
        flowKey = flowKey,
        reason = options and options.reason,
    }
end

onboarding.ShouldAutoOpen = function(_, flowKey)
    return flowKey == "manager"
end

auth.GetEffectiveAccessProfile = function()
    return "full_shell"
end

openedFlow = nil
slash.command("")
assert.equal("manager", openedFlow and openedFlow.flowKey, "/gbm should auto-open manager onboarding for a first-run full-shell user")
assert.equal("slash_default", openedFlow and openedFlow.reason, "/gbm should report the default slash-open reason")

onboarding.ShouldAutoOpen = function(_, flowKey)
    return flowKey == "requestOnly"
end

auth.GetEffectiveAccessProfile = function()
    return "request_only"
end

openedFlow = nil
slash.command("ui")
assert.equal("requestOnly", openedFlow and openedFlow.flowKey, "/gbm ui should auto-open request onboarding for a first-run request-only user")
assert.equal("slash_ui", openedFlow and openedFlow.reason, "/gbm ui should report the explicit ui-open reason")

onboarding.ShouldAutoOpen = originalShouldAutoOpen
```

```lua
-- tests/spec/ui_shell_spec.lua
local env = fixture.load()
local minimapButton = env.ns.modules.minimapButton
local onboarding = env.ns.modules.onboarding
local auth = env.ns.modules.auth or env.ns.modules.permissions
local mainFrame = env.mainFrame

local originalShouldAutoOpen = onboarding.ShouldAutoOpen
local originalGetEffectiveAccessProfile = auth.GetEffectiveAccessProfile

local openedFlow
mainFrame.OpenOnboarding = function(self, flowKey, options)
    openedFlow = {
        flowKey = flowKey,
        reason = options and options.reason,
    }
end

onboarding.ShouldAutoOpen = function(_, flowKey)
    return flowKey == "manager"
end
auth.GetEffectiveAccessProfile = function()
    return "full_shell"
end

openedFlow = nil
minimapButton.button:GetScript("OnClick")(minimapButton.button)
assert.equal("manager", openedFlow and openedFlow.flowKey, "minimap open should auto-open manager onboarding for eligible first-run full-shell users")
assert.equal("minimap", openedFlow and openedFlow.reason, "minimap open should report the minimap reason")

onboarding.ShouldAutoOpen = originalShouldAutoOpen
auth.GetEffectiveAccessProfile = originalGetEffectiveAccessProfile
```

- [ ] **Step 2: Run the trigger specs to verify they fail**

Run:

- `.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua`

Expected: `FAIL` because the slash and minimap paths do not invoke onboarding yet.

- [ ] **Step 3: Add one shared onboarding-aware entry helper and route slash/minimap opens through it**

```lua
-- GBankManager/Core/SlashCommands.lua
local function maybe_open_onboarding(mainFrame, accessProfile, reason)
    local onboarding = ns.modules.onboarding
    local store = ns.modules.store or ns.data.store
    local db = store and type(store.GetDatabase) == "function" and store.GetDatabase() or (ns.state.db or {})
    local flowKey = onboarding and type(onboarding.GetFlowForAccessProfile) == "function" and onboarding.GetFlowForAccessProfile(accessProfile) or nil

    if type(mainFrame.OpenOnboarding) ~= "function" then
        return false
    end
    if flowKey == nil then
        return false
    end
    if onboarding and type(onboarding.ShouldAutoOpen) == "function" and onboarding.ShouldAutoOpen(db, flowKey) then
        mainFrame:OpenOnboarding(flowKey, {
            auto = true,
            reason = reason,
        })
        return true
    end
    return false
end

local function open_access_ui(mainFrame, accessProfile, requestOnlyOpensWizard, reason)
    if not mainFrame then
        return
    end

    -- existing blocked/full-shell/request-only behavior stays here

    if maybe_open_onboarding(mainFrame, accessProfile, reason) then
        return
    end

    if accessProfile == "full_shell" and type(mainFrame.ShowDashboard) == "function" then
        mainFrame:ShowDashboard()
        return
    end

    if type(mainFrame.ShowRequestOnly) == "function" then
        mainFrame:ShowRequestOnly()
        if requestOnlyOpensWizard then
            open_request_wizard(mainFrame)
        end
    end
end
```

```lua
-- GBankManager/Core/SlashCommands.lua command routing
elseif command == "ui" and mainFrame then
    open_access_ui(mainFrame, accessProfile, false, "slash_ui")
elseif command == "" and mainFrame then
    open_access_ui(mainFrame, accessProfile, accessProfile ~= "full_shell", "slash_default")
```

```lua
-- GBankManager/UI/MinimapButton.lua OnClick
button:SetScript("OnClick", function()
    local mainFrame = ns.modules.mainFrame
    if type(mainFrame) == "table" and type(mainFrame.IsShown) == "function" and mainFrame:IsShown() then
        if type(mainFrame.Hide) == "function" then
            mainFrame:Hide()
            return
        end
    end

    local slash = ns.modules.slash
    if slash and type(slash.command) == "function" then
        slash.command("")
    end
end)
```

- [ ] **Step 4: Run the trigger specs to verify they pass**

Run:

- `.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua`

Expected: both `PASS`

- [ ] **Step 5: Commit the trigger integration slice**

```bash
git add GBankManager/Core/SlashCommands.lua GBankManager/UI/MinimapButton.lua tests/spec/slash_commands_spec.lua tests/spec/ui_shell_spec.lua
git commit -m "feat: trigger onboarding from slash and minimap opens"
```

### Task 3: Build the onboarding modal and request-only-safe step actions

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `GBankManager/UI/Onboarding.lua`
- Test: `tests/spec/ui_requests_spec.lua`
- Test: `tests/spec/onboarding_spec.lua`

- [ ] **Step 1: Add failing UI specs for request-only-safe onboarding behavior**

```lua
-- tests/spec/ui_requests_spec.lua
local onboarding = env.ns.modules.onboarding
local mainFrame = env.mainFrame

mainFrame:ShowRequestOnly()
mainFrame:OpenOnboarding("requestOnly", { auto = true, reason = "test" })

assert.truthy(mainFrame.onboardingModal:IsShown(), "request-only onboarding should render through the onboarding modal")
assert.equal("requestOnly", mainFrame.onboardingFlowKey, "request-only onboarding should track the active flow")
assert.equal("REQUESTS", mainFrame.activeView, "request-only onboarding should remain on the compact request surface")

mainFrame:AdvanceOnboardingStep()
assert.equal("request_flow", mainFrame.onboardingCurrentStep.id, "request-only onboarding should advance to the request flow step")

mainFrame:RunOnboardingPrimaryAction()
assert.truthy(mainFrame.requestWizardModal and mainFrame.requestWizardModal:IsShown(), "request-only onboarding should open the request wizard from the request flow step")
```

```lua
-- tests/spec/onboarding_spec.lua
mainFrame:OpenOnboarding("manager", { auto = true, reason = "test" })
assert.truthy(mainFrame.onboardingModal:IsShown(), "manager onboarding should show the onboarding modal")
assert.equal("manager", mainFrame.onboardingFlowKey, "manager onboarding should track the active flow")

mainFrame:AdvanceOnboardingStep()
assert.equal("permissions", mainFrame.onboardingCurrentStep.id, "manager onboarding should advance to the permissions step")

mainFrame:RunOnboardingPrimaryAction()
assert.equal("OPTIONS", mainFrame.activeView, "manager onboarding permissions action should open Options")
assert.equal("PERMISSIONS", mainFrame.optionsActiveTab, "manager onboarding permissions action should focus the Permissions tab")
```

- [ ] **Step 2: Run the onboarding UI specs to verify they fail**

Run:

- `.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`

Expected: `FAIL` because `OpenOnboarding`, step state, and primary-action handlers do not exist yet.

- [ ] **Step 3: Add modal rendering and step navigation in MainFrame**

```lua
-- GBankManager/UI/MainFrame.lua
function mainFrame:EnsureOnboardingModal()
    if self.onboardingModal then
        return self.onboardingModal
    end

    local modal = _G.CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    modal:SetSize(520, 340)
    modal:SetPoint("CENTER", self.content, "CENTER", 0, 0)
    apply_surface_variant(modal, "modal-sheet")
    modal:Hide()

    modal.titleText = make_label(modal, "", "GameFontHighlightLarge")
    modal.titleText:SetPoint("TOPLEFT", modal, "TOPLEFT", 24, -24)
    modal.bodyText = make_label(modal, "", "GameFontHighlight")
    modal.bodyText:SetPoint("TOPLEFT", modal.titleText, "BOTTOMLEFT", 0, -12)
    modal.bodyText:SetWidth(472)
    if type(modal.bodyText.SetWordWrap) == "function" then
        modal.bodyText:SetWordWrap(true)
    end

    modal.stepText = make_label(modal, "", "GameFontHighlightSmall")
    modal.stepText:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 24, 18)

    modal.primaryActionButton = make_button(modal, 150, 24, "")
    modal.primaryActionButton:SetPoint("BOTTOMLEFT", modal.stepText, "TOPLEFT", 0, 12)
    modal.primaryActionButton:Hide()

    modal.backButton = make_button(modal, 80, 24, "Back")
    modal.backButton:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -270, 14)
    modal.nextButton = make_button(modal, 80, 24, "Next")
    modal.nextButton:SetPoint("LEFT", modal.backButton, "RIGHT", 8, 0)
    modal.skipButton = make_button(modal, 80, 24, "Skip")
    modal.skipButton:SetPoint("LEFT", modal.nextButton, "RIGHT", 8, 0)
    modal.doNotShowAgainButton = make_button(modal, 120, 24, "Do Not Show Again")
    modal.doNotShowAgainButton:SetPoint("LEFT", modal.skipButton, "RIGHT", 8, 0)

    self.onboardingModal = modal
    return modal
end

function mainFrame:RenderOnboardingStep()
    local modal = self:EnsureOnboardingModal()
    local step = self.onboardingCurrentStep
    local steps = self.onboardingSteps or {}
    local index = self.onboardingStepIndex or 1

    modal.titleText:SetText(step.title or "")
    modal.bodyText:SetText(step.description or "")
    modal.stepText:SetText(string.format("%d of %d", index, #steps))
    modal.backButton:SetShown(index > 1)
    modal.nextButton.labelText:SetText(index >= #steps and "Done" or "Next")

    if step.primaryActionLabel then
        modal.primaryActionButton.labelText:SetText(step.primaryActionLabel)
        modal.primaryActionButton:Show()
    else
        modal.primaryActionButton:Hide()
    end

    modal:Show()
end

function mainFrame:OpenOnboarding(flowKey, options)
    local onboarding = ns.modules.onboarding
    self.onboardingFlowKey = flowKey
    self.onboardingSteps = onboarding.GetSteps(flowKey)
    self.onboardingStepIndex = 1
    self.onboardingCurrentStep = self.onboardingSteps[1]
    self.onboardingAutoOpen = type(options) == "table" and options.auto == true
    self:RenderOnboardingStep()
end

function mainFrame:AdvanceOnboardingStep()
    local steps = self.onboardingSteps or {}
    if self.onboardingStepIndex >= #steps then
        local db = current_db()
        local onboarding = ns.modules.onboarding
        onboarding.MarkCompleted(db, self.onboardingFlowKey)
        self:CloseOnboarding()
        return
    end
    self.onboardingStepIndex = self.onboardingStepIndex + 1
    self.onboardingCurrentStep = steps[self.onboardingStepIndex]
    self:RenderOnboardingStep()
end

function mainFrame:CloseOnboarding()
    if self.onboardingModal then
        self.onboardingModal:Hide()
    end
    self.onboardingFlowKey = nil
    self.onboardingSteps = nil
    self.onboardingStepIndex = nil
    self.onboardingCurrentStep = nil
end
```

```lua
-- GBankManager/UI/MainFrame.lua step actions
function mainFrame:RunOnboardingPrimaryAction()
    local step = self.onboardingCurrentStep or {}
    if step.targetView == "OPTIONS" then
        self:ShowDashboard()
        self:SelectView("OPTIONS")
        if step.optionsTab then
            self:SetOptionsTab(step.optionsTab)
        end
        return
    end
    if step.targetView == "REQUESTS" and self.onboardingFlowKey == "requestOnly" then
        self:ShowRequestOnly()
        if step.primaryAction == "open_request_wizard" and type(self.OpenRequestWizard) == "function" then
            self:OpenRequestWizard()
        end
        return
    end
    if step.targetView == "REQUESTS" then
        self:ShowDashboard()
        self:SelectView("REQUESTS")
        return
    end
    if step.targetView == "DASHBOARD" then
        self:ShowDashboard()
    end
end
```

```lua
-- GBankManager/UI/MainFrame.lua button wiring
mainFrame:EnsureOnboardingModal()
mainFrame.onboardingModal.backButton:SetScript("OnClick", function()
    mainFrame.onboardingStepIndex = math.max(1, (mainFrame.onboardingStepIndex or 1) - 1)
    mainFrame.onboardingCurrentStep = (mainFrame.onboardingSteps or {})[mainFrame.onboardingStepIndex]
    mainFrame:RenderOnboardingStep()
end)
mainFrame.onboardingModal.nextButton:SetScript("OnClick", function()
    mainFrame:AdvanceOnboardingStep()
end)
mainFrame.onboardingModal.skipButton:SetScript("OnClick", function()
    mainFrame:CloseOnboarding()
end)
mainFrame.onboardingModal.doNotShowAgainButton:SetScript("OnClick", function()
    local onboarding = ns.modules.onboarding
    onboarding.MarkDoNotShowAgain(current_db(), mainFrame.onboardingFlowKey)
    mainFrame:CloseOnboarding()
end)
mainFrame.onboardingModal.primaryActionButton:SetScript("OnClick", function()
    mainFrame:RunOnboardingPrimaryAction()
end)
```

- [ ] **Step 4: Run the onboarding UI specs to verify they pass**

Run:

- `.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`

Expected: both `PASS`

- [ ] **Step 5: Commit the onboarding modal slice**

```bash
git add GBankManager/UI/MainFrame.lua GBankManager/UI/Onboarding.lua tests/spec/onboarding_spec.lua tests/spec/ui_requests_spec.lua
git commit -m "feat: add onboarding modal and step actions"
```

### Task 4: Add replay from Options and final verification updates

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_options_spec.lua`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`

- [ ] **Step 1: Add the failing Options replay spec**

```lua
-- tests/spec/ui_options_spec.lua
local env = fixture.load()
local mainFrame = env.mainFrame

mainFrame:ShowDashboard()
mainFrame:SelectView("OPTIONS")
mainFrame:SetOptionsTab("APPEARANCE")

assert.truthy(type(mainFrame.optionsReplayOnboardingButton) == "table", "options should expose a replay onboarding button for full-shell users")
assert.equal("Replay Onboarding", mainFrame.optionsReplayOnboardingButton.labelText:GetText(), "options replay button should use the expected label")

mainFrame.optionsReplayOnboardingButton:GetScript("OnClick")(mainFrame.optionsReplayOnboardingButton)
assert.truthy(mainFrame.onboardingModal and mainFrame.onboardingModal:IsShown(), "options replay should reopen onboarding on demand")
assert.equal("manager", mainFrame.onboardingFlowKey, "options replay should reopen the manager flow for full-shell users")
```

- [ ] **Step 2: Run the Options replay spec to verify it fails**

Run: `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`

Expected: `FAIL` because the replay control does not exist yet.

- [ ] **Step 3: Add the Options replay control and finish docs**

```lua
-- GBankManager/UI/MainFrame.lua inside the Appearance or help area of Options
mainFrame.optionsReplayOnboardingButton = mainFrame.optionsReplayOnboardingButton or make_button(mainFrame.optionsAppearancePanel, 156, 24, "Replay Onboarding")
mainFrame.optionsReplayOnboardingButton:SetPoint("TOPLEFT", mainFrame.optionsMinimapToggle, "BOTTOMLEFT", 0, -18)
mainFrame.optionsReplayOnboardingButton:SetScript("OnClick", function()
    mainFrame:OpenOnboarding("manager", {
        auto = false,
        reason = "options_replay",
    })
end)
```

```markdown
<!-- docs/manual-test-checklist.md -->
11b. On a fresh character or reset SavedVariables state, open the addon from `/gbm` and confirm first-run onboarding appears for the current access profile.
11c. Repeat the same first-run check from the minimap button and confirm it uses the same onboarding flow.
11d. In onboarding, click `Skip` and confirm the modal closes without blocking normal UI use.
11e. Reopen first-run onboarding, click `Do not show again`, close and reopen the addon, and confirm the walkthrough no longer auto-opens.
11f. Open `Options` as a full-shell user, click `Replay Onboarding`, and confirm the manager walkthrough reopens on demand.
```

```markdown
<!-- docs/superpowers/handoffs/latest-handoff.md -->
- First-run onboarding now auto-opens from `/gbm` and the minimap button for eligible full-shell and request-only users, supports `Skip` plus `Do not show again`, and can be replayed from `Options` for full-shell users.
- Request-only replay parity is intentionally deferred; v1 replays only through `Options`.
```

- [ ] **Step 4: Run focused specs and full verification**

Run:

- `.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua`
- `.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua`
- `.\tools\lua\lua.exe .\tests\run_all.lua`

Expected:

- all focused specs `PASS`
- full suite `PASS`

- [ ] **Step 5: Commit the replay/docs/final verification slice**

```bash
git add GBankManager/UI/MainFrame.lua tests/spec/ui_options_spec.lua docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
git commit -m "feat: add onboarding replay and docs"
```

## Spec Coverage Check

- First-run trigger from `/gbm`: covered in Task 2.
- First-run trigger from minimap: covered in Task 2.
- Manager walkthrough: covered in Tasks 1 and 3.
- Request-only walkthrough: covered in Tasks 1 and 3.
- `Skip`: covered in Task 3 test flow and final verification.
- `Do not show again`: covered in Task 1 state spec and Task 4 manual checks.
- Replay from `Options`: covered in Task 4.
- Request-only replay not in v1: explicitly documented in Task 4 docs update and preserved from the approved spec.

## Notes for the Implementer

- Keep the manager and request-only flow copy in `UI/Onboarding.lua`; do not scatter strings across `MainFrame.lua`.
- Preserve current request-only behavior. The onboarding overlay must not promote request-only users into inaccessible views.
- Prefer adding one focused replay control in `Options` rather than inventing a second help system.
- If modal layout pressure appears in `MainFrame.lua`, split only the onboarding rendering helpers into a local helper section; do not refactor unrelated parts of the shell during this task.
