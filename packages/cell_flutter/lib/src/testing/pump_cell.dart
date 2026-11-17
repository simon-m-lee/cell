// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An extension on [WidgetTester] that pumps a bare `CellBuilder` over a
/// [ValueCell].
///
/// [CellPumpCell] is the binding's **Single-Cell Test Harness**. It is the
/// smallest possible test-tree for a `CellBuilder`-driven widget: a
/// `MaterialApp` wrapper for `Text`-based children that need an ambient
/// `TextStyle`, a `Scaffold` body slot to satisfy widgets that expect one,
/// and the `CellBuilder` itself. Nothing else — no [CellScope], no
/// navigation, no theme override.
///
/// ### Why it is used
/// - **Zero-boilerplate rendering**: most widget tests only need to render
///   one cell through one builder and assert on the resulting text or
///   widget. This extension expresses that in a single call.
/// - **Material-ambient defaults**: a bare `pumpWidget(CellBuilder(...))`
///   lacks the `MaterialApp` + `Scaffold` context that `Text`, `Icon`,
///   `Material`, and theme-dependent widgets rely on. This extension
///   supplies exactly that frame.
/// - **A clean failure mode**: because no [CellScope] is installed, a
///   widget under test that calls [CellScope.of] will fail loudly (its
///   assertion fires) instead of silently resolving against an unintended
///   scope. Tests that *do* need scoped lookups should use
///   [CellPumpWithCells.pumpWithCells] instead — the two are deliberately
///   distinct.
///
/// ### How it works
/// 1. The provided [builder] is wrapped in a `CellBuilder<V>` bound to
///    [cell].
/// 2. The `CellBuilder` is placed in a `Scaffold` body, which is itself
///    wrapped in a `MaterialApp`.
/// 3. [WidgetTester.pumpWidget] is called once and the returned [Future]
///    is forwarded, so callers can `await tester.pumpCell(...)` exactly as
///    they would `await tester.pumpWidget(...)`.
///
/// ### Design Note: why no `CellScope`
/// Installing a `CellScope` here would be a convenience for the minority
/// of tests that need scoped lookups, but a hazard for the majority that
/// don't: a widget that *should* be resolving its own cell via a
/// constructor argument would silently resolve against the ambient scope
/// instead, and the test would pass for the wrong reason. The absence is
/// intentional — tests that need a scope opt in by calling
/// `pumpWithCells` explicitly.
///
/// ### Return value
/// The [Future] returned by [WidgetTester.pumpWidget]. Resolves once the
/// first frame has been built. Widgets whose first visible state depends
/// on a post-frame or async completion need an additional
/// `await tester.pump(...)` — same as with `pumpWidget`.
///
/// ### Hooks and richer widget types
/// This extension renders exactly one `CellBuilder`. When the widget
/// under test is not a plain `CellBuilder` — a hook-based widget
/// (from `flutter_hooks`, or a Mitosis hooks layer if one is present), a
/// `StatefulWidget` in a non-Material frame, or a widget that needs a
/// `Navigator` — build the frame directly:
///
/// ```dart
/// await tester.pumpWidget(
///   MaterialApp(home: Scaffold(body: HookBuilder(...))),
/// );
/// ```
///
/// Any such widget composes fine inside that frame; the frame this
/// extension supplies is exactly the one to reproduce.
///
/// ### Technical Details
/// - **Single pump**: this extension pumps once. Additional `pump`s are the
///   caller's responsibility, as with any `pumpWidget`-based helper.
/// - **Requires a [ValueCell]**: `CellBuilder` takes `ValueCell<V>`, so
///   this extension does too. Plain-cell sources (`Cell.derive`,
///   `Cell.synthesis`, `Cell.asyncMap`) must be mirrored via
///   `asValueCell` or rendered with a `CellValueBuilder` under a
///   hand-built `pumpWidget` frame.
/// - **Stateless extension**: it registers no teardown. Any recorders or
///   cell invalidation the test needs must be registered separately (see
///   e.g. [CellRecordPulses.recordPulses] and `addTearDown`).
///
/// ### Example
/// ```dart
/// testWidgets('displays cell value', (tester) async {
///   final counter = Cell.state<int>(initial: 0);
///   await tester.pumpCell(
///     cell: counter.cell,
///     builder: (_, v) => Text('value: $v'),
///   );
///   expect(find.text('value: 0'), findsOneWidget);
/// });
/// ```
///
/// ### See Also:
/// - [CellPumpWithCells.pumpWithCells] — the [CellScope]-installing
///   variant for tests that need scoped cell lookups.
/// - `CellBuilder` — the widget this extension pumps.
/// - [WidgetTester.pumpWidget] — the Flutter primitive this wraps.
/// - [CellRecordPulses.recordPulses] — a companion test helper for
///   asserting pulse sequences.
extension CellPumpCell on WidgetTester {
  /// Pumps a bare `CellBuilder` over [cell] inside a default
  /// `MaterialApp` + `Scaffold` frame.
  ///
  /// No [CellScope] is installed; widgets under test that require one
  /// should be pumped via [CellPumpWithCells.pumpWithCells] instead.
  ///
  /// ### Parameters:
  /// * [cell]: **The Rendered Cell.** Must be a [ValueCell] because
  ///   `CellBuilder` requires a synchronous current value. Use
  ///   `asValueCell` or `CellValueBuilder` for plain-`Cell` sources.
  /// * [builder]: **The Render Callback.** Called on initial build and
  ///   whenever [cell] emits a new value. Same contract as
  ///   `CellBuilder.builder` — receives `V?`.
  ///
  /// ### Returns:
  /// The [Future] from [WidgetTester.pumpWidget] — resolves once the first
  /// frame has been built.
  ///
  /// ### See Also:
  /// - [CellPumpCell] — the extension-level docs, including the rationale
  ///   for omitting a [CellScope].
  /// - [CellPumpWithCells.pumpWithCells] — the scoped-lookup variant.
  Future<void> pumpCell<V>({
    required ValueCell<V> cell,
    required Widget Function(BuildContext context, V? value) builder,
  }) {
    return pumpWidget(MaterialApp(
      home: Scaffold(
        body: CellBuilder<V>(cell: cell, builder: builder),
      ),
    ));
  }
}
