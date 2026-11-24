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

/// The wire-safe JSON read model of a cell's application result.
///
/// In the framework's biological metaphor, [WireOutcome] is the **Skin Form**
/// of the **Forensic Receipt**. While the internal framework uses
/// `ApplyOutcome` to handle live objects and functions, this class represents
/// the sanitized version that is safe to transmit across the **Skin Membrane**.
///
/// ### When to use
/// - **Remote Inspection**: Use this on the client side (AI agent, web app)
///   to verify the result of a **Command Journey**.
/// - **Serialization Boundary**: The primary structure used when converting
///   a **Somatic State Transition** result into a JSON payload.
///
/// ### How it works
/// 1. **Sanitization**: During encoding, the system checks if the result or
///    reason can be encoded as JSON.
/// 2. **Omission Guard**: If a value is not serializable, it is replaced with
///    a placeholder to prevent a transport failure (a "Forensic Hole"), and
///    the corresponding `omitted` flag is set to `true`.
/// 3. **Forensic Integrity**: The [receipt] field carries the technical
///    metadata (sequence, timestamp) required to anchor the result in the
///    **Forensic Ledger**.
///
/// ### Non‑obvious behavior
/// - **Read-Only**: This is a "honest" JSON model. It does not attempt to
///   reconstruct live Dart functions or cell references, as those cannot
///   physically survive the trip across the wire.
/// - **Authoritative Outcome**: The [kind] property acts as the **Signal Tag**,
///   telling the receiver if the transition was `accepted`, `rejected`
///   (by an **Integrity Gate**), or `staged`.
///
/// ### See also
/// - [ApplyOutcome]: The live, internal version of this result.
/// - [WireReceipt]: The detailed forensic metadata attached to this outcome.
/// - [wireOutcomeJson]: The utility that performs the sanitization and encoding.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is the result of your tool call.
/// **Live signature:** `final class WireOutcome { final String kind; final Object? result; final Object? reason; final Map<String, Object?> receipt; const WireOutcome({required String kind, Object? result, Object? reason, required Map<String, Object?> receipt}); factory WireOutcome.fromJson(Map<String, Object?> json); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Integrity:** Check `resultOmitted` or `reasonOmitted` if a value looks
/// like a placeholder string.
/// **Validation:** If `kind` is `rejected`, the transition did not occur in
/// the **Forensic Ledger**.
final class WireOutcome {

  /// The specific status of the transition.
  ///
  /// In the biological metaphor, this is the **Signal Tag**. It will be
  /// `accepted`, `rejected`, or `staged`.
  final String kind;

  /// The resulting value produced by the cell.
  ///
  /// This represents the new **Phenotype** snapshot. If this field is
  /// a string like `<unencodable: ...>`, check [resultOmitted].
  final Object? result;

  /// The explanation for why a transition was denied.
  ///
  /// This is the **Rejection Evidence** provided by an **Integrity Gate**
  /// when the `kind` is `rejected`.
  final Object? reason;

  /// The technical metadata for the transition.
  ///
  /// This is the **Forensic Evidence** (see `wire_receipt.dart`) that anchors
  /// this specific outcome to a point in the system's history.
  final Map<String, Object?> receipt;

  /// Whether the result was too complex for JSON and was replaced by a placeholder.
  ///
  /// A `true` value indicates a **Forensic Omission** occurred to preserve
  /// transport stability.
  final bool resultOmitted;

  /// Whether the rejection reason was replaced by a placeholder during encoding.
  final bool reasonOmitted;

  /// Whether one or more arguments in the receipt were replaced by placeholders.
  final bool argumentsOmitted;

  /// Creates a new [WireOutcome] envelope.
  const WireOutcome({
    required this.kind,
    this.result,
    this.reason,
    required this.receipt,
    this.resultOmitted = false,
    this.reasonOmitted = false,
    this.argumentsOmitted = false,
  });

  /// Converts the outcome into its **Skin Form** for transport.
  Map<String, Object?> toJson() => {
    'kind': kind,
    if (result != null) 'result': result,
    if (reason != null) 'reason': reason,
    'receipt': receipt,
    if (resultOmitted) 'resultOmitted': true,
    if (reasonOmitted) 'reasonOmitted': true,
    if (argumentsOmitted) 'argumentsOmitted': true,
  };

  /// Decodes the **Skin Form** back into a [WireOutcome] model.
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
  // A state binding returns the next value as a `Pulse`; the wire result
  // is the pulse's payload, never the pulse itself (a `Pulse` is not a
  // JSON value and would be flagged `resultOmitted`).
  final value = result is Pulse ? result.payload : result;
  final omitted = <String>[];
  final safe = _sanitize(value, omitted, 'resultOmitted');
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
