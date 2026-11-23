// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:flutter/material.dart';

import 'boundary/memory.dart';
import 'boundary/stores.dart';
import 'domain/books.dart';
import 'ui/kiosk.dart';

/// Kiosk Twins — Phase C: the books now live behind the memory boundary.
///
/// On boot the boundary restores the latest value of every book from the
/// store; on shutdown every pending write is settled. Restart the app
/// from the same directory and the kiosk picks up where it left off.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await selectStore();
  final books = KioskBooks();
  final boundary = MemoryBoundary(books: books, store: store, ownsStore: true);
  await boundary.open();

  runApp(KioskTwinsApp(books: books, boundary: boundary));
}

class KioskTwinsApp extends StatelessWidget {
  const KioskTwinsApp({super.key, required this.books, this.boundary});

  final KioskBooks books;

  final MemoryBoundary? boundary;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosk Twins',
      theme: ThemeData(colorSchemeSeed: Colors.brown),
      home: KioskScreen(books: books, boundary: boundary),
    );
  }
}
