// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class _CascadeNucleus extends CascadeNucleusBase {
  _CascadeNucleus(
    Relatable relatable, {
    super.bind,
    super.context,
    super.receptor,
    super.testRule,
    super.synapses,
    super.user,
    super.depth,
  }) : super(relatable: relatable, forceLock: false);

  _CascadeNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor? receptor,
      TestRelatable? testRule,
      Synapses? synapses,
      bool forceLock = true,
      CascadeNucleus? override,
      required super.principal})
      : super.evolve(
            override: override ??
                _CascadeNucleus.fromRecord(record: (
                  mask: NucleusBase.mask(
                      bind: bind,
                      context: context,
                      receptor: receptor,
                      testRule: testRule,
                      synapses: synapses,
                      forceLock: forceLock)
                )));

  _CascadeNucleus.fromRecord({super.record}) : super.fromRecord();

  @override
  CascadeNucleus get clone {
    final receptor = get<RelatableReceptor?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestRelatable?>(() => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _CascadeNucleus.fromRecord(record: (
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
      cascade: depth != 8
          ? (
              depth: FinalBox<int>()..value = depth,
              relatable: FinalBox<Relatable>()
            )
          : (relatable: FinalBox<Relatable>())
    ));
  }
}

abstract class CascadeNucleusBase extends RelatableNucleusBase
    implements CascadeNucleus {
  CascadeNucleusBase({
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor receptor = RelatableReceptor.passThrough,
    TestRelatable testRule = TestRelatable.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = false,
    Record? user,
    required Relatable relatable,
    int depth = 8,
  }) : super.fromRecord(record: (
          mask: NucleusBase.mask(
              bind: bind,
              context: context,
              receptor:
                  receptor != RelatableReceptor.passThrough ? receptor : null,
              testRule: testRule != TestRelatable.allowAll ? testRule : null,
              synapses: synapses,
              forceLock: forceLock,
              user: user),
          relatable: (
            fields: FinalBox<Tissue<Field>>(),
            relations: FinalBox<Tissue<Relation>>(),
            descendants: FinalBox<Tissue<One>>()
          ),
          cascade: depth != 8
              ? (
                  depth: FinalBox<int>()..value = depth,
                  relatable: FinalBox<Relatable>()..value = relatable
                )
              : (relatable: FinalBox<Relatable>()..value = relatable)
        ));

  const CascadeNucleusBase.fromRecord({super.record}) : super.fromRecord();

  CascadeNucleusBase.evolve(
      {super.override, required CascadeNucleus super.principal})
      : super.evolve();

  @override
  Relatable get relatable {
    return get<Relatable>(() => record.cascade.relatable.value,
        fallback: () => principal!.relatable);
  }

  @override
  int get depth {
    return get<int>(() => record.cascade.depth,
        fallback: () => principal!.depth, orElse: 8);
  }

  @override
  CascadeNucleus? get principal {
    return super.principal as CascadeNucleus?;
  }

  static ({
    Iterable<Field> fields,
    Iterable<Relation> relations,
    Iterable<One> descendants
  }) _parse(Relatable relatable,
      {int depth = 8, DeputyContext? context, TestRelatable? testRule}) {
    final uniques = Set<One>.identity();

    var fields = Set<Field>.identity();
    var relations = Set<Relation>.identity();
    var descendants = Set<One>.identity();

    parse(Relatable relatable) {
      var counter = depth;

      parseOne(One one) {
        if (uniques.add(one)) {
          final testOne = one.validate != TestOne.allowAll ? one.validate : null;
          fields.addAll(testOne != null
              ? one.fields.map<Field>((f) {
                  return f is ValueField && testOne[f.name] != null
                      ? f.deputy(
                          context: context ??
                              DeputyContext.create(
                                  principal: f._nucleus.context,
                                  deputyRole: 'Cascade'),
                          testRule: testOne[f.name]! as TestValue)
                      : f;
                })
              : one.fields);

          relations.addAll(testOne != null
              ? one.relations.map<Relation>((rel) {
                  return testOne[rel.field.name] != null
                      ? rel.deputy(
                          context: context ??
                              DeputyContext.create(
                                  principal: rel._nucleus.context,
                                  deputyRole: 'Cascade'),
                          testRule: testOne[rel.field.name]! as TestRelation)
                      : rel;
                })
              : one.relations);

          // descendants.addAll(testRule != null
          //     ? one.descendants.map<One>((e) => e.deputy(testRule: testRule, mapRule: mapRule)) : one.descendants);

          one.descendants.forEach(parseOne);
        }
      }

      parseRelatable(Relatable relatable) {
        if (counter-- > 0) {
          if (relatable is Many) {
            relatable.forEach(parseRelatable);
          } else if (relatable is One) {
            if (testRule != null) {
              final testOne =
                  relatable is OneBase && testRule != TestRelatable.allowAll
                      ? testRule
                      : null;
              final one = relatable.deputy(
                  context: context ??
                      DeputyContext.create(
                          principal: relatable._nucleus.context,
                          deputyRole: 'Cascade'),
                  testRule: testOne! as TestOne);
              parseOne(one);
            } else {
              parseOne(relatable);
            }
            parseOne(relatable);
          } else if (relatable is RelationField) {
            parseRelatable((relatable as RelationField).value);
          }
        }
      }

      parseRelatable(relatable);
    }

    parse(relatable);

    return (fields: fields, relations: relations, descendants: descendants);
  }

  ({Tissue<Field> fields, Tissue<Relation> relations, Tissue<One> descendants})
      _attributes(Relatable relatable,
          {TissueSet<Field>? fields,
          TissueSet<Relation>? relations,
          TissueSet<One>? descendants}) {
    final attributes = _parse(relatable, depth: depth, testRule: testRule);

    if (fields == null) {
      fields = TissueSet<Field>(
        attributes.fields,
        bind: Cell(
            bind: relatable,
            receptor: Receptor.from(rule:
                PulseRule<Cell, RelatablePost, RelatablePost>((cell, pulse,
                    {user}) {
              final body = <RelatablePulse, Iterable>{};

              for (var en in pulse.payload!.entries) {
                switch (en.key) {
                  case Relatable.oneAdded || OneAddedEvent():
                    body[Relatable.fieldAdded] = en.value
                        .map<List<Field>>(
                            (m) => m.fieldReferences.toList(growable: false))
                        .reduce((c, n) => c + n)
                        .toSet();
                    break;
                  case Relatable.oneRemoved || OneRemovedEvent():
                    body[Relatable.fieldRemoved] = en.value
                        .map<List<Field>>(
                            (m) => m.fieldReferences.toList(growable: false))
                        .reduce((c, n) => c + n)
                        .toSet();
                    break;
                  default:
                    body[en.key] = en.value;
                }
              }

              return RelatablePost._(from: pulse.from, body: body);
            }))),
      );
    } else {
      fields.addAll(attributes.fields);
    }

    if (relations == null) {
      relations = TissueSet<Relation>(
        fields.whereType<Relation>(),
        bind: Cell(
            bind: fields,
            receptor: Receptor.from(rule:
                PulseRule<Cell, RelatablePost, RelatablePost>((cell, pulse,
                    {user}) {
              final body = <RelatablePulse, Iterable>{};
              for (var en in pulse.payload!.entries) {
                switch (en.key) {
                  case Relatable.fieldAdded || FieldAddedEvent():
                    body[Relatable.relationAdded] =
                        en.value.whereType<Relation>();
                    break;
                  case Relatable.fieldRemoved || FieldRemovedEvent():
                    body[Relatable.relationRemoved] =
                        en.value.whereType<Relation>();
                    break;
                  default:
                    body[en.key] = en.value;
                }
              }
              return RelatablePost._(from: pulse.from, body: body);
            }))),
      );
    } else {
      fields.apply(fields.addAll, [attributes.fields]);
    }

    descendants ??= TissueSet<One>(
      relations
          .where((rel) => rel is! BelongsTo && rel.isNotEmpty)
          .map<List<One>>((rel) => rel.toList(growable: false))
          .reduce((c, n) => c + n)
          .toSet(),
      bind: Cell(
          bind: relations,
          receptor: Receptor.from(rule:
              PulseRule<Cell, RelatablePost, RelatablePost>((cell, pulse,
                  {user}) {
            final body = <RelatablePulse, Iterable>{};
            for (var en in pulse.payload!.entries) {
              switch (en.key) {
                case Relatable.relationAdded || RelationAddedEvent():
                  body[Relatable.oneAdded] = en.value
                      .map<List<One>>((rel) => rel.toList(growable: false))
                      .reduce((c, n) => c + n)
                      .toSet();
                  break;
                case Relatable.relationRemoved || FieldRemovedEvent():
                  body[Relatable.oneRemoved] = en.value
                      .map<List<One>>((rel) => rel.toList(growable: false))
                      .reduce((c, n) => c + n)
                      .toSet();
                  break;
                default:
                  body[en.key] = en.value;
              }
            }
            return RelatablePost._(from: pulse.from, body: body);
          }))),
    );

    return (fields: fields, relations: relations, descendants: descendants);
  }
}

