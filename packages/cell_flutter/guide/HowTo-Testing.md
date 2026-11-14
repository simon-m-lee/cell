# HowTo-Testing

`package:cell_flutter/testing.dart` provides `WidgetTester` extensions,
a pulse recorder, and a test harness for cell-driven widget tests.

## The `flutter_test` requirement

`testing.dart` imports `flutter_test`. `cell_flutter` declares it as a
regular dependency (the `bloc_test` / `mocktail` / `mockito` pattern), so
it resolves automatically — just keep `cell_flutter` in your
`dev_dependencies` and nothing test-related reaches release builds:

```yaml
dev_dependencies:
  cell_flutter: ^0.4.0
```

## Extension cheatsheet

| Extension | What it does |
|---|---|
| `pumpWithCells` | Pumps a widget with cells registered in a `CellScope` |
| `pumpCell` | Pumps a bare `CellBuilder` in `MaterialApp + Scaffold` |
| `emitAndSettle` | Sets a cell's value, then `pumpAndSettle` |
| `emitAndPump` | Sets a cell's value, pumps one frame (or a duration) |
| `expectCellValue` | `expect(cell.value, matcher)` with a cell-naming reason |
| `expectCellGolden` | Golden snapshot of a `CellBuilder` |
| `recordPulses` | Records every pulse from any `Cell` |

## `pumpWithCells`

```dart
await tester.pumpWithCells(
  cells: {#counter: counter.cell},
  child: CellBuilder<int>(
    cell: counter.cell,
    builder: (_, v) => Text('$v'),
  ),
);
```

The default wrapper is `MaterialApp(home: Scaffold(body: child))`.
Override with `wrapper:` for a `Navigator` key, theme, or custom frame.

## `pumpCell`

The single-cell case:

```dart
await tester.pumpCell(
  cell: counter.cell,
  builder: (_, v) => Text('$v'),
);
```

No `CellScope` is installed — use `pumpWithCells` when the child looks
cells up.

## `emitAndSettle` and the timer caveat

```dart
await tester.emitAndSettle(counter.cell, 5);
expect(find.text('5'), findsOneWidget);
```

Sync receptors and microtask-resolving async receptors settle fine.
**`pumpAndSettle` does not wait for timer-resolving receptors**
(e.g. `Future.delayed` in an `asyncMap` mapper). For those, either pump
the duration yourself or use `emitAndPump`:

```dart
await tester.emitAndPump(counter.cell, 5,
    duration: const Duration(milliseconds: 300));
```

## `emitAndPump`

The intermediate-state escape hatch: emit, pump exactly one frame (or a
duration), and assert on the in-between state (e.g. a loading spinner)
before the async work lands.

## `expectCellValue`

```dart
tester.expectCellValue(counter.cell, 5);
tester.expectCellValue(auth.cell, isA<SignedIn>(), reason: 'after sign-in');
```

Any `expect` matcher works.

## `recordPulses`

```dart
final recorder = counter.cell.recordPulses();
addTearDown(recorder.stop);

counter.update(1);
counter.update(2);
expect(recorder.payloads, [1, 2]);
```

Works on **any** `Cell` — derived cells, async operators, tissue
collections. Every pulse is recorded regardless of type. Error pulses
appear with `type == 'error'` and an `Object` payload; inspect
`recorder.pulses` when you need the type. The per-source error table
(inherited from Phase 3):

| Source | Emits error pulse |
|---|---|
| `Cell.fromFuture` | **Yes** (`type: 'error'`) |
| `Cell.fromStream` | No |
| `Cell.asyncMap` | No |

A recorder over `fromStream` / `asyncMap` will not see failures.

## `CellTestHarness`

For suites with 3+ cells (or cells shared across many tests):

```dart
late CellTestHarness harness;

setUp(() {
  harness = CellTestHarness()
    ..add(#counter, Cell.state<int>(initial: 0).cell)
    ..add(#auth, Cell.state<AuthState?>(initial: null).cell);
});

tearDown(() => harness.dispose());

testWidgets('renders', (tester) async {
  await harness.pump(tester: tester, child: LoginScreen());
  await harness.emitAndSettle(tester, #counter, 5);
  expect(find.text('5'), findsOneWidget);
});
```

Decision boundary: **1–2 cells → extensions; 3+ cells → harness.**
`harness.recordPulses(#id)` returns a recorder auto-stopped on
`dispose()`. The harness never disposes your cells — they are yours.

## `expectCellGolden`

```dart
await tester.expectCellGolden(
  cell: counter.cell,
  builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
  name: 'counter_zero',
);
```

Generate with `flutter test --update-goldens` on the reference platform
(the committed goldens were generated on Windows; regenerate on another
platform before enabling the comparison there). The default test font
renders text as boxes — load real fonts with `golden_toolkit`'s
`loadAppFonts()` in `setUpAll` for legible goldens.

## Hooks

`pumpWithCells` works with `HookBuilder` — hooks compose with widgets:

```dart
await tester.pumpWithCells(
  cells: {#counter: counter.cell},
  child: HookBuilder(builder: (ctx) {
    final v = useCell<int, int>(
      cell: CellScope.valueOf<int>(ctx, #counter),
      select: (x) => x ?? 0,
    );
    return Text('$v');
  }),
);
```

## Agentic runtime preview

When the agentic runtime (`cell_mind`) lands, its testing section will
cover agent-driven flows; the utilities here remain the widget-layer
baseline for those tests.

## See also

- `example/test/counter_test.dart` — the extensions together.
- `HowTo-CellScope.md` — scoped cell lookups.
- `HowTo-CellAsyncBuilder.md` — the per-source error behavior.
