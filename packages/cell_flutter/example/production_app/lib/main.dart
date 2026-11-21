// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The dogfooding app. Every screen exercises a different part
// of the cell_flutter surface:
//
//   login    — CellFormField / CellTextField + Form.validate()
//              + PersistedCell (nickname prefill)
//   list     — CellListView.builder over 120 derived cells
//   detail   — CellBuilder + CellErrorBoundary + cell-driven navigation
//   settings — restorableState + CellRestorationScope + CellTextField
//              + useCellRouter (route badge)
//
// Run with: flutter run (and flutter test in test/).

import 'package:cell_flutter/cell_flutter.dart';
// The dedicated entry point; the barrel re-export goes away in 2.0.
// ignore: unnecessary_import
import 'package:cell_flutter/devtools.dart';
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';
import 'package:cell_flutter_router/hooks.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CellFlutterDevTools.enable(); // Opt-in in-app inspector (dev only).
  runApp(ProductionApp(router: _productionRouter()));
}

/// The real backend: SharedPreferencesAsync.
SharedPreferencesAsync _productionPrefs() => SharedPreferencesAsync();

GoRouter _productionRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const CellInspectorOverlay(child: LoginScreen()),
        ),
        GoRoute(
          path: '/list',
          builder: (context, state) => ListScreen(
            email: state.extra as String? ?? '',
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

class ProductionApp extends StatefulWidget {
  const ProductionApp({
    required this.router,
    this.restorationBucket,
    this.preferences,
    super.key,
  });

  /// The go_router instance driving navigation.
  final GoRouter router;

  /// Optional pre-built restoration bucket (tests / hot-restart tooling);
  /// production passes null and claims from the engine as usual.
  final RestorationBucket? restorationBucket;

  /// Optional preferences backend (tests); production defaults to
  /// `SharedPreferencesAsync()`.
  final SharedPreferencesAsync? preferences;

  @override
  State<ProductionApp> createState() => _ProductionAppState();
}

class _ProductionAppState extends State<ProductionApp> {
  late final PersistedCell<String> _nickname;

  @override
  void initState() {
    super.initState();
    _nickname = persistedState<String>(
      restorationId: 'nickname',
      initial: 'simon',
      adapter: SharedPreferencesAdapter.string(
        widget.preferences ?? _productionPrefs(),
      ),
      writeMode: WriteMode.debounced,
    );
    _nickname.start();
    _nickname.load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeCell = routerState(restorationId: 'router');

    return CellRouterStateMirror(
      router: widget.router,
      stateCell: routeCell,
      child: CellRouterScope(
        router: widget.router,
        stateCell: routeCell,
        child: NicknameProvider(
          nickname: _nickname,
          child: MaterialApp.router(
            title: 'cell_flutter production app',
            theme: ThemeData(useMaterial3: true),
            // The builder wraps the Navigator, so the restoration scope
            // covers every route (pushed routes are siblings of `home`,
            // not children).
            builder: (context, child) => CellRestorationScope(
              restorationScopeId: 'production-app',
              bucket: widget.restorationBucket,
              child: _RestorationRegistrations(
                nickname: _nickname,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            routerConfig: widget.router,
          ),
        ),
      ),
    );
  }
}

/// Registers the app-level persisted cells with the enclosing
/// [CellRestorationScope] (must live under it).
class _RestorationRegistrations extends StatefulWidget {
  const _RestorationRegistrations({
    required this.nickname,
    required this.child,
  });

  final PersistedCell<String> nickname;
  final Widget child;

  @override
  State<_RestorationRegistrations> createState() =>
      _RestorationRegistrationsState();
}

class _RestorationRegistrationsState extends State<_RestorationRegistrations> {
  @override
  void initState() {
    super.initState();
    CellRestorationScope.maybeOf(context)?.register(widget.nickname.cell);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Passes the persisted nickname cell down to the screens.
class NicknameProvider extends InheritedWidget {
  const NicknameProvider({
    required this.nickname,
    required super.child,
    super.key,
  });

  final PersistedCell<String> nickname;

  static PersistedCell<String>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NicknameProvider>()
      ?.nickname;

  @override
  bool updateShouldNotify(NicknameProvider oldWidget) =>
      !identical(nickname, oldWidget.nickname);
}
