// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

part of '../../cell_tissue.dart';

/// The canonical wire version produced (and accepted) by this codec.
const String _kTissueWireVersion = '1.0.0';

/// The tissue kinds the codec dispatches on.
const Set<String> _kTissueKinds = {'list', 'set', 'map', 'queue', 'value'};

/// A tissue cannot be serialised because it carries a field with no honest
/// wire representation.
///
/// ### When to use
/// Catch it around `tissue.toJson()` / [encodeTissue]. The [field] names the
/// offender: `'receptor'`, `'testRule'`, `'policy'`, `'elements'`,
/// `'container'`, `'context'`, `'bind'`, or `'user'`. [tissue] is the tissue
/// that carried the field.
///
/// ### Non-obvious
/// [toString] names the escape hatch (`lenient: true`) so a caller who hits
/// the error learns the parameter name from the message.
class TissueNotSerializable implements Exception {
  /// The offending field.
  final String field;

  /// The tissue whose field was non-serialisable.
  final Tissue<dynamic> tissue;

  /// Creates an error naming [field] on [tissue].
  const TissueNotSerializable(this.field, this.tissue);
  @override
  String toString() => 'TissueNotSerializable: tissue carries $field. '
      'Pass lenient: true to encodeTissue to substitute a safe default.';
}

/// A tissue JSON record cannot be decoded.
///
/// ### When to use
/// Catch it around `TissueXxx.fromJson` / [decodeTissue]. [message] names the
/// decode problem; [cause] carries the underlying error when one exists;
/// [field] names the offending wire field when one is identifiable.
class TissueDecodeError implements Exception {
  /// The decode problem, in human-readable form.
  final String message;

  /// The underlying error that caused the decode failure, when one exists.
  final Object? cause;

  /// The wire field that could not be decoded, when identifiable.
  final String? field;

  /// Creates an error carrying [message], an optional [cause], and the
  /// optional wire [field].
  const TissueDecodeError(this.message, {this.cause, this.field});

  @override
  String toString() => 'TissueDecodeError: $message';
}

/// Encodes [tissue] to its canonical JSON wire form.
///
/// ## Strict mode (default)
///
/// When [lenient] is `false`, throws [TissueNotSerializable] on the first
/// field that cannot be honestly reconstructed: a custom receptor, a
/// non-registered test rule, an [EphemeralPolicy], a custom container, a
/// `Cell` element with an empty `id`, or a non-JSON-encodable element /
/// user value. The error names the field.
///
/// ## Lenient mode
///
/// When [lenient] is `true`, suppresses [TissueNotSerializable]. For each
/// non-serialisable field a safe, fail-closed default is substituted and the
/// field name is recorded in the encoded JSON's `__skipped__` array (sorted,
/// present iff a substitution occurred). The result is always valid canonical
/// JSON that decodes in strict or lenient mode.
///
/// ## Security default
///
/// [lenientFallbackTestRule] is the rule used when [lenient] is `true` and
/// the tissue carries an untaggable rule. It defaults to
/// [TestTissue.readOnly] — a **fail-closed** default that blocks mutations
/// on the reconstructed tissue. Pass [TestTissue.allowAll] explicitly if you
/// accept the wider permission.
///
/// ### Round-trip
/// `decodeTissue(encodeTissue(t))` reproduces `t` to codec precision. Two
/// logically-equal tissues produce the same bytes under
/// [canonicalJsonEncode].
Map<String, dynamic> encodeTissue(
  Tissue<dynamic> tissue, {
  bool lenient = false,
  TestTissue<dynamic, Tissue<dynamic>> lenientFallbackTestRule =
      TestTissue.readOnly,
}) {
  final skipped = <String>[];

  T guarded<T>(String field, T Function() check, T fallback) {
    try {
      return check();
    } on TissueNotSerializable {
      if (!lenient) rethrow;
      skipped.add(field);
      return fallback;
    }
  }

  // 1. Kind — the shape dispatch drives every later step. A tissue that is
  //    none of the five shapes fails here (strict) or falls back to the
  //    shape implied by its storage (lenient).
  final kind =
      guarded('container', () => _kindOf(tissue), _defaultKindFor(tissue));

  // 2. receptor → the gate is a validation; passThrough is the decode
  //    default so no receptor field is emitted.
  guarded('receptor', () => _requireDefaultReceptor(tissue),
      TissueReceptor.passThrough);

  // 3. ephemeralPolicy → never serialised.
  guarded('policy', () => _requireNoPolicy(tissue), null);

  // 4. testRule → tag.
  final ruleTag = guarded('testRule', () => _requireTaggedRule(tissue),
      _tagOf(lenientFallbackTestRule) ?? 'readOnly');

  // 5. container → tag.
  final containerTag = guarded('container', () => _requireContainerTag(tissue),
      _defaultContainerTag(kind));

  // 6. elements — per-element leniency.
  final elements =
      _encodeElements(tissue, kind, lenient: lenient, skipped: skipped);

  // 7. context.
  final context = guarded(
      'context',
      () => _encodeContext(tissue.context, tissue),
      _encodeContext(Context.system, tissue));

  // 8. bind.
  final bind = guarded('bind', () => _requireResolvableBind(tissue), null);

  // 9. user.
  final user = guarded(
      'user', () => _encodeUserValue(tissue._nucleus.user, tissue), null);

  // A decode wraps the user record as `(value:, __skipped__:)`; the wire
  // skip list is provenance, so it is re-emitted to keep
  // encode → decode → encode byte-identical.
  skipped.addAll(_wireSkippedOf(tissue._nucleus.user));

  final wire = <String, dynamic>{
    '__tissue__': _kTissueWireVersion,
    'kind': kind,
    'config': {
      'container': containerTag,
      'capacity': _capacityOf(tissue, kind),
      'synapses': _synapsesTag(tissue._nucleus.synapses),
    },
    'elements': elements,
    'governance': {
      'testRule': {'tag': ruleTag},
      'context': context,
      'bind': bind,
    },
    'user': user,
  };
  if (skipped.isNotEmpty) {
    final unique = skipped.toSet().toList()..sort();
    wire['__skipped__'] = unique;
  }
  return wire;
}

