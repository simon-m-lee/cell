// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../cell_organ.dart';

abstract class FieldNucleusBase<H extends One, V> extends NucleusBase
    implements FieldNucleus<H, V> {
  FieldNucleusBase({
    required TissueNucleusBase<V, ValueContainer<V>, Field<H, V>> local,
    required H has,
    required Symbol name,
    V? value,
  }) : super.fromRecord(record: (
          mask: local.record,
          field: (
            has: FinalBox<H>()..value = has,
            name: FinalBox<Symbol>()..value = name
          )
        )) {
    if (value != null) {
      container.store.value = value;
    }
  }

  FieldNucleusBase.evolve(
      {super.override, required FieldNucleus<H, V> super.principal})
      : super.evolve();

  FieldNucleusBase.fromRecord({super.record}) : super.fromRecord();

  @override
  FieldNucleusBase<H, V>? get principal =>
      super.principal as FieldNucleusBase<H, V>?;

  @override
  Symbol get name => get<Symbol>(() => record.field.name.value,
      fallback: () => principal!.name);

  @override
  H get has =>
      get<H>(() => record.field.has.value, fallback: () => principal!.has);

  @override
  TissueContainer<V, ValueContainer<V>> get container =>
      get<TissueContainer<V, ValueContainer<V>>>(() => record.mask.container,
          fallback: () => record.principal.container);

  @override
  V? get value => container.store.value;

  @override
  TestField<H, V, Field<H, V>> get testRule {
    return get<TestField<H, V, Field<H, V>>>(() => record.mask.testRule,
        fallback: () => principal?.testRule, orElse: TestField.allowAll);
  }

  @override
  RelatableReceptor get receptor =>
      get<RelatableReceptor>(() => record.mask.receptor,
          fallback: () => principal?.receptor,
          orElse: RelatableReceptor.passThrough);
}
