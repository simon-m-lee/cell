// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  group('open / load', () {
    test('a miss keeps initial and creates nothing', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 7,
      );
      expect(memory.value, 7);
      expect(memory.loaded, isTrue);
      expect(memory.revision, 0);
      expect(await store.list(), isEmpty);
    });

    test('a hit restores value and revision and emits one loaded pulse',
        () async {
      final store = InMemoryMemoryStore();
      await seed(store, 'counter', revision: 5, payload: 42);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        loadOnOpen: false,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      final value = await memory.load();
      expect(value, 42);
      expect(memory.value, 42);
      expect(memory.revision, 5);
      final pulses = recorder.memory<int>();
      expect(pulses, hasLength(1));
      expect(pulses.single.event, MemoryEvent.loaded);
    });

    test('a corrupt load does not emit and leaves the previous value',
        () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 1),
          expectedRevision: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 9,
        loadOnOpen: false,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      // Poison the store: an envelope whose payload cannot decode as int.
      final poisoned = _PoisonStore(store);
      final second = await MemoryCell.open<int>(
        id: 'counter',
        store: poisoned,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 3,
        loadOnOpen: false,
      );
      await expectLater(second.load(), throwsA(isA<MemoryCorrupt>()));
      expect(second.value, 3, reason: 'previous value untouched');
      expect(second.loaded, isFalse);
      expect(recorder.pulses, isEmpty);
      expect(memory.value, 9);
    });
  });

  group('ingress / save', () {
    test('an accepted ingress emits applied and one write (immediate)',
        () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await deliverValue(memory, 1);
      await memory.save(); // settle barrier

      expect(memory.value, 1);
      final applied =
          recorder.memory<int>().where((p) => p.event == MemoryEvent.applied);
      expect(applied, hasLength(1));
      expect(store.writes, 1);
      expect(memory.revision, 1);
      final stored =
          recorder.memory<int>().where((p) => p.event == MemoryEvent.stored);
      expect(stored, hasLength(1));
    });

    test('a second save of the same value does not bump revision', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, 5);
      final envelope = await memory.save();
      expect(envelope?.revision, 1);
      expect(memory.revision, 1);

      // Accept the same value again: dirty by the codec, so nothing to
      // write.
      await deliverValue(memory, 5);
      expect(await memory.save(), isNull);
      expect(memory.revision, 1);
      expect((await store.read('counter'))?.revision, 1);
    });

    test('explicit mode writes only on save', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, 3);
      expect(store.writes, 0, reason: 'explicit mode schedules nothing');
      await memory.save();
      expect(store.writes, 1);
    });

    test('debounced: two pulses inside the window produce one write at the '
        'second value', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final scheduler = ManualScheduler();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.debounced),
        scheduler: scheduler,
      );

      await deliverValue(memory, 1);
      expect(scheduler.isPending, isTrue);
      await deliverValue(memory, 2);
      expect(scheduler.isPending, isTrue);

      scheduler.elapse();
      await memory.save(); // settle barrier
      expect(store.writes, 1);
      expect((await store.inner.read('counter'))?.payload, 2,
          reason: 'the burst coalesced into one write at the second value');
      expect(memory.revision, 1);
    });

    test('unload cancels the debounce and flushes once', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final scheduler = ManualScheduler();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.debounced),
        scheduler: scheduler,
      );
      await deliverValue(memory, 7);
      await memory.unload();
      expect(store.writes, 1);
      expect((await store.inner.read('counter'))?.payload, 7);
      expect(scheduler.isPending, isFalse);
    });

    test('revision does not advance when apply accepts; only when write '
        'succeeds', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, 8);
      expect(memory.value, 8);
      expect(memory.revision, 0);
      await memory.save();
      expect(memory.revision, 1);
    });
  });

  group('unload / remove', () {
    test('unload flushes, keeps the record, and stops the cell', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await deliverValue(memory, 4);
      await memory.unload();

      expect(await store.read('counter'), isNotNull,
          reason: 'unload keeps the durable record');
      expect((await store.read('counter'))?.payload, 4);
      expect(memory.value, isNull);
      expect(memory.loaded, isFalse);
      expect(recorder.memory<int>().last.event, MemoryEvent.unloaded);
      await expectLater(memory.load(), throwsA(isA<StateError>()));
    });

    test('remove deletes the record and emits removed', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);
      await deliverValue(memory, 4);
      await memory.save();

      await memory.remove();

      expect(await store.read('counter'), isNull);
      expect(memory.value, isNull);
      expect(memory.revision, 0);
      expect(recorder.memory<int>().last.event, MemoryEvent.removed);
    });

    test('close is idempotent and closes the store only when it owns it',
        () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
      );
      await memory.close();
      await memory.close();
      // The shared store stays open.
      expect(await store.read('counter'), isNull);

      final ownedStore = InMemoryMemoryStore();
      final owned = await MemoryCell.open<int>(
        id: 'counter',
        store: ownedStore,
        codec: JsonMemoryCodec<int>.identity(),
        ownsStore: true,
      );
      await owned.close();
      await expectLater(ownedStore.read('x'), throwsA(isA<StateError>()));
    });
  });

  group('transaction (Phase 0 branch: receptor-based)', () {
    test('commit writes the envelope; rollback writes nothing', () async {
      final counting = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: counting,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );

      await deliverValue(memory, 1);
      await memory.save();
      expect(counting.writes, 1);

      // A rolled-back transaction never delivers into the receptor.
      final rolledBack = Cell.transaction();
      await rolledBack.begin([memory]);
      rolledBack.update(memory, 99);
      await rolledBack.rollback();
      expect(memory.value, 1);
      await memory.save();
      expect(counting.writes, 1, reason: 'rollback writes nothing');

      // A committed transaction delivers the staged value.
      final committed = Cell.transaction();
      await committed.begin([memory]);
      committed.update(memory, 2);
      await committed.commit();
      await memory.save();
      expect(counting.writes, 2);
      expect((await counting.inner.read('counter'))?.payload, 2);
    });
  });

  group('code review regressions', () {
    test('H1: queued writes re-check dirty; two same-value pulses in '
        'immediate mode produce one revision', () async {
      final store = _SlowStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      await deliverValue(memory, 5);
      await deliverValue(memory, 5);
      await memory.save();
      expect(store.writes, 1, reason: 'the second queued write sees a '
          'clean cell and must not inflate the revision');
      expect(memory.revision, 1);
    });

    test('H3: remove drains in-flight writes; no resurrection and the next '
        'write starts at revision 1', () async {
      final store = _SlowStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      await deliverValue(memory, 1);
      await memory.remove();
      await Future<void>.delayed(Duration.zero);
      expect(await store.inner.read('counter'), isNull,
          reason: 'a late write must not resurrect the record');
      expect(memory.revision, 0);

      await deliverValue(memory, 2);
      await memory.save();
      expect((await store.inner.read('counter'))?.payload, 2);
      expect(memory.revision, 1);
    });

    test('H4: unload still closes and detaches when the final flush fails, '
        'and save failures set lastError', () async {
      final failing = _FailingWriteStore();
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: failing,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await memory.attach(upstream.cell);
      await deliverValue(memory, 1);

      await expectLater(memory.unload(), throwsA(isA<MemoryIoException>()));
      expect(memory.closed, isTrue);
      expect(memory.attached, isFalse);
      expect(memory.lastError, isA<MemoryIoException>());

      // save() failures also set lastError (they propagate AND report).
      final second = await MemoryCell.open<int>(
        id: 'counter',
        store: _FailingWriteStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(second, 3);
      await expectLater(second.save(), throwsA(isA<MemoryIoException>()));
      expect(second.lastError, isA<MemoryIoException>());
    });

    test('unload whose write throws, ownsStore: the store stays open and '
        'the following close releases it once', () async {
      final inner = InMemoryMemoryStore();
      final failing = _FailingOwnedStore(inner);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: failing,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        ownsStore: true,
      );
      await deliverValue(memory, 1);

      await expectLater(memory.unload(), throwsA(isA<MemoryIoException>()));
      expect(memory.closed, isTrue);
      expect(memory.lastError, isA<MemoryIoException>());
      // unload never closes the store.
      expect(await inner.read('counter'), isNull);
      expect(failing.closed, isFalse);

      // close after the failed unload releases the owned store, once.
      await memory.close();
      expect(failing.closed, isTrue);
      expect(failing.closeCalls, 1);
      await memory.close();
      expect(failing.closeCalls, 1);
    });

    test('two close() calls with no await between them, ownsStore: both '
        'complete and the store closes once', () async {
      final inner = InMemoryMemoryStore();
      final counting = _CountingCloseStore(inner);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: counting,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        ownsStore: true,
      );
      await deliverValue(memory, 1);

      final first = memory.close();
      final second = memory.close();
      await first;
      await second;
      expect(counting.closeCalls, 1);
      expect(memory.closed, isTrue);
      // unload after close throws.
      await expectLater(memory.unload(), throwsA(isA<StateError>()));
    });

    test('H5: an in-place mutation of a retained List is still written',
        () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<List<int>>(
        id: 'list',
        store: store,
        codec: JsonMemoryCodec<List<int>>.identity(),
        initial: [1, 2],
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, [1, 2, 3]);
      await memory.save();
      expect(memory.revision, 1);

      // Mutate the very list the cell retained, then re-pulse the same
      // reference. The stored payload must be a copy, so the dirty check
      // sees the change.
      final aliased = memory.value!;
      aliased.add(4);
      await deliverValue(memory, aliased);
      expect(await memory.save(), isNotNull,
          reason: 'the stored payload is a copy; mutating the original must '
              'still dirty the cell');
      expect(memory.revision, 2);
      expect((await store.read('list'))?.payload, [1, 2, 3, 4]);
    });

    test('M2: a non-serialisable ingress is rejected before commit and '
        'reported on errors', () async {
      final memory = await MemoryCell.open<Object>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<Object>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      final errors = <Object>[];
      memory.errors.listen(errors.add);
      await deliverValue(memory, () => 'not serialisable');
      expect(memory.value, 0, reason: 'value must not be committed');
      expect(errors, isNotEmpty);
      expect(errors.first, isA<MemoryNotSerializable>());
    });

    test('M3: removed/unloaded pulses from a chained memory cell are not '
        'value updates, and evolved self-pulses are echoes', () async {
      final upstream = await MemoryCell.open<int>(
        id: 'upstream',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 1,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );
      final downstream = await MemoryCell.open<int>(
        id: 'downstream',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );

      // Chain: upstream -> downstream through the public synapses.
      final linked = await upstream.synapses
          .link(upstream, downstreamCell: downstream);
      expect(linked, isTrue);

      await deliverValue(upstream, 7);
      expect(downstream.value, 7);

      await upstream.remove();
      expect(downstream.value, 7,
          reason: 'a removed pulse is not a value update');
      await upstream.unload();
      expect(downstream.value, 7,
          reason: 'an unloaded pulse is not a value update');
    });

    test('a relayed withStep echo does not write a second revision',
        () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );
      // A relay that receives the cell's pulse and sends
      // `pulse.withStep('relay')` back into the same cell.
      final relay = _StepRelay(memory);
      final linked = await memory.synapses.link(memory, downstreamCell: relay);
      expect(linked, isTrue);

      await deliverValue(memory, 4);
      await memory.save();

      expect(memory.value, 4);
      expect(store.writes, 1);
      expect(memory.revision, 1,
          reason: 'a second revision means the stepped pulse was adopted');
    });
  });

  group('second review regressions', () {
    test('a pulse that arrives after close() has latched ingress is not a '
        'value and is not written', () async {
      final gate = Completer<void>();
      final written = <MemoryEnvelope>[];
      final store = _RecordingGatedStore(gate, written);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      await deliverValue(memory, 1); // W1 enters the store, gated.
      final closing = memory.close();
      // The latch is set synchronously: this pulse is dropped.
      await deliverValue(memory, 2);
      gate.complete();
      await closing;
      await Future<void>.delayed(Duration.zero);

      expect([for (final envelope in written) envelope.payload], [1],
          reason: 'close() latched ingress the moment it returned its '
              'future; the later pulse is not a value');
      expect(memory.closed, isTrue);

      // And nothing writes after close completes.
      await deliverValue(memory, 3);
      await Future<void>.delayed(Duration.zero);
      expect(written, hasLength(1));
    });

    test('a pulse accepted before close() is flushed once', () async {
      final gate = Completer<void>();
      final written = <MemoryEnvelope>[];
      final store = _RecordingGatedStore(gate, written);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      await deliverValue(memory, 1); // W1 enters the store, gated.
      await deliverValue(memory, 2); // Accepted before close().
      final closing = memory.close();
      gate.complete();
      await closing;
      await Future<void>.delayed(Duration.zero);

      expect([for (final envelope in written) envelope.payload], [1, 2],
          reason: 'the value accepted before close() returned is flushed '
              'once');
      expect(memory.closed, isTrue);
    });

    test('save returns the envelope of the value it captured and leaves '
        'dirty true when a newer pulse arrived during the write', () async {
      final gate = Completer<void>();
      final written = <MemoryEnvelope>[];
      final store = _RecordingGatedStore(gate, written);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, 1);
      final saving = memory.save(); // W1 gated inside the store.
      await store.started.future; // W1 captured value 1 and is in flight.
      await deliverValue(memory, 2); // Newer value while save is in flight.
      gate.complete();
      final envelope = await saving;

      expect(envelope?.payload, 1,
          reason: 'save returns the envelope of the value it captured');
      expect(memory.dirty, isTrue,
          reason: 'a newer value is still pending; no StateError, no loop');
      final second = await memory.save();
      expect(second?.payload, 2);
      expect(memory.dirty, isFalse);
      expect([for (final e in written) e.payload], [1, 2]);
    });

    test('remove fences a write queued during its drain: no resurrection',
        () async {
      final gate = Completer<void>();
      final written = <MemoryEnvelope>[];
      final store = _RecordingGatedStore(gate, written);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      await deliverValue(memory, 1); // W1 enters the store, gated.
      final removing = memory.remove();
      // Queued while remove waits for W1: it captures the old write epoch
      // and must be fenced — it must never land after the delete.
      await deliverValue(memory, 2);
      gate.complete();
      await removing;
      await Future<void>.delayed(Duration.zero);

      expect(written, hasLength(1),
          reason: 'only the pre-remove write may land; the write queued '
              'during the drain is fenced, not resurrected');
      expect(memory.revision, 0);
    });

    test('close with ownsStore closes the store after the flush', () async {
      final inner = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: inner,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
        ownsStore: true,
      );
      await deliverValue(memory, 1);
      await memory.close();
      await expectLater(inner.read('counter'), throwsA(isA<StateError>()));
    });

    test('open(initial:) on an empty store does not persist until a pulse '
        'arrives (locked v1 behaviour)', () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 7,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      expect(memory.value, 7);
      expect(await memory.save(), isNull);
      expect(await store.read('counter'), isNull,
          reason: 'initial is the value, not a write');
      expect(memory.revision, 0);

      await deliverValue(memory, 8);
      await memory.save();
      expect((await store.read('counter'))?.payload, 8);
    });

    test('a real conflict stays failed without a hot loop; the caller '
        'retries', () async {
      final store = InMemoryMemoryStore();
      await store.write(MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 99),
          expectedRevision: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );
      final errors = <Object>[];
      memory.errors.listen(errors.add);

      await deliverValue(memory, 5);
      await expectLater(memory.save(), throwsA(isA<MemoryConflict>()));
      await expectLater(memory.save(), throwsA(isA<MemoryConflict>()));
      expect(memory.value, 5);
      expect(memory.revision, 0);
      expect(errors, hasLength(2),
          reason: 'one report per failed save, no rescheduling loop');
    });

    test('a conflict whose stored payload is our own write adopts the '
        'stored revision, clears lastError, and emits stored', () async {
      final inner = InMemoryMemoryStore();
      // A backend whose first write commits to the inner store and then
      // throws a conflict with no stored row: the lost response. The cell
      // reads the row back, sees its own generation (the write carried the
      // cell's minted generation), and adopts revision 1.
      final store = _StrictCasStore(inner);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);
      await deliverValue(memory, 5);
      expect(await memory.save(), isNull,
          reason: 'the write already landed; save converges without '
              'rewriting');
      expect(memory.revision, 1);
      expect(memory.lastError, isNull);
      expect((await inner.read('counter'))?.revision, 1);
      final pulses = recorder.memory<int>();
      expect(pulses.last.event, MemoryEvent.stored,
          reason: 'the recovered write is published once it is known to '
              'be the current value');
      expect(pulses.last.revision, 1);

      // And the next value writes from the adopted baseline, with the
      // adopted generation.
      await deliverValue(memory, 6);
      final envelope = await memory.save();
      expect(envelope?.revision, 2);
      expect(envelope?.generation, (await inner.read('counter'))?.generation);
    });

    test('recovery while a newer value is already in memory adopts the '
        'baseline, stays dirty, and emits no stored pulse', () async {
      final inner = InMemoryMemoryStore();
      final gate = Completer<void>();
      // First write lands (revision 1, payload 1); a newer value arrives
      // before the conflict resolves.
      final store = _LostResponseThenGatedStore(inner, gate);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);
      await deliverValue(memory, 1);
      final saving = memory.save();
      // The first write has committed and is about to report the lost
      // response; the newer value lands while it is in flight.
      await store.started.future;
      await deliverValue(memory, 2);
      gate.complete();
      await saving;
      expect(memory.revision, 1,
          reason: 'the landed row is adopted as the baseline');
      expect(memory.dirty, isTrue,
          reason: 'the newer value still needs a write');
      expect(recorder.memory<int>().where((p) => p.event == MemoryEvent.stored),
          isEmpty,
          reason: 'no stored pulse for a value that is already stale');
      // The pulse that made it dirty already scheduled; in explicit mode
      // save() writes it.
      final envelope = await memory.save();
      expect(envelope?.revision, 2);
    });

    test('a codec rejection does not change value, revision, or dirty',
        () async {
      final store = InMemoryMemoryStore();
      final memory = await MemoryCell.open<Object>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<Object>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await deliverValue(memory, () => 'not serialisable');
      expect(memory.value, 0);
      expect(memory.revision, 0);
      expect(await memory.save(), isNull,
          reason: 'the rejected ingress never dirtied the cell');
      expect(await store.read('counter'), isNull);
    });
  });
}

