// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Phase 1, exit item 7: this file deliberately imports ONLY the replay
// barrel — the Phase 1 public API must be usable without importing
// `package:cell/cell.dart`.
import 'package:cell/replay.dart';

import 'package:test/test.dart';

void main() {
  group('canonicalJsonEncode', () {
    test('sorts map keys regardless of insertion order', () {
      final a = canonicalJsonEncode({'zeta': 1, 'alpha': 2, 'mid': 3});
      final b = canonicalJsonEncode({'mid': 3, 'alpha': 2, 'zeta': 1});
      expect(a, b);
      expect(a, '{"alpha":2,"mid":3,"zeta":1}');
    });

    test('handles nested maps and lists', () {
      final json = canonicalJsonEncode({
        'b': [1, {'y': 2, 'x': 3}],
        'a': {'nested': null},
      });
      expect(json, '{"a":{"nested":null},"b":[1,{"x":3,"y":2}]}');
    });

    test('distinguishes int from double', () {
      expect(canonicalJsonEncode(1), '1');
      expect(canonicalJsonEncode(1.0), '1.0');
      expect(canonicalJsonEncode({'v': 1}), '{"v":1}');
      expect(canonicalJsonEncode({'v': 1.0}), '{"v":1.0}');
    });

    test('rejects NaN and Infinity loudly', () {
      expect(() => canonicalJsonEncode(double.nan), throwsArgumentError);
      expect(
        () => canonicalJsonEncode(double.infinity),
        throwsArgumentError,
      );
      expect(
        () => canonicalJsonEncode({'v': double.nan}),
        throwsArgumentError,
      );
    });

    test('rejects non-string map keys', () {
      expect(() => canonicalJsonEncode({1: 'a'}), throwsArgumentError);
    });

    test('rejects DateTime and other non-JSON objects', () {
      expect(
        () => canonicalJsonEncode(DateTime.utc(2026)),
        throwsArgumentError,
      );
      expect(() => canonicalJsonEncode(Object()), throwsArgumentError);
    });

    test('escapes strings exactly like jsonEncode', () {
      final source = 'hello "world"\n\u0001中文';
      final value = {'s': source};
      expect(
        canonicalJsonEncode(value),
        '{"s":"hello \\"world\\"\\n\\u0001中文"}',
      );
    });

    test('omitNulls drops null values recursively', () {
      final value = {
        'keep': 1,
        'drop': null,
        'nested': {'alsoDrop': null, 'stay': true},
      };
      expect(
        canonicalJsonEncode(value, omitNulls: true),
        '{"keep":1,"nested":{"stay":true}}',
      );
    });

    test('canonicalJsonDecode is the matched decoder', () {
      final tree = canonicalJsonDecode('{"a":[1,2.5,true,null]}');
      expect(tree, isA<Map<String, dynamic>>());
      expect((tree as Map)['a'], [1, 2.5, true, null]);
    });
  });

  group('fingerprint', () {
    test('is deterministic and map-order independent', () {
      final a = fingerprint({'x': 1, 'y': 'two'});
      final b = fingerprint({'y': 'two', 'x': 1});
      expect(a, b);
    });

    test('is a 64-character hex SHA-256', () {
      final hex = fingerprint({'v': 1});
      expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('changes when the value changes', () {
      expect(fingerprint({'v': 1}), isNot(fingerprint({'v': 2})));
      expect(fingerprint({'v': 1}), isNot(fingerprint({'v': 1.0})));
    });
  });

  group('barrel surface', () {
    test('package:cell/replay.dart alone exposes the Phase 1 API', () {
      // Compile-time proof: these identifiers resolve through the barrel
      // without importing package:cell/cell.dart.
      final snapshot = CellSnapshot(
        id: 'cell-1',
        configFingerprint: fingerprint({'receptor': 'r1', 'version': 'v1'}),
        receptorVersion: 'v1',
        value: 7,
      );
      final graph = CellGraphSnapshot(
        graphId: 'graph-1',
        schemaVersion: CellGraphSnapshot.currentSchemaVersion,
        lastLedgerSeq: -1,
        cells: [snapshot],
      );
      final restored = CellGraphSnapshot.fromJson(graph.toJson());
      expect(restored.graphId, 'graph-1');
      expect(restored.cells.single.value, 7);

      // The codec classes themselves are also exported.
      const types = <Type>[
        PulseCodec,
        PulseContextCodec,
        CellSnapshot,
        CellGraphSnapshot,
      ];
      expect(types, hasLength(4));
    });
  });
}
