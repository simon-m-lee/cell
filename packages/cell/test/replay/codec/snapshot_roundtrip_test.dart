// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

import 'package:test/test.dart';

void main() {
  group('CellSnapshot', () {
    test('round-trips all fields', () {
      final snapshot = CellSnapshot(
        id: 'graph-1:user.name',
        configFingerprint: fingerprint({'receptor': 'r', 'version': 'v2'}),
        receptorVersion: 'v2',
        value: {'count': 3},
        extras: {'region': 'eu'},
      );
      final restored = CellSnapshot.fromJson(snapshot.toJson());
      expect(restored.id, snapshot.id);
      expect(restored.configFingerprint, snapshot.configFingerprint);
      expect(restored.receptorVersion, 'v2');
      expect(restored.value, {'count': 3});
      expect(restored.extras, {'region': 'eu'});
    });

    test('defaults receptorVersion to empty and extras to empty map', () {
      final restored = CellSnapshot.fromJson({
        'id': 'c1',
        'configFingerprint': 'f',
        'value': null,
      });
      expect(restored.receptorVersion, '');
      expect(restored.extras, isEmpty);
    });
  });

  group('CellGraphSnapshot', () {
    test('round-trips a full graph', () {
      final graph = CellGraphSnapshot(
        graphId: 'graph-uuid',
        schemaVersion: CellGraphSnapshot.currentSchemaVersion,
        lastLedgerSeq: 41,
        parentLedgerHash: 'sha256:ledger',
        cells: [
          CellSnapshot(
            id: 'a',
            configFingerprint: fingerprint('a'),
            receptorVersion: '1',
            value: 1,
          ),
          CellSnapshot(
            id: 'b',
            configFingerprint: fingerprint('b'),
            receptorVersion: '1',
            value: 'two',
          ),
        ],
      );
      final restored = CellGraphSnapshot.fromJson(graph.toJson());
      expect(restored.graphId, 'graph-uuid');
      expect(restored.schemaVersion, CellGraphSnapshot.currentSchemaVersion);
      expect(restored.lastLedgerSeq, 41);
      expect(restored.parentLedgerHash, 'sha256:ledger');
      expect(restored.cells.map((c) => c.id), ['a', 'b']);
    });

    test('defaults lastLedgerSeq to -1 and parentLedgerHash to null', () {
      final restored = CellGraphSnapshot.fromJson({
        'graphId': 'g',
        'schemaVersion': CellGraphSnapshot.currentSchemaVersion,
        'cells': <Object?>[],
      });
      expect(restored.lastLedgerSeq, -1);
      expect(restored.parentLedgerHash, isNull);
    });

    test('rejects a schema version newer than the codec', () {
      expect(
        () => CellGraphSnapshot.fromJson({
          'graphId': 'g',
          'schemaVersion': CellGraphSnapshot.currentSchemaVersion + 1,
          'cells': <Object?>[],
        }),
        throwsFormatException,
      );
    });
  });

  group('Cell.id', () {
    test('is a stable, non-empty string for a fresh cell', () {
      final cell = Cell.ingress<int>().cell;
      final id = cell.id;
      expect(id, isNotEmpty);
      expect(id, startsWith('nucleus:'));
      expect(cell.id, id); // stable across calls
    });

    test('is available on state and derived cells', () {
      final state = Cell.state<int>(initial: 1);
      expect(state.cell.id, isNotEmpty);

      final derived = Cell.derive<Pulse<int>, Pulse<int>>(
        source: state.cell,
        project: (p) => Pulse<int>((p.payload ?? 0) + 1),
      );
      expect(derived.id, isNotEmpty);
      expect(derived.id, isNot(state.cell.id));
    });

    test('a deputy shares its principal id (the serialisation layer behaviour)', () async {
      final cell = Cell.ingress<int>().cell;
      final deputy = await cell.deputy(testRule: TestCell.readOnly);
      expect(deputy.id, cell.id);
    });

    test('id is parallel to hashCode, not a replacement for it', () {
      final cell = Cell.ingress<int>().cell;
      expect(cell.id, isNot(cell.hashCode.toString()));
      // `id` is a wire identity: the hashCode contract is untouched.
      expect(cell.hashCode, cell.hashCode);
    });
  });
}
