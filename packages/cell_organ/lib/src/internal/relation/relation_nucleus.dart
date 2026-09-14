// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

abstract class RelationNucleusBase<H extends One, E extends One,
        R extends Relation<H, E>> extends RelatableNucleusBase<E, R>
    implements TissueNucleus<E>, RelationNucleus<H, E, R> {
  RelationNucleusBase(
      {TissueNucleus<E>? base,
      RelationField<H, E, R>? field,
      dynamic containerInit})
      : super.fromRecord(record: (
          mask: (base ?? TissueNucleus<E>()).record.mask,
          relatable: (
            fields: FinalBox<Tissue<Field>>(),
            relations: FinalBox<Tissue<Relation>>(),
            descendants: FinalBox<Tissue<One>>()
          ),
          relation: (field: FinalBox<RelationField<H, E, R>>()..value = field)
        )) {
    if (containerInit != null) {
      record.mask.container.init(containerInit);
    }

    if (field != null) {
      final fields = RelatableNucleusBase.createFields(field,
          initialFields: field.value.fields);
      record.relatable.fields.value = fields;
      final relations = RelatableNucleusBase.createRelations(fields);
      record.relatable.relations.value = relations;
      record.relatable.descendants.value =
          RelatableNucleusBase.createDescendants(relations);
    }
  }

  RelationNucleusBase.fromRecord({super.record}) : super.fromRecord();

  RelationNucleusBase.evolve(
      {super.bind,
      super.context,
      RelatableReceptor<E, R>? super.receptor,
      TestRelation<H, E, R>? super.testRule,
      super.synapses,
      super.override,
      required RelationNucleus<H, E, R> super.principal})
      : super.evolve();

  @override
  RelationNucleusBase<H, E, R>? get principal =>
      super.principal as RelationNucleusBase<H, E, R>?;

  RelationField<H, E, R> get field {
    final field = get<RelationField<H, E, R>>(record.relation.field.value,
        fallback: principal!.record.relation.field.value);
    return field.value is Unmodifiable ? field.unmodifiable : field;
  }

  @override
  TestRelation<H, E, R> get testRule {
    return get<TestRelation<H, E, R>>(record.mask.testRule,
        fallback: principal!.record.mask.testRule, orElse: TestRelation.allowAll);
  }

  @override
  RelatableReceptor<E, R> get receptor {
    return get<RelatableReceptor<E, R>>(record.mask.receptor,
        fallback: principal!.record.mask.receptor,
        orElse: RelatableReceptor.passThrough);
  }

  @override
  RelationNucleus<H, E, R> get clone;
}
