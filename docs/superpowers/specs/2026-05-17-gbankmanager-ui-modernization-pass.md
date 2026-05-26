# GBankManager UI Modernization Pass

## Summary

Modernize the full `Guild Bank Manager` addon shell into a polished WoW-native management tool without changing the underlying workflow contracts, SavedVariables shape, slash commands, exports, permissions, request behavior, or scan logic except where a narrow UI refactor is required to support the new visual system.

This is a big-bang visual pass across the officer shell, the request surfaces, export workflows, options, and Minimums staging presentation. The implementation should reuse the current controller and domain behavior wherever possible, while introducing a reusable theme and component layer that keeps future UI work consistent.

The provided style-guide mockup is not merely inspiration. It is the near-literal target for layout rhythm, panel composition, control grouping, typography hierarchy, button weight, and overall Blizzard-like dark-fantasy presentation. Future implementation decisions in this pass should prefer fidelity to that mockup over preserving today's lightweight shell styling.

## Goals

- Make the addon feel like a modern Blizzard-native management tool rather than a dense prototype shell.
- Make the live addon visually track the supplied style-guide mockup as closely as WoW frame primitives reasonably allow.
- Improve visual hierarchy, spacing, scanning speed, and row readability.
- Introduce a centralized token-based theme system with live switching and persistence.
- Preserve real WoW crafting quality tier icons and stop any drift into rarity-based styling.
- Upgrade Minimums staging presentation so staged adds, edits, and deletes are obvious and grouped at the top.
- Keep the addon practical and data-dense instead of turning it into a sparse decorative UI.

## Non-Goals

- No domain rewrite of planning, requests, permissions, exports, or guild-bank scan semantics.
- No change to the current export payload compatibility for Auctionator, TSM, CSV, or Manual Shopping List formats.
- No change to slash command routing.
- No new sync protocol work in this slice.
- No free-form custom theme editor in this slice.
- No more "light-touch restyle" compromises if they preserve the old generic shell look. Larger shared-shell rewrites are explicitly in scope.

## Current Constraints

- The existing shell already centralizes many widget primitives in `GBankManager/UI/MainFrameShell.lua`.
- Shared table behavior already flows through `GBankManager/UI/MainTableController.lua` and `GBankManager/UI/TableLayouts.lua`.
- Minimums already uses an in-memory staged overlay model and does not need a persistence redesign for stronger staged-row visuals.
- Current appearance settings already persist locally, so the new theme system must migrate older preset keys cleanly instead of resetting user preferences.
- Current crafted-quality rendering is spread across view/controller helpers but already normalizes low-tier and max-tier icon families enough to be wrapped by a reusable renderer.

## Visual Direction

Use the supplied mockup as the primary visual reference and Blizzard/Dragonflight UI as the implementation language.

The live addon should specifically converge on these traits from the mockup:

- dark matte panels
- thin gold accent borders
- restrained inner shadow and layered inset treatment
- deliberate gold separators rather than default WoW tooltip boxes everywhere
- hover and focus glow that stays subtle but visible
- section framing that feels like carved panels, not generic utility rectangles
- more space between groups
- readable row scanning
- strong gold headers with muted support text
- denser but cleaner table chrome
- visually distinct metric cards, tab pills, and export cards
- narrow polished sidebar with icon-led navigation and a guild identity footer
- no generic SaaS or web-dashboard look

The UI should feel like a serious guild operations tool that belongs in WoW.

## Fidelity Rules

The implementation should follow these fidelity rules:

- Prefer rebuilding shared shell primitives over restyling old ones in place if the old primitive cannot visually match the mockup.
- Buttons, tabs, metric cards, export cards, row badges, and sidebar items should each have explicit component variants instead of sharing one generic bordered button helper.
- The default `Generic WoW` theme should visually align with the mockup's baseline palette and framing treatment.
- Screen composition should stay close to the mockup's information architecture unless a live addon workflow forces a narrow deviation.
- If a tradeoff is required, preserve workflow correctness first, then preserve the mockup's hierarchy and grouping, and only last preserve old frame code.

## Quality Icon Contract

Crafting quality is not item rarity and must stay visually independent from stock or request status.

### Five-tier items

- Tier 1: bronze single diamond
- Tier 2: single silver diamond
- Tier 3: three gold diamonds
- Tier 4: cyan or teal gem cluster
- Tier 5: golden pentagon

### Two-tier items

- Tier 2: single silver diamond
- Tier 5: golden pentagon

### Required behavior

- Never show two silver diamonds for a two-tier item.
- Never recolor quality icons through theme tokens.
- Verify atlas availability at runtime through `C_Texture.GetAtlasInfo` when present.
- Prefer `Texture:SetAtlas`.
- Provide a safe fallback atlas or markup path when an atlas is unavailable.
- Support 14, 16, 18, and 20 pixel display sizes.
- Default table usage should be 16.
- Detail panels and modals may use 20.

