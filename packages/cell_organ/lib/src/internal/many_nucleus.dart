// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

class _ManyNucleus<E extends Relatable, C extends Many<E>>
    extends ManyNucleusBase<E, C> {
  _ManyNucleus(
      {super.bind,
      super.context,
      super.receptor,
      super.testRule,
      super.synapses,
      super.identitySet = false,
      super.user})
      : super(forceLock: false);

  _ManyNucleus.evolve(
      {Container? container,
      Cell? bind,
      Context? context,
      RelatableReceptor<E, C>? receptor,
      TestRelatable<E, C>? testRule,
      Synapses? synapses,
      bool forceLock = true,
      ManyNucleus<E>? override,
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

  _ManyNucleus.fromRecord({super.record}) : super.fromRecord();

  @override
  ManyNucleus<E> get clone {
    final receptor = get<RelatableReceptor<E, C>?>(
        () => record.mask.inheritable.receptor,
        orElse: null);
    final testRule = get<TestRelatable<E, C>?>(
        () => record.mask.inheritable.testRule,
        orElse: null);
    final context =
        get<Context?>(() => record.mask.inheritable.context, orElse: null);
    return _ManyNucleus<E, C>.fromRecord(record: (
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

abstract class ManyNucleusBase<E extends Relatable, C extends Many<E>>
    extends TissueSetNucleusBase<E, C>
    with RelatableNucleusMixin
    implements ManyNucleus<E> {
  ManyNucleusBase({
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, C> receptor = RelatableReceptor.passThrough,
    TestRelatable<E, C> testRule = TestRelatable.allowAll,
    Synapses synapses = Synapses.enabled,
    bool identitySet = false,
    bool forceLock = false,
    Record? user,
    Tissue<Field>? fields,
    Tissue<Relation>? relations,
    Tissue<One>? descendants,
  }) : super.fromRecord(
            record: fields != null
                ? (
                    mask: TissueNucleusBase.local<E, Set<E>, C>(
                      bind: bind,
                      context: context,
                      receptor: receptor,
                      testRule: testRule,
                      synapses: synapses,
                      container: identitySet ? Container.identitySet : null,
                      forceLock: forceLock,
                      user: user,
                    ),
                    relatable: (
                      fields: FinalBox<Tissue<Field>>(),
                      relations: FinalBox<Tissue<Relation>>(),
                      descendants: FinalBox<Tissue<One>>()
                    )
                  )
                : (
                    mask: TissueNucleusBase.local<E, Set<E>, C>(
                      bind: bind,
                      context: context,
                      receptor: receptor,
                      testRule: testRule,
                      synapses: synapses,
                      container: identitySet ? Container.identitySet : null,
                      forceLock: forceLock,
                      user: user,
                    )
                  )) {
    if (fields != null) {
      record.relatable.fields.value = fields;
      record.relatable.relations.value =
          relations ??= RelatableNucleusBase.createRelations(fields);
      record.relatable.descendants.value =
          descendants ?? RelatableNucleusBase.createDescendants(relations);
    }
  }

  const ManyNucleusBase.fromRecord({super.record}) : super.fromRecord();

  ManyNucleusBase.evolve(
      {super.override, required ManyNucleus<E> super.principal})
      : super.evolve();

  @override
  ManyNucleusBase<E, C>? get principal =>
      super.principal as ManyNucleusBase<E, C>?;

  @override
  TissueContainer<E, Set<E>> get container {
    return get<TissueContainer<E, Set<E>>>(() => record.mask.container,
        fallback: () => principal?.container);
  }

  @override
  TestRelatable<E, C> get testRule {
    return get<TestRelatable<E, C>>(record.mask.testRule,
        fallback: principal?.record.mask.testRule,
        orElse: TestRelatable.allowAll);
  }

  @override
  RelatableReceptor<E, C> get receptor {
    return get<RelatableReceptor<E, C>>(record.mask.receptor,
        fallback: principal?.record.mask.receptor,
        orElse: RelatableReceptor.passThrough);
  }
}
