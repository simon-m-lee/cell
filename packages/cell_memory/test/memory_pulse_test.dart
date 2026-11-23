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
  late InMemoryMemoryStore store;
  late MemoryCell<int> memory;

  setUp(() async {
    store = InMemoryMemoryStore();
    memory = await MemoryCell.open<int>(
      id: 'counter',
      store: store,
      codec: JsonMemoryCodec<int>.identity(),
      initial: 0,
      policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      loadOnOpen: false,
    );
  });

  test('a loaded pulse has payload, revision, memory id and implements Pulse',
      () async {
    await seed(store, 'counter', revision: 4, payload: 42);
    final recorder = PulseRecorder();
    await linkRecorder(memory, recorder);
    await memory.load();

    final pulse = recorder.memory<int>().single;
    expect(pulse, isA<Pulse<int>>());
    expect(pulse.event, MemoryEvent.loaded);
    expect(pulse.payload, 42);
    expect(pulse.revision, 4);
    expect(pulse.memoryId, 'counter');
    expect(pulse.source, same(memory));
  });

  test('evolve returns a pulse whose parent is the original', () async {
    final original = memoryApplied<int>(
      source: memory,
      value: 1,
      revision: 0,
    );
    final evolved = original.evolve(step: 'logged');
    expect(evolved, isA<MemoryPulse>());
    expect(evolved.payload, 1);
    // The parent chain is walked by root/trace: the evolved pulse's root is
    // the original, and the step is recorded on the lineage.
    expect(evolved.root, same(original));
    expect(evolved.trace, contains('logged'));
    expect(evolved.event, MemoryEvent.applied);
    expect(evolved.memoryId, 'counter');
    expect(evolved.revision, 0);
    expect(evolved.source, same(memory));
  });

  test('withStep keeps the memory fields', () async {
    final original = memoryLoaded<int>(
      source: memory,
      value: 9,
      revision: 3,
    );
    final stepped = original.withStep('downstream');
    expect(stepped.event, MemoryEvent.loaded);
    expect(stepped.payload, 9);
    expect(stepped.revision, 3);
    expect(stepped.memoryId, 'counter');
    expect(stepped.trace, contains('downstream'));
    expect(stepped.source, same(memory));
  });

  test('unmodifiable preserves memory fields', () async {
    final original = memoryApplied<int>(
      source: memory,
      value: 5,
      revision: 1,
    );
    final readOnly = original.unmodifiable;
    expect(readOnly.payload, 5);
    expect(readOnly.event, MemoryEvent.applied);
    expect(readOnly.revision, 1);
    expect(readOnly.memoryId, 'counter');
    expect(() => readOnly.evolve(step: 'x'), throwsUnsupportedError);
  });
}
