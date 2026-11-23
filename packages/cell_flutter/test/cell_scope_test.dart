// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required Map<Symbol, Cell> cells, required Widget child}) =>
    MaterialApp(
      home: CellScope(
        cells: cells,
        child: Scaffold(body: child),
      ),
    );

Widget _probe({
  required Symbol id,
  required void Function(BuildContext) onBuild,
}) => Builder(
  builder: (ctx) {
    onBuild(ctx);
    return const SizedBox.shrink();
  },
);

void main() {
  group('CellScope.of', () {
    testWidgets('returns registered cell', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      Cell? found;

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #counter,
            onBuild: (ctx) {
              found = CellScope.of<int>(ctx, #counter);
            },
          ),
        ),
      );

      expect(found, same(counter.cell));
    });

    testWidgets('throws StateError on type mismatch', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #counter,
            onBuild: (ctx) {
              expect(
                () => CellScope.of<String>(ctx, #counter),
                throwsA(isA<StateError>()),
              );
            },
          ),
        ),
      );
    });

    testWidgets('debug assert on unknown id', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #missing,
            onBuild: (ctx) {
              expect(
                () => CellScope.of<int>(ctx, #missing),
                throwsAssertionError, // assert in debug
              );
            },
          ),
        ),
      );
    });

    testWidgets('debug assert when no scope exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _probe(
              id: #counter,
              onBuild: (ctx) {
                expect(
                  () => CellScope.of<int>(ctx, #counter),
                  throwsAssertionError,
                );
              },
            ),
          ),
        ),
      );
    });

    testWidgets('returns non-ValueCell registrations as-is', (tester) async {
      final src = Cell.ingress<int>();
      Cell? found;

      await tester.pumpWidget(
        _wrap(
          cells: {#src: src.cell},
          child: _probe(
            id: #src,
            onBuild: (ctx) {
              found = CellScope.of<int>(ctx, #src);
            },
          ),
        ),
      );

      // `Cell` carries no runtime value type; non-ValueCell cells are
      // returned as-is (type safety lives on the pulse and in `valueOf`).
      expect(found, same(src.cell));
    });
  });

  group('CellScope.maybeOf', () {
    testWidgets('returns null for unknown id', (tester) async {
      final counter = Cell.state<int>(initial: 0);
      Cell? found;

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #missing,
            onBuild: (ctx) {
              found = CellScope.maybeOf<int>(ctx, #missing);
            },
          ),
        ),
      );

      expect(found, isNull);
    });

    testWidgets('returns null when no scope exists', (tester) async {
      Cell? found;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _probe(
              id: #counter,
              onBuild: (ctx) {
                found = CellScope.maybeOf<int>(ctx, #counter);
              },
            ),
          ),
        ),
      );

      expect(found, isNull);
    });

    testWidgets('throws on type mismatch', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #counter,
            onBuild: (ctx) {
              expect(
                () => CellScope.maybeOf<String>(ctx, #counter),
                throwsA(isA<StateError>()),
              );
            },
          ),
        ),
      );
    });
  });

  group('CellScope.valueOf', () {
    testWidgets('returns ValueCell for ValueCell registration', (tester) async {
      final counter = Cell.state<int>(initial: 42);
      ValueCell<int>? found;

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #counter,
            onBuild: (ctx) {
              found = CellScope.valueOf<int>(ctx, #counter);
            },
          ),
        ),
      );

      expect(found, same(counter.cell));
    });

    testWidgets('throws for non-ValueCell registration', (tester) async {
      final src = Cell.ingress<int>();

      await tester.pumpWidget(
        _wrap(
          cells: {#src: src.cell},
          child: _probe(
            id: #src,
            onBuild: (ctx) {
              expect(
                () => CellScope.valueOf<int>(ctx, #src),
                throwsA(isA<StateError>()),
              );
            },
          ),
        ),
      );
    });

    testWidgets('throws for wrong ValueCell type parameter', (tester) async {
      final counter = Cell.state<int>(initial: 0);

      await tester.pumpWidget(
        _wrap(
          cells: {#counter: counter.cell},
          child: _probe(
            id: #counter,
            onBuild: (ctx) {
              expect(
                () => CellScope.valueOf<String>(ctx, #counter),
                throwsA(isA<StateError>()),
              );
            },
          ),
        ),
      );
    });
  });

  group('CellScope.updateShouldNotify', () {
    // These pump `CellScope` directly (no MaterialApp): MaterialApp caches
    // its `home` route, so a re-pumped home widget would never reach the
    // scope element.
    testWidgets('rebuilds when cell swapped', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      var buildCount = 0;

      final probe = _probe(
        id: #counter,
        onBuild: (ctx) {
          CellScope.of<int>(ctx, #counter); // register dependency
          buildCount++;
        },
      );

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 1);

      await tester.pumpWidget(
        CellScope(cells: {#counter: b.cell}, child: probe),
      );
      expect(buildCount, 2);
    });

    testWidgets('does not rebuild when map is re-created with same cells', (
      tester,
    ) async {
      final a = Cell.state<int>(initial: 1);
      var buildCount = 0;

      final probe = _probe(
        id: #counter,
        onBuild: (ctx) {
          CellScope.of<int>(ctx, #counter); // register dependency
          buildCount++;
        },
      );

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 1);

      // Fresh map with identical cell identity.
      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 1);
    });

    testWidgets('rebuilds when cell added', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<String>(initial: '');
      var buildCount = 0;

      final probe = _probe(
        id: #counter,
        onBuild: (ctx) {
          CellScope.of<int>(ctx, #counter); // register dependency
          buildCount++;
        },
      );

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 1);

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell, #other: b.cell}, child: probe),
      );
      expect(buildCount, 2);
    });

    testWidgets('rebuilds when cell removed', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<String>(initial: '');
      var buildCount = 0;

      final probe = _probe(
        id: #counter,
        onBuild: (ctx) {
          CellScope.of<int>(ctx, #counter); // register dependency
          buildCount++;
        },
      );

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell, #other: b.cell}, child: probe),
      );
      expect(buildCount, 1);

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 2);
    });

    testWidgets('does not rebuild when a cell is swapped for an equal deputy', (
      tester,
    ) async {
      final a = Cell.state<int>(initial: 1);
      // A non-default deputy is a distinct instance, but `Cell` equality is
      // nucleus-based, so it is equal to its principal.
      final deputy = await a.cell.deputy(synapses: Synapses.disabled);
      expect(deputy == a.cell, isTrue);
      var buildCount = 0;

      final probe = _probe(
        id: #counter,
        onBuild: (ctx) {
          CellScope.of<int>(ctx, #counter); // register dependency
          buildCount++;
        },
      );

      await tester.pumpWidget(
        CellScope(cells: {#counter: a.cell}, child: probe),
      );
      expect(buildCount, 1);

      await tester.pumpWidget(
        CellScope(cells: {#counter: deputy}, child: probe),
      );
      expect(
        buildCount,
        1,
        reason: 'an equal deputy is not a change; dependents stay put',
      );
    });
  });

  group('CellScope nested', () {
    testWidgets('inner scope shadows outer', (tester) async {
      final outer = Cell.state<int>(initial: 1);
      final inner = Cell.state<int>(initial: 2);
      Cell? found;

      await tester.pumpWidget(
        MaterialApp(
          home: CellScope(
            cells: {#counter: outer.cell},
            child: CellScope(
              cells: {#counter: inner.cell},
              child: Builder(
                builder: (ctx) {
                  found = CellScope.of<int>(ctx, #counter);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(found, same(inner.cell));
    });

    testWidgets('outer cell still reachable from outer-scope context', (
      tester,
    ) async {
      final outer = Cell.state<int>(initial: 1);
      Cell? found;

      // A context *above* the inner scope resolves against the outer scope.
      await tester.pumpWidget(
        MaterialApp(
          home: CellScope(
            cells: {#counter: outer.cell},
            child: Builder(
              builder: (ctx) {
                found = CellScope.of<int>(ctx, #counter);
                return const CellScope(
                  cells: {},
                  child: Scaffold(body: SizedBox.shrink()),
                );
              },
            ),
          ),
        ),
      );

      expect(found, same(outer.cell));
    });
  });
}
