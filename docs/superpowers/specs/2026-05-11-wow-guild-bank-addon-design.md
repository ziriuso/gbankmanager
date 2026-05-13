# World of Warcraft Guild Bank Management Addon Design

## Overview

This addon is an officer-led guild bank inventory and procurement tool for World of Warcraft. It replaces a spreadsheet-heavy workflow with in-game scanning, stock policy management, request approval, historical change tracking, and export generation.

The addon has two primary sources of truth:

- Live guild bank scans are the source of truth for current inventory.
- Officer-maintained rules are the source of truth for desired inventory levels and approved purchasing intent.

The addon is intended for a small officer group collaborating on guild bank management. Regular guild members can submit purchase requests and track their own request status, but they cannot view full bank inventory or planning data.

## Goals

- Scan all accessible guild bank tabs with one button press.
- Store the latest snapshot of current inventory with per-tab and total item counts.
- Maintain a searchable change log across scans, including date-based filtering.
- Support recurring minimum stock policies.
- Support member item requests with officer or guildmaster approval.
- Merge shortages and approved requests into a unified planning view.
- Export to Auctionator, Excel-friendly delimited formats, and customizable templates.
- Sync data automatically when guild members with the addon log in, with manual import/export fallback.

## Non-Goals for V1

- Exposing full guild bank inventory to regular guild members.
- Automating Auction House purchases directly.
- Perfectly proving fulfillment without officer confirmation.
- Becoming a full guild operations suite beyond bank stocking and procurement workflows.

## Existing Workflow to Preserve and Improve

The current process uses an external spreadsheet with these roles:

- `CurrentInventory` receives pasted guild bank inventory data.
- `ShoppingList` tracks minimum stock and what needs to be purchased.
- `AuctionatorList` builds an Auctionator import string.

The addon should preserve the practical outcomes of this process while removing manual copy/paste, text-to-columns, and formula maintenance from day-to-day operation.

## User Roles

### Members

- Search for an item by name or item ID.
- Resolve the request against a list of matching items.
- Submit a request with quantity and optional note.
- View only their own request status.

### Officers

- Run official guild bank scans.
- View dashboard, inventory, history, minimums, requests, exports, options, and about information.
- Create and edit recurring minimum stock rules.
- Approve, reject, reopen, and fulfill requests.

### Guildmaster

- All officer permissions.
- Highest authority for conflict resolution and administrative data ownership.

## Product Structure

The addon should use a dashboard-first officer experience with drill-down screens:

- `Dashboard`
- `Inventory`
- `Minimums`
- `Requests`
- `History`
- `Exports`
- `Options`
- `About`

### Dashboard

Shows actionable information first:

- Last successful scan time
- Scanning officer
- Tabs scanned
- Critical shortages
- Pending requests
- Suggested fulfillments
- Export-ready totals

### Inventory

Shows current guild bank contents from the latest accepted scan:

- Searchable item list
- Per-item total quantity
- Per-tab quantities
- Tab membership
- Last scan metadata

### Minimums

Stores recurring stock policies:

- Global recurring minimums per item
- Tab-specific minimums per item
- Tab-specific rules override broader rules for that tab and item

#### Minimums UX Rules

- Existing saved minimum rows should allow inline editing for:
  - enabled or disabled restock state
  - minimum quantity
- Existing saved minimum rows should not allow the configured `Bank Tab` to be edited
- Newly staged rows must allow `Bank Tab` selection before save
- New-row `Bank Tab` selection should use a dropdown of known guild bank tab names
- Draft-state highlighting must be clearly visible in the live client:
  - changed rows use a yellow-tinted background
  - deleted rows use a red-tinted background
  - added rows use a green-tinted background
- Remove and undo actions should use clear iconography rather than placeholder ASCII symbols
- Inline edit controls must not show ghosted underlying cell text behind the active editor
- The `Enabled Only` and `Show All` toggle states must fit without text overflow
- The Minimums search field should be clearly labeled inside the control frame

#### Minimums Add Modal Rules

