# WoW Guild Bank Addon Refactor Plan

> **For agentic workers:** execute this as a phased refactor, not a rewrite. Preserve working behavior, keep tests green after each slice, and avoid mixing speculative feature work into architecture changes.

**Goal:** Refactor `GBankManager` to align more closely with `WoWAddonDevGuide` structure and best practices while preserving the current officer workflow, Minimums/Exports functionality, and procurement-audit-only History behavior.

**Primary references:**
- `C:\Users\Ziri\.codex\vendor_imports\WoWAddonDevGuide\04_Addon_Structure.md`
- `C:\Users\Ziri\.codex\vendor_imports\WoWAddonDevGuide\05_Patterns_And_Best_Practices.md`

**Current root:** `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager`

---

## Why Refactor

The addon already has a reasonable folder split, but the implementation no longer cleanly matches its intended architecture.

Highest-value current gaps:

- `GBankManager/UI/MainFrame.lua` is carrying too many responsibilities:
  - shell layout
  - shared table rendering
  - Minimums workflow state
  - Exports modal behavior
  - request actions
  - persistence wiring
  - feature-specific interaction logic
- `GBankManager/Core/Events.lua` is a broad event funnel rather than a thin event boundary feeding well-owned subsystems.
- UI modules and domain modules are not consistently separated by responsibility.
- Some cross-feature state is stored on the frame directly when it should live in narrower controllers or helper modules.
- The original implementation plan assumed a thinner UI/event layer than the current code actually has.

---

## Guardrails

- Keep `History` procurement-audit-only.
- Do not reintroduce `Targets`.
- Do not let the refactor become a feature rewrite.
- Keep current user-facing workflows working unless the current slice explicitly replaces them.
- Keep TDD for every refactor slice that changes behavior or module contracts.
- Verify with `.\tools\lua\lua.exe .\tests\run_all.lua` after each completed slice.

---

## Parked TODO

Do **not** solve this during the structural refactor unless a slice explicitly reopens it:

- offline/global item discovery for Minimums add-item search

Phase 1 baseline decision on May 13, 2026:

- the experimental `ItemSearch` service and Auction House-backed search wiring were reverted out of the implementation worktree
- Minimums add-item search is back on the prior local-only resolver path
- offline/global item discovery remains a follow-up design task, not part of the core architecture refactor

---

## Target Architecture

The refactor should move the addon toward this shape:

- `Core/`
  - bootstrap, constants, slash commands
  - thin event registration and dispatch only
- `Data/`
  - defaults, migrations, store, saved schema normalization
- `Domain/`
  - pure or mostly pure business logic
  - snapshots, diff, planning, exports, requests, permissions
  - future item-search service
- `Features/`
  - live WoW integration workflows with API/event coordination
  - guild bank scanning
  - future item-index collection
- `UI/`
  - shell layout
  - view-specific rendering helpers
  - feature controllers/adapters for user interaction

---

## Refactor Phases

### Phase 1: Stabilize Current Branch

**Goal:** create a safe baseline before large structural edits.

Files likely:
- `GBankManager/Core/Events.lua`
- `GBankManager/UI/MainFrame.lua`
- `GBankManager/UI/MinimumsView.lua`
- `GBankManager/Domain/ItemSearch.lua`
- `tests/spec/item_search_spec.lua`
- `tests/run_all.lua`

Tasks:

- [x] Decide whether to keep the experimental `ItemSearch` files as parked WIP or revert them before the main refactor begins
- [x] Make sure the branch state is intentional and documented
- [x] Update docs/handoff context if needed so the refactor starts from a known baseline
- [x] Rerun `.\tools\lua\lua.exe .\tests\run_all.lua`

### Phase 2: Split MainFrame Responsibilities

**Goal:** reduce `UI/MainFrame.lua` into a shell plus orchestrated helpers.

Likely new files:
- `GBankManager/UI/MainFrameShell.lua`
- `GBankManager/UI/MainTableController.lua`
- `GBankManager/UI/MinimumsController.lua`
- `GBankManager/UI/ExportsController.lua`
- `GBankManager/UI/RequestsController.lua`

Tasks:

- [x] Extract shell construction and shared visual helpers from `MainFrame.lua`
- [x] Extract shared table layout / scrolling / header control logic into a table controller
- [x] Extract Minimums modal and inline edit orchestration into a dedicated UI controller
- [x] Extract Exports preset/modal orchestration into a dedicated UI controller
- [x] Extract Requests action-panel orchestration into a dedicated UI controller
- [x] Leave `MainFrame.lua` as a coordinator rather than a monolith

Success criteria:

- `MainFrame.lua` becomes materially smaller
- feature-specific behavior lives in narrower helpers
- existing tests still pass

### Phase 3: Tighten Event and Feature Boundaries