/// Decodes a tissue from canonical JSON produced by [encodeTissue].
///
/// ## Strict mode (default)
///
/// When [lenient] is `false`, throws [TissueDecodeError] for any
/// unresolvable reference: a `registered:` tag with no governance resolver
/// (and no [TissueGovernanceRegistry] entry), or a Map key/value that cannot
/// be resolved via [cellResolver].
///
/// ## Lenient mode
///
/// When [lenient] is `true`, suppresses [TissueDecodeError] **where the
/// document structure is sound** and only a reference is missing:
///
/// * An unresolved `registered:` tag falls back to
///   [lenientFallbackTestRule] (default [TestTissue.readOnly]).
/// * An unresolved Map key or value drops the entry.
/// * An unresolved `Cell` element in List/Set/Queue/Value becomes `null`
///   (also in strict mode — see [TissueCellResolver]).
///
/// **Lenient mode does not suppress structural corruption**: an unknown
/// `__tissue__` version, an unknown `kind`, or malformed `elements` still
/// throws [TissueDecodeError]. A partial result from a corrupt document
/// would be fabricated, not partial.
///
/// ## On-skip reporting
///
/// [onSkipped] is invoked once, after decoding completes, with the list of
/// skipped field categories (wire entries first, then decode entries). It is
/// only invoked when [lenient] is `true` and at least one reference was
/// unresolved. The same information is recorded on the decoded tissue's
/// `user` record and is readable as `user['__skipped__']` with distinct
/// `wire` and `decode` keys.
TissueBase<dynamic, dynamic, dynamic> decodeTissue(
  Map<String, dynamic> json, {
  TissueCellResolver? cellResolver,
  TissueGovernanceResolver? governanceResolver,
  bool lenient = false,
  TestTissue<dynamic, Tissue<dynamic>> lenientFallbackTestRule =
      TestTissue.readOnly,
  void Function(List<String> skipped)? onSkipped,
}) {
  // 1. Structural checks — these always throw, in both modes.
  final version = json['__tissue__'];
  if (version == null || version is! String || !version.startsWith('1.')) {
    throw TissueDecodeError(
        'missing or unsupported __tissue__ version: $version');
  }
  final kind = json['kind'];
  if (kind is! String || !_kTissueKinds.contains(kind)) {
    throw TissueDecodeError('unknown tissue kind: $kind', field: 'kind');
  }

  // 2. Wire __skipped__ (from a lenient encode) is preserved for inspection.
  final wireSkipped = <String>[];
  final rawWireSkipped = json['__skipped__'];
  if (rawWireSkipped != null) {
    if (rawWireSkipped is! List) {
      throw TissueDecodeError('malformed __skipped__: expected an array',
          field: '__skipped__');
    }
    for (final entry in rawWireSkipped) {
      if (entry is String) wireSkipped.add(entry);
    }
  }

  // 3. Governance — only this can degrade in lenient mode.
  final gov = json['governance'];
  if (gov is! Map) {
    throw TissueDecodeError('missing or malformed governance',
        field: 'governance');
  }
  final skipped = <String>[];
  final testRule = _decodeRule(gov['testRule'], governanceResolver,
      lenient: lenient, fallback: lenientFallbackTestRule, skipped: skipped);
  final context = _decodeContext(gov['context']);
  final bindId = gov['bind'];
  if (bindId != null && bindId is! String) {
    throw TissueDecodeError('malformed bind: expected a cell id string',
        field: 'bind');
  }
  final bind = bindId is String ? cellResolver?.call(bindId) : null;

  // 4. Config.
  final config = json['config'];
  if (config is! Map) {
    throw TissueDecodeError('missing or malformed config', field: 'config');
  }
  final container = _containerOfTag(config['container'], kind);
  final capacity = _decodeCapacity(config['capacity'], kind);
  final synapses = _synapsesOf(config['synapses']);

  // 5. Elements — per-shape decode with lenient reference handling.
  final elements = _decodeElements(json['elements'], kind,
      cellResolver: cellResolver, lenient: lenient, skipped: skipped);

  // 6. Construct.
  final decodedUser = _jsonDecodeValue(json['user']);
  final tissue = _instantiate(kind,
      elements: elements,
      container: container,
      capacity: capacity,
      synapses: synapses,
      testRule: testRule,
      context: context,
      bind: bind,
      user: decodedUser,
      wireSkipped: wireSkipped,
      decodeSkipped: skipped);

  // 7. Surface wire-skipped + decode-skipped.
  final allSkipped = <String>{...wireSkipped, ...skipped}.toList();
  if (lenient && allSkipped.isNotEmpty) {
    onSkipped?.call(allSkipped);
  }
  return tissue;
}

