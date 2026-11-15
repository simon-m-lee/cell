// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

const promptEffectVersion = '1.1.0';

/// The journaled record of one LLM prompt call.
///
/// ### When to use
/// Read from a journal replay or the audit trail: every LLM-call
/// decision journals one `PromptEffect` through the `EffectJournal`
/// (`label: 'mind.prompt'`). Reconstruct typed instances via
/// [PromptEffect.fromMap] or [promptEffectFromMap].
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
/// The map carries the full prompt and full response — replay needs
/// the exact response to reproduce the verdict without re-invoking
/// the LLM, and audit needs the exact prompt.
///
/// ### Non-obvious
/// - **Session metadata (1.1.0).** [sessionFingerprint] and
///   [sessionId] are null when the policy is stateless; a non-null
///   fingerprint identifies the exact conversation state the LLM saw.
/// - **The effect is recorded only on LLM calls.** Verdict cache hits
///   journal [VerdictCacheHitEffect] instead.
/// - **`at` is truncated to milliseconds.** The replay clock restores
///   epochs at millisecond precision; truncation keeps re-created
///   maps fingerprint-identical to the recorded ones.
/// - **Prompts may contain sensitive data.** Apply redaction at the
///   journal layer when the ledger must not store the prompt text.
///
/// ### See also
/// - [promptEffectFromMap], [VerdictCacheHitEffect],
///   `promptedPolicyWith`, `guide/12-Prompted-Policy.md`
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
  /// The effect schema version (bumped for session support).
  static const schemaVersion = '1.1.0';

  /// The id of the [PromptConfig] that produced this call.
  final String configId;

  /// The semantic version of the [PromptConfig].
  final String configVersion;

  /// The verdict cache key fingerprint for this decision.
  final String cacheKey;

  /// SHA-256 of the rendered context fragment.
  final String contextHash;

  /// SHA-256 of the rendered decision fragment.
  final String decisionHash;

  /// SHA-256 of the session history at call time, or `null` when the
  /// policy is stateless.
  final String? sessionFingerprint;

  /// The session id at call time, or `null` when stateless.
  final String? sessionId;

  /// The full prompt text sent to the model (for audit).
  final String prompt;

  /// The full response text returned by the model (for replay).
  final String response;

  /// The moment the call completed (millisecond precision).
  final DateTime at;

  /// How long the LLM call took.
  final Duration latency;

  const PromptEffect({
    required this.configId,
    required this.configVersion,
    required this.cacheKey,
    required this.contextHash,
    required this.decisionHash,
    required this.prompt,
    required this.response,
    required this.at,
    required this.latency,
    this.sessionFingerprint,
    this.sessionId,
  });

  /// Serializes this effect for persistence.
  Map<String, dynamic> toMap() => {
        'type': 'mind.prompt',
        'version': schemaVersion,
        'configId': configId,
        'configVersion': configVersion,
        'cacheKey': cacheKey,
        'contextHash': contextHash,
        'decisionHash': decisionHash,
        'sessionFingerprint': sessionFingerprint,
        'sessionId': sessionId,
        'prompt': prompt,
        'response': response,
        'at': _isoAt(at),
        'latencyMillis': latency.inMilliseconds,
      };

  /// Reconstructs an effect from [PromptEffect.toMap] output.
  static PromptEffect fromMap(Map<String, dynamic> map) => PromptEffect(
        configId: map['configId'] as String,
        configVersion: map['configVersion'] as String,
        cacheKey: map['cacheKey'] as String? ?? '',
        contextHash: map['contextHash'] as String? ?? '',
        decisionHash: map['decisionHash'] as String? ?? '',
        sessionFingerprint: map['sessionFingerprint'] as String?,
        sessionId: map['sessionId'] as String?,
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

/// The journaled record of a verdict-cache (or prompt-cache) hit.
///
/// ### When to use
/// Read from a journal replay: a recorded cache hit is journaled as
/// this effect (`label: 'mind.prompt.cache.hit'`), which is what lets
/// a replay reproduce the recorded hit without the same cache state.
///
/// ### How it works
/// Carries the [VerdictCacheKey.fingerprint] and the served [verdict]
/// with its lookup latency.
///
/// ### Non-obvious
/// - **Cache hits do not append to sessions** (D14): a repeated
///   decision is not a new conversation turn.
/// - **Prompt-cache hits journal this effect too** — the effective
///   cache served the verdict either way.
///
/// ### See also
/// - [VerdictCache], [PromptEffect], `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Prompt}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class VerdictCacheHitEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The config id.
  final String configId;

  /// The config version.
  final String configVersion;

  /// The verdict cache key fingerprint that hit.
  final String cacheKey;

  /// The served verdict.
  final Verdict verdict;

  /// When the hit was served.
  final DateTime at;

  /// Lookup time.
  final Duration lookupLatency;

  const VerdictCacheHitEffect({
    required this.configId,
    required this.configVersion,
    required this.cacheKey,
    required this.verdict,
    required this.at,
    required this.lookupLatency,
  });

  /// Serializes this effect.
  Map<String, dynamic> toMap() => {
        'type': 'mind.prompt.cache.hit',
        'version': schemaVersion,
        'configId': configId,
        'configVersion': configVersion,
        'cacheKey': cacheKey,
        'verdict': verdict.toMap(),
        'at': _isoAt(at),
        'lookupLatencyMillis': lookupLatency.inMilliseconds,
      };

  /// Reconstructs an effect from [VerdictCacheHitEffect.toMap] output.
  static VerdictCacheHitEffect fromMap(Map<String, dynamic> map) =>
      VerdictCacheHitEffect(
        configId: map['configId'] as String,
        configVersion: map['configVersion'] as String,
        cacheKey: map['cacheKey'] as String? ?? '',
        verdict: verdictFromMap(
          (map['verdict'] as Map).cast<String, dynamic>(),
        ),
        at: DateTime.parse(map['at'] as String),
        lookupLatency: Duration(
          milliseconds: map['lookupLatencyMillis'] as int? ?? 0,
        ),
      );
}

