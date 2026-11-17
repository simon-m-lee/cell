# Migrating From Riverpod

The primary adoption path from Riverpod 3.x to Mitosis (`cell_flutter`
0.5.0). This guide is honest: some things don't migrate, and it says so.

## 1. Before you start

- Read `doc/CHOOSING.md` first. If the answer is "stay on Riverpod",
  that is a good outcome.
- Read this entire guide before migrating anything; several steps have
  prerequisites.
- Time estimate: 2–4 hours for a small app, 1–2 days for a medium one.
- Vocabulary disclaimer: pulses, nuclei, and synapses map to concepts
  you know, but the mapping is not 1:1. A pulse is not an event; a
  nucleus is not a provider.

## 2. Concept mapping

| Riverpod 3 | Mitosis | Mapping |
|---|---|---|
| `Provider<T>` | Direct `Cell` reference (constructor arg) | No DI container; cells are explicit |
| `ProviderScope` | `CellScope` | Only for app-level singletons |
| `ref.watch(p)` | `CellBuilder(cell: c)` | Fine-grained via `CellSelector` |
| `ref.read(p)` | `cell.value` | Direct read |
| `ref.listen(p, cb)` | `CellListener(cell: c, onPulse: cb)` | Mid-frame deferral built in |
| `StateProvider` | `Cell.state<T>()` | `ValueCell` is the primitive |
| `StateNotifierProvider` | `Cell.state<T>()` with `testRule` | No notifier class |
| `FutureProvider` | `Cell.fromFuture` | — |
| `StreamProvider` | `Cell.fromStream` | — |
| `AsyncNotifierProvider` | `Cell.state` + `Cell.asyncMap` | Compose |
| `AsyncValue<T>` | `AsyncSnapshot<T>` | Reuses Flutter's type |
| `Notifier<T>` (3.x) | `ValueCell<T>` | Direct |
| `.family` | Direct cell factories + `Cell.switchMap` | No `.family` primitive |
| `autoDispose` | `Cell.governed(ephemeralPolicy: ...)` | Explicit TTL |
| `ref.invalidate(p)` | `EphemeralPolicy` invalidation | Different semantics — a `Cell` is only invalidated through its policy |
| `ProviderContainer` (testing) | `pumpWithCells` | No separate container |
| `overrideWithValue` (testing) | `pumpWithCells(cells: {...})` | Map-based |
| `ConsumerWidget` / `ConsumerStatefulWidget` | `HookWidget` / `StatefulWidget` | No special widget base class |
| `WidgetRef` | `BuildContext` (via `CellScope.of`) | Simpler |
| `ref.watch(p.select(...))` | `CellSelector(cell: c, select: ...)` | Selector is a widget |
| `Listenable` bridges | `Cell.asStream()` | For interop |

## 3. Step 1: State primitives

**Before** (Riverpod 3.x):

<!-- skip-extraction -->
```dart
final counterProvider = StateProvider<int>((ref) => 0);

class Counter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

**After** (Mitosis):

```dart
final counter = Cell.state<int>(initial: 0);

// Riverpod: ref.watch(counterProvider) inside a ConsumerWidget.
// Mitosis: the builder is the widget body.
CellBuilder<int>(
  cell: counter.cell.unmodifiable,
  builder: (_, count) => Text('${count ?? 0}'),
)
```

Key difference: Mitosis is not override-based. Tests build a fresh cell
in `setUp` and register it with `pumpWithCells` — there is no runtime
override hierarchy.

## 4. Step 2: Derived state

**Before** (Riverpod 3.x):

<!-- skip-extraction -->
```dart
final doubledProvider = Provider<int>((ref) {
  final value = ref.watch(baseProvider);
  return value * 2;
});
```

**After** (Mitosis):

```dart
final base = Cell.state<int>(initial: 1);
final doubled = Cell.derive<Pulse<int>, Pulse<int>>(
  source: base.cell,
  project: (p) => Pulse<int>((p.payload ?? 0) * 2),
);
```

**The key gotcha:** derived cells return `Cell`, not `ValueCell`, and they
do not replay the source's current value — a `Cell.derive` only projects
pulses emitted after it was created. `CellBuilder` needs a `ValueCell`;
the bridge is `CellValueBuilder` (give it `initial:` for the pre-first-
pulse frame):

```dart
final base = Cell.state<int>(initial: 1);
final doubled = Cell.derive<Pulse<int>, Pulse<int>>(
  source: base.cell,
  project: (p) => Pulse<int>((p.payload ?? 0) * 2),
);

