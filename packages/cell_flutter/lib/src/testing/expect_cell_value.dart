// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// An extension on [WidgetTester] that asserts a [ValueCell]'s current value
/// against a matcher, with a cell-naming diagnostic on failure.
///
/// [CellExpectValue] is the binding's **Value Assertion Helper**. It is a
/// thin sugar over `expect(cell.value, matcher)` whose only behavior beyond
/// the raw matcher call is to attach a `reason` that names the cell. That
/// sounds small, but it turns a failed assertion from
///
/// ```
/// Expected: <5>
///   Actual: <3>
/// ```
///
/// into
///
/// ```
/// Expected: <5>
///   Actual: <3>
/// for cell ValueCell<int>
/// ```
///
/// which tells the reader *which* cell in a test with several of them was
/// the one that disagreed with the expectation.
///
/// ### Why it is used
/// - **Readable assertions**: `tester.expectCellValue(counter.cell, 5)` reads
///   as a sentence and, at a glance, makes the test's intent obvious.
/// - **Failure diagnostics**: the default `reason` names the cell's runtime
///   type so multi-cell tests do not require counting failures against a
///   stack trace to figure out which assertion failed.
/// - **Uniform idiom across the binding's tests**: mirroring the way
///   [CellRecordPulses.recordPulses] and `pumpWithCells` extend
///   [WidgetTester], this helper keeps cell-specific test utilities on the
///   same receiver, so tests do not need to import per-helper utilities.
///
/// ### How it works
/// 1. It calls `cell.value` — a synchronous read of the [ValueCell]'s
///    current value.
/// 2. It forwards that value and [matcher] to [expect], along with a
///    `reason` derived from [reason] (if supplied) or from the cell's
///    runtime type.
///
/// ### Design Note: why a `WidgetTester` extension, not a free function
/// Placing the helper on [WidgetTester] is deliberate: it lets tests mix
/// cell assertions with widget-test actions (`tap`, `pump`, `find`) on the
/// same `tester` receiver, and it keeps the helper out of the global
/// namespace so application code that happens to import `flutter_test`
/// does not accidentally see it. The same placement is used by
/// [CellPumpCell.pumpCell] and [CellPumpWithCells.pumpWithCells], so the
/// binding's test helpers are cohesive.
///
/// ### Return value and failure
/// This method returns `void`. On mismatch, it throws a [TestFailure] — the
/// same failure type [expect] raises — with the diagnostic described above.
/// There is no way to make it not throw: it is a strict assertion.
///
/// ### Technical Details
/// - **Generic over [ValueCell]** only: the helper reads `cell.value`
///   synchronously, which is a [ValueCell] capability. Plain `Cell`
///   sources (`Cell.derive`, `Cell.asyncMap`) have no synchronous value —
///   assert on a recorded pulse sequence via
///   [CellRecordPulses.recordPulses] or on the rendered widget via
///   [CellPumpCell.pumpCell] instead.
/// - **The default `reason` names only the runtime type**, not the
///   specific instance — two `Cell<int>` instances in one test still
///   produce the same message. Supply [reason] explicitly when the test has
///   more than one cell of the same value type.
/// - **No cell-side effects**: this helper reads; it does not mutate, does
///   not subscribe, and does not require the recorder or any harness.
///
/// ### Example
/// ```dart
/// tester.expectCellValue(counter.cell, 5);
/// tester.expectCellValue(auth.cell, isA<SignedIn>(),
///   reason: 'after sign-in');
/// ```
///
/// ### See Also:
/// - [ValueCell] — the cell type this helper asserts on.
/// - [CellRecordPulses.recordPulses] — for asserting a pulse *sequence*
///   rather than a current value.
/// - [CellPumpCell.pumpCell] / [CellPumpWithCells.pumpWithCells] — the
///   companion pumping helpers, also extensions on [WidgetTester].
/// - [expect] — the matcher call this helper forwards to.
extension CellExpectValue on WidgetTester {
  /// Asserts that [cell]'s current value matches [matcher].
  ///
  /// Sugar over `expect(cell.value, matcher)` with a diagnostic `reason`
  /// that names the cell. Throws [TestFailure] on mismatch.
  ///
  /// ### Parameters:
  /// * [cell]: **The Asserted Cell.** Must be a [ValueCell] — the helper
  ///   reads `.value` synchronously. For plain `Cell` sources, assert on a
  ///   recorded pulse sequence or a rendered widget instead.
  /// * [matcher]: **The Expected Value.** Any matcher accepted by [expect]
  ///   — a literal value, `isA<T>()`, `predicate(...)`, and so on.
  /// * [reason]: **Optional Failure Context.** If supplied, it replaces the
  ///   default reason; otherwise the default reason names the cell's
  ///   runtime type. Supply it when the test has more than one cell of the
  ///   same value type, so the failure message identifies which one.
  ///
  /// ### Throws:
  /// [TestFailure] — the same failure type [expect] raises — when [cell]'s
  /// current value does not match [matcher]. The reason attached to the
  /// failure is [reason] when supplied; otherwise
  /// `'for cell ${cell.runtimeType}'`.
  ///
  /// ### See Also:
  /// - [CellExpectValue] — the extension-level docs, including the
  ///   diagnostic rationale.
  /// - [expect] — the underlying matcher call.
  void expectCellValue<V>(
    ValueCell<V> cell,
    Object? matcher, {
    String? reason,
  }) {
    expect(
      cell.value,
      matcher,
      reason: reason ?? 'for cell ${cell.runtimeType}',
    );
  }
}
