// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// ignore_for_file: prefer_mixin
// ignore_for_file: unnecessary_lambdas
// ignore_for_file: hash_and_equals
// ignore_for_file: unused_element, unused_field

part of '../cell_organ.dart';

abstract interface class Many<E extends Relatable>
    implements TissueSet<E>, Relatable {
  @override
  ManyNucleus<E> get _nucleus;

  factory Many(Iterable<E> relatables,
      {Relatable? bind,
      Context context,
      TestRelatable<E, Many<E>> testRule,
      RelatableReceptor<E, Many<E>> receptor,
      Synapses synapses,
      bool identitySet}) = _Many<E, Many<E>>;

  factory Many.empty(
      {Relatable? bind,
      Context context,
      TestRelatable<E, Many<E>> testRule,
      RelatableReceptor<E, Many<E>> receptor,
      Synapses synapses,
      bool identitySet}) = _Many<E, Many<E>>.empty;

  factory Many.fromNucleus(ManyNucleus<E> properties,
      {Iterable<E>? relatables}) = _Many<E, Many<E>>.fromNucleus;

  factory Many.unmodifiable(Many<E> bind, {bool unmodifiableElement}) =
      _UnmodifiableMany<E, Many<E>>.bind;

  static Many<E> fromMap<E extends Relatable>(Map<String, dynamic> map,
      {int cascade = 0, Set<One>? lookup}) {
    // Implementation details handled internally...
    final many = Many<E>.empty();
    // ...
    return many;
  }

  static Many<T> fromJson<T extends Relatable>(String json,
      {int cascade = 0, Set<One>? lookup}) {
    return fromMap<T>(jsonDecode(json) as Map<String, dynamic>,
        cascade: cascade, lookup: lookup);
  }

  Many<E> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  Many<Relatable> operator +(Relatable other);

  @override
  Many<E> get unmodifiable;

  @override
  TestRelatable get validate;
}

abstract interface class UnmodifiableMany<E extends Relatable>
    implements Many<E>, Unmodifiable {
  @override
  ManyNucleus<E> get _nucleus;

  factory UnmodifiableMany(
      {Iterable<E>? relatables,
      bool unmodifiableElement = true,
      Relatable? bind,
      TestRelatable<E, Many<E>> testRule = TestRelatable.allowAll,
      RelatableReceptor<E, Many<E>> receptor = RelatableReceptor.passThrough,
      Synapses synapses = Synapses.enabled,
      bool identitySet = false}) {
    return _UnmodifiableMany<E, Many<E>>.fromNucleus(
        ManyNucleus<E>(
            bind: bind,
            testRule: testRule,
            receptor: receptor,
            synapses: synapses),
        unmodifiableElement: unmodifiableElement,
        relatables: relatables);
  }

  factory UnmodifiableMany.fromNucleus(ManyNucleus<E> properties,
      {Iterable<E>? relatables,
      bool unmodifiableElement}) = _UnmodifiableMany<E, Many<E>>.fromNucleus;

  @override
  Many<E> deputy(
      {covariant DeputyContext context = DeputyContext.system,
      covariant TestRelatable<E, Many<E>> testRule = TestRelatable.allowAll,
      EphemeralPolicy? ephemeralPolicy,
      Synapses synapses = Synapses.enabled});

  @override
  TestRelatable get validate;

  @override
  Many<E> get unmodifiable;
}
