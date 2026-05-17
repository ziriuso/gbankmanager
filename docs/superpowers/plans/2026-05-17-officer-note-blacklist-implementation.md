# Officer Note Blacklist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Guild Info blacklist membership storage with appended `[GBMBL]` officer-note tags while keeping blacklist reasons local to GBankManager and synchronized through addon messages.

**Architecture:** Add one focused guild-roster blacklist source module that owns officer-note tag parsing, roster reads, and note writes. Keep the existing auth policy container, but rebuild active blacklist membership from guild roster when officer notes are visible and stop serializing blacklist membership into the Guild Info policy string.

**Tech Stack:** WoW Lua addon modules, `C_GuildInfo` guild APIs, existing SavedVariables auth store, Lua unit and UI specs.

---

### Task 1: Add the design-backed blacklist source module

**Files:**
- Create: `GBankManager/Domain/OfficerNoteBlacklist.lua`
- Modify: `GBankManager/GBankManager.toc`
- Test: `tests/spec/officer_note_blacklist_spec.lua`

- [ ] Write the failing test
- [ ] Run the new spec and watch it fail
- [ ] Implement note-tag parse, append, remove, and roster-key helpers
- [ ] Run the new spec and watch it pass

### Task 2: Rebuild active blacklist membership from guild roster

**Files:**
- Modify: `GBankManager/Domain/Permissions.lua`
- Modify: `GBankManager/Data/Defaults.lua`
- Modify: `GBankManager/Data/Migrations.lua`
- Test: `tests/spec/auth_spec.lua`
- Test: `tests/spec/officer_note_blacklist_spec.lua`

- [ ] Write the failing auth and roster refresh assertions
- [ ] Run the targeted specs and watch them fail
- [ ] Implement roster-directory persistence plus officer-note-driven refresh in `RefreshPolicyFromGuild`
- [ ] Run the targeted specs and watch them pass

### Task 3: Stop carrying blacklist membership in Guild Info policy strings

**Files:**
- Modify: `GBankManager/Domain/AuthPolicyCodec.lua`
- Modify: `GBankManager/Domain/AuthPolicySource.lua`
- Test: `tests/spec/auth_source_spec.lua`

- [ ] Write the failing auth-source assertions for no-blacklist Guild Info export
- [ ] Run the auth-source spec and watch it fail
- [ ] Implement minimal codec and apply-path changes
- [ ] Run the auth-source spec and watch it pass

### Task 4: Wire options save to automatic officer-note writes

**Files:**
- Modify: `GBankManager/UI/MainFrame.lua`
- Modify: `tests/helpers/wow_stubs.lua`
- Test: `tests/spec/ui_options_spec.lua`

- [ ] Write the failing options test for automatic officer-note writes and status handling
- [ ] Run the UI options spec and watch it fail
- [ ] Implement the write-on-save flow and visible status messaging
- [ ] Run the UI options spec and watch it pass

### Task 5: Preserve reason sync and live event behavior

**Files:**
- Modify: `GBankManager/Sync/SyncEvents.lua`
- Modify: `tests/spec/sync_spec.lua`

- [ ] Write the failing sync assertion for learned blacklist reason metadata surviving auth snapshot sync
- [ ] Run the sync spec and watch it fail
- [ ] Implement the minimal sync-safe merge behavior
- [ ] Run the sync spec and watch it pass

### Task 6: Update docs and verify end to end

**Files:**
- Modify: `README.md`
- Modify: `docs/testing.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `docs/superpowers/handoffs/latest-handoff.md`

- [ ] Update user-facing docs to describe officer-note blacklist sourcing
- [ ] Run `.\tools\lua\lua.exe .\tests\run_all.lua`
- [ ] Deploy with `powershell -ExecutionPolicy Bypass -File .\tools\catalog\Deploy-AddonsToTarget.ps1 -Target Retail`
