// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

abstract interface class Field<H extends One, V> implements TissueValue<V> {
  const factory Field({required TestField testRule}) = _FieldNever;

  Symbol get name;

  H get has;

  @override
  TestField<H, V, Field<H, V>> get validate;

  @override
  Field<H, V> get unmodifiable;

  @override
  Field<H, V> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestField testRule = TestField.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  V? get value;

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other);

/*
  static V valueOf<V>(Model model, Symbol name) {
    for (var f in model.fields) {
      if (f.name == name) {
        final v = f.value;
        if (V == dynamic || v is V) {
          if (v is Relatable) {
            return model is Unmodifiable ? v.unmodifiable : v;
          }
          return v;
        }
      }
    }
    throw ArgumentError.value('#${symbolAsString(name)}', 'name', 'Invalid Symbol for the field.' );
  }
  */

  static T? valueAs<T>(dynamic value) {
    if (value is String && value == '_\$Null\$_') return null;
    if (value.runtimeType == T) return value as T;
    if (value != null) {
      // ignore_for_file: type_literal_in_constant_pattern
      switch (T) {
        case String:
          if (value is DateTime) return value.toIso8601String() as T;
          if (value is Duration) return value.inMilliseconds.toString() as T;
          if (value is Type) return value.toString() as T;
          if (value is Symbol) return symbolAsString(value) as T;
          if (value == Null) return '_\$Null\$_' as T;
          break;
        case int:
          if (value is String) return int.parse(value) as T;
          break;
        case double:
          if (value is String) return double.parse(value) as T;
          break;
        case num:
          if (value is String) return num.parse(value) as T;
          break;
        case DateTime:
          if (value is String) return DateTime.parse(value) as T;
          if (value is int) {
            return DateTime.fromMillisecondsSinceEpoch(value * 1000) as T;
          }
          break;
        case bool:
          if (value is num) return (value == 0 ? false : true) as T;
          if (value is String) {
            return (num.parse(value) == 0 ? false : true) as T;
          }
          break;
        case Duration:
          if (value is String) {
            return Duration(milliseconds: int.parse(value)) as T;
          }
          if (value is int) return Duration(milliseconds: value) as T;

          if (value is num) return (value == 0 ? false : true) as T;
          if (value is String) {
            return (num.parse(value) == 0 ? false : true) as T;
          }
          break;
      }
    }
    return null;
  }
}

abstract interface class TestField<H extends One, V, C extends Tissue<V>> implements TestRelatable<V, C> {

  static const allowAll = _TestFieldNever();

  Symbol get name;

  static TestValue<H, V> value<H extends One, V>(Symbol name, Iterable<TestRule<ValueField<H, V>>> rules, {
    TestValue<H, V>? parent, dynamic user}) {
    return TestValue<H, V>.chain(name, rules, parent: parent, user: user);
  }

  static TestRelation<H, E, R> relation<H extends One, E extends One, R extends Relation<H, E>>(Symbol name, Iterable<TestRule<R>> rules, {
    TestRelation<H, E, R>? parent, dynamic user}) {
    return TestRelation<H, E, R>.chain(name, rules, parent: parent, user: user);
  }
}

abstract interface class UnmodifiableField<H extends One, V> implements Field<H, V>, Unmodifiable {}
