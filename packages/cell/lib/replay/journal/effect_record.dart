// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A single recorded non-deterministic observation.
///
/// Every field is a JSON primitive (except [at] which is a `DateTime`
/// serialised to ISO-8601 in [toJson]). The record is designed to be
/// stored verbatim in the ledger, so its canonical form is
/// pinned by this codec and never extended without a schema version bump.
///
/// ### Non-obvious: input/output digests, not raw values
///
/// Recording the *value* of every clock read or I/O response would blow
/// up the ledger (a `Future<Response>` with a 10 KB body per call, times
/// thousands of calls). The journal records the **fingerprint** of the
/// input and the output instead, and stores the raw value in a side
/// buffer only when the value is required to reconstruct (see
/// [EffectRecord.rawOutput]). This keeps the ledger compact and lets
/// `verify()` detect tampering via hash mismatch, without storing
/// secrets in the clear.
sealed class EffectRecord {
  /// Monotonic ordinal within the journal, assigned by [EffectJournal].
  /// Used to assert exact consumption during replay.
  final int ordinal;

  /// SHA-256 fingerprint of the effect's input (e.g. for `Clock.now`, the
  /// fingerprint of `"clock"`; for [IoEffect], the fingerprint of the
  /// request).
  final String inputDigest;

  /// SHA-256 fingerprint of the effect's output (e.g. the epoch millis
  /// for a clock read; the response body for an I/O call).
  final String outputDigest;

  /// Wall-clock time of the observation. Recorded because replay needs to
  /// reconstruct ordering; not part of the *semantics* of the effect.
  final DateTime at;

  const EffectRecord({
    required this.ordinal,
    required this.inputDigest,
    required this.outputDigest,
    required this.at,
  });

  /// The type tag stored in the ledger. Stable across schema versions.
  String get kind;

  Map<String, Object?> toJson() => {
        'kind': kind,
        'ordinal': ordinal,
        'inputDigest': inputDigest,
        'outputDigest': outputDigest,
        'at': at.toUtc().toIso8601String(),
        ...payloadJson(),
      };

  /// The variant-specific payload. Called by [toJson].
  Map<String, Object?> payloadJson();

  /// Reconstruct from [toJson]'s output.
  static EffectRecord fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String?;
    if (kind == null) {
      throw const FormatException('EffectRecord: missing "kind"');
    }
    switch (kind) {
      case 'clock':
        return ClockEffect.fromJson(json);
      case 'uuid':
        return UuidEffect.fromJson(json);
      case 'io':
        return IoEffect.fromJson(json);
      case 'stream':
        return StreamEffect.fromJson(json);
      case 'timer':
        return TimerEffect.fromJson(json);
      case 'verdict':
        return VerdictEffect.fromJson(json);
      case 'policyTick':
        return PolicyTickEffect.fromJson(json);
      default:
        throw FormatException('EffectRecord: unknown kind "$kind"');
    }
  }
}

/// A read of the system clock. Records the epoch millis.
class ClockEffect extends EffectRecord {
  /// The observed wall-clock time (epoch millis).
  final int epochMillis;

  const ClockEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.epochMillis,
  });

  @override
  String get kind => 'clock';

  @override
  Map<String, Object?> payloadJson() => {'epochMillis': epochMillis};

  static ClockEffect fromJson(Map<String, Object?> json) => ClockEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        epochMillis: json['epochMillis'] as int,
      );
}

/// A UUID generation. Records the generated UUID.
class UuidEffect extends EffectRecord {
  /// The generated UUID string.
  final String uuid;

  const UuidEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.uuid,
  });

  @override
  String get kind => 'uuid';

  @override
  Map<String, Object?> payloadJson() => {'uuid': uuid};

  static UuidEffect fromJson(Map<String, Object?> json) => UuidEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        uuid: json['uuid'] as String,
      );
}

/// A single I/O call (network, disk, database). Records the label, the
/// request digest, and the response digest; the **raw response** is held
/// only if the caller supplied `rawOutput`. For replay, `rawOutput` is
/// required — the digest alone cannot reconstruct the response.
class IoEffect extends EffectRecord {
  /// A semantic label, e.g. `'http.GET /profile/42'`. Used by the CLI
  /// for legibility.
  final String label;

  /// The raw response, JSON-encoded, or `null` if the recorder did not
  /// capture it (or the observation genuinely produced `null`). Use
  /// [hasRawOutput] to distinguish the two — a missing record means the
  /// effect cannot be replayed, a recorded `null` can.
  final Object? rawOutput;

  /// Whether `rawOutput` was captured at all. (Review fix: a legitimate
  /// `null` observation used to be indistinguishable from "not
  /// recorded", so `ReplayJournal.io` refused to replay any null result.)
  final bool hasRawOutput;

