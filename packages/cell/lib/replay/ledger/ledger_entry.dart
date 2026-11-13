// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A single, immutable row in the ledger.
///
/// The row is the atomic unit of persistence: `append` writes it
/// atomically, `verify` checks its hash against the previous row, and
/// `entriesSince` reads them sequentially. Its `toJson` form is what
/// `FileLedgerStore` writes (one JSON object per line) and what a future
/// network store would transmit.
///
/// ### Non-obvious: `pulseDigest` is a digest of the *whole* pulse chain
///
/// Not just the pulse's payload. Two pulses that share a payload but
/// differ in parent, trace, or context are different causal entities; the
/// ledger records both, distinguished by their digests. This is what
/// lets the replay engine reconstruct the pulse without re-storing the
/// chain, and it is why `PulseCodec.toJson` captures the parent's digest
/// rather than the parent itself.
class LedgerEntry {
  /// Monotonic sequence number. Genesis is 0.
  final int seq;

  /// The hash of the previous entry. For `seq == 0`, this is the graph's
  /// genesis hash (`HashChain.genesisHash`).
  final String prevHash;

  /// This entry's hash. Must satisfy `HashChain.nextHash(prevHash, ...)`
  /// for the entry's other fields.
  final String hash;

  /// SHA-256 of the pulse that produced this entry, computed by
  /// `PulseCodec` (materialising the pulse first) and stored in the
  /// receipt.
  final String pulseDigest;

  /// The `ApplyReceipt` for the mutation that produced this entry. Its
  /// `ledgerSeq` and `pulseDigest` fields are populated by the ledger
  /// before the entry is created; callers see the same receipt they
  /// received from `apply`, plus the two back-filled fields.
  final ApplyReceipt receipt;

  /// The effects recorded during this pulse's processing (Phase 3's
  /// `EffectRecord`s), in ordinal order.
  final List<EffectRecord> effects;

  /// The state deltas produced by this pulse. A single pulse can write
  /// multiple cells (e.g., a `synthesis` cell writing several
  /// downstreams); the delta list preserves order.
  final List<StateDelta> deltas;

  /// Wall-clock time the entry was committed to the ledger.
  final DateTime at;

  /// The original receipt JSON, carried by reloaded entries so that
  /// `receiptDigest` and `toJson` stay byte-identical to the stored
  /// form (a live `Function` cannot be serialised). Append-created
  /// entries carry it too, so the recorded cell id never depends on the
  /// live registry's state.
  final Map<String, Object?>? _storedReceiptJson;

  const LedgerEntry({
    required this.seq,
    required this.prevHash,
    required this.hash,
    required this.pulseDigest,
    required this.receipt,
    required this.effects,
    required this.deltas,
    required this.at,
    Map<String, Object?>? receiptJson,
  }) : _storedReceiptJson = receiptJson;

  LedgerEntry._restored({
    required this.seq,
    required this.prevHash,
    required this.hash,
    required this.pulseDigest,
    required this.receipt,
    required this.effects,
    required this.deltas,
    required this.at,
    required Map<String, Object?> storedReceiptJson,
  }) : _storedReceiptJson = storedReceiptJson;

  /// The cell id recorded in the receipt — the value captured when the
  /// entry was appended. `receipt.cell.id` re-resolves through the live
  /// registry and can change after `CellGraphRegistry.forceReset`;
  /// the recorded id cannot.
  String get receiptCellId =>
      (_storedReceiptJson?['cell'] ?? receipt.cell.id) as String;

  /// SHA-256 of the effects list. Used by `HashChain.nextHash`.
  String get effectsDigest => fingerprint(
        effects.map((e) => e.toJson()).toList(growable: false),
      );

  /// SHA-256 of the deltas list.
  String get deltaDigest => fingerprint(
        deltas.map((d) => d.toJson()).toList(growable: false),
      );

