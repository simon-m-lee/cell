// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// Serialises and deserialises [PulseContext], preserving the full parent
/// chain.
///
/// ### How it works
/// [PulseContext] is inherited: `childContext.reason` walks up to
/// `parentContext.reason` if the child didn't override it. The wire format
/// must therefore preserve the chain, not just the resolved values.
/// [toJson] walks to the root and stores an **array of deltas** (root
/// first, leaf last). [fromJson] reconstructs the chain as a fold of
/// `fromEntries(parent: previous)`.
///
/// Every level of the chain is emitted — including levels whose local
/// record is empty (e.g. `PulseContext.system`) — so that
/// `encode(decode(encode(x))) == encode(x)` holds byte-for-byte.
///
/// See also:
/// * [PulseCodec] — the pulse serialiser that delegates to this codec.
/// {@category Replay}
class PulseContextCodec {
  const PulseContextCodec._();

  /// Encodes [context] (and its full lineage) to a canonical JSON map.
  ///
  /// ### Parameters:
  /// - [context]: The pulse context to encode.
  ///
  /// ### Returns:
  /// The canonical JSON map, whose `lineage` key holds the delta array in
  /// root-first, leaf-last order — matching the [fromJson] fold order.
  static Map<String, Object?> toJson(PulseContext context) {
    final deltas = <Map<String, Object?>>[];
    PulseContext? cursor = context;
    while (cursor != null) {
      deltas.add(_deltaToJson(cursor));
      cursor = _parentOf(cursor);
    }
    return {
      // Root first, leaf last — matches `fromJson` fold order.
      'lineage': deltas.reversed.toList(growable: false),
    };
  }

  /// Reconstructs a [PulseContext] from [toJson]'s output.
  ///
  /// ### How it works
  /// The `others` maps of each generation are preserved verbatim. Any
  /// property that was resolved by inheritance is *not* re-materialised
  /// here; it is re-resolved by the fold, matching the runtime's own
  /// resolution rules.
  ///
  /// ### Parameters:
  /// - [json]: The canonical map produced by [toJson].
  ///
  /// ### Returns:
  /// The reconstructed context chain.
  static PulseContext fromJson(Map<String, Object?> json) {
    final rawLineage = json['lineage'];
    if (rawLineage is! List) {
      throw FormatException(
        'PulseContext codec: expected {"lineage": [...]}, got $json',
      );
    }
    PulseContext? current;
    for (final raw in rawLineage) {
      if (raw is! Map) {
        throw FormatException('PulseContext codec: lineage entry is not a map');
      }
      final delta = Map<String, Object?>.from(raw);
      // `__others__` is out-of-band metadata, not a governance entry; it is
      // pulled out before the entry switch runs.
      final othersRaw = delta.remove('__others__');
      final entries = _entriesFromDelta(delta);
      final others = othersRaw is Map
          ? Map<String, dynamic>.from(_decodeValue(othersRaw) as Map)
          : null;
      current = PulseContext.fromEntries(
        entries,
        others: others,
        parent: current,
      );
    }
    if (current == null) {
      throw FormatException('PulseContext codec: empty lineage');
    }
    return current;
  }

  // ── private ───────────────────────────────────────────────────────────

  static PulseContext? _parentOf(PulseContext context) {
    // `PulseContext` does not expose a public `parent` getter; the codec
    // reaches in via `_parent`, which is the direct ancestor in the
    // prototype chain. The system context's parent is the non-ContextBase
    // `_ContextSystem` singleton, which maps to "no parent" here.
    final p = context._parent;
    return p is PulseContext ? p : null;
  }

