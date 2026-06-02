# GBankManager AceComm Sync Redesign

## Goal

Replace the current ad hoc addon communication layer with a vendored AceComm-based sync system that matches the product rules agreed for this branch:

1. Requests sync between the original submitter and everyone currently allowed to view or act on them through Guild Info policy.
2. Minimums sync to everyone, but only officers or other policy-qualified managers are authoritative publishers.
3. Guild bank ledger history can sync between everyone running the addon.
4. Guild policy no longer syncs over addon messages and instead comes only from Guild Info.
5. Options gets a new `Sync` tab that shows persisted known peers and their last alive timestamp.
6. Sync data stays isolated per guild so a character in one guild never bleeds requests, minimums, ledger history, or peer state into a different guild on the same account.

## Status

Design approved for spec write on 2026-05-28. Implementation has not started yet.

## Current Problems

### Transport is custom and narrow

The current sync transport is a custom codec plus message dispatcher. It now has manual chunking support, but the addon is still carrying its own framing, message routing, and payload-size handling. That is extra maintenance surface for a problem AceComm is already built to solve.

### Policy sync is on the wrong channel

`AUTH_POLICY_SNAPSHOT` currently rides the addon-message path even though the desired authority is Guild Info. Keeping policy on both channels creates split-brain risk and unnecessary message traffic.

### Request visibility is too broad for the target product rule

The current request sync path is guild-broadcast oriented. The desired behavior is narrower: request creation and updates should only move between the submitter and the people who currently have permission to view or manage those requests under the active Guild Info policy.

### Minimums do not have a dedicated authority-aware sync contract

Minimums are shared state, but the authority model is different from requests. Officers or equivalent policy-qualified managers should be the authoritative publishers, while everyone may receive the synced result.

### Peer visibility is too weak

The addon sends a hello today, but there is no persisted peer history, no user-facing Sync tab, and no reliable operator view showing who the addon has communicated with and when they were last seen alive.

### Guild isolation is not explicit enough

The current runtime database already carries guild metadata, but the sync design needs to state this boundary directly. A player using multiple characters in different guilds must not have one guild's synced requests, minimums, ledger history, or peer history show up in another guild's dataset.

### Guild bank ledger sync is not yet part of the main sync contract

Guild bank ledger data needs an everyone-to-everyone sync model more like `GuildBankLedger`, with append-only merge behavior and peer visibility, but the current GBankManager sync scope is centered on requests and policy snapshots.

## Architecture

Keep the existing domain rules and UI shell where they already fit, but replace the transport layer and tighten authority boundaries.

### Keep

- current request domain validation and conflict resolution
- Guild Info as the source of truth for policy and capability checks
- current main options shell and tab pattern in `MainFrame`
- append-only ledger merge expectations

### Replace or remove

- replace the long-term custom transport path with `AceComm-3.0`
- remove `AUTH_POLICY_SNAPSHOT` send and receive behavior
- replace guild-broadcast request sync with recipient-aware routing
- add dedicated minimums sync messages
- add dedicated ledger sync messages
- add persisted peer tracking and Sync status UI

### Isolation boundary

- all synced datasets and peer history are partitioned by guild identity
- local persistence should continue to anchor to the current guild database rather than a cross-character global sync cache
- inbound sync messages should carry enough guild identity to be ignored when they do not belong to the active guild context
- changing to a character in a different guild should surface that guild's own sync state only

## Design

### 1. Vendored AceComm stack

Vendor only the libraries needed for this addon package.

Initial expected set:

- `LibStub`
- `CallbackHandler-1.0`
- `ChatThrottleLib`
- `AceComm-3.0`
- `AceSerializer-3.0`

Rules:

- vendor the libraries into the addon so users do not need a separate Ace3 install
- load only the required libraries in the TOC rather than bundling the whole framework
- use AceComm for message splitting, reassembly, and send callbacks
- keep GBankManager-owned message typing and domain validation above AceComm rather than burying business rules inside the library layer

### 2. Message families and authority model

The sync system should split by data family rather than trying to force one rule across all sync traffic.

#### Requests

Rules:

- any guild member may publish a new request for themselves
- request create and request update messages should be sent only to:
  - the original submitter
  - players who currently qualify to view or manage requests through Guild Info policy
