# GBankManager Onboarding And Sync UX Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the onboarding modal, `Options -> Sync`, and adjacent `Appearance` and `Data` layouts so players get clearer guild-policy guidance, better peer sync visibility, and throttled manual sync actions through both the UI and slash commands.

**Architecture:** Add a small sync-action coordinator module that owns manual sync permissions, action routing, and cooldowns, then layer peer-state schema updates and UI changes on top of it. Keep onboarding content definition in `UI/Onboarding.lua`, keep persisted peer data guild-scoped in `Sync/PeerState.lua`, and reuse the existing shared table and button patterns instead of creating one-off UI primitives.

**Tech Stack:** WoW Lua addon modules, existing shared UI controls in `GBankManager/UI/MainFrame.lua`, persisted SavedVariables state, AceComm-based sync transport, Lua specs in `tests/spec`, and repo docs in `README.md` plus `docs/manual-test-checklist.md`.

---

## File Structure

### Existing files to modify

- `GBankManager/UI/Onboarding.lua`
  - update manager/request-only copy for permissions, blacklist, and request sync messaging
- `GBankManager/UI/MainFrame.lua`
  - make onboarding modal draggable and recenter-on-open
  - clean up onboarding footer buttons
  - extend `Appearance` chrome around `Replay Onboarding`
  - move and annotate `Repair Threshold`
  - replace the current Sync text block with a reusable scrollable table plus action buttons
- `GBankManager/Core/SlashCommands.lua`
  - add `/gbm sync`, `/gbm sync requests`, `/gbm sync minimums`, `/gbm sync ledger`, and `/gbm sync all`
- `GBankManager/Sync/PeerState.lua`
  - extend peer entries to track synchronized timestamps separately from last-seen timestamps
- `GBankManager/Sync/SyncEvents.lua`
  - update peer-state writes when accepted sync traffic occurs
- `README.md`
- `docs/manual-test-checklist.md`
- `docs/superpowers/handoffs/latest-handoff.md`

### New files to create

- `GBankManager/Sync/ManualActions.lua`
  - single source of truth for manual sync action permissions, cooldowns, dispatch, and player-facing messages
- `tests/spec/sync_manual_actions_spec.lua`
  - focused red-green coverage for cooldowns, role gating, bare `/gbm sync` defaults, and per-action routing

### Existing test files to modify

- `tests/spec/onboarding_spec.lua`
- `tests/spec/ui_options_spec.lua`
- `tests/spec/ui_requests_spec.lua`
- `tests/spec/ui_shell_spec.lua`
- `tests/spec/slash_commands_spec.lua`
- `tests/spec/sync_peer_state_spec.lua`
- `tests/spec/sync_spec.lua`

## Task 1: Extend Peer State For Seen Vs Synchronized Timestamps

**Files:**
- Modify: `GBankManager/Sync/PeerState.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Test: `tests/spec/sync_peer_state_spec.lua`
- Test: `tests/spec/sync_spec.lua`

- [ ] **Step 1: Write the failing peer-state test**

Add assertions to `tests/spec/sync_peer_state_spec.lua` that prove a peer can store both a last-seen timestamp and a separate last-synchronized timestamp:

```lua
peerState.TouchPeer(db, {
    guildKey = "Guild Testers",
    characterKey = "Stormrage-OfficerOne",
    messageType = "SYNC_HELLO",
    seenAt = 1717000000,
})

peerState.MarkSynchronized(db, {
    guildKey = "Guild Testers",
    characterKey = "Stormrage-OfficerOne",
    synchronizedAt = 1717000300,
})

local entry = (((db.syncState or {}).peers or {})["Guild Testers"] or {})["Stormrage-OfficerOne"] or {}
assert.equal(1717000000, tonumber(entry.lastSeen or 0), "peer state should keep last seen separate from sync success timestamps")
assert.equal(1717000300, tonumber(entry.lastSynchronizedAt or 0), "peer state should persist the last successful sync timestamp")
```

- [ ] **Step 2: Run the targeted peer-state test and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_peer_state_spec.lua
```

