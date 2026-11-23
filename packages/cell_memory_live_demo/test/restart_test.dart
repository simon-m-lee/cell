// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';
import 'package:cell_memory_live_demo/boundary/memory.dart';
import 'package:cell_memory_live_demo/domain/books.dart';
import 'package:cell_memory_live_demo/domain/pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('restart drill (CI shape)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kiosk_twins_');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('boot → brew → relaunch restores every book from the file store',
        () async {
      // ── First "process" ──────────────────────────────────────────────
      final store1 = FileMemoryStore.directory(dir);
      final books1 = KioskBooks();
      final boundary1 =
          MemoryBoundary(books: books1, store: store1, ownsStore: true);
      await boundary1.open();

      final pipeline = OrderPipeline(books1);
      pipeline.order(const OrderLine(drink: 'flat white', price: 2.50));
      pipeline.order(const OrderLine(drink: 'cold brew', price: 3.00));

      expect(books1.stockView.cell.value, 22);
      expect(books1.cashView.cell.value, 5.50);
      expect(books1.orders.cell.value, 2);

      await boundary1.dispose(); // settled writes + owned store closed

      // ── Second "process" ─────────────────────────────────────────────
      final store2 = FileMemoryStore.directory(dir);
      final books2 = KioskBooks();
      final boundary2 =
          MemoryBoundary(books: books2, store: store2, ownsStore: true);
      await boundary2.open();

      // The books restored their latest values — including the governed
      // tissue books, not only the UI mirrors.
      expect(books2.stock.value, 22);
      expect(books2.stockView.cell.value, 22);
      expect(books2.cash.value, 5.50);
      expect(books2.cashView.cell.value, 5.50);
      expect(books2.orders.cell.value, 2);
      // Two back-to-back brews coalesce into one memory write (the
      // `immediate` policy writes the latest value per flush) — the
      // stored revision is 1, and the payload is the final stock.
      expect(boundary2.stockMemory?.revision, 1);
      expect(boundary2.stockMemory?.value, 22);

      // A restored value is not echoed back as a fresh write: the store
      // row keeps the revision the first process left.
      final stockRow = await store2.read('stock');
      expect(stockRow?.revision, 1);

      await boundary2.dispose();
    });

    test('a stored stock value that violates governance fails the open '
        'and is not adopted', () async {
      // Corrupt the record the way an external writer could: a negative
      // stock row at revision 1.
      final writer = FileMemoryStore.directory(dir);
      await writer.write(
        MemoryEnvelope(
          generation: MemoryEnvelope.mintGeneration(),
          id: 'stock',
          revision: 1,
          payload: -5,
        ),
        expectedRevision: 0,
      );
      await writer.close();

      final store = FileMemoryStore.directory(dir);
      final books = KioskBooks();
      final boundary =
          MemoryBoundary(books: books, store: store, ownsStore: true);

      await expectLater(boundary.open(), throwsA(isA<StateError>()));
      expect(books.stock.value, 24,
          reason: 'the corrupt value was never adopted');
      expect(books.stockView.cell.value, 24);
    });
  });
}