class _CascadeDeputy extends CascadeBase with Deputy<Cascade> {
  _CascadeDeputy._(Cascade bind,
      {Context context = Context.system,
      required TestRelatable testRule,
      FilterRule? filter})
      : super.fromNucleus(CascadeNucleus.evolve(
          bind: bind,
          context: context,
          testRule: testRule,
          synapses: bind._nucleus.synapses != Synapses.disabled
              ? filter != null
                  ? Synapses(filter: filter)
                  : Synapses.enabled
              : Synapses.disabled,
          principal: bind._nucleus,
        ));

  @override
  Cascade deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _CascadeDeputy._(this,
        context: context,
        testRule: _nucleus.testRule + testRule,
        filter: filter);
  }
}

class _Cascade extends CascadeBase {
  _Cascade(super.relatable,
      {super.depth,
      super.bind,
      super.context,
      super.receptor,
      super.testRule,
      super.synapses})
      : super();

  @override
  Cascade deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _CascadeDeputy._(this,
        context: context, testRule: testRule, filter: filter);
  }

  @override
  Cascade get unmodifiable => _UnmodifiableCascade(this);
}

abstract class CascadeBase extends RelatableBase implements Cascade {
  @override
  CascadeNucleus get _nucleus => super._nucleus as CascadeNucleus;

