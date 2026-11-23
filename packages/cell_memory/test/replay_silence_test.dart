// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

void main() {
  group('replay silence', () {
    test('with MemoryWritePolicy.replay, domain pulses perform zero writes '
        'and open does not read', () async {
      final store = _FailOnWriteStore();
      final upstream = Cell.state<int>(initial: 0);
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: MemoryWritePolicy.replay,
        loadOnOpen: false, // replay callers disable load
      );
      expect(store.reads, 0, reason: 'open must not read in replay mode');

      await memory.attach(upstream.cell);
      upstream.update(1);
      upstream.update(2);
      await memory.save(); // settle barrier; enabled: false → no-op
      expect(memory.value, 2);
      expect(store.writes, 0);
      expect(store.reads, 0);
    });

    test('save and unload also refuse to write under replay', () async {
      final store = _FailOnWriteStore();
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: store,
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: MemoryWritePolicy.replay,
        loadOnOpen: false,
      );
      await memory.attach(Cell.state<int>(initial: 0).cell);
      expect(await memory.save(), isNull);
      await memory.unload();
      expect(store.writes, 0);
    });
  });
}

/// A store that fails the test if `write` is invoked — the replay guard's
/// contract.
class _FailOnWriteStore implements MemoryStore {
  int reads = 0;

  int writes = 0;

  @override
  Future<MemoryEnvelope?> read(String id) async {
    reads++;
    return null;
  }

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    writes++;
    throw StateError('replay must never write');
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<void> close() async {}
}
