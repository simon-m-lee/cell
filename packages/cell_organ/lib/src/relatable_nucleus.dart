// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

abstract interface class RelatableNucleus implements Nucleus {
  factory RelatableNucleus({
    Cell? bind,
    Context context,
    RelatableReceptor receptor,
    TestRelatable testRule,
    Synapses synapses,
    Record? user,
    Tissue<Field>? fields,
    Tissue<Relation>? relations,
    Tissue<One>? descendants,
  }) = _RelatableNucleus;

  factory RelatableNucleus.evolve({
    Cell? bind,
    Context? context,
    RelatableReceptor? receptor,
    TestRelatable? testRule,
    Synapses? synapses,
    RelatableNucleus? override,
    required RelatableNucleus principal,
  }) = _RelatableNucleus.evolve;

  @override
  RelatableNucleus? get principal;

  Tissue<Field> get fields;

  Tissue<Relation> get relations;

  Tissue<One> get descendants;

  @override
  RelatableReceptor get receptor;

  @override
  TestRelatable get testRule;

  @override
  RelatableNucleus get clone;
}
