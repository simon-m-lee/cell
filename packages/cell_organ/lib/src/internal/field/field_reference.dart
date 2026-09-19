// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

class FieldReference<H extends One, V> {
  final Type classType;

  final Symbol name;

  final TypeValue<V> typeValue;

  final bool isSetter;

  final bool isRelation;

  final Function instantiator;

  final Iterable metadata;

  const FieldReference(
      {required this.classType,
      required this.name,
      required this.typeValue,
      required this.isSetter,
      required this.isRelation,
      required this.instantiator,
      required this.metadata});

  V? value(dynamic value) {
    // If the value is already of the correct type or is null, return it directly.
    if (value is V) return value;
    if (value == null)
      return null; // Explicitly handle null input after type check

    // The `ignore_for_file: type_literal_in_constant_pattern` is used because
    // this switch statement uses type literals (e.g., `String`, `int`) in
    // case patterns, which is a feature enabled by an experiment or newer Dart versions.
    // ignore_for_file: type_literal_in_constant_pattern
    switch (typeValue.type) {
      // Switch on the target field type (V)
      case String:
        if (value is DateTime) return value.toIso8601String() as V;
        // Extract string from symbol: Symbol('foo') -> "Symbol(\"foo\")" -> "foo"
        if (value is Symbol) return value.toString().split('"')[1] as V;
        return value.toString() as V; // Fallback to ensure it's a string
      case int:
        if (value is String) return int.tryParse(value) as V?;
        if (value is double) return value.toInt() as V;
        if (value is num)
          return value.toInt() as V; // Handles other num subtypes
        break; // If no specific conversion, will fall through to null
      case double:
        if (value is String) return double.tryParse(value) as V?;
        if (value is int) return value.toDouble() as V;
        if (value is num) return value.toDouble() as V;
        break;
      case num:
        // This case is tricky as `num` is abstract.
        // We're trying to convert to the *specific* num type V represents.
        if (value is String) {
          if (V == int) return int.tryParse(value) as V?;
          if (V == double) return double.tryParse(value) as V?;
          return num.tryParse(value) as V?; // General num parse
        }
        if (V == int && value is num) return value.toInt() as V;
        if (V == double && value is num) return value.toDouble() as V;
        // If V is just `num`, and value is already a num, it should have been caught by `value is V`
        break;
      case DateTime:
        if (value is String) return DateTime.tryParse(value) as V?;
        // Assuming integer timestamp is in seconds for fromMillisecondsSinceEpoch
        if (value is int)
          return DateTime.fromMillisecondsSinceEpoch(value * 1000) as V;
        break;
      case bool:
        if (value is int)
          return (value != 0) as V; // Common: 0 is false, non-zero is true
        if (value is String) {
          final lower = value.toLowerCase();
          if (lower == 'true') return true as V;
          if (lower == 'false') return false as V;
        }
        break;
      // Add more cases here for other types if needed.
    }
    // If no specific conversion rule matched and the value is not already of type V,
    // and not null (handled at the start), then conversion failed or is not supported.
    return null;
  }
}