// Riverpod: ref.watch(sumProvider) inside ConsumerWidget
// Mitosis: CellValueBuilder over the derived cell
CellValueBuilder<int>(
  cell: doubled, // Cell, not ValueCell
  initial: 2,
  builder: (_, total) => Text('$total'),
)
```

For multiple sources, `Cell.synthesis`:

```dart
final a = Cell.state<int>(initial: 1);
final b = Cell.state<int>(initial: 2);
final sum = Cell.synthesis<Pulse<int>>(
  [a.cell, b.cell],
  aggregator: (cells, _) => Pulse<int>(
    cells.fold<int>(
        0, (acc, c) => acc + (((c as ValueCell<int>).value) ?? 0)),
  ),
);
```

## 5. Step 3: Async

**Before** (Riverpod 3.x):

<!-- skip-extraction -->
```dart
final userProvider = FutureProvider<User>((ref) => api.fetchUser());
final streamProvider = StreamProvider<Tick>((ref) => api.ticks());
```

**After** (Mitosis):

```dart
// In your app these come from your API layer, e.g. api.fetchUser().
final user = Cell.fromFuture<String>(
    Future.value('ada'), journal: RecordingJournal());
final ticks = Cell.fromStream<int>(
    Stream.value(1), journal: RecordingJournal());
```

The `journal:` argument is required by the in-repo `cell` core's replay
round-trip (commit `05b4895d`); the published `cell` 1.1.x API does not
have it.

`AsyncValue` becomes `AsyncSnapshot` via `CellAsyncBuilder`:

```dart
final user = Cell.fromFuture<String>(
    Future.value('ada'), journal: RecordingJournal());

CellAsyncBuilder<String>(
  cell: user,
  builder: (_, snapshot) => snapshot.hasError
      ? Text('error: ${snapshot.error}')
      : snapshot.hasData
          ? Text('user: ${snapshot.data}')
          : const Text('loading...'),
)
```

**The per-source error table — read this before migrating async code:**

| Source | Emits error pulse | What the widget shows on failure |
|---|---|---|
| `Cell.fromFuture` | Yes (`type: 'error'`) | `hasError == true` |
| `Cell.fromStream` | No | Last successful value (or `nothing`) |
| `Cell.asyncMap` | No | Last successful value (or `nothing`) |

Riverpod's `AsyncValue` always surfaces errors. In Mitosis, a
`CellAsyncBuilder` over an `asyncMap` source will **not** show an error
when the mapper throws — it shows the last successful value. Bridge
failures through a `Cell.fromFuture` that re-emits them, or return a
sealed result type from the mapper.

**`retry`:** Mitosis has no built-in retry. Compose with
`Cell.asyncMap` and a manual state machine, or wait for `cell_flow`.
**Honest gap.**

## 6. Step 4: Widgets

- `ConsumerWidget` → `HookWidget` (if using hooks) or `StatefulWidget`
  (if not). There is no special base class.
- `ref.watch` → `CellBuilder` or `CellSelector`.
- `ref.read` → direct `cell.value` access.
- `ref.listen` → `CellListener`. Error pulses must branch on
  `pulse.type == 'error'`:

```dart
final auth = Cell.state<String?>(initial: null);

