# Migrating From Bloc

The secondary adoption path from Bloc 8.x (including `flutter_bloc`) to
Mitosis (`cell_flutter` 0.5.0). Honest about what doesn't migrate.

## 1. Before you start

- Read `doc/CHOOSING.md` first.
- Read this entire guide before migrating anything.
- Vocabulary disclaimer: Mitosis flattens Bloc's event/state pair into
  one graph of cells; the mapping is not 1:1.

## 2. Concept mapping

| Bloc | Mitosis | Mapping |
|---|---|---|
| `Cubit<State>` | `ValueCell<State>` (via `Cell.state`) | Cubit is Bloc without events; `Cell` is without events |
| `Bloc<Event, State>` | `Cell.state<State>` + `Cell.ingress` | Events are optional in Mitosis |
| `emit(newState)` | `stateHandle.update(newState)` | Direct |
| `add(event)` | `ingress.emit(event)` | Events are pulses, not typed |
| `on<Event>(handler)` | `Cell.ingress(refine: ...)` | No event registry; one refine function |
| `BlocBuilder` | `CellBuilder` | — |
| `BlocListener` | `CellListener` | Mid-frame deferral built in |
| `BlocConsumer` | Compose `CellBuilder` + `CellListener` | Two widgets |
| `BlocProvider` | `CellScope` | Only for app-level |
| `RepositoryProvider` | `CellScope` or constructor arg | — |
| `MultiBlocListener` | Nested `CellListener` | No multi-listener primitive |
| `blocTest` | `pumpWithCells` + `recordPulses` | Different shape |
| `expectStates` | `expect(recorder.payloads, ...)` | — |
| `HydratedBloc` | Compose with persistence layer | Out of scope |
| `freezed` states | `sealed class` + `switch` | Dart 3 idiom |

## 3. Step 1: Cubit → Cell.state

The simplest case.

**Before** (Bloc 8.x):

<!-- skip-extraction -->
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}
// UI: BlocBuilder<CounterCubit, int>(builder: (context, count) => Text('$count'))
```

**After** (Mitosis):

```dart
final counter = Cell.state<int>(initial: 0);
void increment() => counter.update((counter.cell.value ?? 0) + 1);
```

`emit` → `update`; `BlocBuilder` → `CellBuilder`:

```dart
final counter = Cell.state<int>(initial: 0);
void increment() => counter.update((counter.cell.value ?? 0) + 1);

CellBuilder<int>(
  cell: counter.cell.unmodifiable,
  builder: (_, count) => Text('${count ?? 0}'),
)
```

## 4. Step 2: Bloc → Cell.state + ingress

`Bloc<Event, State>` has two concepts: events and states. Mitosis
flattens: one `Cell.state` + one `Cell.ingress`.

**Before** (Bloc 8.x):

<!-- skip-extraction -->
```dart
class TodoBloc extends Bloc<TodoEvent, List<Todo>> {
  TodoBloc() : super(const []) {
    on<AddTodo>((event, emit) {
      if (event.title.trim().isEmpty) return;
      emit([...state, Todo(event.title)]);
    });
  }
}
```

**After** (Mitosis):

```dart
class Todo {
  Todo(this.title);
  final String title;
}

final todos = Cell.state<List<Todo>>(
  initial: const [],
  testRule: TestCell((object, {host, arguments, user}) {
    // A custom rule gates every validation kind — links and actions
    // must pass through, only state pulses are checked.
    if (object is! Pulse) return true;
    final payload = object.payload;
    return payload is List<Todo> &&
        payload.every((t) => t.title.trim().isNotEmpty);
  }),
);
final todoEvents = Cell.ingress<Todo>(
  refine: (host, input) {
    final title = input.payload?.title.trim() ?? '';
    if (title.isEmpty) return null; // silently drop empty titles
    return Pulse<Todo>(Todo(title), type: 'todo.add');
  },
);

