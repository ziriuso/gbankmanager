# GBankManager AceComm Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current custom sync path with vendored AceComm-based communication while enforcing per-guild data isolation, targeted request routing, officer-authoritative minimum sync, everyone-readable ledger sync, and a persisted Sync tab in Options.

**Architecture:** Land the redesign in layers so each layer is testable on its own. First, make the saved-variable store truly guild-scoped so sync state cannot bleed between guilds. Second, vendor the required Ace3 libraries and replace the custom transport/chunking seam with an AceComm adapter. Third, migrate the domain sync families one by one: requests, minimums, ledger, and peer presence. Finish by surfacing persisted peer state in the Options UI and refreshing docs and handoff state.

**Tech Stack:** WoW Lua addon runtime, vendored `LibStub`/`CallbackHandler-1.0`/`ChatThrottleLib`/`AceSerializer-3.0`/`AceComm-3.0`, existing `GBankManagerDB` saved variables, focused Lua specs under `tests/spec/*.lua`, `.\tools\lua\lua.exe`, retail manual verification after deploy

---

## File Structure

- `GBankManager/GBankManager.toc`
  - vendored library load order ahead of addon modules
- `GBankManager/Libs/LibStub/LibStub.lua`
  - vendored Ace bootstrap library
- `GBankManager/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`
  - vendored Ace callback dependency
- `GBankManager/Libs/ChatThrottleLib/ChatThrottleLib.lua`
  - vendored throttled chat transport dependency
- `GBankManager/Libs/AceSerializer-3.0/AceSerializer-3.0.lua`
  - vendored table serialization dependency
- `GBankManager/Libs/AceComm-3.0/AceComm-3.0.lua`
  - vendored AceComm transport dependency
- `GBankManager/Data/Defaults.lua`
  - default root saved-variable shape and per-guild database seed
- `GBankManager/Data/Migrations.lua`
  - compatibility migration from legacy single-db saves to guild-scoped root saves
- `GBankManager/Data/Store.lua`
  - active guild database selection, guild key normalization, and compatibility accessors
- `GBankManager/Sync/Codec.lua`
  - message envelope and payload encode/decode rules above AceSerializer
- `GBankManager/Sync/Transport.lua`
  - AceComm registration, send, receive, prefix health, and callback reporting
- `GBankManager/Sync/SyncEvents.lua`
  - guild event hooks, request/minimum/ledger/peer message dispatch, policy refresh, and auth snapshot removal
- `GBankManager/Sync/Coordinator.lua`
  - request conflict logic reused by inbound sync families
- `GBankManager/Sync/PeerState.lua`
  - new persisted peer state helper keyed by guild scope
- `GBankManager/UI/MainRequestsController.lua`
  - outbound request create/update sync calls
- `GBankManager/UI/MainMinimumsController.lua`
  - authoritative minimum publish hooks
- `GBankManager/Domain/BankLedger.lua`
  - outbound ledger delta materialization and append-only remote merge entrypoints
- `GBankManager/UI/MainFrame.lua`
  - new Sync tab shell and persisted peer rendering
- `tests/helpers/wow_stubs.lua`
  - AceComm and vendored library test doubles
- `tests/spec/store_spec.lua`
  - guild-scoped saved-variable migration and isolation coverage
- `tests/spec/sync_spec.lua`
  - transport, message routing, guild envelope, auth snapshot removal, request/minimum/ledger acceptance rules
- `tests/spec/ui_requests_spec.lua`
  - request send targeting and round-trip behavior
- `tests/spec/ui_options_spec.lua`
  - Sync tab rendering and persisted peer visibility
- `tests/spec/bank_ledger_spec.lua`
  - append-only ledger merge expectations for remote sync
- `docs/testing.md`
  - focused and full verification commands for AceComm sync
- `docs/manual-test-checklist.md`
  - multi-client manual verification steps
- `docs/superpowers/handoffs/latest-handoff.md`
  - current state, next slice, and manual follow-up notes

---

### Task 1: Make saved variables truly guild-scoped before changing sync transport

**Files:**
- Modify: `GBankManager/Data/Defaults.lua`
- Modify: `GBankManager/Data/Migrations.lua`
- Modify: `GBankManager/Data/Store.lua`
- Modify: `tests/spec/store_spec.lua`
- Test: `tests/spec/store_spec.lua`

