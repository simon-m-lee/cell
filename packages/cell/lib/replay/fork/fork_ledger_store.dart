// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A `LedgerStore` wrapper that injects a synthetic `ForkRecord` entry
/// at seq 0.
///
/// This lets `Ledger` and `Ledger.verify` operate on a fork without
/// changing their implementation — the fork is just a ledger whose
/// genesis happens to be a `ForkRecord`.
///
/// ### Non-obvious: the synthetic entry is a *real* chain entry
///
/// Its `hash` is computed by the same `HashChain.nextHash` every other
/// entry uses (`prevHash` = the fork record's genesis hash, seq 0, empty
/// pulse/effects/deltas, stable synthetic receipt). The fork's real
/// entries then chain from that hash. The doc's alternative — making the
/// synthetic hash equal `ForkRecord.genesisHash` — cannot verify: the
/// recomputed hash would differ from the stored one.
///
/// The synthetic entry is also **injected into the inner store** on the
/// first append: the inner store's genesis check (Phase 4) must pass
/// against the fork record's genesis hash, and it can only pass for the
/// synthetic entry itself.
class ForkLedgerStore implements LedgerStore {
  final ForkRecord record;
  final LedgerStore inner;

  /// Cached synthetic entry — deterministic (stable closure marker and
  /// cell id), so its hash and receipt digest never change between
  /// `entriesSince` calls.
  late final LedgerEntry _synthetic = _buildSyntheticEntry();

  bool _injected = false;

  ForkLedgerStore({required this.record, required this.inner});

  /// The fork's chain genesis. [inner] must have been created with this
  /// value — `CellGraphFork.fork` passes it to the caller's store
  /// factory.
  @override
  String get genesisHash => record.genesisHash;

  @override
  Future<void> append(LedgerEntry entry) async {
    await _ensureInjected();
    await inner.append(entry);
  }

  Future<void> _ensureInjected() async {
    if (_injected) return;
    _injected = true;
    await inner.append(_synthetic);
  }

  @override
  Future<int> get lastSeq async {
    final last = await inner.lastSeq;
    return last < 0 ? 0 : last;
  }

  @override
  Future<String?> get lastHash async {
    final innerLast = await inner.lastHash;
    return innerLast ?? _synthetic.hash;
  }

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    if (fromSeq <= 0) {
      yield _synthetic;
    }
    // The inner store also holds the injected synthetic at seq 0; skip
    // it when streaming.
    await for (final entry in inner.entriesSince(fromSeq <= 0 ? 1 : fromSeq)) {
      yield entry;
    }
  }

  @override
  Future<void> close() async {
    await inner.close();
  }

  LedgerEntry _buildSyntheticEntry() {
    final cell = _ForkCell(record);
    final receipt = (
      id: 'fork:${record.forkId}',
      cell: cell,
      function: _forkRecordMarker,
      arguments: (
        positionalArguments: null,
        namedArguments: null,
      ),
      timestamp: record.at,
      txSequence: null,
      vetted: true,
      ledgerSeq: 0,
      pulseDigest: '',
      receptorVersion: '0.0.0',
      ruleVersion: '0.0.0',
      contextVersion: '0.0.0',
    );
    final receiptJson =
        LedgerEntry._receiptJson(receipt, 'fork:${record.forkId}');
    final chain = HashChain(record.genesisHash);
    final hash = chain.nextHash(
      prevHash: record.genesisHash,
      seq: 0,
      pulseDigest: '',
      receiptDigest: fingerprint(receiptJson),
      effectsDigest: fingerprint(const <Object?>[]),
      deltaDigest: fingerprint(const <Object?>[]),
      at: record.at,
    );
    return LedgerEntry(
      seq: 0,
      prevHash: record.genesisHash,
      hash: hash,
      pulseDigest: '',
      receipt: receipt,
      effects: const [],
      deltas: const [],
      at: record.at,
      receiptJson: receiptJson,
    );
  }

  /// A stable function marker for the synthetic fork entry. A
  /// top-level function tear-off has a deterministic `toString`, so the
  /// receipt digest is byte-stable across syntheses. Dart forbids
  /// implementing `Function`, so a tear-off is the only honest
  /// stand-in.
  static final Function _forkRecordMarker = _forkRecordMarkerFn;

  static Object? _forkRecordMarkerFn(Object? _) => null;
}

/// A `Cell` stand-in for the synthetic fork entry. Never used for
/// anything other than logging.
class _ForkCell extends CellBase {
  final ForkRecord record;
  _ForkCell(this.record) : super.fromNucleus(Nucleus.empty());
  @override
  String get id => 'fork:${record.forkId}';
}
