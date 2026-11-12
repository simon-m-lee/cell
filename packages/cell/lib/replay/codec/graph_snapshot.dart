// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A serialisable snapshot of an entire cell graph.
///
/// Sits alongside `Ledger` (Phase 4) as one of the two persistence units.
/// A snapshot is the *state* at a point in time; a ledger is the *history*
/// that produced it. Both are needed for replay: replay replays the ledger
/// from a snapshot's `lastLedgerSeq`.
class CellGraphSnapshot {
  /// A UUID identifying the graph. Assigned by `CellGraphBuilder`.
  final String graphId;

  /// A monotonic version of the codec itself, so a future schema change
  /// can be detected on read and routed to a migration path.
  final int schemaVersion;

  /// The ledger sequence number at which this snapshot was taken. Phase 4
  /// supplies this; Phase 1 accepts it verbatim (or `-1` for a snapshot
  /// taken before any ledger exists).
  final int lastLedgerSeq;

  /// Merkle root of the ledger *up to* [lastLedgerSeq]. Phase 4 computes
  /// it; Phase 1 serialises it opaquely.
  final String? parentLedgerHash;

  /// Per-cell snapshots, sorted by id.
  final List<CellSnapshot> cells;

  const CellGraphSnapshot({
    required this.graphId,
    required this.schemaVersion,
    required this.lastLedgerSeq,
    this.parentLedgerHash,
    required this.cells,
  });

  /// The current on-disk schema version. Increment this any time the
  /// serialised representation of `CellGraphSnapshot`, `CellSnapshot`,
  /// `PulseCodec`, or `PulseContextCodec` changes in a way that old data
  /// cannot parse.
  static const int currentSchemaVersion = 1;

  Map<String, Object?> toJson() => {
        'graphId': graphId,
        'schemaVersion': schemaVersion,
        'lastLedgerSeq': lastLedgerSeq,
        if (parentLedgerHash != null) 'parentLedgerHash': parentLedgerHash,
        'cells': cells.map((c) => c.toJson()).toList(growable: false),
      };

  factory CellGraphSnapshot.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'] as int?;
    if (version == null || version > currentSchemaVersion) {
      throw FormatException(
        'CellGraphSnapshot: unsupported schemaVersion $version '
        '(current $currentSchemaVersion)',
      );
    }
    final rawCells = json['cells'];
    if (rawCells is! List) {
      throw const FormatException('CellGraphSnapshot: cells must be a list');
    }
    return CellGraphSnapshot(
      graphId: json['graphId'] as String,
      schemaVersion: version,
      lastLedgerSeq: (json['lastLedgerSeq'] as int?) ?? -1,
      parentLedgerHash: json['parentLedgerHash'] as String?,
      cells: rawCells
          .whereType<Map>()
          .map((m) => CellSnapshot.fromJson(m.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}
