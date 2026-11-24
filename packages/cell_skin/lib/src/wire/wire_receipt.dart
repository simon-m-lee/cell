// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `ApplyReceipt` ⇄ wire JSON.
///
/// The receipt is the framework's own record; the wire form replaces
/// the live `cell` with its registered `Cell.id` and the live `function`
/// with a label. When the caller supplies the binding's wire-facing
/// [functionLabel] it wins — a Dart `Function` cannot serialise and its
/// `toString` discloses closure internals, so the binding name is the
/// honest label. Argument names come from the original wire request
/// when available; `Symbol.toString()` parsing is only a fallback.
/// {@category Features}
library;

import 'dart:convert';

import 'package:cell/cell.dart';

/// Encodes an [ApplyReceipt] to its wire JSON form.
///
/// * [functionLabel] — the binding's wire-facing name (recommended).
/// * [requestNamed] — the original wire request's named arguments, in
///   wire order; argument names are taken from here instead of parsing
///   VM-specific `Symbol.toString()` output.
Map<String, Object?> wireReceiptJson(
  ApplyReceipt receipt, {
  String? functionLabel,
  Map<String, Object?>? requestNamed,
}) {
  final positional = _sanitizeList(receipt.arguments.positionalArguments);
  final named = _namedToJson(receipt.arguments.namedArguments, requestNamed);
  return {
    'id': receipt.id,
    'cell': receipt.cell.id,
    'function': functionLabel ?? _functionLabel(receipt.function),
    'arguments': {
      'positional': positional,
      'named': named,
    },
    'timestamp': receipt.timestamp.toUtc().toIso8601String(),
    if (receipt.txSequence != null) 'txSequence': receipt.txSequence,
    'vetted': receipt.vetted,
    if (receipt.ledgerSeq != null) 'ledgerSeq': receipt.ledgerSeq,
    if (receipt.pulseDigest != null) 'pulseDigest': receipt.pulseDigest,
    if (receipt.receptorVersion != null)
      'receptorVersion': receipt.receptorVersion,
    if (receipt.ruleVersion != null) 'ruleVersion': receipt.ruleVersion,
    if (receipt.contextVersion != null)
      'contextVersion': receipt.contextVersion,
  };
}

/// The read model of a cell's physical state transition, stripped of live
/// references for transport.
///
/// In the framework's biological metaphor, [WireReceipt] is the **Skin Form**
/// of the **Forensic Receipt**. While the internal `ApplyReceipt` carries live
/// cell objects and Dart functions, this class represents the sanitized,
/// JSON-safe proof that a **Somatic State Transition** has been recorded.
///
/// ### When to use
/// - **Audit Inspection**: Use this on the client side to verify the exact
///   sequence, timing, and authority of a past change.
/// - **State Reconstruction**: Essential for "Time Travel" or replaying
///   the **Forensic Ledger** in a remote environment.
///
/// ### How it works
/// 1. **Signal Sanitization**: During encoding, live `Function` objects are
///    replaced with [functionLabel] to prevent closure internal leakage.
/// 2. **Integrity Guarding**: Arguments are checked for JSON safety. If an
///    argument cannot be encoded, it is replaced with a `<unencodable: type>`
///    marker to prevent a "Forensic Hole" (a transport failure).
/// 3. **Causal Mapping**: It bundles the [pulseDigest] and [ledgerSeq] to
///    provide a verifiable link back to the **Command Journey**.
///
/// ### Non‑obvious behavior
/// - **Honest Labeling**: The [functionLabel] prefers the name provided by the
///   wire binding. If missing, it falls back to a string representation of
///   the closure, which is useful for debugging but not for execution.
/// - **Historical Snapshot**: This receipt is a static record. It does not
///   change if the cell's "DNA" (receptor or rule version) is updated later.
///
/// ### See also
/// - [ApplyReceipt]: The live, internal record being modeled here.
/// - [WireOutcome]: The structure that carries this receipt as proof of result.
/// - [wireReceiptJson]: The encoder that produces this structure.
///
/// ### AI Agent Guide
/// **Layer:** Skin — the framework receipt in wire form.
/// **When to use:** decoding the receipt inside a [WireOutcome]; the
/// encoder is [wireReceiptJson], never a hand-built map.
/// **When NOT to use:** inventing receipts the graph never produced.
/// **Live signature:** `const WireReceipt({required String id, required String cellId, required String functionLabel, List<Object?>? positional, Map<String, Object?>? named, required DateTime timestamp, int? txSequence, required bool vetted, int? ledgerSeq, String? pulseDigest, String? receptorVersion, String? ruleVersion, String? contextVersion})` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
final class WireReceipt {
  final String id;
  final String cellId;
  final String functionLabel;
  final List<Object?>? positional;
  final Map<String, Object?>? named;
  final DateTime timestamp;
  final int? txSequence;
  final bool vetted;
  final int? ledgerSeq;
  final String? pulseDigest;
  final String? receptorVersion;
  final String? ruleVersion;
  final String? contextVersion;

