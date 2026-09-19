// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

abstract interface class ManyNucleus<E extends Relatable>
    implements RelatableNucleus, TissueSetNucleus<E> {
  factory ManyNucleus(
      {Cell? bind,
      Context context,
      RelatableReceptor<E, Many<E>> receptor,
      TestRelatable<E, Many<E>> testRule,
      Synapses synapses,
      Record? user}) = _ManyNucleus<E, Many<E>>;

  factory ManyNucleus.evolve({
    Cell? bind,
    Context context,
    RelatableReceptor<E, Many<E>> receptor,
    TestRelatable<E, Many<E>> testRule,
    Synapses synapses,
    ManyNucleus<E>? override,
    required ManyNucleus<E> principal,
  }) = _ManyNucleus<E, Many<E>>.evolve;

  static ManyNucleus<E> create<E extends Relatable, C extends Many<E>>(
      {Cell? bind,
      Context context = Context.system,
      RelatableReceptor<E, C> receptor = RelatableReceptor.passThrough,
      TestRelatable<E, C> testRule = TestRelatable.allowAll,
      Synapses synapses = Synapses.enabled,
      bool identitySet = false,
      Record? user}) {
    return _ManyNucleus<E, C>(
        bind: bind,
        context: context,
        receptor: receptor,
        testRule: testRule,
        synapses: synapses,
        identitySet: identitySet,
        user: user);
  }

  @override
  TestRelatable get testRule;

  @override
  RelatableReceptor get receptor;

  @override
  ManyNucleus<E>? get principal;

  ManyNucleus<E> get clone;
}
