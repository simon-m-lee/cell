// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class ValueFieldNucleus<H extends One, V> extends FieldNucleusBase<H, V> implements TissueValueNucleusBase<V, ValueField<H, V>> {

  ValueFieldNucleus(
    H has, Symbol name, {
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<V, ValueField<H, V>> receptor = RelatableReceptor.passThrough,
    TestValue<H, V> testRule = TestValue.allowAll,
    Synapses synapses = Synapses.enabled,
    super.value,
    bool? finalValue,
    bool forceLock = false,
    Record? user,
  }) : super(
            local: TissueNucleus.create<V, ValueContainer<V>, ValueField<H, V>>(
              bind: bind,
              context: context,
              testRule: _testValue<H, V>(has, testRule, name),
              receptor: receptor,
              synapses: Synapses(
                  downstreams: [has],
                  filter: FilterRule((pulse, {user}) {
                    if (pulse is TissuePost &&
                        identical(pulse.from, has[name])) {
                      return RelatablePost._(
                          from: pulse.from as ValueField<H, V>,
                          body: Map.fromEntries(pulse.payload!.entries.map(
                              (en) => MapEntry<RelatablePulse,
                                      Iterable<ElementValueChange>>(
                                  (en.key is ElementUpdatedEvent
                                      ? Relatable.fieldChanged
                                      : en.key is ElementAdded
                                          ? Relatable.fieldAdded
                                          : en.key is ElementRemoved
                                              ? Relatable.fieldRemoved
                                              : en.key) as RelatablePulse,
                                  en.value as Iterable<ElementValueChange>))));
                    }
                    return pulse;
                  })),
              container: finalValue != null
                  ? (finalValue ? Container.finalValue : null)
                  : !V.runtimeType.toString().contains('?')
                      ? Container.finalValue
                      : null,
              user: user,
              forceLock: forceLock,
            ),
            has: has,
            name: name);

  ValueFieldNucleus.evolve({
    Cell? bind, Context? context, RelatableReceptor<V, ValueField<H, V>>? receptor, TestValue<H, V>? testRule,
      required ValueFieldNucleus<H, V> super.principal})
      : super.evolve(override: Nucleus.create<ValueField<H, V>>(
      bind: bind,
      context: context,
      receptor: receptor,
      testRule: testRule,
      forceLock: true
  ));

  static TestValue<H, V> _testValue<H extends One, V>(
      H has, TestValue<H, V> testRule, Symbol name) {
    final parentRule = (has as OneBase<H>)._nucleus.testRule[name];
    if (parentRule is TestValue<H, V> && parentRule != TestValue.allowAll) {
      return testRule != TestValue.allowAll ? parentRule + testRule : testRule;
    }
    return testRule;
  }

  @override
  ValueFieldNucleus<H, V>? get principal =>
      super.principal as ValueFieldNucleus<H, V>?;

  @override
  TestValue<H, V> get testRule => super.testRule as TestValue<H, V>;

  @override
  RelatableReceptor<V, ValueField<H, V>> get receptor =>
      super.receptor as RelatableReceptor<V, ValueField<H, V>>;

  @override
  Container get containerType {
    return get<Container>(() => record.mask.inheritable.container,
        fallback: () => principal!.containerType, orElse: Container.value);
  }

  @override
  ValueFieldNucleus<H, V> get clone {
    final receptor = get<RelatableReceptor<V, ValueField<H, V>>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestValue<H, V>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return ValueFieldNucleus<H, V>._fromRecord(record: (
      mask: TissueNucleusBase.local<V, ValueContainer<V>, ValueField<H, V>>(
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: Synapses(filter: FilterRule((pulse, {user}) {
          if (pulse is TissuePost && identical(pulse.from, has[name])) {
            return RelatablePost._(
                from: pulse.from as ValueField<H, V>,
                body: Map.fromEntries(pulse.payload!.entries.map((en) =>
                    MapEntry<RelatablePulse, Iterable<ElementValueChange>>(
                        (en.key is ElementUpdatedEvent
                            ? Relatable.fieldChanged
                            : en.key is ElementAdded
                                ? Relatable.fieldAdded
                                : en.key is ElementRemoved
                                    ? Relatable.fieldRemoved
                                    : en.key) as RelatablePulse,
                        en.value as Iterable<ElementValueChange>))));
          }
          return pulse;
        })),
        container:
            containerType == Container.finalValue ? Container.finalValue : null,
        forceLock: false,
      ),
      field: (has: FinalBox<H>(), name: FinalBox<Symbol>()),
      principal: this,
    ));
  }

  ValueFieldNucleus._fromRecord({super.record}) : super.fromRecord();
}