- request routing should be computed from the active guild's roster and policy only
- officer or policy-qualified actions such as approve, reject, fulfill, reopen, cancel, and delete should round-trip back to the submitter
- non-qualified guild members should not receive request payloads
- inbound request messages still go through the existing coordinator and validation rules before mutating local state

Consequence:

- request sync becomes targeted rather than pure guild broadcast
- payload privacy aligns with the current policy model

#### Minimums

Rules:

- minimum datasets may be received by everyone
- only officers or other policy-qualified managers may publish authoritative minimum changes
- inbound minimum messages from non-authoritative senders should be rejected
- minimum traffic from a different guild scope should be ignored
- minimum sync should use its own message family rather than piggybacking on request side effects

Consequence:

- minimums become a first-class shared dataset with a clear authority boundary

#### Guild bank ledger

Rules:

- guild bank ledger updates may sync between everyone running the addon
- ledger sync stays append-only and merge-safe
- duplicate prevention should rely on stable entry identity or stable transaction fingerprints already used by the ledger domain
- ledger entries from a different guild scope should never merge into the active guild ledger
- sync should never delete or rewrite ledger history based only on remote traffic

Consequence:

- ledger sync follows the collaborative model the user wants while staying resilient to repeated or delayed messages

#### Guild policy

Rules:

- policy is never sent by addon comms
- policy refresh continues to come from Guild Info plus roster-driven refresh hooks
- request and minimum authority checks always evaluate against the local Guild Info-derived policy

Consequence:

- there is one authority source for permissions

### 3. Peer presence and alive tracking

Adopt a lightweight presence model inspired by `GuildBankLedger`, not the full GRM network stack.

Rules:

- keep a hello or alive message family for peer discovery
- update peer last-seen state when receiving:
  - explicit hello messages
  - any valid sync payload from that peer
- persist known peers across reloads and relogs
- track at minimum:
  - character key
  - guild identity
  - version when available
  - last alive timestamp
  - last message type
  - capability summary if cheap to compute
- stale peers remain visible in history, but the UI should distinguish stale from currently alive

The persisted peer list belongs to the active guild scope only. A peer discovered while logged into one guild must never appear in another guild's Sync tab unless that same character is also a valid peer in that second guild context.

### 4. Guild scoping and message acceptance

Guild isolation must be enforced both in storage and on the wire.

Rules:

- every sync message family should include a normalized guild identity envelope
- the local sync layer should compare the incoming guild identity against the active database guild metadata before decoding the payload into domain state
- mismatched guild traffic should be ignored and optionally surfaced as debug status, but never merged
- peer history should be recorded under the matching guild scope only
- if a player changes guilds, the new guild starts with its own clean sync namespace except for whatever data already belongs to that guild's saved database

### 5. Sync startup timing

Borrow only the light startup lessons from `Guild_Roster_Manager`.

Rules:

- do not start meaningful sync traffic before addon login initialization completes
- wait until guild context and initial roster or guild info state are available before the first presence burst
- avoid leader election, heavy queue orchestration, or large sync-network construction phases
- if AceComm send callbacks indicate throttling, record that in debug or status state instead of building a large custom scheduler up front

### 6. Sync tab in Options

Add a new `Sync` tab inside the existing Options surface.

The tab should show:

- high-level sync status
- whether AceComm and prefix registration are healthy
- known peers
- each peer's last alive timestamp
- a relative last-seen presentation such as `seen 2m ago`
- the last message type seen from each peer
- basic recent sync status text for operator troubleshooting

The tab should persist peer history between sessions and should fit the current reusable options-panel pattern already used by the existing tabs.

### 7. Transition strategy

The redesign should intentionally separate transport migration from domain rewrites.

Rules:

- first move the message send and receive surfaces to AceComm while preserving existing request behavior under tests
- then remove policy snapshot messaging
- then add minimums sync
- then add ledger sync
- then add peer persistence and the Sync tab polish

This sequencing keeps the risk narrow and makes TDD practical.

## Components

### Files expected to change

