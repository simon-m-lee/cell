// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  group('concurrency', () {
    test('a load that started first does not overwrite an applied value, '
        'but still adopts the store revision so later writes count from it',
        () async {
      final store = _GatedStore(InMemoryMemoryStore());
      await store.inner.write(
          MemoryEnvelope(generation: testGeneration, id: 'counter', revision: 1, payload: 10),
          expectedRevision: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
        loadOnOpen: false,
      );

      // Start load; the store read is gated.
      final loadFuture = memory.load();
      // While the read is in flight, accept a new value.
      await deliverValue(memory, 42);
      // Release the read.
      store.releaseRead();
      await loadFuture;

      expect(memory.value, 42,
          reason: 'the stale load result must be dropped');
      expect(memory.revision, 1,
          reason: 'the envelope revision must still be adopted or every '
              'later write conflicts against revision 0');
      expect(memory.loaded, isTrue);

      // The wedge check: a later save writes 2, not a conflict against 0.
      final envelope = await memory.save();
      expect(envelope?.revision, 2);
      expect((await store.inner.read('counter'))?.payload, 42);
    });

    test('two memory cells on one store write in parallel without sharing '
        'a lock', () async {
      final store = _SlowStore(InMemoryMemoryStore());
      final a = await MemoryCell.open<int>(
        id: 'a',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );
      final b = await MemoryCell.open<int>(
        id: 'b',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
      );

      // Gate id 'a' writes; id 'b' must proceed without waiting.
      store.gateId('a');
      await deliverValue(a, 1);
      final bWrite = Future.sync(() async {
        await deliverValue(b, 2);
        await b.save();
      });
      await bWrite.timeout(const Duration(seconds: 2),
          onTimeout: () => fail('id "b" was blocked by id "a"'));
      expect(store.overlapped, isTrue);
      store.release('a');
      await a.save();
      expect((await store.inner.read('a'))?.payload, 1);
      expect((await store.inner.read('b'))?.payload, 2);
    });
  });
}

class _GatedStore implements MemoryStore {
  _GatedStore(this.inner);

  final MemoryStore inner;

  final Completer<void> _gate = Completer<void>();

  void releaseRead() => _gate.complete();

  @override
  Future<MemoryEnvelope?> read(String id) async {
    await _gate.future;
    return inner.read(id);
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

class _SlowStore implements MemoryStore {
  _SlowStore(this.inner);

  final MemoryStore inner;

  String? _gatedId;

  int _inFlight = 0;

  bool overlapped = false;

  void gateId(String id) => _gatedId = id;

  void release(String id) {
    _gatedId = null;
    _releaseFor(id);
  }

  final Map<String, Completer<void>> _gates = {};

  void _releaseFor(String id) {
    final gate = _gates.remove(id);
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<MemoryEnvelope?> read(String id) => inner.read(id);

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    _inFlight++;
    if (_inFlight > 1) overlapped = true;
    final gate = _gates.putIfAbsent(envelope.id, Completer<void>.new);
    if (_gatedId != envelope.id) {
      _releaseFor(envelope.id);
    }
    await gate.future;
    await inner.write(envelope, expectedRevision: expectedRevision);
    _inFlight--;
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<List<String>> list() => inner.list();

  @override
  Future<void> close() => inner.close();
}
