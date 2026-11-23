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

/// The read model of [wireReceiptJson]: what the remote side can know
/// without the live graph.
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
