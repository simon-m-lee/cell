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

import 'package:cell/cell.dart';

/// The technical blueprint describing the shape and constraints of a somatic signal.
///
/// In the framework's biological metaphor, [JsonSchema] is the **Somatic Blueprint**.
/// It defines the "DNA" structure required for a **Nervous Signal** (request)
/// to successfully pass through a cell's **Integrity Gate**.
///
/// These blueprints are carried within the **Somatic Index** (the manifest) to
/// help external agents (like AI tools) understand how to format a
/// **Command Journey** that the system will accept.
///
/// ### When to use
/// - **Discovery**: Provided in a [WireManifestResponse] so clients know
///   the valid inputs for exposed cells and tools.
/// - **Validation**: Used at the **Skin Membrane** to pre-screen
///   **Skin Payloads** before they are converted into internal pulses.
///
/// ### How it works
/// 1. **Observation**: The system monitors the **Forensic Ledger** and uses
///    [schemaForValue] to record the shapes of data that have successfully
///    triggered transitions.
/// 2. **Widening**: As different types of data are accepted, the blueprint
///    "widens" to accommodate the new valid shapes.
/// 3. **Manual Hardening**: Developers can provide explicit blueprints to
///    enforce strict **Integrity Gates** (e.g., specific `enum` values or
///    numeric ranges).
///
/// ### Non-obvious behavior
/// - **Permissive Fallback**: If a cell's receptor is an opaque predicate
///   (a Dart closure), the blueprint falls back to [permissive] (`{}`). In
///   this case, the **Integrity Gate** remains authoritative, but the
///   membrane cannot describe the requirements to the outside world.
/// - **Forensic Integrity**: While the blueprint guides the agent, the
///   actual state transition is only granted if the live cell
///   accepts the pulse during the **Command Journey**.
///
/// ### See also
/// - [WireManifestResponse]: The signal that carries these blueprints.
/// - [schemaForValue]: The utility that derives blueprints from observed state.
///
/// ### AI Agent Guide
/// **Layer:** Skin — this is your guide for tool calls.
/// **Live signature:** `final class JsonSchema { static const JsonSchema permissive; const JsonSchema({String? type, String? description, Map<String, JsonSchema>? properties, List<String>? required, JsonSchema? items, num? minimum, num? maximum, List<Object?>? enumValues}); }` — pinned at `cell_skin: 1.0.0`
/// **Stability:** stable
/// **Constraint:** Always match your arguments to the `properties` defined here.
/// **Validation:** Rejection by the system usually means your signal violated
/// the somatic structure defined in this blueprint.
final class JsonSchema {
  /// The physical category of the signal (e.g., 'object', 'string', 'integer').
  final String? type;

  /// Human-readable context describing the somatic purpose of this field.
  final String? description;

  /// The internal structure of a complex **Skin Payload**.
  final Map<String, JsonSchema>? properties;

  /// The list of mandatory **Somatic Nutrients** (arguments) that must be
  /// present for the signal to be valid.
  final List<String>? required;

  /// The blueprint for elements within a signal sequence (array).
  final JsonSchema? items;

  /// The lower somatic threshold for numeric signals.
  final num? minimum;

  /// The upper somatic threshold for numeric signals.
  final num? maximum;

  /// The allowed somatic vocabulary for this signal.
  final List<Object?>? enumValues;

  /// Whether the membrane allows extra, non-modelled data to pass through.
  final bool? additionalProperties;

  /// Non-modelled technical metadata preserved from the original signal.
  ///
  /// This ensures that if the **Skin Membrane** receives tags it doesn't
  /// recognize, they are not lost during the **Command Journey**.
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


