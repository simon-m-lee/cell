// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Injects [value] through the framework's receptor path via `apply`.
Future<void> ingest<T>(MemoryCell<T> memory, T value) async {
  final ApplyCommand command = (
    function: () => Pulse(value),
    arguments: (positionalArguments: null, namedArguments: null),
    compensation: null,
  );
  final outcome = await memory.apply(command);
  expect(outcome, isA<ApplyAccepted>());
}

/// A store that counts write attempts and forwards everything else.
class _CountingStore implements MemoryStore {
  _CountingStore(this.inner);

  final MemoryStore inner;

  int writeAttempts = 0;
  int writes = 0;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    writeAttempts++;
    await inner.write(envelope, expectedRevision: expectedRevision);
    writes++;
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}

/// A spike-style probe cell whose receptor is a dispatcher-shaped chain.
///
/// Production never lets an action call `synapses` itself; the probe builds
/// that forbidden shape so the one-broadcast rule stays measurable.
class ProbeCell extends CellBase {
  ProbeCell({required Receptor receptor, TestCell testRule = TestCell.allowAll})
      : this._(receptor: receptor, testRule: testRule, synapses: Synapses());

  ProbeCell._({
    required Receptor receptor,
    required TestCell testRule,
    required this.synapses,
  }) : super.fromNucleus(Nucleus(
          receptor: receptor,
          testRule: testRule,
          synapses: synapses,
        ));

  final Synapses synapses;

  int actionRuns = 0;

  late final Pulse Function() _go = _goBody;

  Pulse _goBody() => Pulse(1);

  @override
  Iterable<Function> get modifiable => {apply<dynamic>, _go};
}

