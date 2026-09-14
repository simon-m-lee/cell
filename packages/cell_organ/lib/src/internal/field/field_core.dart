// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

class TypeValue<T> {
  final List<TypeValue>? _typeArguments;

  const TypeValue({List<TypeValue>? typeArguments})
      : _typeArguments = typeArguments;

  List<TypeValue> get typeArguments => _typeArguments != null
      ? UnmodifiableListView<TypeValue>(_typeArguments)
      : [];

/*
  factory TypeValue.fromString(String typeString) {
    if (['HasOne', 'HasMany', 'ManyToMany'].any((e) => typeString.startsWith(e))) {
      final splits = typeString.split(RegExp(r'\<|\>'));
      if (splits.length == 3) {
        final types = splits[1].split(',').map<String>((s) => s.trim()).toList(growable: false);
        final r = Reference.instance._references.firstWhereOrNull((r) => r.modelTypes.any((t) => types.first == t.toString()));
        if (r != null) {
          final typeValue = r.fieldReferences().firstWhereOrNull((fr) => fr.typeValue.toString() == typeString);
          if (typeValue != null) {
            return typeValue as TypeValue<T>;
          }
        }
      }
    } else if (typeString.startsWith('Many')) {
      final splits = typeString.split(RegExp(r'\<|\>'));
    }

    return Reference.instance._references.first.typeValue(typeString) as TypeValue<T>;

  }
*/

  @override
  String toString() {
    return T.toString();
  }

  Type get type => T;

  // bool get isDartCoreIterable => <String?>['List', 'Set'].firstWhere((s) => T.toString().contains(s), orElse: () => null) != null;
  // bool get isDartCoreMap => T.toString().contains('Map');
  // bool get isDartCoreType => [bool, double, Function, int, List, Map, null, num, Object, Set, String, Symbol, dynamic].contains(T);

  // Set<T> createSet(Iterable elements) => Set<T>.from(elements.whereType<T>());
}

// class Metadata {
//   final dynamic object;
//   const Metadata(this.object);
//   Metadata call(dynamic object) => Metadata(object);
// }

/*
Iterable<Field> expQuery(Relatable relatable, final Expression expr) {

  if (expr is Or) {
    final result = Set<Field>.identity();
    for (var e in expr) {
      final fields = expQuery(relatable, e);
      result.addAll(fields);
    }
    return result;
  }
  if (expr is And) {
    final lists = expr.map<Iterable<Field>>((e) => expQuery(relatable, e)).toList(growable: false);
    final lasts = lists.sublist(1, lists.length);
    return lists.first.where((f) => lasts.every((list) => list.contains(f))).toList(growable: false);
  }
  if (expr is Condition) {
    if (expr.lhs is FieldExpression) {
      return (expr.lhs as FieldExpression).find(relatable, expr.op, (expr.rhs as Literal).value);
    }
  }
  if (expr is Between) {
    if(expr.lhs is FieldExpression) {
      return
        ((expr.lhs as FieldExpression).find(relatable, Operator.Gt, (expr.min as Literal).value).toList() +
            (expr.lhs as FieldExpression).find(relatable, Operator.Lt, (expr.max as Literal).value).toList()).toSet();
    }
  }
  if (expr is FieldExpression) {
    return expr.find(relatable);

  }
  return Iterable<Field>.empty();
}

class FieldExpression<H extends One, V> extends Expression {
  final dynamic object;

  factory FieldExpression([dynamic object]) {
    return FieldExpression._(object);
  }

  FieldExpression._(this.object);

  FieldExpression<HH,VV> call<HH extends One, VV>(dynamic tag) {
    return FieldExpression<HH,VV>(tag);
  }

  Iterable<Field> find(Relatable relatable, [Operator? op, dynamic value]) {
    final fields = H != One || V != dynamic ? relatable._fieldsGet.whereType<Field<H,V>>().toList() : relatable._fieldsGet.toList();
    if (object is Symbol) {
      fields.retainWhere((f) => f.name == object);
    } else if (object is Metadata) {
      fields.retainWhere((f) => f.metadata.contains(object.object));
    }

    if (op == null) {
      return fields.toList(growable: false);
    }

    return fields.where((f) {
      dynamic fv = f.value, vv = value;
      if (fv is num) {
        if (vv is num) {
          switch(op) {
            case Operator.Eq: return fv == vv;
            case Operator.Gt: return fv > vv;
            case Operator.GtEq: return fv >= vv;
            case Operator.Lt: return fv < vv;
            case Operator.LtEq: return fv <= vv;
            case Operator.Ne: return fv != vv;
            default: return false;
          }
        }
      }
      else if (fv is String) {
        if (vv is String) {
          switch(op) {
            case Operator.Eq: return fv == vv;
            case Operator.Ne: return fv != vv;
            case Operator.Like:
              final exp = RegExp('~$vv');
              return exp.hasMatch(fv);
            default: return false;
          }
        }
      }
      else if (fv is DateTime) {
        if (vv is DateTime) {
          switch(op) {
            case Operator.Eq: return fv.compareTo(vv) == 0;
            case Operator.Gt: return fv.compareTo(vv) > 0;
            case Operator.GtEq: return fv.compareTo(vv) >= 0;
            case Operator.Lt: return fv.compareTo(vv) < 0;
            case Operator.LtEq: return fv.compareTo(vv) <= 0;
            case Operator.Ne: return fv.compareTo(vv) != 0;
            default: return false;
          }
        }
      }
      else if (fv is bool) {
        if (vv is bool) {
          switch(op) {
            case Operator.Eq: return fv == vv;
            case Operator.Ne: return fv != vv;
            default: return false;
          }
        }
      }
      return false;
    }).toList(growable: false);

  }

}*/
