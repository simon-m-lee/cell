// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// The go_router bridge — state, mirror, scope, controller, and
// restoration.

import 'package:cell_flutter/hooks.dart';
import 'package:cell_flutter_router/hooks.dart';
import 'package:cell_flutter_router/hooks.dart' as router_hooks;
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter makeRouter({String? initialLocation, List<GoRoute>? routes}) {
  return GoRouter(
    initialLocation: initialLocation ?? '/',
    routes: routes ??
        [
          GoRoute(path: '/', builder: (context, state) => const Text('home')),
          GoRoute(
            path: '/detail/:id',
            builder: (context, state) =>
                Text('detail ${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Text('settings'),
          ),
        ],
  );
}

Widget appWithMirror(
  GoRouter router,
  ValueCell<CellRouterState> stateCell, {
  Widget? child,
}) {
  return CellRouterStateMirror(
    router: router,
    stateCell: stateCell,
    child: child ?? MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('CellRouterState', () {
    test('construction, equality, and hash', () {
      const a = CellRouterState(location: '/detail/42', queryParams: {
        'tab': 'info',
      });
      const b = CellRouterState(location: '/detail/42', queryParams: {
        'tab': 'info',
      });
      const c = CellRouterState(location: '/detail/42');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.extra, isNull);
    });

    test('toJson/fromJson round-trips location and query params', () {
      const original = CellRouterState(location: '/x?y=1&z=2', queryParams: {
        'y': '1',
        'z': '2',
      });
      final restored = CellRouterState.fromJson(original.toJson());

      expect(restored.location, original.location);
      expect(restored.queryParams, original.queryParams);
      expect(restored.extra, isNull);
    });

    test('extra is deliberately excluded from persistence', () {
      const state = CellRouterState(location: '/x', extra: 42);
      expect(state.extraIsJsonSafe, isTrue); // numbers are JSON-safe,
      // but toJson still drops it:
      final restored = CellRouterState.fromJson(state.toJson());
      expect(restored.extra, isNull);
    });

    test('non-JSON-safe extras are detected', () {
      final state = CellRouterState(location: '/x', extra: Object());
      expect(state.extraIsJsonSafe, isFalse);
    });

    test('toString is readable', () {
      const state = CellRouterState(location: '/a', queryParams: {'b': 'c'});
      expect(state.toString(), contains('/a'));
      expect(state.toString(), contains('b'));
    });
  });

  group('Cell.routerState', () {
    test('creates a restorable cell with the initial location', () {
      final cell = routerState(
        restorationId: 'router',
        initial: const CellRouterState(location: '/settings'),
      );
      expect(cell.value?.location, '/settings');
    });

    testWidgets('restores the location from the restoration bucket',
        (tester) async {
      final cell = routerState(restorationId: 'router');

      await tester.pumpWidget(MaterialApp(
        home: CellRestorationScope(
          restorationScopeId: 'router-scope',
          bucket: _bucketWith({
            'router': {
              'location': '/detail/7',
              'queryParams': <Object?, Object?>{},
            },
          }),
          child: _RouterRegistrationHost(cell: cell),
        ),
      ));

      expect(cell.value?.location, '/detail/7');
    });
  });

  group('CellRouterStateMirror', () {
    testWidgets('mirrors the initial route', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      expect(stateCell.value?.location, '/');
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('updates the cell on go', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      router.go('/detail/42');
      await tester.pumpAndSettle();

      expect(stateCell.value?.location, '/detail/42');
      expect(find.text('detail 42'), findsOneWidget);
    });

    testWidgets('updates the cell on push and pop', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      router.push('/settings');
      await tester.pumpAndSettle();
      expect(stateCell.value?.location, '/settings');

      router.pop();
      await tester.pumpAndSettle();
      expect(stateCell.value?.location, '/');
    });

    testWidgets('preserves query parameters', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      router.go('/detail/3?tab=info&sort=asc');
      await tester.pumpAndSettle();

      expect(stateCell.value?.queryParams['tab'], 'info');
      expect(stateCell.value?.queryParams['sort'], 'asc');
    });

    testWidgets('carries extras while live', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      final extra = Object();
      router.go('/settings', extra: extra);
      await tester.pumpAndSettle();

      expect(stateCell.value?.extra, same(extra));
    });

    testWidgets('mirrors a deep link (initialLocation)', (tester) async {
      final router = makeRouter(initialLocation: '/detail/9');
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(router, stateCell));
      await tester.pumpAndSettle();

      expect(stateCell.value?.location, '/detail/9');
      expect(find.text('detail 9'), findsOneWidget);
    });

    testWidgets('does not emit for an unchanged route', (tester) async {
      final router = makeRouter();
      var updates = 0;
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;
      Cell.observe<Pulse<Object?>>(
        source: stateCell,
        effect: (_) => updates++,
        initiallyStarted: true,
      );

      await tester.pumpWidget(appWithMirror(router, stateCell));
      final afterMount = updates;

      router.go('/');
      await tester.pumpAndSettle();
      expect(updates, afterMount, reason: 'same route emits no pulse');
    });

    testWidgets('re-syncs when the router is swapped', (tester) async {
      final first = makeRouter();
      final second = makeRouter(initialLocation: '/detail/1');
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(appWithMirror(first, stateCell));
      expect(stateCell.value?.location, '/');

      await tester.pumpWidget(appWithMirror(second, stateCell));
      await tester.pumpAndSettle();
      expect(stateCell.value?.location, '/detail/1');
    });

    testWidgets('widgets react to the mirrored state cell', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(
        CellRouterStateMirror(
          router: router,
          stateCell: stateCell,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Column(children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              CellBuilder<CellRouterState>(
                cell: stateCell,
                builder: (context, state) =>
                    Text('route:${state?.location ?? ''}'),
              ),
            ]),
          ),
        ),
      );
      expect(find.text('route:/'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('route:/settings'), findsOneWidget);
    });
  });

  group('CellRouterScope + useCellRouter', () {
    testWidgets('of() throws without a scope', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));
      expect(() => CellRouterScope.of(context), throwsStateError);
    });

    testWidgets('useCellRouter navigates and rebuilds on route changes',
        (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(
        CellRouterStateMirror(
          router: router,
          stateCell: stateCell,
          child: CellRouterScope(
            router: router,
            stateCell: stateCell,
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => Column(children: [
                Expanded(child: child ?? const SizedBox.shrink()),
                const _RouterButton(),
              ]),
            ),
          ),
        ),
      );

      expect(find.text('at:/'), findsOneWidget);
      await tester.tap(find.text('go to settings'));
      await tester.pumpAndSettle();
      expect(find.text('at:/settings'), findsOneWidget);
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('useCellRouter throws without a scope', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      // Record reported errors while forwarding to the test binding; the
      // hook's StateError must be among them.
      final reported = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        reported.add(details);
        original?.call(details);
      };

      await tester.pumpWidget(
        CellRouterStateMirror(
          router: router,
          stateCell: stateCell,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Column(children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              const _UnscopedRouterButton(),
            ]),
          ),
        ),
      );
      FlutterError.onError = original;

      expect(reported.where((d) => d.exception is StateError), isNotEmpty,
          reason: 'the scope StateError must be among the reported errors');
      expect(
        reported
            .where((d) => d.exception is StateError)
            .first
            .exception
            .toString(),
        contains('no CellRouterScope'),
      );

      // Drain the binding's pending exceptions so the test ends cleanly.
      while (tester.takeException() != null) {}
    });

    testWidgets('controller pop delegates to go_router', (tester) async {
      final router = makeRouter();
      final stateCell = Cell.state<CellRouterState>(
        initial: const CellRouterState(location: '/'),
      ).cell;

      await tester.pumpWidget(
        CellRouterStateMirror(
          router: router,
          stateCell: stateCell,
          child: CellRouterScope(
            router: router,
            stateCell: stateCell,
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => Column(children: [
                Expanded(child: child ?? const SizedBox.shrink()),
                const _PushPopButtons(),
              ]),
            ),
          ),
        ),
      );

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(stateCell.value?.location, '/settings');

      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();
      expect(stateCell.value?.location, '/');
    });
  });
}

