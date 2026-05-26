# GBankManager UI Shell Polish Design

Date: 2026-05-23
Branch: `codex/gbankmanager-v1`
Scope: visual modernization pass for the shared shell and its first-order UI surfaces without depending on a new art pack

## Status

This design is no longer just a proposed direction. Its core shell pass has been implemented and extended in the live addon.

The sections below still describe the approved visual direction, but the current product has also accumulated a few implemented addenda that should now be treated as part of the active shell contract:

- dashboard `Quick Actions` is intentionally trimmed to `Add Minimum`, `Create Request`, and `Export Data`
- `Create Request` should launch the request wizard, not only navigate to the Requests view
- `Options` is intentionally trimmed to `Appearance`, `Stock Settings`, `Permissions`, `Blacklist`, and `Data`
- `Options -> Blacklist` is a read-only instructions-plus-list view with the `Refresh` action below the parsed-member list
- `Options -> Data` owns retention, scan interval, and destructive local-data cleanup actions
- `/gbm` now opens the UI the current player can access, while `/gbm help` prints the supported slash-command list
- the shell footer identity card is replaced by the theme crest zone, hidden while the sidebar is collapsed
- `UI Scale` now lives in the right-hand slider column above shell and modal opacity, with the minimap toggle directly beneath the theme presets

## Purpose

This design defines the next shell-focused UI polish pass for `GBankManager`.

The goal is to make the addon feel more modern, smoother, and more WoW-native while preserving:

- current data flow and behavior
- request, scan, export, auth, and sync functionality
- saved variables
- theme support

This pass intentionally does **not** wait on a dedicated art pack. Instead, it uses more native WoW UI elements where practical and reduces the current over-framed, box-heavy presentation.

## Problem Statement

The current UI has a usable structure, but it still reads as dated because it relies on too many repeated framed rectangles, excess linework, and nested panel treatments. Even where the layout has improved, the shell still feels heavier and older than intended.

The user wants:

- fewer lines and fewer boxes within boxes
- a smoother, more modern feel
- more native WoW UI influence
- themes that still feel distinct and colored
- strong readability and data density

## Design Goals

1. Reduce visual noise in the shell without flattening the addon into something generic.
2. Use Blizzard or WoW-native controls and visual patterns where they improve feel or reliability.
3. Keep the addon practical and data-dense rather than airy or web-app-like.
4. Preserve meaningful theme identity even without the art pack.
5. Make the shared shell better first, then let the major screens inherit the improvement.

## Non-Goals

This pass does not:

- attempt near-literal Alliance mockup fidelity through custom bitmap art
- redesign the underlying workflow behavior
- change request, export, sync, or auth rules
- replace all existing shell visuals with a fully new bespoke skin

## Approved Direction

The approved direction for this pass is:

- Overall style: `Hybrid Modern`
- Shell chrome: `Native Paneled`
- Sidebar nav: soft distinct buttons with a stronger selected state
- Top header: `Clean Toolbar Band`
- Main content sections: `Flatter Dark Bands`
- Dashboard top metrics: separate metric cards
- Tables: `Structured Rows`
- Buttons and action strips: `Slim Modern Actions`
- Modals: `Cleaner Floating Sheet`
- Tabs and filters: `Soft Segmented Tabs`
- Themes: clearly colored and visibly distinct
- Density: `Dense but Clean`

Additional approved requirement:

- `Last Scan` time in the header should include a timezone abbreviation when shown in the polished shell

## Visual Principles

### 1. Reduce nested framing

The shell should stop stacking framed rectangles inside larger framed rectangles unless the inner frame has a real semantic job.

Preferred pattern:

- one clear container
- soft inset or banded separation only where needed
- fewer repeated border lines

Avoid:

- thin line borders on nearly every child frame
- repeated inset boxes for both section and subsection when one grouping layer is enough

### 2. Keep WoW feel through control choice, not ornament volume

The shell should feel more native by leaning on WoW interaction patterns, not by adding extra framing.

Use more native or Blizzard-inspired behavior for:

- sliders
- tabs
- segmented selection states
- dropdown rhythm
- button affordance

### 3. Keep themes expressive but structurally disciplined

The shell structure should remain stable across themes, while the themes express themselves through:

- accent rails
- active states
- header tinting
- card tinting
- selected tab or filter treatment
- subtle panel tone shifts

Themes should not rely on noisy border recolors or heavy saturation everywhere.

## Shared Shell Treatment

### Sidebar

- keep distinct nav rows
- soften their edges and weight
- selected nav row gets the stronger active treatment:
  - brighter text
  - stronger accent rail
  - more deliberate selected fill
- inactive rows should remain clearly clickable but visually lighter
- footer identity card remains, but should inherit the cleaner shell treatment

### Top Header