Expected: FAIL because `MarkSynchronized` does not exist yet or the sync timestamp is not persisted.

- [ ] **Step 3: Implement minimal peer-state support**

Add a narrow helper in `GBankManager/Sync/PeerState.lua`:

```lua
function peerState.MarkSynchronized(db, details)
    local entry = peerState.TouchPeer(db, details)
    if type(entry) ~= "table" then
        return nil
    end

    local synchronizedAt = tonumber(details.synchronizedAt or 0) or 0
    entry.lastSynchronizedAt = math.max(tonumber(entry.lastSynchronizedAt or 0) or 0, synchronizedAt)
    return entry
end
```

Keep `TouchPeer` focused on presence/traffic updates only.

- [ ] **Step 4: Run the targeted peer-state test and verify GREEN**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_peer_state_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Write the failing sync-events test for accepted sync traffic**

Add a focused spec case in `tests/spec/sync_spec.lua` showing that accepted sync traffic updates `lastSynchronizedAt`, while hello-only traffic does not:

```lua
assert.equal(0, tonumber((peerEntry.lastSynchronizedAt or 0)), "hello traffic alone should not mark a peer as synchronized")
assert.truthy(tonumber(updatedPeerEntry.lastSynchronizedAt or 0) >= 1717000500, "accepted sync payloads should mark the peer as synchronized")
```

- [ ] **Step 6: Run the targeted sync spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected: FAIL because accepted sync paths are not yet marking synchronization timestamps.

- [ ] **Step 7: Implement minimal accepted-sync writes in `SyncEvents`**

In the accepted sync handlers in `GBankManager/Sync/SyncEvents.lua`, call the new helper only on real accepted sync families:

```lua
if type(peerState.MarkSynchronized) == "function" then
    peerState.MarkSynchronized(db, {
        guildKey = active_guild_key(db),
        characterKey = characterKey,
        synchronizedAt = tonumber(message.updatedAt or (_G.time and _G.time() or 0)) or 0,
        messageType = tostring(message.type or ""),
    })
end
```

Do not call it from hello-only presence updates.

- [ ] **Step 8: Re-run the targeted sync specs**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_peer_state_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected: PASS on both specs.

- [ ] **Step 9: Commit the peer-state slice**

```powershell
git add GBankManager/Sync/PeerState.lua GBankManager/Sync/SyncEvents.lua tests/spec/sync_peer_state_spec.lua tests/spec/sync_spec.lua
git commit -m "feat: track peer sync timestamps separately"
```

## Task 2: Add A Manual Sync Action Coordinator

**Files:**
- Create: `GBankManager/Sync/ManualActions.lua`
- Modify: `GBankManager/GBankManager.toc`
- Test: `tests/spec/sync_manual_actions_spec.lua`

- [ ] **Step 1: Write the failing coordinator spec for role gating and cooldowns**

Create `tests/spec/sync_manual_actions_spec.lua` with focused expectations like:

```lua
local result = manualActions.Run(db, {
    action = "requests",
    accessProfile = "request_only",
    now = 1717000000,
})

assert.equal(true, result.ok, "request-only users should be allowed to trigger request sync")

local denied = manualActions.Run(db, {
    action = "ledger",
    accessProfile = "request_only",
    now = 1717000000,
})

assert.equal(false, denied.ok, "request-only users should not be allowed to trigger ledger sync")
assert.truthy(string.find(denied.message or "", "requires broader guild-management access", 1, true) ~= nil, "denied sync actions should explain why they are disabled")
```

Add cooldown expectations too:

```lua
local first = manualActions.Run(db, { action = "requests", accessProfile = "full_shell", now = 1717000000 })
local second = manualActions.Run(db, { action = "requests", accessProfile = "full_shell", now = 1717000020 })

assert.equal(true, first.ok, "first request sync should be allowed")
assert.equal(false, second.ok, "request sync should be throttled for 60 seconds")
```

- [ ] **Step 2: Run the new coordinator spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: FAIL because the module and runner do not exist yet.

- [ ] **Step 3: Add the new module to the TOC and implement the minimal coordinator**