// Wire the ingress into the state cell (one-time, app init):
Cell.observe<Pulse<Todo>>(
  source: todoEvents.cell,
  effect: (p) {
    if (p.payload == null) return;
    todos.update([...?todos.cell.value, p.payload!]);
  },
);
```

**Honest gap:** Mitosis has no typed event registry; events are pulses
with optional `type` tags. Validation moves into `testRule` (states) and
`refine` (events).

**Live-API caveat (cell 2.0.0):** a state cell with a custom `testRule`
commits updates but does **not** fan the pulse out to downstream
`Cell.derive` links (`update`, `updateAsync`, and `ingest` all behave
this way). If you derive cells from a state cell, put the validation in
the ingress `refine` hook instead — the derive-compatible path. The
`todo_with_auth` example shows both patterns side by side.

## 5. Step 3: Widgets

- `BlocBuilder` → `CellBuilder`.
- `BlocListener` → `CellListener` (branch on `pulse.type == 'error'`).
- `BlocConsumer` → compose both widgets.
- `BlocProvider`/`RepositoryProvider` → `CellScope` or constructor args.

The per-source error table for async Bloc sources that migrate to
`asyncMap` / `fromStream`:

| Source | Emits error pulse |
|---|---|
| `Cell.fromFuture` | Yes (`type: 'error'`) |
| `Cell.fromStream` | No |
| `Cell.asyncMap` | No |

A failed `asyncMap` mapper shows the last successful value in
`CellAsyncBuilder` — not an error snapshot. Bridge through
`Cell.fromFuture` if the UI must show failures.

## 6. Step 4: DI

- `BlocProvider` → `CellScope` at the app root.
- `RepositoryProvider` → constructor args or `CellScope`.

```dart
final todos = Cell.state<List<Todo>>(initial: const []);

CellScope(
  cells: {#todos: todos.cell},
  child: const MaterialApp(home: SizedBox.shrink()),
)
```

## 7. Step 5: Testing

**Before** (Bloc 8.x):

<!-- skip-extraction -->
```dart
blocTest<CounterCubit, int>(
  'emits [1] when increment is called',
  build: () => CounterCubit(),
  act: (cubit) => cubit.increment(),
  expect: () => [1],
);
```

**After** (Mitosis):

```dart
test('increment updates the cell', () {
  final counter = Cell.state<int>(initial: 0);
  final recorder = counter.cell.recordPulses();
  addTearDown(recorder.stop);

  counter.update((counter.cell.value ?? 0) + 1);

  expect(recorder.payloads, [1]);
});
```

`blocTest` is more declarative; Mitosis's is more imperative. Honest
comparison: `blocTest`'s `wait` maps to `tester.pumpAndSettle`, and its
`verify` (side effects) requires `CellListener` + a spy. **`emitAndSettle`
does not wait for timer-resolving receptors**; use
`emitAndPump(duration:)` (see `HowTo-Testing.md` §5).

## 8. Step 6: Hydration

`HydratedBloc` is out of scope for `cell_flutter`. Compose with a
persistence layer, or a minimal load-on-init pattern:

```dart
class Todo {
  Todo(this.title);
  final String title;
}

final stored = Cell.state<List<Todo>>(initial: const []);
// saveToDisk(...) is your persistence layer.
Cell.observe<Pulse<List<Todo>>>(
  source: stored.cell,
  effect: (_) {
    // saveToDisk(stored.cell.value ?? const []);
  },
);
```

**Honest gap:** no built-in hydration.

## 9. What doesn't migrate

- **Typed events.** Mitosis's pulses have a dynamic `type` field; they
  are not compile-time-checked. Use `testRule` or `refine` for runtime
  checking.
- **`on<Event>` registry.** No equivalent; every event flows through one
  `refine` function.
- **`blocTest`'s declarative shape.** Mitosis's is more imperative.
- **`HydratedBloc`.** Out of scope.
- **`bloc_concurrency` transformers.** Not built in; compose with
  `concurrency` on `Cell.asyncMap` or a manual state machine.
- **Async error visibility from `asyncMap` and `fromStream`.** Same as
  the Riverpod guide's note — only `Cell.fromFuture` emits error pulses
  today.

## 10. Incremental migration

Same as Riverpod: run Bloc and Mitosis side by side, with the boundary
at the widget or at the service layer. Remove `flutter_bloc` only after
the migrated feature is stable in production.

## 11. Migration checklist

- [ ] Read `doc/CHOOSING.md`; confirmed Mitosis is right for this project.
- [ ] Read this entire guide.
- [ ] Migrate one `Cubit` to `Cell.state` as a pilot.
- [ ] Migrate one `Bloc` to `Cell.state` + `Cell.ingress` if events are
      needed.
- [ ] Run the pilot test suite with `recordPulses`.
- [ ] Verify async sources' error behavior — `asyncMap`/`fromStream` do
      not emit error pulses.
- [ ] Remove Bloc only after the pilot is stable.

## 12. See also

- `doc/CHOOSING.md` — should you migrate at all.
- `guide/MigratingFrom-Riverpod.md` — the Riverpod path.
- `doc/INDEX.md` — all guides.
- `package:cell` — the core framework.
