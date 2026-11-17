// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// An extension on [WidgetTester] that drives a [ValueCell] through the
/// widget tree and lets the frame pipeline catch up.
///
/// [CellEmitAndSettle] is the binding's **Emission Driver** — the companion
/// to [CellPumpCell.pumpCell] and [CellPumpWithCells.pumpWithCells]. Where
/// the pump helpers put a widget on screen with the cell's *initial* value,
/// this extension triggers an update and pumps the frames needed for that
/// update to render. The pair together forms the shortest possible
/// widget-test cycle: pump → emit → assert.
///
/// ### Why it is used
/// - **Deterministic widget tests**: a `cell.value = ...` mutation runs the
///   pulse through the graph synchronously but does not, by itself, cause
///   Flutter to render the resulting state. `emitAndSettle` combines the
///   mutation with the pumping required to see it.
/// - **Timer-aware**: `pumpAndSettle` drains the microtask queue between
///   frames, so receptors that resolve on a microtask (the common case)
///   work without further help. See *Async receptor caveats* below for the
///   one case it does not cover.
/// - **Intermediate-state observation**: `emitAndPump` lets a test observe
///   the tree before the widget has fully settled — useful for asserting a
///   loading spinner before the results list appears.
///
/// ### How it works
/// - [emitAndSettle] assigns `cell.value = value`, then awaits
///   [WidgetTester.pumpAndSettle]. It keeps pumping frames while any are
///   scheduled, so a cell whose update triggers a `setState` (as in every
///   `CellBuilder`) will end with the tree settled.
/// - [emitAndPump] assigns `cell.value = value`, then awaits exactly one
///   [WidgetTester.pump] — or one [WidgetTester.pump] with [duration] when
///   supplied. It does not wait for the tree to settle; the caller controls
///   how many frames to advance.
///
/// ### Async receptor caveats (read this)
/// `pumpAndSettle` does **not** wait for timers — only for scheduled frames
/// and microtasks. That leaves three cases to reason about:
/// | Receptor resolves… | `emitAndSettle` works? | Fallback |
/// |---|---|---|
/// | synchronously | yes | — |
/// | on a microtask (e.g. plain `await`) | yes — microtasks drain between frames | — |
/// | on a timer (`Future.delayed`, `Timer`) | **no** — the timer has not fired yet | `await tester.pump(duration)` after, or `emitAndPump(cell, value, duration: …)` |
///
/// Use [emitAndPump] with an explicit [emitAndPump]`duration` when the
/// pulse resolution depends on a timer, or to inspect an intermediate
/// frame.
///
/// ### Design Note: why this is not automatic
/// `CellBuilder` rebuilds through `ValueListenableBuilder` and `CellNotifier`,
/// not through `setState` on the widget's own state. That means Flutter
/// **does** schedule a frame on every pulse — but the frame only renders
/// after the test's event loop yields. A test that asserts immediately
/// after `cell.value = value` inspects the *previous* frame, which is the
/// most common widget-test failure mode with cells. This extension exists
/// to make the yield explicit and test-local, rather than hidden in a
/// `waitFor`-style loop.
///
/// ### Technical Details
/// - **ValueCell only**: both methods assign `cell.value` synchronously,
///   which is a [ValueCell] capability. Plain `Cell` sources
///   (`Cell.derive`, `Cell.asyncMap`) must be driven through their input
///   cells, not asserted directly here.
/// - **Single assignment**: each call assigns once. For a burst of updates,
///   call the extension multiple times or assign directly and `pump` —
///   `pumpAndSettle` collapses all intermediate frames into the final
///   rendered state, which is usually what tests want.
/// - **No assertions**: these helpers mutate and pump; they do not check
///   anything. Pair with [CellExpectValue.expectCellValue] or the usual
///   `expect(find.text(...), …)` after settling.
///
/// ### Example
/// ```dart
/// await tester.pumpCell(cell: counter.cell, builder: (_, v) => Text('$v'));
/// await tester.emitAndSettle(counter.cell, 5);
/// expect(find.text('5'), findsOneWidget);
/// ```
///
/// ### See Also:
/// - [CellPumpCell.pumpCell] — the pump step that precedes emission.
/// - [CellPumpWithCells.pumpWithCells] — the scoped variant.
/// - [CellExpectValue.expectCellValue] — the assertion step that follows.
/// - [WidgetTester.pumpAndSettle] / [WidgetTester.pump] — the Flutter
///   primitives these helpers wrap.
extension CellEmitAndSettle on WidgetTester {
  /// Sets [cell]'s value to [value], then pumps until the widget tree
  /// settles.
  ///
  /// The common assertion pattern: emit, let the graph and widgets catch
  /// up, then assert. See the extension-level *Async receptor caveats* for
  /// the one case (`Future.delayed` / `Timer`) where `pumpAndSettle` alone
  /// is insufficient.
  ///
  /// ### Parameters:
  /// * [cell]: **The Emitted Cell.** Must be a [ValueCell] — the method
  ///   assigns `cell.value` synchronously. For plain `Cell` sources, emit
  ///   through their input cells instead.
  /// * [value]: **The New Value.** Assigned to `cell.value` before pumping
  ///   begins. Subject to the cell's own `testRule` and `evolve` logic —
  ///   an update rejected by the cell's integrity gate does **not** change
  ///   the value and the tree settles on the previous state.
  ///
  /// ### Returns:
  /// A [Future] that completes when the frame pipeline is idle — the same
  /// completion semantics as [WidgetTester.pumpAndSettle].
  ///
  /// ### See Also:
  /// - [emitAndPump] — the single-frame variant for observing intermediate
  ///   state or advancing a timer.
  /// - [CellEmitAndSettle] — the extension-level docs, including the async
  ///   receptor caveats.
  Future<void> emitAndSettle<V>(ValueCell<V> cell, V? value) async {
    cell.value = value;
    await pumpAndSettle();
  }

