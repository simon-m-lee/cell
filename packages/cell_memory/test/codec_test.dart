// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_memory/cell_memory.dart';
import 'package:test/test.dart';

void main() {
  group('JsonMemoryCodec.identity', () {
    test('round-trips int, String, Map, List, bool, null', () {
      final codec = JsonMemoryCodec<int>.identity();
      expect(codec.name, 'json');
      expect(codec.encode(7), 7);
      expect(codec.decode(7), 7);

      final strings = JsonMemoryCodec<String>.identity();
      expect(strings.decode(strings.encode('hello')), 'hello');

      final maps = JsonMemoryCodec<Map<String, Object?>>.identity();
      final map = {'a': 1, 'b': [true, null]};
      expect(maps.decode(maps.encode(map)), map);
    });

    test('a failed decode cast throws MemoryCorrupt', () {
      final codec = JsonMemoryCodec<int>.identity();
      expect(() => codec.decode('nope'), throwsA(isA<MemoryCorrupt>()));
    });
  });

  group('JsonMemoryCodec.mapped', () {
    test('round-trips through toJson / fromJson', () {
      final codec = JsonMemoryCodec<Point>.mapped(
        toJson: (p) => [p.x, p.y],
        fromJson: (payload) {
          final list = payload as List;
          return Point(list[0] as int, list[1] as int);
        },
      );
      final restored = codec.decode(codec.encode(Point(3, 4)));
      expect(restored.x, 3);
      expect(restored.y, 4);
    });
  });

  group('serialisability', () {
    test('a closure is rejected with MemoryNotSerializable before the store',
        () async {
      final writes = <MemoryEnvelope>[];
      _RecordingStore(writes);
      final codec = JsonMemoryCodec<Object>.identity();
      expect(() => codec.encode(() => 1), throwsA(isA<MemoryNotSerializable>()));
      expect(writes, isEmpty);
    });

    test('a nested closure inside a map is rejected', () {
      final codec = JsonMemoryCodec<Map<String, Object?>>.identity();
      expect(
        () => codec.encode({'fn': () => 1}),
        throwsA(isA<MemoryNotSerializable>()),
      );
    });

    test('encode returns a deep copy, so payloads never alias the value '
        'or each other', () {
      final codec = JsonMemoryCodec<List<int>>.identity();
      final original = [1, 2];
      final first = codec.encode(original);
      final second = codec.encode(original);
      expect(first, original);
      expect(identical(first, original), isFalse);
      expect(identical(first, second), isFalse);
      (first! as List).add(99);
      expect(original, [1, 2]);
    });

    test('a double cell decodes an int payload (web writes 1.0 as 1)',
        () {
      final codec = JsonMemoryCodec<double>.identity();
      expect(codec.decode(1), 1.0,
          reason: 'cross-platform number semantics: int 1 decodes as the '
              'double 1.0');
      expect(codec.decode(1.5), 1.5);
    });

    test('an int cell still rejects a fractional payload', () {
      final codec = JsonMemoryCodec<int>.identity();
      expect(() => codec.decode(1.5), throwsA(isA<MemoryCorrupt>()));
    });
  });
}

class Point {
  const Point(this.x, this.y);

  final int x;
  final int y;
}

class _RecordingStore implements MemoryStore {
  _RecordingStore(this.writes);

  final List<MemoryEnvelope> writes;

  @override
  Future<void> close() async {}

  @override
  Future<List<String>> list() async => const [];

  @override
  Future<MemoryEnvelope?> read(String id) async => null;

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> write(MemoryEnvelope envelope,
      {required int expectedRevision}) async {
    writes.add(envelope);
  }
}
