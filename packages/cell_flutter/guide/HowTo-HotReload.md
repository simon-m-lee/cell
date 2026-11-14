# HowTo-HotReload

Cells are reactive graph nodes; hot reload preserves them only if their
*lifetime* is not tied to a widget build.

## Where to create cells

- **`initState` / `State` field** — the canonical place:
  `late final StateHandle<int> _counter = Cell.state<int>(initial: 0);`
- **Top-level `final`** — shared, process-lifetime cells.
- **`CellScope`** at the app root — cells registered there are owned by
  the app, not by any screen.
- **Hooks**: `useMemoized(() => Cell.state<int>(initial: 0))` (no deps)
  survives rebuilds; for hot reload the hook state is recreated if the
  widget tree is re-inflated — hoist app-level cells out of `build`.

## Where not to create cells

**`build`**. A cell created in `build` is a new cell on every rebuild:
subscriptions churn, hot reload resets state, and the UI silently detaches
from the old cell. `CellBuilder` detects the anti-pattern heuristically:
three consecutive cell identity swaps produce this warning:

> CellBuilder: the cell identity changed N times in a row. This usually
> means the cell is created in build() — an anti-pattern that breaks hot
> reload. Move the Cell.state / Cell.ingress call to initState, a State
> field, or a top-level final.

## What survives hot reload

State fields, top-level finals, and `CellScope`-registered cells — the
cell *objects* are retained, so their values survive. Widgets re-subscribe
to the same cells.

## What doesn't

Cells created in `build` (new identity each rebuild), and any state kept
in `build`-local variables.

## See also

- `HowTo-Debugging.md` — the three debug diagnostics and how to fix them.
- `HowTo-CellBuilder.md` — the primary display widget.
- `HowTo-Hooks.md` — hook equivalents and their lifetime rules.