  /// SHA-256 of the receipt. The `ledgerSeq` and `pulseDigest` fields are
  /// excluded so a receipt's digest is stable across the back-fill that
  /// happens between `apply` and `append`.
  ///
  /// Reloaded entries carry their original stored receipt JSON (a live
  /// `Function` cannot be serialised), so the digest is computed over
  /// that exact form — byte-identical to the append-time digest.
  String get receiptDigest =>
      fingerprint(_storedReceiptJson ?? _receiptJson(receipt));

  /// The canonical JSON form of the receipt, used both on the wire and
  /// for [receiptDigest]. Named arguments are stored by *symbol name*
  /// (not `Symbol("x")`), so the form is identical whether it is
  /// produced from a live receipt or from a reloaded one.
  ///
  /// [cellId] is the pre-resolved cell id. `Cell.id` walks the nucleus
  /// principal chain through a dynamic record access that is expensive
  /// inside future callbacks (where the append runs); the coordinated
  /// append path resolves it once in the caller's direct context and
  /// passes it down.
  static Map<String, Object?> _receiptJson(ApplyReceipt receipt,
          [String? cellId]) =>
      {
        'id': receipt.id,
        'cell': cellId ?? receipt.cell.id,
        'function': receipt.function.toString(),
        'arguments': _encodeArgs(receipt.arguments),
        'timestamp': receipt.timestamp.toUtc().toIso8601String(),
        'txSequence': receipt.txSequence,
        'vetted': receipt.vetted,
        // The back-filled fields; present because `append` populated
        // them on the *store's* copy of the receipt, not the caller's.
        'ledgerSeq': receipt.ledgerSeq,
        'pulseDigest': receipt.pulseDigest,
        // Phase 7 — governance versions (defaulted for old ledgers).
        'receptorVersion': receipt.receptorVersion,
        'ruleVersion': receipt.ruleVersion,
        'contextVersion': receipt.contextVersion,
      };

  /// The canonical JSON form of an [ApplyArguments] record. Named
  /// arguments are stored by *symbol name* (not `Symbol("x")`), so the
  /// form is identical whether it is produced from a live receipt or
  /// from a reloaded one.
  static Map<String, Object?> _encodeArgs(ApplyArguments args) {
    return {
      if (args.positionalArguments != null)
        'positional': args.positionalArguments!.map(_encodeValue).toList(),
      if (args.namedArguments != null)
        'named': {
          for (final e in args.namedArguments!.entries)
            _symbolName(e.key): _encodeValue(e.value),
        },
    };
  }

  static Object? _encodeValue(Object? v) {
    if (v == null || v is num || v is bool || v is String) return v;
    if (v is List) return v.map(_encodeValue).toList();
    if (v is Map) {
      return v.map((k, value) => MapEntry('$k', _encodeValue(value)));
    }
    if (v is Cell) return {'__cell__': v.id};
    return v.toString();
  }

  /// Extracts the name of a [Symbol] without dart:mirrors:
  /// `Symbol("foo").toString()` is `Symbol("foo")`, whose inner part is a
  /// JSON-quoted string.
  static String _symbolName(Symbol symbol) {
    final text = symbol.toString();
    if (!text.startsWith('Symbol("') || !text.endsWith('")')) {
      return text;
    }
    final inner = text.substring(7, text.length - 2);
    try {
      final decoded = jsonDecode(inner);
      if (decoded is String) return decoded;
    } catch (_) {}
    return inner;
  }

  Map<String, Object?> toJson() => {
        'seq': seq,
        'prevHash': prevHash,
        'hash': hash,
        'pulseDigest': pulseDigest,
        'receipt': _storedReceiptJson ?? _receiptJson(receipt),
        'effects': effects.map((e) => e.toJson()).toList(growable: false),
        'deltas': deltas.map((d) => d.toJson()).toList(growable: false),
        'at': at.toUtc().toIso8601String(),
      };

