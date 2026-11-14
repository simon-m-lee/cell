// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Hosts a [CellListener] whose cell stays in a stable element position so
/// that emissions triggered during [emitOnBuild] (which runs inside the
/// host's `build`) reach an already-subscribed listener state.
class _PulseHost extends StatefulWidget {
  const _PulseHost({
    required this.cell,
    required this.onPulse,
    required this.emitOnBuild,
  });

  final ValueCell<int> cell;
  final void Function(BuildContext, Pulse<int>) onPulse;
  final void Function() emitOnBuild;

  @override
  State<_PulseHost> createState() => _PulseHostState();
}

class _PulseHostState extends State<_PulseHost> {
  @override
  Widget build(BuildContext context) {
    widget.emitOnBuild();
    return CellListener<int>(
      cell: widget.cell,
      onPulse: widget.onPulse,
      child: const SizedBox.shrink(),
    );
  }
}

/// Hosts a [CellListener] that can be removed in the same build that emits —
/// exercising the pending-queue clearing on dispose.
class _ToggleHost extends StatefulWidget {
  const _ToggleHost({
    required this.cell,
    required this.onPulse,
    required this.showListener,
    required this.emitOnBuild,
  });

  final ValueCell<int> cell;
  final void Function(BuildContext, Pulse<int>) onPulse;
  final bool showListener;
  final void Function() emitOnBuild;

  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  @override
  Widget build(BuildContext context) {
    widget.emitOnBuild();
    if (!widget.showListener) return const SizedBox.shrink();
    return CellListener<int>(
      cell: widget.cell,
      onPulse: widget.onPulse,
      child: const SizedBox.shrink(),
    );
  }
}

