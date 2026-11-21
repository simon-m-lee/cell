# cell_flutter

## Install and import

```bash
flutter pub add cell cell_flutter

# optional: only if you use HookWidget
flutter pub add flutter_hooks
```

```dart
import 'package:cell_flutter/cell_flutter.dart'; // app surface (re-exports package:cell)
import 'package:cell_flutter/hooks.dart';         // optional: flutter_hooks integration
import 'package:cell_flutter/testing.dart';       // test-only: pump/emit/assert helpers
```

---

> **Flutter Widgets for Mitosis Cells** — display, react, route, bridge, and test — with one import. Plain Flutter widgets plus a governed reactive graph.

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/LICENSE)
[![Version](https://img.shields.io/badge/cell__flutter-1.0.2-blue.svg)](#status)
[![Status](https://img.shields.io/badge/Status-Stable-green.svg)](#status)

This is the Flutter binding for the Cell Framework (Mitosis). Sibling packages add the core graph, stream combinators, and collections; this package adds the widget layer.

## See it live

The **[Audit Trail demo](https://simon-m-lee.github.io/cell/audit-trail/)** proves the
Cell difference in under a minute: a state change that is **recorded**
(live `ApplyReceipt` ledger), **rejected** by a `TestCell` integrity gate,
and **undone** through a recorded compensation executed inside a real
`Cell.txApply` transaction — three buttons, one screen, no installation.

<!-- GIF placeholder: record a 10-second loop (add → invalid → undo) of the
     live demo at ~640×480 and keep it under 2 MB. -->
[![Try it live](https://img.shields.io/badge/Try%20it%20live-Audit%20Trail%20demo-blue.svg)](https://simon-m-lee.github.io/cell/audit-trail/)

Source: [`demo/audit_trail/`](https://github.com/simon-m-lee/cell/tree/master/demo/audit_trail) — under 500 lines, comments included.

---

## Overview

A **cell** holds a value or relays a signal; a **pulse** is the immutable message that carries a change. `cell_flutter` binds that graph to Flutter's widget tree:

- **Live state display** — `CellBuilder` shows a `ValueCell`'s current value and rebuilds only its own subtree on change. `CellSelector` rebuilds only when the slice it reads changes. `CellValueBuilder` does the same for any `Cell` (derived, async, tissue). Three widgets, three levels of granularity — no `AnimatedBuilder`, no `setState`, no manual subscription.
- **Side effects on pulses** — `CellListener` invokes a handler once per pulse without rebuilding the tree. Navigation, snackbars, haptics, analytics. Same contract as `Cell.observe`, with a `BuildContext`.
- **Async state as `AsyncSnapshot`** — `CellAsyncBuilder` gives you the same `hasData` / `hasError` shape `StreamBuilder` and `FutureBuilder` produce, driven by any `Cell`. The builder branches loading / data / error without further plumbing.
- **App-level dependency injection** — `CellScope` registers a small set of cells (`#auth`, `#theme`, `#featureFlags`) for subtree lookup by `Symbol`. Not a general locator; the DI escape hatch for genuinely global identifiers.
- **Zero-copy bridges** — `asValueCell` mirrors any `Cell` into a `ValueCell` (with an explicit `dispose`); `asStream` bridges any `Cell` to a `Stream<V?>`; `CellNotifier` exposes a `ValueCell` as a Flutter `ValueNotifier`. Reach out of the widget tree without leaving the reactive graph.
- **A test surface you actually use** — `pumpWithCells`, `pumpCell`, `emitAndSettle`, `emitAndPump`, `recordPulses`, `expectCellValue`, `expectCellGolden`, and `CellTestHarness` ship in one import (`package:cell_flutter/testing.dart`). Pump → emit → assert in three lines.
- **Optional hooks layer** — `useCell`, `useCellValue`, `useCellNotifier`, `useCellListener`, and `useCellAsync` in `package:cell_flutter/hooks.dart`. Same contracts as the widgets, expressed as `flutter_hooks` hooks for `HookWidget` users, with two documented cell-swap caveats (`useCell` shows the previous slice for one frame, `useCellAsync` keeps the previous snapshot — key on the cell to reset). Application code that does not use `HookWidget` never sees them.

Where plain Flutter state gives you `setState` and hand-rolled listeners, `cell_flutter` gives you a widget tree **with a governance contract**:

| Capability | Plain Flutter (`setState` / `ValueNotifier` / `StreamBuilder`) | `cell_flutter` |
|---|---|---|
| Change notification | Manual `addListener` or `StreamBuilder` | Built-in pulse graph — every widget subscribes to exactly what it reads |
| **Transactions** | None — `setState` is atomic per widget, not across widgets | Fully available through the cell layer (`Cell.txApply` / `Cell.transaction`); the widget tree simply observes the committed state |
| Validation | Manual `if` checks in the widget | `TestCell` gates run before the pulse reaches the widget |
| Restricted views | Copy the data, or trust the child widget | `cell.unmodifiable` handed to `CellBuilder` = a read-only render |
| Audit trail | None | The same `ApplyReceipt` the cell records is what the widget rendered |
| Timing operators | Hand-rolled `Timer` inside a `State` | `Cell.debounce` / `Cell.throttle` / `Cell.distinct` operate upstream, invisible to the widget |
| Async combinators | `FutureBuilder` / `StreamBuilder` per source | `Cell.asyncMap` / `switchMap` / `fromFuture` / `fromStream` share one `Cell`, rendered by one `CellAsyncBuilder` |
| Multi-source aggregation | `Future.wait` in `build` | `Cell.synthesis` fans in, `CellBuilder`/`CellValueBuilder` renders the converged value |
| **Test setup** | Hand-rolled `pumpWidget` + `CellScope` + `addTearDown` per test | `pumpWithCells` / `pumpCell` / `emitAndSettle` / `CellTestHarness` ship with the package |

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

> **The whole cycle, in one breath:**
>
> ```dart
> final counter = Cell.state<int>(initial: 0);
>
> // Display it — one widget, one rebuild per change:
> CellBuilder<int>(
>   cell: counter.cell.unmodifiable,
>   builder: (_, v) => Text('${v ?? 0}'),
> );
>
> // React to it — side effect per pulse, no rebuild:
> CellListener<int>(
>   cell: counter.cell,
>   onPulse: (ctx, pulse) => HapticFeedback.lightImpact(),
>   child: const SizedBox.shrink(),
> );
>
> // Reach it from anywhere — no constructor threading:
> CellScope(
>   cells: {#counter: counter.cell},
>   child: const AppRoot(),
> );
> // Later, deep in the tree:
> // final counter = CellScope.valueOf<int>(context, #counter);
>
> // Test it — three lines, no boilerplate:
> await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
> await tester.emitAndSettle(counter.cell, 5);
> expect(find.text('5'), findsOneWidget);
> ```

Defaults are pass-through and allow-all — the widget layer never requires learning `Nucleus`, `Receptor`, or `TestCell`. Those are available (through `cell`) when you need them.

## Table of Contents

- [Overview](#overview)
- [When it fits](#when-it-fits)
- [Install](#install)
- [Quick example](#quick-example)
- [Core widgets](#core-widgets)
- [Optional hooks layer](#optional-hooks-layer)
- [Test surface](#test-surface)
- [How much you need to know](#how-much-you-need-to-know)
- [Documentation](#documentation)
- [Ecosystem](#ecosystem)
- [Status](#status)
- [License](#license)

## When it fits

`cell_flutter` is a good match if you want:

- Live state display with rebuild granularity (`CellBuilder` / `CellSelector` / `CellValueBuilder`)
- Side effects that fire on pulses, not on rebuilds (`CellListener`)
- Async state (`fromFuture`, `fromStream`, `asyncMap`) rendered as `AsyncSnapshot` (`CellAsyncBuilder`)
- App-level cells (auth, theme, feature flags) reachable from deep in the tree (`CellScope`)
- Zero-copy bridges to Flutter primitives (`CellNotifier`, `asValueCell`, `asStream`)
- Widget tests that do not hand-roll the pump frame (`testing.dart`)

It is more machinery than you need for:

- A single `StatefulWidget` with `setState` and no cross-tree sharing
- A form-local controller that owns one value
- A `FutureBuilder` that reads one value once and never again
- A widget that does not already use cells in its state layer

**`cell_flutter` is the widget binding, not a state library.** If your state model is not already cells, start with `cell` (the core). The widget layer is what makes a cell-based state model *visible* and *testable* in Flutter; it does not replace the state model itself.

For Rx-style combinators (`merge`, `zip`, `scan`, windows), use **cell_flow**.

---

## Install

From pub.dev:

```yaml
dependencies:
  cell: ^2.0.0
  cell_flutter: ^1.0.2  # stable — see Status below
```

From git:

```yaml
dependencies:
  cell_flutter:
    git:
      url: https://github.com/simon-m-lee/cell.git
      path: packages/cell_flutter
```

Requires Dart `>=3.5.0 <4.0.0` and Flutter `>=3.24.0`. `cell_flutter` declares `flutter_test` as a **regular dependency** (the `bloc_test` / `mocktail` / `mockito` pattern), so `package:cell_flutter/testing.dart` resolves without an extra dependency. Adding `cell_flutter` to `dev_dependencies` in application code keeps the test import out of production builds.

```dart
import 'package:cell_flutter/cell_flutter.dart';
```

---

## Quick example

```dart
import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CounterApp());

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(home: CounterScreen());
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  // One cell, created once in initState — the same anti-pattern rules as
  // any StatefulWidget apply: do not create the cell inside build().
  final _counter = Cell.state<int>(initial: 0);

  @override
  void dispose() {
    _counter.cell.invalidate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CellBuilder<int>(
          cell: _counter.cell,
          builder: (_, v) => Text('${v ?? 0}', style: const TextStyle(fontSize: 48)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _counter.update(1),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Runnable demos live in [`example/`](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter/example). Start with `example/state_demo.dart`.

---

## Core widgets

You can build most Flutter application UIs from these widgets. None of them require configuring `Receptor`, `TestCell`, `Context`, or `Synapses`.

| | Widget | Use when |
|---|--------|----------|
| 1 | `CellBuilder` | Show a `ValueCell`'s current value |
| 2 | `CellSelector` | Show one field of a `ValueCell` |
| 3 | `CellValueBuilder` | Show any `Cell` (derived, async, tissue) |
| 4 | `CellAsyncBuilder` | Show loading / data / error as `AsyncSnapshot` |
| 5 | `CellListener` | Run a side effect on each pulse (no rebuild) |
| 6 | `CellScope` | Reach app-level cells from deep in the tree |
| 7 | `CellNotifier` | Get a `Listenable` for Flutter primitives |
| 8 | `CellAsStream` (ext) | Bridge any `Cell` to `Stream<V?>` |
| 9 | `CellAsValue` (ext) | Mirror any `Cell` into a `ValueCell` (with explicit `dispose`) |
| 10 | `ValueCellBuilder` (ext) | Fluent `cell.builder((_, v) => …)` sugar |

Also implemented, outside that numbered set: **`MirroredCell`** (the record returned by `asValueCell`), **`snapshotForPulse` / `snapshotForCell`** (the pure snapshot decoders used by `CellAsyncBuilder`).

Learning order: show state → react → route → bridge → isolate. Widgets 1–3 are enough for a first app.

**Which display widget?**

| Your source is… | Use |
|---|---|
| A `ValueCell` (`Cell.state` results) | `CellBuilder` |
| A `ValueCell`, but only one field matters | `CellSelector` |
| Any `Cell` (derived, async, tissue) | `CellValueBuilder` |
| An async `Cell`, and you need `AsyncSnapshot` | `CellAsyncBuilder` |

`CellBuilder` is the cheapest binding for a `ValueCell` and gets `ValueListenableBuilder`'s subtree isolation for free. Reach for `CellValueBuilder` only when the source is not a `ValueCell`. Reach for `CellSelector` when a `CellBuilder` would rebuild too often.

---

## Optional hooks layer

For `HookWidget` users. Import separately:

```dart
import 'package:cell_flutter/hooks.dart';
```

The hooks follow `flutter_hooks`' rules: unconditional, top-level, same order every build. Violations trigger `flutter_hooks`' own assertion.

| Hook | Equivalent widget | Use |
|---|---|---|
| `useCell` | `CellSelector` | Slice-granular rebuild in a `HookWidget` |
| `useCellValue` | `CellBuilder` | Full-value rebuild in a `HookWidget` |
| `useCellNotifier` | `CellNotifier` | A `Listenable` for `useValueListenable` / `ValueListenableBuilder` |
| `useCellListener` | `CellListener` | Side effect per pulse (no rebuild) |
| `useCellAsync` | `CellAsyncBuilder` | `AsyncSnapshot` for async cells |

The hooks layer re-exports `flutter_hooks` and `cell_flutter`, so a `HookWidget` needs only the one import. `useCellAsync` inherits `CellAsyncBuilder`'s per-source error behavior and the concurrent-`asyncMap` caveat; see `use_cell_async.dart` for the full picture. Two cell-swap caveats differ from the widgets and are documented in the hook docs: `useCell` shows the previous cell's slice for one frame after a swap, and `useCellAsync` keeps the previous snapshot across a swap. Key the enclosing `HookWidget` on the cell when reset-on-swap is required.

---

## Test surface

Import from test files only:

```dart
import 'package:cell_flutter/testing.dart';
import 'package:flutter_test/flutter_test.dart';
```

The barrel exports every helper the binding provides, plus the application-facing surface they build on.

| Helper | Use |
|---|---|
| `pumpWithCells` | Pump inside a `CellScope` with a `MaterialApp` frame |
| `pumpCell` | Pump a bare `CellBuilder` (no `CellScope`) |
| `emitAndSettle` | Write a `ValueCell`, then `pumpAndSettle` |
| `emitAndPump` | Write a `ValueCell`, then `pump([duration])` |
| `recordPulses` | Capture the ordered pulse sequence from any `Cell` |
| `PulseRecorder<T>` | The recorder type; exposes `pulses` and `payloads` |
| `expectCellValue` | Assert a `ValueCell`'s value against a matcher |
| `expectCellGolden` | Capture a golden of a `CellBuilder` at the current value |
| `CellTestHarness` | Per-test registry: cells + recorders + pump/emit helpers |

`CellTestHarness` is worth its ceremony for suites with 3+ cells or with cells reused across tests. For 1–2 cells, use the extensions directly.

> **Per-source error-pulse note.** `recordPulses` records every pulse regardless of type. Only `Cell.fromFuture` currently emits `Pulse<Object>(type: 'error')` on the failure path in the core package; `Cell.fromStream` and `Cell.asyncMap` do not. See `record_pulses.dart` for the full explanation — it is the authoritative statement in the binding.

---

## How much you need to know

Layers are optional, not a reading list.

1. **Core widgets** — `CellBuilder`, `CellListener`, `CellScope`. The intended default for Flutter application code.
2. **Selector and async widgets** — `CellSelector`, `CellValueBuilder`, `CellAsyncBuilder`. When the plain widgets rebuild too much or the source is not a `ValueCell`.
3. **Bridges** — `asValueCell`, `asStream`, `CellNotifier`. When reaching out to Flutter primitives or Dart interop.
4. **Hooks** — `useCell*` in `hooks.dart`. When using `HookWidget`.
5. **Test surface** — `testing.dart`. When writing widget tests.

The underlying `cell` layers (`Receptor` / `Instruction`, `TestCell` / `Context`, `Nucleus` / `Cell.governed`) are still there — the widget layer simply does not require them. See [`cell`'s README](https://github.com/simon-m-lee/cell/blob/master/packages/cell/README.md) for the full stack.

See [ARCHITECTURE-flutter.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/ARCHITECTURE-flutter.md) for the design rationale behind the widget-layer split and §11 for the known-gaps list.

---

## Documentation

| Document | What it is |
|----------|------------|
| [HowTo-CellBuilder.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellBuilder.md) | Primary state display |
| [HowTo-CellSelector.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellSelector.md) | Slice-granular rendering |
| [HowTo-CellValueBuilder.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellValueBuilder.md) | Rendering any `Cell` |
| [HowTo-CellAsyncBuilder.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellAsyncBuilder.md) | Async sources and error pulses |
| [HowTo-CellListener.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellListener.md) | Side effects without rebuilds |
| [HowTo-CellScope.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellScope.md) | App-level cell DI |
| [HowTo-Hooks.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Hooks.md) | `flutter_hooks` integration |
| [HowTo-Restoration.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Restoration.md) | Process-kill state survival |
| [HowTo-Forms.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Forms.md) | Text fields and form validation |
| [HowTo-Router.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Router.md) | `go_router` bridge (`cell_flutter_router`) |
| [HowTo-Persistence.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Persistence.md) | Durable state (`cell_flutter_persistence`) |
| [HowTo-Testing.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-Testing.md) | Pump, emit, and assert |
| [ARCHITECTURE-flutter.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/ARCHITECTURE-flutter.md) | Why the pieces are shaped this way (known gaps in §11) |

Guides use `HowTo-*.md` (hyphens). Generate API docs with `dart doc .` and open `doc/api/index.html`.

If a guide and the source disagree, **the source is current**.

---

## Ecosystem

| Package | Delivery | Adds |
|---------|----------|------|
| **cell** | Now | Nodes, pulses, operators, governance, transactions |
| **cell_flow** | Now | 100+ instruction factories on `Flow`, plus fluent chaining (`mapTo`, `asyncExpand`, `zip`, …) |
| **cell_tissue** | Now | Reactive collections (list / map / set / queue) |
| **cell_flutter** (this) | Now | Flutter widget bindings for cells, pulses, and their pulse sequences |
| **cell_flutter/hooks.dart** | Now | Optional `flutter_hooks` integration for `HookWidget` users |
| **cell_flutter_router** | Now | `go_router` bridge: `CellRouterStateMirror` / `CellRouterScope` / `useCellRouter` |
| **cell_flutter_persistence** | Now | `SharedPreferencesAdapter`, `InMemoryAdapter`, `PersistedCell` write modes |
| **cell_flutter_lints** | Now | Four `custom_lint` rules guarding known anti-patterns |

The widget layer renders cells regardless of which layer produced them: a `Cell.state` from `cell`, a `Flow` from `cell_flow`, a `TissueList` from `cell_tissue`. The three `CellBuilder` / `CellValueBuilder` / `CellAsyncBuilder` widgets are the universal bridge.

---

### Comparing to other packages

See [`doc/comparison.md`](doc/comparison.md) for an honest
Provider / Riverpod / Bloc / cell_flutter comparison and a
should-I-use-this decision guide.

### Migrating

- [Migrating from Provider](guide/Migrating-From-Provider.md)
- [Migrating from Riverpod](guide/Migrating-From-Riverpod.md)
- [Migrating from Bloc](guide/Migrating-From-Bloc.md)
- [Migrating from setState](guide/Migrating-From-SetState.md)

Each guide's worked examples are fixture-verified
(`test/migration/`) — the guide's code is executed and compared
against the source package's code by the test suite.

### Lint rules

[`cell_flutter_lints`](https://pub.dev/packages/cell_flutter_lints)
ships four `custom_lint` rules guarding the anti-patterns these docs
warn about (cells created in `build`, unkeyed `HookBuilder`s,
forgotten observation-link disposal, collection selectors without
`equals`).

---

## Status

**1.0.2 — stable.** The production-readiness work is complete
Completing it delivered: the `cell_flutter_router` (`0.1.1`) and
`cell_flutter_persistence` (`0.1.1`) ecosystem packages, microbenchmark baselines
with a 15% regression gate (`benchmark/`, `tool/benchmark.dart`), CI
workflows for analysis/coverage/benchmarks/publish dry-runs
(`.github/workflows/cell_flutter*.yml`), and the full documentation
set. The suite is 364 tests (1 intentionally skipped: the release-mode devtools path) with ≥95% line coverage of `lib/`; the
golden suite is regeneration-checked in CI; `dart doc` is warning-free.

The 1.0.x API freeze covers every public symbol in `cell_flutter.dart`
and `hooks.dart`; breaking changes go through major versions per
semver. See [ARCHITECTURE-flutter.md §12](ARCHITECTURE-flutter.md) for
the stability policy and roadmap.

What 1.0.x guarantees:

- **Live display**: `CellBuilder`, `CellSelector`, `CellValueBuilder` rebuild on the pulses they subscribe to, no more and no less.
- **Side effects**: `CellListener` invokes its handler once per pulse, in order, and never rebuilds its child.
- **Async rendering**: `CellAsyncBuilder` produces `AsyncSnapshot` transitions equivalent to `StreamBuilder` for the async sources it receives. Only `Cell.fromFuture` failures surface as `hasError`; `fromStream` / `asyncMap` failures do not emit error pulses in the core package (see `record_pulses.dart` and `test/error_pulse_sources_test.dart`).
- **Late-subscriber seeding (0.6.1)**: a `fromFuture` / `fromStream` / `asyncMap` / `derive` cell that emitted before a widget subscribed **is** replayed into the first frame via `Cell.latestPulse` (`CellValueBuilder`, `CellAsyncBuilder`, `asValueCell`, `asStream` — see `test/seed_paths_test.dart`). The hooks layer is verified to match: `useCellAsync` seeds from the same retained pulse (0.7.0).
- **State restoration (0.8.0)**: `restorableState` + `CellRestorationScope` persist primitive values through Flutter's `RestorationManager`; custom types need `toPrimitives` / `fromPrimitives` codecs (see `guide/HowTo-Restoration.md`).
- **Forms (0.9.0)**: `CellTextField` / `CellFormField<T>` / `cellEditingController` bind Flutter form widgets two-way to cells; `Form.validate()` works unchanged (see `guide/HowTo-Forms.md`).
- **Error containment (0.9.0)**: `CellErrorBoundary` renders a fallback for invalidated-cell and build-phase errors, with `reset()` recovery.
- **Virtualized lists (0.9.0)**: `CellListView.builder` and `CellListView.keyed` render `List<T>` cells lazily; the keyed variant rebuilds only new keys and preserves item state across reorders.
- **Bridges**: `asValueCell` mirrors a `Cell` into a `ValueCell`; `asStream` bridges to `Stream<V?>`; `CellNotifier` is a correct read-only `ValueListenable`.
- **Hooks**: `useCell*` mirror the widget contracts, with `flutter_hooks`' rules inherited and two documented cell-swap caveats (see the hooks layer section).
- **Test surface**: `pumpWithCells` / `pumpCell` / `emitAndSettle` / `emitAndPump` / `recordPulses` / `expectCellValue` / `expectCellGolden` / `CellTestHarness` behave as documented.
- **Router bridge (`cell_flutter_router`)**: `CellRouterStateMirror` mirrors go/push/replace/pop/deep links into a restorable `CellRouterState` cell; `useCellRouter` provides a reactive controller. Tested against go_router 18 (the current line).
- **Persistence (`cell_flutter_persistence`)**: `PersistedCell` composes a `RestorableCell` with a `CellPersistenceAdapter` (SharedPreferencesAsync or in-memory) under immediate / debounced / onAppPause write modes.

What 1.0.x does **not** claim:

- Concurrent `Cell.asyncMap` effect attribution (tracked separately in `cell`).
- Error-pulse visibility for `Cell.fromStream` and `Cell.asyncMap` in the widget layer (they do not emit error pulses in the core package at present; see `record_pulses.dart`).
- Per-platform golden precision (see `HowTo-Testing.md` for the recommended per-platform override pattern).
- Production-readiness for the paths the failed 1.0.0 gates cover (benchmarks, CI-only fuzz, external usability).

Feedback and issues are useful at this stage.

```bash
flutter analyze lib
flutter test
dart format .
dart doc .
```

---

## License

MIT or Apache-2.0. See [LICENSE](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/LICENSE).

## Authors

Lee Man Hoi Simon. See [AUTHORS](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/AUTHORS) for copyright holders.