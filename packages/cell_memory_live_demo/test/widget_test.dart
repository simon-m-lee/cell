// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_memory/cell_memory_io.dart';
import 'package:cell_memory_live_demo/boundary/memory.dart';
import 'package:cell_memory_live_demo/domain/books.dart';
import 'package:cell_memory_live_demo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase C: brewing drops stock, settles cash, and fills the '
      'pipeline feed; a drain below zero is denied by the Tissue gate',
      (tester) async {
    // All real file IO must run through `runAsync`: the widget test body
    // executes in a FakeAsync zone where real IO futures never complete.
    final dir = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('kiosk_twins_ui_')))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
    });

    final store = FileMemoryStore.directory(dir);
    final books = KioskBooks();
    final boundary =
        MemoryBoundary(books: books, store: store, ownsStore: false);
    await tester.runAsync(() => boundary.open());

    await tester.pumpWidget(KioskTwinsApp(books: books, boundary: boundary));
    await tester.pump();

    expect(find.text('24'), findsOneWidget);
    expect(find.text('\$0.00'), findsOneWidget);

    await tester.tap(find.text('Brew Flat White'));
    await tester.pumpAndSettle();

    expect(find.text('23'), findsOneWidget);
    expect(find.text('\$2.50'), findsWidgets,
        reason: 'the cash book and each pipeline line show the price');
    expect(find.text('validated — flat white'), findsOneWidget);
    expect(find.text('receipted — flat white'), findsOneWidget);

    await tester.tap(find.text('Drain −99 (governance)'));
    await tester.pumpAndSettle();

    expect(find.text('drain denied by governance: -99'), findsOneWidget);
    expect(find.text('23'), findsOneWidget,
        reason: 'the Tissue gate rejected the drain below zero');

    // Store persistence is covered by restart_test.dart in a real async
    // zone. This test never flushes the memory write chain: a write
    // initiated inside the fake zone cannot be awaited, even from
    // runAsync, because its completion callback is queued on the fake
    // zone.
  });
}