void main() {
  group('CellListener', () {
    testWidgets('sync dispatch from event handler', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (_, pulse) => received.add(pulse.payload!),
          child: const SizedBox.shrink(),
        ),
      ));

      // Emitting from an event handler (outside the frame) is synchronous.
      cell.update(42);
      await tester.pump();

      expect(received, [42]);
    });

    testWidgets('defers pulse emitted during build', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      final phases = <SchedulerPhase>[];

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: cell.cell,
        onPulse: (_, pulse) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(pulse.payload!);
        },
        emitOnBuild: () {},
      )));

      // Rebuild the same element; the host emits during build.
      await tester.pumpWidget(_wrap(_PulseHost(
        cell: cell.cell,
        onPulse: (_, pulse) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(pulse.payload!);
        },
        emitOnBuild: () => cell.update(99),
      )));

      expect(received, [99]);
      // Deferred: the handler ran in the post-frame callback, not during
      // the build (persistentCallbacks).
      expect(phases, [SchedulerPhase.postFrameCallbacks]);
    });

    testWidgets('multiple mid-frame pulses delivered in order', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      final phases = <SchedulerPhase>[];

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: cell.cell,
        onPulse: (_, pulse) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(pulse.payload!);
        },
        emitOnBuild: () {},
      )));

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: cell.cell,
        onPulse: (_, pulse) {
          phases.add(SchedulerBinding.instance.schedulerPhase);
          received.add(pulse.payload!);
        },
        emitOnBuild: () {
          cell.update(1);
          cell.update(2);
          cell.update(3);
        },
      )));

      expect(received, [1, 2, 3]);
      // One consolidated post-frame flush for all three pulses.
      expect(phases, List.filled(3, SchedulerPhase.postFrameCallbacks));
    });

    testWidgets('defers pulse during midFrameMicrotasks', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      final phases = <SchedulerPhase>[];

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (_, pulse) {
            phases.add(SchedulerBinding.instance.schedulerPhase);
            received.add(pulse.payload!);
          },
          child: const SizedBox.shrink(),
        ),
      ));

      // A microtask scheduled from a transient (animation) callback runs in
      // the midFrameMicrotasks phase.
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() => cell.update(7));
      });
      await tester.pump();

      expect(received, [7]);
      expect(phases, [SchedulerPhase.postFrameCallbacks]);
    });

    testWidgets('listener survives onPulse throw', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];
      var shouldThrow = true;

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (_, pulse) {
            if (shouldThrow) {
              shouldThrow = false;
              throw StateError('boom');
            }
            received.add(pulse.payload!);
          },
          child: const SizedBox.shrink(),
        ),
      ));

      cell.update(1);
      await tester.pump();
      expect(tester.takeException(), isStateError);

      cell.update(2);
      await tester.pump();
      expect(received, [2]);
    });

    testWidgets('rebinds on cell swap', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final received = <int>[];

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: a.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () {},
      )));

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: b.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () {},
      )));

      a.update(10); // old cell — should not fire
      b.update(20); // new cell — should fire
      await tester.pump();

      expect(received, [20]);
    });

    testWidgets('cell swap clears pending queue', (tester) async {
      final a = Cell.state<int>(initial: 1);
      final b = Cell.state<int>(initial: 2);
      final received = <int>[];

      await tester.pumpWidget(_wrap(_PulseHost(
        cell: a.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () {},
      )));

      // Emit from `a` during the same build that swaps the cell to `b`.
      await tester.pumpWidget(_wrap(_PulseHost(
        cell: b.cell,
        onPulse: (_, p) => received.add(p.payload!),
        emitOnBuild: () => a.update(10),
      )));

      expect(received, isEmpty,
          reason: 'pending pulse from old cell must not be delivered');

      // The new binding is live.
      b.update(20);
      await tester.pump();
      expect(received, [20]);
    });

    testWidgets('onPulse identity change does not rebind', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      var counter = 0;

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (context, pulse) => counter++,
          child: const SizedBox.shrink(),
        ),
      ));

      // Rebuild with a fresh closure — this would rebind if the
      // implementation checked `oldWidget.onPulse != widget.onPulse`.
      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (context, pulse) => counter++,
          child: const SizedBox.shrink(),
        ),
      ));

      cell.update(1);
      await tester.pump();
      expect(counter, 1); // fires exactly once, not twice
    });

    testWidgets('dispose stops further callbacks', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (_, p) => received.add(p.payload!),
          child: const SizedBox.shrink(),
        ),
      ));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      cell.update(1);
      await tester.pump();

      expect(received, isEmpty);
    });

    testWidgets('clears pending on dispose', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];

      await tester.pumpWidget(_wrap(_ToggleHost(
        cell: cell.cell,
        onPulse: (_, p) => received.add(p.payload!),
        showListener: true,
        emitOnBuild: () {},
      )));

      // Emit during the same build that removes the listener.
      await tester.pumpWidget(_wrap(_ToggleHost(
        cell: cell.cell,
        onPulse: (_, p) => received.add(p.payload!),
        showListener: false,
        emitOnBuild: () => cell.update(1),
      )));

      expect(received, isEmpty,
          reason: 'pending pulse should be discarded on dispose');
    });

    testWidgets('100 rebuilds with the same cell do not churn egress',
        (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final received = <int>[];

      for (var i = 0; i < 100; i++) {
        await tester.pumpWidget(_wrap(
          CellListener<int>(
            cell: cell.cell,
            onPulse: (_, p) => received.add(p.payload!),
            child: const SizedBox.shrink(),
          ),
        ));
      }

      cell.update(1);
      await tester.pump();
      expect(received, [1]);
    });

    testWidgets('context has access to Navigator', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final cell = Cell.state<String>(initial: '');
      Object? navigatorResult;

      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: CellListener<String>(
          cell: cell.cell,
          onPulse: (ctx, _) {
            navigatorResult = Navigator.of(ctx);
          },
          child: const Scaffold(body: SizedBox.shrink()),
        ),
      ));

      cell.update('push');
      await tester.pump();

      expect(navigatorResult, isNotNull);
      expect(identical(navigatorResult, nav.currentState), isTrue,
          reason: 'listener context should sit below Navigator');
    });

    testWidgets('async onPulse with mounted check', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      int? finalValue;

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (ctx, p) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            if (!ctx.mounted) return;
            finalValue = p.payload;
          },
          child: const SizedBox.shrink(),
        ),
      ));

      cell.update(42);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(finalValue, 42);
    });

    testWidgets('reads from non-ValueCell sources', (tester) async {
      final src = Cell.ingress<String>();
      final received = <String>[];

      await tester.pumpWidget(_wrap(
        CellListener<String>(
          cell: src.cell,
          onPulse: (_, p) => received.add(p.payload ?? ''),
          child: const SizedBox.shrink(),
        ),
      ));

      src.emit('hello');
      await tester.pump();
      expect(received, ['hello']);
    });

    testWidgets('handles error pulses without casting crash', (tester) async {
      final src = Cell.ingress<Object>();
      final received = <String>[];

      await tester.pumpWidget(_wrap(
        CellListener<Object>(
          cell: src.cell,
          onPulse: (_, pulse) {
            // Documented pattern: branch on type before casting.
            if (pulse.type == 'error') {
              received.add('error: ${pulse.payload}');
              return;
            }
            received.add('data: ${pulse.payload}');
          },
          child: const SizedBox.shrink(),
        ),
      ));

      src.emit(42);
      await src.ingest(Pulse<Object>(StateError('boom'), type: 'error'));
      await tester.pump();

      expect(received, [
        'data: 42',
        'error: Bad state: boom',
      ]);
    });

    testWidgets('rejects invalidated cell', (tester) async {
      final policy = EphemeralPolicy<Cell>(
        eventLimit: 1,
        onEvent: (o, {required cell, required policy, arguments, user}) =>
            (events: policy.events + 1),
        onInvalidate: (nucleus) => true,
      );
      final head = Cell.governed(
        ephemeralPolicy: policy,
        context: Context.system,
      );
      policy('use', cell: head);
      expect(head.isInvalidated, isTrue);

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: head,
          onPulse: (context, pulse) {},
          child: const SizedBox.shrink(),
        ),
      ));

      // _bind throws during initState; the error surfaces via the framework.
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets('multiple listeners over the same cell all fire',
        (tester) async {
      final cell = Cell.state<int>(initial: 0);
      final a = <int>[];
      final b = <int>[];

      await tester.pumpWidget(_wrap(
        Column(children: [
          CellListener<int>(
            cell: cell.cell,
            onPulse: (_, p) => a.add(p.payload!),
            child: const SizedBox.shrink(),
          ),
          CellListener<int>(
            cell: cell.cell,
            onPulse: (_, p) => b.add(p.payload!),
            child: const SizedBox.shrink(),
          ),
        ]),
      ));

      cell.update(1);
      cell.update(2);
      await tester.pump();
      expect(a, [1, 2]);
      expect(b, [1, 2]);
    });

    testWidgets('child is not rebuilt on pulse', (tester) async {
      final cell = Cell.state<int>(initial: 0);
      var childBuilds = 0;

      Widget child() {
        childBuilds++;
        return const SizedBox.shrink();
      }

      await tester.pumpWidget(_wrap(
        CellListener<int>(
          cell: cell.cell,
          onPulse: (context, pulse) {},
          child: Builder(builder: (_) => child()),
        ),
      ));

      expect(childBuilds, 1);

      cell.update(1);
      await tester.pump();
      cell.update(2);
      await tester.pump();

      expect(childBuilds, 1,
          reason: 'CellListener passes the child through unchanged');
    });
  });
}
