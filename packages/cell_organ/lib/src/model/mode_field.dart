// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../model.dart';























































abstract class ModelValueField<H extends Model, V> extends ValueField<H,V> {

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelValueField(H has, FieldReference<H,V> fieldReference, {
    V? value,
    Context context = Context.system,
    RelatableReceptor<V,ModelValueField<H,V>> receptor = RelatableReceptor.passThrough,
    TestValue<H,V> testRule = TestValue.allowAll,
  }) : this.fromNucleus(
      ValueFieldNucleus<H,V>(has, fieldReference.name,
        bind: has,
        receptor: receptor,
        testRule: testRule,
      ), value: value
  );

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelValueField.fromNucleus(super.properties, {super.value})
      : super.fromNucleus();

  @override
  ValueField<H,V> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestValue<H,V> testRule = TestValue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  @override
  ValueField<H,V> get unmodifiable;

}


































































abstract class ModelRelationField<H extends Model, E extends Model, R extends Relation<H,E>>
    extends RelationField<H,E,R> {

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelRelationField(H has, FieldReference<H,R> fieldReference, {
    R? relation,
    Context context = Context.system,
  }) : this.fromNucleus(RelationFieldNucleus<H,E,R>(has, fieldReference.name,
    bind: has,
    context: context,
  ), fieldReference: fieldReference);

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelRelationField.fromNucleus(super.properties, {FieldReference<H,R>? fieldReference, super.relation})
      : super.fromNucleus();

  // {
  //   if (fieldReference != null) {
  //     final relation = fieldReference.instantiator(this) as R;
  //     _nucleus.container.init(relation);
  //   }
  // }

  @override
  RelationField<H,E,R> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H,E,R> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  @override
  RelationField<H,E,R> get unmodifiable;

}
