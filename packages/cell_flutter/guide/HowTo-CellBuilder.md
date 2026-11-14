# HowTo-CellBuilder

`CellBuilder<V>` is the primary widget for displaying state from a Mitosis cell.

## When to use

- You have a `ValueCell<V>` (from `Cell.state`) and need a widget that
  displays its value.
- You want fine-grained rebuilds: one `CellBuilder` per widget that
  displays a distinct piece of state.

## When not to use

- The value is a side-effect trigger (navigation, snackbar, haptics).
  That's `CellListener` (Phase 2).
- The source is a derived `Cell` (from `Cell.derive`, `Cell.synthesis`,
  `Cell.switchMap`). That's `CellAsyncBuilder` or `asValueCell` (Phase 3).

## Basic usage

```dart
import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

class CounterApp extends StatefulWidget {
  const CounterApp({super.key});
  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  late final StateHandle<int> _counter = Cell.state<int>(initial: 0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CellBuilder<int>(
            cell: _counter.cell,
            builder: (_, value) => Text('${value ?? 0}'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _counter.update((_counter.cell.value ?? 0) + 1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

`CellBuilder` seeds its first build with `cell.value`, then rebuilds each
time the cell emits a value different from the previous one.

## Read-only views

Pass `cell.unmodifiable` to children. The child gets a `ValueCell` it
cannot mutate:

```dart
CellBuilder<int>(
  cell: _counter.cell.unmodifiable,
  builder: (context, value) => Text('$value'),
)
```

Any attempt to call `.value = ...` or `.apply(...)` on the deputy throws
`UnsupportedError` (for `.value`) or returns `ApplyRejected` (for `.apply`).

## Rebuild granularity

Each `CellBuilder` rebuilds independently. Use multiple builders for
independent subtree rebuilds:

```dart
Column(children: [
  CellBuilder<int>(cell: counter.cell, builder: ...),   // only this
  CellBuilder<String>(cell: status.cell, builder: ...), // and this
])
```

When `counter` updates, only the first rebuilds.

## Emit-during-build

**Do not** emit from `builder`:

```dart
CellBuilder<int>(
  cell: counter.cell,
  builder: (_, v) {
    counter.update(v! + 1);  // ❌ throws
    return Text('$v');
  },
)
```

Emit from an event handler (button, timer callback, etc.):

```dart
onPressed: () => counter.update((counter.cell.value ?? 0) + 1),
```

## Hot reload

Cells created in `build` are recreated on every build — an anti-pattern.
Create cells in `initState` or as top-level `final` fields. Cells created
outside `build` survive hot reload.

## What's coming

- **Phase 2:** `CellListener` (side effects with mid-frame deferral) and
  `CellScope` (app-level dependency injection via `InheritedWidget`).
- **Phase 3:** `CellAsyncBuilder` (renders `Cell.fromFuture`,
  `Cell.fromStream`, `Cell.asyncMap` outputs as `AsyncSnapshot`),
  `CellSelector` (rebuild on selected slice), `CellValueBuilder` (render
  any `Cell`), `asStream` and `asValueCell` extensions.
- **Phase 4:** `flutter_hooks` integration, hot-reload hardening, debug
  infrastructure.
- **Phase 5:** Testing utilities (`pumpWithCells`, `emitAndSettle`,
  `CellTestHarness`, `recordPulses`).
- **Phase 6:** Migration guides, `CHOOSING.md`, end-to-end examples,
  accessibility audit.

## See also

- `example/lib/counter_app.dart` — the runnable counter example.
- `package:cell` — the underlying reactive framework and its replay
  verification status.
