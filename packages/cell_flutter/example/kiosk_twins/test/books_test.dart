// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_memory_live_demo/domain/books.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskBooks governance', () {
    test('a negative restock is rejected and the book is unchanged', () {
      final books = KioskBooks(initialStock: 4);
      expect(books.stock.value, 4);

      final ok = books.restock(-5);

      expect(ok, isFalse, reason: 'the TestTissue rule rejects negatives');
      expect(books.stock.value, 4, reason: 'the value never changed');
    });

    test('a true restock passes and the book moves', () {
      final books = KioskBooks(initialStock: 4);
      expect(books.restock(6), isTrue);
      expect(books.stock.value, 10);
    });

    test('cash is also non-negative: a negative settle price is rejected',
        () {
      final books = KioskBooks();
      final ok = books.cash.set(-0.01);
      expect(ok, isFalse);
      expect(books.cash.value, 0);
    });

    test('settle moves all three books: stock −1, cash +price, orders +1',
        () {
      final books = KioskBooks(initialStock: 24);
      final ok = books.settle(
          const OrderLine(drink: 'flat white', price: 2.50));

      expect(ok, isTrue);
      expect(books.stock.value, 23);
      expect(books.cash.value, 2.50);
      expect(books.orders.cell.value, 1);
    });
  });
}
