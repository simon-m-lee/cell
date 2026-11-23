// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `ApplyOutcome` ⇄ wire JSON.
///
/// The wire form is the compact tagged union the plan specifies: one
/// `kind` discriminator, the result or reason, and the target's real
/// receipt JSON. Decoding never reconstructs a live [ApplyOutcome] — a
/// receipt embeds a live `Cell` and `Function`, which JSON cannot carry
/// — so the read side gets [WireOutcome], the honest JSON read model.
///
/// Encoding is **sanitising**: a result, reason, or argument that JSON
/// cannot encode is replaced with a labelled placeholder and flagged
/// (`resultOmitted`, `reasonOmitted`, `argumentsOmitted`), so a
/// successful apply can never produce a transport 500 after the state
/// already changed.
/// {@category Features}
library;

import 'dart:convert';

import 'package:cell/cell.dart';

import 'wire_receipt.dart';

/// The JSON read model of an [ApplyOutcome]: what the remote side can
/// know without the live graph.
final class WireOutcome {
  /// `accepted`, `rejected`, or `staged`.
  final String kind;

  /// The result payload of an accepted outcome, when JSON-serialisable.
  final Object? result;

  /// The rejection reason, when the outcome was rejected.
  final Object? reason;

  /// The receipt JSON (`wire_receipt.dart` shape).
  final Map<String, Object?> receipt;

  /// Whether [result] was replaced by a placeholder during encoding.
  final bool resultOmitted;

  /// Whether [reason] was replaced by a placeholder during encoding.
  final bool reasonOmitted;

  /// Whether a receipt argument was replaced by a placeholder.
  final bool argumentsOmitted;

  const WireOutcome({
    required this.kind,
    this.result,
    this.reason,
    required this.receipt,
    this.resultOmitted = false,
    this.reasonOmitted = false,
    this.argumentsOmitted = false,
  });

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (result != null) 'result': result,
        if (reason != null) 'reason': reason,
        'receipt': receipt,
        if (resultOmitted) 'resultOmitted': true,
        if (reasonOmitted) 'reasonOmitted': true,
        if (argumentsOmitted) 'argumentsOmitted': true,
      };

  factory WireOutcome.fromJson(Map<String, Object?> json) => WireOutcome(
        kind: json['kind'] as String,
        result: json['result'],
        reason: json['reason'],
        receipt: (json['receipt'] as Map).cast<String, Object?>(),
        resultOmitted: json['resultOmitted'] as bool? ?? false,
        reasonOmitted: json['reasonOmitted'] as bool? ?? false,
        argumentsOmitted: json['argumentsOmitted'] as bool? ?? false,
      );
}

/// Encodes a live [ApplyOutcome] to its wire JSON form, sanitising any
/// value JSON cannot encode (see [WireOutcome.resultOmitted]).
///
/// * [functionLabel] — the binding's wire-facing name, preferred over
///   parsing the live closure's `toString`.
/// * [requestNamed] — the original wire request's named arguments, so
///   receipt argument names come from the wire, not from VM-specific
///   `Symbol.toString()` output.
Map<String, Object?> wireOutcomeJson(
  ApplyOutcome<Object?> outcome, {
  String? functionLabel,
  Map<String, Object?>? requestNamed,
}) =>
    switch (outcome) {
      ApplyAccepted<Object?>(:final result, :final receipt) => _accepted(
          result,
          wireReceiptJson(receipt,
              functionLabel: functionLabel, requestNamed: requestNamed),
        ),
      ApplyRejected<Object?>(:final reason, :final receipt) => _rejected(
          reason,
          wireReceiptJson(receipt,
              functionLabel: functionLabel, requestNamed: requestNamed),
        ),
      ApplyStaged(:final receipt) => WireOutcome(
          kind: 'staged',
          receipt: wireReceiptJson(receipt,
              functionLabel: functionLabel, requestNamed: requestNamed),
        ).toJson(),
    };

Map<String, Object?> _accepted(Object? result, Map<String, Object?> receipt) {
  final omitted = <String>[];
  final safe = _sanitize(result, omitted, 'resultOmitted');
  final receiptOut = _sanitizeReceipt(receipt, omitted);
  return WireOutcome(
    kind: 'accepted',
    result: safe,
    receipt: receiptOut,
    resultOmitted: omitted.contains('resultOmitted'),
    argumentsOmitted: omitted.contains('argumentsOmitted'),
  ).toJson();
}

Map<String, Object?> _rejected(Object? reason, Map<String, Object?> receipt) {
  final omitted = <String>[];
  final safe = _sanitize(reason, omitted, 'reasonOmitted');
  final receiptOut = _sanitizeReceipt(receipt, omitted);
  return WireOutcome(
    kind: 'rejected',
    reason: safe,
    receipt: receiptOut,
    reasonOmitted: omitted.contains('reasonOmitted'),
    argumentsOmitted: omitted.contains('argumentsOmitted'),
  ).toJson();
}

Map<String, Object?> _sanitizeReceipt(
  Map<String, Object?> receipt,
  List<String> omitted,
) {
  final arguments = receipt['arguments'];
  if (arguments is! Map) return receipt;
  var changed = false;
  final safeArguments = <String, Object?>{};
  arguments.forEach((key, value) {
    if (value is List) {
      final list = <Object?>[];
      for (final item in value) {
        final before = item;
        final after = _sanitize(item, omitted, 'argumentsOmitted');
        list.add(after);
        if (!identical(before, after)) changed = true;
      }
      safeArguments[key] = list;
    } else if (value is Map) {
      final map = <String, Object?>{};
      value.forEach((k, v) {
        final before = v;
        final after = _sanitize(v, omitted, 'argumentsOmitted');
        map[k as String] = after;
        if (!identical(before, after)) changed = true;
      });
      safeArguments[key] = map;
    } else {
      safeArguments[key] = value;
    }
  });
  if (!changed) return receipt;
  return {...receipt, 'arguments': safeArguments};
}

Object? _sanitize(Object? value, List<String> omitted, String flag) {
  if (value == null) return null;
  try {
    jsonEncode(value);
    return value;
  } catch (_) {
    if (!omitted.contains(flag)) omitted.add(flag);
    return '<unencodable: ${value.runtimeType}>';
  }
}

/// Decodes the wire form into the [WireOutcome] read model.
WireOutcome wireOutcomeFromJson(Map<String, Object?> json) =>
    WireOutcome.fromJson(json);

/// The `kind` tag for [outcome]: `accepted`, `rejected`, or `staged`.
String wireOutcomeKind(ApplyOutcome<Object?> outcome) => switch (outcome) {
      ApplyAccepted() => 'accepted',
      ApplyRejected() => 'rejected',
      ApplyStaged() => 'staged',
    };
