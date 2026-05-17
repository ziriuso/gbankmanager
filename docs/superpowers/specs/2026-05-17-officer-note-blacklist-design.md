# Officer Note Blacklist Design

## Goal

Move guild-shared blacklist membership out of the compact Guild Info auth policy string and into appended officer-note tags, while keeping blacklist reasons local to GBankManager and synchronized through addon messages.

## Shared Source Of Truth

- Guild-shared blacklist membership is represented by an appended officer-note tag: `[GBMBL]`
- The tag may appear inside existing freeform officer notes and must not overwrite unrelated note text
- The compact Guild Info auth policy string no longer carries blacklist membership
- Blacklist reasons remain in addon data and continue to sync through `AUTH_POLICY_SNAPSHOT`

## Officer Note Contract

- Add tag:
  - empty officer note -> `[GBMBL]`
  - non-empty officer note -> `<existing note> [GBMBL]`
- Remove tag:
  - remove only the addon-owned `[GBMBL]` token
  - trim surrounding whitespace after removal
  - preserve all remaining human-authored note text
- Do not truncate or overwrite notes to make the tag fit
  - if the officer note cannot fit the appended tag within Blizzard's 31-character limit, report a visible failure and leave the note untouched

## Read Behavior

- On `ADDON_LOADED`, `GUILD_ROSTER_UPDATE`, `PLAYER_GUILD_UPDATE`, and `GUILD_RANKS_UPDATE`, refresh guild policy from live guild state
- If the client can view officer notes and roster data is available:
  - scan guild roster entries
  - rebuild active blacklist membership from `[GBMBL]`
  - preserve local reasons by matching the member against the learned local blacklist directory
- If the client cannot view officer notes:
  - keep existing local blacklist membership and reasons unchanged
  - continue to rely on addon sync or a later viewer-capable refresh

## Write Behavior

- `Options -> Auth` remains the editing surface
- Saving staged blacklist changes attempts automatic officer-note writes through `C_GuildInfo.SetNote(guid, text, false)` when the client can edit officer notes
- Save compares previous active blacklist membership to the staged desired membership and writes only changed members
- After successful writes:
  - refresh the roster-derived blacklist state
  - keep staged local reasons in the learned blacklist directory
  - continue sending `AUTH_POLICY_SNAPSHOT` so other addon clients receive the reason text and local metadata
- If any officer-note write fails:
  - report the failure in options status text
  - do not silently claim success for the guild-shared blacklist change

## Data Shape

Reuse the existing auth container and add roster-note metadata:

- `db.auth.blacklist`
  - active blacklist membership currently derived from officer notes
- `db.auth.blacklistDirectory`
  - learned per-character detail cache including local reason text
- `db.auth.blacklistRosterDirectory`
  - last seen guild-roster metadata keyed by canonical character key
  - stores at least `guid`, `officerNote`, `isBlacklisted`, and `updatedAt`

## UI Behavior

- `Options -> Auth` blacklist rows continue to render as `Character-Server - Reason`
- Status/help text should explain:
  - blacklist membership is guild-shared through officer notes
  - reasons stay in addon data and sync through addon communication
  - Save may fail if the officer note does not have enough free space for the appended tag

## Testing

Add coverage for:

- officer-note tag parse, append, remove, and length-limit behavior
- roster refresh rebuilding blacklist membership from tagged officer notes
- auth policy string export no longer serializing blacklist membership
- options save automatically writing officer notes when permitted
- sync snapshots continuing to carry learned blacklist reason metadata even though Guild Info no longer does