Register a new file in `GBankManager/GBankManager.toc` near other sync modules, then create `GBankManager/Sync/ManualActions.lua` with a narrow API:

```lua
function manualActions.ResolveDefaultAction(accessProfile)
    if accessProfile == "request_only" then
        return "requests"
    end
    return "all"
end

function manualActions.Run(db, options)
    local action = normalize_action(options.action)
    local accessProfile = tostring(options.accessProfile or "full_shell")
    local now = tonumber(options.now or (_G.time and _G.time() or 0)) or 0
    -- permission checks
    -- cooldown checks
    -- dispatch to sync transport/coordinator hooks
    return {
        ok = true,
        action = action,
        message = "Triggered sync.",
    }
end
```

Use a per-character `db.ui.syncCooldowns` or similarly scoped store keyed by action.

- [ ] **Step 4: Re-run the new coordinator spec and verify GREEN**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Add coordinator coverage for `all`**

Extend the spec with `Sync All` coverage:

```lua
assert.equal("all", manualActions.ResolveDefaultAction("full_shell"), "full-shell bare sync should default to all")
assert.equal("requests", manualActions.ResolveDefaultAction("request_only"), "request-only bare sync should default to requests")
```

Add child-action cooldown expectations so `all` honors family-specific cooldowns.

- [ ] **Step 6: Run the coordinator spec again**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: PASS.

- [ ] **Step 7: Commit the coordinator slice**

```powershell
git add GBankManager/GBankManager.toc GBankManager/Sync/ManualActions.lua tests/spec/sync_manual_actions_spec.lua
git commit -m "feat: add manual sync action coordinator"
```

## Task 3: Wire Manual Sync Actions Into Slash Commands

**Files:**
- Modify: `GBankManager/Core/SlashCommands.lua`
- Modify: `tests/spec/slash_commands_spec.lua`
- Test: `tests/spec/sync_manual_actions_spec.lua`

- [ ] **Step 1: Write the failing slash-command spec**

Extend `tests/spec/slash_commands_spec.lua` to capture sync routing:

```lua
local captured = {}
env.ns.modules.syncManualActions = {
    Run = function(_, options)
        captured[#captured + 1] = options
        return { ok = true, message = "Triggered sync." }
    end,
}

slash.Handle("sync")
slash.Handle("sync requests")
slash.Handle("sync ledger")

assert.equal("all", captured[1].action, "bare /gbm sync should default to all for full-shell users")
assert.equal("requests", captured[2].action, "explicit /gbm sync requests should route to the request sync action")
assert.equal("ledger", captured[3].action, "explicit /gbm sync ledger should route to the ledger sync action")
```

- [ ] **Step 2: Run the slash-command spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
```

Expected: FAIL because `sync` is not routed yet.

- [ ] **Step 3: Add the slash routing**

In `GBankManager/Core/SlashCommands.lua`, add a branch for `sync`:

```lua
if command == "sync" then
    local action = subcommand ~= "" and subcommand or manualActions.ResolveDefaultAction(accessProfile)
    local result = manualActions.Run(current_db(), {
        action = action,
        accessProfile = accessProfile,
    })
    push_chat_line(result.message)
    return
end
```

Keep all player-facing copy free of debug/test commands.

- [ ] **Step 4: Re-run the slash-command spec and verify GREEN**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Run the manual-action spec again**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
```

Expected: PASS, confirming slash routing did not drift from the coordinator contract.

- [ ] **Step 6: Commit the slash slice**

```powershell
git add GBankManager/Core/SlashCommands.lua tests/spec/slash_commands_spec.lua
git commit -m "feat: add manual sync slash commands"
```

