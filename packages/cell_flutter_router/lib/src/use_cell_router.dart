// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/hooks.dart';
import 'package:cell_flutter_router/cell_flutter_router.dart';

/// Returns a reactive router controller for the nearest
/// [CellRouterScope].
///
/// The returned controller rebuilds the calling hook whenever the
/// mirrored route state changes; its navigation methods delegate to the
/// scope's [GoRouter]:
///
/// ```dart
/// class DetailButton extends HookWidget {
///   @override
///   Widget build(BuildContext context) {
///     final router = useCellRouter();
///     return TextButton(
///       onPressed: () => router.go('/detail/42'),
///       child: const Text('Open detail'),
///     );
///   }
/// }
/// ```
///
/// ### Throws:
/// [StateError] when no [CellRouterScope] encloses the calling widget.
CellRouterController useCellRouter() {
  final context = useContext();
  final scope = CellRouterScope.of(context);
  final state = useCell<CellRouterState, CellRouterState>(
    cell: scope.stateCell,
    select: (value) => value ?? const CellRouterState(location: '/'),
  );
  return CellRouterController(router: scope.router, state: state);
}

/// Restorable route-state factory.
///
/// Creates a [RestorableCell] holding a [CellRouterState], persisted
/// through Flutter's restoration protocol (JSON codecs; the `extra`
/// field is not restored — see [CellRouterState]). Pair with a
/// `CellRestorationScope` for the route to survive process kill.
///
/// (A `Cell.routerState` extension spelling is not reachable from
/// another package — Dart extension statics belong to the extension,
/// not the extended type — so the factory ships as this top-level
/// function.)
RestorableCell<CellRouterState> routerState({
  required String restorationId,
  CellRouterState? initial,
}) {
  return restorableState<CellRouterState>(
    restorationId: restorationId,
    initial: initial ?? const CellRouterState(location: '/'),
    toPrimitives: (state) => state?.toJson(),
    fromPrimitives: (data) => CellRouterState.fromJson(
      data is Map<Object?, Object?> ? data : const {},
    ),
  );
}