## Theme System

Introduce a centralized `GBM.ThemeManager` layer that owns theme registration, theme lookup, token access, preset migration, and repaint hooks for all active frames.

### Required themes

1. `Alliance`
2. `Horde`
3. `Generic WoW`
4. `Nature`
5. `Void`
6. `High Contrast`

### Theme token set

- `bg`
- `bgAlt`
- `panel`
- `panelAlt`
- `border`
- `borderSoft`
- `accent`
- `accentHover`
- `accentMuted`
- `text`
- `textMuted`
- `textStrong`
- `header`
- `button`
- `buttonHover`
- `buttonText`
- `danger`
- `warning`
- `success`
- `info`
- `row`
- `rowAlt`
- `rowHover`
- `inputBg`
- `inputBorder`
- `modalBg`
- `modalBorder`
- `shadow`

### Semantic status colors

These should remain functionally stable across every theme:

- Healthy or At Minimum: green
- Low Stock: yellow or amber
- Critical: red
- Pending: blue
- Approved: green
- Rejected: red
- Disabled: gray

### Preset migration

Older local appearance preset values should migrate without breaking SavedVariables:

- `default` -> `generic_wow`
- `contrast` -> `high_contrast`
- `horde` -> `horde`
- `alliance` -> `alliance`
- `void` -> `void`
- `moonglade` -> `nature`
- `adventurer` -> `generic_wow`
- `warm` -> `generic_wow`

If a saved preset is unknown, fall back to `Generic WoW`.

## Layout Tokens

Introduce shared layout tokens:

- `spacingXS = 4`
- `spacingSM = 8`
- `spacingMD = 12`
- `spacingLG = 16`
- `spacingXL = 24`
- `rowHeightCompact`
- `rowHeightComfortable`
- `rowHeightWide`

Add a reusable density setting with:

- `Compact`
- `Comfortable`
- `Wide`

The UI scale slider changes shell sizing, while density changes row spacing, filter spacing, and table rhythm without breaking layout math.

## Typography

Use WoW-native fonts and hierarchy:

- large gold title for the main screen title
- smaller gold section labels
- light gray or ivory body copy
- muted gray metadata
- bright values for metrics and numeric emphasis

## Screen Contracts

### Shell

The shell keeps the current navigation model:

- Dashboard
- Inventory
- History
- Minimums
- Request Admin
- Exports
- About
- Options

The left sidebar should closely match the mockup's left rail:

- icon plus label
- selected accent bar or filled active state
- restrained hover glow
- clear collapsed behavior
- footer identity card for player and guild context when available
- slim carved-panel framing rather than broad boxed buttons

The top header should visually track the mockup:

- addon title
- per-screen subtitle
- last scan timestamp
- Scan Bank button
- Close button
- narrow gold dividers and more deliberate vertical rhythm than the current top bar

### Dashboard

Replace the current simple card stack with the mockup-style dashboard composition:

- metric card row:
  - Last Scan
  - Pending Requests
  - Ready to Buy
  - Critical Shortages
- Top 5 Most Used panel
- Recent Activity panel
- Quick Actions row

This remains a visual re-layout of current data plus the new `Critical Shortages` summary if it can be derived from existing plan rows without changing planning behavior.

The cards should look like distinct Blizzard-style utility cards, not plain shared panels with relabeled text.

### Inventory

Inventory should present the mockup-style dense table shell:

- search input
- tier filter
- bank-tab filter
- Restock Only toggle
- Low Stock Only toggle
- status-aware table rows
- footer summary with item count and actions

The screen should feel data-dense and practical, with the table as the dominant surface and controls tucked into a polished top filter row and bottom action strip.

### History

History should present:

- category filter
- item filter
- date range controls
- search
- action badges for Created, Updated, Removed, Approved, Rejected, and Fulfilled

History should read close to the mockup: high-contrast row scanning, restrained separators, and compact filter controls.

### Minimums

Minimums keeps the current staged persistence model, but its visible contract changes:

- staged rows are grouped at the top
- staged adds are green
- staged edits are yellow
- staged deletes are red
- staged rows show clear `ADD`, `EDIT`, or `DELETE` badges
- footer clearly reports staged-change count
- `Save Changes` is emphasized when staged rows exist
- `Revert All` appears or enables only when needed

Delete behavior remains staged-only until save, and delete confirmation copy must say so explicitly.

### Request Admin

Request Admin should move visually toward the mockup's tabbed filter chips:

- All Requests
- Pending Approval
- Pending Fulfillment
- Completed

Status should use badge treatment, not only plain text.

### Exports

Exports should present the current compatible actions as export cards matching the mockup's composition:

- Auctionator
- TSM
- CSV Spreadsheet
- Manual Shopping List

The export formats themselves must stay byte-for-byte compatible with current expected behavior.

### About

About should become the centered branded information panel from the mockup, including a stronger crest or emblem treatment if existing assets allow.

### Options

