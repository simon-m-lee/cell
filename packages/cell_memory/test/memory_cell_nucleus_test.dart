// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Injects [value] through the framework's receptor path — the same path a
/// domain pulse takes — via `CellBase.apply`.
Future<void> ingest<T>(MemoryCell<T> memory, T value) async {
  final ApplyCommand command = (
    function: () => Pulse(value),
    arguments: (positionalArguments: null, namedArguments: null),
    compensation: null,
  );
  final outcome = await memory.apply(command);
  expect(outcome, isA<ApplyAccepted>(),
      reason: 'the default allowAll gate accepts the pulse');
}

/// The write-free policy used by the identity tests: nothing is ever
/// scheduled or flushed, so value/revision/dirty stay exactly where the
/// ingress path left them.
const MemoryWritePolicy noWrites = MemoryWritePolicy.replay;

void main() {
  group('MemoryCellNucleus', () {
    test('two opens get two runtimes; setting one value leaves the other '
        'unchanged', () async {
      final store = InMemoryMemoryStore();
      final a = await MemoryCell.open<int>(
        id: 'a',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: noWrites,
      );
      final b = await MemoryCell.open<int>(
        id: 'b',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 2,
        policy: noWrites,
      );

      expect(identical(a.runtimeForTest, b.runtimeForTest), isFalse,
          reason: 'one runtime per open');
      expect(identical(a.nucleusForTest, b.nucleusForTest), isFalse);

      await ingest(a, 9);

      expect(a.value, 9);
      expect(b.value, 2, reason: 'the other open is untouched');

      await a.close();
      await b.close();
    });

    test('clone and evolve share the principal runtime, store, and queues',
        () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'shared',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 3,
        policy: noWrites,
      );

      final cloneNucleus = memory.nucleusForTest.clone;
      final evolveNucleus =
          MemoryCellNucleus.evolve(principal: memory.nucleusForTest);

      expect(identical(cloneNucleus.runtime, memory.runtimeForTest), isTrue);
      expect(identical(evolveNucleus.runtime, memory.runtimeForTest), isTrue);

      // No second store and no second queue: everything walks the principal.
      expect(identical(cloneNucleus.slots.store, memory.store), isTrue);
      expect(identical(evolveNucleus.slots.store, memory.store), isTrue);
      expect(
        identical(cloneNucleus.runtime.turnChain,
            memory.runtimeForTest.turnChain),
        isTrue,
      );
      expect(
        identical(evolveNucleus.runtime.writeChain,
            memory.runtimeForTest.writeChain),
        isTrue,
      );
      expect(
        identical(evolveNucleus.runtime.ingressChain,
            memory.runtimeForTest.ingressChain),
        isTrue,
      );

      await memory.close();
    });

    test('a pulse through the existing receptor behaves as before the '
        'extraction', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'pulse',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: noWrites,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await ingest(memory, 5);

      expect(memory.value, 5);
      expect(memory.revision, 0, reason: 'no write under the replay policy');
      expect(memory.dirty, isTrue);

      final pulses = recorder.memory<int>();
      expect(pulses, hasLength(1), reason: 'one observer, one callback');
      expect(pulses.single.event, MemoryEvent.applied);

      await memory.close();
    });

    test('close leaves a shared store open when ownsStore is false',
        () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'shared-store',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: noWrites,
        ownsStore: false,
      );

      await memory.close();

      // The store still admits reads: the cell did not close it.
      expect(await store.read('shared-store'), isNull);
    });

    test('close closes an owned store exactly once', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'owned-store',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: noWrites,
        ownsStore: true,
      );

      await memory.close();
      await memory.close(); // Cell-level idempotence; must not double-close.

      await expectLater(
        store.read('owned-store'),
        throwsA(isA<StateError>()),
        reason: 'the owned store was closed',
      );
    });

    test('Cell.id and memoryId stay different namespaces', () async {
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: noWrites,
      );

      expect(memory.memoryId, 'counter');
      expect(memory.id, isNot('counter'));
      expect(memory.id, isNot(memory.memoryId));

      await memory.close();
    });

    test('deputy() returns a memory-typed view sharing the principal runtime',
        () async {
      final memory = await MemoryCell.open<int>(
        id: 'deputy',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 7,
        policy: noWrites,
      );

      final deputy = await memory.deputy(testRule: TestCell.readOnly);

      expect(deputy, isA<MemoryCell<int>>(),
          reason: 'Phase 4 returns a memory-typed deputy');
      expect(identical(deputy.runtimeForTest, memory.runtimeForTest), isTrue);
      expect(memory.value, 7, reason: 'the principal is unchanged');

      await memory.close();
    });
  });
}