- `GBankManager.toc`
- `GBankManager/Sync/Transport.lua`
- `GBankManager/Sync/Codec.lua`
- `GBankManager/Sync/SyncEvents.lua`
- `GBankManager/Sync/Coordinator.lua`
- `GBankManager/UI/MainRequestsController.lua`
- `GBankManager/UI/MainFrame.lua`
- minimums domain or controller files where authoritative publish hooks belong
- ledger sync integration surfaces
- data migrations or normalization for persisted sync peer history
- relevant specs and docs

### New likely surfaces

- a sync peer persistence helper or sync state module
- a dedicated sync options-panel renderer or controller if `MainFrame` needs to stay trimmed

### Likely unchanged

- Guild Info parsing rules in principle
- CSV export `Tier` numeric behavior
- completed item-hyperlink and crafted-quality migration decisions

## Testing Strategy

Follow TDD for each slice of the migration.

### Focused failing specs first

1. AceComm transport seam
- outbound sync should route through AceComm registration and send APIs
- inbound AceComm callbacks should dispatch back into the existing domain handlers
- oversized request payloads should no longer require GBankManager-owned chunk assembly

2. Request visibility and authority
- request creation should target only the submitter plus policy-qualified recipients
- officer or policy-qualified updates should sync back to the submitter
- unqualified recipients should not receive request traffic
- forged or unauthorized request updates should still be rejected

3. Minimums authority
- authoritative minimum publishers should be accepted
- non-authoritative minimum publishers should be rejected
- everyone should be able to consume accepted minimum updates

4. Ledger sync
- remote ledger entries should merge append-only
- duplicate ledger entries should be ignored on replay
- ledger sync should accept traffic from any addon peer

5. Policy source
- addon comm policy snapshot messages should no longer be sent or applied
- guild event refresh should continue to update local policy from Guild Info

6. Sync peer persistence and UI
- peer history should persist across reload-like database reinitialization
- Sync tab should render known peers and last alive information from persisted state

### Verification commands

Run focused specs first, then:

```powershell
.\tools\lua\lua.exe .\tests\run_all.lua
```

### Live verification after deploy

1. Requests
- submitter creates a request on one character
- officer or policy-qualified viewer receives it
- officer updates status
- submitter receives the update
- unrelated non-qualified addon user does not receive the request payload

2. Minimums
- officer updates a minimum
- all addon users receive the update
- non-officer attempt to publish a minimum is ignored

3. Ledger sync
- a ledger-producing client syncs new rows
- other addon users receive the rows without duplicates

4. Policy
- Guild Info changes update permissions without relying on addon comms

5. Guild isolation
- sync data from one guild does not appear when logging into a different guild character on the same account
- cross-guild traffic is ignored rather than merged

6. Sync tab
- peer list persists across `/reload`
- last alive timestamps update after hello or real sync traffic

## Risks and Mitigations

### Risk: AceComm integration changes addon packaging unexpectedly

Mitigation:

- vendor only the required libraries
- add TOC and package verification coverage so release packages include the needed files

### Risk: targeted request routing becomes inconsistent with live policy changes

Mitigation:

- compute recipients from the current Guild Info-derived policy at send time
- keep inbound authorization checks even for targeted traffic

### Risk: minimums and ledger sync broaden scope too quickly

Mitigation:

- land the transport migration and request parity first
- stage minimums and ledger sync in follow-up slices under the same design

### Risk: peer history becomes noisy or stale

Mitigation:

- persist known peers, but visually separate active and stale peers
- keep the stored peer shape intentionally small

### Risk: cross-guild bleed creates privacy or data-integrity issues

Mitigation:

- include guild identity in every sync envelope
- key persisted peer and sync state by guild scope
- add regression tests that simulate one account using two characters in different guilds

## Out of Scope

- switching the whole addon to the wider AceAddon or AceDB architecture
- guild policy authoring over addon comms
- changing the current CSV rule that `Tier` must stay numeric
- reopening completed item-hyperlink or crafted-quality migration decisions as blockers for this sync redesign

## Success Criteria

- GBankManager ships with vendored AceComm-related libs and does not require a separate Ace3 install
- request sync uses recipient-aware delivery aligned to Guild Info policy
- minimums sync is officer-authoritative and everyone-readable
- ledger sync can replicate append-only history between addon users
- policy no longer syncs over addon messages
- one guild's synced state does not bleed into another guild's database or Sync tab
- Options includes a persisted Sync tab with known peers and last alive timestamps