// ─────────────────────────────────────────────────────────────────────────────
// Override helpers — shared by the five `fromJson` factories.
// ─────────────────────────────────────────────────────────────────────────────

/// Resolves the `testRule` override for a `fromJson` factory.
///
/// * [tissueNullTestRule] → [TestTissue.allowAll] (explicit widening).
/// * `null` → the rule decoded from the JSON.
/// * Anything else → itself.
TestTissue<dynamic, Tissue<dynamic>> _resolveRuleOverride(
  Object? testRule,
  TestTissue<dynamic, Tissue<dynamic>> fromJson,
) {
  if (testRule == null) return fromJson;
  if (identical(testRule, tissueNullTestRule)) return TestTissue.allowAll;
  return testRule as TestTissue<dynamic, Tissue<dynamic>>;
}

/// Resolves the `bind` override for a `fromJson` factory.
Cell? _resolveBindOverride(Object? bind, Cell? fromJson) {
  if (bind == null) return fromJson;
  if (identical(bind, tissueNullBind)) return null;
  return bind as Cell;
}

/// Resolves the `container` override for a `fromJson` factory.
Container _resolveContainerOverride(Object? container, Container fromJson) {
  if (container == null) return fromJson;
  if (identical(container, tissueNullContainer)) return fromJson;
  return container as Container;
}

/// Resolves the `user` override for a `fromJson` factory.
Object? _resolveUserOverride(Object? user, Object? fromJson) {
  if (user == null) return fromJson;
  if (identical(user, tissueNullUser)) return null;
  return user;
}

// ─────────────────────────────────────────────────────────────────────────────
// Encoder internals
// ─────────────────────────────────────────────────────────────────────────────

/// The wire kind of [tissue]. A tissue that is none of the five shapes is
/// not serialisable by shape.
String _kindOf(Tissue<dynamic> tissue) {
  if (tissue is TissueList) return 'list';
  if (tissue is TissueSet) return 'set';
  if (tissue is TissueMap) return 'map';
  if (tissue is TissueQueue) return 'queue';
  if (tissue is TissueValue) return 'value';
  throw TissueNotSerializable('container', tissue);
}

/// The kind used when shape dispatch failed — a tissue that is none of the
/// five shapes falls back to the list shape in lenient mode.
String _defaultKindFor(Tissue<dynamic> tissue) => 'list';

/// Fails unless the tissue's receptor behaves as the pass-through default.
TissueReceptor<dynamic, dynamic> _requireDefaultReceptor(
    Tissue<dynamic> tissue) {
  final receptor = tissue._nucleus.receptor;
  if (_isPassThroughReceptor(receptor)) {
    return receptor;
  }
  throw TissueNotSerializable('receptor', tissue);
}

/// Whether [receptor] is behaviourally the pass-through default. The
/// framework stores the default as either the `passThrough` singleton or an
/// empty-record `_TissueReceptor` clone, so identity alone is not enough.
bool _isPassThroughReceptor(Object? receptor) {
  if (identical(receptor, TissueReceptor.passThrough)) return true;
  if (receptor is _TissueReceptor && identical(receptor._record, ())) {
    return true;
  }
  return false;
}

/// Fails when the tissue hosts an [EphemeralPolicy].
void _requireNoPolicy(Tissue<dynamic> tissue) {
  final nucleus = tissue._nucleus;
  final EphemeralPolicy? policy;
  if (nucleus is TissueNucleusBase<dynamic, dynamic, dynamic>) {
    policy = nucleus._hostedEphemeralPolicy;
  } else {
    policy = null;
  }
  if (policy != null) throw TissueNotSerializable('policy', tissue);
}

