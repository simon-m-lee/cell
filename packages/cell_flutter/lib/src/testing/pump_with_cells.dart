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

/// An extension on [WidgetTester] that pumps a widget inside a [CellScope].
///
/// [CellPumpWithCells] is the binding's **Test Tree Seeder** — a one-call
/// replacement for the `pumpWidget(CellScope(cells: …, child: MaterialApp(…)))`
/// boilerplate that every widget test using app-level cells would otherwise
/// repeat. It combines the two steps a test needs: registering the cells in
/// a [CellScope] above the widget under test, and pumping that tree with a
/// Material wrapper that provides `Scaffold`, `Navigator`, and the default
/// theme.
///
/// ### Why it is used
/// - **Correct tree shape**: any widget that calls [CellScope.of] /
///   [CellScope.maybeOf] / [CellScope.valueOf] requires a [CellScope]
///   ancestor. This extension guarantees one exists, above a default
///   `MaterialApp` + `Scaffold`, without each test spelling out the
///   nesting.
/// - **Material defaults**: a bare widget tree lacks a `Scaffold` and
///   `Navigator`, which many widgets assume (dialogs, snackbars,
///   `Theme.of`). The default wrapper supplies them.
/// - **Overridable wrapper**: tests that need a `GlobalKey` navigator, a
///   specific theme, or a `MaterialApp.router` can pass [wrapper] and get
///   the same cell registration.
///
/// ### How it works
/// 1. The [child] is wrapped — by [wrapper] if supplied, otherwise by a
///    default `MaterialApp(home: Scaffold(body: child))`.
/// 2. The wrapped tree is placed inside a [CellScope] holding [cells].
/// 3. [WidgetTester.pumpWidget] is called once and the returned [Future]
///    is forwarded, so the caller can `await tester.pumpWithCells(...)`
///    exactly as they would `await tester.pumpWidget(...)`.
///
/// ### Design Note: why the [CellScope] sits *outside* the [wrapper]
/// The scope wraps the wrapper, not the other way around. That means a
/// custom [wrapper] — a `MaterialApp` with a `navigatorKey`, for instance —
/// is itself inside the [CellScope], so widgets constructed by the wrapper
/// (route builders, splash-screen overlays) can also resolve cells. It also
/// matches how a production app is typically assembled: the app root that
/// installs global cells sits *above* the `MaterialApp`.
///
/// ### Return value
/// The [Future] returned by [WidgetTester.pumpWidget]. Resolves once the
/// first frame has been built; call [WidgetTester.pump] afterward for
/// subsequent frame-driven updates.
///
/// ### Technical Details
/// - **Single pump**: this extension pumps once. Widgets whose first
///   visible state depends on a post-frame or an async completion need an
///   additional `await tester.pump(...)` — same as with `pumpWidget`.
/// - **Stateless extension**: it adds no per-test state and no tear-down
///   hooks. Any recorders, subscriptions, or cell invalidation that the
///   test needs must be registered separately (see e.g.
///   [CellRecordPulses.recordPulses] and `addTearDown`).
/// - **Wrapper signature is `Widget Function(Widget child)`**: it receives
///   the already-`CellScope`-free child (the scope is installed outside
///   the wrapper) and returns the widget to pump.
///
/// ### Example: default wrapper
/// ```dart
/// testWidgets('counter renders', (tester) async {
///   final counter = Cell.state<int>(initial: 42);
///   await tester.pumpWithCells(
///     cells: {#counter: counter.cell},
///     child: CellBuilder<int>(
///       cell: counter.cell,
///       builder: (_, v) => Text('$v'),
///     ),
///   );
///   expect(find.text('42'), findsOneWidget);
/// });
/// ```
///
/// ### Example: custom wrapper with a `navigatorKey`
/// ```dart
/// final navKey = GlobalKey<NavigatorState>();
/// await tester.pumpWithCells(
///   cells: {#auth: auth.cell},
///   wrapper: (child) => MaterialApp(
///     navigatorKey: navKey,
///     home: child,
///   ),
///   child: const LoginScreen(),
/// );
/// ```
///
/// ### See Also:
/// - [CellScope] — the registry this extension installs above the widget.
/// - [WidgetTester.pumpWidget] — the Flutter primitive this wraps.
/// - [CellRecordPulses.recordPulses] — a companion test helper for
///   asserting pulse sequences.
/// - [CellTestHarness] — a higher-level harness for tests that need cell
///   lifecycle management alongside pumping.
extension CellPumpWithCells on WidgetTester {
  /// Pumps [child] inside a [CellScope] pre-populated with [cells].
  ///
  /// Wraps [child] in [wrapper] if supplied; otherwise in a default
  /// `MaterialApp(home: Scaffold(body: child))`. The [CellScope] is
  /// installed **outside** the wrapper, so widgets built by the wrapper
  /// can also resolve cells through [CellScope].
  ///
  /// ### Parameters:
  /// * [cells]: **The Registration Map.** `Symbol`-keyed cells placed in
  ///   the [CellScope] installed above [child]. Use the same `Symbol`s the
  ///   widget under test will look up via [CellScope.of] /
  ///   [CellScope.valueOf].
  /// * [child]: **The Widget Under Test.** Placed inside [wrapper] and
  ///   beneath the [CellScope].
  /// * [wrapper]: **Optional Tree Override.** A function that takes the
  ///   [child] and returns the widget to place inside the [CellScope].
  ///   Useful for supplying a `navigatorKey`, a specific theme, or a
  ///   router. When omitted, the default `MaterialApp(home: Scaffold(body:
  ///   child))` is used.
  ///
  /// ### Returns:
  /// The [Future] from [WidgetTester.pumpWidget] — resolves once the first
  /// frame has been built.
  ///
  /// ### See Also:
  /// - [CellPumpWithCells] — the extension-level docs, including the
  ///   rationale for placing the [CellScope] outside the [wrapper].
  /// - [CellScope] — the registry installed above the tree.
  Future<void> pumpWithCells({
    required Map<Symbol, Cell> cells,
    required Widget child,
    Widget Function(Widget child)? wrapper,
  }) {
    final wrapped = wrapper != null
        ? wrapper(child)
        : MaterialApp(home: Scaffold(body: child));
    return pumpWidget(CellScope(cells: cells, child: wrapped));
  }
}