  const IoEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.label,
    required this.rawOutput,
    required this.hasRawOutput,
  });

  @override
  String get kind => 'io';

  @override
  Map<String, Object?> payloadJson() => {
        'label': label,
        if (rawOutput != null) 'rawOutput': rawOutput,
        'hasRawOutput': hasRawOutput,
      };

  static IoEffect fromJson(Map<String, Object?> json) => IoEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        label: json['label'] as String,
        rawOutput: json['rawOutput'],
        // Pre-review records lack the flag: the key's presence is the
        // old behaviour's "recorded" signal.
        hasRawOutput:
            json['hasRawOutput'] as bool? ?? json['rawOutput'] != null,
      );
}

/// A stream event. Records the event's stream label, the digest of the
/// value, and optionally the raw value.
///
/// ### Non-obvious: codec-only today
///
/// No journal operation produces or consumes `StreamEffect` yet — the
/// journalled operators record stream events as [IoEffect]s. The type
/// exists so the schema is stable for a later dedicated stream
/// journaling (per-event sequence tags).
class StreamEffect extends EffectRecord {
  final String streamLabel;
  final Object? rawValue;

  const StreamEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.streamLabel,
    required this.rawValue,
  });

  @override
  String get kind => 'stream';

  @override
  Map<String, Object?> payloadJson() => {
        'streamLabel': streamLabel,
        if (rawValue != null) 'rawValue': rawValue,
      };

  static StreamEffect fromJson(Map<String, Object?> json) => StreamEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        streamLabel: json['streamLabel'] as String,
        rawValue: json['rawValue'],
      );
}

/// A timer firing. Records the scheduled duration and the actual fire
/// time; the pair is what makes debounce/throttle replayable.
class TimerEffect extends EffectRecord {
  final Duration scheduled;
  final int scheduledAtMillis;
  final int firedAtMillis;

  const TimerEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.scheduled,
    required this.scheduledAtMillis,
    required this.firedAtMillis,
  });

  @override
  String get kind => 'timer';

  @override
  Map<String, Object?> payloadJson() => {
        'scheduled': scheduled.inMicroseconds,
        'scheduledAtMillis': scheduledAtMillis,
        'firedAtMillis': firedAtMillis,
      };

  static TimerEffect fromJson(Map<String, Object?> json) => TimerEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        scheduled: Duration(microseconds: json['scheduled'] as int),
        scheduledAtMillis: json['scheduledAtMillis'] as int,
        firedAtMillis: json['firedAtMillis'] as int,
      );
}

/// The decision reached by an `effectful` [TestCell].
///
/// Recorded once per rule call. On replay, the rule is **not called
/// again**; the recorded decision is served. This is what makes an
/// `effectful` test rule replayable without re-executing its external
/// checks.
///
/// The `inputDigest` is a fingerprint of the object being tested (for
/// a pulse, its canonical JSON; for a value, its canonical JSON). It
/// lets `ReplayJournal` assert that the rule is being asked about the
/// same input it was asked about during recording.
class VerdictEffect extends EffectRecord {
  /// The rule's decision.
  final bool verdict;

  /// A stable label for the rule, e.g. `'AdminRule@1.0.0'`.
  final String ruleLabel;

  const VerdictEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.verdict,
    required this.ruleLabel,
  });

  @override
  String get kind => 'verdict';

  @override
  Map<String, Object?> payloadJson() => {
        'verdict': verdict,
        'ruleLabel': ruleLabel,
      };

  static VerdictEffect fromJson(Map<String, Object?> json) => VerdictEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        verdict: json['verdict'] as bool,
        ruleLabel: json['ruleLabel'] as String,
      );
}

/// A single tick of an [EphemeralPolicy].
///
/// Recorded once per `(policy, cell)` tick during a pulse wave. On
/// replay, the tick is consumed from the journal and re-applied to the
/// `CycleChecker` so diamond graphs do not spuriously detect cycles
/// (the cycle-checker fix the previous revision deferred).
class PolicyTickEffect extends EffectRecord {
  /// A stable label for the policy, e.g. `'cachePolicy'`.
  final String policyLabel;

  /// The cell on which the policy ticked. Necessary because a pulse
  /// can visit multiple cells, and only the cell being ticked matters
  /// to the `CycleChecker`.
  final String cellId;

  const PolicyTickEffect({
    required super.ordinal,
    required super.inputDigest,
    required super.outputDigest,
    required super.at,
    required this.policyLabel,
    required this.cellId,
  });

  @override
  String get kind => 'policyTick';

  @override
  Map<String, Object?> payloadJson() => {
        'policyLabel': policyLabel,
        'cellId': cellId,
      };

  static PolicyTickEffect fromJson(Map<String, Object?> json) =>
      PolicyTickEffect(
        ordinal: json['ordinal'] as int,
        inputDigest: json['inputDigest'] as String,
        outputDigest: json['outputDigest'] as String,
        at: DateTime.parse(json['at'] as String),
        policyLabel: json['policyLabel'] as String,
        cellId: json['cellId'] as String,
      );
}