## Task 4: Redesign `Options -> Sync` Around A Scrollable Table And Action Buttons

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_options_spec.lua`
- Modify: `tests/spec/ui_requests_spec.lua`

- [ ] **Step 1: Write the failing options spec for the sync table**

Replace the current peer-text expectations in `tests/spec/ui_options_spec.lua` with table expectations:

```lua
assert.truthy(type(mainFrame.optionsSyncTable) == "table", "options Sync should expose a reusable scrollable table")
assert.equal("Character", ((mainFrame.optionsSyncColumnHeaders or {})[1] or {}).text, "options Sync should show a Character column")
assert.equal("Last Time Seen", ((mainFrame.optionsSyncColumnHeaders or {})[2] or {}).text, "options Sync should show a Last Time Seen column")
assert.equal("Last Time Synchronized", ((mainFrame.optionsSyncColumnHeaders or {})[3] or {}).text, "options Sync should show a Last Time Synchronized column")
```

Add peer-row expectations:

```lua
assert.truthy(string.find(firstRow.character or "", "OfficerOne%-Stormrage", 1, false) ~= nil, "sync rows should render Name-Realm values")
```

- [ ] **Step 2: Run the options spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: FAIL because the Sync tab still renders a text block.

- [ ] **Step 3: Implement the minimal sync table model and rendering**

In `GBankManager/UI/MainFrame.lua`, replace the text summary with a narrow table adapter:

```lua
local function build_sync_rows(db)
    local rows = {}
    for _, entry in ipairs(syncPeerState.GetPeers(db, current_sync_guild_key(db)) or {}) do
        rows[#rows + 1] = {
            character = tostring(entry.characterKey or ""),
            lastSeen = format_timestamp(entry.lastSeen),
            lastSynchronized = format_timestamp(entry.lastSynchronizedAt),
        }
    end
    return rows
end
```

Bind that into the existing shared-table style instead of raw labels.

- [ ] **Step 4: Re-run the options spec and verify GREEN for the table surface**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: PASS on the sync-table rendering assertions.

- [ ] **Step 5: Write the failing options/request-only spec for action buttons**

Add role-aware assertions:

```lua
assert.equal("Sync Requests", mainFrame.optionsSyncRequestsButton.labelText:GetText(), "sync tab should expose a request sync action")
assert.truthy(mainFrame.optionsSyncLedgerButton:IsEnabled() ~= true, "request-only users should see ledger sync disabled")
```

Use `tests/spec/ui_requests_spec.lua` for request-only behavior and `tests/spec/ui_options_spec.lua` for full-shell behavior.

- [ ] **Step 6: Run the UI specs and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected: FAIL because the buttons and role gating are not wired yet.

- [ ] **Step 7: Add the action buttons and role-aware enabled state**

In `GBankManager/UI/MainFrame.lua`, create buttons for:

```lua
mainFrame.optionsSyncRequestsButton
mainFrame.optionsSyncMinimumsButton
mainFrame.optionsSyncLedgerButton
mainFrame.optionsSyncAllButton
```

Hook them through the shared coordinator:

```lua
local result = manualActions.Run(current_db(), {
    action = "requests",
    accessProfile = current_access_profile(),
})
self:SetOptionsSyncStatus(result.message)
```

For request-only users, disable the broader buttons and show helper text such as:

```lua
"Minimums and ledger sync require broader guild-management access."
```

- [ ] **Step 8: Re-run the role-aware Sync UI specs**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected: PASS.

- [ ] **Step 9: Commit the Sync tab UI slice**

```powershell
git add GBankManager/UI/MainFrame.lua tests/spec/ui_options_spec.lua tests/spec/ui_requests_spec.lua
git commit -m "feat: redesign sync options tab"
```

## Task 5: Refresh Onboarding Copy, Drag Behavior, And Footer Layout

**Files:**
- Modify: `GBankManager/UI/Onboarding.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/onboarding_spec.lua`
- Modify: `tests/spec/ui_shell_spec.lua`

- [ ] **Step 1: Write the failing onboarding content spec**

Update `tests/spec/onboarding_spec.lua` so the manager flow explicitly expects the new copy themes:

```lua
assert.truthy(string.find(managerSteps[2].description or "", "Guild Info", 1, true) ~= nil, "permissions onboarding should name Guild Info as the policy source")
assert.truthy(string.find(managerSteps[3].description or "", "read-only", 1, true) ~= nil, "blacklist onboarding should explain why parsed blacklist results are read-only")
assert.truthy(string.find(managerSteps[4].description or "", "online addon users", 1, true) ~= nil, "request onboarding should explain request synchronization between online addon users")
```

- [ ] **Step 2: Run the onboarding spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua
```