/// The tag of [rule] — `allowAll`, `readOnly`, or `registered:<key>` via
/// [TissueGovernanceRegistry]. A composed `allowAll + rule` chain that
/// holds a single inner rule unwraps to the inner rule's tag (the allowAll
/// singleton is the identity element of `+`). Returns `null` for an
/// untaggable rule.
String? _tagOf(TestTissue<dynamic, Tissue<dynamic>> rule) {
  if (identical(rule, TestTissue.allowAll)) return 'allowAll';
  if (identical(rule, TestTissue.readOnly)) return 'readOnly';
  if (rule is _TestTissueAllowAll && rule._others.length == 1) {
    final inner = rule._others.single;
    if (identical(inner, TestTissue.allowAll)) return 'allowAll';
    if (identical(inner, TestTissue.readOnly)) return 'readOnly';
    final registered = TissueGovernanceRegistry.tagOf(
        inner as TestTissue<dynamic, Tissue<dynamic>>);
    if (registered != null) return 'registered:$registered';
    return null;
  }
  final registered = TissueGovernanceRegistry.tagOf(rule);
  if (registered != null) return 'registered:$registered';
  return null;
}

/// Fails unless the tissue's rule carries a tag. An [UnmodifiableTissue]
/// view encodes as `readOnly` — its semantic fact — even when its nucleus
/// resolves the rule through the principal.
String _requireTaggedRule(Tissue<dynamic> tissue) {
  if (tissue is UnmodifiableTissue) return 'readOnly';
  final rule = tissue.validate;
  final tag = _tagOf(rule);
  if (tag == null) throw TissueNotSerializable('testRule', tissue);
  return tag;
}

/// Fails unless the tissue's container strategy has a wire tag.
String _requireContainerTag(Tissue<dynamic> tissue) {
  final container = tissue._nucleus.containerType;
  try {
    return _containerTagOf(container);
  } on StateError {
    throw TissueNotSerializable('container', tissue);
  }
}

/// The wire tag of [container]; throws [StateError] for a custom strategy.
String _containerTagOf(Container container) {
  if (identical(container, Container.growableTrue) ||
      identical(container, Container.list)) {
    return 'growableTrue';
  }
  if (identical(container, Container.growableFalse)) return 'growableFalse';
  if (identical(container, Container.set)) return 'set';
  if (identical(container, Container.identitySet)) return 'identitySet';
  if (identical(container, Container.map)) return 'map';
  if (identical(container, Container.identityMap)) return 'identityMap';
  if (identical(container, Container.queue)) return 'queue';
  if (identical(container, Container.value)) return 'value';
  if (identical(container, Container.finalValue)) return 'finalValue';
  throw StateError('unknown container strategy: ${container.runtimeType}');
}

/// The framework default container tag for [kind].
String _defaultContainerTag(String kind) => switch (kind) {
      'list' => 'growableTrue',
      'set' => 'set',
      'map' => 'map',
      'queue' => 'queue',
      _ => 'value',
    };

/// Fails when the upstream bind has no resolvable id; returns `null` when
/// there is no bind.
String? _requireResolvableBind(Tissue<dynamic> tissue) {
  final bind = tissue._nucleus.bind;
  if (bind == null) return null;
  if (bind.id.isEmpty) throw TissueNotSerializable('bind', tissue);
  return bind.id;
}

/// Encodes [context] through the pulse-context codec. [PulseContext]
/// instances use their native codec; every other [Context] snapshots its
/// resolved ontology dimensions. A dimension value that is not
/// JSON-encodable fails the encode with [TissueNotSerializable] on the
/// `'context'` field.
Map<String, dynamic> _encodeContext(Context context, Tissue<dynamic> tissue) {
  if (context is PulseContext) {
    return Map<String, dynamic>.from(PulseContextCodec.toJson(context));
  }
  if (identical(context, Context.system)) {
    return {'__system__': true};
  }
  final entries = <String, dynamic>{};
  for (final dimension in Ontology.values) {
    try {
      final value = context[dimension];
      if (value != null) {
        try {
          entries[dimension.name] = _jsonEncodeValue(value);
        } on StateError {
          throw TissueNotSerializable('context', tissue);
        }
      }
    } catch (_) {
      // A dimension that cannot be read is simply absent from the snapshot.
    }
  }
  return {'__context__': entries};
}

/// The capacity of [tissue] when it is a queue, or `null` otherwise
/// (`-1` is omitted from the wire).
int? _capacityOf(Tissue<dynamic> tissue, String kind) {
  if (kind != 'queue') return null;
  final nucleus = tissue._nucleus as TissueQueueNucleus<dynamic>;
  final capacity = nucleus.capacity;
  return capacity == TestTissue.unlimitedLength ? null : capacity;
}

