// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// JSON Schema models for the skin's tool catalogue.
///
/// `TestCell` predicates are Dart closures and cannot be translated to
/// JSON Schema in general. The skin therefore keeps the live gate
/// authoritative and derives schemas from two honest sources:
///
/// 1. **Observed argument shapes** — the values that actually crossed
///    the ledger, collected per binding; the schema over-approximates
///    (any observed type widens the schema).
/// 2. **Explicit developer hints** — a binding author can supply a
///    hand-written [JsonSchema] (min/max, enum, …), which always wins.
///
/// An opaque predicate falls back to the permissive `{}` schema: the
/// agent can reason about shape, and the real `TestCell` still rejects
/// what the schema cannot express.
/// {@category Features}
library;

/// A small JSON Schema subset sufficient for MCP `tools/list` and REST
/// clients. Unknown keywords are preserved in [extra].
///
/// ### When to use
/// * Declaring a binding's `argumentSchema` hint, or describing the
///   observed value shape in the manifest.
///
/// ### How it works
/// [schemaForValue] derives a **widening** schema from a live value:
/// type-only inference (no single-value `enum` or
/// `minimum == maximum`), `required` as the intersection across
/// objects, absent bounds as unconstrained, and array items merged
/// across every element.
///
/// ### Non-obvious
/// [JsonSchema.fromJson] is lenient (array `type`, schema-object
/// `additionalProperties`) and strips known keys from [extra] so a raw
/// input map can never re-spread over modelled fields.
///
/// ### See also
/// [mergeSchemas], [SkinBinding.argumentSchema].
final class JsonSchema {
  final String? type;
  final String? description;
  final Map<String, JsonSchema>? properties;
  final List<String>? required;
  final JsonSchema? items;
  final num? minimum;
  final num? maximum;
  final List<Object?>? enumValues;
  final bool? additionalProperties;
  final Map<String, Object?> extra;

  const JsonSchema({
    this.type,
    this.description,
    this.properties,
    this.required,
    this.items,
    this.minimum,
    this.maximum,
    this.enumValues,
    this.additionalProperties,
    this.extra = const {},
  });

  /// The permissive schema: accepts anything.
  static const permissive = JsonSchema();

  static const _knownKeys = {
    'type',
    'description',
    'properties',
    'required',
    'items',
    'minimum',
    'maximum',
    'enum',
    'additionalProperties',
  };

  Map<String, Object?> toJson() => {
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (properties != null)
          'properties': properties!.map((k, v) => MapEntry(k, v.toJson())),
        if (required != null) 'required': required,
        if (items != null) 'items': items!.toJson(),
        if (minimum != null) 'minimum': minimum,
        if (maximum != null) 'maximum': maximum,
        if (enumValues != null) 'enum': enumValues,
        if (additionalProperties != null)
          'additionalProperties': additionalProperties,
        ...extra,
      };

  /// Decodes a [JsonSchema] from its JSON form. Lenient where the spec
  /// is richer than this subset: `type` may be an array (the first
  /// entry wins) and `additionalProperties` may be a schema object
  /// (treated as `true`).
  factory JsonSchema.fromJson(Map<String, Object?> json) {
    final rawType = json['type'];
    final type = switch (rawType) {
      String value => value,
      List value when value.isNotEmpty => value.first as String?,
      _ => null,
    };
    final rawAdditional = json['additionalProperties'];
    final additionalProperties = switch (rawAdditional) {
      bool value => value,
      Map<dynamic, dynamic>() => true,
      _ => null,
    };
    final propertiesJson = json['properties'];
    return JsonSchema(
      type: type,
      description: json['description'] as String?,
      properties: propertiesJson is Map
          ? propertiesJson.map((k, v) => MapEntry(k as String,
              JsonSchema.fromJson((v as Map).cast<String, Object?>())))
          : null,
      required: (json['required'] as List?)?.cast<String>(),
      items: json['items'] is Map
          ? JsonSchema.fromJson((json['items'] as Map).cast<String, Object?>())
          : null,
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      enumValues: (json['enum'] as List?)?.cast<Object?>(),
      additionalProperties: additionalProperties,
      // Known keywords are modelled; unknown ones are preserved
      // verbatim — they must not re-spread over the modelled fields.
      extra: Map.unmodifiable({
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value
      }),
    );
  }

  @override
  String toString() => toJson().toString();
}

