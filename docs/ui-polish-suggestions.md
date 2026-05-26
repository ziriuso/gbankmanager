# UI Polish Suggestions

This is now a shelf document for the next refinement pass. The first appearance foundation has landed already:

- local-only theme presets
- separate shell scale and table density controls
- separate shell and modal opacity sliders
- collapsed-nav icons
- stronger active-state glow for nav and workflow filters

## Current Reality

- The current branch has a real UI modernization checkpoint committed and pushed.
- The shell, sidebar, header, dashboard cards, export cards, request wizard, About panel, and tabbed Options shell now have reusable structure.
- That said, the live addon still does **not** match the Alliance mockup closely enough in raw visual fidelity.
- The dashboard-specific richer layout pass was intentionally rolled back one iteration because it expanded the structure before the surface art and framing were good enough.
- The next polish pass should stop trying to solve the mockup entirely with generic frame styling and should instead introduce a lightweight addon-local art pack to support the look directly.
- See [docs/ui-reference/mockup-reference-manifest.md](./ui-reference/mockup-reference-manifest.md) for the saved reference set from the working thread.

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

6. Build an art pack to close the fidelity gap.
   - Create or source a small addon-local art pack for the Alliance-target shell rather than continuing to fake all of the mockup treatment with plain WoW backdrop primitives.
   - Prioritize reusable shell assets first:
     - sidebar crest or identity emblem
     - panel corner and edge trims
     - header band treatment
     - nav active rail or glow plate
     - metric-card surface variants
     - quick-action and export-card icon plates
     - subtle inset shadows or divider textures
   - Keep the pack theme-aware where possible, but design the first pass around Alliance because that is the current visual contract.
   - Reuse the same assets across Dashboard, Inventory, History, Minimums, Requests, Exports, About, and Options instead of per-view one-offs.

## Implementation Notes

- Centralize view-level spacing and sizing tokens before adding the scale slider.
- Keep table layouts driven through `UI/TableLayouts.lua` plus shared shell constants so scale and themes stay reusable.
- Prefer small reusable helper functions for nav-button state, theme application, and opacity application instead of per-view one-offs.
- When the sidebar is collapsed, preserve the current active-state cue with both color and icon treatment.
- Treat the art pack as part of the UI system, not as disposable decorative garnish. Asset names, layout hooks, and fallback behavior should all be reusable.

## Decisions Already Made

- Theme presets stay purely local per character.
- Shell scale and table density stay separate controls.
- Icons land in main nav first, then expand selectively into action-strip buttons in a later pass.