/// The wire tag of [synapses].
String _synapsesTag(Synapses synapses) =>
    identical(synapses, Synapses.disabled) ? 'disabled' : 'enabled';

/// Encodes the elements of [tissue] per [kind].
///
/// Per-element failures are lenient per shape: one bad element does not
/// invalidate the whole collection.
dynamic _encodeElements(Tissue<dynamic> tissue, String kind,
    {required bool lenient, required List<String> skipped}) {
  Object? encode(Object? element) {
    try {
      return _encodeElement(element);
    } on StateError {
      throw TissueNotSerializable('elements', tissue);
    }
  }

  switch (kind) {
    case 'list':
    case 'set':
    case 'queue':
      final out = <dynamic>[];
      var anyDropped = false;
      for (final element in tissue) {
        try {
          out.add(encode(element));
        } on TissueNotSerializable {
          if (!lenient) rethrow;
          anyDropped = true;
        }
      }
      if (anyDropped) skipped.add('elements');
      return out;
    case 'map':
      final map = tissue as TissueMap;
      final allStringKeys = map.entries.every((e) => e.key is String);
      if (allStringKeys) {
        final out = <String, dynamic>{};
        var anyDropped = false;
        for (final entry in map.entries) {
          try {
            out['${entry.key}'] = encode(entry.value);
          } on TissueNotSerializable {
            if (!lenient) rethrow;
            anyDropped = true;
          }
        }
        if (anyDropped) skipped.add('elements');
        return out;
      }
      final out = <dynamic>[];
      var anyDropped = false;
      for (final entry in map.entries) {
        try {
          out.add([encode(entry.key), encode(entry.value)]);
        } on TissueNotSerializable {
          if (!lenient) rethrow;
          anyDropped = true;
        }
      }
      if (anyDropped) skipped.add('elements');
      return out;
    case 'value':
      try {
        return encode((tissue as TissueValue).value);
      } on TissueNotSerializable {
        if (!lenient) rethrow;
        skipped.add('elements');
        return null;
      }
  }
  throw TissueDecodeError('unknown tissue kind: $kind');
}

/// Encodes a single element: JSON primitives pass through, `Cell`s encode
/// as `{"__cell__": id}` references, everything else fails loudly.
Object? _encodeElement(Object? element) {
  if (element == null) return null;
  if (element is Cell) {
    if (element.id.isEmpty) {
      throw StateError('cell element with empty id: ${element.runtimeType}');
    }
    return {'__cell__': element.id};
  }
  return _jsonEncodeValue(element);
}

/// Encodes the nucleus `user` value. The decode-side positional wrapper
/// record `(value, skipped)` is unwrapped so decode → encode round-trips.
Object? _encodeUserValue(Object? user, Tissue<dynamic> tissue) {
  if (user == null) return null;
  if (user is (Object?, Object?)) {
    final dynamic record = user;
    try {
      final skipped = record.$2;
      if (skipped is Map &&
          (skipped.containsKey('wire') || skipped.containsKey('decode'))) {
        return _encodeUserValue(record.$1 as Object?, tissue);
      }
    } on NoSuchMethodError {
      // Not the codec wrapper — fall through to the loud failure.
    }
  }
  try {
    return _jsonEncodeValue(user);
  } on StateError {
    throw TissueNotSerializable('user', tissue);
  }
}

/// The wire `__skipped__` list carried by a decoded user wrapper, if any.
List<String> _wireSkippedOf(Object? user) {
  if (user is! (Object?, Object?)) return const [];
  final dynamic record = user;
  try {
    final skipped = record.$2;
    if (skipped is Map && skipped['wire'] is List) {
      return (skipped['wire'] as List).whereType<String>().toList();
    }
  } on NoSuchMethodError {
    return const [];
  }
  return const [];
}

/// Deep-encodes [value] into a JSON-safe tree; throws [StateError] for
/// unsupported types. Positional records (arity 1–3) encode as JSON arrays;
/// named records and larger records are not JSON-encodable.
Object? _jsonEncodeValue(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is List) {
    return [for (final item in value) _jsonEncodeValue(item)];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _jsonEncodeValue(entry.value),
    };
  }
  if (value is DateTime) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute,
            utc.second, utc.millisecond)
        .toIso8601String();
  }
  if (value is (Object?,)) {
    final dynamic record = value;
    return [_jsonEncodeValue(record.$1)];
  }
  if (value is (Object?, Object?)) {
    final dynamic record = value;
    return [_jsonEncodeValue(record.$1), _jsonEncodeValue(record.$2)];
  }
  if (value is (Object?, Object?, Object?)) {
    final dynamic record = value;
    return [
      _jsonEncodeValue(record.$1),
      _jsonEncodeValue(record.$2),
      _jsonEncodeValue(record.$3),
    ];
  }
  throw StateError('not JSON-encodable: ${value.runtimeType}');
}