Expected: FAIL because the old copy is still present.

- [ ] **Step 3: Implement the content refresh in `UI/Onboarding.lua`**

Update the step descriptions directly in `GBankManager/UI/Onboarding.lua`, for example:

```lua
description = "Guild Info is the source of truth for permissions. The addon reads that guild policy to decide who can manage requests, minimums, and broader guild actions. Use Refresh Guild Policy after guild-maintained changes."
```

And:

```lua
description = "Blacklist blocks request-system usage for tagged players. This panel is read-only because it reflects guild-backed policy parsing rather than a local editable list."
```

- [ ] **Step 4: Re-run the onboarding spec and verify GREEN for content**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua
```

Expected: PASS on the new copy assertions.

- [ ] **Step 5: Write the failing drag/recenter/footer spec**

Add modal shell expectations to `tests/spec/onboarding_spec.lua` and `tests/spec/ui_shell_spec.lua`:

```lua
assert.equal(true, mainFrame.onboardingModal.isMovable, "onboarding modal should be movable while open")
assert.same(mainFrame.content, (mainFrame.onboardingModal.points[1] or {})[2], "onboarding modal should reopen centered against the shell content frame")
assert.truthy(mainFrame.onboardingModal.doNotShowAgainButton:GetWidth() >= 164, "do-not-show-again should remain a wide readable footer action")
```

- [ ] **Step 6: Run the onboarding and shell specs and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
```

Expected: FAIL because the modal is not draggable yet and the layout contract has not been updated.

- [ ] **Step 7: Implement the modal drag and footer refresh**

In `GBankManager/UI/MainFrame.lua`:

```lua
modal:SetMovable(true)
modal:RegisterForDrag("LeftButton")
modal:SetScript("OnDragStart", function(frame)
    if type(frame.StartMoving) == "function" then
        frame:StartMoving()
    end
end)
modal:SetScript("OnDragStop", function(frame)
    if type(frame.StopMovingOrSizing) == "function" then
        frame:StopMovingOrSizing()
    end
end)
```

And in `OpenOnboarding`, always recenter before showing:

```lua
modal:ClearAllPoints()
modal:SetPoint("CENTER", self.content, "CENTER", 0, 0)
```

Also adjust footer anchors and widths so `Skip` and `Do Not Show Again` no longer overlap or look cramped.

- [ ] **Step 8: Re-run the onboarding and shell specs**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
```

Expected: PASS.

- [ ] **Step 9: Commit the onboarding slice**

```powershell
git add GBankManager/UI/Onboarding.lua GBankManager/UI/MainFrame.lua tests/spec/onboarding_spec.lua tests/spec/ui_shell_spec.lua
git commit -m "feat: refresh onboarding modal and copy"
```

## Task 6: Finish `Appearance` And `Data` Panel Layout Polish

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_options_spec.lua`

- [ ] **Step 1: Write the failing options-layout spec**

Extend `tests/spec/ui_options_spec.lua` with layout contract checks:

```lua
assert.truthy((mainFrame.optionsReplayOnboardingButton:GetBottom() or 0) >= (mainFrame.optionsAppearancePanel:GetBottom() or 0), "appearance chrome should extend behind the replay onboarding button")
assert.same(mainFrame.optionsLogsHistoryPanel, (mainFrame.optionsRepairThresholdTitle.points[1] or {})[2], "repair threshold should anchor from the data panel left-side control area")
assert.truthy(string.find(mainFrame.optionsRepairThresholdHint:GetText() or "", "equal to or under", 1, true) ~= nil, "repair threshold should explain repair-vs-withdrawal classification")
```

- [ ] **Step 2: Run the options spec and verify RED**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: FAIL because the panel chrome and `Repair Threshold` layout are still in the old positions.

- [ ] **Step 3: Implement the layout changes**

