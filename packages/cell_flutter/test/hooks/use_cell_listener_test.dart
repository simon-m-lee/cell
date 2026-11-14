// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hook host whose element stays stable across re-pumps, so emissions
/// triggered by [emitOnBuild] during a rebuild reach an already-subscribed
/// hook (flutter_hooks runs effects after the first build).
class _Host extends HookWidget {
  const _Host({
    required this.cell,
    required this.onPulse,
    required this.emitOnBuild,
  });

  final ValueCell<int> cell;
  final void Function(BuildContext, Pulse<int>) onPulse;
  final void Function() emitOnBuild;

  @override
  Widget build(BuildContext context) {
    useCellListener<int>(cell: cell, onPulse: onPulse);
    return Builder(builder: (ctx) {
      emitOnBuild();
      return const SizedBox.shrink();
    });
  }
}

void main() {
  group('useCellListener', () {
    testWidgets('sync dispatch from event handler', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCellListener<int>(
          cell: cell.cell,
          onPulse: (_, p) => received.add(p.payload!),
        );
        return const SizedBox.shrink();
      }));

      cell.update(1);
      await tester.pump();
      expect(received, [1]);
    });

    testWidgets('defers mid-frame pulse', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      final phases = <SchedulerPhase>[];

      await tester.pumpWidget(_Host(
        cell: cell.cell,
        onPulse: (_, p) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(p.payload!);
        },
        emitOnBuild: () {},
      ));

      // Rebuild with the same element; the host emits during build.
      await tester.pumpWidget(_Host(
        cell: cell.cell,
        onPulse: (_, p) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(p.payload!);
        },
        emitOnBuild: () => cell.update(1),
      ));

      expect(received, [1]);
      expect(phases, [SchedulerPhase.postFrameCallbacks]);
    });

    testWidgets('onPulse throw is contained', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCellListener<int>(
          cell: cell.cell,
          onPulse: (context, pulse) => throw StateError('boom'),
        );
        return const SizedBox.shrink();
      }));

      cell.update(1);
      await tester.pump();
      expect(errors, hasLength(1));
    });

    testWidgets('fresh onPulse closure does not churn', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      var counter = 0;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCellListener<int>(
            cell: cell.cell, onPulse: (context, pulse) => counter++);
        return const SizedBox.shrink();
      }));
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCellListener<int>(
            cell: cell.cell, onPulse: (context, pulse) => counter++);
        return const SizedBox.shrink();
      }));
      cell.update(1);
      await tester.pump();
      expect(counter, 1);
    });

    testWidgets('cell swap rebinds', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final source = ValueNotifier<ValueCell<int>>(a.cell);
      addTearDown(source.dispose);
      final received = <int>[];
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useValueListenable(source); // rebuild when the source swaps
        useCellListener<int>(
          cell: source.value,
          onPulse: (_, p) => received.add(p.payload!),
        );
        return const SizedBox.shrink();
      }));

      source.value = b.cell;
      await tester.pump();
      a.update(10);
      b.update(20);
      await tester.pump();
      expect(received, [20]);
    });

    testWidgets('cell swap clears pending queue', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final received = <int>[];

      await tester.pumpWidget(_Host(
        cell: a.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () {},
      ));

      // Emit from `a` during the same build that swaps the cell to `b`;
      // the pending pulse must be discarded when the hook rebinds.
      await tester.pumpWidget(_Host(
        cell: b.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () => a.update(10),
      ));

      expect(received, isEmpty,
          reason: 'pending pulse from old cell must not be delivered');
    });

    testWidgets('does not rebuild widget', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      var buildCount = 0;
      await tester.pumpWidget(HookBuilder(builder: (_) {
        useCellListener<int>(cell: cell.cell, onPulse: (context, pulse) {});
        buildCount++;
        return const SizedBox.shrink();
      }));
      expect(buildCount, 1);
      cell.update(1);
      await tester.pump();
      expect(buildCount, 1);
    });
  });
}
