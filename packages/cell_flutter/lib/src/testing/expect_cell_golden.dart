// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
// Flutter >=3.47 deprecates the material library in favour of
// material_ui; kept for compatibility with the stable SDK used here.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_with_cells.dart';

/// An extension on [WidgetTester] that captures a golden image of a
/// `CellBuilder` over a [ValueCell], at the cell's current value.
///
/// [CellExpectGolden] is the binding's **Golden Capture Helper**. It
/// assembles the same tree that [CellPumpCell.pumpCell] would — a
/// `CellBuilder` inside `MaterialApp(home: Scaffold(...))` — pumps it,
/// then delegates to `matchesGoldenFile` to compare against a reference
/// image. In a single call it replaces the three-step
/// `pumpWidget` + `pump` + `expectLater(..., matchesGoldenFile(...))`
/// sequence that every cell-driven golden test would otherwise repeat.
///
/// ### Why it is used
/// - **One call per snapshot**: golden tests frequently capture several
///   snapshots of the same widget at different cell values. This helper
///   lets each snapshot be a single `await`, keeping the test body readable
///   and making the sequence of expected visual states obvious.
/// - **Correct ambient frame**: a bare `CellBuilder` lacks the
///   `MaterialApp` + `Scaffold` context that `Text` styling,
///   `Material`, and theme-dependent widgets rely on. This helper supplies
///   the same frame in every capture, so goldens are comparable across
///   tests.
/// - **Optional scoped lookups**: when the widget under test needs
///   [CellScope]-provided cells, pass [cells] and the helper routes the
///   capture through [CellPumpWithCells.pumpWithCells] rather than a bare
///   `pumpWidget`.
///
/// ### How it works
/// 1. The [builder] is wrapped in a `CellBuilder<V>` bound to [cell].
/// 2. If [cells] is non-empty, the `CellBuilder` is pumped inside a
///    [CellScope] via [CellPumpWithCells.pumpWithCells] with the same
///    `MaterialApp(home: Scaffold(...))` wrapper. Otherwise a bare
///    `pumpWidget` of the same wrapper is used.
/// 3. `expectLater(find.byType(MaterialApp), matchesGoldenFile(...))` is
///    awaited against the file path resolved from [goldenPath] or the
///    default `goldens/$name.png`.
///
/// ### Design Note: capture the whole `MaterialApp`, not the `Scaffold`
/// The golden matcher targets `find.byType(MaterialApp)`, not the
/// `Scaffold` inside it. That includes the app's ambient Material theme,
/// elevation, and any navigation bars or banner overlays that `MaterialApp`
/// contributes to the rendered pixels. Capturing the `Scaffold` alone would
/// omit that context, and two goldens generated under different ambient
/// themes would compare as if identical. The broader finder makes the
/// captured image a faithful record of what the user actually sees.
///
/// ### Design Note: every call starts from a fresh pump
/// Each `expectCellGolden` call builds and pumps a **new** tree — the
/// previous tree (and any frames pumped against it, e.g. by
/// `emitAndSettle`) is discarded. What matters for the capture is the
/// cell's value at the moment of the call; drive that with a direct
/// mutation (`counter.update(5)` or `cell.value = 5`), not by pumping the
/// tree that is about to be replaced.
///
/// ### Generating and updating goldens
/// Run the test suite with `flutter test --update-goldens` on the
/// **reference platform** to (re)generate baseline images. The reference
/// platform is typically macOS for iOS-shaped goldens; for cross-platform
/// precision, add per-platform overrides (e.g. `goldens/ios/…`,
/// `goldens/android/…`) at the call site via [goldenPath].
///
/// ### Known limitation: text rendering
/// Flutter's default test font renders text as black boxes unless a
/// real-font loader has been installed for the suite. This helper does
/// **not** load fonts — that is a suite-level concern — so a test that
/// captures text-bearing widgets without loading fonts will produce
/// unreadable goldens. The recommended fix is a single `setUpAll` in the
/// test file (or a shared test harness) that calls `loadAppFonts` from
/// `package:golden_toolkit`:
///
/// ```dart
/// setUpAll(() async {
///   await loadAppFonts(); // from package:golden_toolkit
/// });
/// ```
///
/// `golden_toolkit` is a `dev_dependency` of the test suite, **not** of
/// `cell_flutter`. Application code that ships this binding does not need
/// it; only the binding's own golden tests (or an application's own golden
/// suite) do.
///
/// ### Technical Details
/// - **Generic over [ValueCell]** only: `CellBuilder` takes a
///   [ValueCell], so this helper does too. Plain-cell sources
///   (`Cell.derive`, `Cell.synthesis`, `Cell.asyncMap`) must be mirrored
///   via `asValueCell` or captured through a hand-built frame with
///   `CellValueBuilder`.
/// - **Single pump**: the helper performs the `pumpWidget`; callers that
///   need additional frames for post-frame or async completion must `await
///   tester.pump(...)` before invoking this helper (or accept that the
///   capture is of the pre-completion frame).
/// - **File path resolution**: [goldenPath] overrides the default
///   `'goldens/$name.png'` when supplied. Relative paths are resolved the
///   same way `matchesGoldenFile` resolves them — relative to the test
///   file's directory.
/// - **Side effects**: this method pumps and compares; it does not
///   subscribe, record, or otherwise mutate the cell. Any recorder the
///   test needs should be registered separately (see
///   [CellRecordPulses.recordPulses] and `addTearDown`).
///
/// ### Example
/// ```dart
/// testWidgets('counter golden', (tester) async {
///   final counter = Cell.state<int>(initial: 0);
///   await tester.expectCellGolden(
///     cell: counter.cell,
///     builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
///     name: 'counter_zero',
///   );
///
///   // Drive the value directly. Each expectCellGolden call pumps a fresh
///   // tree; pumping the old tree in between (e.g. emitAndSettle) would
///   // only exercise a tree that the next call is about to replace.
///   counter.update(5);
///   await tester.expectCellGolden(
///     cell: counter.cell,
///     builder: (_, v) => Text('$v', style: const TextStyle(fontSize: 48)),
///     name: 'counter_five',
///   );
/// });
/// ```
///
/// ### See Also:
/// - [CellPumpCell.pumpCell] — the non-golden equivalent for a single
///   cell, no scope.
/// - [CellPumpWithCells.pumpWithCells] — the scoped variant this helper
///   delegates to when [cells] is non-empty.
/// - `matchesGoldenFile` — the Flutter primitive this helper invokes.
/// - [CellRecordPulses.recordPulses] — a companion test helper for
///   asserting pulse sequences.
extension CellExpectGolden on WidgetTester {
  /// Captures a golden of a `CellBuilder` over [cell] at the cell's
  /// current value.
  ///
  /// Pumps the widget inside `MaterialApp(home: Scaffold(...))` — with a
  /// [CellScope] above it when [cells] is non-empty — then awaits
  /// `matchesGoldenFile` against the resolved path.
  ///
  /// ### Parameters:
  /// * [cell]: **The Captured Cell.** Must be a [ValueCell] because
  ///   `CellBuilder` requires a synchronous current value. Use
  ///   `asValueCell` or `CellValueBuilder` for plain-`Cell` sources.
  /// * [builder]: **The Render Callback.** Same contract as
  ///   `CellBuilder.builder` — receives `V?` and is called on every pulse.
  ///   The golden is captured from whatever the builder renders at the
  ///   time of the call.
  /// * [name]: **The Golden Name.** Used to build the default path
  ///   `'goldens/$name.png'`; ignored when [goldenPath] is supplied.
  ///   Choose names that are stable across platforms and unambiguous
  ///   within a test file.
  /// * [cells]: **Optional Scope Registration.** When non-empty, the
  ///   widget is pumped inside a [CellScope] holding these cells, via
  ///   [CellPumpWithCells.pumpWithCells]. When empty (the default), a bare
  ///   `pumpWidget` is used — no [CellScope] is installed, matching
  ///   [CellPumpCell.pumpCell]'s behavior.
  /// * [goldenPath]: **Optional Path Override.** Replaces the default
  ///   `'goldens/$name.png'`. Use this for per-platform golden directories
  ///   (`goldens/ios/…`) or for goldens that live outside the default
  ///   path.
  ///
  /// Exactly one of [name] / [goldenPath] must be supplied (asserted in
  /// debug builds; a `null` [name] with a `null` [goldenPath] is a caller
  /// bug).
  ///
  /// ### Returns:
  /// A [Future] that resolves once the golden comparison has completed.
  /// On mismatch, the [Future] completes with the standard
  /// `matchesGoldenFile` failure.
  ///
  /// ### See Also:
  /// - [CellExpectGolden] — the extension-level docs, including the
  ///   text-rendering limitation and golden-generation workflow.
  /// - [CellPumpWithCells.pumpWithCells] — the scoped pump path.
  /// - `matchesGoldenFile` — the underlying comparison primitive.
  Future<void> expectCellGolden<V>({
    required ValueCell<V> cell,
    required Widget Function(BuildContext context, V? value) builder,
    String? name,
    Map<Symbol, Cell> cells = const {},
    String? goldenPath,
  }) async {
    assert(
      goldenPath != null || name != null,
      'expectCellGolden: provide either a name or a goldenPath.',
    );
    final path = goldenPath ?? 'goldens/${name!}.png';
    final widget = CellBuilder<V>(cell: cell, builder: builder);
    if (cells.isNotEmpty) {
      await pumpWithCells(
        cells: cells,
        wrapper: (child) => MaterialApp(home: Scaffold(body: child)),
        child: widget,
      );
    } else {
      await pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  }
}