  /// Sets [cell]'s value and pumps a single frame (or [duration], if
  /// provided). Does not wait for settle.
  ///
  /// Use when the test needs to observe an intermediate state — e.g., a
  /// loading spinner — before the widget settles, or when the receptor
  /// resolves on a timer that `pumpAndSettle` would not wait for.
  ///
  /// ### Parameters:
  /// * [cell]: **The Emitted Cell.** Must be a [ValueCell]. See
  ///   [emitAndSettle] for the assignment semantics.
  /// * [value]: **The New Value.** Assigned to `cell.value` before pumping.
  ///   Subject to the same integrity-gate and evolve rules as
  ///   [emitAndSettle].
  /// * [duration]: **Optional Frame Advance.** When supplied, the helper
  ///   calls [WidgetTester.pump] with this duration — advancing the fake
  ///   clock by that amount, which fires any timers due within it. When
  ///   omitted, a plain [WidgetTester.pump] advances a single frame.
  ///
  /// ### Returns:
  /// A [Future] that completes when the pumped frame has been rendered.
  ///
  /// ### Example
  /// ```dart
  /// final query = Cell.state<String>(initial: '');
  /// await tester.pumpWidget(...);
  /// await tester.emitAndPump(query.cell, 'dart');
  /// expect(find.byType(Spinner), findsOneWidget);
  /// await tester.pump(const Duration(seconds: 1));
  /// expect(find.byType(ResultsList), findsOneWidget);
  /// ```
  ///
  /// ### See Also:
  /// - [emitAndSettle] — the settle variant for the common case.
  /// - [CellEmitAndSettle] — the extension-level docs.
  Future<void> emitAndPump<V>(
    ValueCell<V> cell,
    V? value, {
    Duration? duration,
  }) {
    cell.value = value;
    return duration == null ? pump() : pump(duration);
  }
}
