// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../model.dart';

class _ModelNucleus<M extends Model> extends ModelNucleusBase<M> {
  _ModelNucleus({
    super.id,
    super.createdAt,
    super.lastModifiedAt,
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.identityMap,
    super.forceLock,
    super.user,
  }) : super();

  _ModelNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor<Tissue, M>? receptor,
      TestModel<M>? testRule,
      Synapses? synapses,
      bool forceLock = true,
      ModelNucleus<M>? override,
      required super.principal})
      : super.evolve(
            override: override ??
                _ModelNucleus.fromRecord(
                    record: NucleusBase.mask(
                        bind: bind,
                        context: context,
                        receptor: receptor,
                        testRule: testRule,
                        synapses: synapses,
                        forceLock: forceLock)));

  _ModelNucleus.fromRecord({super.record}) : super.fromRecord();

  @override
  ModelNucleus<M> get clone {
    final receptor = get<RelatableReceptor<Tissue, M>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestModel<M>?>(() => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _ModelNucleus<M>.fromRecord(record: (
      mask: NucleusBase.mask(
          context: context,
          receptor: receptor,
          testRule: testRule,
          synapses: synapses == Synapses.disabled
              ? Synapses.disabled
              : Synapses.enabled,
          forceLock: false),
      relatable: (
        fields: FinalBox<Tissue<Field>>(),
        relations: FinalBox<Tissue<Relation>>(),
        descendants: FinalBox<Tissue<One>>()
      ),
      one: (
        id: FinalBox<String>()..value = PushId.generate(),
        createdAt: FinalBox<DateTime>()..value = DateTime.now(),
        lastModifiedAt: FinalBox<DateTime>()..value = DateTime.now(),
      )
    ));
  }
}

abstract class ModelNucleusBase<M extends Model> extends OneNucleusBase<M>
    with RelatableNucleusMixin
    implements ModelNucleus<M> {
  ModelNucleusBase({
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.identityMap = false,
    super.forceLock = false,
    super.user,
    super.id,
    super.createdAt,
    super.lastModifiedAt,
  }) : super();

  const ModelNucleusBase.fromRecord({super.record}) : super.fromRecord();

  ModelNucleusBase.evolve(
      {super.override, required ModelNucleus<M> super.principal})
      : super.evolve();

  @override
  TestModel<M> get testRule => get<TestModel<M>>(record.mask.testRule,
      fallback: principal?.record.mask.testRule, orElse: TestModel.allowAll);

  // bool init(M model, Map<String, dynamic> map, {int cascade = 0, Set<Model>? lookup}) {
  //   if (synapses.link(model, downstreamPole: model)) {
  //     return true;
  //   }
  //   return false;
  // }

  bool init(M model, Map<String, dynamic> map,
      {int cascade = 0, Set<Model>? lookup}) {
    if (synapses.link(model, downstreamCell: model)) {
      final uniques = (lookup ?? <Model>{})..add(model);

      int depth = cascade;

      parse(Model model, Map<String, dynamic> map) {
        // if (depth >= cascade && map.isNotEmpty) {
        //   String n, relType;
        //   FieldReference fr;
        //   Type elementType;
        //   for (var f in fields) {
        //     fr = reference.model<M>().fieldReference.singleWhere((fr) => fr.name == f.name);
        //     n = symbolAsString(f.name);
        //     if (map.containsKey(n)) {
        //
        //       if (f is RelationField) {
        //         if (cascade > 0 && map[n] != null) {
        //           elementType = fr.typeValue.typeArguments.last.type;
        //           relType = fr.typeValue.type.toString();
        //
        //           if (relType.contains('Many')) {
        //             if (map[n] is Iterable) {
        //               final elements = Set<Model>.identity();
        //
        //               for (var m in map[n]) {
        //                 if (m is Map<String, dynamic>) {
        //                   if (reference.modelTypes.contains(elementType)) {
        //                     var element = uniques.firstWhereOrNull((e) => e.id == id && e.runtimeType == elementType)
        //                         // ?? reference.model(elementType).fieldReference.firstWhereOrNull((fr) => fr.name == f.name) as Model;
        //                         ?? reference.model(elementType).fromMap(m);
        //                     if (!uniques.add(element)) {
        //                       element = uniques.lookup(element)!;
        //                     }
        //                     elements.add(element);
        //                   }
        //                 }
        //               }
        //
        //               if (elements.isNotEmpty) {
        //                 (model._nucleus.container.store[f.name] as RelationMany).addAll(elements);
        //               }
        //             }
        //           }
        //
        //           else if (relType.contains('HasOne')) {
        //             if (map[n] is Map<String, dynamic>) {
        //               if (reference.modelTypes.contains(elementType)) {
        //                 // final m = map[n];
        //                 // var element = uniques.firstWhereOrNull((e) => e.id == id && e.runtimeType == elementType)
        //                 //     ?? reference.model(elementType).fieldReference.firstWhereOrNull((fr) => fr.name == f.name) as Model;
        //                 // reference.model(elementType).fromMap(m);
        //                 // if (!uniques.add(element)) {
        //                 //   element = uniques.lookup(element)!;
        //                 // }
        //                 // (model._nucleus.container.store[f.name] as HasOne).set(element);
        //               }
        //             }
        //           }
        //
        //           else if (relType.contains('BelongsTo')) {
        //             if (map[n] is Map<String, dynamic>) {
        //               if (reference.modelTypes.contains(elementType)) {
        //                 var element = uniques.firstWhereOrNull((e) {
        //                   return e.id == map[n]['id'] && e.runtimeType == elementType;
        //                 });
        //                 if (element != null) {
        //                   // final fs = element.fields.where((f) => f is RelationField && f.typeValue.typeArguments.last.type == runtimeType);
        //                   // final fs = reference.model(elementType).fieldReference.firstWhereOrNull((fr) => fr.name == f.name);
        //                   // if (fs != null) {
        //                   //   final rel = fs.value;
        //                   //   if (rel is ModelHasMany) {
        //                   //     rel._nucleus.container.store.add(element);
        //                   //   } else if (rel is ModelHasOne) {
        //                   //     rel._nucleus.container.store.value = element;
        //                   //   }
        //                   // }
        //                 }
        //               }
        //             }
        //           }
        //
        //         }
        //       }
        //
        //       else if (f is ModelValueField) {
        //         if (map.containsKey(n)) {
        //           f._nucleus.container.store.value = map[n];
        //         }
        //       }
        //
        //     }
        //   }
        // }
      }

      if (model._nucleus.container.store.isEmpty) {
        parse(model, map);
      }

      return true;
    }
    return false;
  }
}

