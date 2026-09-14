// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../../../cell_organ.dart';

class _TestFieldNever implements TestField<Never, Never, Never>, TestPasses {
  const _TestFieldNever();

  @override
  TestField<Never, Never, Never> operator +(covariant TestRule<dynamic> other) {
    return this;
  }

  @override
  Nucleus get _record => const Nucleolus();

  @override
  bool action(Function action, {required Cell host, Arguments? arguments}) {
    return true;
  }

  @override
  bool call(object, {covariant Tissue<Never>? host, arguments}) {
    return true;
  }

  @override
  bool element(covariant Never? element,
      {required Tissue<Never> host, Function? action}) {
    return true;
  }

  @override
  bool link(covariant Cell link, {required Cell host}) {
    return false;
  }

  @override
  bool pulse(covariant Pulse<dynamic> pulse, {required Cell host}) {
    return true;
  }
}

abstract class FieldBase<H extends One, V> extends CellBase
    implements Field<H, V> {
  final FieldNucleus<H, V> _nucleus;

  FieldBase(FieldNucleus<H, V> properties, {V? value}) : _nucleus = properties {
    // if (value != null) {
    //   _nucleus.container.init(value);
    //   if (value is Cell) {
    //     _nucleus.synapses.link(value, downstreamPole: this);
    //   }
    // }
  }

  @override
  Field<H, V> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestRelatable testRule = TestRelatable.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  });

  @override
  Symbol get name => _nucleus.name;

  @override
  V? get value => _nucleus.value;

  @override
  H get has => _nucleus.has;
}

abstract class UnmodifiableFieldBase<H extends One, V> extends FieldBase<H, V>
    implements UnmodifiableField<H, V> {
  UnmodifiableFieldBase(super.properties) : super();

  @override
  H get has => _nucleus.has.unmodifiable as H;

  @override
  Symbol get name => (_nucleus.bind as Field<H, V>).name;

  @override
  V? get value => (_nucleus.bind as Field<H, V>).value;

  @override
  Field<H, V> get unmodifiable => this;
}

final class _FieldNever extends IterableBase<Never>
    with TissueValueMixin<Never, TissueValue<Never>>
    implements Field<Never, Never> {
  const _FieldNever({required TestField testRule});

  @override
  Never? get value => null;

  @override
  apply(Function function, List<dynamic>? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {}

  @override
  Never get has => throw UnsupportedError('message');

  @override
  Iterator<Never> get iterator => const Iterable<Never>.empty().iterator;

  @override
  Iterable<Function> get modifiable => const Iterable<Function>.empty();

  @override
  Symbol get name => #Never;

  @override
  Field<Never, Never> get unmodifiable => this;

  @override
  TestField<Never, Never, Field<Never, Never>> get validate => TestField.allowAll;

  @override
  Field<Never, Never> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestField<Never, Never, Field<Never, Never>> testRule =
        TestField.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) {
    return this;
  }

  @override
  ModifiableValueAsync<Never> get async => ModifiableValueAsync<Never>(this);

  @override
  Context get context => Context.system;

  @override
  bool get isTerminal => true;

  @override
  bool get isNotTerminal => !isTerminal;
}
