// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// A serialisable projection of one cell's identity and current value.
///
/// ### When to use
/// As the atom of [CellGraphSnapshot]: one [CellSnapshot] per registered
/// cell. Its [configFingerprint] is the SHA-256 of the cell's receptor
/// name + version, its test rule, and its context — the three things that
/// determine whether a replay of the same pulse sequence will produce the
/// same result.
///
/// ### How it works
/// The snapshot stores the graph-scoped [id], the [configFingerprint], the
/// receptor's version string, the current [value] (JSON-encoded), and any
/// [extras] carried from the nucleus. [toJson]/[fromJson] round-trip the
/// record unchanged.
///
/// See also:
/// * [CellGraphSnapshot] — the container that holds one snapshot per cell.
/// {@category Replay}
class CellSnapshot {
  /// Stable, graph-scoped cell identifier. Assigned by `CellGraph.register`
  /// (graph registration). For standalone use, callers may supply a manual
  /// id, or the snapshot captures `cell.id` (see `Cell.id`), which
  /// falls back to `nucleus:<hex>` when no graph has registered the cell.
  final String id;

  /// SHA-256 fingerprint of the cell's receptor, rule, and context.
  final String configFingerprint;

  /// The receptor's stable version string (see `Receptor.version`).
  /// Empty for the framework's built-in receptors until graph registration stamps
  /// them.
  final String receptorVersion;

  /// Current value, JSON-encoded. The shape matches whatever the cell's
  /// payload type produces; a snapshot does not know the type.
  final Object? value;

  /// Additional per-cell metadata (custom user fields, mirror the
  /// `Nucleus.user` record). Preserved verbatim.
  final Map<String, Object?> extras;

  /// Creates a [CellSnapshot].
  ///
  /// ### Parameters:
  /// - [id]: The stable, graph-scoped cell identifier.
  /// - [configFingerprint]: SHA-256 fingerprint of the cell's receptor,
  ///   rule, and context.
  /// - [receptorVersion]: The receptor's stable version string.
  /// - [value]: The current value, JSON-encoded.
  /// - [extras]: Additional per-cell metadata, preserved verbatim.
  const CellSnapshot({
    required this.id,
    required this.configFingerprint,
    required this.receptorVersion,
    required this.value,
    this.extras = const {},
  });

  /// Serialises this snapshot to a canonical JSON map.
  Map<String, Object?> toJson() => {
        'id': id,
        'configFingerprint': configFingerprint,
        'receptorVersion': receptorVersion,
        'value': value,
        if (extras.isNotEmpty) 'extras': extras,
      };

  /// Reconstructs a [CellSnapshot] from [toJson]'s output.
  ///
  /// ### Parameters:
  /// - [json]: The map produced by [toJson].
  factory CellSnapshot.fromJson(Map<String, Object?> json) {
    return CellSnapshot(
      id: json['id'] as String,
      configFingerprint: json['configFingerprint'] as String,
      receptorVersion: (json['receptorVersion'] as String?) ?? '',
      value: json['value'],
      extras: (json['extras'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }
}
