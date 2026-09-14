// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

/// Resolves the [FutureOr] returned by [Tissue.deputy] into a [Tissue].
Future<Tissue<T>> resolveDeputy<T>(Tissue<T> source) async {
  final result = source.deputy();
  return result is Future<Tissue<T>> ? await result : result;
}

/// A minimal [TissueBase] subclass used to exercise the base-class members
/// (`==`, `hashCode`, `iterator`, `toString`) that are shadowed by
/// [UnmodifiableTissueBase] or [ListMixin] in the standard implementations.
class _DirectTissue<E> extends TissueBase<E, Iterable<E>, Tissue<E>> {
  _DirectTissue(Iterable<E> elements)
      : super(
          TissueNucleus.create<E, Iterable<E>, Tissue<E>>(
            container: Container.iterable,
          ),
          elements: elements,
        );

  @override
  Tissue<E> get unmodifiable => this;

  @override
  TestTissue get validate => TestTissue.allowAll;

  @override
  FutureOr<Tissue<E>> deputy({
    covariant DeputyContext context = DeputyContext.system,
    covariant TestTissue testRule = TestTissue.allowAll,
    EphemeralPolicy? ephemeralPolicy,
    Synapses synapses = Synapses.enabled,
  }) =>
      this;
}

void main() {
  group('Tissue primary factory', () {
    test('creates a populated iterable tissue', () {
      final t = Tissue<int>([1, 2, 3]);

      expect(t.toList(), [1, 2, 3]);
      expect(t.length, 3);
      expect(t.first, 1);
      expect(t.last, 3);
      expect(t.elementAt(1), 2);
      expect(t.isEmpty, isFalse);
      expect(t.isNotEmpty, isTrue);
    });

    test('delegates iterable operations to the container', () {
      final t = Tissue<int>([1, 2, 3]);

      expect(t.cast<num>().toList(), [1, 2, 3]);
      expect(t.map((e) => e * 2).toList(), [2, 4, 6]);

      final collected = <int>[];
      t.forEach(collected.add);
      expect(collected, [1, 2, 3]);
    });

    test('exposes cell governance metadata', () {
      final t = Tissue<int>([1, 2, 3]);

      expect(t.validate, same(TestTissue.allowAll));
      expect(t.context, Context.system);
      expect(t.isTerminal, isFalse);
      expect(t.isInvalidated, isFalse);
      expect(t.isGoverned, isFalse);
    });

    test('unmodifiable of a mutable _Tissue returns itself', () {
      final t = Tissue<int>([1, 2, 3]);

      expect(identical(t, t.unmodifiable), isTrue);
      expect(t.unmodifiable.toList(), [1, 2, 3]);
    });

    test('modifiable manifest is empty and async handle is available', () {
      final t = Tissue<int>([1, 2, 3]);

      expect(t.modifiable.toList(), isEmpty);
      expect(t.async, isA<TissueModifiableAsync<int, Tissue<int>>>());
    });

    test('structural equality, hashCode and toString', () {
      final t = Tissue<int>([1, 2, 3]);
      final same = Tissue<int>([1, 2, 3]);
      final different = Tissue<int>([1, 2, 4]);

      expect(t == t, isTrue);
      expect(t == same, isTrue);
      expect(t == ([1, 2, 3] as Object), isTrue);
      expect(t == different, isFalse);
      expect(t == ([1, 2, 4] as Object), isFalse);
      expect(identical(t, 42), isFalse);
      expect(t.hashCode, same.hashCode);
      expect(t.toString(), contains('1'));
      expect(t.toString(), contains('2'));
      expect(t.toString(), contains('3'));
    });

    test('auto-links initial elements that are cells', () {
      final cell = Cell.state<int>(initial: 7).cell;
      final t = Tissue<Cell>([cell]);

      expect(t.toList(), [cell]);
      expect(t.length, 1);
    });
  });

  group('Tissue.governed', () {
    test('creates a governed tissue with a custom validation rule', () {
      final rule = TestTissue<int, Tissue<int>>(
        (object, {host, arguments, user}) => (object as int) > 0,
      );
      final t = Tissue<int>.governed(
        [1, 2],
        context: Context.system,
        testRule: rule,
      );

      expect(t.toList(), [1, 2]);
      expect(t.validate, same(rule));
    });

    test('accepts a custom receptor and synapses', () {
      final t = Tissue<int>.governed(
        [5],
        context: Context.system,
        receptor: TissueReceptor.passThrough,
        synapses: Synapses.enabled,
      );

      expect(t.toList(), [5]);
      expect(t.isTerminal, isFalse);
    });
  });

  group('Tissue.empty', () {
    test('default empty returns a mutable empty _Tissue', () {
      final t = Tissue<int>.empty();

      expect(t.toList(), isEmpty);
      expect(t.length, 0);
      expect(t.validate, same(TestTissue.allowAll));
    });

    test('empty with a bind creates an empty bound tissue', () {
      final cell = Cell.state<int>(initial: 42).cell;
      final t = Tissue<int>.empty(bind: cell);

      expect(t.toList(), isEmpty);
      expect(t.validate, same(TestTissue.allowAll));
    });

    test('empty with disabled synapses returns the TissueNever sentinel', () {
      final t = Tissue<int>.empty(synapses: Synapses.disabled);

      expect(t.runtimeType.toString(), 'TissueNever');
      expect(t.toList(), isEmpty);
      expect(t.length, 0);
    });
  });

  group('TissueNever sentinel', () {
    late Tissue<int> empty;

    setUp(() {
      empty = Tissue<int>.empty(synapses: Synapses.disabled);
    });

    test('reports terminal and invalidated state', () {
      expect(empty.isTerminal, isTrue);
      expect(empty.isInvalidated, isTrue);
      expect(empty.isGoverned, isFalse);
      expect(empty.context, Context.system);
      expect(empty.validate, same(TestTissue.allowAll));
    });

    test('modifiable is empty and unmodifiable returns itself', () {
      expect(empty.modifiable.toList(), isEmpty);
      expect(identical(empty, empty.unmodifiable), isTrue);
    });

    test('apply is a no-op returning null', () {
      expect(empty.apply((x) => x), isNull);
    });

    test('deputy returns itself', () {
      expect(empty.deputy(), same(empty));
    });

    test('async handle is available', () {
      expect(empty.async, isA<ModifiableAsync<Cell>>());
    });

    test('iterator yields nothing', () {
      expect(empty.iterator.moveNext(), isFalse);
    });

    test('operator + returns the other operand', () {
      final never = empty as dynamic;
      final other = Tissue<int>([1]);

      expect(identical(never + empty, empty), isTrue);
      expect(identical(never + other, other), isTrue);
    });
  });

  group('Tissue.fromNucleus and Tissue.create', () {
    test('fromNucleus populates initial elements', () {
      final nucleus = TissueNucleus.create<int, Iterable<int>, Tissue<int>>(
        container: Container.iterable,
      );
      final t = Tissue<int>.fromNucleus(nucleus, elements: [7, 8]);

      expect(t.toList(), [7, 8]);
      expect(t.first, 7);
    });

    test('create builds a tissue from explicit parameters', () {
      final t = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );

      expect(t.toList(), [4, 5]);
      expect(t.length, 2);
    });

    test('create without elements builds an empty tissue', () {
      final t = Tissue.create<int, Iterable<int>, Tissue<int>>(
        container: Container.iterable,
      );

      expect(t.toList(), isEmpty);
    });
  });

  group('Tissue.deputy', () {
    test('creates a deputy sharing the principal storage', () async {
      final source = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(deputy.toList(), [4, 5]);
      expect(deputy == source, isTrue);
      expect(source == deputy, isTrue);
    });

    test('creates nested deputies', () async {
      final source = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(nested.toList(), [4, 5]);
      expect(nested == source, isTrue);
      expect(nested == deputy, isTrue);
    });
  });

  group('Tissue.unmodifiable (view)', () {
    test('creates a live read-only projection sharing storage', () {
      final source = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );
      final view = Tissue<int>.unmodifiable(source);

      expect(view.runtimeType.toString(), contains('UnmodifiableTissue'));
      expect(view.toList(), [4, 5]);
      expect(view.modifiable.toList(), isEmpty);
      expect(view == source, isTrue);
      expect(source == view, isTrue);
      expect(view == ([4, 5] as Object), isTrue);
      expect(view == ([9, 9] as Object), isFalse);
      expect(identical(view, 42), isFalse);
      expect(view.validate, same(TestTissue.allowAll));
      expect(identical(view, view.unmodifiable), isTrue);
    });

    test('projects child cells as unmodifiable elements', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final source = Tissue<Cell>([cell]);
      final view = Tissue<Cell>.unmodifiable(source);

      final projected = view.toList().single;
      expect(identical(projected, cell), isFalse);
    });

    test('view with unmodifiableElement false still shares storage', () {
      final source = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );
      final view =
          UnmodifiableTissue<int>.view(source, unmodifiableElement: false);

      expect(view.toList(), [4, 5]);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = Tissue.create<int, Iterable<int>, Tissue<int>>(
        elements: [4, 5],
        container: Container.iterable,
      );
      final view = Tissue<int>.unmodifiable(source);
      final deputy = await resolveDeputy(view);

      expect(deputy.toList(), [4, 5]);
    });
  });

  group('UnmodifiableTissue factories', () {
    test('standalone unmodifiable tissue holds fixed elements', () {
      final u = UnmodifiableTissue<int>([1, 2, 3]);

      expect(u.toList(), [1, 2, 3]);
      expect(u.length, 3);
      expect(u.modifiable.toList(), isEmpty);
      expect(u.validate, same(TestTissue.allowAll));
      expect(u == ([1, 2, 3] as Object), isTrue);
      expect(u == u, isTrue);
      expect(u == ([9] as Object), isFalse);
      expect(identical(u, 42), isFalse);
      expect(u.hashCode, UnmodifiableTissue<int>([1, 2, 3]).hashCode);
      expect(u.toString(), contains('1'));
      expect(identical(u, u.unmodifiable), isTrue);
    });

    test('standalone unmodifiable tissue with unmodifiableElement false', () {
      final u = UnmodifiableTissue<int>([1, 2, 3], unmodifiableElement: false);

      expect(u.toList(), [1, 2, 3]);
    });

    test('fromNucleus populates elements', () {
      final nucleus = TissueNucleus.create<int, Iterable<int>, Tissue<int>>(
        container: Container.iterable,
      );
      final u = UnmodifiableTissue<int>.fromNucleus(nucleus, elements: [9, 10]);

      expect(u.toList(), [9, 10]);
    });

    test('fromNucleus with unmodifiableElement false', () {
      final nucleus = TissueNucleus.create<int, Iterable<int>, Tissue<int>>(
        container: Container.iterable,
      );
      final u = UnmodifiableTissue<int>.fromNucleus(nucleus,
          unmodifiableElement: false, elements: [11, 12]);

      expect(u.toList(), [11, 12]);
    });

    test('fromNucleus links cells when elements are identical to the bind', () {
      final cell = Cell.state<int>(initial: 9).cell;
      final source = Tissue<Cell>([cell]);
      final nucleus = TissueNucleus.create<Cell, Iterable<Cell>, Tissue<Cell>>(
        bind: source,
        container: Container.iterable,
      );
      final u = UnmodifiableTissue<Cell>.fromNucleus(nucleus, elements: source);

      expect(u.toList(), [cell]);
      expect(u.length, 1);
    });
  });

  group('TissueBase members (direct subclass)', () {
    test('base equality, hashCode, iterator and toString', () {
      final a = _DirectTissue<int>([1, 2, 3]);
      final b = _DirectTissue<int>([1, 2, 3]);
      final c = _DirectTissue<int>([1, 2, 4]);

      expect(a == a, isTrue);
      expect(a == b, isTrue);
      expect(a == ([1, 2, 3] as Object), isTrue);
      expect(a == c, isFalse);
      expect(identical(a, 42), isFalse);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('1'));
      expect(a.toList(), [1, 2, 3]);
    });

    test('unmodifiable branch of base equality is exercised', () {
      final source = _DirectTissue<int>([1, 2, 3]);
      final view = Tissue<int>.unmodifiable(source);

      // The view binds back to the source; both equality paths execute.
      expect(source == view, isFalse);
      expect(view == source, isFalse);
      expect(view.toList(), [1, 2, 3]);
    });
  });
}