- [ ] **Step 1: Write the failing guild-isolation storage specs**

```lua
local isolatedRoot = store.Normalize({
    guilds = {
        ["Guild Testers"] = defaults.CreateDatabase("Guild Testers"),
        ["Bank Alts"] = defaults.CreateDatabase("Bank Alts"),
    },
    activeGuildKey = "Guild Testers",
}, "Guild Testers")

assert.truthy(type(isolatedRoot.guilds) == "table", "normalized root should expose guild buckets")
assert.equal("Guild Testers", isolatedRoot.activeGuildKey, "active guild key should track the requested guild")
assert.equal("Guild Testers", isolatedRoot.guilds["Guild Testers"].meta.guildName, "requested guild bucket should preserve guild metadata")
assert.equal("Bank Alts", isolatedRoot.guilds["Bank Alts"].meta.guildName, "other guild buckets should remain isolated")

local legacyRoot = store.Normalize({
    meta = { guildName = "Legacy Guild" },
    requests = { { requestId = "legacy-1" } },
}, "Legacy Guild")

assert.truthy(type(legacyRoot.guilds) == "table", "legacy single-db saves should migrate into guild buckets")
assert.equal("legacy-1", (((legacyRoot.guilds["Legacy Guild"] or {}).requests or {})[1] or {}).requestId, "legacy requests should move into the migrated guild bucket")
```

- [ ] **Step 2: Run the focused store spec to verify it fails**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
```

Expected:

- `FAIL` because the current store still treats `GBankManagerDB` as a single database instead of a guild-scoped root

- [ ] **Step 3: Implement the minimal guild-root shape and compatibility migration**

```lua
function defaults.CreateDatabaseRoot(guildName)
    local resolvedGuild = tostring(guildName or "Unknown")
    return {
        activeGuildKey = resolvedGuild,
        guilds = {
            [resolvedGuild] = defaults.CreateDatabase(resolvedGuild),
        },
    }
end
```

```lua
local function normalize_root(root, guildName)
    local resolvedGuild = tostring(guildName or current_guild_name() or "Unknown")
    if type(root.guilds) ~= "table" then
        root = {
            activeGuildKey = resolvedGuild,
            guilds = {
                [resolvedGuild] = ensure_v1_shape(root),
            },
        }
    end

    root.guilds[resolvedGuild] = ensure_v1_shape(root.guilds[resolvedGuild] or defaults.CreateDatabase(resolvedGuild))
    root.activeGuildKey = resolvedGuild
    return root
end
```

- [ ] **Step 4: Re-run the store spec to verify the migration passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\store_spec.lua
```

Expected:

- `PASS tests/spec/store_spec.lua`

- [ ] **Step 5: Commit**

```bash
git add GBankManager/Data/Defaults.lua GBankManager/Data/Migrations.lua GBankManager/Data/Store.lua tests/spec/store_spec.lua
git commit -m "feat: scope saved variables by guild"
```

---

### Task 2: Vendor AceComm dependencies and replace the custom transport seam

**Files:**
- Create: `GBankManager/Libs/LibStub/LibStub.lua`
- Create: `GBankManager/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`
- Create: `GBankManager/Libs/ChatThrottleLib/ChatThrottleLib.lua`
- Create: `GBankManager/Libs/AceSerializer-3.0/AceSerializer-3.0.lua`
- Create: `GBankManager/Libs/AceComm-3.0/AceComm-3.0.lua`
- Modify: `GBankManager/GBankManager.toc`
- Modify: `GBankManager/Sync/Codec.lua`
- Modify: `GBankManager/Sync/Transport.lua`
- Modify: `tests/helpers/wow_stubs.lua`
- Modify: `tests/spec/sync_spec.lua`
- Test: `tests/spec/sync_spec.lua`

- [ ] **Step 1: Write the failing transport specs for AceComm registration and send/receive**