/// Derives a best-effort [JsonSchema] for a single observed value.
///
/// A single observation widens to its *type only* — no `enum`, no
/// `minimum == maximum` — so the schema never rejects the next
/// legitimate observation of the same type.
JsonSchema schemaForValue(Object? value) {
  if (value == null) return const JsonSchema();
  if (value is num) {
    return JsonSchema(type: value is int ? 'integer' : 'number');
  }
  if (value is bool) return const JsonSchema(type: 'boolean');
  if (value is String) return const JsonSchema(type: 'string');
  if (value is List) {
    if (value.isEmpty) return const JsonSchema(type: 'array');
    // Union of every element's schema, not just the first element's.
    var items = schemaForValue(value.first);
    for (final element in value.skip(1)) {
      items = mergeSchemas(items, schemaForValue(element));
    }
    return JsonSchema(type: 'array', items: items);
  }
  if (value is Map) {
    final properties = <String, JsonSchema>{};
    final required = <String>[];
    value.forEach((key, v) {
      if (key is String) {
        properties[key] = schemaForValue(v);
        if (v != null) required.add(key);
      }
    });
    return JsonSchema(
      type: 'object',
      properties: properties,
      required: required,
      additionalProperties: true,
    );
  }
  return const JsonSchema();
}

/// Merges observed schemas by widening: the union of two shapes is the
/// looser of the two at every keyword. An absent constraint means
/// *unconstrained* — it never inherits the other side's constraint.
JsonSchema mergeSchemas(JsonSchema a, JsonSchema b) {
  // An unconstrained type absorbs everything.
  if (a.type == null || b.type == null) {
    return JsonSchema(description: a.description ?? b.description);
  }
  final type = switch ((a.type!, b.type!)) {
    ('integer', 'number') || ('number', 'integer') => 'number',
    (final x, final y) when x == y => x,
    _ => null,
  };
  if (type == null) {
    return JsonSchema(description: a.description ?? b.description);
  }
  final properties = <String, JsonSchema>{};
  if (a.properties != null) properties.addAll(a.properties!);
  if (b.properties != null) {
    b.properties!.forEach((key, schema) {
      properties[key] = properties.containsKey(key)
          ? mergeSchemas(properties[key]!, schema)
          : schema;
    });
  }
  // The union requires the *intersection* of required keys: a key is
  // only required when both observations require it.
  final required = <String>{
    if (a.required != null && b.required != null)
      ...a.required!.where(b.required!.contains),
  };
  return JsonSchema(
    type: type,
    description: a.description ?? b.description,
    properties: properties.isEmpty ? null : properties,
    required: required.isEmpty ? null : (required.toList()..sort()),
    items: a.items == null || b.items == null
        ? null
        : mergeSchemas(a.items!, b.items!),
    // Widening: the union's minimum is the smaller bound and its
    // maximum the larger — but an absent bound is unconstrained.
    minimum: a.minimum == null || b.minimum == null
        ? null
        : (a.minimum! < b.minimum! ? a.minimum : b.minimum),
    maximum: a.maximum == null || b.maximum == null
        ? null
        : (a.maximum! > b.maximum! ? a.maximum : b.maximum),
    enumValues: a.enumValues == null || b.enumValues == null
        ? null
        : {...a.enumValues!, ...b.enumValues!}.toList(),
    additionalProperties:
        a.additionalProperties == null || b.additionalProperties == null
            ? null
            : (a.additionalProperties! || b.additionalProperties!),
  );
}

/// Accumulates observed argument shapes per named argument into schemas.
final class SchemaObserver {
  final Map<String, JsonSchema> _named = {};
  final List<JsonSchema> _positional = [];

  /// Records one observed call.
  void observe({List<Object?>? positional, Map<String, Object?>? named}) {
    if (positional != null) {
      for (var i = 0; i < positional.length; i++) {
        final schema = schemaForValue(positional[i]);
        if (_positional.length <= i) {
          _positional.add(schema);
        } else {
          _positional[i] = mergeSchemas(_positional[i], schema);
        }
      }
    }
    named?.forEach((key, value) {
      final schema = schemaForValue(value);
      _named[key] =
          _named.containsKey(key) ? mergeSchemas(_named[key]!, schema) : schema;
    });
  }

  /// The merged schema for observed named arguments.
  Map<String, JsonSchema> get namedSchemas => Map.unmodifiable(_named);

  /// The merged schema for observed positional arguments, in order.
  List<JsonSchema> get positionalSchemas => List.unmodifiable(_positional);
}