CellListener<String?>(
  cell: auth.cell,
  onPulse: (context, pulse) {
    if (pulse.type == 'error') {
      // Your error surface, e.g. showErrorDialog(context, pulse.payload).
      return;
    }
    // ...side effect
  },
  child: const SizedBox.shrink(),
)
```

**Before** (Riverpod 3.x):

<!-- skip-extraction -->
```dart
ref.listen(userProvider, (previous, next) {
  next.whenOrNull(data: (u) => showToast('Loaded ${u.name}'));
});
```

## 7. Step 5: DI

- `ProviderScope` → `CellScope` at the app root.
- `ProviderScope(overrides: ...)` → `pumpWithCells(cells: {...})` for
  tests; there are **no runtime overrides**.

```dart
final auth = Cell.state<String?>(initial: null);

CellScope(
  cells: {#auth: auth.cell},
  child: const MaterialApp(home: SizedBox.shrink()),
)

// Deep in the tree, from a BuildContext:
// final authCell = CellScope.valueOf<String?>(context, #auth);
```

**Honest gap:** Riverpod's override mechanism is more flexible;
Mitosis's is test-only.

## 8. Step 6: Testing

- `ProviderContainer` → no equivalent; use `pumpWithCells`.
- `overrideWithValue` → `pumpWithCells(cells: {...})`.
- `ProviderContainer.test()` → direct `Cell` construction in `setUp`.

```dart
testWidgets('counter renders', (tester) async {
  final counter = Cell.state<int>(initial: 42);
  await tester.pumpWithCells(
    cells: {#counter: counter.cell},
    child: CellBuilder<int>(
      cell: counter.cell,
      builder: (_, v) => Text('$v'),
    ),
  );
  expect(find.text('42'), findsOneWidget);
});
```

**`emitAndSettle` timer caveat:** if the async receptor resolves on a
timer (e.g. `Future.delayed`), `emitAndSettle` does not wait. Use
`emitAndPump(duration:)` (see `HowTo-Testing.md` §5).

**Honest gap:** Riverpod's test infrastructure is richer for DI-heavy
apps.

## 9. What doesn't migrate

- **`ref` DI.** Mitosis has no equivalent; use constructor-arg passing
  or `CellScope`.
- **`overrideWithValue` at runtime.** `CellScope` is static per widget
  tree; use `pumpWithCells` for tests only.
- **`.family`.** Emulate with `Cell.switchMap` or direct factory
  functions.
- **`autoDispose` combinations.** `EphemeralPolicy` is coarser-grained;
  some combinations require manual lifecycle handling.
- **`Listenable` bridging.** `asStream()` covers the common case;
  direct `Listenable` bridging is manual.
- **`Notifier` mutation interception.** `testRule` can intercept state
  changes, but it does not have the same lifecycle hooks.
- **Async error visibility from `asyncMap` and `fromStream`.**
  Riverpod's `AsyncValue` always surfaces errors; Mitosis's `asyncMap`
  and `fromStream` do not emit error pulses today. This is a real
  behavior difference; bridge if you need it.

## 10. Incremental migration

Run Riverpod and Mitosis side by side. The smallest integration is one
`Cell.state` + one `CellBuilder` in one feature (see the recipe in
`doc/CHOOSING.md`). Two boundary choices:

- **Boundary at the widget:** a Mitosis-managed subtree inside a
  Riverpod screen.
- **Boundary at the service layer:** cells replace providers in one
  service; widgets keep using Riverpod until the service is stable.

Remove Riverpod only after the migrated feature has been stable in
production.

## 11. Migration checklist

- [ ] Read `doc/CHOOSING.md`; confirmed Mitosis is right for this project.
- [ ] Read this entire guide.
- [ ] Set up `CellScope` at the app root.
- [ ] Migrate one `StateProvider` to `Cell.state` as a pilot.
- [ ] Add `testRule` to the migrated cell (if validation is needed).
- [ ] Run the pilot test suite.
- [ ] Verify async sources' error behavior in the pilot —
  `asyncMap`/`fromStream` do not emit error pulses.
- [ ] Migrate the rest incrementally.
- [ ] Remove Riverpod only after the pilot is stable.

## 12. See also

- `doc/CHOOSING.md` — should you migrate at all.
- `guide/MigratingFrom-Bloc.md` — the Bloc path.
- `doc/INDEX.md` — all guides.
- `package:cell` — the core framework.
