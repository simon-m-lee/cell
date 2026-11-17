# Migrating from Provider

## What this guide covers

Moving one Provider-based screen (state container, consumers, selectors)
to `cell_flutter`, with fixture-verified code. The accuracy contract:
`test/migration/provider/` contains the before/after pairs below, and
`test/migration/migration_test.dart` asserts they render identically.

## The mental model shift

| Provider | cell_flutter |
|---|---|
| `ChangeNotifier` subclass | `Cell.state<V>` handle (`cell`, `update`) |
| `ChangeNotifierProvider(create:)` | plain Dart field — no provider tree |
| `Consumer<T>` | `CellBuilder<V>` |
| `Selector<T, S>` | `CellSelector<V, S>` |
| `context.read<T>().method()` | `handle.update(...)` / `handle.cell.value = ...` |
| `notifyListeners()` | nothing — writes emit pulses automatically |

The big shift: Provider's unit is the *container you write*; cell_flutter's
unit is the *cell*. The `ChangeNotifier` class disappears and its fields
become `Cell.state` handles.

## A worked migration

**Before** — `test/migration/provider/before_counter.dart`:

```dart
class Counter extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() { _count++; notifyListeners(); }
}

ChangeNotifierProvider(
  create: (_) => Counter(),
  child: ... Consumer<Counter>(
    builder: (context, counter, child) => TextButton(
      onPressed: counter.increment,
      child: Text('count: ${counter.count}'),
    ),
  ),
)
```

**After** — `test/migration/provider/after_counter.dart`:

```dart
final counter = Cell.state<int>(initial: 0);
...
CellBuilder<int>(
  cell: counter.cell,
  builder: (context, value) => TextButton(
    onPressed: () => counter.update((value ?? 0) + 1),
    child: Text('count: ${value ?? 0}'),
  ),
)
```

Forms migrate to `CellTextField` (see `guide/HowTo-Forms.md`); lists to
`CellListView` (see the todo fixture pair). Values derived from *several*
fields use a computed cell fed by `onChanged` — see the login fixture
pair, which is the pattern `CellSelector` cannot cover (one source cell
only).

## What you can keep

- `Consumer` → `CellBuilder` is a mechanical one-to-one swap for
  single-value rebuilds.
- `Selector` → `CellSelector` keeps the rebuild-slicing discipline
  (pass `equals` for collection slices).
- `ProxyProvider`-style composition becomes cells that read other cells
  (`Cell.derive` for pulse projections, computed cells for multi-source
  values).
- Your widget tree, theme, and navigation stay exactly as they are.

## What you must replace

- **The provider tree.** `MultiProvider` setup code is deleted; cells are
  plain fields on the owning `State` (or top-level finals).
- **`context.read/watcher`.** Write access becomes `update`/`cell.value`;
  reads inside builders are the builder's `value` parameter.
- **`notifyListeners` bookkeeping.** There is none.
- **Manual disposal rules.** `Cell.state` handles need no dispose; only
  `asValueCell`/`recordPulses` links do (see the lint rules).

## Migration checklist

- [ ] Replace each `ChangeNotifier` field with a `Cell.state` handle.
- [ ] Replace each `Consumer<T>` with `CellBuilder<T>`.
- [ ] Replace `Selector` with `CellSelector` (keep `equals` semantics).
- [ ] Run the fixture pair test for the migrated screen type.
- [ ] Delete `MultiProvider`/`ChangeNotifierProvider` wiring.
- [ ] Delete the now-unused `ChangeNotifier` classes.

## What comes next

- [Migrating from Riverpod](Migrating-From-Riverpod.md) — providers to
  cells, `AsyncValue` to `AsyncSnapshot`.
- [Migrating from setState](Migrating-From-SetState.md) — the smallest
  first step.
- `ARCHITECTURE-flutter.md` — why the pieces are shaped this way.
