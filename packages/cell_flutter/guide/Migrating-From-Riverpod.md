# Migrating from Riverpod

## What this guide covers

Moving Riverpod-based screens (providers, `ref.watch`, `AsyncValue`)
to `cell_flutter`. Fixture-verified: `test/migration/riverpod/` holds
the before/after pairs; `test/migration/migration_test.dart` asserts
they render identically.

> **Riverpod version note.** The fixtures are written against
> riverpod 3.x: `StateProvider` was removed upstream, so the guide's
> "before" code uses `Notifier` / `NotifierProvider` — the direct
> successor of the riverpod 2.x `StateProvider` the original plan
> named.

## The mental model shift

| Riverpod | cell_flutter |
|---|---|
| `NotifierProvider<T, V>` | `Cell.state<V>` handle |
| `ref.watch(provider)` | `CellBuilder<V>(cell:)` |
| `ref.listen` | `CellListener` |
| `AsyncNotifier` / `AsyncValue` | `fromFuture` / `fromStream` + `CellAsyncBuilder` (`AsyncSnapshot`) |
| `family` providers | `Map<Object, ValueCell>` or `Cell.switchMap` |
| `autoDispose` | no equivalent — cells live with their owner |
| `ProviderScope(overrides:)` | no overrides — construct cells in tests directly |

The big shift: Riverpod's providers are globally-visible reactive nodes
resolved through `ref`; cell_flutter's cells are ordinary objects you
pass around — the graph exists, but there is no container to query.

## A worked migration

**Before** — `test/migration/riverpod/before_counter.dart`:

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}
final counterProvider =
    NotifierProvider<CounterNotifier, int>(CounterNotifier.new);
// ... ConsumerWidget:
final count = ref.watch(counterProvider);
TextButton(
  onPressed: () => ref.read(counterProvider.notifier).increment(),
  child: Text('count: $count'),
)
```

**After** — `test/migration/riverpod/after_counter.dart`:

```dart
final counter = Cell.state<int>(initial: 0);
CellBuilder<int>(
  cell: counter.cell,
  builder: (context, value) => TextButton(
    onPressed: () => counter.update((value ?? 0) + 1),
    child: Text('count: ${value ?? 0}'),
  ),
)
```

## What you can keep

- `AsyncValue` → `AsyncSnapshot` is one-to-one in the UI when the
  source is a `fromFuture`/`fromStream` cell rendered with
  `CellAsyncBuilder` (`waiting` / `data` / `error` all map directly).
- `ref.listen` → `CellListener` keeps the "side effect per change"
  pattern.
- `Provider<T>` computed values → a cell recomputed from its sources
  (single-source: `CellSelector`; multi-source: computed cell, see the
  login fixture pair).

## What you must replace

- **`family` providers** have no direct equivalent. Use a
  `Map<Object, ValueCell>` cache owned by a `State`/`CellScope`, or
  route per-item events through `Cell.switchMap`.
- **`autoDispose`** — cells are disposed by their owner; move the
  lifecycle into the owning `State.dispose` when needed.
- **`ProviderScope(overrides:)`** — inject cells as constructor
  parameters; tests build fresh cells instead of overriding.
- **`ref.watch` inside non-widget code** — subscribe with `Cell.observe`
  (and release the egress handle).

## Migration checklist

- [ ] Replace each provider declaration with a `Cell.state`/`fromFuture`/`fromStream`.
- [ ] Replace `ref.watch` with `CellBuilder` / `CellAsyncBuilder`.
- [ ] Replace `ref.listen` with `CellListener`.
- [ ] Replace families with a cell cache keyed by parameter.
- [ ] Run the fixture pair test for the migrated screen type.
- [ ] Delete `ProviderScope` and the provider declarations.

## What comes next

- [Migrating from Provider](Migrating-From-Provider.md) — the container
  view of the same mapping.
- [Migrating from Bloc](Migrating-From-Bloc.md) — events to cells.
- `ARCHITECTURE-flutter.md` — the deeper story.