```lua
_G.AceCommStub.reset()

local payload = transport.Send("WHISPER", "OfficerOne", {
    type = "SYNC_HELLO",
    updatedAt = 55,
    payload = "Stormrage-GuildLead",
})

assert.equal("GBankManager", _G.AceCommStub.lastPrefix, "transport should register and send over the addon AceComm prefix")
assert.equal("WHISPER", _G.AceCommStub.lastDistribution, "transport should preserve AceComm distribution")
assert.equal("OfficerOne", _G.AceCommStub.lastTarget, "transport should preserve the whisper target")
assert.equal(payload, _G.AceCommStub.lastMessage, "transport should pass the encoded sync envelope to AceComm")

local received
transport.SetReceiver(function(message, distribution, sender)
    received = { message = message, distribution = distribution, sender = sender }
end)
_G.AceCommStub.fire("GBankManager", "SYNC_HELLO|55|Stormrage-OfficerOne", "GUILD", "OfficerOne")
assert.equal("OfficerOne", (received or {}).sender, "AceComm receive callback should be wired back into the addon transport")
```

- [ ] **Step 2: Run the focused sync spec to verify the new AceComm expectations fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected:

- `FAIL` because the current transport still uses raw `C_ChatInfo.SendAddonMessage` framing and chunk assembly

- [ ] **Step 3: Vendor the required libraries and wire the TOC load order**

```toc
Libs/LibStub/LibStub.lua
Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
Libs/ChatThrottleLib/ChatThrottleLib.lua
Libs/AceSerializer-3.0/AceSerializer-3.0.lua
Libs/AceComm-3.0/AceComm-3.0.lua
```

- [ ] **Step 4: Implement the minimal AceComm-backed transport adapter**

```lua
local AceComm = LibStub and LibStub("AceComm-3.0", true)

function transport.Initialize(receiver)
    if transport.initialized or not AceComm then
        return transport.initialized == true
    end

    transport.receiver = receiver
    transport.comm = transport.comm or {}
    AceComm.Embed(transport.comm)
    transport.comm:RegisterComm(PREFIX, function(_, message, distribution, sender)
        if type(transport.receiver) == "function" then
            transport.receiver(message, distribution, sender)
        end
    end)
    transport.initialized = true
    return true
end
```

- [ ] **Step 5: Re-run the focused sync spec to verify the transport seam passes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected:

- the AceComm-focused transport assertions pass
- any remaining failures are in higher-level request or policy behavior, not library loading

- [ ] **Step 6: Commit**

```bash
git add GBankManager/GBankManager.toc GBankManager/Libs GBankManager/Sync/Codec.lua GBankManager/Sync/Transport.lua tests/helpers/wow_stubs.lua tests/spec/sync_spec.lua
git commit -m "feat: migrate sync transport to vendored AceComm"
```

---

### Task 3: Migrate request sync to guild-scoped targeted routing and remove auth snapshots

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/Sync/Coordinator.lua`
- Modify: `GBankManager/UI/MainRequestsController.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `tests/spec/ui_requests_spec.lua`
- Modify: `GBankManager/Testing/InGameUnit.lua`
- Modify: `GBankManager/Testing/LiveSmoke.lua`
- Test: `tests/spec/sync_spec.lua`
- Test: `tests/spec/ui_requests_spec.lua`

- [ ] **Step 1: Write the failing request-routing and policy-source specs**

```lua
local sendCalls = {}
transport.Send = function(distribution, target, message)
    sendCalls[#sendCalls + 1] = {
        distribution = distribution,
        target = target,
        type = message.type,
        guildKey = message.guildKey,
    }
end

mainFrame:SubmitRequestFromWizard()
assert.truthy(#sendCalls > 0, "request submission should fan out sync messages")
assert.equal("WHISPER", sendCalls[1].distribution, "request sync should use targeted whisper delivery")
assert.equal("Guild Testers", sendCalls[1].guildKey, "request sync messages should carry the active guild identity")

assert.equal(nil, ns.modules.syncEvents.HandleEvent("CHAT_MSG_ADDON", "GBankManager", remoteAuthPayload, "GUILD", "GuildLead"), "auth policy snapshots should no longer be applied from addon comms")
```

- [ ] **Step 2: Run the focused request and sync specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected:

- `FAIL` because requests still use guild broadcast semantics and auth snapshot handling still exists

- [ ] **Step 3: Implement guild envelopes, recipient targeting, and auth snapshot removal**

```lua
local envelope = {
    type = "REQUEST_CREATED",
    guildKey = active_guild_key(db),
    updatedAt = request.updatedAt,
    payload = {
        actorContext = actorContext,
        request = request,
    },
}
for _, recipient in ipairs(resolve_request_recipients(db, request, actorContext)) do
    transport.Send("WHISPER", recipient.name, envelope)
end
```

