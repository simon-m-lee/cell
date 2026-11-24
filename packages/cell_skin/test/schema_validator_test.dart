// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// `validateJsonSchema`, directly.
library;

import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

void main() {
  test('a permissive schema accepts anything', () {
    expect(validateJsonSchema(JsonSchema.permissive, null), isNull);
    expect(validateJsonSchema(JsonSchema.permissive, 'x'), isNull);
    expect(validateJsonSchema(JsonSchema.permissive, {'a': 1}), isNull);
  });

  test('integer is exactly is int', () {
    const schema = JsonSchema(type: 'integer');
    expect(validateJsonSchema(schema, 1), isNull);
    expect(validateJsonSchema(schema, true), isNotNull);
    expect(validateJsonSchema(schema, 1.0), isNotNull);
    expect(validateJsonSchema(schema, null), contains('null'));
    expect(validateJsonSchema(schema, '1'), isNotNull);
  });

  test('minimum and maximum are inclusive', () {
    const schema = JsonSchema(type: 'integer', minimum: 16);
    expect(validateJsonSchema(schema, 15), isNotNull);
    expect(validateJsonSchema(schema, 16), isNull);
  });

  test('enum allows exactly the listed scalars', () {
    const schema = JsonSchema(type: 'string', enumValues: ['eco', 'heat']);
    expect(validateJsonSchema(schema, 'off'), isNotNull);
    expect(validateJsonSchema(schema, 'eco'), isNull);
  });

  test('a closed object enforces required, null, and extras', () {
    const schema = JsonSchema(
      type: 'object',
      properties: {'target': JsonSchema(type: 'integer')},
      required: ['target'],
    );
    expect(validateJsonSchema(schema, {}), contains(r'$.target: required'));
    expect(validateJsonSchema(schema, {'target': null}), isNotNull);
    expect(validateJsonSchema(schema, {'target': 19, 'extra': true}),
        contains('additional property'));
    expect(validateJsonSchema(schema, {'target': 19}), isNull);
  });

  test('a nested required failure carries the full path', () {
    const schema = JsonSchema(
      type: 'object',
      properties: {
        'address': JsonSchema(
          type: 'object',
          properties: {'city': JsonSchema(type: 'string')},
          required: ['city'],
        ),
      },
      required: ['address'],
    );
    final error = validateJsonSchema(schema, {
      'address': {'street': 'x'},
    });
    expect(error, contains(r'$.address.city'));
  });

  test('items validates every element', () {
    const schema = JsonSchema(
      type: 'array',
      items: JsonSchema(type: 'integer'),
    );
    expect(validateJsonSchema(schema, [1, true]), isNotNull);
    expect(validateJsonSchema(schema, [1, 2]), isNull);
  });

  test('explicit additionalProperties true allows unknown keys', () {
    const schema = JsonSchema(
      type: 'object',
      properties: {'target': JsonSchema(type: 'integer')},
      additionalProperties: true,
    );
    expect(validateJsonSchema(schema, {'target': 19, 'extra': true}), isNull);
  });

  test('a 33-deep map hits the depth cap', () {
    JsonSchema schema = const JsonSchema(type: 'integer');
    for (var i = 0; i < 40; i++) {
      schema = JsonSchema(type: 'object', properties: {'next': schema});
    }
    var value = <String, Object?>{'leaf': 1};
    for (var i = 0; i < 40; i++) {
      value = <String, Object?>{'next': value};
    }
    expect(
      validateJsonSchema(schema, value),
      'schema validation exceeded depth',
    );
  });

  test('an unknown type string fails closed', () {
    const schema = JsonSchema(type: 'weird');
    expect(validateJsonSchema(schema, 'anything'),
        contains('unsupported type'));
  });
}
