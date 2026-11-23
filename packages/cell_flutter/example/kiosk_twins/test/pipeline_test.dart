// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_memory_live_demo/domain/books.dart';
import 'package:cell_memory_live_demo/domain/pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderPipeline', () {
    test('an order passes all four stages and settles the books', () {
      final books = KioskBooks(initialStock: 2);
      final pipeline = OrderPipeline(books);

      final emitted = pipeline
          .order(const OrderLine(drink: 'cold brew', price: 3.00));

      expect(emitted, isTrue);
      expect(
        pipeline.feed.cell.value!.map((e) => e.stage).toList(),
        ['validated', 'reserved', 'settled', 'receipted'],
        reason: 'one feed event per stage, in pipeline order',
      );
      expect(books.stock.value, 1);
      expect(books.cash.value, 3.00);
      expect(books.orders.cell.value, 1);
    });

    test('an empty drink name is filtered at validation', () {
      final books = KioskBooks();
      final pipeline = OrderPipeline(books);

      pipeline.order(const OrderLine(drink: '   ', price: 1));

      expect(pipeline.feed.cell.value, isEmpty);
      expect(books.stock.value, 24);
    });

    test('out of stock is refused at the reserve gate with a denial and '
        'no book movement', () {
      final books = KioskBooks(initialStock: 1);
      final pipeline = OrderPipeline(books);

      pipeline.order(const OrderLine(drink: 'flat white', price: 2.50));
      expect(books.stock.value, 0);

      pipeline.order(const OrderLine(drink: 'espresso', price: 1.50));

      expect(books.stock.value, 0, reason: 'the second order never settles');
      expect(books.orders.cell.value, 1);
      expect(pipeline.feed.cell.value!.length, 5,
          reason: 'the second order only reached validation');
      expect(pipeline.feed.cell.value!.first.stage, 'validated');
      expect(pipeline.feed.cell.value!.first.drink, 'espresso');
      expect(pipeline.feed.cell.value!.any((e) => e.stage == 'settled' &&
              e.drink == 'espresso'),
          isFalse, reason: 'the second order never settled');
    });

    test('a settled order always ends with a receipted event', () {
      final books = KioskBooks(initialStock: 1);
      final pipeline = OrderPipeline(books);

      pipeline.order(const OrderLine(drink: 'flat white', price: 2.50));

      final receipted =
          pipeline.feed.cell.value!.firstWhere((e) => e.stage == 'receipted');
      expect(receipted.drink, 'flat white');
      expect(receipted.price, 2.50);
    });
  });
}