  const WireReceipt({
    required this.id,
    required this.cellId,
    required this.functionLabel,
    this.positional,
    this.named,
    required this.timestamp,
    this.txSequence,
    required this.vetted,
    this.ledgerSeq,
    this.pulseDigest,
    this.receptorVersion,
    this.ruleVersion,
    this.contextVersion,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'cell': cellId,
        'function': functionLabel,
        'arguments': {'positional': positional, 'named': named},
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (txSequence != null) 'txSequence': txSequence,
        'vetted': vetted,
        if (ledgerSeq != null) 'ledgerSeq': ledgerSeq,
        if (pulseDigest != null) 'pulseDigest': pulseDigest,
        if (receptorVersion != null) 'receptorVersion': receptorVersion,
        if (ruleVersion != null) 'ruleVersion': ruleVersion,
        if (contextVersion != null) 'contextVersion': contextVersion,
      };

  /// Decodes a [WireReceipt] encoded by [wireReceiptJson] or [toJson].
  factory WireReceipt.fromJson(Map<String, Object?> json) {
    final arguments = (json['arguments'] as Map?)?.cast<String, Object?>();
    return WireReceipt(
      id: json['id'] as String,
      cellId: json['cell'] as String,
      functionLabel: json['function'] as String? ?? '',
      positional: (arguments?['positional'] as List?)?.cast<Object?>(),
      named: (arguments?['named'] as Map?)?.cast<String, Object?>(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      txSequence: json['txSequence'] as int?,
      vetted: json['vetted'] as bool? ?? false,
      ledgerSeq: json['ledgerSeq'] as int?,
      pulseDigest: json['pulseDigest'] as String?,
      receptorVersion: json['receptorVersion'] as String?,
      ruleVersion: json['ruleVersion'] as String?,
      contextVersion: json['contextVersion'] as String?,
    );
  }
}

String _functionLabel(Function function) {
  final text = function.toString();
  // "Closure: (int) => void from Function 'set': static." → keep it short
  // but informative; it is a log label, never an execution handle.
  if (text.length > 160) return '${text.substring(0, 157)}…';
  return text;
}

Map<String, Object?>? _namedToJson(
  Map<Symbol, Object?>? named,
  Map<String, Object?>? requestNamed,
) {
  if (named == null) return null;
  final out = <String, Object?>{};
  // Preferred: the original wire names, in wire order.
  if (requestNamed != null) {
    for (final entry in requestNamed.entries) {
      final symbol = Symbol(entry.key);
      if (named.containsKey(symbol)) out[entry.key] = named[symbol];
    }
  }
  // Fallback for any symbol the request did not carry (VM-specific
  // parsing; only reached when no wire names were supplied).
  named.forEach((symbol, value) {
    final name = _symbolName(symbol);
    if (!out.containsKey(name)) out[name] = _sanitize(value);
  });
  if (requestNamed != null) {
    for (final entry in out.entries.toList()) {
      out[entry.key] = _sanitize(entry.value);
    }
  }
  return out;
}

List<Object?>? _sanitizeList(List<Object?>? values) =>
    values == null ? null : [for (final v in values) _sanitize(v)];

Object? _sanitize(Object? value) {
  if (value == null) return null;
  try {
    jsonEncode(value);
    return value;
  } catch (_) {
    // A receipt argument must never break the wire's JSON encoding.
    return '<unencodable: ${value.runtimeType}>';
  }
}

String _symbolName(Symbol symbol) {
  // Symbol('<name>') → '<name>'; a multi-part symbol carries both names.
  final text = symbol.toString();
  if (text.startsWith('Symbol("') && text.endsWith('")')) {
    return text.substring(8, text.length - 2);
  }
  return text;
}