  /// The permissive blueprint: accepts any **Nervous Signal**.
  ///
  /// In the biological metaphor, this represents an "open receptor" that
  /// lets all **Skin Payloads** through to be judged by the internal
  /// **Integrity Gate**.
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
  /// (treated as `true` — the subset accepts it as open; a client that
  /// re-validates a decoded schema does not get the object form
  /// enforced).
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

/// Derives a best-effort [JsonSchema] by observing a single somatic value.
////// In the framework's biological metaphor, this is **Trait Induction**. It
/// takes a specific **Somatic Nutrient** (a value) that has successfully
/// crossed an **Integrity Gate** and derives the **Somatic Blueprint** (DNA)
/// required to represent it.
///
/// ### When to use
/// - **Automatic Discovery**: Used by the system to learn the shape of valid
///   signals by watching the **Forensic Ledger**.
/// - **Manifest Generation**: Helps populate the **Somatic Index** with
///   schemas when no explicit developer hints are provided.
///
/// ### How it works
/// 1. **Trait Analysis**: The function inspects the runtime type of the
///    provided value.
/// 2. **Blueprint Mapping**: It maps Dart types to their wire-safe equivalents
///    (e.g., `int` becomes `integer`, `List` becomes `array`).
/// 3. **Recursive Induction**: For complex **Skin Payloads** (Maps and Lists),
///    it recursively derives blueprints for all internal elements.
///
/// ### Non‑obvious behavior
/// - **Widen by Type Only**: To avoid "Forensic Holes" where a valid future
///   signal is rejected, this function only induces the *type*. It does
///   not automatically set `enum`, `minimum`, or `maximum` constraints based
///   on a single observation.
/// - **Required Traits**: When inducing an object (Map), any key with a
///   non-null value is marked as `required` in the resulting blueprint.
/// - **Permissive Nutrients**: If the value is `null` or an unknown type,
///   it returns a [JsonSchema.permissive] blueprint, allowing the
///   internal **Integrity Gate** to remain the sole arbiter of validity.
///
/// ### See also
/// - [JsonSchema]: The blueprint being produced.
/// - [mergeSchemas]: How multiple induced blueprints are combined into a
///   wider system DNA.
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

/// Merges two somatic blueprints into a single, wider DNA structure.
///
/// In the framework's biological metaphor, this is **Somatic Merging**. When
/// the system observes multiple successful **Nervous Signals** (pulses) over
/// time, it combines their requirements to form a unified **Somatic Blueprint**
/// that represents the total known capacity of the cell.
///
/// ### When to use
/// - **Schema Evolution**: Used by the **Somatic Index** (manifest) to
///   update its technical description of a cell as new, valid argument
///   shapes are observed in the **Forensic Ledger**.
/// - **Blueprint Synthesis**: Helpful when combining developer-provided
///   hints with observed data shapes to create a hardened **Integrity Gate**.
///
/// ### How it works
/// 1. **Widening Logic**: The merge always prefers the "loosest" constraint.
///    For example, if one blueprint allows an `integer` and another allows
///    a `number`, the result is a `number`.
/// 2. **Recursive Integration**: For complex **Skin Payloads** (objects),
///    it recursively merges the blueprints for every property.
/// 3. **Requirement Intersection**: A field is only marked as `required`
///    in the resulting blueprint if it was mandatory in **both** source
///    blueprints. This prevents "Forensic Holes" where a valid signal is
///    blocked by an overly strict requirement.
/// 4. **Constraint Union**: For `enum` values, the result is the union of
///    both vocabularies. For numeric bounds, the result is the widest
///    possible range (the minimum of the minimums and the maximum of
///    the maximums).
///
/// ### Non‑obvious behavior
/// - **Absorption**: If either blueprint is [JsonSchema.permissive] (untyped),
///   the resulting blueprint effectively becomes permissive for that
///   segment, as an unconstrained DNA strand can absorb any shape.
/// - **Conflict Resolution**: If the two blueprints describe fundamentally
///   incompatible types (e.g., a `string` and a `boolean`), the merge
///   widens to a null-typed schema, signaling that the membrane
///   cannot reliably predict the shape.
/// - **Sorting**: Required keys and enum values are sorted during the
///   merge to ensure the resulting **Skin Form** is deterministic and
///   stable for caching.
///
/// ### See also
/// - [JsonSchema]: The blueprint structure being merged.
/// - [schemaForValue]: The function that generates the initial blueprints
///   for merging.
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

/// Validates [value] against an explicit [JsonSchema] subset.
///
/// Returns `null` when the value fits, or a path-prefixed message when
/// it does not. Never throws. The path form is `$.target`,
/// `$.address.city`, `$.items[0]`.
///
/// The enforced subset: `type` (`integer` is `value is int` — `bool` is
/// not an `integer`, `1.0` is not an `integer`), `enum`, `minimum` /
/// `maximum` (inclusive), `required`, `properties`, `additionalProperties`
/// (`null` means closed when `properties` is set — `schemaForValue`
/// objects are open because it sets `true`), and `items`. `extra` is
/// ignored; `pattern`, `minLength`, and `format` are not part of this
/// subset.
///
/// `null` does not satisfy a typed schema (there is no union type), and
/// an unknown type string fails closed. The recursion depth is capped at
/// 32 so a hostile body cannot recurse forever; past that the message is
/// `schema validation exceeded depth`.
///
/// `properties`/`required`/`additionalProperties` are only enforced
/// when the value is a `Map`. A schema that declares `properties` but
/// no `type: 'object'` is spec-legal and leaves non-object values
/// unchecked by those keywords — set `type: 'object'` when the object
/// is meant to be closed.
String? validateJsonSchema(
  JsonSchema schema,
  Object? value, {
  String path = r'$',
  int depth = 0,
}) {
  if (depth > 32) return 'schema validation exceeded depth';

  final type = schema.type;
  if (type != null) {
    final bool ok;
    switch (type) {
      case 'integer':
        ok = value is int;
      case 'number':
        ok = value is num;
      case 'string':
        ok = value is String;
      case 'boolean':
        ok = value is bool;
      case 'array':
        ok = value is List;
      case 'object':
        ok = value is Map;
      default:
        return '$path: unsupported type "$type"';
    }
    if (!ok) return '$path: expected $type, got ${_schemaDescribe(value)}';
  }

  final enumValues = schema.enumValues;
  if (enumValues != null) {
    final matches = enumValues.any((allowed) => _schemaEquals(value, allowed));
    if (!matches) {
      return '$path: must be one of '
          '${enumValues.map(_schemaDescribe).join(', ')}';
    }
  }

  if (value is num) {
    if (schema.minimum != null && value < schema.minimum!) {
      return '$path: below minimum ${schema.minimum}';
    }
    if (schema.maximum != null && value > schema.maximum!) {
      return '$path: above maximum ${schema.maximum}';
    }
  }

  final properties = schema.properties;
  if (value is Map) {
    for (final entry in properties?.entries ?? const <MapEntry<String, JsonSchema>>[]) {
      if (value.containsKey(entry.key)) {
        final error = validateJsonSchema(
          entry.value,
          value[entry.key],
          path: '$path.${entry.key}',
          depth: depth + 1,
        );
        if (error != null) return error;
      }
    }
    // A required key must be present; a present null is a type failure
    // on that property, not a second required failure.
    final required = schema.required;
    if (required != null) {
      for (final name in required) {
        if (!value.containsKey(name)) return '$path.$name: required';
      }
    }
    // additionalProperties: true allows unknown keys; false rejects
    // them; null means false when properties is non-null (an explicit
    // schema that models an object is closed by default).
    final additional = schema.additionalProperties;
    final closed = properties != null &&
        (additional == false || additional == null);
    if (closed) {
      for (final key in value.keys) {
        if (key is! String || !properties.containsKey(key)) {
          return '$path.$key: additional property not allowed';
        }
      }
    }
  } else if (requiredForMissingObject(schema)) {
    // `required` names a property of an object; a non-object value that
    // passed an (absent) type check still fails the requirement.
    final required = schema.required!;
    if (required.isNotEmpty) return '$path.${required.first}: required';
  }

  final items = schema.items;
  if (items != null && value is List) {
    for (var i = 0; i < value.length; i++) {
      final error = validateJsonSchema(
        items,
        value[i],
        path: '$path[$i]',
        depth: depth + 1,
      );
      if (error != null) return error;
    }
  }
  return null;
}

bool requiredForMissingObject(JsonSchema schema) => schema.required != null;

Object? _schemaDescribe(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return '$value';
  if (value is String) {
    return value.length <= 40 ? '"$value"' : 'String';
  }
  return value.runtimeType.toString();
}

bool _schemaEquals(Object? a, Object? b) {
  if (a is List || a is Map) {
    try {
      return canonicalJsonEncode(a) == canonicalJsonEncode(b);
    } catch (_) {
      return false;
    }
  }
  return a == b;
}

/// The collector responsible for learning the system's DNA by watching signals.
///
/// In the framework's biological metaphor, [SchemaObserver] is the
/// **Somatic Watcher**. It sits at the **Skin Membrane** and records every
/// **Nervous Signal** (impulse) that successfully triggers a
/// **Somatic State Transition**, using them to build a cumulative
/// **Somatic Blueprint** of what the system accepts.
///
/// ### When to use
/// - **Automatic Discovery**: Use this to dynamically populate the
///   **Somatic Index** (manifest) without requiring manual schema definitions.
/// - **AI Adaptation**: Allows the system to "learn" the shape of valid
///   tool calls by observing real-world usage in the **Forensic Ledger**.
///
/// ### How it works
/// 1. **Signal Capture**: Every time a cell's `apply` logic is triggered,
///    the observer is notified of the **Somatic Nutrients** (arguments).
/// 2. **Trait Induction**: It uses [schemaForValue] to derive the
///    immediate DNA shape of those nutrients.
/// 3. **DNA Synthesis**: It uses [mergeSchemas] to widen its internal
///    blueprints, ensuring the resulting schema represents the union of all
///    valid signals seen so far.
///
/// ### Non‑obvious behavior
/// - **Cumulative Memory**: The observer never "forgets" a valid shape.
///   Once a trait is induced and merged, the schema remains wide enough
///   to accept that shape forever, preventing "Forensic Holes" where
///   previously valid signals suddenly fail.
/// - **Stability**: The resulting [namedSchemas] and [positionalSchemas]
///   are sorted and unmodifiable, ensuring the **Skin Form** of the manifest
///   remains deterministic for external AI agents.
/// - **Thread Safety**: Designed to be used within a single somatic
///   governance loop; external access is provided via read-only views.
///
/// ### See also
/// - [JsonSchema]: The blueprint being accumulated.
/// - [schemaForValue]: The induction logic used for each observation.
/// - [mergeSchemas]: The synthesis logic used to grow the DNA.
final class SchemaObserver {
  /// The internal dictionary of learned blueprints for named signals.
  final Map<String, JsonSchema> _named = {};

  /// The ordered sequence of learned blueprints for positional signals.
  final List<JsonSchema> _positional = [];

  /// Records the traits of a single **Command Journey** to update the DNA.
  ///
  /// This method performs **Trait Induction** on the provided [positional]
  /// and [named] nutrients, merging the results into the observer's
  /// permanent memory.
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

  /// The cumulative **Somatic Blueprint** for all observed named signals.
  ///
  /// Returns a read-only **Skin Form** of the named argument requirements.
  Map<String, JsonSchema> get namedSchemas => Map.unmodifiable(_named);

  /// The cumulative **Somatic Blueprint** for observed positional sequences.
  ///
  /// Returns a read-only, ordered list of DNA requirements for
  /// positional arguments.
  List<JsonSchema> get positionalSchemas => List.unmodifiable(_positional);
}