// ─────────────────────────────────────────────────────────────────────────────
// Decoder internals
// ─────────────────────────────────────────────────────────────────────────────

/// Resolves a governance `{"tag": ...}` record to a [TestTissue].
TestTissue<dynamic, Tissue<dynamic>> _decodeRule(
  Object? tagJson,
  TissueGovernanceResolver? governanceResolver, {
  required bool lenient,
  required TestTissue<dynamic, Tissue<dynamic>> fallback,
  required List<String> skipped,
}) {
  if (tagJson is! Map) {
    throw TissueDecodeError('missing or malformed testRule', field: 'testRule');
  }
  final tag = tagJson['tag'];
  if (tag is! String) {
    throw TissueDecodeError('missing or malformed testRule tag',
        field: 'testRule');
  }
  switch (tag) {
    case 'allowAll':
      return TestTissue.allowAll;
    case 'readOnly':
      return TestTissue.readOnly;
  }
  final resolved =
      governanceResolver?.call(tag) ?? TissueGovernanceRegistry.lookup(tag);
  if (resolved != null) return resolved;
  if (lenient) {
    skipped.add('testRule');
    return fallback;
  }
  throw TissueDecodeError('unresolvable testRule tag: $tag', field: 'testRule');
}

/// Decodes a wire context record back to a [Context].
Context _decodeContext(Object? contextJson) {
  if (contextJson is! Map) {
    throw TissueDecodeError('missing or malformed context', field: 'context');
  }
  final map = Map<String, dynamic>.from(contextJson);
  if (map['__system__'] == true) return Context.system;
  // A PulseContextCodec payload carries a `lineage` key.
  if (map.containsKey('lineage')) {
    try {
      return PulseContextCodec.fromJson(Map<String, Object?>.from(map));
    } catch (e) {
      throw TissueDecodeError('malformed context', cause: e, field: 'context');
    }
  }
  final entries = map['__context__'];
  if (entries is Map) {
    final governance = <GovernanceEntry<Ontology, dynamic>>[];
    for (final entry in entries.entries) {
      Ontology<dynamic>? dimension;
      for (final candidate in Ontology.values) {
        if (candidate.name == entry.key) {
          dimension = candidate;
          break;
        }
      }
      if (dimension != null) {
        governance
            .add(GovernanceEntry<Ontology, dynamic>(dimension, entry.value));
      }
    }
    try {
      return Context.fromEntries(governance);
    } catch (e) {
      throw TissueDecodeError('malformed context', cause: e, field: 'context');
    }
  }
  throw TissueDecodeError('unsupported context encoding', field: 'context');
}

/// The [Container] for a wire container tag, validated against [kind].
Container _containerOfTag(Object? tag, String kind) {
  final Container resolved;
  if (tag == null) {
    resolved = _containerOfDefaultTag(kind);
  } else {
    if (tag is! String) {
      throw TissueDecodeError('malformed container tag', field: 'container');
    }
    resolved = switch (tag) {
      'growableTrue' => Container.growableTrue,
      'growableFalse' => Container.growableFalse,
      'set' => Container.set,
      'identitySet' => Container.identitySet,
      'map' => Container.map,
      'identityMap' => Container.identityMap,
      'queue' => Container.queue,
      'value' => Container.value,
      'finalValue' => Container.finalValue,
      _ => throw TissueDecodeError('unknown container tag: $tag',
          field: 'container'),
    };
  }
  final valid = switch (kind) {
    'list' => identical(resolved, Container.growableTrue) ||
        identical(resolved, Container.growableFalse),
    'set' => identical(resolved, Container.set) ||
        identical(resolved, Container.identitySet),
    'map' => identical(resolved, Container.map) ||
        identical(resolved, Container.identityMap),
    'queue' => identical(resolved, Container.queue),
    _ => identical(resolved, Container.value) ||
        identical(resolved, Container.finalValue),
  };
  if (!valid) {
    throw TissueDecodeError('container tag $tag does not match kind $kind',
        field: 'container');
  }
  return resolved;
}

/// The framework default [Container] for [kind].
Container _containerOfDefaultTag(String kind) => switch (kind) {
      'list' => Container.growableTrue,
      'set' => Container.set,
      'map' => Container.map,
      'queue' => Container.queue,
      _ => Container.value,
    };

/// Decodes the queue capacity; non-queue kinds ignore the field.
int _decodeCapacity(Object? capacityJson, String kind) {
  if (kind != 'queue') return TestTissue.unlimitedLength;
  if (capacityJson == null) return TestTissue.unlimitedLength;
  if (capacityJson is! int) {
    throw TissueDecodeError('malformed capacity: expected an int',
        field: 'capacity');
  }
  return capacityJson;
}

