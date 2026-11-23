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
  group('deputy', () {
    test('the deputy is a Cell, not a MemoryCell: durability operations '
        'do not exist on it', () async {
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy = await memory.deputy(testRule: TestCell.readOnly);
      expect(deputy, isA<Cell>());
      expect(deputy, isNot(isA<MemoryCell<int>>()));
      // load/unload/remove are principal-only by construction.
    });

    test('a read-only deputy rejects apply; the principal still accepts',
        () async {
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy = await memory.deputy(testRule: TestCell.readOnly);

      final outcome = await deputy.apply<int>((
        function: (int x) => x,
        arguments: (positionalArguments: [1], namedArguments: null),
        compensation: null,
      ));
      expect(outcome, isA<ApplyRejected<int>>());
    });

    test('principal and deputy see the same value through the bind view',
        () async {
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        initial: 0,
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy = await memory.deputy();
      final seen = <Object?>[];
      final observer = Cell.observe<Pulse<int>>(
        source: deputy,
        effect: (pulse) => seen.add(pulse.payload),
      );
      await deliverValue(memory, 42);
      expect(memory.value, 42);
      expect(seen, contains(42), reason: 'the deputy is a bind view of the '
          'principal and observes its pulses');
      observer.stop();
    });

    test('no-narrowing deputy returns the identical principal', () async {
      final memory = await MemoryCell.open<int>(
        id: 'counter',
        store: InMemoryMemoryStore(),
        codec: JsonMemoryCodec<int>.identity(),
        policy: const MemoryWritePolicy(mode: MemoryWriteMode.explicit),
      );
      final deputy = await memory.deputy();
      expect(identical(deputy, memory), isTrue);
    });
  });
}
