// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

abstract interface class Relatable implements Cell {
  RelatableNucleus get _nucleus;

  const factory Relatable.model(
      {TestRule? testRule, RelatableReceptor? receptor}) = RelatableNever;

  @override
  TestRelatable get validate;

  Tissue<Field> get fields;

  Tissue<Relation> get relations;

  Tissue<One> get descendants;

  // @override
  // Relatable deputy({
  //     covariant DeputyContext context = DeputyContext.system,
  //     covariant TestRelatable testRule = TestRelatable.allowAll,
  //     EphemeralPolicy? ephemeralPolicy,
  //     Synapses synapses = Synapses.enabled
  //   });

  Map<String, dynamic> toMap({int cascade = 0});

  String toJson(
      {int cascade = 0, String? Function(Object? nonEncodable)? toEncodable});

  Many<Relatable> operator +(Relatable other);
}

abstract interface class UnmodifiableRelatable
    implements Relatable, Unmodifiable {}
