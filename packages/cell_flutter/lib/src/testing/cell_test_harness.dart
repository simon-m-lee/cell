// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'emit_and_settle.dart';
import 'pump_with_cells.dart';
import 'record_pulses.dart';

/// A per-test **Cell Registry** that bundles the cells a test suite needs,
/// tracks their pulse recorders, and disposes both in one call.
///
/// [CellTestHarness] is the binding's **Test Fixture**. It wraps the two
/// pieces that most cell-based tests share — a `Symbol`-keyed map of cells
/// to register into a [CellScope], and the [PulseRecorder]s opened on them —
/// behind a single object whose `dispose` cleans up everything it created.
/// The per-operation extensions (`pumpWithCells`, `emitAndSettle`,
/// `recordPulses`) remain available; the harness simply layers ownership on
/// top so tests with several cells do not have to track recorders by hand.
///
/// ### Why it is used
/// - **Multi-cell tests**: suites with 3+ cells, or with the same cells
///   reused across many tests, benefit from a single fixture that knows
///   every registration and every recorder. Per-test bookkeeping of "did I
///   `addTearDown` the recorder?" disappears.
/// - **Recorder ownership**: every recorder created via
///   [recordPulses] is tracked and stopped on [dispose]. A recorder left
///   running pins its source cell for the isolate's lifetime; the harness
///   eliminates that failure mode by default.
/// - **Chainable setup**: `add` returns the harness, so `setUp` reads as a
///   single chain of registrations.
///
/// ### When **not** to use it
/// For a suite with 1–2 cells, the extension methods ([CellPumpWithCells],
/// [CellEmitAndSettle], [CellRecordPulses]) are shorter — a few lines of
/// `setUp`/`tearDown` beat a harness object. The harness is worth its
/// ceremony only when there are enough registrations to justify it.
///
/// ### How it works
/// 1. **Registration**: [add] inserts a cell under a `Symbol` key. The map
///    is what [pump] passes to [CellPumpWithCells.pumpWithCells], so the
///    same set of cells is scoped above every widget the test pumps.
/// 2. **Lookup**: [cell] and [valueCell] retrieve a registration with
///    optional type narrowing. A type mismatch throws [StateError]; an
///    unknown id throws too.
/// 3. **Recording**: [recordPulses] opens a [PulseRecorder] on the cell at
///    the given id and stores it for later disposal.
/// 4. **Pumping and emission**: [pump] and [emitAndSettle] delegate to the
///    corresponding `WidgetTester` extensions, using the harness's
///    registry as the scope.
/// 5. **Disposal**: [dispose] stops every recorder and clears the registry.
///    It is idempotent.
///
/// ### Design Note: the harness owns **recorders**, not cells
/// The split is deliberate. A test's cells may outlive the harness (a
/// suite-level `Cell.state` reused across tests, for example), and
/// invalidating them during `tearDown` would break the next test. The
/// harness therefore owns only the resources **it created** — the
/// recorders — and leaves cell lifecycle entirely to the caller. Registering
/// the same [Symbol] twice replaces the previous entry without disposing it;
/// [dispose] clears the map without invalidating the cells.
///
/// ### Technical Details
/// - **Symbol-keyed registry**: matches [CellScope]'s design — the same
///   map is passed to the scope in [pump], so registrations and lookups
///   use the same keys. See [CellScope] for why `Symbol`s rather than
///   type-keys.
/// - **Type narrowing is `ValueCell`-only**: `Cell` carries no value type
///   parameter, so [cell] can only type-check [ValueCell] registrations.
///   [valueCell] requires a `ValueCell<V>` and throws otherwise.
/// - **Disposal is idempotent and final**: after [dispose], [add],
///   [recordPulses], and [pump] throw [StateError]. The registry is
///   cleared; subsequent calls are programmer errors, not silent no-ops.
/// - **No `WidgetTester` ownership**: the harness does not hold a tester.
///   [pump] and [emitAndSettle] take a tester argument per call so the same
///   harness can serve multiple `testWidgets` bodies.
///
/// ### Example
/// ```dart
/// late CellTestHarness harness;
///
/// setUp(() {
///   harness = CellTestHarness()
///     ..add(#counter, Cell.state<int>(initial: 0).cell)
///     ..add(#auth, Cell.state<AuthState?>(initial: null).cell);
/// });
///
/// tearDown(() => harness.dispose());
///
/// testWidgets('renders counter', (tester) async {
///   await harness.pump(tester: tester, child: LoginScreen());
///   await harness.emitAndSettle(tester, #counter, 5);
///   expect(find.text('5'), findsOneWidget);
/// });
///
/// testWidgets('records pulses', (tester) async {
///   final recorder = harness.recordPulses(#counter);
///   // harness.dispose() stops all recorders automatically.
///   expect(recorder.payloads, isEmpty);
/// });
/// ```
///
/// ### See Also:
/// - [CellPumpWithCells.pumpWithCells] — the underlying scoped-pump helper.
/// - [CellEmitAndSettle.emitAndSettle] — the underlying emit-and-settle
///   helper.
/// - [CellRecordPulses.recordPulses] — the underlying recorder constructor.
/// - [CellScope] — the registry installed above every pumped tree.
/// - [PulseRecorder] — the recorder type the harness tracks and disposes.
class CellTestHarness {
  final Map<Symbol, Cell> _cells = {};
  final List<PulseRecorder<Cell>> _recorders = [];
  bool _disposed = false;

