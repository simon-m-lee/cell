# cell_flutter — Documentation Index

The map to everything in `cell_flutter` 0.5.0.

## Start here

- New to Mitosis? → `guide/HowTo-CellBuilder.md`
- Evaluating whether to use it at all? → `doc/CHOOSING.md`
- Comparing Cell against Riverpod / BLoC / Provider / GetX / Signals? →
  `doc/comparison.md` (the fair comparison matrix + decision tree)
- Migrating from Riverpod? → `guide/MigratingFrom-Riverpod.md`
- Migrating from Bloc? → `guide/MigratingFrom-Bloc.md`
- Comparing both and deciding? → `guide/Migrating-From-Riverpod-BLoC.md`

## Decision table

| I want to... | Read |
|---|---|
| Decide whether Cell is right for my app | `doc/comparison.md` |
| Display state in a widget | `guide/HowTo-CellBuilder.md` |
| React to pulses (navigation, snackbars) | `guide/HowTo-CellListener.md` |
| Share cells app-wide | `guide/HowTo-CellScope.md` |
| Display a slice of a value | `guide/HowTo-CellSelector.md` |
| Display async state | `guide/HowTo-CellAsyncBuilder.md` |
| Display a derived cell | `guide/HowTo-DerivedCells.md` |
| Interop with Streams | `guide/HowTo-Streams.md` |
| Use hooks instead of widgets | `guide/HowTo-Hooks.md` |
| Test cells in widgets | `guide/HowTo-Testing.md` |
| Debug warnings | `guide/HowTo-Debugging.md` |
| Fix hot reload issues | `guide/HowTo-HotReload.md` |
| Migrate from Riverpod | `guide/MigratingFrom-Riverpod.md` |
| Migrate from Bloc | `guide/MigratingFrom-Bloc.md` |

## All guides

**State display and effects**

- `HowTo-CellBuilder.md` — the primary display widget; read-only views;
  rebuild granularity.
- `HowTo-CellListener.md` — side effects without rebuilds; mid-frame
  deferral; error pulses.
- `HowTo-CellScope.md` — app-level DI for global cells; `of` /
  `maybeOf` / `valueOf`.

**Async and derived**

- `HowTo-CellAsyncBuilder.md` — async sources as `AsyncSnapshot`;
  per-source error behavior.
- `HowTo-CellSelector.md` — rebuild only on the selected slice.
- `HowTo-DerivedCells.md` — bridging `Cell.derive` / `synthesis` /
  `switchMap` into widgets.
- `HowTo-Streams.md` — the `asStream` escape hatch.

**Hooks and debug**

- `HowTo-Hooks.md` — `useCell`, `useCellValue`, `useCellNotifier`,
  `useCellListener`, `useCellAsync`.
- `HowTo-HotReload.md` — where cells live across hot reload.
- `HowTo-Debugging.md` — the three debug diagnostics.

**Testing**

- `HowTo-Testing.md` — `pumpWithCells`, `emitAndSettle` (and its timer
  caveat), `recordPulses`, `CellTestHarness`, goldens.

**Migration**

- `MigratingFrom-Riverpod.md` — the primary adoption path, including
  what doesn't migrate.
- `MigratingFrom-Bloc.md` — the secondary adoption path.

## Examples

| Example | Shows |
|---|---|
| `example/lib/counter_app.dart` | The minimal `CellBuilder` counter |
| `example/lib/auth_flow.dart` | `CellScope` + `CellListener` +
  `CellBuilder` sign-in flow |
| `example/lib/async_search.dart` | `CellAsyncBuilder` over `asyncMap` |
| `example/lib/derived_cells.dart` | `CellBuilder` vs `CellValueBuilder` |
| `example/lib/hooks_counter.dart` | The hook equivalents |
| `example/lib/todo_with_auth.dart` | Everything together, with tests and
  an accessibility audit |

## What's not covered

- Replay verification tooling — that is `package:cell`'s surface, not the
  binding's.
- Devtools for the cell graph — out of scope for `cell_flutter`.
- Agentic runtime (`cell_mind`) — a separate track.

Honest boundaries, restated: the replay round-trip is verified for pure
state, debounce, throttle, `fromFuture`, and `fromStream` (commit
`05b4895d`); concurrent `asyncMap` attribution is tracked separately
; only `Cell.fromFuture` emits error pulses today.

## See also

- `package:cell` — the core framework (reactive primitives + replay).
- `cell_flow` — the orchestration/operator layer.
- `cell_tissue` — governed collections.