void main() {
  group('MemoryCell chain', () {
    test('load and a domain apply each deliver one resumed MemoryPulse, '
        'never the command', () async {
      final store = InMemoryMemoryStore();
      await seed(store, 'counter', revision: 3, payload: 42);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        loadOnOpen: false,
        policy: MemoryWritePolicy.replay,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      final value = await memory.load();
      expect(value, 42);

      final loaded = recorder.memory<int>();
      expect(loaded, hasLength(1), reason: 'one callback for load');
      expect(loaded.single.event, MemoryEvent.loaded);
      expect(loaded.single.payload, 42);
      expect(loaded.single, isA<MemoryPulse<int>>(),
          reason: 'the observer sees the resumed MemoryPulse, never the '
              'MemoryCommand');

      await ingest(memory, 9);

      final all = recorder.memory<int>();
      expect(all, hasLength(2), reason: 'one callback for the apply');
      expect(all.last.event, MemoryEvent.applied);
      expect(all.last.payload, 9);
      expect(all.last, isA<MemoryPulse<int>>());

      await memory.close();
    });

    test('a probe action that also calls synapses.call delivers twice — the '
        'S5 bug', () async {
      final observed = <Pulse>[];
      final probe = ProbeCell(receptor: Receptor<Cell>.instruction(
        Instruction<ProbeCell, Pulse, Pulse>.chain([
          Instruction<ProbeCell, Pulse, Pulse>.future(
            (pulse, {cell, user, future, token}) {
              cell!.actionRuns++;
              // The forbidden pattern: the action broadcasts AND resumes
              // the continuation.
              cell.synapses.call(Pulse(7));
              future?.call(result: Pulse(8), token: token);
              return null;
            },
          ),
        ]),
      ));
      Cell.observe<Pulse>(source: probe, effect: (p) => observed.add(p));

      final ApplyCommand command = (
        function: probe._go,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      );
      final outcome = await probe.apply(command);

      expect(outcome, isA<ApplyAccepted>());
      expect(probe.actionRuns, 1);
      expect(observed, hasLength(2),
          reason: 'two deliveries: the review marker of the S5 pattern');
    });

    test('an echo of this cell emitted MemoryPulse does not re-adopt or '
        'write', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'echo',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await ingest(memory, 5);
      final emitted = recorder.memory<int>().single;
      expect(emitted.event, MemoryEvent.applied);

      await memory.save();
      expect(memory.revision, 1);
      expect(store.writes, 1);

      final pulsesBefore = recorder.pulses.length;
      final ApplyCommand command = (
        function: () => emitted,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      );
      final outcome = await memory.apply(command);

      expect(outcome, isA<ApplyAccepted>());
      expect(recorder.pulses.length, pulsesBefore,
          reason: 'the echo is dropped, nothing broadcasts');
      expect(memory.revision, 1, reason: 'revision unchanged');
      expect(store.writes, 1, reason: 'the echo writes nothing');

      await memory.close();
    });

    test('a governed pulse runs the apply action and schedules one write',
        () async {
      final scheduler = ManualScheduler();
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'governed',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(),
        scheduler: scheduler,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      // `Cell.transaction` commits a non-ValueCell with Pulse.governed.
      await deliverValue(memory, 7);

      expect(memory.value, 7);
      expect(scheduler.isPending, isTrue,
          reason: 'exactly one debounced write was scheduled');
      final pulses = recorder.memory<int>();
      expect(pulses, hasLength(1));
      expect(pulses.single.event, MemoryEvent.applied);

      scheduler.elapse();
      await memory.save(); // settle barrier for the detached write
      expect(store.writes, 1);

      await memory.close();
    });

    test('two overlapping saves serialize on the turn chain with one '
        'compare-and-swap attempt', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'overlap',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await ingest(memory, 5);

      final first = memory.save();
      final second = memory.save();
      final a = await first;
      final b = await second;

      expect(a, isNotNull, reason: 'the first save wrote');
      expect(b, isNull, reason: 'the second save sees a clean cell');
      expect(store.writeAttempts, 1,
          reason: 'one CAS attempt, never a hot loop');
      expect(store.writes, 1);

      await memory.close();
    });

    test('save after close is the same StateError and the store flushed '
        'once', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'closed',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await ingest(memory, 5);

      await memory.close();
      expect(store.writes, 1, reason: 'the close flushed once');

      await expectLater(
        memory.save(),
        throwsA(isA<StateError>()),
        reason: 'the same closed-cell error as before the extraction',
      );
      expect(store.writes, 1);
    });

    test('attach after a seed writes nothing for the seed and once for the '
        'next domain pulse', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'seeded',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );

      // Seed before attach: no observer installed yet, so the restore does
      // not write.
      upstream.update(9);
      expect(store.writeAttempts, 0, reason: 'the seed writes nothing');

      await memory.attach(upstream.cell);
      upstream.update(10);
      expect(memory.value, 10);

      await memory.save();
      expect(store.writes, 1, reason: 'the domain pulse wrote once');

      await memory.close();
    });

    test('a rejected tear-off never enters the instruction', () async {
      final observed = <Pulse>[];
      final rejectsGo = TestCell.chain([
        TestCell<ProbeCell>(
          (object, {host, arguments, user}) =>
              host is! ProbeCell || !identical(object, host._go),
        ),
      ]);
      final probe = ProbeCell(
        receptor: Receptor<Cell>.instruction(
          Instruction<ProbeCell, Pulse, Pulse>.chain([
            Instruction<ProbeCell, Pulse, Pulse>.future(
              (pulse, {cell, user, future, token}) {
                cell!.actionRuns++;
                future?.call(result: pulse, token: token);
                return null;
              },
            ),
          ]),
        ),
        testRule: rejectsGo,
      );
      Cell.observe<Pulse>(source: probe, effect: (p) => observed.add(p));

      final ApplyCommand command = (
        function: probe._go,
        arguments: (positionalArguments: null, namedArguments: null),
        compensation: null,
      );
      final outcome = await probe.apply(command);

      expect(outcome, isA<ApplyRejected>());
      expect(probe.actionRuns, 0,
          reason: 'the gate rejected before the dispatcher ran');
      expect(observed, isEmpty);
    });
  });
}
