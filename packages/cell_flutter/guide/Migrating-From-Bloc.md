# Migrating from Bloc

## What this guide covers

Moving Bloc-based screens (Cubit, Bloc events/states, `BlocBuilder`)
to `cell_flutter`. Fixture-verified: `test/migration/bloc/` holds the
before/after pairs; `test/migration/migration_test.dart` asserts they
render identically.

## The mental model shift

| Bloc | cell_flutter |
|---|---|
| `Cubit<V>` | `Cell.state<V>` handle |
| `Bloc<Event, State>` + `add(event)` | `Cell.ingress<V>` for the event stream + `Cell.state` for the state |
| `BlocBuilder<B, S>` | `CellBuilder<S>` |
| `BlocListener` | `CellListener` |
| `BlocSelector` | `CellSelector` |
| `bloc_test` | `recordPulses` + `pumpWithCells` (assert pulse sequences) |

The big shift: Bloc enforces an event/state boundary with classes;
cell_flutter keeps the boundary but makes it data-shaped — an ingress
cell receives events, state cells hold state, and a switch/listener
glues them.

## A worked migration

**Before** — `test/migration/bloc/before_counter.dart`:

```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}
BlocProvider(
  create: (_) => CounterCubit(),
  child: ... BlocBuilder<CounterCubit, int>(
    builder: (context, count) => TextButton(
      onPressed: () => context.read<CounterCubit>().increment(),
      child: Text('count: $count'),
    ),
  ),
)
```

**After** — `test/migration/bloc/after_counter.dart`:

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

For real event/state Blocs, split the event stream from the state:

```dart
final events = Cell.ingress<LoginEvent>();
final state = Cell.state<LoginState>(initial: const LoginState());
// Subscribe once (e.g. in initState) and translate events to state
// transitions, mirroring the Bloc's mapEventToState.
```

## What you can keep

- **One event class per user action** — ingress cells carry the same
  events; the event types survive unchanged.
- **`BlocBuilder` → `CellBuilder`** when the state is a `ValueCell`.
- **`BlocListener` → `CellListener`** for navigation/snackbar side
  effects.
- **`bloc_test`'s sequence assertions** → `recordPulses` sequences are
  strictly more precise (payloads, types, order).

## What you must replace

- **The `Bloc` class itself.** There is no event/state dispatcher to
  subclass; the reducer becomes a listener/switch on the ingress cell
  writing `Cell.state` handles.
- **`BlocProvider`** — no inherited lookup; pass cells to widgets.
- **`emit`** — `handle.update(...)` is the emit.

## Migration checklist

- [ ] Turn each `Cubit` into a `Cell.state` handle.
- [ ] Turn each `Bloc`'s events into a `Cell.ingress` + a state cell +
  a subscriber that reduces events.
- [ ] Replace `BlocBuilder` with `CellBuilder`, `BlocListener` with
  `CellListener`, `BlocSelector` with `CellSelector`.
- [ ] Run the fixture pair test for the migrated screen type.
- [ ] Delete the `BlocProvider` wiring and the bloc classes.

## What comes next

- [Migrating from Riverpod](Migrating-From-Riverpod.md) — the provider
  view of the same mapping.
- [Migrating from setState](Migrating-From-SetState.md) — the smallest
  first step.
- `ARCHITECTURE-flutter.md` — the deeper story.
