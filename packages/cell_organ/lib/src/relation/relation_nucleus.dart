// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

abstract interface class RelationNucleus<H extends One, E extends One,
    R extends Relation<H, E>> implements RelatableNucleus, TissueNucleus<E> {
  @override
  RelationNucleus<H, E, R>? get principal;

  @override
  TestRelation<H, E, R> get testRule;

  @override
  RelatableReceptor<E, R> get receptor;

  RelationNucleus<H, E, R> get clone;
}
