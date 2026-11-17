// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Dogfooding integration tests: login → list → detail →
// settings, error-boundary break/recovery, restoration persistence,
// router mirroring, persisted nickname, and the in-app inspector.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';
import 'package:cell_flutter_router/hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:production_app/main.dart';
import 'package:production_app/screens/list_screen.dart';
import 'package:production_app/screens/login_screen.dart';
import 'package:production_app/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

GoRouter makeRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const CellInspectorOverlay(child: LoginScreen()),
        ),
        GoRoute(
          path: '/list',
          builder: (context, state) =>
              ListScreen(email: state.extra as String? ?? ''),
        ),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    );

SharedPreferencesAsync makePrefs() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  return SharedPreferencesAsync();
}

void main() {
  tearDown(CellFlutterDevTools.resetForTesting);

  Future<void> login(WidgetTester tester) async {
    CellFlutterDevTools.enable();
    await tester.pumpWidget(
      ProductionApp(router: makeRouter(), preferences: makePrefs()),
    );
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Email'), 'user@example.com');
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Password'), 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('full user journey: login, list, detail, settings, inspector',
      (tester) async {
    await login(tester);

    // Login validation ran; the list screen shows the email and lazily
    // renders the 120 items.
    expect(find.text('Welcome, user@example.com'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 120'), findsNothing);

    // Detail.
    await tester.tap(find.text('Item 3'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);

    // Settings: restoration-backed field + router badge.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('/settings'), findsOneWidget, reason: 'route badge');
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Nickname'), 'simon-l');
    await tester.pump();
    expect(find.text('simon-l'), findsOneWidget);

    // Back to login through the router bridge (the logout button in the
    // settings app bar) — the inspector overlay lives on the home route.
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    await tester.tap(find.byTooltip('Cell Inspector'));
    await tester.pump();
    expect(find.textContaining('login.email'), findsOneWidget);
    // The inspector lists live registrations; settings was disposed on logout.
  });

  testWidgets('error boundary contains a broken cell and recovers',
      (tester) async {
    await login(tester);
    await tester.tap(find.text('Item 3'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Break it'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Something broke'), findsOneWidget);

    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 3'), findsOneWidget);
  });

  testWidgets('settings restoration writes into the restoration bucket',
      (tester) async {
    CellFlutterDevTools.enable();
    await tester.pumpWidget(ProductionApp(
      router: makeRouter(),
      preferences: makePrefs(),
      restorationBucket: RestorationBucket.empty(
        restorationId: 'production-app',
        debugOwner: 'test',
      ),
    ));
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Email'), 'user@example.com');
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Password'), 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Nickname'), 'persisted-name');
    await tester.pump();
    expect(find.text('persisted-name'), findsOneWidget);

    // The app-level CellRestorationScope serializes the edited nickname
    // into its claimed child bucket.
    final scope = tester.state<CellRestorationScopeState>(
      find.byElementPredicate(
        (e) => e is StatefulElement && e.state is CellRestorationScopeState,
        // The scope sits under the login route, which is offstage once the
        // settings route covers it.
        skipOffstage: false,
      ),
    );
    expect(scope.bucket!.read<String>('settings.nickname'), 'persisted-name');
  });

  testWidgets('the route mirror tracks navigation reactively',
      (tester) async {
    CellFlutterDevTools.enable();
    final router = makeRouter();
    await tester.pumpWidget(
      ProductionApp(router: router, preferences: makePrefs()),
    );

    // Mirror the route into a cell and navigate the bridge.
    final routeCell = routerState(restorationId: 'router');
    await tester.pumpWidget(ProductionApp(
      router: router,
      preferences: makePrefs(),
      restorationBucket: RestorationBucket.empty(
        restorationId: 'production-app',
        debugOwner: 'test',
      ),
    ));

    // The login flow drives router.go('/list') — the mirror follows.
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Email'), 'user@example.com');
    await tester.enterText(
        find.widgetWithText(CellTextField, 'Password'), 'secret123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    final mirror = CellRouterStateMirror(
      router: router,
      stateCell: routeCell,
      child: const SizedBox.shrink(),
    );
    await tester.pumpWidget(mirror);
    await tester.pumpAndSettle();
    expect(routeCell.value?.location, '/list');
  });

  testWidgets('the persisted nickname prefills the login email',
      (tester) async {
    CellFlutterDevTools.enable();
    final prefs = makePrefs();
    await SharedPreferencesAdapter.string(prefs).write('nickname', 'alice');

    await tester.pumpWidget(ProductionApp(router: makeRouter(), preferences: prefs));
    await tester.pumpAndSettle(); // load() completes + rebuild

    final field = tester.widget<CellTextField>(
      find.widgetWithText(CellTextField, 'Email'),
    );
    expect(field.cell.value, 'alice');
  });
}
