// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class _BlendFieldTissue extends BlendBase
    with FieldTissueMixin<Blend>
    implements TissueMap<Symbol, Tissue> {
  _BlendFieldTissue._(super.properties, {required Map<Symbol, Field> map})
      : super.fromNucleus() {
    try {
      final container = Map<Symbol, Field>.from(map);
      _nucleus.record.container.init(container);
    } catch (_) {}

    try {
      final fields = RelatableNucleusBase.createFields(this,
          initialFields: map.values.toSet());
      _nucleus.record.relatable.fields.value = fields;
      final relations = RelatableNucleusBase.createRelations(fields);
      _nucleus.record.relatable.relations.value = relations;
      _nucleus.record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(relations);
    } catch (_) {}
  }

  _BlendFieldTissue.from(String name,
      {required Map<Symbol, Field> map,
      Cell? bind,
      Context context = Context.system,
      RelatableReceptor<Tissue, Blend> receptor = RelatableReceptor.passThrough,
      TestOne<Blend> testRule = TestOne.allowAll,
      Synapses synapses = Synapses.enabled})
      : this._(
            BlendNucleus(name,
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses),
            map: map);

  _BlendFieldTissue(String name,
      {required Iterable<Field> fields,
      Cell? bind,
      Context context = Context.system,
      RelatableReceptor<Tissue, Blend> receptor = RelatableReceptor.passThrough,
      TestOne<Blend> testRule = TestOne.allowAll,
      Synapses synapses = Synapses.enabled})
      : this.from(name,
            map: Map<Symbol, Field>.fromEntries(
                fields.map<MapEntry<Symbol, Field>>(
                    (f) => MapEntry<Symbol, Field>(f.name, f))),
            bind: bind,
            context: context,
            receptor: receptor,
            testRule: testRule,
            synapses: synapses);

  @override
  Blend(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _BlendDeputy._(this,
        context: context, testRule: testRule, filter: filter);
  }

  @override
  String get name => _nucleus.name;

  @override
  Iterable<Field> followedBy(Iterable<Field> other) {
    return fields.followedBy(other).cast();
  }

  @override
  Field reduce(Field Function(Tissue value, Tissue element) combine) {
    return fields.reduce(combine);
  }

  @override
  Field firstWhere(bool Function(Field element) test,
      {Field Function()? orElse}) {
    return fields.firstWhere((element) => test(element), orElse: orElse);
  }

  @override
  Field lastWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return fields.lastWhere((element) => test(element), orElse: orElse);
  }

  @override
  Field singleWhere(bool Function(Field element) test,
      {covariant Field Function()? orElse}) {
    return fields.singleWhere((element) => test(element), orElse: orElse);
  }

  @override
  Field putIfAbsent(Symbol key, Field Function() ifAbsent) {
    throw UnsupportedError('Unmodifiable TissueMap.');
  }

  @override
  Field update(Symbol key, Field Function(Tissue value) update,
      {Field Function()? ifAbsent}) {
    throw UnsupportedError('Unmodifiable TissueMap.');
  }
}

class _BlendTissueValue extends BlendBase
    with ValueTissueMixin<Blend, dynamic, TissueValue>
    implements TissueMap<Symbol, Tissue> {
  _BlendTissueValue(String name,
      {required Map<Symbol, Iterable<Field>> map,
      required MapEntry<Symbol, TissueValue> Function(
              MapEntry<Symbol, Iterable<Field>> entry)
          toValue,
      Cell? bind,
      Context context = Context.system,
      RelatableReceptor<Tissue, Blend> receptor = RelatableReceptor.passThrough,
      TestOne<Blend> testRule = TestOne.allowAll,
      Synapses synapses = Synapses.enabled})
      : super.fromNucleus(BlendNucleus(name,
            bind: bind,
            context: context,
            receptor: receptor,
            testRule: testRule,
            synapses: synapses)) {
    final container = Map<Symbol, TissueValue>.fromEntries(map.entries
        .map<MapEntry<Symbol, TissueValue>>((en) =>
            MapEntry<Symbol, TissueValue>(
                en.key, toValue(en) as TissueValue<dynamic>)));
    _nucleus.record.container.init(container);

    final fields = RelatableNucleusBase.createFields(this,
        initialFields: map.values
            .map((e) => e.toList())
            .reduce((c, n) => [...c, ...n])
            .toSet());
    _nucleus.record.relatable.fields.value = fields;
    final relations = RelatableNucleusBase.createRelations(fields);
    _nucleus.record.relatable.relations.value = relations;
    _nucleus.record.relatable.descendants.value =
        RelatableNucleusBase.createDescendants(relations);
  }

  @override
  Blend deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<Blend> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _BlendDeputy._(this,
        context: context, testRule: testRule, filter: filter);
  }

  @override
  String get name => _nucleus.name;

  @override
  Iterable<Field> followedBy(Iterable<Field> other) {
    return fields.followedBy(other).cast();
  }

  @override
  TissueValue reduce(Field Function(Tissue value, Tissue element) combine) {
    return values.reduce(combine);
  }

  @override
  TissueValue firstWhere(bool Function(TissueValue element) test,
      {TissueValue Function()? orElse}) {
    return values.firstWhere((element) => test(element), orElse: orElse);
  }

  @override
  TissueValue lastWhere(bool Function(TissueValue element) test,
      {covariant TissueValue Function()? orElse}) {
    return values.lastWhere((element) => test(element), orElse: orElse);
  }

  @override
  TissueValue singleWhere(bool Function(TissueValue element) test,
      {covariant TissueValue Function()? orElse}) {
    return values.singleWhere((element) => test(element), orElse: orElse);
  }

  @override
  TissueValue putIfAbsent(Symbol key, TissueValue Function() ifAbsent) {
    throw UnsupportedError('Unmodifiable TissueMap.');
  }

  @override
  TissueValue update(Symbol key, TissueValue Function(Tissue value) update,
      {Tissue Function()? ifAbsent}) {
    throw UnsupportedError('Unmodifiable TissueMap.');
  }
}

