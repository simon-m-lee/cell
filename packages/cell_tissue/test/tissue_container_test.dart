// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell_tissue/cell_tissue.dart';
import 'package:test/test.dart';

void main() {
  group('Container strategies', () {
    test('create without elements builds an empty persistent store', () {
      final container = Container.list.create<int, List<int>>();

      expect(container, isA<TissueContainer<int, List<int>>>());
      expect(container.init(), isEmpty);
      expect(container.store, isA<List<int>>());
    });

    test('create with elements initialises the persistent store', () {
      final container = Container.list.create<int, List<int>>(
        elements: [1, 2, 3],
      );

      expect(container.store, [1, 2, 3]);
      expect(container.length, 3);
    });

    test('init delegates to the strategy create function', () {
      final store = Container.list.init([1, 2]);

      expect(store, isA<List<dynamic>>());
      expect(store, [1, 2]);
    });

    test('add operates on a transient store', () {
      final tissue = TissueList<int>();

      expect(Container.list.add(tissue, 7), isTrue);
      // The persistent tissue is untouched: add() used a transient store.
      expect(tissue.toList(), isEmpty);
    });

    test('remove operates on a transient store', () {
      final tissue = TissueList.of([1]);

      // A fresh transient store never contains the element.
      expect(Container.list.remove(tissue, 1), isFalse);
      expect(tissue.toList(), [1]);
    });
  });
}
