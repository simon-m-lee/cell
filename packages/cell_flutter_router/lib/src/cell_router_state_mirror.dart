// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'cell_router_state.dart';

/// Mirrors a [GoRouter]'s route state into a [ValueCell].
///
/// [CellRouterStateMirror] does **not** replace `go_router`'s delegate —
/// the developer's [GoRouter] configuration keeps working unchanged. The
/// mirror listens to the router's delegate and writes a
/// [CellRouterState] into [stateCell] on every route change (go, push,
/// replace, pop, deep links), so widgets can read the current route
/// reactively:
///
/// ```dart
/// CellRouterStateMirror(
///   router: router,
///   stateCell: routerState(restorationId: 'router'),
///   child: MaterialApp.router(routerConfig: router),
/// );
/// ```
///
/// ### Placement
/// The mirror itself renders [child] unchanged and can wrap the whole
/// `MaterialApp.router`. The state cell updates synchronously with the
/// delegate notification.
///
/// ### Restoration
/// Pair `routerState` (a `RestorableCell`) with a
/// `CellRestorationScope` and the route survives process kill; deep
/// links restored from the OS go through `go_router`'s normal
/// `routeInformationProvider` path and are mirrored the same way.
class CellRouterStateMirror extends StatefulWidget {
  /// Creates the mirror.
  const CellRouterStateMirror({
    required this.router,
    required this.stateCell,
    required this.child,
    super.key,
  });

  /// The [GoRouter] to observe.
  final GoRouter router;

  /// The cell that receives the current [CellRouterState].
  final ValueCell<CellRouterState> stateCell;

  /// The app subtree, rendered unchanged.
  final Widget child;

  @override
  State<CellRouterStateMirror> createState() => _CellRouterStateMirrorState();
}

class _CellRouterStateMirrorState extends State<CellRouterStateMirror> {
  @override
  void initState() {
    super.initState();
    _attach(widget.router);
    _sync();
  }

  @override
  void didUpdateWidget(CellRouterStateMirror oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.router, widget.router)) {
      _detach(oldWidget.router);
      _attach(widget.router);
      _sync();
    }
    if (!identical(oldWidget.stateCell, widget.stateCell)) {
      _sync();
    }
  }

  @override
  void dispose() {
    _detach(widget.router);
    super.dispose();
  }

  void _attach(GoRouter router) {
    // Both notifiers fire at different points of a route change: the
    // information provider notifies *before* the delegate processes the
    // change, the delegate notifies *after* (on pops). Listening to both
    // and deferring a second read to a post-frame callback guarantees
    // the configuration observed is always post-update.
    router.routeInformationProvider.addListener(_onChanged);
    router.routerDelegate.addListener(_onChanged);
  }

  void _detach(GoRouter router) {
    router.routeInformationProvider.removeListener(_onChanged);
    router.routerDelegate.removeListener(_onChanged);
  }

  void _onChanged() {
    // Immediate read (delegate-already-updated notifications) plus a
    // post-frame catch-up (provider-before-delegate orderings). The
    // equality guard in _sync makes the extra run free.
    _sync();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sync();
      }
    });
  }

  /// Reads the delegate's current configuration and writes it into the
  /// state cell. Equality-guarded: an unchanged route emits no pulse.
  void _sync() {
    // In go_router 14+ the delegate's currentConfiguration is a
    // RouteMatchList, not a GoRouterState. Imperative navigations
    // (push/replace) keep the list's base uri; the live location is the
    // top match's matchedLocation.
    final configuration = widget.router.routerDelegate.currentConfiguration;
    final topMatch =
        configuration.matches.isEmpty ? null : configuration.matches.last;
    final location = topMatch is ImperativeRouteMatch
        ? topMatch.matchedLocation
        : configuration.uri.toString();
    final uri = Uri.parse(location);
    final next = CellRouterState(
      location: location,
      queryParams: {
        for (final entry in uri.queryParameters.entries) entry.key: entry.value,
      },
      extra: configuration.extra,
    );
    if (widget.stateCell.value == next) {
      return;
    }
    widget.stateCell.value = next;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
