// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

void main() {
  test('schema derivation widens to types, never narrows to one value', () {
    expect(schemaForValue(3).type, 'integer');
    expect(schemaForValue(3).minimum, isNull,
        reason: 'a single observation must not pin minimum == maximum');
    expect(schemaForValue('a').enumValues, isNull,
        reason: 'a single observation must not enumerate one value');
    expect(schemaForValue([1, 2]).items?.type, 'integer');
    expect(schemaForValue({'x': 1}).properties?['x']?.type, 'integer');
    expect(schemaForValue(null).type, isNull);
  });

  test('merging widens instead of narrows', () {
    final a = schemaForValue({'x': 1});
    final b = schemaForValue({'y': 's'});
    final merged = mergeSchemas(a, b);
    expect(merged.type, 'object');
    expect(merged.properties, contains('x'));
    expect(merged.properties, contains('y'));
    // Required keys must take the *intersection*: x is required by a
    // but optional in b, so the union must not require it.
    expect(merged.required, isNull);
  });

  test('merging same-key objects intersects required keys', () {
    final a = schemaForValue({'x': 1, 'y': 2});
    final b = schemaForValue({'x': 's', 'y': 't'});
    final merged = mergeSchemas(a, b);
    expect(merged.required, containsAll(['x', 'y']));
    expect(merged.properties?['x']?.type, isNull,
        reason: 'integer ∪ string is unconstrained');
  });

  test('merging different types falls back to permissive', () {
    expect(mergeSchemas(schemaForValue(1), schemaForValue('a')).type, isNull);
  });

  test('integer merged with number widens to number', () {
    final merged = mergeSchemas(
        const JsonSchema(type: 'integer'), const JsonSchema(type: 'number'));
    expect(merged.type, 'number');
  });

  test('an absent bound is unconstrained, never inherited', () {
    final a = const JsonSchema(type: 'number', minimum: 1);
    final b = const JsonSchema(type: 'number', maximum: 5);
    final merged = mergeSchemas(a, b);
    expect(merged.minimum, isNull);
    expect(merged.maximum, isNull);
    final both = mergeSchemas(
        const JsonSchema(type: 'number', minimum: 1, maximum: 3),
        const JsonSchema(type: 'number', minimum: 2, maximum: 5));
    expect(both.minimum, 1);
    expect(both.maximum, 5);
  });

  test('SchemaObserver accumulates shapes per argument', () {
    final observer = SchemaObserver()
      ..observe(positional: [1], named: {'mode': 'eco'})
      ..observe(positional: [2], named: {'mode': 'boost', 'dry': true});
    expect(observer.positionalSchemas.single.type, 'integer');
    expect(observer.positionalSchemas.single.minimum, isNull);
    expect(observer.namedSchemas['mode']?.type, 'string');
    expect(observer.namedSchemas['mode']?.enumValues, isNull);
    expect(observer.namedSchemas['dry']?.type, 'boolean');
  });

  test('JsonSchema JSON round-trip preserves keywords', () {
    const schema = JsonSchema(
      type: 'object',
      description: 'd',
      properties: {
        'target': JsonSchema(type: 'integer', minimum: 16, maximum: 26),
      },
      required: ['target'],
      additionalProperties: false,
    );
    final decoded = JsonSchema.fromJson(schema.toJson());
    expect(decoded.type, 'object');
    expect(decoded.description, 'd');
    expect(decoded.required, ['target']);
    expect(decoded.properties?['target']?.minimum, 16);
    expect(decoded.additionalProperties, isFalse);
  });

  test('JsonSchema.fromJson tolerates array types and schema objects', () {
    final decoded = JsonSchema.fromJson({
      'type': ['string', 'null'],
      'additionalProperties': {'type': 'string'},
      'x-extra': 1,
    });
    expect(decoded.type, 'string');
    expect(decoded.additionalProperties, isTrue);
    expect(decoded.extra, {'x-extra': 1});
    expect(decoded.toJson().containsKey('x-extra'), isTrue);
    expect(decoded.toJson()['type'], 'string',
        reason: 'extra keywords must not re-spread over modelled ones');
  });
}
