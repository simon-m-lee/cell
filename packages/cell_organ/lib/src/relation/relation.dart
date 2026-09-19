// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_organ.dart';

abstract interface class Relation<H extends One, E extends One>
    implements Relatable, Tissue<E> {
  Field<H, Relation<H, E>> get field;

  H get has;

  Type get elementType;

  @override
  Relation<H, E> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelation<H, E, Relation<H, E>> testRule =
          TestRelation.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  TestRelation<H, E, Relation<H, E>> get validate;
}

abstract class Has<H extends One, E extends One> implements Relation<H, E> {}