  /// Registers [cell] under [id]. Chainable.
  ///
  /// Registering the same [id] twice replaces the previous entry. The
  /// previous cell is **not** disposed — the harness does not own the
  /// cells' lifecycles.
  ///
  /// ### Parameters:
  /// * [id]: **The Registration Key.** A `Symbol` (`#counter`, `#auth`)
  ///   used both here and in every lookup ([cell], [valueCell],
  ///   [recordPulses], [emitAndSettle]). The same symbol is installed into
  ///   the [CellScope] built by [pump].
  /// * [cell]: **The Registered Cell.** Any [Cell]. Held by reference.
  ///
  /// ### Returns:
  /// `this`, for chaining registrations in `setUp`.
  ///
  /// ### Throws:
  /// [StateError] if [dispose] has already been called.
  CellTestHarness add(Symbol id, Cell cell) {
    if (_disposed) {
      throw StateError('CellTestHarness: add called after dispose.');
    }
    _cells[id] = cell;
    return this;
  }

  /// Returns the cell registered at [id], narrowed to `ValueCell<V>` when
  /// the registration is a `ValueCell`.
  ///
  /// ### Parameters:
  /// * [id]: **The Registration Key.** The `Symbol` used at [add].
  ///
  /// ### Returns:
  /// The registered [Cell]. If the registration is a `ValueCell<V>`, the
  /// result is narrowed to that type; plain [Cell] registrations are
  /// returned as-is.
  ///
  /// ### Throws:
  /// - [StateError] when [id] is not registered.
  /// - [StateError] when the registration is a `ValueCell` whose value type
  ///   does not satisfy `V`.
  ///
  /// ### See Also:
  /// - [valueCell] — the variant that requires a `ValueCell<V>`.
  /// - [CellScope.of] — the production equivalent with the same semantics.
  Cell cell<V>(Symbol id) {
    final c = _cells[id];
    if (c == null) {
      throw StateError('CellTestHarness: no cell registered at $id.');
    }
    if (c is ValueCell && c is! ValueCell<V>) {
      throw StateError(
        'CellTestHarness: $id is ${c.runtimeType}, not ValueCell<$V>.',
      );
    }
    return c;
  }

  /// Returns the `ValueCell<V>` registered at [id].
  ///
  /// This is the common lookup for [emitAndSettle] and for any test that
  /// wants to read the current value directly.
  ///
  /// ### Parameters:
  /// * [id]: **The Registration Key.**
  ///
  /// ### Returns:
  /// The registered cell, statically typed as [ValueCell<V>].
  ///
  /// ### Throws:
  /// - [StateError] when [id] is not registered.
  /// - [StateError] when the registration is not a `ValueCell<V>` at all
  ///   (either a plain [Cell], or a `ValueCell` of a different value type).
  ///
  /// ### See Also:
  /// - [cell] — the un-narrowed variant.
  /// - [CellScope.valueOf] — the production equivalent.
  ValueCell<V> valueCell<V>(Symbol id) {
    final c = _cells[id];
    if (c == null) {
      throw StateError('CellTestHarness: no cell registered at $id.');
    }
    if (c is! ValueCell<V>) {
      throw StateError(
        'CellTestHarness: $id is ${c.runtimeType}, not ValueCell<$V>.',
      );
    }
    return c;
  }