**Goal:** align with guide recommendations for thinner event layers and clearer ownership.

Files likely:
- `GBankManager/Core/Events.lua`
- `GBankManager/Features/GuildBankScanner.lua`
- new feature/event adapter modules as needed

Tasks:

- [x] Reduce direct feature branching inside `Core/Events.lua`
- [x] Move feature-specific event handling closer to the owning feature module
- [x] Keep event registration centralized only where it improves clarity
- [x] Prefer clear dispatch helpers over long event-condition chains

Success criteria:

- events module mainly registers and forwards
- feature ownership is obvious from file boundaries

### Phase 4: Standardize State and Persistence Flow

**Goal:** make state shape and normalization more predictable across the addon.

Files likely:
- `GBankManager/Data/Defaults.lua`
- `GBankManager/Data/Migrations.lua`
- `GBankManager/Data/Store.lua`
- `GBankManager/UI/MainFrame.lua`
- `GBankManager/Domain/*`

Tasks:

- [x] Audit which state belongs in SavedVariables vs transient runtime state
- [x] Centralize normalization and defaulting patterns
- [x] Reduce ad hoc DB shape assumptions inside UI code
- [x] Introduce explicit helper accessors where UI repeatedly reaches into nested DB tables

Success criteria:

- DB access patterns are more uniform
- UI code does less structural repair work
- migrations/defaults are the clear source of truth

### Phase 5: Sharpen Domain/UI Separation

**Goal:** ensure business rules stay in `Domain/` and view formatting/orchestration stays in `UI/`.

Files likely:
- `GBankManager/Domain/Exports.lua`
- `GBankManager/Domain/Requests.lua`
- `GBankManager/Domain/Planning.lua`
- `GBankManager/UI/*`

Tasks:

- [x] Move non-rendering logic out of UI files when it does not require frame state
- [x] Keep formatting builders and row-shaping logic in well-defined places
- [x] Remove duplicated logic between UI modules and domain helpers where possible

Success criteria:

- UI modules consume domain outputs rather than recomputing rules
- domain modules become easier to test in isolation

Completed in this phase:

- export demand-plan assembly moved behind `Domain/Planning.lua` and `Domain/Exports.lua` database-facing helpers
- `UI/MainFrame.lua` now consumes prebuilt export rows instead of rebuilding planning inputs and quality enrichment inline
- procurement-only history filtering moved into `UI/HistoryView.lua` so the shell no longer hardcodes allowed audit categories
- new isolated tests now cover planning-from-database, export-row materialization-from-database, and procurement-history filtering

### Phase 6: Naming, Documentation, and Final Polish

**Goal:** make the architecture readable and maintainable for future sessions.

Tasks:

- [x] Normalize file/module naming where it improves ownership clarity
- [x] Refresh implementation docs to match the refactored architecture
- [x] Update manual QA checklist for any workflow movement
- [x] Add clear TODO notes for deferred work like offline item indexing

Completed in this phase:

- kept the current controller filenames stable and documented their ownership explicitly instead of doing cosmetic rename churn
- refreshed `README.md` so its feature list and architecture summary match the post-refactor addon shape
- refreshed the implementation delta, manual QA checklist, and latest handoff to match the new `GBankManager` root and the current shell/navigation truth
- captured offline/global item discovery as an explicit deferred design task instead of implied future behavior

---

## Suggested Execution Order

1. Stabilize current branch and decide what to do with the parked item-search experiment.
2. Refactor `MainFrame.lua` first, because it is the biggest architecture hotspot.
3. Refactor event ownership next, once the UI orchestration boundaries are clearer.
4. Standardize persistence/state flow after the UI ownership is less tangled.
5. Finish with naming/doc cleanup.

---

## Review Checklist Per Slice

- [ ] Is behavior still the same from the user's perspective?
- [ ] Did the change reduce coupling rather than just move code around?
- [ ] Is the owning module now more obvious?
- [ ] Did we avoid introducing speculative feature work?
- [ ] Did `.\tools\lua\lua.exe .\tests\run_all.lua` pass?

---

## Next Recommended Prompt

> Continue work on the WoW guild bank addon refactor from the implementation worktree.  
> Worktree: `C:\Users\Ziri\Documents\Codex\2026-05-11\GBankManager\.worktrees\gbankmanager-v1`  
> Branch: `codex/gbankmanager-v1`  
>  
> Read first:  
> `docs/superpowers/plans/2026-05-11-wow-guild-bank-addon-implementation.md`  
> `docs/superpowers/plans/2026-05-13-wow-guild-bank-addon-refactor-plan.md`  
>  
> Then run:  
> `git status -sb`  
> `.\tools\lua\lua.exe .\tests\run_all.lua`  
>  
> Priority for this session: return to live-client QA follow-up or new feature work from the refactored baseline without reopening removed `Targets` or non-planning export logic.
