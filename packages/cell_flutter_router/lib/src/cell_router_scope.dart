// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'cell_router_state.dart';

/// Provides the [GoRouter] and its mirrored state cell to descendants.
///
/// ```dart
/// CellRouterScope(
///   router: router,
///   stateCell: routerState,
///   child: MaterialApp.router(routerConfig: router),
/// );
/// ```
///
/// [CellRouterStateMirror] usually sits next to the scope: the mirror
/// keeps the cell in sync with the router, the scope makes both
/// available to [useCellRouter] and to widgets that read
/// [CellRouterScope.of] directly.
class CellRouterScope extends InheritedWidget {
  /// Creates the scope.
  const CellRouterScope({
    required this.router,
    required this.stateCell,
    required super.child,
    super.key,
  });

  /// The router to navigate with.
  final GoRouter router;

  /// The cell that mirrors the current route.
  final ValueCell<CellRouterState> stateCell;

  /// Returns the nearest enclosing scope, or `null`.
  static CellRouterScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CellRouterScope>();

  /// Returns the nearest enclosing scope.
  ///
  /// ### Throws:
  /// [StateError] when no [CellRouterScope] encloses [context].
  static CellRouterScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw StateError(
        'CellRouterScope.of: no CellRouterScope above this widget. '
        'Wrap the app in a CellRouterScope before using useCellRouter.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(CellRouterScope oldWidget) =>
      !identical(router, oldWidget.router) ||
      !identical(stateCell, oldWidget.stateCell);
}

/// A thin controller over a [GoRouter], returned by [useCellRouter].
///
/// Navigation methods delegate one-to-one to the underlying router's
/// `go` / `push` / `replace` / `pop`; [state] is the mirrored route
/// state at the time the controller was obtained (reactive via the
/// hook).
class CellRouterController {
  /// Creates the controller.
  const CellRouterController({required this.router, required this.state});

  /// The router to navigate with.
  final GoRouter router;

  /// The current route state.
  final CellRouterState state;

  /// Navigates to [location], replacing the current entry.
  void go(String location, {Object? extra}) =>
      router.go(location, extra: extra);

  /// Pushes [location] onto the stack.
  void push(String location, {Object? extra}) =>
      router.push(location, extra: extra);

  /// Replaces the current entry with [location].
  void replace(String location, {Object? extra}) =>
      router.replace(location, extra: extra);

  /// Pops the current route.
  void pop([Object? result]) => router.pop(result);
}