  /// Records pulses from the cell registered at [id].
  ///
  /// The recorder is tracked by the harness and auto-stopped on [dispose].
  /// If you call `recorder.stop()` early, the harness's `dispose` remains
  /// safe (stop is idempotent).
  ///
  /// ### Parameters:
  /// * [id]: **The Registration Key.**
  ///
  /// ### Returns:
  /// A live [PulseRecorder] over the registered cell. The recorder is
  /// already subscribed and recording.
  ///
  /// ### Throws:
  /// - [StateError] when [dispose] has already been called.
  /// - [StateError] when [id] is not registered.
  ///
  /// ### See Also:
  /// - [CellRecordPulses.recordPulses] — the underlying helper.
  /// - [PulseRecorder] — the recorder type.
  /// - [dispose] — releases every recorder this method created.
  PulseRecorder<Cell> recordPulses(Symbol id) {
    if (_disposed) {
      throw StateError('CellTestHarness: recordPulses called after dispose.');
    }
    final c = _cells[id];
    if (c == null) {
      throw StateError('CellTestHarness: no cell registered at $id.');
    }
    final recorder = c.recordPulses();
    _recorders.add(recorder);
    return recorder;
  }

  /// The cells registered in this harness, in insertion order.
  ///
  /// Returns an unmodifiable view of the internal registry. Useful for
  /// assertions about what was registered without going through [cell] /
  /// [valueCell]'s type checks.
  ///
  /// The same map is passed to [pump] as the [CellScope] registrations, so
  /// mutating it in place would desynchronize the harness from already-
  /// pumped trees — hence the unmodifiable view.
  Map<Symbol, Cell> get cells => Map.unmodifiable(_cells);

  /// Pumps [child] with the harness's registered cells in a [CellScope].
  ///
  /// Delegates to [CellPumpWithCells.pumpWithCells] with the harness's
  /// registry as [CellPumpWithCells.pumpWithCells]`cells`. The default
  /// `MaterialApp(home: Scaffold(...))` wrapper is used unless [wrapper] is
  /// supplied.
  ///
  /// ### Parameters:
  /// * [tester]: **The Active Tester.** Supplied per call — the harness
  ///   does not own a `WidgetTester`.
  /// * [child]: **The Widget Under Test.**
  /// * [wrapper]: **Optional Tree Override.** Passed through to
  ///   [CellPumpWithCells.pumpWithCells].
  ///
  /// ### Returns:
  /// A [Future] that resolves once the first frame is built (the same
  /// return semantics as [WidgetTester.pumpWidget]).
  ///
  /// ### Throws:
  /// [StateError] if [dispose] has already been called.
  ///
  /// ### See Also:
  /// - [CellPumpWithCells.pumpWithCells] — the underlying pump helper,
  ///   including the rationale for placing [CellScope] outside the wrapper.
  Future<void> pump({
    required WidgetTester tester,
    required Widget child,
    Widget Function(Widget child)? wrapper,
  }) async {
    if (_disposed) {
      throw StateError('CellTestHarness: pump called after dispose.');
    }
    await tester.pumpWithCells(
      cells: _cells,
      child: child,
      wrapper: wrapper,
    );
  }

  /// Sets the value of the cell at [id] and pumps the tree to settle.
  ///
  /// Delegates to [CellEmitAndSettle.emitAndSettle], resolving the cell
  /// through [valueCell] first so the value type is checked at the call
  /// site.
  ///
  /// ### Parameters:
  /// * [tester]: **The Active Tester.** Supplied per call.
  /// * [id]: **The Registration Key** of the cell to emit on.
  /// * [value]: **The New Value.** Assigned to `cell.value` before pumping.
  ///   Subject to the cell's own `testRule` / `evolve` rules (see
  ///   [CellEmitAndSettle.emitAndSettle]).
  ///
  /// ### Returns:
  /// A [Future] that resolves when the frame pipeline is idle.
  ///
  /// ### Throws:
  /// [StateError] if [dispose] has already been called, or — via
  /// [valueCell] — if [id] is unknown or the value type does not match.
  ///
  /// ### See Also:
  /// - [CellEmitAndSettle.emitAndSettle] — the underlying helper, including
  ///   the async-receptor caveats.
  /// - [valueCell] — the lookup used to resolve [id].
  Future<void> emitAndSettle<V>(
    WidgetTester tester,
    Symbol id,
    V? value,
  ) async {
    if (_disposed) {
      throw StateError('CellTestHarness: emitAndSettle called after dispose.');
    }
    await tester.emitAndSettle(valueCell<V>(id), value);
  }

  /// Stops all recorders and clears the registry. Idempotent.
  ///
  /// Does **not** dispose the registered cells — the harness does not own
  /// them. The caller is responsible for any cell invalidation.
  ///
  /// After [dispose], [add], [recordPulses], [pump], and [emitAndSettle]
  /// throw [StateError]; [cell], [valueCell], and [cells] return the (now
  /// empty) registry without throwing, since they read from it rather than
  /// extending it.
  ///
  /// ### See Also:
  /// - [PulseRecorder.stop] — the primitive used on each tracked recorder.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final recorder in _recorders) {
      recorder.stop();
    }
    _recorders.clear();
    _cells.clear();
  }
}
