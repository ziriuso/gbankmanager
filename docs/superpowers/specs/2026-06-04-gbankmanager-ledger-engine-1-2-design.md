# GBankManager Ledger Engine 1.2.0 Design

## Summary

GBankManager 1.2.0 replaces the current Bank Ledger scan and ledger-sync internals with a full-batch ledger engine while retaining the existing GBankManager UI, auth model, options, docs, tests, and release workflow. The goal is to make busy live-guild ledger convergence reliable when multiple addon clients see different visible guild-bank log windows.

The new engine treats ledger rows as a replicated dataset instead of a stream of best-effort recent deltas. Native guild-bank log scans append local rows only when the visible batch proves there are new occurrences. Sync compares bucket hashes first, requests only differing buckets, and imports missing rows without echoing them back out.

## Release And Protocol Boundary

This work ships as `1.2.0`.

The ledger subsystem gets a hard compatibility boundary:

- Bump addon metadata and runtime constants to `1.2.0`.
- Add a dedicated ledger protocol marker, for example `LEDGER_PROTOCOL_VERSION = 2`.
- On first load of `1.2.0`, clear current Bank Ledger item rows, money rows, fingerprints, source snapshots, session batch state, ledger digest state, and ledger peer bucket-sync state.
- Preserve unrelated user and guild data: inventory snapshots, Minimums, Requests, non-ledger History rows, UI settings, auth policy, blacklist state, and general sync peers.
- Reject inbound ledger sync payloads that are missing the new ledger protocol marker or carry an older ledger protocol.
- Leave non-ledger sync families on their existing compatibility rules unless explicitly changed later.

Net effect: `1.2.0` clients form a clean ledger sync island. Older addon clients may still exist in the guild, but their ledger payloads cannot repopulate or poison the reset ledger.

## Scanner Architecture

The ledger scanner moves to a full-visible-batch model.

On manual bank scan, bank-open scan, passive bank-open refresh, or direct ledger scan:

1. Confirm the guild bank is open and ledger scanning is allowed.
2. Build the ordered list of viewable guild-bank tabs.
3. Register for `GUILDBANKLOG_UPDATE` before sending log queries.
4. Query every viewable item-log tab with `QueryGuildBankLog(tabIndex)`.
5. Query the fixed money-log tab with `QueryGuildBankLog((MAX_GUILDBANK_TABS or 8) + 1)`.
6. Debounce `GUILDBANKLOG_UPDATE` briefly so all tab and money-log responses can arrive.
7. Finalize by reading every queried item log and the money log in one pass.
8. Use a timeout fallback only as a safety path when no event arrives, and record that mode in debug state.

The scanner should not advance row state one tab at a time. It should normalize the complete visible batch and then hand that batch to the ledger store.

## WoW API Payload

The engine must continue to assume that WoW does not provide a stable native row ID.

Item logs are read with:

```lua
local actionType, who, itemLink, count, tabOne, tabTwo, year, month, day, hour =
    GetGuildBankTransaction(tabIndex, index)
```

Money logs are read with:

```lua
local actionType, who, amount, year, month, day, hour =
    GetGuildBankMoneyTransaction(index)
```

Derived fields are allowed and expected:

- `itemID` from `itemLink`
- `itemName` from item APIs or item-link text
- crafted quality from the item link or catalog helpers
- source tab index and name from the queried tab
- destination or moved-from tab for move actions
- absolute timestamp derived from server time and Blizzard's relative year/month/day/hour offsets

Because row IDs are synthetic, the dedupe contract must be count-based and bucket-aware rather than purely position-based.

## Transaction Identity And Dedupe

Each visible row becomes a normalized ledger transaction record.

Base identity for item rows:

- normalized action
- actor
- item ID
- quantity
- source tab
- destination or moved-from tab when present
- hour-level time slot

Base identity for money rows:

- normalized action
- actor
- amount in copper
- hour-level time slot

The final stable transaction ID adds an occurrence index to the base identity. Repeated same-actor, same-item, same-quantity, same-hour withdrawals become distinct records when the visible batch count proves more occurrences exist.

Dedupe rules:

- Group the current full visible batch by base identity.
- Compare the current batch count against the local stored count for that base identity, with adjacent-hour tolerance for cross-client relative-time drift.
- Append only the excess occurrences.
- Re-running the same visible batch appends nothing.
- A later visible batch with one additional identical occurrence appends exactly one row.
- Remote merges update stored count/high-water metadata so a following local scan does not reappend already-synced rows.

The store should keep event-count or high-water metadata per base identity so cleanup and sync can reason about repeated identical rows without relying on volatile API row order.