/// The [Synapses] for a wire tag; defaults to enabled.
Synapses _synapsesOf(Object? synapsesJson) {
  if (synapsesJson == null || synapsesJson == 'enabled') {
    return Synapses.enabled;
  }
  if (synapsesJson == 'disabled') return Synapses.disabled;
  throw TissueDecodeError('unknown synapses tag: $synapsesJson',
      field: 'synapses');
}

/// Decodes the shape-specific `elements` payload.
dynamic _decodeElements(Object? elementsJson, String kind,
    {required TissueCellResolver? cellResolver,
    required bool lenient,
    required List<String> skipped}) {
  switch (kind) {
    case 'list':
    case 'set':
    case 'queue':
      if (elementsJson == null) return <dynamic>[];
      if (elementsJson is! List) {
        throw TissueDecodeError('malformed elements for kind: $kind',
            field: 'elements');
      }
      return [
        for (final raw in elementsJson)
          _decodeElement(raw, kind,
              cellResolver: cellResolver, lenient: lenient, skipped: skipped),
      ];
    case 'map':
      if (elementsJson == null) return <MapEntry<dynamic, dynamic>>[];
      if (elementsJson is Map) {
        final out = <MapEntry<dynamic, dynamic>>[];
        for (final entry in elementsJson.entries) {
          try {
            out.add(MapEntry(
                entry.key as String,
                _decodeElement(entry.value, kind,
                    cellResolver: cellResolver,
                    lenient: lenient,
                    skipped: skipped)));
          } on TissueDecodeError {
            if (!lenient) rethrow;
            skipped.add('elements');
          }
        }
        return out;
      }
      if (elementsJson is List) {
        final out = <MapEntry<dynamic, dynamic>>[];
        for (final raw in elementsJson) {
          if (raw is! List || raw.length != 2) {
            throw TissueDecodeError('malformed map entry: expected [k, v]',
                field: 'elements');
          }
          try {
            final key = _decodeElement(raw[0], kind,
                cellResolver: cellResolver, lenient: lenient, skipped: skipped);
            final value = _decodeElement(raw[1], kind,
                cellResolver: cellResolver, lenient: lenient, skipped: skipped);
            out.add(MapEntry(key, value));
          } on TissueDecodeError {
            if (!lenient) rethrow;
            skipped.add('elements');
          }
        }
        return out;
      }
      throw TissueDecodeError('malformed elements for kind: map',
          field: 'elements');
    case 'value':
      return _decodeElement(elementsJson, kind,
          cellResolver: cellResolver, lenient: lenient, skipped: skipped);
  }
  throw TissueDecodeError('unknown tissue kind: $kind', field: 'kind');
}

/// Decodes one element. A `{"__cell__": id}` reference resolves through
/// [cellResolver]; an unresolved cell is `null` for List/Set/Queue/Value
/// (both modes) and throws [TissueDecodeError] for Map keys/values (strict
/// rethrows, lenient skips the whole entry).
dynamic _decodeElement(Object? raw, String kind,
    {required TissueCellResolver? cellResolver,
    required bool lenient,
    required List<String> skipped}) {
  if (raw is Map && raw.containsKey('__cell__')) {
    final id = raw['__cell__'];
    if (id is! String) {
      throw TissueDecodeError('malformed cell reference', field: 'elements');
    }
    final cell = cellResolver?.call(id);
    if (cell != null) return cell;
    if (kind == 'map') {
      throw TissueDecodeError('unresolved cell reference: $id',
          field: 'elements');
    }
    return null;
  }
  return _jsonDecodeValue(raw);
}

/// Deep-decodes a JSON tree into maps with string keys.
Object? _jsonDecodeValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _jsonDecodeValue(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _jsonDecodeValue(item)];
  }
  return value;
}