abstract class ValueField<H extends One, V>
    extends TissueValueBase<V, ValueField<H, V>> implements Field<H, V> {
  final ValueFieldNucleus<H, V> _nucleus;

  ValueField(
    H has,
    Symbol name, {
    V? value,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<V, ValueField<H, V>> receptor =
        RelatableReceptor.passThrough,
    TestValue<H, V> testRule = TestValue.allowAll,
  }) : this.fromNucleus(
            ValueFieldNucleus<H, V>(
              has,
              name,
              bind: bind,
              context: context,
              receptor: receptor,
              testRule: testRule,
            ),
            value: value);

  ValueField.fromNucleus(ValueFieldNucleus<H, V> super.properties,
      {super.value})
      : _nucleus = properties,
        super();

  @override
  H get has => _nucleus.has;

  @override
  Symbol get name => _nucleus.name;

  bool get isFinal => _nucleus.container.store is FinalBox;

  @override
  bool set(V? value) {
    return _set(value).isNotEmpty;
  }

  @override
  ValueField<H, V> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestValue<H, V> testRule = TestValue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  TestValue<H, V> get validate => _nucleus.testRule;

  Map<RelatablePulse, Iterable<ElementValueChange>> _set(V? v, {bool notification = true}) {
    if (_nucleus.testRule.action(set,
        host: this,
        arguments: (positionalArguments: [v], namedArguments: null))) {
      if (_nucleus.testRule(v, host: this)) {
        return _setValue(v, notification: notification);
      }
      return {};
    }
    return {};
  }

  Map<RelatablePulse, Iterable<ElementValueChange>> _setValue(V? v,
      {bool notification = true}) {
    final map =
        <RelatablePulse, Iterable<ElementValueChange<Field<H, V>, V?>>>{};

    final before = v;
    if (_nucleus.value != v) {
      if (v is Cell) {
        if (!_nucleus.synapses.link(v, downstreamCell: this)) {
          return {};
        }
      }

      if (before is Relatable) {
        if (!before._nucleus.synapses.unlink(this, before)) {
          if (v is Relatable) {
            v._nucleus.synapses.unlink(this, v);
          }
          return {};
        }
      }

      if (_nucleus.record.container == Container.value) {
        if (_nucleus.container.isNotEmpty && _nucleus.container.first == v) {
          return {};
        }

        if (v != null) {
          (_nucleus.container.store as List)
            ..clear()
            ..add(v);
        } else {
          (_nucleus.container.store as List).clear();
        }

        map[Relatable.fieldChanged] = {
          ElementValueChange<Field<H, V>, V?>(
              element: this as Field<H, V>, after: v, before: before)
        };
        if (notification) {
          final post = RelatablePost._(from: this, body: map);
          _nucleus.receptor(post);
        }
      }
    }
    return map;
  }

  @override
  ValueField<H, V> get unmodifiable;

}

class NamedTestRule<E, C extends Tissue<E>> extends TestRule<C> {

  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final _record;

  const NamedTestRule(String name, FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user}) rule, {
    NamedTestRule<E, C>? parent, dynamic user
  }) : this.fromRecord(parent != null
      ? user != null
      ? (name: name, rule: rule, parent: parent, user: user)
      : (name: name, rule: rule, parent: parent)
      : user != null
      ? (name: name, rule: rule, user: user)
      : (name: name, rule: rule));

  const NamedTestRule.chain(Iterable<NamedTestRule<E,C>> rules, {
    NamedTestRule<E, C>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {C? host, dynamic arguments, dynamic user})? strategy})
      : this.fromRecord(strategy != null ? parent != null
      ? user != null ? (rules: rules, rule: strategy, parent: parent, user: user) : (rules: rules, rule: strategy, parent: parent)
      : user != null ? (rules: rules, rule: strategy, user: user) : (rules: rules, rule: strategy)
      : (rules: rules)
  );

  const NamedTestRule.fromRecord(Record record)
      : _record = record, super.fromRecord(record);

}

class TestValue<H extends One, V>
    extends TestRelatable<V, ValueField<H, V>> implements TestField<H, V, ValueField<H, V>> {

  static const allowAll = _TestValueNever();

  const TestValue(Symbol name, FutureOr<bool> Function(dynamic object, {ValueField<H, V>? host, dynamic arguments, dynamic user}) rule, {
    TestValue<H, V>? parent, dynamic user
  }) : this.fromRecord(parent != null
      ? user != null
      ? (name: name, rule: rule, parent: parent, user: user)
      : (name: name, rule: rule, parent: parent)
      : user != null
      ? (name: name, rule: rule, user: user)
      : (name: name, rule: rule));

  const TestValue.chain(Symbol name, Iterable<TestRule<ValueField<H, V>>> rules, {
    TestValue<H, V>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {ValueField<H, V>? host, dynamic arguments, dynamic user})? strategy})
      : this.fromRecord(strategy != null ? parent != null
      ? user != null ? (name: name, rules: rules, rule: strategy, parent: parent, user: user) : (name: name, rules: rules, rule: strategy, parent: parent)
      : user != null ? (name: name, rules: rules, rule: strategy, user: user) : (rules: rules, rule: strategy)
      : (name: name, rules: rules)
  );

  const TestValue.fromRecord(Record record)
      : super.fromRecord(record);

  @override
  Symbol get name => get<Symbol>(() => _record.name, fallback: () => _parent!.name);

  /// The next rule in the validation chain, evaluated if this rule passes.
  TestValue<H,V>? get _parent => get<TestValue<H,V>?>(() => _record.parent, orElse: null);

  @override
  TestValue<H, V> operator +(covariant TestValue<H,V> other) {
    return TestValue<H, V>.chain(name, [this, other]);
  }
}

