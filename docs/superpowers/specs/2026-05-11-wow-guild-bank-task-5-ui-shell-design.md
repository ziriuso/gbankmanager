# WoW Guild Bank Task 5 UI Shell Design

## Scope

This addendum defines the officer-facing UI shell for Task 5:

- Main frame structure
- Dashboard-first information hierarchy
- Navigation model
- Visual system for the initial officer views

It does not expand scope into Task 6 request/minimum/target management workflows or Task 7 sync behavior.

## Chosen Direction

The Task 5 UI should use a modern ops dashboard style rather than a Warcraft-themed parchment interface. The goal is to feel like a polished companion tool for officers managing guild bank operations: clean, readable, efficient, and visually current.

### Visual Tone

- Default theme uses steel and slate neutrals
- Styling should feel crisp and professional rather than decorative
- Theme structure should be token-based so alternate themes can be added later without rewriting view logic

### Density

- Content density is balanced
- Officers should see useful information without the frame feeling cramped
- Cards, tables, and controls should use consistent spacing with enough air to keep scanning easy

## Layout Model

The shell should use a sidebar plus top status bar layout.

### Sidebar

- Left-aligned primary navigation
- Supports a collapsed state
- Contains the main sections needed in Task 5:
  - Dashboard
  - Inventory
  - History
  - Exports
- Should be visually stable across view switches

### Top Status Bar

- Always visible while the main frame is open
- Shows scan freshness and scan metadata prominently enough to maintain operator trust
- Hosts primary actions such as `Scan Bank`
- Can also surface compact status pills such as tabs scanned, pending requests, or export readiness

### Content Area

- Main workspace uses card-based sections with consistent spacing and alignment
- Designed to support both summary cards and tabular/list content
- Should avoid one-off layouts per screen when a shared frame pattern will work

## Dashboard Hierarchy

The dashboard should prioritize the officer action queue above all other information.

### Primary Area

The most prominent content on first open should be:

- Critical shortages
- Pending requests
- Suggested fulfillments
- Export-ready purchase work

### Secondary Area

Supporting context should remain visible but subordinate:

- Last successful scan time
- Scanning officer
- Number of tabs scanned
- Snapshot health / freshness

This keeps the dashboard aligned with the user’s stated preference that action queue information matters more than raw scan context.

## View Design Rules

### Dashboard

- Lead with actionable cards and ranked items
- Make the next officer action obvious
- Avoid burying shortages or request pressure below passive metadata

### Inventory

- Reuse the shared shell
- Emphasize search, scan metadata, and structured item browsing
- Present data in a clean list/table pattern rather than freeform text blocks

### History

- Reuse the shared shell
- Make filters readable and consistent with the rest of the interface
- Favor a compact audit/log presentation with clear change-type distinction

### Exports

- Reuse the shared shell
- Present export presets as clear actions rather than raw text output alone
- Keep spreadsheet and Auctionator generation easy to discover

## Interaction Model

- `/gbm ui` opens the main shell on the dashboard
- Sidebar switches the active view without changing the overall frame structure
- Collapsing the sidebar should preserve the current view and content layout
- The shell should be implemented so later Task 6 views can plug into the same frame without redesign

Resizable sections are desirable, but Task 5 should treat them as optional polish. The collapsible sidebar is the required layout affordance for this phase.

## Implementation Guidance

- Build shared frame primitives in `UI/MainFrame.lua` rather than duplicating layout code in each view
- Keep the visual system centralized with reusable colors, spacing values, and section styles
- Keep domain logic out of view files; views should consume already-shaped data from domain modules
- Favor reusable card/list/table helpers where practical so later views inherit the same look and behavior

## Acceptance Criteria

Task 5 is successful when:

- The officer UI opens from `/gbm ui`
- The shell has a collapsible sidebar and top status bar
- The dashboard clearly prioritizes action-queue information
- Inventory, History, and Exports render inside the same cohesive shell
- The visual style feels modern, clean, and intuitive rather than placeholder-like
- The code structure leaves room for future theme options without reworking the shell