/// Instantiates the decoded tissue of the given [kind] with a fresh root
/// nucleus carrying the decoded semantic facts.
TissueBase<dynamic, dynamic, dynamic> _instantiate(String kind,
    {required dynamic elements,
    required Container container,
    required int capacity,
    required Synapses synapses,
    required TestTissue<dynamic, Tissue<dynamic>> testRule,
    required Context context,
    required Cell? bind,
    required Object? user,
    required List<String> wireSkipped,
    required List<String> decodeSkipped}) {
  final effectiveUser =
      _decodedUserRecord(user, wire: wireSkipped, decode: decodeSkipped);
  switch (kind) {
    case 'list':
      final nucleus = TissueListNucleus.create<dynamic, TissueList<dynamic>>(
          container: container,
          testRule: testRule as dynamic,
          context: context,
          synapses: synapses,
          bind: bind,
          user: effectiveUser as dynamic);
      return TissueList.fromNucleus(nucleus,
              elements: elements as List<dynamic>)
          as TissueBase<dynamic, dynamic, dynamic>;
    case 'set':
      final nucleus = TissueSetNucleus.create<dynamic, TissueSet<dynamic>>(
          container: container,
          testRule: testRule as dynamic,
          context: context,
          synapses: synapses,
          bind: bind,
          user: effectiveUser as dynamic);
      return TissueSet.fromNucleus(nucleus, elements: elements as List<dynamic>)
          as TissueBase<dynamic, dynamic, dynamic>;
    case 'map':
      final nucleus = TissueMapNucleus.create<dynamic, dynamic,
              TissueMap<dynamic, dynamic>>(
          container: container,
          testRule: testRule as dynamic,
          context: context,
          synapses: synapses,
          bind: bind,
          user: effectiveUser as dynamic);
      return TissueMap.fromNucleus(nucleus,
              entries: elements as List<MapEntry<dynamic, dynamic>>)
          as TissueBase<dynamic, dynamic, dynamic>;
    case 'queue':
      final nucleus = TissueQueueNucleus.create<dynamic, TissueQueue<dynamic>>(
          capacity: capacity,
          container: container,
          testRule: testRule as dynamic,
          context: context,
          synapses: synapses,
          bind: bind,
          user: effectiveUser as dynamic);
      return TissueQueue.fromNucleus(nucleus,
              elements: elements as List<dynamic>)
          as TissueBase<dynamic, dynamic, dynamic>;
    case 'value':
      final nucleus = TissueValueNucleus.create<dynamic, TissueValue<dynamic>>(
          container: container,
          testRule: testRule as dynamic,
          context: context,
          synapses: synapses,
          bind: bind,
          user: effectiveUser as dynamic);
      return TissueValue.fromNucleus(nucleus, value: elements)
          as TissueBase<dynamic, dynamic, dynamic>;
  }
  throw TissueDecodeError('unknown tissue kind: $kind', field: 'kind');
}

/// Builds the decoded user record. The decoded user value is wrapped as a
/// **positional** record so the nucleus's `Record?` user slot stays
/// structurally valid; skip metadata rides in the record's second field and
/// is readable as `user[1]` with `wire` and `decode` keys (and via
/// [TissueSkippedReport.skippedReport]).
Record? _decodedUserRecord(Object? user,
    {required List<String> wire, required List<String> decode}) {
  if (user == null && wire.isEmpty && decode.isEmpty) return null;
  final skipped = <String, dynamic>{
    'wire': wire,
    'decode': [
      for (final field in decode)
        {'field': field, 'reason': 'unresolved_reference'},
    ],
  };
  return (user, skipped);
}

/// Unwraps the decode-side positional user wrapper, returning the plain
/// decoded value (used when an override supersedes the skip metadata).
Object? _unwrapDecodedUser(Object? user) {
  if (user is! (Object?, Object?)) return user;
  final dynamic record = user;
  try {
    final skipped = record.$2;
    if (skipped is Map &&
        (skipped.containsKey('wire') || skipped.containsKey('decode'))) {
      return record.$1 as Object?;
    }
  } on NoSuchMethodError {
    return user;
  }
  return user;
}

/// The wire synapses tag of [json], or enabled.
Synapses _synapsesFromJson(Map<String, dynamic> json) {
  final config = json['config'];
  if (config is Map && config['synapses'] == 'disabled') {
    return Synapses.disabled;
  }
  return Synapses.enabled;
}

/// The skip metadata recorded on a decoded tissue.
///
/// ### When to use
/// Inspect [TissueSkippedReport.skippedReport] after a lenient decode to
/// learn exactly what the encoder substituted (`wire`) and what this
/// decoder could not resolve (`decode`):
///
/// ```dart
/// final tissue = TissueList.fromJson(json, lenient: true);
/// print(tissue.skippedReport); // {'wire': [...], 'decode': [...]}
/// ```
///
/// ### Contract
/// The report is present only when a skip occurred. `wire` holds the field
/// categories from the input JSON's `__skipped__` list (a lenient encode);
/// `decode` holds the reference gaps resolved leniently by this decode. The
/// same information rides on the tissue's `user` record as the second
/// positional field.
extension TissueSkippedReport<E> on Tissue<E> {
  /// The `{'wire': [...], 'decode': [...]}` skip report, or `null` when no
  /// skip occurred.
  Map<String, dynamic>? get skippedReport {
    final user = _nucleus.user;
    if (user is (Object?, Object?)) {
      final dynamic record = user;
      try {
        final skipped = record.$2;
        if (skipped is Map &&
            (skipped.containsKey('wire') || skipped.containsKey('decode'))) {
          return Map<String, dynamic>.from(skipped);
        }
      } on NoSuchMethodError {
        return null;
      }
    }
    return null;
  }
}
