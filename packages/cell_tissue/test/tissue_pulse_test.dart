// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

TissuePulse<int> addedEvent(TissueList<int> list, int value) =>
    list.apply(list.add, positionalArguments: [value]) as TissuePulse<int>;

TissuePulse<int> removedEvent(TissueList<int> list, int value) {
  final result = list.apply(list.remove, positionalArguments: [value]);
  return (result as Iterable).first as TissuePulse<int>;
}

ElementUpdated<int, TissueValue<int>> updatedEvent(
  TissueValue<int> value,
  int next,
) =>
    value.apply(value.set, positionalArguments: [next])
        as ElementUpdated<int, TissueValue<int>>;

void main() {
  group('TissuePulse.batch and CollectiveTissuePulse', () {
    test('batch creates a collective from events', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);
      final r = removedEvent(list, 2);

      final batch = TissuePulse.batch<int>([a, r]);

      expect(batch, isA<CollectiveTissuePulse>());
      expect(batch.payload.length, 2);
      expect(batch.toList(), [a, r]);
    });

    test('empty batch remains a collective', () {
      final batch = TissuePulse.batch<int>(const []);

      expect(batch, isA<CollectiveTissuePulse>());
      expect(batch.toList(), isEmpty);
    });

    test('CollectiveTissuePulse.from wraps events', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);

      final batch = CollectiveTissuePulse<int>.from([a]);

      expect(batch.payload.single, a);
    });

    test('CollectiveTissuePulse.governed overrides metadata', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);
      final r = removedEvent(list, 2);

      final batch = CollectiveTissuePulse<int>.governed(
        [a, r],
        context: PulseContext(actor: 'admin'),
        type: 'bulk_operation',
        source: list,
        step: 'batch_step',
        priority: 80,
        onComplete: (event) {},
        onError: (event, error, {stackTrace}) {},
        onProgress: (event, cell, {message}) {},
        scrutinize: (receptor) => null,
      );

      expect(batch.type, 'bulk_operation');
      expect(batch.priority, 80);
      expect(batch.toList().length, 2);
    });

    test('plus operator flattens collectives', () {
      final list = TissueList.of([1, 2, 3]);
      final a = addedEvent(list, 4);
      final r = removedEvent(list, 4);
      final batch1 = a + r;
      final batch2 = batch1 + addedEvent(list, 5);
      final batch3 = batch1 + batch2;

      expect(batch1, isA<CollectiveTissuePulse>());
      expect(batch1.toList().length, 2);
      expect(batch2.toList().length, 3);
      expect(batch3.toList().length, 5);
    });

    test('plus branches with collective and foreign types', () {
      final list = TissueList.of([1, 2]);
      final a = addedEvent(list, 3);
      final batch = TissuePulse.batch<int>([a]);
      final stringList = TissueList.of(['x']);
      final foreign =
          stringList.apply(stringList.add, positionalArguments: ['y'])
              as TissuePulse<String>;

      final withBatch = a + batch;
      expect(withBatch.toList().length, 2);

      final withForeign = a + foreign;
      expect(withForeign.toList().length, 2);
    });

    test('collective exposes shell, evolution, source, root and unmodifiable',
        () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);
      final batch = TissuePulse.batch<int>([a]);

      final shell = batch.shell;
      expect(shell, isA<TissueEventShell<dynamic>>());

      final step = batch.withStep('logged') as dynamic;
      expect(step, isA<TissuePulse<dynamic>>());
      expect(step.root, isNotNull);

      final evolved = batch.evolve(step: 'next') as dynamic;
      expect(evolved, isA<TissuePulse<dynamic>>());
      expect(evolved.root, isNotNull);

      expect(batch.root, isA<TissuePulse<dynamic>>());
      expect(batch.unmodifiable, isA<UnmodifiableTissuePulse<dynamic>>());
      expect((batch + a).toList().length, 2);
    });
  });

  group('TissuePulse evolution', () {
    test('withStep creates a chain', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);

      final evolved = a.withStep('validation') as dynamic;

      expect(evolved, isA<TissuePulse<int>>());
      expect(evolved.root, isNotNull);
    });

    test('evolve creates an evolved event', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);

      final evolved = a.evolve(step: 'transformation') as dynamic;

      expect(evolved, isA<TissuePulse<int>>());
      expect(evolved.root, isNotNull);
      expect(evolved.payload, 2);
    });

    test('evolved plus builds a collective', () {
      final list = TissueList.of([1, 2, 3]);
      final a = addedEvent(list, 4);
      final evolved = a.withStep('step1') as dynamic;

      final batch = evolved + removedEvent(list, 4);

      expect(batch, isA<CollectiveTissuePulse>());
      expect(batch.toList().length, 2);
    });

    test('chained steps accumulate trace', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);

      final chain =
          a.withStep('validation').withStep('transformation') as dynamic;

      expect(chain.trace, ['validation', 'transformation']);
      expect(chain.root, same(a));
    });

    test('evolved events exercise the tissue event mixin', () {
      final list = TissueList.of([1]);
      final a = addedEvent(list, 2);
      final evolved = a.evolve(step: 'base') as dynamic;

      expect(evolved.shell, isA<TissueEventShell<int>>());
      expect(evolved.source, same(list));
      expect(evolved.root, isNotNull);
      expect(evolved.unmodifiable, isA<UnmodifiableTissuePulse<int>>());
      expect((evolved + a).toList().length, 2);

      final reEvolved = evolved.evolve(pulse: a, step: 'again') as dynamic;
      expect(reEvolved, isA<TissuePulse<dynamic>>());

      final stepped = evolved.withStep('step') as dynamic;
      expect(stepped, isA<TissuePulse<dynamic>>());

      final collective = CollectiveTissuePulse<int>.from([a]);
      final withBatch = evolved + collective;
      expect(withBatch.toList().length, 2);

      expect(() => evolved.parent, throwsA(anything));
    });
  });

  group('TissuePulse shell', () {
    late TissueList<int> list;
    late TissuePulse<int> event;

    setUp(() {
      list = TissueList.of([1]);
      event = addedEvent(list, 2);
    });

    test('shell getter returns a TissueEventShell', () {
      final shell = event.shell;

      expect(shell, isA<TissueEventShell<int>>());
      expect(shell.shell, same(shell));
      expect(shell.unmodifiable, same(shell));
      expect(shell.root, same(shell));
      expect(shell.source, same(list));
    });

    test('shell iterator yields itself', () {
      final shell = event.shell;
      final iterator = shell.iterator;

      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, same(shell));
      expect(iterator.moveNext(), isFalse);
    });

    test('shell rejects addition, evolution and steps', () {
      final shell = event.shell;

      expect(() => shell + event, throwsUnsupportedError);
      expect(() => shell.evolve(), throwsUnsupportedError);
      expect(() => shell.withStep('x'), throwsUnsupportedError);
    });

    test('shell scrutinize returns the underlying event', () {
      final shell = event.shell;

      final unlocked = shell.scrutinize(TissueReceptor.passThrough, []);

      expect(unlocked, isNotNull);
    });
  });

  group('TissuePulse unmodifiable', () {
    late TissueList<int> list;
    late TissuePulse<int> event;

    setUp(() {
      list = TissueList.of([1]);
      event = addedEvent(list, 2);
    });

    test('unmodifiable getter returns a read-only projection', () {
      final view = event.unmodifiable;

      expect(view, isA<UnmodifiableTissuePulse<int>>());
      expect(view.payload, 2);
      expect(identical(view, view.unmodifiable), isTrue);
    });

    test('UnmodifiableTissuePulse factory', () {
      final view = UnmodifiableTissuePulse<int>(event);

      expect(view.payload, 2);
    });

    test('unmodifiable derives new events without mutating', () {
      final view = event.unmodifiable;

      final step = view.withStep('logged');
      final evolved = view.evolve(step: 'next');

      expect(step.root, same(event));
      expect(evolved.root, same(event));
      expect(view.payload, 2);
    });

    test('unmodifiable plus builds a collective', () {
      final view = event.unmodifiable;

      final batch = view + removedEvent(list, 2);

      expect(batch, isA<CollectiveTissuePulse>());
      expect(batch.toList().length, 2);
    });

    test('unmodifiable forwards shell and root', () {
      final view = event.unmodifiable;

      expect(view.shell, isA<TissueEventShell<int>>());
      expect(view.root, isA<TissuePulse<int>>());
      expect(view.source, isA<TissueList<int>>());
    });
  });

  group('ElementAdded, ElementRemoved and ElementUpdated', () {
    test('list add emits ElementAdded with payload', () {
      final list = TissueList.of([1]);
      final event = addedEvent(list, 2);

      expect(event, isA<ElementAdded<int>>());
      expect(event.payload, 2);
      expect(event.source, same(list));
    });

    test('list remove emits ElementRemoved with payload', () {
      final list = TissueList.of([1, 2]);
      final event = removedEvent(list, 2);

      expect(event, isA<ElementRemoved<int>>());
      expect(event.payload, 2);
    });

    test('value set emits ElementUpdated record', () {
      final value = TissueValue<int>(0);
      final event = updatedEvent(value, 42);

      expect(event, isA<ElementUpdated<int, TissueValue<int>>>());
      expect(event.payload!.before, 0);
      expect(event.payload!.after, 42);
      expect(event.payload!.value, same(value));
    });
  });

  group('groupBy utility', () {
    test('groups elements by key', () {
      final grouped =
          groupBy<int, String>([1, 2, 3, 4], (e) => e.isEven ? 'even' : 'odd');

      expect(grouped['even'], [2, 4]);
      expect(grouped['odd'], [1, 3]);
    });

    test('handles empty iterable', () {
      expect(groupBy<int, String>(const [], (e) => '$e'), isEmpty);
    });
  });
}