  /// Reconstructs an entry from [toJson].
  ///
  /// `receipt.cell` is resolved from the cell id via
  /// `_ReplayCellRegistry`. If the cell is not registered (e.g. the
  /// ledger is being opened before the graph was rebuilt), the receipt
  /// is reconstructed with a **placeholder** cell whose `id` matches the
  /// recorded one but whose nucleus is an empty stub. Phase 5's
  /// `ReplayEngine` refuses to process an entry whose receipt points at
  /// a placeholder, which is the correct behaviour: replaying into a
  /// graph that does not contain the cell is a divergence.
  factory LedgerEntry.fromJson(Map<String, Object?> json) {
    final rawReceipt = json['receipt'] as Map?;
    if (rawReceipt == null) {
      throw const FormatException('LedgerEntry: missing receipt');
    }
    final cellId = rawReceipt['cell'] as String?;
    if (cellId == null) {
      throw const FormatException('LedgerEntry: missing receipt.cell');
    }
    final cell = _ReplayCellRegistry.lookup(cellId) ?? _PlaceholderCell(cellId);

    final rawArgs = rawReceipt['arguments'];
    final arguments = _decodeArgs(rawArgs);
    final storedReceiptJson = Map<String, Object?>.from(rawReceipt);

    final receipt = (
      id: rawReceipt['id'] as String,
      cell: cell,
      function: (Object? _) => null,
      arguments: arguments,
      timestamp: DateTime.parse(rawReceipt['timestamp'] as String),
      txSequence: rawReceipt['txSequence'] as int?,
      vetted: (rawReceipt['vetted'] as bool?) ?? true,
      ledgerSeq: rawReceipt['ledgerSeq'] as int?,
      pulseDigest: rawReceipt['pulseDigest'] as String?,
      // Phase 7 — governance versions; '0.0.0' for pre-Phase-7 ledgers.
      receptorVersion: rawReceipt['receptorVersion'] as String? ?? '0.0.0',
      ruleVersion: rawReceipt['ruleVersion'] as String? ?? '0.0.0',
      contextVersion: rawReceipt['contextVersion'] as String? ?? '0.0.0',
    );

    final rawEffects = json['effects'];
    final effects = rawEffects is List
        ? rawEffects
            .whereType<Map>()
            .map((m) => EffectRecord.fromJson(m.cast<String, Object?>()))
            .toList(growable: false)
        : const <EffectRecord>[];

    final rawDeltas = json['deltas'];
    final deltas = rawDeltas is List
        ? rawDeltas
            .whereType<Map>()
            .map((m) => StateDelta.fromJson(m.cast<String, Object?>()))
            .toList(growable: false)
        : const <StateDelta>[];

    return LedgerEntry._restored(
      seq: json['seq'] as int,
      prevHash: json['prevHash'] as String,
      hash: json['hash'] as String,
      pulseDigest: json['pulseDigest'] as String,
      receipt: receipt,
      effects: effects,
      deltas: deltas,
      at: DateTime.parse(json['at'] as String),
      storedReceiptJson: storedReceiptJson,
    );
  }

  static ApplyArguments _decodeArgs(Object? raw) {
    if (raw is! Map) {
      return (positionalArguments: null, namedArguments: null);
    }
    final rawPositional = raw['positional'];
    final rawNamed = raw['named'];
    return (
      positionalArguments: rawPositional is List
          ? rawPositional.map(_decodeValue).toList(growable: false)
          : null,
      namedArguments: rawNamed is Map
          ? {
              for (final e in rawNamed.entries)
                Symbol(e.key as String): _decodeValue(e.value),
            }
          : null,
    );
  }

  static Object? _decodeValue(Object? v) {
    if (v is List) return v.map(_decodeValue).toList(growable: false);
    if (v is Map) {
      return {
        for (final e in v.entries) '${e.key}': _decodeValue(e.value),
      };
    }
    return v;
  }
}

/// A `Cell` stand-in used when a ledger entry is reconstructed before
/// its cell is registered. Never used for anything other than logging;
/// Phase 5's `ReplayEngine` rejects any entry whose receipt points at
/// one of these.
class _PlaceholderCell extends CellBase {
  final String _id;

  _PlaceholderCell(this._id) : super.fromNucleus(Nucleus.empty());

  @override
  String get id => _id;

  @override
  String toString() => 'PlaceholderCell($_id)';
}