## Bucketed Sync Architecture

Ledger sync becomes dataset reconciliation.

Each client maintains:

- stable transaction IDs for item and money rows
- a global ledger hash
- per-bucket hashes, grouped by time window, initially 6-hour buckets
- peer ledger manifests keyed by guild, peer, and ledger protocol

Sync flow:

1. A native local scan appends rows.
2. The client updates bucket and global hashes.
3. The client broadcasts a compact ledger manifest containing guild key, actor context, addon version, ledger protocol, row count, global hash, and recent bucket hashes.
4. A receiver validates guild, sender, blacklist, version, and ledger protocol.
5. If the manifest matches local hashes, the receiver records convergence and sends no row request.
6. If one or more buckets differ, the receiver requests only those buckets.
7. The sender replies with chunked row payloads for the requested buckets.
8. The receiver merges valid missing rows, updates hashes, refreshes the ledger view if open, and prints at most one routine message if actual rows were written.

Startup behavior:

- `SYNC_HELLO` remains presence-only.
- A `1.2.0` client may send a ledger manifest after login/addon load, but should not push row chunks unless a peer requests them.
- A native local scan that writes rows should publish a manifest immediately.

Noise behavior:

- Same-hash manifests stay silent.
- Bucket requests/replies stay silent unless rows are actually written.
- Rejected old-protocol ledger payloads stay out of routine chat and appear in `/gbm debug sync`.
- Remote sync merges never trigger a new outbound ledger publish.

## Retained UI And Options

The existing GBankManager UI stays in place:

- `Bank Ledger` keeps item/money modes, filters, summaries, export, shared table rendering, and active-view refresh.
- `Options -> Data -> Clear Guild Bank Log Data` clears the new ledger engine state.
- `Options -> Appearance -> Suppress Routine Chat` continues to gate routine ledger scan and sync messages.
- `Options -> Sync` keeps the current peer table; ledger-specific protocol/hash details remain debug-only for the first 1.2.0 pass.

No new visible UI is required for this refactor unless tests or live validation show the debug surface is insufficient.

## Diagnostics

`/gbm debug ledger` should report:

- addon version and ledger protocol version
- ledger reset marker
- last scan trigger and finalize mode: event debounce or timeout fallback
- queried item tabs and fixed money-log tab
- visible row counts per target
- appended row counts per target and per bucket
- current global hash and recent bucket hashes
- stored count/high-water summary for recent repeated identities

`/gbm debug sync` should report:

- last ledger manifest received or sent
- peer ledger protocol
- bucket comparison result
- last bucket request/reply
- last chunk merge summary
- old-protocol or missing-protocol rejection reason

Debug output should stay copy-friendly and should not add routine chat spam.

## Testing Contract

Focused tests should cover:

- First `1.2.0` load clears old ledger rows and ledger sync metadata once.
- Repeated loads do not clear newly scanned `1.2.0` rows again.
- Missing or older ledger protocol payloads are rejected before merge.
- Full-batch scan queries all viewable item tabs plus the fixed money-log tab.
- Log finalization waits for `GUILDBANKLOG_UPDATE` debounce and records timeout fallback diagnostics.
- Repeated identical same-hour item rows append by count.
- Repeated identical same-hour money rows append by count.
- Re-running the same visible batch appends zero rows.
- A later batch with one extra identical row appends exactly one row.
- Remote merges update count/high-water state so local scans do not reappend synced rows.
- Bucket manifest match sends no row request.
- Bucket manifest mismatch requests only differing buckets.
- Chunked bucket payloads merge missing rows without echoing outbound sync.
- Accepted bucket replies print routine ledger sync feedback only when rows are written.
- Full suite remains the release gate with `.\tools\lua\lua.exe .\tests\run_all.lua`.

## Implementation Slices

1. Ledger protocol and reset boundary for `1.2.0`.
2. Full-batch scanner coordinator and diagnostics.
3. Count-based transaction identity and ledger store migration to clean 1.2.0 state.
4. Bucket hash/manifest model.
5. Bucket request/reply chunked sync.
6. UI/debug/docs wiring and manual validation checklist refresh.

Each slice should be TDD-first and keep docs current.

## Non-Goals

- Do not replace the GBankManager shell or Bank Ledger UI.
- Do not make old ledger rows authoritative after the `1.2.0` reset.
- Do not accept ledger sync from older ledger protocols.
- Do not add broad new chat output for scanner or sync internals.
- Do not change unrelated request, minimum, inventory, auth, or blacklist sync behavior unless needed for load order or protocol validation.
