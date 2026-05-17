# UI Polish Suggestions

This is now a shelf document for the next refinement pass. The first appearance foundation has landed already:

- local-only theme presets
- separate shell scale and table density controls
- separate shell and modal opacity sliders
- collapsed-nav icons
- stronger active-state glow for nav and workflow filters

## Priority Themes

1. Make navigation and action surfaces less blocky.
   - Reduce heavy panel boxing around repeated controls where a lighter divider or inset will do.
   - Tighten large rectangular button groups into slimmer strips with stronger hover, active, and pressed states.
   - Use more interior spacing contrast instead of more border boxes.
   - Review corners, border weight, and empty gutters before adding more ornament.

2. Expand icons where they improve scanning speed.
   - Main nav icons are now in place for collapsed mode.
   - Next pass should add matching icons to the expanded sidebar labels once the icon set is stable.
   - After nav is settled, extend icons to high-value action-strip buttons only where they clearly improve scan speed.
   - Keep using the same crafted-quality icon mapping everywhere quality is shown, with the lower tier on the silver diamond and the max tier on the gold pentagon.

3. Tune the preset themes instead of jumping straight to free-form theme editing.
   - Keep theme presets local per character.
   - Current preset direction is: `Current`, `Contrast`, `Horde`, `Alliance`, `Void`, `Adventurer`, `Moonglade`.
   - Next pass should refine contrast, accent balance, and text hierarchy inside each preset before attempting custom token editors.

4. Keep scalable sizing reusable.
   - Shell scale and table density should stay separate controls.
   - Keep table math derived from shared constants so scale does not desync headers, filters, and rows.
   - Review modal sizing and typography again at the smallest and largest supported settings.

5. Keep opacity and focus behavior deliberate.
   - Shell and modal opacity are already split.
   - Future polish should make sure translucent states still preserve readable text contrast.
   - Recheck shell focus behavior against other draggable addon windows during live QA to make sure the top-level ordering feels natural.

## Implementation Notes

- Centralize view-level spacing and sizing tokens before adding the scale slider.
- Keep table layouts driven through `UI/TableLayouts.lua` plus shared shell constants so scale and themes stay reusable.
- Prefer small reusable helper functions for nav-button state, theme application, and opacity application instead of per-view one-offs.
- When the sidebar is collapsed, preserve the current active-state cue with both color and icon treatment.

## Decisions Already Made

- Theme presets stay purely local per character.
- Shell scale and table density stay separate controls.
- Icons land in main nav first, then expand selectively into action-strip buttons in a later pass.