/// Reconstructs a typed cache-hit effect from a journal map.
///
/// ### When to use
/// The canonical entry point for journal-side reconstruction, paired
/// with [VerdictCacheHitEffect.toMap].
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the [VerdictCacheHitEffect.fromMap]
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
VerdictCacheHitEffect verdictCacheHitEffectFromMap(Map<String, dynamic> map) =>
    VerdictCacheHitEffect.fromMap(map);

/// The journaled record of a session's first population.
///
/// ### When to use
/// Read from a journal replay: `label: 'mind.session.init'`.
///
/// ### How it works
/// Carries the session id and its initial messages so replay can
/// validate the reconstructed conversation against the recorded one.
///
/// ### Non-obvious
/// - **Dedicated sessions record an empty initialization** — the
///   effect marks the session's existence.
/// - **Shared sessions record their pre-populated state.**
///
/// ### See also
/// - [SessionAppendedEffect], [PromptSession]
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class SessionInitializedEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The session id.
  final String sessionId;

  /// The messages present at initialization.
  final List<ChatMessage> initialMessages;

  /// When the initialization was recorded.
  final DateTime at;

  const SessionInitializedEffect({
    required this.sessionId,
    required this.initialMessages,
    required this.at,
  });

  /// Serializes this effect.
  Map<String, dynamic> toMap() => {
        'type': 'mind.session.init',
        'version': schemaVersion,
        'sessionId': sessionId,
        'initialMessages': initialMessages.map((m) => m.toMap()).toList(),
        'at': _isoAt(at),
      };

  /// Reconstructs an effect from [SessionInitializedEffect.toMap] output.
  static SessionInitializedEffect fromMap(Map<String, dynamic> map) =>
      SessionInitializedEffect(
        sessionId: map['sessionId'] as String,
        initialMessages: (map['initialMessages'] as List? ?? const [])
            .map((m) => ChatMessage.fromMap((m as Map).cast<String, dynamic>()))
            .toList(),
        at: DateTime.parse(map['at'] as String),
      );
}

/// The journaled record of one `(user, assistant)` session exchange.
///
/// ### When to use
/// Read from a journal replay: `label: 'mind.session.append'`.
///
/// ### How it works
/// Carries the exact two messages appended after a successful LLM
/// decision, so replay can reconstruct the conversation deterministically.
///
/// ### Non-obvious
/// - **Failed calls do not append** — no effect is recorded.
/// - **Verdict cache hits do not append** — no effect is recorded.
///
/// ### See also
/// - [SessionInitializedEffect], [PromptSession]
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class SessionAppendedEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The session id.
  final String sessionId;

  /// The appended user message.
  final ChatMessage userMessage;

  /// The appended assistant message.
  final ChatMessage assistantMessage;

  /// When the append was recorded.
  final DateTime at;

  const SessionAppendedEffect({
    required this.sessionId,
    required this.userMessage,
    required this.assistantMessage,
    required this.at,
  });

  /// Serializes this effect.
  Map<String, dynamic> toMap() => {
        'type': 'mind.session.append',
        'version': schemaVersion,
        'sessionId': sessionId,
        'userMessage': userMessage.toMap(),
        'assistantMessage': assistantMessage.toMap(),
        'at': _isoAt(at),
      };

  /// Reconstructs an effect from [SessionAppendedEffect.toMap] output.
  static SessionAppendedEffect fromMap(Map<String, dynamic> map) =>
      SessionAppendedEffect(
        sessionId: map['sessionId'] as String,
        userMessage: ChatMessage.fromMap(
          (map['userMessage'] as Map).cast<String, dynamic>(),
        ),
        assistantMessage: ChatMessage.fromMap(
          (map['assistantMessage'] as Map).cast<String, dynamic>(),
        ),
        at: DateTime.parse(map['at'] as String),
      );
}

