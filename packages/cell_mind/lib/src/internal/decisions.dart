// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// A first-class record of a decision made by a [CognitiveHandle].
///
/// ### When to use
/// Read from [CognitiveHandle.decisions]. Every accept and reject is
/// logged with the context version active at decision time.
///
/// ### Non-obvious
/// - **`contextVersion` is load-bearing.** Replay of a decision uses the
///   context version active at decision time, not the current one.
///   Editing constraints without bumping `context.version` breaks
///   replay determinism.
/// - **Serialization is lossy in 0.2.0.** `toMap` preserves the audit
///   shape; `fromMap` cannot rebuild the live [Context] / [Pulse] /
///   [ApplyCommand] objects (substrate values are not round-trippable),
///   so it restores the record shell with those fields nulled. Phase 3
///   adds a codec where training requires it.
///
/// {@category Organ}
/// {@category Runtime}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
final class Decision {
  /// The decision id — generated via [Identity.next].
  final String id;

  /// The moment the decision was made.
  final DateTime at;

  /// The active context at decision time.
  final Context context;

  /// The context's version stamp at decision time (`Context.version`).
  final String contextVersion;

  /// The pulse that triggered this decision, if it was a pulse decision.
  final Pulse? pulse;

  /// The command that triggered this decision, if it was an action.
  ///
  /// Reconstructed from the `TestCell` dispatch: `function` and
  /// `arguments` are the live values; `compensation` is always `null`
  /// because the substrate does not forward the full command to generic
  /// rules.
  final ApplyCommand? command;

  /// The verdict — accept or reject (defer arrives in Phase 4).
  final Verdict verdict;

  /// The policy's implementation version, if the policy provided one.
  final String? policyVersion;

  /// How long the composite evaluation took.
  final Duration? evaluationTime;

  const Decision({
    required this.id,
    required this.at,
    required this.context,
    required this.contextVersion,
    required this.verdict,
    this.pulse,
    this.command,
    this.policyVersion,
    this.evaluationTime,
  });

  /// Serializes this decision for the audit trail.
  ///
  /// The map is JSON-encodable as long as the verdict annotations are;
  /// pulse payloads and command arguments are reduced via `toString()`.
  Map<String, dynamic> toMap() => {
        'id': id,
        'at': at.toUtc().toIso8601String(),
        'context': _contextToMap(context),
        'contextVersion': contextVersion,
        'pulse': pulse == null ? null : _pulseToMap(pulse!),
        'command': command == null ? null : _commandToMap(command!),
        'verdict': verdict.toMap(),
        'policyVersion': policyVersion,
        'evaluationTime': evaluationTime?.inMicroseconds,
      };

  /// Reconstructs the decision-record shell from [Decision.toMap] output.
  ///
  /// The live [context], [pulse], and [command] objects are not
  /// reconstructible (documented lossy serialization); they are restored
  /// as [Context.system] and `null` respectively. The verdict, versions,
  /// timestamps, and ids round-trip exactly.
  static Decision fromMap(Map<String, dynamic> map) => Decision(
        id: map['id'] as String,
        at: DateTime.parse(map['at'] as String),
        context: Context.system,
        contextVersion: map['contextVersion'] as String,
        verdict: verdictFromMap(map['verdict'] as Map<String, dynamic>),
        policyVersion: map['policyVersion'] as String?,
        evaluationTime: map['evaluationTime'] == null
            ? null
            : Duration(microseconds: map['evaluationTime'] as int),
      );

  @override
  String toString() => 'Decision($id, ${verdict.runtimeType}, $contextVersion)';
}

Map<String, dynamic> _contextToMap(Context context) => {
      'type': context.type,
      'identity': context.identity,
      'domains': context.domains,
      'compliance': context.compliance,
      'version': context.version,
    };

Map<String, dynamic> _pulseToMap(Pulse pulse) => {
      'type': pulse.type?.toString(),
      'payload': pulse.payload?.toString(),
      'priority': pulse.priority,
      'traceId': pulse.context.traceId,
      'actor': pulse.context.actor,
      'reason': pulse.context.reason,
      'confidence': pulse.context.confidence,
      'domains': pulse.context.domains,
      'compliance': pulse.context.compliance,
    };

Map<String, dynamic> _commandToMap(ApplyCommand command) => {
      'function': command.function.toString(),
      'positional': command.arguments.positionalArguments
          ?.map((a) => a.toString())
          .toList(),
      'named': command.arguments.namedArguments
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
      'compensation': command.compensation?.function.toString(),
    };
