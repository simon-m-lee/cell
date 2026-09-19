// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class RelatableNever implements Relatable {
  const RelatableNever({TestRule? testRule, RelatableReceptor? receptor});

  @override
  apply(Function function, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {}

  @override
  Tissue<Never> get descendants => Tissue<Never>.empty();

  @override
  Tissue<Field<Never, Never>> get fields => Tissue<Never>.empty();

  @override
  Tissue<Relation<Never, Never>> get relations => Tissue<Never>.empty();

  @override
  String toJson(
          {int cascade = 0,
          String? Function(Object? nonEncodable)? toEncodable}) =>
      '';

  @override
  Map<String, dynamic> toMap({int cascade = 0}) => <Never, Never>{};

  @override
  Relatable get unmodifiable => this;

  @override
  Many<Never> operator +(Object other) => _Many.empty();

  @override
  ModifiableAsync<Cell> get async => throw UnimplementedError();

  @override
  Relatable deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return this;
  }

  @override
  Iterable<Function> get modifiable => const Iterable<Function>.empty();

  @override
  TestRelatable<Never, Never> get validate => TestRelatable.allowAll;

  @override
  RelatableNucleus get _nucleus => const RelatableNucleusNever();

  @override
  Context get context => Context.system;

  @override
  bool get isTerminal => true;

  @override
  bool get isNotTerminal => !isTerminal;
}

abstract class RelatableBase extends CellBase
    with RelatableMixin
    implements Relatable {
  @override
  final RelatableNucleus _nucleus;

  RelatableBase(RelatableNucleus super.properties)
      : _nucleus = properties,
        super.fromNucleus();

  @override
  Relatable deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});
}

mixin RelatableMixin on CellBase implements Relatable {
  @override
  Tissue<Field> get fields => _nucleus.fields.unmodifiable;

  @override
  Tissue<Relation> get relations => _nucleus.relations.unmodifiable;

  @override
  Tissue<One> get descendants => _nucleus.descendants.unmodifiable;
}

mixin UnmodifiableRelatableMixin on CellBase implements Relatable {
  late final Tissue<Field> _fields = Tissue<Field>(
      _nucleus.fields.map<Field>((f) => f.unmodifiable),
      bind: _nucleus.fields);

  late final Tissue<Relation> _relations = Tissue<Relation>(
      _nucleus.relations.map<Relation>((r) => r.unmodifiable as Relation),
      bind: _nucleus.relations);

  late final Tissue<One> _descendants = Tissue<One>(
      _nucleus.descendants.map<One>((r) => r.unmodifiable as One),
      bind: _nucleus.descendants);

  @override
  Tissue<Field> get fields => _fields;

  @override
  Tissue<Relation> get relations => _relations;

  @override
  Tissue<One> get descendants => _descendants;
}

abstract class UnmodifiableRelatableBase extends RelatableBase
    with UnmodifiableRelatableMixin {
  UnmodifiableRelatableBase(super.properties) : super();

  @override
  Relatable get unmodifiable => this;
}

/*












mixin RelatableMixin<C extends Tissue<E>> implements Relatable {

  
  
  RelatableNucleus get _nucleus;

  
  
  @override
  Tissue<Field> get fields => _nucleus.fields;

  
  
  @override
  Tissue<Relation> get relations => _nucleus.relations;

  
  
  
  @override
  Tissue<One> get descendants => _nucleus.descendants;

  
  
  
  
  
  
  
  
  @override
  apply(Function function, List? positionalArguments, [Map<Symbol, dynamic>? namedArguments]) {
    return Function.apply(function, positionalArguments, namedArguments);
  }

  @override
  String toString() => '${runtimeType.toString()}: ${toJson()}';

  // int? _hash;
  // @override
  // int get hashCode => _hash ??= _calcHashCode();
  //
  // int _calcHashCode() {
  //   if (fields.isNotEmpty) {
  //     var hash = RANDOM_PRIME;
  //     final iterable = fields.where((f) => !f.isRelation && f.value != null);
  //     if (iterable.isNotEmpty) {
  //       for (var f in iterable) {
  //         hash = 31 * hash + f.value.hashCode;
  //       }
  //       return hash;
  //     }
  //   }
  //   return identityHashCode(this);
  // }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is RelatableBase) {
      if (fields.length == other.fields.length) {
        return other.fields.where((f) => f is! RelationField)
            .every((f) => fields.contains(f));
      }
    }
    return false;
  }


  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    final lookup = Set<One>.identity();

    Map<String, dynamic> parse(Relatable relatable, int cascade) {
      final map = Map<String, dynamic>.from(<String, dynamic>{'_\$Type': relatable.runtimeType});
      String n; dynamic v;
      for (var f in relatable.fields) {
        n = symbolAsString(f.name);
        v = f.value;
        if (f is RelationField) {
          if (cascade > 0) {
            if (v is RelationMany) {
              map[n] = v.map<Map<String, dynamic>>((e) {
                return lookup.add(e) ? parse(e, cascade-1) : e.toMap();
              }).toList(growable: false);
            } else if (v is HasOne && v.isNotEmpty) {
              final e = v.one as One;
              map[n] = lookup.add(e) ? parse(e, cascade-1) : e.toMap();
            } else if (v is BelongsTo && v.isNotEmpty) {
              map[n] = <String, dynamic>{'_\$Type': v.elementType, 'id': v.one!.id};
            }
          }
        } else if (v != null) {
          if (v is Iterable && v.isEmpty) {
            continue;
          }
          map[n] = v;
        }
      }
      return map;
    }

    return parse(this, cascade);
  }


  
  
  
  
  
  
  
  
  
  
  
  
  @override
  String toJson({int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // ignore: prefer_typing_uninitialized_variables
    var vv;
    final map = toMap(cascade: cascade);
    return jsonEncode(map, toEncodable: (v) {
      if (toEncodable != null) {
        vv = toEncodable(v);
        if (vv != null) {
          return vv;
        }
      }
      return Field.valueAs<String>(v);
    });
  }
}*/
