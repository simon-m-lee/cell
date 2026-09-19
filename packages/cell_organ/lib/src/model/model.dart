// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../model.dart';
































































abstract interface class ModelNucleus<M extends Model> implements OneNucleus<M> {

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  factory ModelNucleus({
    String? id,
    DateTime? createdAt,
    DateTime? lastModifiedAt,

    Cell? bind,
    Context context,
    RelatableReceptor<Tissue,M> receptor,
    TestModel<M> testRule,
    Synapses synapses,

    Record? user,

  }) = _ModelNucleus<M>;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  factory ModelNucleus.evolve({
    Cell? bind,
    Context context,
    RelatableReceptor<Tissue,M> receptor,
    TestOne<M> testRule,
    Synapses synapses,

    ModelNucleus<M>? override,
    required ModelNucleus<M> principal,
  }) = _ModelNucleus<M>.evolve;

  @override
  TestModel<M> get testRule;

  @override
  RelatableReceptor<Tissue, M> get receptor;

  @override
  ModelNucleus<M> get clone;
}















































typedef TestModel<M extends Model> = TestOne<M>;

















































































abstract interface class Model implements One, UnmodifiableTissueMap<Symbol, Tissue> {

  ModelNucleus get _nucleus;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  Model deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestCell testRule = TestModel.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  // Iterable

  @override
  Iterator<Field> get iterator;

  @override
  Iterable<Field> followedBy(Iterable<Field> other);

  @override
  Field reduce(Field Function(Tissue value, Tissue element) combine);

  @override
  Field firstWhere(bool Function(Field element) test, {Field Function()? orElse});

  @override
  Field lastWhere(bool Function(Field element) test, {covariant Field Function()? orElse});

  @override
  Field singleWhere(bool Function(Field element) test, {covariant Field Function()? orElse});

  @override
  Iterable<Field> where(bool Function(Field element) test);

  @override
  Iterable<Field> skip(int count);

  @override
  Iterable<Field> take(int count);

  @override
  Iterable<Field> skipWhile(bool Function(Field element) test);

  @override
  Iterable<Field> takeWhile(bool Function(Field element) test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(Field element) toElements);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, Field element) combine);

  @override
  bool every(bool Function(Field<One, dynamic> element) test);

  @override
  bool any(bool Function(Field<One, dynamic> element) test);

  @override
  void forEach(void Function(Field element) action);

  @override
  Iterable<T> map<T>(T Function(Field e) toElement);

  @override
  List<Field> toList({bool growable = true});

  @override
  Set<Field> toSet();

  //

  @override
  bool add(Symbol key, Field value);

  @override
  void addAll(Map<Symbol, Field> other);

  @override
  void addEntries(Iterable<MapEntry<Symbol, Field>> newEntries);

  @override
  Field? remove(Object? key);

  @override
  void removeWhere(bool Function(Symbol key, Field value) predicate);

  // Map

  @override
  Field putIfAbsent(Symbol key, Field Function() ifAbsent);

  @override
  Field update(Symbol key, Field Function(Tissue value) update, {Field Function()? ifAbsent});

  @override
  void updateAll(Field Function(Symbol key, Tissue value) update);

  //

  @override
  TestModel get validate;

  @override
  Field? operator [](Object? key);

  @override
  Iterable<Field> get values;

  @override
  Iterable<MapEntry<Symbol, Field>> get entries;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  Many<One> operator +(Relatable other);

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  static M fromMap<M extends Model>(Map<String, dynamic> map, {Type? type, int cascade = 0, Set<Model>? lookup}) {
    lookup ??= <Model>{};
    return M == Blend
        ? Blend.fromMap(map, lookup: lookup, cascade: cascade) as M
        : fromMap<M>(map, cascade: cascade, lookup: lookup);
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  static M fromJson<M extends Model>(String json, {Type? type, int cascade = 0, Set<Model>? lookup}) {
    return fromMap<M>(jsonDecode(json) as Map<String, dynamic>, type: type, cascade: cascade, lookup: lookup);
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  String toJson({int cascade = 0, String? Function(Object? nonEncodable)? toEncodable});

  
  
  
  
  
  
  
  
  
  
  
  @override
  Map<String, dynamic> toMap({int cascade = 0});

}

































































abstract interface class UnmodifiableModel implements Model, UnmodifiableOne {

  
  
  
  
  
  
  @override
  Model deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestModel testRule = TestModel.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  
  
  
  
  @override
  Iterable<Field> followedBy(Iterable<Field> other);

  
  
  
  
  @override
  Field reduce(Field Function(Tissue value, Tissue element) combine);

  
  
  
  @override
  Field firstWhere(bool Function(Field element) test, {Field Function()? orElse});

  
  
  
  @override
  Field lastWhere(bool Function(Field element) test, {covariant Field Function()? orElse});

  
  
  
  @override
  Field singleWhere(bool Function(Field element) test, {covariant Field Function()? orElse});

  
  
  @override
  Field putIfAbsent(Symbol key, Field Function() ifAbsent);

  
  
  @override
  Field update(Symbol key, Field Function(Tissue value) update, {Field Function()? ifAbsent});
}