In `GBankManager/UI/MainFrame.lua`:

```lua
mainFrame.optionsRepairThresholdTitle:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -132)
mainFrame.optionsRepairThresholdInput:SetPoint("TOPLEFT", mainFrame.optionsLogsHistoryPanel, "TOPLEFT", 16, -160)
mainFrame.optionsRepairThresholdHint = mainFrame.optionsRepairThresholdHint or make_label(mainFrame.optionsLogsHistoryPanel, "Withdrawals equal to or under this amount count as repairs instead of normal withdrawals.", "GameFontHighlightSmall")
```

Move the `Save Settings` row lower, then move the `Clear Data` stack down from that new baseline. Increase the `Appearance` panel height or its contained section geometry so the replay section sits fully inside the chrome.

- [ ] **Step 4: Re-run the options spec and verify GREEN**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Commit the layout-polish slice**

```powershell
git add GBankManager/UI/MainFrame.lua tests/spec/ui_options_spec.lua
git commit -m "feat: polish onboarding and data option layouts"
```

## Task 7: Update Docs And Run Final Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`

- [ ] **Step 1: Update README behavior notes**

Add or revise bullets so they reflect:

```md
- First-run onboarding now uses a draggable modal that reopens centered and explains Guild Info permissions, blacklist read-only parsing, and request sync between online addon users.
- `Options -> Sync` now shows a scrollable peer table with `Character`, `Last Time Seen`, and `Last Time Synchronized`, plus manual sync actions.
- `/gbm sync`, `/gbm sync requests`, `/gbm sync minimums`, `/gbm sync ledger`, and `/gbm sync all` now share the same throttled manual sync backend.
```

- [ ] **Step 2: Update the manual checklist**

Add or revise manual steps in `docs/manual-test-checklist.md` for:

```md
- drag onboarding, change tabs under it, and confirm it reopens centered
- verify the permissions and blacklist copy updates
- confirm request-only users can trigger only `Sync Requests`
- confirm `Sync All` and each per-family button respect the 60-second cooldown
- confirm `Repair Threshold` helper text and spacing
```

- [ ] **Step 3: Update the latest handoff**

Revise `docs/superpowers/handoffs/latest-handoff.md` so the checkpoint summary mentions:

```md
- draggable role-aware onboarding refresh
- sync peer table with last-seen vs last-synchronized timestamps
- throttled `/gbm sync` support
- request-only Sync tab limitations
```

- [ ] **Step 4: Run focused verification lanes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_peer_state_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_manual_actions_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\slash_commands_spec.lua
.\tools\lua\lua.exe .\tests\spec\onboarding_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_shell_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected: PASS `tests/run_all.lua`.

- [ ] **Step 6: Commit docs and verification checkpoint**

```powershell
git add README.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
git commit -m "docs: document onboarding and sync ux refresh"
```

## Self-Review

### Spec Coverage

- Onboarding footer cleanup: covered in Task 5.
- Draggable modal and recenter-on-open: covered in Task 5.
- Permissions and blacklist copy refresh: covered in Task 5.
- Request sync wording for online addon users: covered in Task 5.
- `Appearance` replay chrome and `Data` panel spacing: covered in Task 6.
- Scrollable Sync table with `Character`, `Last Time Seen`, `Last Time Synchronized`: covered in Tasks 1 and 4.
- `Name-Realm` character formatting: covered in Task 4.
- Separate sync buttons and role-aware enablement: covered in Tasks 2, 3, and 4.
- `/gbm sync` and subcommands: covered in Task 3.
- 60-second throttling and `Sync All`: covered in Task 2.
- Docs updates: covered in Task 7.

### Placeholder Scan

No `TODO`, `TBD`, or “implement later” placeholders were left in the task steps. Each code-touching step includes specific file paths, concrete commands, and representative code shapes to guide the implementation.

### Type Consistency

- Sync action names are consistently `requests`, `minimums`, `ledger`, and `all`.
- The planned peer-state field name is consistently `lastSynchronizedAt`.
- The new coordinator module is consistently named `GBankManager/Sync/ManualActions.lua`.
