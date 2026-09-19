// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../cell_organ.dart';

typedef FieldAdded<H extends One, V> = ElementRemoved<Field>;
typedef FieldRemoved<H extends One, V> = ElementRemoved<Field>;
typedef FieldUpdated<H extends One, V> = ElementUpdated<V, Field<H, V>>;

typedef RelataionAdded<H extends One, E extends One, R extends Relation<H, E>>
    = ElementAdded<R>;
typedef RelationRemoved<H extends One, E extends One, R extends Relation<H, E>>
    = ElementRemoved<R>;
typedef RelationChanged<H extends One, E extends One, R extends Relation<H, E>>
    = ElementUpdated<R, Field<H, R>>;

typedef OneAdded = ElementAdded<One>;
typedef OneRemoved = ElementRemoved<One>;
// typedef OneChanged<O extends One> = ElementUpdated<R,Field<H,R>>;

abstract interface class EvolvedRelatablePulse<E>
    implements RelatablePulse<E>, EvolvedPulse<E> {
  @override
  RelatablePulse<E> get parent;

  CollectiveRelatablePulse operator +(covariant RelatablePulse other);
}

abstract interface class CollectiveRelatablePulse<E>
    implements RelatablePulse<Iterable<Pulse<E>>>, CollectivePulse<E> {
  @override
  Iterable<RelatablePulse<E>> get payload;

  CollectiveRelatablePulse operator +(covariant RelatablePulse other);
}

class RelatablePulseShell<E> extends PulseShell<E, RelatableReceptor>
    implements RelatablePulse<E> {
  const RelatablePulseShell._(RelatablePulseBase<E> super.kernal) : super();

  @override
  Iterator<RelatablePulse> get iterator => [this].iterator;

  @override
  RelatablePulse operator +(covariant Pulse other) {
    throw UnsupportedError('PulseShell not supported for addition.');
  }

  @override
  RelatablePulseShell<E> get shell => this;

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context}) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }

  @override
  RelatablePulse<E> get root => this;

  @override
  Relatable? get source => super.source as Relatable?;

  @override
  RelatablePulse<E> get unmodifiable => this;

  @override
  dynamic scrutinize(
      covariant RelatableReceptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]) {
    return super.scrutinize(receptor, positionalArguments, namedArguments);
  }

  @override
  RelatablePulse<E> withStep(String step) {
    throw UnsupportedError('PulseShell cannot be evolved.');
  }
}

abstract interface class RelatablePulse<E> implements Pulse<E> {
  @override
  dynamic scrutinize(covariant Receptor receptor, List? positionalArguments,
      [Map<Symbol, dynamic>? namedArguments]);

  @override
  RelatablePulseShell<E> get shell;

  @override
  RelatablePulse<E> withStep(String step);

  @override
  Relatable? get source;

  @override
  RelatablePulse<E> get root;

  @override
  RelatablePulse evolve(
      {Pulse? pulse, String? step, covariant PulseContext? context});

  @override
  RelatablePulse<E> get unmodifiable;

  @override
  RelatablePulse operator +(covariant RelatablePulse other);
}

abstract interface class UnmodifiableRelatablePulse<E>
    implements RelatablePulse<E>, UnmodifiablePulse<E> {
  RelatablePulse operator +(covariant RelatablePulse other);
}

/*



final class RelationAddedPulse extends RelatablePulse implements ElementAddedPulse {
  const RelationAddedPulse._() : super._(identifier: #RelationAdded);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementAdded)
        ? true : super == other;
  }

}

final class RelationRemovedPulse extends RelatablePulse implements ElementRemovedPulse {
  const RelationRemovedPulse._() : super._(identifier: #RelationRemoved);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementRemoved)
        ? true : super == other;
  }

}

final class RelationChangedPulse extends RelatablePulse implements ElementUpdatedPulse {
  const RelationChangedPulse._() : super._(identifier: #RelationChanged);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementRemoved)
        ? true : super == other;
  }

}

final class OneAddedPulse extends RelatablePulse implements ElementAddedPulse {
  const OneAddedPulse._() : super._(identifier: #ModelAdded);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementAdded)
        ? true : super == other;
  }
}


final class OneRemovedPulse extends RelatablePulse implements ElementRemovedPulse {
  const OneRemovedPulse._() : super._(identifier: #ModelRemoved);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementRemoved)
        ? true : super == other;
  }
}

final class OneChangedPulse extends RelatablePulse implements ElementUpdatedPulse {
  const OneChangedPulse._() : super._(identifier: #FieldChanged);

  @override
  // ignore: hash_and_equals
  bool operator ==(Object other) {
    return identical(other, Relatable.elementUpdated)
        ? true : super == other;
  }
}

*/
