# Item Search Reliability Redesign

## Summary

Replace the current flat-table, per-keystroke item search with a reliable bundled search subsystem built around:

- Ludwig-style generated token indexes
- verified companion-addon data readiness
- a shared runtime search engine
- session-scoped query caching
- a reusable virtualized results control for Minimums and Requests

The goal is to make search correct, responsive, and predictable in the live WoW client, especially for broad queries like `flask`, `flask of`, and `flask magister`.

## Problem Statement

The current implementation is not trustworthy in the live client even though local tests pass.

Repo truth and live behavior show these failure modes:

- the bundled catalog can appear partially available at runtime
- the search path rebuilds large merged catalogs on every keystroke
- the resolver scans large flat tables repeatedly
- the results UI creates one row per match instead of virtualizing
- broad queries surface only a tiny subset of expected results in live WoW
- crafted-quality markers are not consistently available in the bundled search rows

Even where the resolver works offline against the full bundled dataset, the runtime architecture is still too fragile and too expensive to trust.

## Goals

- Make item search reliable in the live client
- Make broad token searches return the full expected result set
- Keep search responsive with a large bundled catalog
- Share one reusable search system between Minimums and Requests
- Distinguish duplicate-name crafted variants clearly in search results
- Keep action buttons gated on confirmed item selection
- Keep the maintainer pipeline aligned with the new runtime search format

## Non-Goals

- typo-tolerant fuzzy search
- arbitrary substring-only search as the primary strategy
- end-user network fetching
- continued reliance on scanning the full flat bundled catalog on every query

## User Experience

### Search Fields

- `Search Item ID`
  - exact numeric lookup
  - may auto-select on an exact resolved item ID

- `Search Item Name`
  - does not search until at least 2 characters are typed
  - uses token-based matching and ranking
  - does not auto-select broad multi-match queries
  - may auto-select only on an exact normalized full-name match

### Results List

- always scrollable
- virtualized so large result sets remain responsive
- each row shows:
  - crafted quality icon or tier when present
  - item name
  - item ID
- duplicate-name variants remain separate rows

### Selection Rules

- action buttons remain disabled until a confirmed selection exists
- typed text alone is not a valid full-shell selection
- clicking a result row updates `Selected Item`
- exact numeric ID resolution can select immediately

## Search Behavior

### Query Model

Name search is token-first.

- normalize the typed query into lowercase alphanumeric tokens
- normalize simple singular/plural variants like `magister` and `magisters`
- require all query tokens to be represented in the result item name
- rank candidates in this order:
  - exact normalized full-name match
  - exact normalized prefix match
  - all tokens matched in order
  - all tokens matched anywhere

Examples:

- `flask` returns all flask-family results
- `flask of` returns the broad set of `Flask of ...` items
- `flask magister` returns all items containing both terms, including pluralized variants
- `flask of the sha` returns both `Flask of the Shattered Sun` quality variants and related matches such as fleeting variants if they satisfy the token rules

### Item ID Search

- direct numeric lookup against bundled indexed data
- fallback to client cache lookup only when the bundled dataset is unavailable or the exact ID is missing

## Architecture

### 1. Generated Item Search Data

Lives in `GBankManager_ItemData`.

Responsibilities:

- ship the bundled search dataset
- expose compressed item records
- expose token-to-itemID index data
- expose metadata and final readiness state

Generated structures:

- `itemsByID`
  - compact item records keyed by `itemID`
  - fields:
    - `itemID`
    - `name`
    - `quality`
    - `qualityName`
    - `craftedQuality`
    - `craftedQualityIcon`
- `tokens`
  - normalized token dictionary
- `tokenToItemIDs`
  - token key to ordered itemID list
- `metadata`
  - item count
  - token count
  - build information
  - readiness marker

### 2. ItemCatalog Search Engine

Lives in the main addon.

Responsibilities:

- load and validate the bundled dataset
- expose exact ID lookup
- expose token search
- rank results
- hydrate full selected item records by `itemID`
- expose a single shared API for Minimums and Requests

The engine must not rebuild full merged catalogs on every keystroke.

### 3. Search Session Cache

Created when a search UI opens.

Responsibilities:

- store per-session merged search sources
- cache recent token intersections
- cache recent ranked query results
- discard cleanly when the modal or panel closes

This cache is session-scoped, not SavedVariables-backed.

### 4. Reusable Search Results Control

Lives in the shared UI shell layer.

Responsibilities:

- own the shared search inputs
- own the virtualized results list
- own result selection state
- expose consistent selected-item behavior to Minimums and Requests

This control replaces the current eager button-stack style match list.

## Data Format

### Companion Addon Output

Stop shipping the search payload as one giant flat file containing only a monolithic item array.

Instead generate:

- a small bootstrap file
- chunked item-record files
- chunked token-index files

The bootstrap file is responsible for:

- setting metadata
- registering item and token chunks
- setting the final `ready` marker only after the full payload is attached

### Runtime Readiness Contract

The main addon must treat the bundled dataset as valid only if all of these are true:

- metadata exists
- expected item count exists
- token index exists
- readiness marker is set

If any check fails:

- do not silently treat partial data as a full bundled catalog
- mark bundled search as unavailable
- use a clearly limited fallback path instead

## UI Implementation Direction

Use Blizzard-style modern list patterns from the local guide and Blizzard source:

- `ScrollBox`
- `DataProvider`
- `ScrollUtil.InitScrollBoxListWithScrollBar`

The reusable results control should:

- virtualize rows instead of instantiating one row per result
- update only the visible rows
- support large result sets cleanly
- remain reusable for both Minimums and Requests

## Maintainer Pipeline Changes

The item catalog pipeline must generate the new search payload format.

The refresh/build flow must produce:

- compact item records
- normalized token dictionary
- token-to-itemID index
- chunked output files
- metadata and readiness bootstrap

The pipeline also needs to preserve:

- `quality`
- `qualityName`
- `craftedQuality`
- `craftedQualityIcon`

Crafted fields remain nullable for non-crafted rows.

## Testing Strategy

### Unit Tests

- token normalization
- singular/plural normalization
- token intersection behavior
- ranking order
- exact ID lookup
- bundled readiness validation

### UI Tests

- search does not activate before 2 characters
- broad token queries return multi-match result sets
- duplicate-name crafted variants remain separate rows
- result rows show item name and item ID
- result rows show crafted quality icon when present
- action buttons remain disabled until confirmed selection
- results list virtualization wiring exists and remains reusable

### Integration Tests

- companion addon load and readiness validation
- known live-query fixtures such as:
  - `flask`
  - `flask of`
  - `flask magister`
  - `flask of the sha`

### Live Validation

After automated lanes pass, live smoke and manual spot checks should confirm:

- broad queries show the expected families
- duplicate-name quality variants are visible separately
- crafted quality markers appear when the data contains them
- Minimums and Requests both use the same reliable search behavior

## Risks

- data format migration is larger than a small bugfix
- virtualized list integration will require updating current UI tests and shared shell helpers
- crafted-quality metadata may still require follow-up enrichment work in the maintainer pipeline for some item families

## Recommendation

Implement the redesign as a dedicated search subsystem rather than patching the current flat-table path again.

The correct direction is:

- token-indexed bundled data
- explicit readiness validation
- cached runtime query engine
- virtualized reusable results UI

That is the strongest path to a search experience that works and keeps working in the live client.
