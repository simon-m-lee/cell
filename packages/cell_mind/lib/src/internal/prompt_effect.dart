// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

const promptEffectVersion = '1.0.0';

/// The journaled record of one LLM prompt call.
///
/// ### When to use
/// Read from a journal replay or the audit trail: every prompted
/// policy decision journals one `PromptEffect` through the
/// `EffectJournal` (`label: 'mind.prompt'`). Reconstruct typed
/// instances via [PromptEffect.fromMap] or
/// [promptEffectFromMap].
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
/// The map carries the full prompt and full response — replay needs
/// the exact response to reproduce the verdict without re-invoking
/// the LLM, and audit needs the exact prompt.
///
/// ### Non-obvious
/// - **The effect is recorded even on cache hits.** The in-process
///   cache only avoids the LLM call; the journal record is what makes
///   replay consume exactly one effect per decision.
/// - **`at` is truncated to milliseconds.** The replay clock restores
///   epochs at millisecond precision; truncation keeps re-created
///   maps fingerprint-identical to the recorded ones.
/// - **Prompts may contain sensitive data.** Apply redaction at the
///   journal layer when the ledger must not store the prompt text.
///
/// ### See also
/// - [promptEffectFromMap], `promptedPolicyWith`, `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them. Reconstruct via
///   [PromptEffect.fromMap] rather than hand-building maps.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class PromptEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The id of the [PromptConfig] that produced this call.
  final String configId;

  /// The semantic version of the [PromptConfig].
  final String configVersion;

  /// SHA-256 of the rendered context fragment.
  final String contextHash;

  /// SHA-256 of the rendered decision fragment.
  final String decisionHash;

  /// The full prompt text sent to the model (for audit).
  final String prompt;

  /// The full response text returned by the model (for replay).
  final String response;

  /// The moment the call completed (millisecond precision).
  final DateTime at;

  /// How long the LLM call took. Zero for cache hits.
  final Duration latency;

  const PromptEffect({
    required this.configId,
    required this.configVersion,
    required this.contextHash,
    required this.decisionHash,
    required this.prompt,
    required this.response,
    required this.at,
    required this.latency,
  });

  /// Serializes this effect for persistence.
  Map<String, dynamic> toMap() => {
        'type': 'mind.prompt',
        'version': schemaVersion,
        'configId': configId,
        'configVersion': configVersion,
        'contextHash': contextHash,
        'decisionHash': decisionHash,
        'prompt': prompt,
        'response': response,
        'at': _isoAt(at),
        'latencyMillis': latency.inMilliseconds,
      };

  /// Reconstructs an effect from [PromptEffect.toMap] output.
  static PromptEffect fromMap(Map<String, dynamic> map) => PromptEffect(
        configId: map['configId'] as String,
        configVersion: map['configVersion'] as String,
        contextHash: map['contextHash'] as String,
        decisionHash: map['decisionHash'] as String,
        prompt: map['prompt'] as String,
        response: map['response'] as String,
        at: DateTime.parse(map['at'] as String),
        latency: Duration(milliseconds: map['latencyMillis'] as int? ?? 0),
      );
}

/// Reconstructs a typed prompt effect from a journal map.
///
/// ### When to use
/// The canonical entry point for journal-side reconstruction, paired
/// with [PromptEffect.toMap].
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the [PromptEffect.fromMap]
///   entry point paired with this type.
///
/// ### See also
/// - The owning module guide and the type paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
PromptEffect promptEffectFromMap(Map<String, dynamic> map) =>
    PromptEffect.fromMap(map);
