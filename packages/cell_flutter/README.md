# cell_flutter

Flutter widget bindings for [Mitosis](https://pub.dev/packages/cell) cells.

> **Status: 0.6.0 (hardening).** Live state display, effects, hooks, and
> testing utilities are production-grade. The Phase 7 1.0 gate was
> evaluated on 2026-11-13 and did **not** pass — see
> `reports/GATE_1.0.md` for the per-gate verdicts; this release carries
> the hardening tooling and reports. The underlying `cell` framework's
> replay round-trip is **verified for the pure state, debounce, throttle,
> `fromFuture`, and `fromStream` probes** (commit `05b4895d`; full suite
> 1371 tests, determinism gate 240/240). Concurrent `asyncMap` effect
> attribution under `concurrency > 0` is tracked separately (Gate G1.5).
> Only `Cell.fromFuture` emits error pulses today; `fromStream` and
> `asyncMap` do not. See the `cell` core package for status.

Phase 3's async widgets inherit the framework's Gate G1.5 caveat when
observing `asyncMap` sources with `concurrency > 0`; see the dartdoc for
details. The `useCellAsync` hook inherits Phase 3's per-source error
behavior and Gate G1.5 caveat; see `HowTo-Hooks.md` §6.

## What's in `cell_flutter`

| Version | What's in it |
|---|---|
| 0.1.0 | `CellNotifier`, `CellBuilder` |
| 0.2.0 | `CellListener`, `CellScope` |
| 0.3.0 | `CellAsyncBuilder`, `CellSelector`, `CellValueBuilder`, `asStream`, `asValueCell` |
| 0.4.0 | Hooks, hot-reload warnings, debug diagnostics |
| 0.5.0 | Testing utilities (`pumpWithCells`, `emitAndSettle`, `CellTestHarness`, `recordPulses`) |

## The 30-line counter

```dart
import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CounterApp());

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
        appBar: AppBar(title: const Text('Counter')),
        body: Center(
          child: CellBuilder<int>(
            cell: _counter.cell.unmodifiable,
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

See `guide/HowTo-CellBuilder.md` for the full guide. The
`example/lib/auth_flow.dart` example demonstrates `CellListener` and
`CellScope` together; see `guide/HowTo-CellListener.md` and
`guide/HowTo-CellScope.md`.

## What's not in `cell_flutter`

- No devtools for the cell graph.
- No Flutter binding for non-`ValueCell` derived cells except via
  `CellValueBuilder` (a widget, not a primitive).
- Concurrent `asyncMap` effect attribution (Gate G1.5) is tracked
  separately.
- `fromStream` and `asyncMap` do not emit error pulses today — only
  `Cell.fromFuture` does.

## Quick links

- Decision: `doc/CHOOSING.md`
- Map: `doc/INDEX.md`
- Migration: `guide/MigratingFrom-Riverpod.md`,
  `guide/MigratingFrom-Bloc.md`
- Guides: `guide/HowTo-CellBuilder.md`, `guide/HowTo-CellListener.md`,
  `guide/HowTo-CellScope.md`, `guide/HowTo-CellAsyncBuilder.md`,
  `guide/HowTo-CellSelector.md`, `guide/HowTo-DerivedCells.md`,
  `guide/HowTo-Streams.md`, `guide/HowTo-Hooks.md`,
  `guide/HowTo-HotReload.md`, `guide/HowTo-Debugging.md`,
  `guide/HowTo-Testing.md`
- Examples: `example/lib/` — counter, auth flow, async search, derived
  cells, hooks counter, and the end-to-end `todo_with_auth.dart`.

## Testing

`cell_flutter` ships testing utilities. Keep `cell_flutter` in your
`dev_dependencies` (it declares `flutter_test` as a regular dependency,
following the `bloc_test` / `mocktail` pattern):

```yaml
dev_dependencies:
  cell_flutter: ^0.5.0
```

Then import `package:cell_flutter/testing.dart` in your tests:

```dart
import 'package:cell_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';

testWidgets('counter increments', (tester) async {
  final counter = Cell.state<int>(initial: 0);
  await tester.pumpCell(
    cell: counter.cell,
    builder: (_, v) => Text('$v'),
  );
  await tester.emitAndSettle(counter.cell, 5);
  expect(find.text('5'), findsOneWidget);
});
```

See `guide/HowTo-Testing.md` for the full reference, including the
`emitAndSettle` timer caveat and the `recordPulses` / `CellTestHarness`
patterns.

## Choosing Mitosis

Mitosis is not the fastest way to ship ordinary app state in 2026 —
Riverpod or Bloc is. It is the right choice when you need a recorded,
replayable, least-privilege shared graph. Read `doc/CHOOSING.md` for
the honest comparison before migrating.

## Verified on

- Windows (this development machine) — `flutter test` green, 100%
  coverage on `lib/src/*`, `flutter analyze` clean, `pub publish
  --dry-run` clean.
- Chrome (web) — `flutter test --platform chrome` was attempted; the run
  hung in this environment's browser harness and is pending a clean
  rerun on a standard CI machine.
- macOS / iOS — required by the phase plan; pending a macOS build host
  (the golden test generates its reference images there).

## Links

- Underlying framework: [cell](https://pub.dev/packages/cell)
- License: MIT or Apache-2.0 (see `LICENSE`)
