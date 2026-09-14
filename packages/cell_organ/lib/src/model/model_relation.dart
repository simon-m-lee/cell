// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../model.dart';




























































abstract class ModelHasOne<H extends Model, E extends Model> extends HasOne<H,E> {

  // ignore: unused_field
  final RelationOneNucleus<H,E,HasOne<H,E>> _nucleus;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelHasOne(RelationField<H,E,HasOne<H,E>> field, {
    E? one,

    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E,HasOne<H,E>> receptor = RelatableReceptor.passThrough,
    TestRelation<H,E,HasOne<H,E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled
  }) : this.fromNucleus(RelationOneNucleus<H,E,HasOne<H,E>>(
      field: field,
      bind: bind,
      context: context,
      testRule: testRule,
      receptor: receptor,
      synapses: synapses
  ), field: field, one: one);



  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelHasOne.fromNucleus(super.properties, {
    required super.field,
    super.one
  }) : _nucleus = properties, super.fromNucleus();


  @override
  HasOne<H,E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H,E,HasOne<H,E>> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  @override
  HasOne<H,E> get unmodifiable;

}



















































abstract class ModelHasMany<H extends Model, E extends Model> extends HasMany<H,E> {

  
  
  // ignore: unused_field
  final RelationManyNucleus<H,E,HasMany<H,E>> _nucleus;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelHasMany(RelationField<H,E,HasMany<H,E>> field, {
    Iterable<E>? elements,

    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E,HasMany<H,E>> receptor = RelatableReceptor.passThrough,
    TestRelation<H,E,HasMany<H,E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled
  }) : this.fromNucleus(RelationManyNucleus<H,E,HasMany<H,E>>(
      field: field,
      bind: bind,
      context: context,
      testRule: testRule,
      receptor: receptor,
      synapses: synapses
  ), field: field, elements: elements);

  
  
  
  
  
  
  
  
  
  ModelHasMany.fromNucleus(super.properties, {
    required super.field,
    super.elements
  }) : _nucleus = properties, super.fromNucleus();

  
  
  
  
  
  
  
  
  @override
  HasMany<H,E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H,E,HasMany<H,E>> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  
  
  
  
  
  
  @override
  HasMany<H,E> get unmodifiable;

}

































abstract class ModelManyToMany<H extends Model, E extends Model> extends ManyToMany<H,E> {

  
  
  
  
  
  
  // ignore: unused_field
  final RelationManyNucleus<H,E,ManyToMany<H,E>> _nucleus;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelManyToMany(RelationField<H, E, ManyToMany<H, E>> field, {
    Iterable<E>? elements,
    Cell? bind,
    Context context = Context.system,
    RelatableReceptor<E, ManyToMany<H, E>> receptor = RelatableReceptor.passThrough,
    TestRelation<H, E, ManyToMany<H, E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled,
  }) : this.fromNucleus(RelationManyNucleus<H, E, ManyToMany<H, E>>(
    field: field,
    bind: bind,
    context: context,
    testRule: testRule,
    receptor: receptor,
    synapses: synapses,
  ), field: field, elements: elements);

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelManyToMany.fromNucleus(super.properties, {
    required super.field,
    super.elements,
  }) : _nucleus = properties, super.fromNucleus();

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  ManyToMany<H, E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H,E,ManyToMany<H,E>> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  ManyToMany<H, E> get unmodifiable;

}

























































abstract class ModelBelongsTo<H extends Model, E extends Model> extends BelongsTo<H,E> {

  
  
  
  
  
  
  
  
  
  
  // ignore: unused_field
  final RelationOneNucleus<H,E,BelongsTo<H,E>> _nucleus;

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelBelongsTo(RelationField<H,E,BelongsTo<H,E>> field, {
    Context context = Context.system,
    RelatableReceptor<E,BelongsTo<H,E>> receptor = RelatableReceptor.passThrough,
    TestRelation<H,E,BelongsTo<H,E>> testRule = TestRelation.allowAll,
    Synapses synapses = Synapses.enabled
  }) : this.fromNucleus(RelationOneNucleus<H,E,BelongsTo<H,E>>(
      field: field,

      context: context,
      testRule: testRule,
      receptor: receptor,
      synapses: synapses
  ), field: field);

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  ModelBelongsTo.fromNucleus(super.properties, {
    required super.field
  }) : _nucleus = properties, super.fromNucleus();

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @override
  BelongsTo<H,E> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelation<H,E,BelongsTo<H,E>> testRule = TestRelation.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled
  });

}