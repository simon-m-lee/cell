// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Canonical `cell_flutter_router` example: the current route location is
/// mirrored into a reactive cell and rendered by a `CellBuilder`.
library;

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_router/hooks.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  GoRoute(path: '/detail', builder: (context, state) => const DetailScreen()),
]);

final RestorableCell<CellRouterState> _stateCell =
    routerState(restorationId: 'router');

void main() => runApp(
      CellRouterStateMirror(
        router: _router,
        stateCell: _stateCell,
        child: MaterialApp.router(routerConfig: _router),
      ),
    );

/// Root screen: shows the mirrored route location and navigates to
/// `/detail`.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('cell_flutter_router example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CellBuilder<CellRouterState>(
              cell: _stateCell,
              builder: (_, state) =>
                  Text('Location: ${state?.location ?? '/'}'),
            ),
            TextButton(
              onPressed: () => context.go('/detail'),
              child: const Text('Go to /detail'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail screen reached at `/detail`; navigates back to `/`.
class DetailScreen extends StatelessWidget {
  /// Creates the detail screen.
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Back to /'),
        ),
      ),
    );
  }
}