Options should use a tabbed settings layout close to the mockup:

- Appearance
- Permissions
- Blacklist
- Automation
- Exports
- Requests

Appearance must include:

- theme dropdown
- UI scale slider
- shell opacity slider
- modal opacity slider
- density dropdown
- font size dropdown
- checkboxes for icons, tooltips, compact rows, and alternate row coloring

Permissions and Blacklist keep current behavior but gain cleaner grouping, mockup-style section framing, and safer text wrapping.

## Modal Contract

Create a consistent modal styling system for:

- Add Minimum
- Confirm Delete (Staged)
- Save Changes
- Scan Confirmation
- CSV Export
- Manual Shopping List
- Request Details

Shared modal behavior:

- centered frame
- dark backdrop overlay
- titled header row
- close affordance
- footer action row
- escape-close where safe
- themed primary, secondary, and destructive buttons

Modals should visually match the mockup's heavier framed treatment instead of inheriting the old lightweight dialog feel.

## Accessibility

This pass must improve:

- high-contrast readability
- explicit hover and focus states
- font-size scaling
- density control
- opacity control
- communication through badges and labels, not color alone

## Architecture

### New or expanded modules

- `GBankManager/UI/ThemeManager.lua`
  - theme registry
  - token lookup
  - preset migration
  - repaint coordination
- `GBankManager/UI/StyleTokens.lua`
  - shared spacing, sizing, density, and semantic color definitions
- `GBankManager/UI/Components/QualityIcon.lua`
  - atlas resolution
  - runtime atlas verification
  - texture application
  - markup fallback

### Existing modules to adapt or partially rebuild

- `GBankManager/UI/MainFrameShell.lua`
  - remain the widget-factory and shell-primitive layer, but larger rewrites are allowed here
  - consume ThemeManager and StyleTokens
  - expose explicit component variants for button, tab, nav item, metric card, export card, badge, input, slider, modal, and viewport helpers
- `GBankManager/UI/MainFrame.lua`
  - remain the top-level composition and routing layer
  - apply new shell, header, dashboard, nav, options, and modal composition
- `GBankManager/UI/MainTableController.lua`
  - centralize row heights, hover/selection visuals, status badges, header styling, and filter-row treatment
- `GBankManager/UI/TableLayouts.lua`
  - centralize new column metadata such as alignment, importance, density behavior, and optional badge/icon columns
- `GBankManager/UI/MainMinimumsController.lua`
  - retain the staged overlay model
  - enrich draft grouping and row-state decoration
- `GBankManager/UI/MainRequestsController.lua`
  - adopt shared modal and badge helpers
- `GBankManager/UI/MainExportsController.lua`
  - adopt export cards and shared modal styling
- `GBankManager/UI/DashboardView.lua`
  - expand to support metric cards, quick actions, and recent activity rows

### Implementation boundary

The modernization should adapt existing files where they already own the right behavior surface instead of replacing them wholesale. However, larger rewrites of shared shell primitives are encouraged if the existing helpers cannot achieve mockup fidelity cleanly. View modules remain responsible for data shaping, while shell and table primitives become the shared presentation layer.

## Testing Strategy

Follow TDD for each UI behavior slice.

### New or expanded automated coverage

- theme preset migration and fallback behavior
- live repaint on theme switch
- density and font-size mapping
- dashboard card layout data contract
- Inventory and Minimums quality icon rendering through the shared renderer
- two-tier item rendering using single silver diamond and golden pentagon
- Minimums staged rows grouped above non-staged rows even after sort application
- staged badge text and tint behavior
- Request Admin status badge rendering
- Exports action-card presence while preserving existing export output
- Options tabbed sections and new appearance controls
- modal opacity application through the shared modal layer

### Manual verification

- open every main view and confirm the shell style is coherent
- verify quality icons in Inventory, Minimums, Requests, Exports, and Manual Shopping List
- verify two-tier items display single silver diamond and golden pentagon
- verify staged Minimums rows stay grouped at the top
- verify export outputs did not change format
- verify request workflow still functions
- verify older saved local appearance settings migrate cleanly
- visually compare the live addon against the supplied mockup and treat obvious composition mismatches as failures, not polish backlog

## Risks

- `MainFrame.lua` and `MainFrameShell.lua` are high-fanout files, so helper signature drift can ripple widely.
- Shared table styling changes can quietly affect Inventory, Minimums, and Requests at once.
- A too-large shell rewrite could destabilize request-only mode unless layout ownership remains explicit.
- Theme migration can accidentally reset user appearance if old preset keys are not mapped carefully.
- Quality-icon centralization can break sorting if display and numeric tier handling drift apart.

## Recommendation

Implement this as a true full-pass modernization, but keep the risk controlled by building the shared theme, token, table, modal, and quality-icon layer first and then migrating each screen onto it without changing domain contracts. The right win condition is a noticeably more polished addon that still behaves exactly like the current product underneath.
