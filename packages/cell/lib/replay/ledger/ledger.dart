// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// The durable, hash-chained record of every state transition.
///
/// A `Ledger` is bound to a [CellGraph] and a [LedgerStore]. It is the
/// authoritative history of the graph; the graph's current state is a
/// *derived* value that can be reconstructed by replaying the ledger
/// from a snapshot.
///
/// ### Non-obvious: `Ledger.appendInternal` is not called by users
///
/// The design says "append from inside a receptor is rejected". The
/// enforcement is: `appendInternal` is `@internal` and only invoked from
/// `_LedgerScopeImpl.recordAndAppend`, which is pushed by `Cell.apply`
/// and the `ValueCell` emit path (with the delta captured by
/// `postProcessRule`). A user who calls `appendInternal` directly will
/// hit the `@internal` warning in a strict analyzer config; more
/// importantly, they will not have the delta and will produce an entry
/// whose `deltaDigest` is `fingerprint([])`, which the engine's
/// `ReplayEngine` rejects as a divergence at replay time. That is the
/// correct outcome: the ledger is not a general-purpose journal, it is a
/// *coordinated* record, and the coordination lives in `LedgerScope`.
class Ledger {
  final CellGraph graph;
  final LedgerStore store;
  final HashChain _chain;
  final StreamController<LedgerEntry> _tail =
      StreamController<LedgerEntry>.broadcast();
  bool _closed = false;

  Ledger._(this.graph, this.store, this._chain);

  /// The chain genesis for a graph id. Stores must be constructed with
  /// this value so [open] can assert the binding is coherent.
  static String genesisHashOf(String graphId) =>
      fingerprint({'graphId': graphId});

  /// Creates a ledger bound to [graph] and backed by [store]. The
  /// genesis hash is `fingerprint({'graphId': graph.id})`; the store's
  /// own `genesisHash` must match, or this throws — a store created for
  /// graph `G` can never silently serve graph `H`.
  ///
  /// [genesisHash] overrides the chain genesis — fork ledgers
  /// chain from their `ForkRecord.genesisHash`, not from the graph id.
  static Future<Ledger> open({
    required CellGraph graph,
    required LedgerStore store,
    String? genesisHash,
  }) async {
    final chain = HashChain(genesisHash ?? genesisHashOf(graph.id));
    if (store.genesisHash != chain.genesisHash) {
      throw StateError(
        'Ledger.open: store genesis hash "${store.genesisHash}" does not '
        'match graph "${graph.id}" (expected "${chain.genesisHash}"). '
        'Construct the store with Ledger.genesisHashOf(graph.id), or '
        'with the explicit genesis hash this ledger is chained from.',
      );
    }
    return Ledger._(graph, store, chain);
  }

  /// Same as [open], but runs [verify] before returning. A corrupt
  /// store fails at open time, not at first append.
  static Future<Ledger> openVerified({
    required CellGraph graph,
    required LedgerStore store,
    String? genesisHash,
  }) async {
    final ledger =
        await open(graph: graph, store: store, genesisHash: genesisHash);
    await ledger.verify();
    return ledger;
  }

  /// The current head sequence number. `-1` if the ledger is empty.
  Future<int> get lastSeq => store.lastSeq;

  /// The current head hash. `null` if the ledger is empty.
  Future<String?> get lastHash => store.lastHash;

  /// A stream of entries as they are appended. Broadcast; new
  /// subscribers receive only *future* entries.
  Stream<LedgerEntry> get tail => _tail.stream;

  /// Iterate entries from [fromSeq] (inclusive).
  Stream<LedgerEntry> entriesSince(int fromSeq) => store.entriesSince(fromSeq);

  /// Verify the entire ledger: every entry's hash matches its
  /// predecessor's hash chain and its own recomputed hash.
  ///
  /// Returns normally on success; throws [LedgerIntegrityException] with
  /// the offending `seq` and the reason on failure.
  Future<void> verify() async {
    var expectedPrev = _chain.genesisHash;
    var expectedSeq = 0;
    await for (final entry in store.entriesSince(0)) {
      if (entry.seq != expectedSeq) {
        throw LedgerIntegrityException(
          seq: entry.seq,
          reason: 'sequence gap: expected $expectedSeq, got ${entry.seq}',
        );
      }
      if (entry.prevHash != expectedPrev) {
        throw LedgerIntegrityException(
          seq: entry.seq,
          reason: 'prevHash mismatch: expected $expectedPrev, '
              'got ${entry.prevHash}',
        );
      }
      final recomputed = _chain.nextHash(
        prevHash: entry.prevHash,
        seq: entry.seq,
        pulseDigest: entry.pulseDigest,
        receiptDigest: entry.receiptDigest,
        effectsDigest: entry.effectsDigest,
        deltaDigest: entry.deltaDigest,
        at: entry.at,
      );
      if (recomputed != entry.hash) {
        throw LedgerIntegrityException(
          seq: entry.seq,
          reason: 'hash mismatch: expected $recomputed, '
              'got ${entry.hash}',
        );
      }
      // (review): when the pulse body is stored, its digest
      // must match pulseDigest — a tampered pulse body fails here.
      if (entry.pulseJson != null &&
          fingerprint(entry.pulseJson!) != entry.pulseDigest) {
        throw LedgerIntegrityException(
          seq: entry.seq,
          reason: 'pulse body digest mismatch: the stored pulseJson does '
              'not hash to pulseDigest ${entry.pulseDigest}',
        );
      }
      expectedPrev = entry.hash;
      expectedSeq++;
    }
  }