class _SlowStore implements MemoryStore {
  _SlowStore(this.inner);

  final MemoryStore inner;

  int writes = 0;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    writes++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await inner.write(envelope, expectedRevision: expectedRevision);
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}

class _FailingWriteStore implements MemoryStore {
  @override
  Future<MemoryEnvelope?> read(String id) async => null;

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    throw MemoryIoException('injected failure');
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<void> close() async {}
}

class _FailingOwnedStore implements MemoryStore {
  _FailingOwnedStore(this.inner);

  final InMemoryMemoryStore inner;

  bool closed = false;

  int closeCalls = 0;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    throw MemoryIoException('injected failure');
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() async {
    closeCalls++;
    closed = true;
    await inner.close();
  }
}

class _CountingCloseStore implements MemoryStore {
  _CountingCloseStore(this.inner);

  final InMemoryMemoryStore inner;

  int closeCalls = 0;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    await inner.write(envelope, expectedRevision: expectedRevision);
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() async {
    closeCalls++;
    await inner.close();
  }
}

class _StrictCasStore implements MemoryStore {
  _StrictCasStore(this.inner);

  final InMemoryMemoryStore inner;

  bool _faulted = false;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    // The lost-response shape: the first write commits, then reports a
    // conflict with no stored row. Later writes are not faulted.
    if (!_faulted) {
      _faulted = true;
      await inner.write(envelope, expectedRevision: expectedRevision);
      throw MemoryConflict(expected: expectedRevision, actual: envelope.revision);
    }
    await inner.write(envelope, expectedRevision: expectedRevision);
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}

