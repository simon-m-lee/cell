// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

Future<TissueValue<T>> resolveDeputy<T>(TissueValue<T> source) async {
  final result = source.deputy();
  return result is Future<TissueValue<T>> ? await result : result;
}

void main() {
  group('TissueValue factories', () {
    test('primary factory creates a reactive value', () {
      final value = TissueValue<int>(1);

      expect(value.runtimeType.toString(), contains('TissueValue'));
      expect(value.value, 1);
    });

    test('empty factory creates a null value', () {
      final value = TissueValue<int>.empty(
        bind: null,
        context: Context.system,
        testRule: TestTissue.allowAll,
        receptor: TissueReceptor.passThrough,
        synapses: Synapses.enabled,
      );

      expect(value.value, isNull);
    });

    test('fromNucleus populates value', () {
      final nucleus = TissueValueNucleus.create<int, TissueValue<int>>();
      final value = TissueValue.fromNucleus(nucleus, value: 7);

      expect(value.value, 7);
    });

    test('create builds a value from explicit parameters', () {
      final value = TissueValue.create<int, TissueValue<int>>(value: 3);

      expect(value.value, 3);
    });
  });

  group('TissueValue reads and writes', () {
    test('value setter and getter', () {
      final value = TissueValue<int>(0);

      value.value = 42;
      expect(value.value, 42);
    });

    test('set returns false for identical value', () {
      final value = TissueValue<int>(1);

      expect(value.set(1), isFalse);
      expect(value.set(2), isTrue);
      expect(value.value, 2);
    });

    test('equality compares underlying value', () {
      final value = TissueValue<int>(5);
      final same = TissueValue<int>(5);

      // ignore: unrelated_type_equality_checks
      expect(value == 5, isTrue);
      expect(value == same, isTrue);
      expect(value == TissueValue<int>(6), isFalse);
      expect(identical(value, 42), isFalse);
      expect(same.hashCode, value.hashCode);
    });

    test('numeric comparison operators', () {
      final value = TissueValue<int>(5);

      expect(value <= 5, isTrue);
      expect(value < 6, isTrue);
      expect(value > 4, isTrue);
      expect(value <= 4, isFalse);
      expect(value > 5, isFalse);
      expect(value < 5, isFalse);
      expect(value < 'x', isFalse);
    });

    test('comparisons accept TissueValue operands', () {
      final value = TissueValue<int>(5);

      expect(value <= TissueValue<int>(5), isTrue);
      expect(value > TissueValue<int>(4), isTrue);
      expect(value < TissueValue<int>(6), isTrue);
      expect(value > TissueValue<int>(6), isFalse);
      expect(value < TissueValue<int>(4), isFalse);
      expect(value <= TissueValue<int>(4), isFalse);
    });

    test('Cell values are linked and unlinked', () {
      final cell = Cell.state<int>(initial: 1).cell;
      final other = Cell.state<int>(initial: 2).cell;
      final value = TissueValue<Cell>(cell);

      expect(value.set(other), isTrue);
      expect(value.value, same(other));
      expect(value.set(other), isFalse);
    });

    test('cell metadata and apply', () {
      final value = TissueValue<int>(0);

      expect(value.validate, same(TestTissue.allowAll));
      expect(value.modifiable, contains(value.set));

      final event = value.apply(value.set, positionalArguments: [9]);
      expect(event, isNotNull);
      expect(value.value, 9);
    });
  });

  group('TissueValueNucleus factories', () {
    test('create returns a reusable blueprint', () {
      final nucleus = TissueValueNucleus.create<int, TissueValue<int>>();

      final value = TissueValue.fromNucleus(nucleus, value: 1);
      expect(value.value, 1);
    });

    test('clone produces an independent nucleus', () {
      final nucleus = TissueValueNucleus.create<int, TissueValue<int>>();
      final clone = nucleus.clone;

      final value = TissueValue.fromNucleus(clone, value: 2);
      expect(value.value, 2);
    });

    test('evolve produces a deputy nucleus', () {
      final principal = TissueValueNucleus.create<int, TissueValue<int>>();
      final evolved = TissueValueNucleus<int>.evolve(
        principal: principal,
        testRule: TestTissue<int, TissueValue<int>>(
          (object, {host, arguments, user}) => (object as int) > 0,
        ),
      );

      expect(evolved, isA<TissueValueNucleus<int>>());
    });
  });

  group('TissueValue.unmodifiable', () {
    late TissueValue<int> source;

    setUp(() {
      source = TissueValue<int>(1);
    });

    test('unmodifiable getter returns a read-only view', () {
      final view = source.unmodifiable;

      expect(view.runtimeType.toString(), contains('UnmodifiableTissueValue'));
      expect(view.value, 1);
      expect(identical(view, view.unmodifiable), isTrue);
      expect(view.modifiable.toList(), isEmpty);
      expect(view == source, isTrue);
      expect(source == view, isTrue);
      expect(view.hashCode, isNotNull);
      expect(view.toString(), contains('1'));
    });

    test('unmodifiable view rejects mutations', () {
      final view = source.unmodifiable;

      expect(view.set(9), isFalse);
      view.value = 9;
      expect(view.value, 1);
    });

    test('standalone UnmodifiableTissueValue factory', () {
      final u = UnmodifiableTissueValue<int>(42);

      expect(u.value, 42);
      // ignore: unrelated_type_equality_checks
      expect(u == 42, isTrue);
      expect(identical(u, 42), isFalse);
    });

    test('view factory', () {
      final view =
          UnmodifiableTissueValue<int>.view(source, unmodifiableElement: false);

      expect(view.value, 1);
    });

    test('fromNucleus populates value', () {
      final nucleus = TissueValueNucleus.create<int, TissueValue<int>>();
      final u = UnmodifiableTissueValue<int>.fromNucleus(nucleus, value: 9);

      expect(u.value, 9);
    });

    test('create factory', () {
      final u = UnmodifiableTissueValue.create<int, TissueValue<int>>(
        value: 11,
      );

      expect(u.value, 11);
    });
  });

  group('TissueValue.deputy', () {
    test('deputy shares principal storage and equality', () async {
      final source = TissueValue<int>(1);
      final deputy = await resolveDeputy(source);

      expect(deputy.runtimeType.toString(), contains('Deputy'));
      expect(deputy.value, 1);
      expect(deputy.value, source.value);
    });

    test('deputy of an unmodifiable view works', () async {
      final source = TissueValue<int>(1);
      final view = source.unmodifiable;
      final deputy = await resolveDeputy(view);

      expect(deputy.value, 1);
    });

    test('nested deputies', () async {
      final source = TissueValue<int>(1);
      final deputy = await resolveDeputy(source);
      final nested = await resolveDeputy(deputy);

      expect(nested.value, 1);
    });
  });

  group('TissueValue async', () {
    test('async set updates the value', () async {
      final value = TissueValue<int>(0);
      final async = ModifiableValueAsync<int>(value);

      expect(async, isA<ModifiableValueAsync<int>>());
      expect(await async.set(42), isTrue);
      expect(value.value, 42);
    });

    test('unmodifiable async set returns false and value is readable',
        () async {
      final view = TissueValue<int>(1).unmodifiable;
      final async = view.async as dynamic;

      await expectLater(async.set(9), throwsUnsupportedError);
      expect(await async.value, 1);
      await expectLater(() => async.apply(view.set, positionalArguments: [9]),
          throwsA(isA<UnimplementedError>()));
      await expectLater(() => async.state, throwsA(isA<UnimplementedError>()));
    });
  });
}