- The add-item modal must render above the shared table and shell controls
- Modal copy and field layout must avoid text overflow at real WoW scale
- Fields must be clearly labeled
- Search results should appear in a clean dropdown or list presentation under the relevant search field
- Search results must not jumble or overlap surrounding modal content
- Add-item search must use WoW item database or client item-info resolution, not just the current guild bank snapshot
- Snapshot matches may still assist disambiguation, but the search source must not be bank-only

### Requests

Stores item-resolved purchase requests:

- Requester
- Item
- Quantity
- Note
- Approval state
- Fulfillment state
- Creator role and approval source

### History

Searchable procurement workflow audit log:

- Timestamp column with localized abbreviated timezone
- Category filter
- Action filter
- Actor filter
- Item filter

The visible `History` tab is intentionally limited to procurement workflow events such as:

- Minimum created, updated, enabled, disabled, or removed
- Request created, approved, rejected, fulfilled, or reopened

Raw inventory diff history may still exist in stored data for diagnostics, but it should not be surfaced in the officer-facing `History` tab.

### Exports

Named export presets and on-demand export generation:

- Auctionator
- CSV
- Custom delimited output

Exports should open in a dedicated modal rather than rendering only inline inside the tab. The modal should:

- Show the generated export text in a scrollable text area
- Allow the officer to review the full output before copying
- Provide `Select All` and `Copy` actions
- Keep the export text selectable and easy to copy/paste into external tools

#### Auctionator Export UX

- The export preset should be labeled `Auctionator`
- When Auctionator is selected, the UI should expose a shopping-list name field
- The list name defaults to `GBankManager` but must be officer-editable
- The generated Auctionator text must follow the user-provided sample screenshot format
- `GBankManager` in that format is only the shopping-list name, not a hardcoded required literal

#### CSV Export UX

- The old `Spreadsheet` label should be renamed to `CSV`
- CSV remains the officer-facing preset for Excel-compatible export
- CSV output should keep comma-delimited, header-friendly formatting suitable for copy/paste

## Scanning Design

The shared Lua example demonstrates that a single-button scan flow is feasible. The v1 addon should support `Scan Bank` from the guild bank frame and automatically scan all accessible tabs without requiring manual tab-by-tab user interaction.

### Scan Flow

1. Officer opens the guild bank.
2. Officer presses `Scan Bank`.
3. Addon queries all accessible tabs.
4. Addon records per-slot contents, per-item totals, and per-tab totals.
5. Addon stores a timestamped snapshot.
6. Addon diffs the new snapshot against the previous accepted snapshot.
7. Addon updates dashboard, inventory, and history views.

### Scan Metadata

Each scan should capture:

- Guild name
- Timestamp
- Scanning officer
- Accessible tabs scanned
- Per-item totals
- Per-item per-tab quantities

### Authoritative Scan Model

- Any officer with permission may perform an official scan.
- The latest valid accepted scan becomes the current inventory basis.
- Each scan is attributable to the officer who performed it.

## Data Model

### Inventory Snapshots

Each scan produces a snapshot record containing:

- Snapshot ID
- Guild identifier
- Timestamp
- Scanning officer identity
- List of scanned tabs
- Item records with total quantity
- Item records with per-tab quantity breakdown

### Change Log

Each new scan is compared to the previous accepted scan to create dated change entries:

- Item added
- Item removed
- Quantity increased
- Quantity decreased
- Possible tab move when inferable with confidence

The change log answers what changed between scan A and scan B. It is not a perfect real-time bank transaction ledger.

### Stock Policies

Recurring minimum policies define permanent desired inventory floors:

- Global recurring minimum for an item
- Tab-specific recurring minimum for an item
- Tab-specific rules override broader rules for the same item and tab

### Requests

Requests are item-resolved demand records:

- Request ID
- Requester identity
- Requester role
- Item ID
- Item name at time of request
- Quantity
- Note
- Approval status
- Fulfillment status
- Created timestamp
- Decision timestamp
- Approver identity if applicable

### Export Templates

Templates define output shape rather than data truth:

- Template name
- Delimiter
- Header row enabled or disabled
- Column list and order
- Item representation, such as name, item ID, or both
- Grouping or merge behavior

## Planning Logic

The planning system should merge two demand sources:

- Recurring minimum shortages
- Approved requests

Each item should appear as a single consolidated planning row by default, while preserving attribution to:

- `RESTOCK`
- `REQUEST`

### Calculation Rules

- Current inventory comes from the latest accepted live scan.
- Recurring shortage is `minimum - current`, clamped at zero.
- Approved request quantity contributes demand until fulfilled or closed.
- Consolidated export quantity is the sum of relevant active demand sources for that item.

### Drill-Down Attribution

Officers should be able to expand a consolidated planning row to see:

- Restock contribution
- Request contribution
- Related tab scope
- Related notes where useful

## Request Workflow

### Request Creation

1. User enters item name or item ID.
2. Addon resolves candidate matches.
3. User selects the intended item from a list.
4. User enters quantity and optional note.
5. Addon creates an item-resolved request record.

### Approval Rules

- Member-created requests start as `pending`.
- Officer-created requests auto-approve.
- Guildmaster-created requests auto-approve.
- Only approved requests affect planning and exports.

### Fulfillment Rules

- Later scans may trigger `suggested fulfilled` when inventory appears sufficient.
- Officers can confirm, reopen, reject fulfillment, or override it manually.
- Fulfillment inference should assist, not silently finalize.

### Conversion Rules

Officers may optionally convert an approved request into a recurring minimum policy.

## Exports

The addon should support at least three preset families.

### Auctionator Preset

- Uses the user-provided Auctionator sample as the source of truth for format
- Includes an officer-editable shopping-list name
- Consolidates totals by item from the active planning rows
- Is suitable for direct copy/paste into Auctionator after opening the export modal

### CSV Preset

Excel-friendly delimited output for audit and manual analysis. Recommended fields:

- Item name
- Item ID
- Current quantity
- Recurring minimum quantity
- Approved request quantity
- Total shortage or purchase quantity
- Tab or scope
- Reason tags

### Custom Delimited Preset

Officer-configurable output:

- Delimiter selection
- Field selection and ordering
- Optional header row
- Item identity format
- Optional extra columns for notes or source attribution

## Sync Design

The addon should sync data automatically via in-game addon messages whenever a guild member with the addon logs in. Manual import/export remains available as a fallback and recovery path.

### Sync Scope

Relevant data to sync:

- Latest accepted inventory snapshot metadata
- Change log records
- Minimum policies
- Requests
- Approval decisions
- Export templates where intended to be shared

### Conflict Rules

Sync should not use blind last-write-wins. Preferred conflict order:

1. Higher-authority actor wins over lower-authority actor.
2. If authority is equal, newer timestamp wins.

Authority ordering:

- Guildmaster
- Officer
- Member

### Permissions in Sync

- Members receive only data they are allowed to view.
- Officers and guildmaster receive operational data needed for management.
- Hidden data should not be surfaced to members through synced UI state.

## Risks and Constraints

### Guild Bank API Limits

The guild bank scan can be driven by official APIs and events, but the addon still works from snapshots rather than guaranteed real-time transaction capture. Change history quality depends on scan cadence and inferential diffing.

### Fulfillment Ambiguity

A later inventory increase may not prove that a specific request or one-time purchase target was the cause. Suggested fulfillment should remain officer-confirmed.

### Sync Complexity

Multi-user sync introduces authority, conflict, and eventual consistency concerns. Keeping members out of inventory views reduces risk and simplifies secure sharing.

### Scope Discipline

The addon should stay focused on guild bank stocking and buying decisions. It should avoid absorbing unrelated guild administration workflows in v1.

## Recommended V1 Success Criteria

- One-button scan across all accessible tabs
- Searchable current inventory
- Searchable procurement audit history by timestamp, item, action, and actor
- Recurring minimum policy management
- Member request submission with approval workflow
- Unified planning view with attribution by source
- Auctionator export preset
- CSV export preset
- Custom delimited export preset
- Automatic sync on addon login
- Manual import/export fallback

## Recommended Approach

The recommended product direction is a hybrid inventory and procurement system:

- Inventory is grounded in live guild bank scans.
- Procurement is grounded in recurring minimums and approved requests.
- Collaboration is grounded in officer authority and limited member participation.
- Exports are treated as outputs of the inventory and planning model, not the primary system of record.

This approach best fits the current spreadsheet-backed workflow while improving accuracy, traceability, and collaboration.