abstract class BlendBase extends OneBase<Blend> implements Blend {
  @override
  BlendNucleus get _nucleus => super._nucleus as BlendNucleus;

  BlendBase(String name,
      {Iterable<Field>? fields,
      Cell? bind,
      Context context = Context.system,
      RelatableReceptor<Tissue, Blend> receptor = RelatableReceptor.passThrough,
      TestOne<Blend> testRule = TestOne.allowAll,
      Synapses synapses = Synapses.enabled})
      : this.fromNucleus(
            BlendNucleus(name,
                bind: bind,
                context: context,
                receptor: receptor,
                testRule: testRule,
                synapses: synapses),
            fields: fields);

  BlendBase.fromNucleus(BlendNucleus super.properties,
      {Iterable<Field>? fields})
      : super() {
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
  String get name => _nucleus.name;

  @override
  String get id => _nucleus.id;

  @override
  TestOne<Blend> get validate => _nucleus.testRule;

  @override
  Blend deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<Blend> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _BlendDeputy._(this,
        testRule: testRule, filter: filter, context: context);
  }

  @override
  late final Blend unmodifiable = _UnmodifiableBlend(this);
}

class _BlendDeputy extends BlendBase with Deputy<Blend> {
  _BlendDeputy._(Blend bind,
      {Context context = Context.system,
      required TestOne<Blend> testRule,
      FilterRule? filter})
      : super.fromNucleus(
            BlendNucleus.evolve(
                context: context,
                bind: bind,
                testRule: testRule,
                synapses: bind._nucleus.synapses != Synapses.disabled
                    ? filter != null
                        ? Synapses(filter: filter)
                        : Synapses.enabled
                    : Synapses.disabled,
                principal: bind._nucleus),
            fields: bind.fields);

  @override
  Blend deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<Blend> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    bool changed = false;
    final iterable = <Field>{};
    Field f_;
    for (var f in fields) {
      f_ = testRule.names.contains(f.name)
          ? f.deputy(
              context: context,
              testRule: testRule[f.name]! as TestField<One, dynamic, Field>)
          : f;
      iterable.add(f_);
      if (!identical(f, f_)) {
        changed = true;
      }
    }
    return changed
        ? _BlendDeputy._(this,
            context: context, testRule: testRule, filter: filter)
        : this;
  }
}

class _UnmodifiableBlend extends UnmodifiableBlendBase {
  _UnmodifiableBlend(Blend blend)
      : this.fromNucleus(
            BlendNucleus.evolve(bind: blend, principal: blend._nucleus),
            fields: blend.fields.unmodifiable);

  _UnmodifiableBlend.fromNucleus(super.properties, {Iterable<Field>? fields})
      : super.fromNucleus(fields: fields ?? properties.fields.unmodifiable);

  @override
  Blend deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestOne<Blend> testRule = TestOne.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return this;
  }
}

abstract class UnmodifiableBlendBase extends BlendBase
    with UnmodifiableRelatableMixin
    implements UnmodifiableBlend {
  UnmodifiableBlendBase(Blend blend)
      : this.fromNucleus(
            BlendNucleus.evolve(bind: blend, principal: blend._nucleus),
            fields: blend.fields.unmodifiable);

  UnmodifiableBlendBase.fromNucleus(super.properties, {Iterable<Field>? fields})
      : super.fromNucleus(fields: fields ?? properties.fields.unmodifiable);

  @override
  Blend deputy(
      {Context context = Context.system,
      required covariant TestChain testRule,
      FilterRule? filter});

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is Blend) {
      return id == other.id;
    } else if (other is RelationOne) {
      if (runtimeType == other.elementType && other.one != null) {
        return id == other.one!.id;
      }
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  Many<One> operator +(Object other) {
    // TODO: implement +
    throw UnimplementedError();
  }
}
