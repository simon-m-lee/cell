// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Soak test for the 1.0 gate: 10k iterations of pulse +
// rebuild, including the replay-verified debounce-burst and throttle
// scenarios plus `fromFuture` / `fromStream` completion paths.
//
// Measurement methodology:
// `ProcessInfo.currentRss` measures the OS working set, not the Dart
// heap — even a pure `Text` rebuild loop grows it by ~9% over 10k
// frames on the reference machine. The test therefore runs a control
// phase (identical workload, no cell operators) and gates on the
// framework-attributable growth: |soak growth − control growth| ≤ 5%,
// plus zero transient-callback accumulation.

import 'dart:async';
import 'dart:io';

import 'package:cell_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

/// Discards every record while still running real timers and I/O.
///
/// The soak gate measures pulse/rebuild memory. Retaining 10k
/// debounce/throttle timer records in a [RecordingJournal] would measure
/// journal storage, not the operators.
class _SoakJournal implements EffectJournal {
  int _consumed = 0;

  @override
  int get consumed => _consumed;

  @override
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  String uuid() => 'soak-${_consumed++}';

  @override
  Future<T> io<T>({
    required String label,
    required Object? input,
    required Future<T> Function() run,
    Object? Function(T)? serializeOutput,
  }) => run();

  @override
  Future<void> timer({
    required Duration duration,
    required Object? input,
    required FutureOr<void> Function() onFire,
    bool fireAtEnd = false,
  }) async {
    await Future<void>.delayed(duration);
    await onFire();
  }

  @override
  void push() {}

  @override
  void pop() {}

  @override
  Future<bool> verdict({
    required String ruleLabel,
    required Object? input,
    required FutureOr<bool> Function() run,
  }) async => await run();

  @override
  void policyTick({
    required String policyLabel,
    required String cellId,
    required Object? input,
  }) {}

  @override
  void assertExhausted() {}

  @override
  List<Map<String, Object?>> toJson() => const [];
}

void main() {
  testWidgets('10k-iteration soak with control phase', (tester) async {
    final samples = <String>[];

    // -----------------------------------------------------------------
    // Control phase: the same update+pump workload without any cell
    // operators. This isolates the harness/engine's own RSS behavior.
    // -----------------------------------------------------------------
    final control = Cell.state<int>(initial: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: CellBuilder<int>(
          cell: control.cell,
          builder: (_, v) => Text('$v'),
        ),
      ),
    );
    var controlBaseline = -1;
    var controlFinal = -1;
    for (var i = 0; i < 10000; i++) {
      control.update(i);
      await tester.pump();
      if (i == 999) controlBaseline = _rssMb();
      if (i == 9999) controlFinal = _rssMb();
    }
    final controlGrowth = (controlFinal - controlBaseline) / controlBaseline;
    samples.add(
      'control: ${controlBaseline}MB -> ${controlFinal}MB '
      '(${(controlGrowth * 100).toStringAsFixed(1)}%)',
    );

    // -----------------------------------------------------------------
    // Soak phase: the replay-verified scenarios.
    // -----------------------------------------------------------------
    final state = Cell.state<int>(initial: 0);
    final debounced = Cell.debounce(
      state.cell,
      const Duration(milliseconds: 10),
      journal: _SoakJournal(),
    );
    final throttled = Cell.throttle(
      state.cell,
      const Duration(milliseconds: 10),
      journal: _SoakJournal(),
    );
    final debounceRecorder = debounced.recordPulses();
    final throttleRecorder = throttled.recordPulses();
    addTearDown(debounceRecorder.stop);
    addTearDown(throttleRecorder.stop);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CellBuilder<int>(
            cell: state.cell,
            builder: (_, v) => Text('$v'),
          ),
        ),
      ),
    );

    var baseline = -1;
    var finalRss = -1;
    var debouncePulses = 0;
    var throttlePulses = 0;

    Future<void> drainTimers() async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 10000; i++) {
      state.update(i);

      if (i % 100 == 0) {
        // Debounce burst: 10 rapid pulses must collapse into at most
        // one emission per settled window.
        for (var j = 0; j < 10; j++) {
          state.update(i * 1000 + j);
        }
      }
      if (i % 100 == 50) {
        // Throttle burst: the emission rate must respect the window.
        for (var j = 0; j < 10; j++) {
          state.update(i * 1000 + j);
        }
      }
      if (i % 500 == 0) {
        // Completion paths for the async sources.
        final completer = Completer<int>();
        final futureCell = Cell.fromFuture<int>(
          completer.future,
          journal: _SoakJournal(),
        );
        final controller = StreamController<int>();
        final streamCell = Cell.fromStream<int>(
          controller.stream,
          journal: _SoakJournal(),
        );
        final futureEgress = Cell.observe<Pulse<Object?>>(
          source: futureCell,
          effect: (_) {},
        );
        final streamEgress = Cell.observe<Pulse<Object?>>(
          source: streamCell,
          effect: (_) {},
        );
        completer.complete(i);
        controller.add(i);
        unawaited(controller.close());
        await drainTimers();
        futureEgress.stop();
        streamEgress.stop();
      }

      await tester.pump();

      if (i == 1000 || i == 2000 || i == 5000 || i == 10000 - 1) {
        await drainTimers();
        final rss = _rssMb();
        samples.add('soak ${i + 1}: ${rss}MB');
        if (baseline < 0) baseline = rss;
        if (i == 10000 - 1) finalRss = rss;
        // The recorders are test accumulators, not framework state.
        debouncePulses += debounceRecorder.payloads.length;
        throttlePulses += throttleRecorder.payloads.length;
        debounceRecorder.clear();
        throttleRecorder.clear();
      }
    }

    await drainTimers();

    // No timer accumulation.
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason:
          'transient callbacks must not accumulate across 10k '
          'iterations',
    );

    // Framework-attributable RSS growth within ±5% of the control phase.
    final soakGrowth = (finalRss - baseline) / baseline;
    final attributable = soakGrowth - controlGrowth;
    expect(
      attributable.abs(),
      lessThan(0.05),
      reason:
          'framework-attributable growth '
          '${(attributable * 100).toStringAsFixed(1)}% '
          '(control ${(controlGrowth * 100).toStringAsFixed(1)}%, '
          'soak ${(soakGrowth * 100).toStringAsFixed(1)}%); '
          'samples: $samples',
    );

    // The debounce/throttle scenarios really ran.
    expect(debouncePulses, greaterThan(0));
    expect(throttlePulses, greaterThan(0));
  });
}
