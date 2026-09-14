// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

abstract interface class OneNucleus<O extends One> implements RelatableNucleus, TissueMapNucleusBase<Symbol, Tissue, O> {
  factory OneNucleus({
    String? id,
    DateTime? createdAt,
    DateTime? lastModifiedAt,

    Tissue<Field>? fields,
    Tissue<Relation>? relations,
    Tissue<One>? descendants,

    Cell? bind,
    Context context,
    RelatableReceptor<Tissue, O> receptor,
    TestOne<O> testRule,
    Synapses synapses,
    Record? user,
    bool identityMap

  }) = _OneNucleus<O>;

  factory OneNucleus.evolve({
    Cell? bind,
    Context? context,
    RelatableReceptor<Tissue, O>? receptor,
    TestOne<O>? testRule,
    Synapses? synapses,
    OneNucleus<O>? override,
    required OneNucleus<O> principal,
  }) = _OneNucleus<O>.evolve;

  String get id;

  @override
  OneNucleus<O>? get principal;

  DateTime get createdAt;

  DateTime get lastModifiedAt;

  @override
  TestOne<O> get testRule;

  @override
  RelatableReceptor<Tissue, O> get receptor;

  OneNucleus<O> get clone;
}

abstract interface class One implements Relatable, TissueMap<Symbol, Tissue> {

  @override
  OneNucleus get _nucleus;

  @override
  One deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestOne testRule = TestOne.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  String get id;

  DateTime get createdAt;

  DateTime get lastModifiedAt;

  @override
  TestOne get validate;

  @override
  Many<One> operator +(Relatable other);

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable});

  @override
  Map<String, dynamic> toMap({int cascade = 0});
}

abstract interface class UnmodifiableOne implements One, Unmodifiable {}

class TestOne<H extends One> extends TestRelatable<Tissue, H> {
  
  static const allowAll = _TestOneNever();

  const TestOne(super.rules, {TestOne<H>? super.parent, super.user, super.strategy})
      : super.chain();

  @override
  TestOne<H> operator +(covariant TestOne<H> other) {
    return TestOne<H>([this, other]);
  }

  const TestOne.fromRecord(super.record) : super.fromRecord();

  Map<Symbol, TestField> get _map {
    return get<Map<Symbol, TestField>>(() => _record.map, orElse: const {});
  }

  static TestValue<H, V> value<H extends One, V>(String name, Iterable<TestRule<ValueField<H, V>>> rules, {
    TestValue<H, V>? parent, dynamic user}) {
    return TestValue<H, V>.chain(name, rules, parent: parent, user: user);
  }

  TestField? operator [](Symbol name) {
    return _map[name];
  }

  Iterable<Symbol> get names => _map.keys;

  bool get isEmpty => _map.isEmpty;

  bool get isNotEmpty => _map.isNotEmpty;

  bool containName(Symbol name) {
    return _map.containsKey(name);
  }

  Iterable<TestField> get values => _map.values;

  Iterable<MapEntry<Symbol, TestField>> get entries => _map.entries;

  int get length => _map.length;
}
