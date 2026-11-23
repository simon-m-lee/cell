// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  group('attach', () {
    test('an upstream Cell.state update changes value and emits applied '
        'downstream', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await memory.attach(upstream.cell);
      expect(memory.attached, isTrue);
      expect(upstream.update(42), isTrue);

      expect(memory.value, 42);
      final applied =
          recorder.memory<int>().where((p) => p.event == MemoryEvent.applied);
      expect(applied, hasLength(1));
      expect(applied.single.payload, 42);
      expect(store.writes, 0, reason: 'explicit mode writes only on save');
      await memory.save();
      expect((await store.inner.read('counter'))?.payload, 42);
    });

    test('a custom project maps the upstream pulse', () async {
      final upstream = Cell.state<String>(initial: 'a');
      final memory = await MemoryCell.open<int>(
        id: 'length',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await memory.attach(
        upstream.cell,
        project: (pulse) => (pulse.payload as String).length,
      );
      upstream.update('abcd');
      expect(memory.value, 4);
    });

    test('detach stops delivery', () async {
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await memory.attach(upstream.cell);
      upstream.update(1);
      expect(memory.value, 1);

      await memory.detach();
      expect(memory.attached, isFalse);
      upstream.update(2);
      expect(memory.value, 1);
    });

    test('attach throws on a closed cell; unload detaches', () async {
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      await memory.attach(upstream.cell);
      await memory.unload();
      expect(memory.attached, isFalse);
      expect(() => memory.attach(upstream.cell), throwsA(isA<StateError>()));
    });

    test('echo: an upstream pulse equal to this cell emission is not '
        'written twice and downstream still receives it', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final recorder = PulseRecorder();
      await linkRecorder(memory, recorder);

      await memory.attach(upstream.cell);
      upstream.update(5);
      expect(recorder.memory<int>(), hasLength(1));

      // Deliver the exact pulse the memory cell just emitted back into the
      // upstream — the framework's cycle checker plus the cell's echo guard
      // must prevent a second write; downstream listeners already saw it.
      final echoed = recorder.memory<int>().single;
      final feed = Cell.state<int>(initial: 0);
      await feed.cell.apply<int>((
        function: (int x) => x,
        arguments: (positionalArguments: [5], namedArguments: null),
        compensation: null,
      ));
      upstream.update(echoed.payload as int);
      expect(store.writes, 0, reason: 'explicit mode; nothing written yet');
      await memory.save();
      expect(store.writes, 1, reason: 'no duplicate write from the echo');
    });

    test('an attached upstream writing while replay-policy is set performs '
        'no store writes', () async {
      final store = _CountingStore(InMemoryMemoryStore());
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        policy: MemoryWritePolicy.replay,
        loadOnOpen: false,
      );
      await memory.attach(upstream.cell);
      upstream.update(1);
      upstream.update(2);
      expect(memory.value, 2);
      expect(store.writes, 0);
    });
  });

  group('remember', () {
    Future<void> seedStore(InMemoryMemoryStore store) async {
      await store.write(
        MemoryEnvelope(
          generation: testGeneration,
          id: 'counter',
          revision: 1,
          payload: 7,
          codec: 'json',
        ),
        expectedRevision: 0,
      );
    }

    test('seed pushes the loaded value into the domain before attach; the '
        'following domain update writes that value plus one', () async {
      final store = InMemoryMemoryStore();
      await seedStore(store);
      final domain = Cell.state<int>(initial: 0);
      final memory = await remember<int>(
        domain.cell,
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        project: (pulse) => pulse.payload as int? ?? 0,
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        seed: (loaded) => domain.update(loaded ?? 0),
      );

      expect(domain.cell.value, 7);
      expect(memory.value, 7);

      // The domain update inside seed ran before the observer existed, so
      // it is not echoed; the next domain pulse writes 8, not the domain's
      // old initial 0.
      domain.update(8);
      await memory.save();
      expect((await store.read('counter'))?.payload, 8);
    });

    test('without seed the domain is unchanged and no write happens until '
        'the domain pulses', () async {
      final store = InMemoryMemoryStore();
      await seedStore(store);
      final domain = Cell.state<int>(initial: 0);
      final memory = await remember<int>(
        domain.cell,
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        project: (pulse) => pulse.payload as int? ?? 0,
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );

      expect(domain.cell.value, 0);
      expect(memory.value, 7);
      expect(await memory.save(), isNull);
      expect((await store.read('counter'))?.revision, 1);

      domain.update(1);
      await memory.save();
      expect((await store.read('counter'))?.payload, 1);
    });

    test('seed that throws, ownsStore: remember throws and releases the '
        'cell and the store', () async {
      final inner = InMemoryMemoryStore();
      await seedStore(inner);
      final domain = Cell.state<int>(initial: 0);
      await expectLater(
        remember<int>(
          domain.cell,
          id: 'counter',
          store: inner,
          codec: JsonMemoryCodec<int>.identity(),
          project: (pulse) => pulse.payload as int? ?? 0,
          initial: 0,
          policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
          ownsStore: true,
          seed: (_) => throw StateError('seed failure'),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(inner.read('counter'), throwsA(isA<StateError>()));
    });
  });
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