  CascadeBase(Relatable relatable,
      {int depth = 8,
      Cell? bind,
      Context context = Context.system,
      RelatableReceptor receptor = RelatableReceptor.passThrough,
      TestRelatable testRule = TestRelatable.allowAll,
      Synapses synapses = Synapses.enabled})
      : this.fromNucleus(CascadeNucleus(relatable,
            depth: depth,
            context: context,
            bind: bind,
            receptor: receptor,
            testRule: testRule,
            synapses: synapses));

  CascadeBase.fromNucleus(CascadeNucleus properties) : super(properties) {
    properties.relatable._nucleus.synapses
        .link(properties.relatable, downstreamCell: this);
  }

  @override
  int get depth => _nucleus.depth;

  @override
  Relatable get relatable => _nucleus.relatable;

  @override
  TestRelatable get validate => _nucleus.testRule;

  @override
  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable}) {
    // TODO: implement toJson
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toMap({int cascade = 0}) {
    // TODO: implement toMap
    throw UnimplementedError();
  }

  @override
  Many<Relatable> operator +(Relatable other) {
    // TODO: implement +
    throw UnimplementedError();
  }
}

class _UnmodifiableCascade extends UnmodifiableCascadeBase {
  _UnmodifiableCascade(Cascade bind)
      : super(CascadeNucleus.evolve(
            bind: bind,
            testRule: bind._nucleus.testRule,
            principal: bind._nucleus));

  @override
  Cascade deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled}) {
    return _CascadeDeputy._(this,
        context: context,
        testRule: _nucleus.testRule + testRule,
        filter: filter);
  }
}

abstract class UnmodifiableCascadeBase extends CascadeBase
    with UnmodifiableRelatableMixin
    implements UnmodifiableCascade {
  UnmodifiableCascadeBase(super.properties) : super.fromNucleus();

  @override
  Cascade get unmodifiable => this;
}