  /// Emits **only locally defined** dimensions — the ones the runtime would
  /// use to build `_record.map`. Inherited values are deliberately omitted;
  /// they re-resolve on `fromJson` via the `parent:` argument.
  static Map<String, Object?> _deltaToJson(PulseContext context) {
    final out = <String, Object?>{};
    void put(String key, Object? v) {
      if (v != null) out[key] = v;
    }

    final record = context._record;
    final map = record?.map as Map<Object, Object?>?;
    if (map != null) {
      for (final entry in map.entries) {
        final key = entry.key;
        // The `_record.map` keys are `Governance` enum instances
        // (`Provenance`/`Ontology`), whose `name` is stable across the wire.
        final name = (key is Enum) ? key.name : key.toString();
        put(name, _encodeValue(entry.value));
      }
    }

    final others = record?.others as Map<String, Object?>?;
    if (others != null && others.isNotEmpty) {
      // Reserved synthetic key: no real `Governance.name` can collide.
      out['__others__'] = _encodeValue(others);
    }
    return out;
  }

  static List<GovernanceEntry> _entriesFromDelta(Map<String, Object?> delta) {
    final out = <GovernanceEntry>[];
    for (final entry in delta.entries) {
      final key = entry.key;
      final value = _decodeValue(entry.value);
      switch (key) {
        // Provenance — the only dimensions a PulseContext stores locally.
        case 'actor':
          out.add(Provenance.actor.entry(value as String));
        case 'reason':
          out.add(Provenance.reason.entry(value as String));
        case 'purpose':
          out.add(Provenance.purpose.entry(value as String));
        case 'strategy':
          out.add(Provenance.strategy.entry(
            ReasoningStrategy.values.byName(value as String),
          ));
        case 'confidence':
          out.add(Provenance.confidence.entry((value as num).toDouble()));
        case 'priority':
          out.add(Provenance.priority.entry(value as int));
        case 'compliance':
          // Wire-format note: `Provenance.compliance` and `Ontology.compliance`
          // share the enum name. A PulseContext's native domain is provenance,
          // so the bare name resolves there; the re-encoded key is identical,
          // keeping the canonical bytes stable either way.
          out.add(Provenance.compliance.entry(value as String));
        case 'sensitivity':
          out.add(Provenance.sensitivity.entry(
            Sensitivity.values.byName(value as String),
          ));
        case 'auditLevel':
          out.add(Provenance.auditLevel.entry(
            AuditLevel.values.byName(value as String),
          ));
        case 'traceId':
          out.add(Provenance.traceId.entry(value as String));
        case 'parentTraceId':
          out.add(Provenance.parentTraceId.entry(value as String));
        case 'integrity':
          out.add(Provenance.integrity.entry(value as String));
        // Ontology dimensions — preserved if any context set them.
        case 'type':
          out.add(Ontology.type.entry(value as String));
        case 'identity':
          out.add(Ontology.identity.entry(value as String));
        case 'domains':
          out.add(Ontology.domains.entry(value as String));
        case 'subDomains':
          out.add(Ontology.subDomains.entry(value as String));
        case 'dataSources':
          out.add(Ontology.dataSources.entry(value as String));
        case 'taxonomy':
          out.add(Ontology.taxonomy.entry(value as String));
        case 'topology':
          out.add(Ontology.topology.entry(value as String));
        case 'version':
          out.add(Ontology.version.entry(value as String));
        case 'stakeholders':
          out.add(Ontology.stakeholders.entry(value as String));
        case 'isNot':
          out.add(Ontology.isNot.entry(value as String));
        case 'partOf':
          out.add(Ontology.partOf.entry(value as String));
        case 'constraints':
          out.add(Ontology.constraints.entry(
            Map<String, dynamic>.from(value as Map),
          ));
        default:
          throw FormatException(
            'PulseContext codec: unknown governance key "$key"',
          );
      }
    }
    return out;
  }

  static Object? _encodeValue(Object? v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    if (v is Enum) return v.name;
    if (v is Map) {
      return v.map((k, value) => MapEntry('$k', _encodeValue(value)));
    }
    if (v is Iterable) return v.map(_encodeValue).toList(growable: false);
    throw ArgumentError.value(
      v,
      'value',
      'Cannot encode ${v.runtimeType} in PulseContext; '
      'extend the codec for custom governance values.',
    );
  }

  static Object? _decodeValue(Object? v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    if (v is Map) {
      return v.map((k, value) => MapEntry(k as String, _decodeValue(value)));
    }
    if (v is List) return v.map(_decodeValue).toList(growable: false);
    return v;
  }
}