/// The journaled record of a session reset.
///
/// ### When to use
/// Read from a journal replay: `label: 'mind.session.clear'`.
///
/// ### How it works
/// Carries the session id; replay clears the reconstructed session at
/// the recorded point.
///
/// ### Non-obvious
/// - Calling [PromptSession.clear] directly does not journal; use
///   [PromptedPolicy.clearSession] for journaled clears.
///
/// ### See also
/// - [PromptedPolicy.clearSession], [PromptSession]
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class SessionClearedEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The session id.
  final String sessionId;

  /// When the clear was recorded.
  final DateTime at;

  const SessionClearedEffect({
    required this.sessionId,
    required this.at,
  });

  /// Serializes this effect.
  Map<String, dynamic> toMap() => {
        'type': 'mind.session.clear',
        'version': schemaVersion,
        'sessionId': sessionId,
        'at': _isoAt(at),
      };

  /// Reconstructs an effect from [SessionClearedEffect.toMap] output.
  static SessionClearedEffect fromMap(Map<String, dynamic> map) =>
      SessionClearedEffect(
        sessionId: map['sessionId'] as String,
        at: DateTime.parse(map['at'] as String),
      );
}

/// The journaled record of one session compaction.
///
/// ### When to use
/// Read from a journal replay: `label: 'mind.session.compact'`.
///
/// ### How it works
/// Carries the number of dropped `(user, assistant)` pairs; replay
/// validates that its own deterministic compaction dropped the same
/// number.
///
/// ### Non-obvious
/// - **Pairs are never partially dropped.**
/// - **System-message fallback drops are not counted as pairs.**
///
/// ### See also
/// - [PromptSession], `guide/12-Prompted-Policy.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
final class SessionCompactedEffect {
  /// The effect schema version.
  static const schemaVersion = '1.0.0';

  /// The session id.
  final String sessionId;

  /// The number of dropped `(user, assistant)` pairs.
  final int droppedPairs;

  /// When the compaction was recorded.
  final DateTime at;

  const SessionCompactedEffect({
    required this.sessionId,
    required this.droppedPairs,
    required this.at,
  });

  /// Serializes this effect.
  Map<String, dynamic> toMap() => {
        'type': 'mind.session.compact',
        'version': schemaVersion,
        'sessionId': sessionId,
        'droppedPairs': droppedPairs,
        'at': _isoAt(at),
      };

  /// Reconstructs an effect from [SessionCompactedEffect.toMap] output.
  static SessionCompactedEffect fromMap(Map<String, dynamic> map) =>
      SessionCompactedEffect(
        sessionId: map['sessionId'] as String,
        droppedPairs: map['droppedPairs'] as int? ?? 0,
        at: DateTime.parse(map['at'] as String),
      );
}

/// Reconstructs a typed session effect from a journal map.
///
/// ### When to use
/// The canonical entry point for journal-side reconstruction, paired
/// with the four session effect types.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the paired `fromMap` entry
///   points.
///
/// ### See also
/// - The owning module guide and the types paired with this
///   declaration.
///
/// ## AI Agent Guide
/// - Read these values; never mutate them. Reconstruct via the
///   paired `fromMap` rather than hand-building maps.
///
/// {@category Organ}
/// {@category Prompt}
/// {@category Session}
///
/// **Stability:** Stable since `cell_mind 1.1.0`.
Object sessionEffectFromMap(Map<String, dynamic> map) {
  switch (map['type']) {
    case 'mind.session.init':
      return SessionInitializedEffect.fromMap(map);
    case 'mind.session.append':
      return SessionAppendedEffect.fromMap(map);
    case 'mind.session.clear':
      return SessionClearedEffect.fromMap(map);
    case 'mind.session.compact':
      return SessionCompactedEffect.fromMap(map);
    default:
      throw ArgumentError.value(
        map['type'],
        'type',
        'Unknown session effect',
      );
  }
}
