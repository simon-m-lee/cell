// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

// Typed, versioned journal effect records for the bridge module.
//
// The live `EffectJournal` has no generic `record(...)` primitive, so
// effects are persisted through `journal.io(...)` with the label equal
// to the effect `type` and the serialized output equal to `toMap()`.
// These classes are the audit-side representation; `bridgeEffectFromMap`
// reconstructs them from a journal replay.

const bridgeEffectVersion = '1.0.0';

/// Journal-safe timestamp: the replay clock restores epochs at
/// MILLISECOND precision, so effect `at` fields truncate to
/// milliseconds — otherwise re-created maps would never match the
/// recorded input fingerprint.
String _isoAt(DateTime at) =>
    DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch, isUtc: true)
        .toIso8601String();

/// A completion was dispatched to a model.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindCompletionEffect {
  final String actor;
  final String prompt;
  final double confidence;
  final ReasoningStrategy strategy;
  final DateTime at;

  const MindCompletionEffect({
    required this.actor,
    required this.prompt,
    required this.confidence,
    required this.strategy,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.completion',
        'version': bridgeEffectVersion,
        'actor': actor,
        'prompt': prompt,
        'confidence': confidence,
        'strategy': strategy.name,
        'at': _isoAt(at),
      };

  static MindCompletionEffect fromMap(Map<String, dynamic> map) =>
      MindCompletionEffect(
        actor: map['actor'] as String,
        prompt: map['prompt'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        strategy: ReasoningStrategy.values.byName(map['strategy'] as String),
        at: DateTime.parse(map['at'] as String),
      );
}

/// A completion failed.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindCompletionErrorEffect {
  final String error;
  final String stackTrace;
  final DateTime at;

  const MindCompletionErrorEffect({
    required this.error,
    required this.stackTrace,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.completion.error',
        'version': bridgeEffectVersion,
        'error': error,
        'stackTrace': stackTrace,
        'at': _isoAt(at),
      };

  static MindCompletionErrorEffect fromMap(Map<String, dynamic> map) =>
      MindCompletionErrorEffect(
        error: map['error'] as String,
        stackTrace: map['stackTrace'] as String? ?? '',
        at: DateTime.parse(map['at'] as String),
      );
}

/// A streaming token was observed.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindStreamChunkEffect {
  final String actor;
  final String chunk;
  final DateTime at;

  const MindStreamChunkEffect({
    required this.actor,
    required this.chunk,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.stream.chunk',
        'version': bridgeEffectVersion,
        'actor': actor,
        'chunk': chunk,
        'at': _isoAt(at),
      };

  static MindStreamChunkEffect fromMap(Map<String, dynamic> map) =>
      MindStreamChunkEffect(
        actor: map['actor'] as String,
        chunk: map['chunk'] as String,
        at: DateTime.parse(map['at'] as String),
      );
}

/// A tool dispatch was accepted and started.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindToolDispatchEffect {
  final String actor;
  final String verb;
  final Map<String, dynamic> args;
  final DateTime at;

  const MindToolDispatchEffect({
    required this.actor,
    required this.verb,
    required this.args,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.tool.dispatch',
        'version': bridgeEffectVersion,
        'actor': actor,
        'verb': verb,
        'args': args,
        'at': _isoAt(at),
      };

  static MindToolDispatchEffect fromMap(Map<String, dynamic> map) =>
      MindToolDispatchEffect(
        actor: map['actor'] as String,
        verb: map['verb'] as String,
        args: (map['args'] as Map).cast<String, dynamic>(),
        at: DateTime.parse(map['at'] as String),
      );
}

/// A tool returned successfully.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindToolResultEffect {
  final String verb;

  /// JSON-encodable when possible; non-encodable results degrade to
  /// `toString()` (documented, lossy).
  final Object? result;
  final Duration duration;
  final DateTime at;

  const MindToolResultEffect({
    required this.verb,
    required this.result,
    required this.duration,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.tool.result',
        'version': bridgeEffectVersion,
        'verb': verb,
        'result': _encodable(result),
        'durationMillis': duration.inMilliseconds,
        'at': _isoAt(at),
      };

  static MindToolResultEffect fromMap(Map<String, dynamic> map) =>
      MindToolResultEffect(
        verb: map['verb'] as String,
        result: map['result'],
        duration: Duration(milliseconds: map['durationMillis'] as int? ?? 0),
        at: DateTime.parse(map['at'] as String),
      );
}

/// A tool threw.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindToolErrorEffect {
  final String verb;
  final String error;
  final String stackTrace;
  final DateTime at;

  const MindToolErrorEffect({
    required this.verb,
    required this.error,
    required this.stackTrace,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.tool.error',
        'version': bridgeEffectVersion,
        'verb': verb,
        'error': error,
        'stackTrace': stackTrace,
        'at': _isoAt(at),
      };

  static MindToolErrorEffect fromMap(Map<String, dynamic> map) =>
      MindToolErrorEffect(
        verb: map['verb'] as String,
        error: map['error'] as String,
        stackTrace: map['stackTrace'] as String? ?? '',
        at: DateTime.parse(map['at'] as String),
      );
}

/// A dispatch was rejected before execution.
/// ### When to use
/// Serialized into journal maps (`toMap` / `fromMap`); constructed by
/// the bridge layer, read by audit code.
///
/// ### How it works
/// An immutable value object over the journal-safe encodable form.
///
/// ### Non-obvious
/// - `at` is truncated to milliseconds for replay fingerprints.
/// - Reconstruction goes through `bridgeEffectFromMap`.
///
/// ### See also
/// - [bridgeEffectFromMap], `guide/06-Bridges.md`
///
/// ## AI Agent Guide
/// - Effects are data: read them, never mutate them.
///
/// {@category Organ}
/// {@category Bridge}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
final class MindToolRejectedEffect {
  final String verb;

  /// `'unknown-verb'`, `'low-confidence'`, or `'invalid-args'`.
  final String reason;
  final Map<String, dynamic> details;
  final DateTime at;

  const MindToolRejectedEffect({
    required this.verb,
    required this.reason,
    required this.details,
    required this.at,
  });

  Map<String, dynamic> toMap() => {
        'type': 'mind.tool.rejected',
        'version': bridgeEffectVersion,
        'verb': verb,
        'reason': reason,
        'details': details,
        'at': _isoAt(at),
      };

  static MindToolRejectedEffect fromMap(Map<String, dynamic> map) =>
      MindToolRejectedEffect(
        verb: map['verb'] as String,
        reason: map['reason'] as String,
        details: (map['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        at: DateTime.parse(map['at'] as String),
      );
}

/// Reconstructs a typed bridge effect from a journal map.
/// ### When to use
/// The declared purpose is stated above; this section pins the
/// canonical entry point and its prerequisites.
///
/// ### How it works
/// Pure data and functions over the existing decision/effect
/// machinery; no hidden state and no side effects beyond the
/// journal.
///
/// ### Non-obvious
/// - Values are immutable once constructed.
/// - Serialization round-trips through the `fromMap` entry
///   point paired with this type.
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
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
Object bridgeEffectFromMap(Map<String, dynamic> map) {
  switch (map['type']) {
    case 'mind.completion':
      return MindCompletionEffect.fromMap(map);
    case 'mind.completion.error':
      return MindCompletionErrorEffect.fromMap(map);
    case 'mind.stream.chunk':
      return MindStreamChunkEffect.fromMap(map);
    case 'mind.tool.dispatch':
      return MindToolDispatchEffect.fromMap(map);
    case 'mind.tool.result':
      return MindToolResultEffect.fromMap(map);
    case 'mind.tool.error':
      return MindToolErrorEffect.fromMap(map);
    case 'mind.tool.rejected':
      return MindToolRejectedEffect.fromMap(map);
    default:
      throw ArgumentError.value(
        map['type'],
        'type',
        'Unknown bridge effect',
      );
  }
}

/// Records a typed bridge effect through the live journal surface.
Future<void> _recordBridgeEffect(
  EffectJournal journal,
  Map<String, dynamic> map,
) async {
  await journal.io<Object?>(
    label: map['type'] as String,
    input: map,
    run: () async => null,
    serializeOutput: (_) => map,
  );
}

/// The journal's raw-output encoding: primitives, collections of
/// encodables, and enums pass through; everything else degrades to
/// `toString()` (lossy, documented).
Object? _encodable(Object? value) {
  if (value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is Enum) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(_encodable(k), _encodable(v)),
    );
  }
  if (value is Iterable) {
    return value.map(_encodable).toList();
  }
  return value.toString();
}