```lua
if decodedMessage.type == "AUTH_POLICY_SNAPSHOT" then
    report_sync_status("Ignored retired auth policy snapshot message.")
    return false
end
```

- [ ] **Step 4: Re-run the focused request and sync specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_requests_spec.lua
```

Expected:

- `PASS` for request-targeting and auth-snapshot removal coverage

- [ ] **Step 5: Commit**

```bash
git add GBankManager/Sync/SyncEvents.lua GBankManager/Sync/Coordinator.lua GBankManager/UI/MainRequestsController.lua tests/spec/sync_spec.lua tests/spec/ui_requests_spec.lua GBankManager/Testing/InGameUnit.lua GBankManager/Testing/LiveSmoke.lua
git commit -m "feat: target request sync by guild policy"
```

---

### Task 4: Add officer-authoritative minimum sync and everyone-readable ledger sync

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/UI/MainMinimumsController.lua`
- Modify: `GBankManager/UI/MinimumsView.lua`
- Modify: `GBankManager/Domain/BankLedger.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `tests/spec/bank_ledger_spec.lua`
- Modify: `tests/spec/ui_minimums_spec.lua`
- Test: `tests/spec/sync_spec.lua`
- Test: `tests/spec/bank_ledger_spec.lua`
- Test: `tests/spec/ui_minimums_spec.lua`

- [ ] **Step 1: Write the failing minimum and ledger sync specs**

```lua
local acceptedMinimum = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", minimumPayloadFromOfficer, "WHISPER", "OfficerOne")
assert.truthy(acceptedMinimum, "officer-authored minimum sync should be accepted")

local rejectedMinimum = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", minimumPayloadFromMember, "WHISPER", "MemberOne")
assert.truthy(not rejectedMinimum, "member-authored minimum sync should be rejected")

