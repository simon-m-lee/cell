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

/// A store that counts writes and forwards everything else.
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

/// A store that counts reads too, for the invalidated-policy probe.
class _ReadCountingStore extends _CountingStore {
  _ReadCountingStore(super.inner);

  int reads = 0;

  @override
  Future<MemoryEnvelope?> read(String id) {
    reads++;
    return inner.read(id);
  }
}

void main() {
  group('MemoryCell deputy', () {
    test('deputy() with default arguments returns the same instance, on the '
        'principal and on a deputy', () async {
      final memory = await MemoryCell.open<int>(
        id: 'identity',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: MemoryWritePolicy.replay,
      );
      final deputy = await memory.deputy(testRule: TestCell.readOnly);

      expect(identical(await memory.deputy(), memory), isTrue);
      expect(identical(await deputy.deputy(), deputy), isTrue);

      await memory.close();
    });

    test('a context that is not a child of the current context throws the '
        'causal-integrity StateError', () async {
      final base = Context(identity: 'principal', type: 'module');
      final memory = await MemoryCell.open<int>(
        id: 'context',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        context: base,
        policy: MemoryWritePolicy.replay,
      );
      final unrelated = Context(identity: 'other', type: 'module');
      final notAChild =
          DeputyContext(baseContext: unrelated, authority: 'READ');

      expect(
        () => memory.deputy(context: notAChild),
        throwsA(isA<StateError>()),
      );

      await memory.close();
    });

    test('a load-only deputy loads the principal value, rejects save without '
        'writing, and shares identity', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      await seed(store.inner, 'narrow', revision: 2, payload: 41);
      final memory = await MemoryCell.open<int>(
        id: 'narrow',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy =
          await memory.deputy(testRule: MemoryCell.allow({MemoryAction.load}));

      expect(await deputy.load(), 41, reason: 'the principal value');
      expect(deputy.value, 41);

      await expectLater(
        deputy.save(),
        throwsA(isA<StateError>()),
        reason: 'save is not in the allow set',
      );
      expect(store.writeAttempts, 0, reason: 'the rejected save wrote nothing');

      expect(identical(deputy.runtimeForTest, memory.runtimeForTest), isTrue);
      expect(deputy, memory, reason: 'a deputy equals its principal');
      expect(deputy.hashCode, memory.hashCode);
      expect(deputy.id, memory.id);
      expect(deputy.id, isNot(deputy.memoryId));

      await memory.close();
    });

    test('a deputy of a deputy can only narrow further', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'narrow2',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy =
          await memory.deputy(testRule: MemoryCell.allow({MemoryAction.load}));
      final deputy2 = await deputy.deputy(
        testRule:
            MemoryCell.allow({MemoryAction.load, MemoryAction.save, MemoryAction.remove}),
      );

      expect(await deputy2.load(), 0, reason: 'load stays allowed');
      await expectLater(
        deputy2.save(),
        throwsA(isA<StateError>()),
        reason: 'the outer allow({load}) still rejects save',
      );
      expect(store.writeAttempts, 0);

      await memory.close();
    });

    test('a context-only deputy save writes once and both registries observe '
        'the stored pulse once', () async {
      final base = Context(identity: 'principal', type: 'module');
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'context-save',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        context: base,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final child = DeputyContext(baseContext: base, authority: 'WRITE');
      final deputy = await memory.deputy(context: child);

      await ingest(memory, 5); // dirty the shared runtime

      final principalPulses = <Pulse>[];
      final deputyPulses = <Pulse>[];
      Cell.observe<Pulse>(source: memory, effect: principalPulses.add);
      Cell.observe<Pulse>(source: deputy, effect: deputyPulses.add);

      await deputy.save();

      expect(store.writes, 1, reason: 'one write');
      expect(principalPulses, hasLength(1),
          reason: 'the principal observer saw the stored pulse once');
      expect(deputyPulses, hasLength(1),
          reason: 'the deputy observer saw the stored pulse once');
      expect(principalPulses.single, isA<MemoryPulse<int>>());
      expect((principalPulses.single as MemoryPulse).event, MemoryEvent.stored);

      await memory.close();
    });

    test('the same observer on both registries receives two calls', () async {
      final base = Context(identity: 'principal', type: 'module');
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'both',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        context: base,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final child = DeputyContext(baseContext: base, authority: 'WRITE');
      final deputy = await memory.deputy(context: child);
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);
      await linkRecorder(deputy, recorder);

      await ingest(memory, 5);
      await deputy.save();

      expect(recorder.memory<int>(), hasLength(2),
          reason: 'two registries, one stored pulse each');

      await memory.close();
    });

    test('the unmodifiable view seals the durability methods and never '
        'touches the store', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'ro',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 3,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final view = memory.unmodifiable;

      expect(() => view.save(), throwsA(isA<UnsupportedError>()));
      expect(() => view.load(), throwsA(isA<UnsupportedError>()));
      expect(() => view.unload(), throwsA(isA<UnsupportedError>()));
      expect(() => view.close(), throwsA(isA<UnsupportedError>()));
      expect(() => view.remove(), throwsA(isA<UnsupportedError>()));
      expect(() => view.detach(), throwsA(isA<UnsupportedError>()));
      expect(
        () => view.attach(Cell.state<int>(initial: 0).cell),
        throwsA(isA<UnsupportedError>()),
      );
      expect(store.writeAttempts, 0);
      expect(memory.value, 3, reason: 'the sealed methods left the cell alone');

      expect(
        identical(view.deputy(testRule: TestCell.allowAll), view),
        isTrue,
        reason: 'the view returns itself for every argument set',
      );
      expect(identical(view.unmodifiable, view), isTrue);

      await memory.close();
    });

    test('the unmodifiable view reads the principal value after a save',
        () async {
      final memory = await MemoryCell.open<int>(
        id: 'ro-value',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final view = memory.unmodifiable;

      await ingest(memory, 5);
      await memory.save();

      expect(view.value, 5, reason: 'the view reads the shared runtime');
      expect(identical(view.runtimeForTest, memory.runtimeForTest), isTrue);

      await memory.close();
    });

    test('observers of the unmodifiable view do not hear principal saves',
        () async {
      final memory = await MemoryCell.open<int>(
        id: 'ro-observe',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final view = memory.unmodifiable;
      final recorder = PulseRecorder();
      await linkRecorder(view, recorder);

      await ingest(memory, 5);
      await memory.save();

      expect(recorder.pulses, isEmpty,
          reason: 'principal emissions stay on the principal registry; a '
              'mirror is a later change');

      await memory.close();
    });

    test('Cell.transaction commit through a load-only deputy and through the '
        'unmodifiable view changes nothing', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'tx',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 7,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy =
          await memory.deputy(testRule: MemoryCell.allow({MemoryAction.load}));
      final view = memory.unmodifiable;

      await expectLater(
        deliverValue(deputy, 9),
        throwsA(isA<TransactionValidationException>()),
        reason: 'the load-only rule rejects the governed value at commit',
      );
      await expectLater(
        deliverValue(view, 10),
        throwsA(isA<TransactionValidationException>()),
        reason: 'the unmodifiable view drops every adopt',
      );

      expect(memory.value, 7, reason: 'neither governed adopt landed');
      expect(view.value, 7);
      expect(store.writeAttempts, 0);

      await memory.close();
    });

    test('close() on the principal does not set isInvalidated', () async {
      final memory = await MemoryCell.open<int>(
        id: 'close-flags',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: MemoryWritePolicy.replay,
      );
      expect(memory.isInvalidated, isFalse);

      await memory.close();

      expect(memory.isInvalidated, isFalse,
          reason: 'close() is not invalidation');
    });

    test('a deputy whose EphemeralPolicy is already invalidated rejects the '
        'next load without reading or writing', () async {
      final store = _ReadCountingStore(InMemoryMemoryStore());
      final memory = await MemoryCell.open<int>(
        id: 'expired',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 4,
        loadOnOpen: false,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final policy = EphemeralPolicy<MemoryCell<int>>(
        onEvent: (
          object, {
          required MemoryCell<int> cell,
          dynamic arguments,
          required EphemeralPolicy<Cell> policy,
          dynamic user,
        }) =>
            (events: 0),
        onInvalidate: (nucleus) => true,
        eventLimit: 1,
      );
      policy.invalidate(memory);
      final deputy = await memory.deputy(ephemeralPolicy: policy);

      // `_proceed` drops the command before the dispatcher runs, so the
      // reply never completes; the load future stays pending. That is the
      // framework's drop semantics — the cell is not closed, the command
      // was just rejected.
      unawaited(deputy.load());
      await Future<void>.delayed(Duration.zero);

      expect(store.reads, 0, reason: 'the load never read the store');
      expect(store.writeAttempts, 0);
      expect(memory.value, 4, reason: 'the value is unchanged');

      await memory.close();
    });

    test('two opens: a deputy of one does not share the other runtime',
        () async {
      final store = InMemoryMemoryStore();
      final a = await MemoryCell.open<int>(
        id: 'a',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        policy: MemoryWritePolicy.replay,
      );
      final b = await MemoryCell.open<int>(
        id: 'b',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        policy: MemoryWritePolicy.replay,
      );
      final deputyOfA = await a.deputy(testRule: TestCell.readOnly);

      expect(
        identical(deputyOfA.runtimeForTest, b.runtimeForTest),
        isFalse,
      );
      expect(identical(deputyOfA.runtimeForTest, a.runtimeForTest), isTrue);

      await a.close();
      await b.close();
    });
  });
}
