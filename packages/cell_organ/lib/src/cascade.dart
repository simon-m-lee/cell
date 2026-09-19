// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

abstract interface class CascadeNucleus implements RelatableNucleus {
  factory CascadeNucleus(
    Relatable relatable, {
    Cell? bind,
    Context context,
    RelatableReceptor receptor,
    TestRelatable testRule,
    Synapses synapses,
    Record? user,
    int depth,
  }) = _CascadeNucleus;

  factory CascadeNucleus.evolve({
    Cell? bind,
    Context? context,
    RelatableReceptor? receptor,
    TestRelatable? testRule,
    Synapses? synapses,
    CascadeNucleus? override,
    required CascadeNucleus principal,
  }) = _CascadeNucleus.evolve;

  @override
  CascadeNucleus? get principal;

  Relatable get relatable;

  int get depth;

  @override
  CascadeNucleus get clone;
}

abstract interface class Cascade implements Relatable {
  @override
  CascadeNucleus get _nucleus;

  factory Cascade(
    Relatable relatable, {
    int depth,
    Cell? bind,
    Context context,
    TestRelatable testRule,
    RelatableReceptor receptor,
    Synapses synapses,
  }) = _Cascade;

  static Cascade fromMap<E extends Relatable>(Map<String, dynamic> map,
      {int cascade = 8, Set<One>? lookup}) {
    throw UnimplementedError();
  }

  static Cascade fromJson<E extends Relatable>(String json,
      {int cascade = 8, Set<One>? lookup}) {
    return fromMap(jsonDecode(json) as Map<String, dynamic>,
        cascade: cascade, lookup: lookup);
  }

  @override
  Cascade deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  int get depth;

  Relatable get relatable;

  @override
  Cascade get unmodifiable;
}

abstract interface class UnmodifiableCascade implements Cascade, Unmodifiable {}