class _LostResponseThenGatedStore implements MemoryStore {
  _LostResponseThenGatedStore(this.inner, this.gate);

  final InMemoryMemoryStore inner;

  final Completer<void> gate;

  /// Completes when the first write has committed and is about to report
  /// the lost response: tests deliver a newer value inside this window.
  final Completer<void> started = Completer<void>();

  bool _faulted = false;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    // The lost-response shape with a window: the first write commits,
    // then waits on the gate before reporting the conflict with no stored
    // row. Later writes are not faulted.
    if (!_faulted) {
      _faulted = true;
      await inner.write(envelope, expectedRevision: expectedRevision);
      if (!started.isCompleted) started.complete();
      await gate.future;
      throw MemoryConflict(expected: expectedRevision, actual: envelope.revision);
    }
    await inner.write(envelope, expectedRevision: expectedRevision);
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}

class _RecordingGatedStore implements MemoryStore {
  _RecordingGatedStore(this.gate, this.written);

  final Completer<void> gate;

  final List<MemoryEnvelope> written;

  /// Completes when a write has captured its value and is about to block:
  /// tests deliver a newer value inside this window.
  final Completer<void> started = Completer<void>();

  @override
  Future<MemoryEnvelope?> read(String id) async => null;

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    if (!started.isCompleted) started.complete();
    await gate.future;
    written.add(envelope);
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<void> close() async {}
}

/// A relay that receives a memory pulse and calls `withStep('relay')` back
/// into the cell it listens to, modelling a downstream hop that echoes.
class _StepRelay extends CellBase {
  _StepRelay(this.target)
      : super(receptor: Receptor((cell, pulse, {user}) {
          final relay = cell as _StepRelay;
          relay.target.synapses.call(pulse.withStep('relay'));
          return null;
        }));

  final MemoryCell<Object?> target;
}

class _CountingStore implements MemoryStore {
  _CountingStore(this.inner);

  final MemoryStore inner;

  int writes = 0;

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    writes++;
    await inner.write(envelope, expectedRevision: expectedRevision);
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}

class _PoisonStore implements MemoryStore {
  _PoisonStore(this.inner);

  final MemoryStore inner;

  @override
  Future<MemoryEnvelope?> read(String id) async {
    final envelope = await inner.read(id);
    if (envelope == null) return null;
    return MemoryEnvelope(
      generation: envelope.generation,
      id: envelope.id,
      revision: envelope.revision,
      payload: 'not-an-int',
      codec: envelope.codec,
    );
  }

  @override
  Future<void> write(MemoryEnvelope envelope,
          {required int expectedRevision}) =>
      inner.write(envelope, expectedRevision: expectedRevision);

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}