/// Builds a root bucket holding [values] under the scope id 'router-scope'.
RestorationBucket _bucketWith(Map<String, Object?> values) {
  return RestorationBucket.root(
    manager: TestWidgetsFlutterBinding.instance.restorationManager,
    rawData: <Object?, Object?>{
      'v': <Object?, Object?>{},
      'c': <Object?, Object?>{
        'router-scope': <Object?, Object?>{
          'v': values,
          'c': <Object?, Object?>{},
        },
      },
    },
  );
}

class _RouterRegistrationHost extends StatefulWidget {
  const _RouterRegistrationHost({required this.cell});

  final RestorableCell<CellRouterState> cell;

  @override
  State<_RouterRegistrationHost> createState() =>
      _RouterRegistrationHostState();
}

class _RouterRegistrationHostState extends State<_RouterRegistrationHost> {
  @override
  void initState() {
    super.initState();
    CellRestorationScope.maybeOf(context)?.register(widget.cell);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _RouterButton extends HookWidget {
  const _RouterButton();

  @override
  Widget build(BuildContext context) {
    final router = router_hooks.useCellRouter();
    return Column(children: [
      Text('at:${router.state.location}'),
      TextButton(
        onPressed: () => router.go('/settings'),
        child: const Text('go to settings'),
      ),
    ]);
  }
}

class _UnscopedRouterButton extends HookWidget {
  const _UnscopedRouterButton();

  @override
  Widget build(BuildContext context) {
    router_hooks.useCellRouter();
    return const Text('unscoped');
  }
}

class _PushPopButtons extends HookWidget {
  const _PushPopButtons();

  @override
  Widget build(BuildContext context) {
    final router = router_hooks.useCellRouter();
    return Row(children: [
      TextButton(
        onPressed: () => router.push('/settings'),
        child: const Text('push'),
      ),
      TextButton(
        onPressed: () => router.pop(),
        child: const Text('pop'),
      ),
    ]);
  }
}