abstract class ModelBase<M extends Model> extends OneBase<M>
    with FieldTissueMixin<M>
    implements Model {
  @override
  final ModelNucleus<M> _nucleus;

  ModelBase(ModelNucleus<M> super.properties, {Iterable<Field>? fields})
      : _nucleus = properties,
        super() {
    if (fields != null) {
      final collective =
          RelatableNucleusBase.createFields(this, initialFields: fields);
      _nucleus.record.relatable.fields.value = collective;
      final relations = RelatableNucleusBase.createRelations(collective);
      _nucleus.record.relatable.relations.value = relations;
      _nucleus.record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(relations);
    }
  }

  @override
  Iterator<Field> get iterator => values.iterator;

  @override
  Field? operator [](Object? key) => _nucleus.container.store[key] as Field?;

  @override
  Iterable<Field> get values => _nucleus.container.store.values.cast();

  @override
  Iterable<MapEntry<Symbol, Field>> get entries => super.entries.cast();

  @override
  M deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestModel<M> testRule = TestModel.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  Many<One> operator +(Relatable other) {
    if (other is Iterable<One>) {
      return Many<One>([this, ...(other as Iterable<One>)]);
    } else if (other is One) {
      return Many<One>([this, other]);
    }
    if (other is Cascade) {
      if (other.relatable is Model) {
        return Many<One>([this, other.relatable as Model]);
      } else if (other.relatable is Iterable<Model>) {
        return Many<One>([this, ...(other.relatable as Iterable<Model>)]);
      }
    }
    return Many<One>([this, ...other.descendants]);
  }

  @override
  int get hashCode => 31 * runtimeType.hashCode + 17 * id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Model && other.runtimeType == runtimeType) {
      return id == other.id;
    }
    return false;
  }

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    return (_nucleus.bind as Model)
        .toJson(cascade: cascade, toEncodable: toEncodable);
  }

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    return (_nucleus.bind as Model).toMap(cascade: cascade);
  }
}

abstract class UnmodifiableModelBase<M extends Model> extends ModelBase<M>
    implements UnmodifiableModel {
  UnmodifiableModelBase(ModelNucleusBase<M> super.properties) : super();

  @override
  M deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestModel<M> testRule = TestModel.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  Iterator<Field> get iterator => values.iterator;

  @override
  Iterable<Field> get values {
    return super.values.map<Field>((f) => f.unmodifiable);
  }

  @override
  Iterable<MapEntry<Symbol, Field>> get entries {
    return super.entries.map<MapEntry<Symbol, Field>>(
        (e) => MapEntry<Symbol, Field>(e.key, e.value.unmodifiable));
  }

  @override
  Iterable<Field> followedBy(Iterable<Field> other) {
    return super.followedBy(other).map<Field>((f) => f.unmodifiable);
  }

  @override
  Field reduce(Field Function(Tissue value, Tissue element) combine) {
    return super
        .reduce((value, element) => (element as Field).unmodifiable)
        .unmodifiable;
  }

  @override
  Field firstWhere(bool Function(Field element) test,
      {Field Function()? orElse}) {
    return super
        .firstWhere((element) => test(element), orElse: orElse)
        .unmodifiable;
  }

  @override
  Field lastWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return super
        .lastWhere((element) => test(element), orElse: orElse)
        .unmodifiable;
  }

  @override
  Field singleWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return super
        .singleWhere((element) => test(element), orElse: orElse)
        .unmodifiable;
  }

  @override
  Iterable<Field> where(bool Function(Field element) test) {
    return super
        .where((element) => test(element))
        .map<Field>((f) => f.unmodifiable);
  }

  @override
  Tissue<Field> get fields => _nucleus.fields.unmodifiable;

  @override
  Tissue<Relation> get relations => _nucleus.relations.unmodifiable;

  @override
  Tissue<One> get descendants => _nucleus.descendants.unmodifiable;
}