local itemBefore = #((db.bankLedger or {}).itemLogs or {})
local acceptedLedger = onEvent(events, "CHAT_MSG_ADDON", "GBankManager", ledgerPayload, "GUILD", "MemberOne")
assert.truthy(acceptedLedger, "ledger sync should accept guild peer traffic")
assert.truthy(#((db.bankLedger or {}).itemLogs or {}) > itemBefore, "accepted ledger sync should append remote item log rows")
```

- [ ] **Step 2: Run the focused minimum and ledger specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
```

Expected:

- `FAIL` because there is no dedicated minimum sync family and no dedicated ledger sync family yet

- [ ] **Step 3: Implement dedicated message families with guild checks**

```lua
if message.type == "MINIMUMS_SNAPSHOT" then
    if not actor_can_manage_minimums(actorContext, policy) then
        return false
    end
    return apply_remote_minimums(db, message.payload)
end

if message.type == "LEDGER_DELTA" then
    return bankLedger.MergeRemoteDelta(db, message.payload)
end
```

- [ ] **Step 4: Re-run the focused minimum and ledger specs to verify they pass**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\spec\bank_ledger_spec.lua
.\tools\lua\lua.exe .\tests\spec\ui_minimums_spec.lua
```

Expected:

- `PASS` for minimum authority, ledger append-only merge, and guild-scope rejection coverage

- [ ] **Step 5: Commit**

```bash
git add GBankManager/Sync/SyncEvents.lua GBankManager/UI/MainMinimumsController.lua GBankManager/UI/MinimumsView.lua GBankManager/Domain/BankLedger.lua tests/spec/sync_spec.lua tests/spec/bank_ledger_spec.lua tests/spec/ui_minimums_spec.lua
git commit -m "feat: add minimum and ledger sync families"
```

---

### Task 5: Persist peer presence, add the Sync tab, and refresh docs and verification

**Files:**
- Create: `GBankManager/Sync/PeerState.lua`
- Modify: `GBankManager/Data/Migrations.lua`
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/spec/ui_options_spec.lua`
- Modify: `tests/spec/sync_spec.lua`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`
- Test: `tests/spec/ui_options_spec.lua`
- Test: `tests/spec/sync_spec.lua`
- Test: `.\tools\lua\lua.exe .\tests\run_all.lua`

- [ ] **Step 1: Write the failing peer persistence and Sync tab specs**

```lua
local peerState = ns.modules.syncPeerState
peerState.TouchPeer(db, {
    guildKey = "Guild Testers",
    characterKey = "Stormrage-OfficerOne",
    version = "0.9.0-beta.3",
    messageType = "SYNC_HELLO",
    seenAt = 1717000000,
})

mainFrame:SelectView("OPTIONS")
mainFrame:SetOptionsTab("SYNC")

assert.equal("SYNC", mainFrame.optionsActiveTab, "options should expose the new Sync tab")
assert.truthy(mainFrame.optionsSyncPanel:IsShown(), "Sync tab panel should be visible when selected")
assert.truthy(string.find(mainFrame.optionsSyncPeersText:GetText() or "", "Stormrage-OfficerOne", 1, true) ~= nil, "Sync tab should list persisted peers")
```

- [ ] **Step 2: Run the focused Sync tab and sync specs to verify they fail**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
```

Expected:

- `FAIL` because there is no persisted peer helper and no Sync options tab yet

- [ ] **Step 3: Implement peer persistence and the Options Sync panel**

```lua
db.syncState.peers = db.syncState.peers or {}
db.syncState.peers[guildKey] = db.syncState.peers[guildKey] or {}
db.syncState.peers[guildKey][characterKey] = {
    characterKey = characterKey,
    guildKey = guildKey,
    version = version,
    lastSeen = seenAt,
    lastMessageType = messageType,
}
```

```lua
set_frame_shown(self.optionsSyncPanel, nextTab == "SYNC")
self.optionsSyncPeersText:SetText(build_sync_peer_lines(current_db()))
```

- [ ] **Step 4: Update docs and run the focused plus full verification lanes**

Run:

```powershell
.\tools\lua\lua.exe .\tests\spec\ui_options_spec.lua
.\tools\lua\lua.exe .\tests\spec\sync_spec.lua
.\tools\lua\lua.exe .\tests\run_all.lua
```

Expected:

- `PASS tests/spec/ui_options_spec.lua`
- `PASS tests/spec/sync_spec.lua`
- `PASS .\tests\run_all.lua`

- [ ] **Step 5: Deploy to Retail and complete the multi-client smoke pass**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail
```

Verify after `/reload`:

- characters in two different guilds do not see each other's requests, minimums, ledger rows, or Sync tab peers
- request submission syncs only to the submitter plus policy-qualified viewers
- officer request actions round-trip back to the submitter
- officer minimum changes reach all addon users
- non-officer minimum publishes are ignored
- ledger deltas merge append-only without duplicates
- policy refresh still comes only from Guild Info
- Sync tab persists peer history across reloads

- [ ] **Step 6: Commit**

```bash
git add GBankManager/Sync/PeerState.lua GBankManager/Data/Migrations.lua GBankManager/Sync/SyncEvents.lua GBankManager/UI/MainFrame.lua tests/spec/ui_options_spec.lua tests/spec/sync_spec.lua docs/testing.md docs/manual-test-checklist.md docs/superpowers/handoffs/latest-handoff.md
git commit -m "feat: add sync peer history and options tab"
```

---

## Notes For The Implementer

- You are not alone in the codebase. Do not revert unrelated in-progress edits already present in `Sync/Transport.lua`, `Sync/SyncEvents.lua`, `tests/spec/sync_spec.lua`, `tests/spec/ui_requests_spec.lua`, `docs/testing.md`, or `docs/superpowers/handoffs/latest-handoff.md`. Read them, preserve them, and layer your changes on top.
- Keep Guild Info as the only authority source for policy. Removing `AUTH_POLICY_SNAPSHOT` is required, not optional cleanup.
- Preserve the existing request conflict logic in `Coordinator.lua` unless a failing test proves a narrow change is required.
- CSV `Tier` must remain numeric. Do not treat the completed item-display migration as a new blocker for this sync work.
- Use the local WoW Addon Dev Guide assumptions already validated for AceComm: vendored libs, TOC load order, and message handling above the library layer.

## Self-Review

- Spec coverage: the plan covers guild-scoped persistence, vendored AceComm transport, request targeting, minimum authority, ledger sync, guild isolation, peer persistence, Sync tab UI, docs, and live verification.
- Placeholder scan: no `TODO`, `TBD`, or “implement later” placeholders remain.
- Type consistency: the plan consistently uses `guildKey`, `activeGuildKey`, `MINIMUMS_SNAPSHOT`, `LEDGER_DELTA`, `lastSeen`, and `lastMessageType` across storage, transport, and UI tasks.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-28-gbankmanager-acecomm-sync-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
