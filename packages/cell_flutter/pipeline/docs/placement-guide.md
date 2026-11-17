# Placement Guide — `flutter-pipeline/v1`

This guide is the human-readable mirror of `rules/placement_rules.dart`,
`rules/patterns.dart`, and `rules/anti_patterns.dart`. **The rules are
the source of truth; this guide documents them.** A CI sync check fails
if a rule exists without a guide section or a guide section exists
without a rule.

---

## 1. The seam sentence

> **The cell decides, the widget renders, the listener reacts.**

Every BRD requirement becomes one of three things:

- a **cell** — the reactive state the requirement reads or writes;
- a **widget** — the renderer bound to that cell;
- a **listener** — the side effect reacting to a cell's pulses.

Placement never mixes them: a widget that writes state on every build
is a placement error; a listener that renders is a placement error.
The pipeline's rules encode this seam.

## 2. The BRD-to-widget table

| BRD sentence pattern | First widget | Do NOT |
|---|---|---|
| `User sees the <noun> field` | `CellTextField` | `CellBuilder` with a writable cell |
| `User sees the list of <noun>` | `CellListView.builder` | `Column` of `CellBuilder`s |
| `User sees the <noun>` | `CellBuilder<T>` | a listener for rendering |
| `While the <thing> is in flight, … loading indicator` | `CellAsyncBuilder` (loading branch) | a bare `CircularProgressIndicator` without the cell |
| `A successful <thing> shows the <results>` | `CellAsyncBuilder` (data branch) | — |
| `Submitting … navigates to the … screen` | `CellListener` + navigation | writing state in `build` |
| `Typing in the … triggers a debounced …` | `CellListener` + debounce | a raw `TextField` without a cell |
| `User can add/delete/reorder …` | `CellListener` on the list cell | `setState` list mutation |
| `The user can retry …` | `CellListener` on the async cell | — |
| `Submitting … shows the error "…"` | `CellErrorBoundary` around the form | `Text` under a `bool` flag |
| `A failed … shows the error "…"` | `CellAsyncBuilder` (error branch) | — |
| `An empty … shows the text "…"` | `CellAsyncBuilder` (empty branch) | — |
| `… persists across app restart` | `Cell.restorableState` | a plain `Cell.state` |
| `… updates A and B together` | `CellListener` + `Cell.txApply` | two independent writes |
| `If A fails, B is reverted` | `CellListener` + `Cell.txApply` compensation | — |

## 3. Display rules

### `placeDisplayField` — display a form field

**Matches:** `User sees the (\w+) field`.

**Context check:** the named field must exist in `## State` with type
`String`. The lookup tolerates common spellings (`search` →
`searchQuery`).

**Failure mode:** `UnplaceableSentence / ContextCheckFailed` — the fix
tells the developer to add the state row or reword the sentence.

**Widget choice:** `CellTextField` bound to `#<field>`, label
`<Field>`.

**LEDGER:** `RENDER` (`rendered via CellTextField`).

**Example:** `REQ-001` in `form_heavy.bfd.md` — "User sees the email
field" → `CellTextField(cell: email.cell, …)`.

### `placeDisplayList` — display a list

**Matches:** `User sees the list of (\w+)`.

**Context check:** the named state (or the unique `List<T>` state) must
exist and be list-typed.

**Widget choice:** `CellListView.builder` with `item.toString()`
rows.

**LEDGER:** `RENDER`.

**Example:** `REQ-001` in `list_heavy.bfd.md`.

### `placeDisplayText` — display any other noun

**Matches:** `User sees the (.+)` (not a field, not a list).

**Context check:** the last word must resolve to a `## State` entry.

**Widget choice:** `CellBuilder<T>` rendering the capitalized state
name.

**LEDGER:** `RENDER`.

### `placeDisplayLoading` — the async loading branch

**Matches:** `While the (.+) is in flight, the user sees a loading
indicator`.

**Context check:** a unique async-shaped state (initial mentions
`AsyncValue` / `loading`) must exist.

**Widget choice:** `CellAsyncBuilder` with a waiting branch rendering
`Loading...`.

**LEDGER:** `RENDER`.

### `placeDisplaySuccess` — the async data branch

**Matches:** `A successful (.+) shows the (.+)`.

**Context check:** a unique async-shaped state must exist.

**Widget choice:** `CellAsyncBuilder` with a data branch.

**LEDGER:** `RENDER`.

## 4. Interaction rules

### `placeInteractionForm` — submit a form and navigate

**Matches:** `Submitting (.+) navigates to the (.+) screen`.

**Context check:** the destination screen, a matching `## Forms` row,
and a `submit` state must exist.

**Widget choice:** `CellListener` on `#submit` + form fields; the
screen emits a submit button (`tap` trigger) and a navigation side
effect.

