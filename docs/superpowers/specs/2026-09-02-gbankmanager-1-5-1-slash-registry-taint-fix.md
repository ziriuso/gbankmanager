# GBankManager 1.5.1 Security Boundary Fixes

**Status:** Implemented, fully tested, locally deployed, and approved for stable release on 2026-09-02

## Problem

With GBankManager enabled, Blizzard's `/tm` and `/targetmarker` commands reach
`SetRaidTarget()` through a tainted execution path and WoW raises
`ADDON_ACTION_FORBIDDEN`. The behavior reproduces with every other third-party
addon disabled and does not reproduce when GBankManager is disabled.

GBankManager currently assigns Blizzard's global `SlashCmdList` binding back to
itself before registering `/gbm`. WoW treats that addon-side global assignment
as taint even when the table identity does not change.

After the slash-command repair was deployed and live-verified, entering some
instances exposed a second modern-client restriction in `Features/ChatFilters.lua`.
WoW can supply the monster-chat sender as a secret string. Lua still reports
that value's type as `string`, so the old type guard passed and the subsequent
`MUTED_AMBIENT_NPCS[sender]` lookup raised `attempted to index a table that
cannot be indexed with secret keys`. The same feature also performs Lua string
operations and table storage on message and rendered bubble text, so those
inputs share the same access boundary.

## Requirements

- Do not assign or replace the global `SlashCmdList` binding.
- Continue registering `/gbm` under GBankManager's own `SlashCmdList` key.
- Add regression coverage that fails if GBankManager reintroduces a whole-table
  `SlashCmdList` assignment.
- Bump the patch release metadata and visible About version to `1.5.1` /
  `v1.5.1` without changing SavedVariables migrations or ledger protocols.
- Document the fix and the live-client `/tm` verification step.
- Check `canaccessvalue` before comparing, formatting, or table-indexing
  sender, message, or rendered bubble text supplied by WoW.
- Fail open when chat data is inaccessible: leave the message and bubble
  visible rather than attempting to identify or suppress it.
- Add regression coverage for inaccessible sender, message, and rendered
  bubble text while preserving normal Silvermoon Citizen suppression.
- Pass the full Lua test suite before local Retail deployment.
- Deploy both shipped addon folders and verify source-to-target hash parity.

## Design

Remove only the redundant `_G.SlashCmdList = _G.SlashCmdList or {}` statement.
Keep the existing alias and handler entry assignments. Blizzard initializes and
owns the registry before third-party addons load, so GBankManager must not
provide a fallback table for it.

The plain Lua test runner cannot reproduce WoW's secure/tainted execution
engine. The regression test therefore enforces the source-level security
boundary directly while the manual checklist exercises the real Blizzard
slash-command path.

Use one `can_use_chat_value` helper at the external-value boundary. An
inaccessible sender returns `false` from `IsMutedAmbientNPC` before the muted-NPC
table lookup. Text normalization returns an empty safe value when the source
text is inaccessible, and queueing happens only after normalization. Bubble
region text is checked before it is copied into a Lua table. This follows the
client's `canaccessvalue` pattern without trying to unwrap, stringify, compare,
or store restricted data.

## Non-goals

- No changes to GBankManager command behavior.
- No changes to combat lockdown handling.
- No attempt to infer, reveal, or persist secret chat values.
- No SavedVariables migration, ledger reset, or sync protocol bump.
- No changes to the existing tag-driven GitHub and CurseForge publication
  workflow.

## Acceptance Criteria

1. GBankManager source contains no assignment to `_G.SlashCmdList` itself.
2. `/gbm` remains registered through `SlashCmdList.GBANKMANAGER`.
3. All version surfaces and release workflow examples agree on `1.5.1`.
4. The full Lua suite passes.
5. Local Retail deployment reports exact hash parity for both addon folders.
6. After `/reload`, `/tm 1` and `/targetmarker 0` run without attributing a
   protected-action failure to GBankManager.
7. Inaccessible monster-chat senders return `false` without table indexing or
   Lua errors.
8. Inaccessible message and rendered bubble text are not normalized, queued,
   matched, or hidden.
9. Accessible Silvermoon Citizen chat and bubble suppression retain their
   existing behavior when the option is enabled.

## Verification Record

- The pre-fix focused regression failed on the global `SlashCmdList`
  assignment as expected.
- The post-fix focused slash, TOC, About, and release-workflow specs passed.
- `tests/run_all.lua` passed the complete unit, UI, and integration suite.
- Retail deployment reported exact parity for 73 GBankManager files and 23
  GBankManager_ItemData files, with no missing, extra, or mismatched files.
- The installed TOC reports `1.5.1` / `v1.5.1`.
- The user live-verified that the deployed `/tm` and `/targetmarker` repair
  resolved the protected-action failure.
- The secret-chat regression failed against the old sender lookup as expected,
  then passed after the shared access guard was added.
- `tests/run_all.lua` passed the complete unit, UI, and integration suite after
  the slash-command and secret-chat fixes were combined.
- Refreshed Retail deployment reported exact parity for 73 GBankManager files
  and 23 GBankManager_ItemData files, with no missing, extra, or mismatched
  hashes. The deployed chat-filter source contains the access guard.
- Live-client verification remains for the secret-chat follow-up because a
  real restricted instance context is required to produce secret chat values.