  /// The internal append used by `LedgerScope`. External callers should
  /// not use this — entries must carry the deltas that only
  /// `postProcessRule` captures.
  ///
  /// ### Non-obvious: no internal serialisation
  ///
  /// `seq` is assigned from `lastSeq + 1` without a lock. `LedgerScope`
  /// serialises appends on its own `_tail` chain, so scoped recording is
  /// safe; a direct caller mixing `appendInternal` with concurrent
  /// appends (including `ReplayEngineFork` appends racing another
  /// writer on the same ledger) must serialise itself.
  Future<void> appendInternal({
    required Pulse pulse,
    required ApplyReceipt receipt,
    required String cellId,
    required List<EffectRecord> effects,
    required List<StateDelta> deltas,
  }) async {
    if (_closed) {
      throw StateError('Ledger is closed');
    }
    final prevHash = (await store.lastHash) ?? _chain.genesisHash;
    final seq = (await store.lastSeq) + 1;
    final at = DateTime.now();
    // The pulse flowing through apply/emit is often a _FastPulse or has
    // _StepPulse ancestors; the digest is over the canonical materialised
    // form. (review): the materialised JSON is now STORED as
    // the entry's pulse body, so replay can reconstruct the exact pulse
    // and verify() can check the body against the digest. Both the body
    // and the digest come from this ONE materialisation — re-materialising
    // to "double check" would not be stable (timestamps regenerate).
    final pulseJson = PulseCodec.toJson(PulseCodec.materialise(pulse));
    final pulseDigest = fingerprint(pulseJson);
    final effectsDigest = fingerprint(
      effects.map((e) => e.toJson()).toList(growable: false),
    );
    final deltaDigest = fingerprint(
      deltas.map((d) => d.toJson()).toList(growable: false),
    );

    final filledReceipt = (
      id: receipt.id,
      cell: receipt.cell,
      function: receipt.function,
      arguments: receipt.arguments,
      timestamp: receipt.timestamp,
      txSequence: receipt.txSequence,
      vetted: receipt.vetted,
      ledgerSeq: seq,
      pulseDigest: pulseDigest,
      // Capture the governance versions that produced the
      // entry. Unversioned components report '0.0.0'.
      receptorVersion: receipt.cell._nucleus.receptor.version,
      ruleVersion: receipt.cell._nucleus.testRule.version,
      contextVersion: receipt.cell.context is DeputyContext
          ? (receipt.cell.context as DeputyContext).version
          : '0.0.0',
    );

    final receiptJson = LedgerEntry._receiptJson(filledReceipt, cellId);
    final receiptDigest = fingerprint(receiptJson);
    final hash = _chain.nextHash(
      prevHash: prevHash,
      seq: seq,
      pulseDigest: pulseDigest,
      receiptDigest: receiptDigest,
      effectsDigest: effectsDigest,
      deltaDigest: deltaDigest,
      at: at,
    );

    final entry = LedgerEntry(
      seq: seq,
      prevHash: prevHash,
      hash: hash,
      pulseDigest: pulseDigest,
      pulseJson: pulseJson,
      receipt: filledReceipt,
      effects: List.unmodifiable(effects),
      deltas: List.unmodifiable(deltas),
      at: at,
      receiptJson: receiptJson,
    );
    await store.append(entry);
    if (!_tail.isClosed) _tail.add(entry);
  }

  /// Close the ledger. The store is closed; subsequent operations fail.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _tail.close();
    await store.close();
  }
}

/// Thrown by [Ledger.verify] when an entry's hash, sequence, or
/// predecessor chain does not match.
class LedgerIntegrityException implements Exception {
  final int seq;
  final String reason;

  LedgerIntegrityException({required this.seq, required this.reason});

  @override
  String toString() => 'LedgerIntegrityException(seq $seq): $reason';
}
