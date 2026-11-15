// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// The outcome of a policy decision — accept, reject, or defer.
///
/// ### When to use
/// Authored and interpreted by the `CognitiveHandle` runtime (Phase 2):
/// every decision in the log carries a [Verdict], and `Defer` hands the
/// decision to a named resolver. User code composes `Policy` factories
/// that return `bool`; the runtime adapts `bool` to [Verdict].
///
/// ### Non-obvious
/// - **`Defer` requires a resolver.** A deferred decision names a
///   resolver; the runtime consults it to resolve to accept/reject.
///   A `Defer` without a registered resolver fails closed (rejects).
/// - **Annotations are user data.** The map carries anything the
///   producing policy wants the audit trail to preserve — pattern
///   matches, reasons, evidence.
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
/// {@category Organ}
///
/// **Stability:** Stable since `cell_mind 1.0.0`.
sealed class Verdict {
  const Verdict();

  /// The discriminant: `'accept'`, `'reject'`, or `'defer'`.
  String get type;

  /// Serializes this verdict for the decision log.
  Map<String, dynamic> toMap();
}

/// The decision passed — the pulse/command may proceed.
final class Accept extends Verdict {
  final Map<String, dynamic> annotations;

  const Accept([this.annotations = const {}]);

  @override
  String get type => 'accept';

  @override
  Map<String, dynamic> toMap() =>
      {'type': 'accept', 'annotations': annotations};
}

/// The decision failed — the pulse/command is dropped with [reason].
final class Reject extends Verdict {
  final String reason;
  final Map<String, dynamic> annotations;

  const Reject(this.reason, [this.annotations = const {}]);

  @override
  String get type => 'reject';

  @override
  Map<String, dynamic> toMap() =>
      {'type': 'reject', 'reason': reason, 'annotations': annotations};
}

/// The decision is handed to the resolver named by [resolver].
///
/// ### Non-obvious
/// `Defer` is not a "maybe". It hands the decision to a named resolver.
/// The resolver returns accept or reject — never another `Defer`.
final class Defer extends Verdict {
  final String resolver;
  final Map<String, dynamic> annotations;

  const Defer(this.resolver, [this.annotations = const {}]);

  @override
  String get type => 'defer';

  @override
  Map<String, dynamic> toMap() =>
      {'type': 'defer', 'resolver': resolver, 'annotations': annotations};
}

/// Reconstitutes a [Verdict] from [Verdict.toMap] output.
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
Verdict verdictFromMap(Map<String, dynamic> map) {
  switch (map['type']) {
    case 'accept':
      return Accept(
        (map['annotations'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    case 'reject':
      return Reject(
        map['reason'] as String,
        (map['annotations'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    case 'defer':
      return Defer(
        map['resolver'] as String,
        (map['annotations'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    default:
      throw ArgumentError.value(map['type'], 'type', 'Unknown verdict type');
  }
}
