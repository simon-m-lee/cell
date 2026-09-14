// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class RelationFieldNucleus<H extends One, E extends One,
        R extends Relation<H, E>> extends FieldNucleusBase<H, R>
    implements TissueValueNucleusBase<R, RelationField<H, E, R>> {
  RelationFieldNucleus(
    H has,
    Symbol name, {
    R? relation,
    Cell? bind,
    Context context = Context.system,
    TestRelation<H, E, R> testRule = TestRelation.allowAll,
    bool forceLock = false,
    Record? user,
  }) : super(
            local: TissueNucleus.create<R, ValueContainer<R>,
                RelationField<H, E, R>>(
              bind: bind,
              context: context,
              testRule: _testRelation<H, E, R>(has, testRule),
              synapses: Synapses(
                  downstreams: [has],
                  filter: FilterRule((pulse, {user}) {
                    if (pulse is TissuePost &&
                        identical(pulse.from, has[name])) {
                      return RelatablePost._(
                          from: pulse.from as RelationField<H, E, R>,
                          body: Map.fromEntries(pulse.payload!.entries.map(
                              (en) => MapEntry<RelatablePulse,
                                      Iterable<ElementValueChange>>(
                                  // if (en.key is ElementAddedEvent) {
                                  //   return Relatable.fieldAdded, en.value as Iterable<ElementValueChange>;
                                  // } else if (en.key is ElementRemovedEvent) {
                                  //   return Relatable.fieldRemoved;
                                  // } else (en.key is ElementChangedEvent) {
                                  //   return Relatable.fieldChanged;
                                  // }
                                  //

                                  switch (en.key) {
                                    ElementAdded() => Relatable.fieldAdded,
                                    ElementRemoved() => Relatable.fieldRemoved,
                                    ElementUpdatedEvent() =>
                                      Relatable.fieldChanged
                                  },
                                  en.value as Iterable<ElementValueChange>))));
                    }
                    return pulse;
                  })),
              container: Container.finalValue,
              user: user,
              forceLock: forceLock,
            ),
            has: has,
            name: name,
            value: relation);

  static TestTissue<R, RelationField<H, E, R>>
      _testRelation<H extends One, E extends One, R extends Relation<H, E>>(
          H has, TestRelation<H, E, R> testRule) {
    return TestTissue.allowAll;
  }

  RelationFieldNucleus.evolve(
      {Cell? bind,
      Context? context,
      TestRelation<H, E, R>? testRule,
      required RelationFieldNucleus<H, E, R> super.principal})
      : super.evolve(
            override: Nucleus.create<R>(
                bind: bind,
                context: context ?? Context.system,
                testRule: testRule != TestRelation.allowAll
                    ? testRule
                    : TestCell.allowAll,
                forceLock: true));

  @override
  RelationFieldNucleus<H, E, R>? get principal =>
      super.principal as RelationFieldNucleus<H, E, R>;

  @override
  R get value => super.value as R;

  @override
  TestField<H, R, RelationField<H, E, R>> get testRule {
    return get<TestField<H, R, RelationField<H, E, R>>>(
        () => record.mask.testRule,
        fallback: () => principal?.testRule,
        orElse: TestRelation.allowAll);
  }

  @override
  RelatableReceptor<R, RelationField<H, E, R>> get receptor => relationReceptor;

  static final RelatableReceptor<Never, RelationField<Never, Never, Never>>
      relationReceptor =
      RelatableReceptor<Never, RelationField<Never, Never, Never>>(
          PulseRule((Cell cell, Pulse pulse, {dynamic user}) {
    return ((cell as RelationField).value)._nucleus.receptor(pulse);
  }));

  RelationFieldNucleus._copy(
      {RelatableReceptor<R, RelationField<H, E, R>> receptor =
          RelatableReceptor.passThrough,
      required RelationFieldNucleus<H, E, R> super.principal})
      : super.evolve(
            override: Nucleus.create<RelationField<H, E, R>>(
                receptor: receptor, forceLock: false));

  @override
  RelationFieldNucleus<H, E, R> get clone {
    return RelationFieldNucleus<H, E, R>._copy(
        receptor: receptor.clone, principal: this);
  }

  @override
  Container get containerType {
    return get<Container>(() => record.mask.inheritable.container,
        fallback: () => principal!.containerType, orElse: Container.value);
  }
}

abstract class RelationField<H extends One, E extends One,
        R extends Relation<H, E>>
    extends UnmodifiableTissueValueBase<R, RelationField<H, E, R>>
    implements Field<H, R> {
  final RelationFieldNucleus<H, E, R> _nucleus;

  RelationField(
    H has,
    Symbol name, {
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, R> receptor = RelatableReceptor.passThrough,
    TestRelation<H, E, R> testRule = TestRelation.allowAll,
  }) : this.fromNucleus(RelationFieldNucleus<H, E, R>(
          has,
          name,
          bind: bind,
          context: context,
        ));

  RelationField.fromNucleus(RelationFieldNucleus<H, E, R> super.properties,
      {R? relation})
      : _nucleus = properties,
        super(value: relation);

  @override
  H get has => _nucleus.has;

  @override
  Symbol get name => _nucleus.name;

  @override
  R get value => _nucleus.value;

  @override
  RelationField<H, E, R> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H, E, R> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return this;
  }

  @override
  TestField<H, R, RelationField<H, E, R>> get validate => TestField.allowAll;

  @override
  RelationField<H, E, R> get unmodifiable => this;
}

class TestRelation<H extends One, E extends One, R extends Relation<H, E>>
    extends TestRelatable<E, R> implements TestField<H, E, R> {

  static const allowAll = _TestRelationNever();

  const TestRelation(Symbol name, FutureOr<bool> Function(dynamic object, {TestRelation<H, E, R>? host, dynamic arguments, dynamic user}) rule, {
    TestRelation<H, E, R>? parent, dynamic user
  }) : this.fromRecord(parent != null
      ? user != null
      ? (name: name, rule: rule, parent: parent, user: user)
      : (name: name, rule: rule, parent: parent)
      : user != null
      ? (name: name, rule: rule, user: user)
      : (name: name, rule: rule));

  const TestRelation.chain(Symbol name, Iterable<TestRule<Tissue<E>>> rules, {
    TestRelation<H, E, R>? parent, dynamic user,
    FutureOr<bool> Function(dynamic object, {TestRelation<H, E, R>? host, dynamic arguments, dynamic user})? strategy})
      : this.fromRecord(strategy != null ? parent != null
      ? user != null ? (name: name, rules: rules, rule: strategy, parent: parent, user: user) : (name: name, rules: rules, rule: strategy, parent: parent)
      : user != null ? (name: name, rules: rules, rule: strategy, user: user) : (rules: rules, rule: strategy)
      : (name: name, rules: rules)
  );

  const TestRelation.fromRecord(Record record)
      : super.fromRecord(record);

  @override
  Symbol get name => get<Symbol>(() => _record.name, fallback: () => _parent!.name);

  TestRelation<H, E, R>? get _parent => get<TestRelation<H, E, R>?>(() => _record.parent, orElse: null);

  @override
  TestRelation<H, E, R> operator +(covariant TestRelation<H, E, R> other) {
    return TestRelation<H, E, R>.chain(name, [this, other]);
  }

}

