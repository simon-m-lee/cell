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

/// Bundles a set of cells for a test suite, auto-disposing their recorders
/// in `tearDown`.
///
/// ## When to use
///
/// Use the extension methods (`pumpWithCells`, `emitAndSettle`) for suites
/// with 1–2 cells. Use the harness for suites with 3+ cells or when the
/// same cells are shared across many tests.
///
/// ## Usage
///
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
/// ```
///
/// ## Recording pulses
///
/// ```dart
/// final recorder = harness.recordPulses(#counter);
/// // harness.dispose() stops all recorders automatically.
/// ```
///
/// ## Ownership
///
/// The harness owns the **recorders** it creates, not the cells. Cells are
/// the caller's responsibility. `dispose()` stops recorders and clears the
/// registry; it does not dispose cells.
class CellTestHarness {
  final Map<Symbol, Cell> _cells = {};
  final List<PulseRecorder<Cell>> _recorders = [];
  bool _disposed = false;

  /// Registers a cell under [id]. Chainable.
  ///
  /// Registering the same [id] twice replaces the previous entry. The
  /// previous cell is **not** disposed — the harness does not own the
  /// cells' lifecycles.
  CellTestHarness add(Symbol id, Cell cell) {
    if (_disposed) {
      throw StateError('CellTestHarness: add called after dispose.');
    }
    _cells[id] = cell;
    return this;
  }

  /// Returns the cell registered at [id].
  ///
  /// Throws [StateError] if [id] is not registered. Because `Cell` carries
  /// no value type parameter, the value type is verified for [ValueCell]
  /// registrations (the common case); a non-`ValueCell` cell is returned
  /// as-is.
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
  /// Throws [StateError] if [id] is not registered, not a `ValueCell`, or
  /// the type does not match.
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
  /// The recorder is auto-stopped on [dispose]. If you call
  /// `recorder.stop()` early, the harness's dispose is still safe (stop is
  /// idempotent).
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
  Map<Symbol, Cell> get cells => Map.unmodifiable(_cells);

  /// Pumps a widget with the registered cells in a `CellScope`.
  ///
  /// Uses the same default wrapper as [CellPumpWithCells.pumpWithCells].
  /// Requires a `WidgetTester` — the harness does not own one.
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

  /// Convenience: sets the value of the cell at [id] and settles.
  Future<void> emitAndSettle<V>(
    WidgetTester tester,
    Symbol id,
    V? value,
  ) async {
    await tester.emitAndSettle(valueCell<V>(id), value);
  }

  /// Stops all recorders and clears the registry. Idempotent.
  ///
  /// Does not dispose the cells — the harness does not own them.
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
