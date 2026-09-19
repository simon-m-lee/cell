// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class RelatableNucleusNever extends Nucleolus
    implements RelatableNucleusBase<Never, Never> {
  const RelatableNucleusNever();

  @override
  RelatableReceptor<Never, Never> get receptor => RelatableReceptor.passThrough;

  @override
  TestRelatable<Never, Never> get testRule => TestRelatable.allowAll;

  @override
  Tissue<One> get descendants => const TissueNever();

  @override
  Tissue<Field<One, dynamic>> get fields => const TissueNever();

  @override
  Tissue<Relation<One, One>> get relations => const TissueNever();

  @override
  RelatableNucleus get clone => this;

  @override
  RelatableNucleus? get principal => null;
}

class _RelatableNucleus<E, C extends Tissue<E>>
    extends RelatableNucleusBase<E, C> {
  _RelatableNucleus({
    super.ephemeralPolicy,
    super.bind,
    super.context,
    super.receptor,
    super.testRule = TestRelatable.allowAll,
    super.synapses,
    super.forceLock,
    super.user,
    super.fields,
    super.relations,
    super.descendants,
  }) : super();

  _RelatableNucleus.evolve(
      {Cell? bind,
      Context? context,
      RelatableReceptor? receptor,
      TestRelatable? testRule,
      Synapses? synapses,
      bool forceLock = true,
      RelatableNucleus? override,
      required super.principal})
      : super.evolve(
            override: override ??
                _RelatableNucleus.fromRecord(record: (
                  mask: NucleusBase.mask(
                      bind: bind,
                      context: context,
                      receptor: receptor,
                      testRule: testRule,
                      synapses: synapses,
                      forceLock: forceLock)
                )));

  _RelatableNucleus.fromRecord({super.record}) : super.fromRecord();

  @override
  RelatableNucleus get clone {
    final receptor = get<RelatableReceptor<E, C>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestRelatable<E, C>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _RelatableNucleus.fromRecord(record: (
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
    ));
  }
}

abstract class RelatableNucleusBase<E, C extends Tissue<E>> extends NucleusBase
    with RelatableNucleusMixin
    implements RelatableNucleus {
  RelatableNucleusBase({
    EphemeralPolicy? ephemeralPolicy,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor receptor = RelatableReceptor.passThrough,
    TestRelatable testRule = TestRelatable.allowAll,
    Synapses synapses = Synapses.enabled,
    bool forceLock = true,
    Record? user,
    RelatableNucleus? principal,
    Tissue<Field>? fields,
    Tissue<Relation>? relations,
    Tissue<One>? descendants,
  }) : super.fromRecord((
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
          )
        )) {
    if (fields != null) {
      record.relatable.fields.value = fields;
      record.relatable.relations.value = relations ??= createRelations(fields);
      record.relatable.descendants.value =
          descendants ?? createDescendants(relations);
    }
  }

  const RelatableNucleusBase.fromRecord(super.record) : super.fromRecord();

  RelatableNucleusBase.evolve(
      {super.bind,
      super.context,
      RelatableReceptor? super.receptor,
      TestRelatable? super.testRule,
      super.synapses,
      super.override,
      required RelatableNucleus super.principal})
      : super.evolve();

  @override
  RelatableNucleus? get principal {
    return get<RelatableNucleus?>(() => record.principal, orElse: null);
  }

  @override
  RelatableReceptor<E, C> get receptor =>
      super.receptor as RelatableReceptor<E, C>;

  @override
  TestRelatable<E, C> get testRule => super.testRule as TestRelatable<E, C>;

  static Tissue<Field<H, dynamic>> createFields<H extends One>(Cell cell,
      {Iterable<Field<H, dynamic>>? initialFields}) {
    final bind = Cell(
        bind: cell,
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
        })));

    return initialFields != null
        ? TissueSet<Field<H, dynamic>>(initialFields, bind: bind)
        : TissueSet<Field<H, dynamic>>.empty(bind: bind);
  }

  static Tissue<Relation<H, One>> createRelations<H extends One>(
      Tissue<Field<H, dynamic>> fields) {
    final initialRelations = fields.isNotEmpty
        ? fields.whereType<Relation<H, One>>()
        : <Relation<H, One>>[];

    final bind = Cell(
        bind: fields,
        receptor: Receptor.from(rule:
            PulseRule<Cell, RelatablePost, RelatablePost>((cell, pulse,
                {user}) {
          final body = <RelatablePulse, Iterable>{};
          for (var en in pulse.payload!.entries) {
            switch (en.key) {
              case Relatable.fieldAdded || FieldAddedEvent():
                body[Relatable.relationAdded] = en.value.whereType<Relation>();
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
        })));

    return TissueSet<Relation<H, One>>(initialRelations, bind: bind);
  }

  static Tissue<One> createDescendants<H extends One>(
      Tissue<Relation<H, dynamic>> relations) {
    final initialDescendants = relations.isNotEmpty
        ? relations
            .where((rel) => rel is! BelongsTo && rel.isNotEmpty)
            .map<List<One>>((rel) => rel.toList(growable: false).cast())
            .reduce((c, n) => c + n)
            .toSet()
        : <One>[];

    final bind = Cell(
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
        })));

    return TissueSet<One>(initialDescendants, bind: bind);
  }
}

mixin RelatableNucleusMixin on Nucleus implements RelatableNucleus {
  @override
  Tissue<Field> get fields {
    return get<Tissue<Field>>(() => record.relatable.fields.value.fields,
        fallback: () => principal?.fields, orElse: Tissue<Field>.empty());
  }

  @override
  Tissue<Relation> get relations {
    return get<Tissue<Relation>>(record.relatable.relations.value.relations,
        fallback: principal?.record.relatable.relations.value,
        orElse: Tissue<Relation>.empty());
  }

  @override
  Tissue<One> get descendants {
    return get<Tissue<One>>(record.relatable.descendants.value.relations,
        fallback: principal?.record.relatable.descendants.value,
        orElse: Tissue<One>.empty());
  }
}
