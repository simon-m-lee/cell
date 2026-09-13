// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

TissuePulse<int> addedEvent(TissueList<int> list, int value) =>
    list.apply(list.add, positionalArguments: [value]) as TissuePulse<int>;

TissuePulse<int> removedEvent(TissueList<int> list, int value) {
  final result = list.apply(list.remove, positionalArguments: [value]);
  return (result as Iterable).first as TissuePulse<int>;
}

void main() {
  group('TissueReceptor.passThrough', () {
    test('is a const singleton with terminal behaviour', () {
      final receptor = TissueReceptor.passThrough;

      expect(identical(receptor, TissueReceptor.passThrough), isTrue);
      expect(receptor.isActivated, isTrue);
      expect(identical(receptor.clone, receptor), isTrue);
      expect(() => receptor.cell, throwsUnsupportedError);
      expect(() => receptor.async, throwsUnsupportedError);
    });

    test('call forwards the pulse unchanged', () {
      final receptor = TissueReceptor.passThrough;
      final pulse = Pulse('payload');

      expect(receptor.call(pulse as dynamic), same(pulse));
    });
  });

  group('TissueReceptor factory', () {
    test('primary factory wraps an instruction', () async {
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => Pulse('$user:${pulse.payload}'),
      );
      final list = TissueList.of([1]);

      expect(receptor.activate(list), isTrue);
      expect(receptor.isActivated, isTrue);
      expect(receptor.cell, same(list));

      final out = receptor.call(Pulse('x'));
      final result = out is Future ? await out : out;
      expect(result, isA<Pulse<dynamic>>());
      expect(result!.payload, 'null:x');
    });

    test('instruction factory stores user metadata', () async {
      final receptor = TissueReceptor<int, TissueList<int>>.instruction(
        Instruction<TissueList<int>, Pulse, Pulse>((pulse, {cell, user}) {
          return Pulse('${user ?? ''}:${pulse.payload}');
        }),
        user: () => 'u',
      );

      final out = receptor.call(Pulse('x'));
      expect(out, isNull); // not activated yet
      expect(receptor.isActivated, isFalse);
    });

    test('pipeline factory wires all stages', () async {
      final receptor = TissueReceptor<int, TissueList<int>>.pipeline(
        preProcess: Instruction<TissueList<int>, Pulse, Pulse>(
          (p, {cell, user}) => Pulse('pre:${p.payload}'),
        ),
        instruction: Instruction<TissueList<int>, Pulse, Pulse>(
          (p, {cell, user}) => Pulse('core:${p.payload}'),
        ),
        postProcess: Instruction<TissueList<int>, Pulse, Pulse>(
          (p, {cell, user}) => Pulse('post:${p.payload}'),
        ),
        init: () {},
        user: () => 'u',
      );
      final list = TissueList.of([1]);

      expect(receptor.activate(list), isTrue);

      final out = receptor.call(Pulse('x'));
      final result = out is Future ? await out : out;
      expect(result, isA<Pulse<dynamic>>());
      expect(result!.payload, 'post:core:pre:x');
    });

    test('pipeline reaction and error boundaries', () async {
      final receptor = TissueReceptor<int, TissueList<int>>.pipeline(
        reaction: (pulse, host, {user}) => Pulse('reaction:${pulse.payload}'),
      );
      final list = TissueList.of([1]);

      expect(receptor.activate(list), isTrue);

      final out = receptor.call(Pulse('x'));
      final result = out is Future ? await out : out;
      expect(result!.payload, 'reaction:x');
    });

    test('clone produces an unactivated copy', () {
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      final list = TissueList.of([1]);
      receptor.activate(list);

      final clone = receptor.clone;

      expect(clone, isA<TissueReceptor<int, TissueList<int>>>());
      expect(clone.isActivated, isFalse);
      expect(receptor.isActivated, isTrue);
    });

    test('async getter returns a ReceptorAsync adapter', () {
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      final list = TissueList.of([1]);
      receptor.activate(list);

      expect(receptor.async, isA<ReceptorAsync<TissueList<int>>>());
    });
  });

  group('TissueReceptorBase.call', () {
    test('returns null when not activated', () {
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );

      expect(receptor.call(Pulse('x')), isNull);
    });

    test('forwards non-tissue pulses to the pipeline', () async {
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => Pulse('seen:${pulse.payload}'),
      );
      final list = TissueList.of([1]);
      receptor.activate(list);

      final out = receptor.call(Pulse('x'));
      final result = out is Future ? await out : out;
      expect(result!.payload, 'seen:x');
    });

    test('synchronises ElementAdded from another tissue', () {
      final target = TissueList<int>();
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1]);
      final event = addedEvent(source, 2);

      receptor.call(event);
      expect(target.toList(), [2]);
    });

    test('synchronises ElementRemoved from another tissue', () {
      final target = TissueList.of([2]);
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1, 2]);
      final event = removedEvent(source, 2);

      receptor.call(event);
      expect(target.toList(), isEmpty);
    });

    test('synchronises collective batches', () {
      final target = TissueList<int>();
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1]);
      final a = addedEvent(source, 2);
      final r = removedEvent(source, 2);
      final batch = a + r;

      receptor.call(batch as PulseBase);
      expect(target.toList(), isEmpty);
    });

    test('partial sync returns single applied event', () {
      final target = TissueList.of([2]);
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1, 99]);
      final add = addedEvent(source, 3);
      final remove = removedEvent(source, 99);
      final batch = add + remove;

      receptor.call(batch as PulseBase);
      expect(target.toList(), [2, 3]);
    });

    test('partial sync returns batch of applied events', () {
      final target = TissueList.of([2]);
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1, 99]);
      final add1 = addedEvent(source, 3);
      final add2 = addedEvent(source, 4);
      final remove = removedEvent(source, 99);
      final batch = add1 + add2 + remove;

      receptor.call(batch as PulseBase);
      expect(target.toList(), [2, 3, 4]);
    });

    test('synchronises ElementUpdated into a list of cells', () {
      final sourceValue = TissueValue<int>(0);
      final event = sourceValue.apply(sourceValue.set, positionalArguments: [42])
          as ElementUpdated<int, TissueValue<int>>;

      final target = TissueList<dynamic>();
      final receptor = TissueReceptor<dynamic, TissueList<dynamic>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      receptor.call(event);
      expect(target.toList(), [sourceValue]);

      final event2 = sourceValue.apply(sourceValue.set, positionalArguments: [43])
          as ElementUpdated<int, TissueValue<int>>;
      receptor.call(event2);
      expect(target.toList(), [sourceValue]);
    });

    test('partial sync returns applied events only', () {
      final target = TissueList.of([2]);
      final receptor = TissueReceptor<int, TissueList<int>>(
        (tissue, pulse, {user}) => pulse,
      );
      receptor.activate(target);

      final source = TissueList.of([1]);
      final event = addedEvent(source, 2); // 2 already present in target

      final out = receptor.call(event);
      expect(out, isNotNull);
      expect(target.toList(), [2, 2]);
    });


  });
}