**LEDGER:** `INTERACT`.

### `placeInteractionList` — add / delete / reorder

**Matches:** `User can (add|delete|reorder) (.+)`.

**Context check:** the named (or unique) `List<T>` state must exist.

**Widget choice:** `CellListener` on the list cell with the matching
list action helper.

**LEDGER:** `INTERACT`.

### `placeInteractionRetry` — retry an async operation

**Matches:** `The user can retry (.+)`.

**Context check:** a unique async-shaped state must exist.

**Widget choice:** `CellListener` on the async cell with a retry
helper.

**LEDGER:** `INTERACT`.

### `placeInteractionDebounce` — debounced input

**Matches:** `Typing in the (.+) triggers a debounced (.+)`.

**Context check:** a `String` field state (any word of the phrase may
resolve it) and an async target state.

**Widget choice:** `CellListener` on the field cell with a debounced
search helper.

**LEDGER:** `INTERACT`.

## 5. Recovery rules

### `placeRecoveryValidation` — form validation errors

**Matches:** `Submitting (.+) shows the error "(.+)"`.

**Context check:** a `## Forms` row must exist.

**Widget choice:** `CellErrorBoundary` around the form fields; the
fallback renders the quoted error text.

**LEDGER:** `RECOVER`.

### `placeRecoveryNetwork` — async failure branch

**Matches:** `A failed (.+) shows the error "(.+)"`.

**Context check:** a unique async-shaped state must exist.

**Widget choice:** `CellAsyncBuilder` with an error branch rendering
the quoted error text.

**LEDGER:** `RECOVER`.

### `placeRecoveryEmpty` — async empty branch

**Matches:** `An empty (.+) shows the text "(.+)"`.

**Context check:** a unique async-shaped state must exist.

**Widget choice:** `CellAsyncBuilder` with an empty branch rendering
the quoted text.

**LEDGER:** `RECOVER`.

## 6. Atomic rules

### `placeAtomicTransaction` — persist across restart

**Matches:** `(.+) persists? across app restart`.

**Context check:** the named state must exist with `Restorable: yes`.

**Widget choice:** `Cell.restorableState<T>` (RestorePattern); the
app root gains a `CellRestorationScope`.

**LEDGER:** `INTERACT` (`persisted via Cell.restorableState`).

### `placeAtomicMultiCell` — update two cells together

**Matches:** `(.+) updates (.+) and (.+) together`.

**Context check:** both states must exist.

**Widget choice:** `CellListener` + `Cell.txApply` over both cells.

**LEDGER:** `INTERACT`.

### `placeAtomicRollback` — compensation on failure

**Matches:** `If (.+) fails, (.+) is reverted`.

**Context check:** both states must exist.

**Widget choice:** `CellListener` + `Cell.txApply` with a compensation.

**LEDGER:** `INTERACT`.

## 7. The eight patterns

| Pattern | Template | LEDGER kind |
|---|---|---|
| `DisplayPattern` | `CellBuilder<T>` / `CellListView` | `RENDER` |
| `SelectorPattern` | `CellSelector<T, S>` | `RENDER` |
| `AsyncPattern` | `CellAsyncBuilder<T>` (loading/error/empty branches) | `RENDER` / `RECOVER` |
| `FormPattern` | `CellTextField` / `CellFormField<T>` | `RENDER` / `INTERACT` |
| `RestorePattern` | `Cell.restorableState<T>` + `CellRestorationScope` | `INTERACT` |
| `RoutePattern` | `CellRouterStateMirror` / `useCellRouter` (Phase C; `Navigator` fallback) | `INTERACT` |
| `AuditPattern` | `CellListener` + `Cell.txApply` | `INTERACT` |
| `IsolationPattern` | `cell.unmodifiable` passed to a child | `RENDER` |

## 8. The do-NOT rules

### `checkCellInBuild`

A `Cell` is created inside a `build` method. The generated code never
does this; the rubric flags hand-edited code. Fix: move the cell to
`initState` or a `lib/cells/` file.

### `checkWritableCellToChild`

A writable `ValueCell` is passed to a child widget. Fix: pass
`cell.unmodifiable`.

### `checkRawObserveInWidget`

`Cell.observe` called inside a widget. Fix: use `CellListener`.

### `checkSetStateOnCell`

`setState` updates a cell-held value. Fix: write `cell.value = …`.

### `checkUnkeyedHookBuilder`

An unkeyed `HookBuilder` around a cell-swappable binding (**heuristic
by design**). Fix: key the builder.

## 9. What the rubric verifies

*(Added in Phase D.)* After generation, the five-category rubric
checks: coverage, placement correctness, anti-pattern compliance,
verification completeness, and structural invariants. See
`docs/rubric.md`.