- use one clean toolbar-style band
- keep title, subtitle, status, and actions in a flatter top composition
- reduce framed subcontainers inside the header
- keep `Scan Bank` and `Close` readable and stable across scales
- include timezone abbreviation in the displayed last-scan timestamp

### Main Content Surfaces

- content sections should read as flatter dark bands rather than thickly framed nested panels
- preserve separation through:
  - spacing
  - tonal shifts
  - subtle inset shadow
  - restrained top or bottom dividers
- avoid hard outlines around every child section

## Dashboard Treatment

### Metric Cards

- keep them as separate cards
- make them flatter and cleaner than the current implementation
- preserve strong scanability
- use theme-aware tinted cards carefully, especially for colored themes

### Lower Panels

- `Top 10 Most Used`, `Recent Activity`, and `Quick Actions` should inherit the flatter dark-band treatment
- preserve structure and readability
- avoid returning to overly heavy card framing

## Table Treatment

Tables should remain structured and highly scannable.

Use:

- clear header row
- compact filter strip
- structured row rhythm
- alternating row tone where helpful
- restrained separators

Avoid:

- heavy boxed rows
- large padded card-like row containers
- overly flat rows that lose alignment confidence

## Action Treatment

### Buttons and Action Strips

- move toward slimmer, more modern action treatments
- preserve a WoW-native sense of clickability
- keep primary actions visually stronger, but not oversized or overly framed

### Tabs and Filters

- use soft segmented treatments rather than plain text-first underlines
- preserve obvious active-state affordance
- keep them themeable

## Modal Treatment

Modals should shift toward cleaner floating sheets:

- smoother shell
- less framed dialog-within-dialog feeling
- clear title area
- clean footer actions
- readable field spacing

They should still feel like WoW dialogs, but not like old boxed utility popups.

## Theme Strategy

Themes should stay clearly distinct in this pass.

Without an art pack, theme identity should come from:

- meaningful base-surface tone shifts
- active nav color
- accent rails
- metric-card tinting
- tab or filter emphasis

The shell structure should remain stable so each theme feels intentional rather than chaotic.

## Native WoW Elements to Favor

Where practical, prefer native or Blizzard-style building blocks over custom approximations, especially when they improve interaction feel or reduce visual awkwardness.

Priority candidates:

- `UISliderTemplate`
- Blizzard-style tab segmentation patterns
- Blizzard-inspired inset pane structure
- WoW-like toolbar and button spacing rhythm
- Blizzard scroll or list affordances where compatible with the existing shared shell

This does not require rewriting the entire shell into XML templates. It means favoring native-feeling primitives and patterns over fully custom chrome when the result looks better.

## Implementation Boundaries

This pass should start with the shared shell layer and flow outward:

1. shared shell chrome
2. sidebar nav
3. top header
4. panel/surface variants
5. action variants
6. modal shell treatment
7. dashboard inheritance
8. table inheritance

Do not start with one-off screen restyling before the shared shell contract is updated.

## Testing Strategy

Use TDD and preserve the current focused-suite approach.

Expected coverage updates:

- `ui_shell_spec`
- `ui_options_spec`
- `ui_dashboard_spec`
- `ui_table_spec`
- `ui_requests_spec`
- `ui_minimums_spec`
- `ui_exports_spec`
- `live_smoke_spec` if any shell behavior assumptions change

Validation should cover:

- nav selected-state treatment
- flatter header layout under scale
- slimmer action treatments
- updated modal shell structure
- continued theme switching
- continued readability at current supported scales
- last-scan timezone abbreviation in header rendering
- `/gbm` opening the correct accessible UI surface
- `/gbm help` reflecting the supported slash-command set
- blacklist and data panels keeping their controls inside the visible chrome

## Risks and Mitigations

### Risk: flattening too far makes the addon feel generic

Mitigation:

- keep strong selected states
- keep colored themes expressive
- preserve structured rows and metric-card separation

### Risk: more native controls create visual mismatch with custom shell pieces

Mitigation:

- update the shared shell contract first
- tune spacing and tinting around native elements rather than forcing everything into the old shell language

### Risk: shell polish improves one screen but leaves others behind

Mitigation:

- implement shared variants first
- only then restyle screens through inherited behavior

## Success Criteria

This pass succeeds when:

- the shell looks less dated even without an art pack
- the UI has fewer obvious boxes within boxes
- the shell feels smoother and more native to WoW
- themes still feel distinct and colored
- tables remain strong for scanning
- the dashboard remains structured and readable
- the header displays last-scan time with timezone abbreviation

## Summary

This is a shell-first visual refinement pass, not a full art-driven reskin.

It deliberately trades some of the current heavy framed look for:

- cleaner WoW-native structure
- softer but stronger interaction states
- flatter section treatment
- more modern button, modal, and tab behavior
- colored themes with disciplined structure

It should materially improve how `GBankManager` feels in live WoW before the art pack exists, while still leaving room for future higher-fidelity theme work.
