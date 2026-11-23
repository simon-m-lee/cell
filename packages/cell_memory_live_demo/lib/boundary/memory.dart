// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory_firebase/cell_memory_firebase.dart';

import '../domain/books.dart';

/// The memory boundary: one `remember()` per book.
///
/// The boundary stores *what the books are now* (latest value) and hands
/// the loaded value back to the domain through `seed` — before the
/// observer is attached, so a restored value is never echoed back as a
/// new write. The governed Tissue books adopt a loaded value through the
/// same gate as every other mutation: a stored value that violates the
/// invariant is a corrupt record and fails the open.
class MemoryBoundary {
  MemoryBoundary({
    required this.books,
    required this.store,
    this.ownsStore = false,
  });

  final KioskBooks books;

  final MemoryStore store;

  /// Whether [dispose] should close [store]. The demo owns its store;
  /// tests that reuse a store across two "processes" inject it and close
  /// it themselves.
  final bool ownsStore;

  MemoryCell<int>? stockMemory;

  MemoryCell<double>? cashMemory;

  MemoryCell<int>? ordersMemory;

  /// The write policy per book. Firestore caps each document at roughly
  /// one sustained write per second, so the network boundary debounces
  /// (the shipped `firestoreWritePolicy`); the file boundary writes
  /// through immediately.
  MemoryWritePolicy get _policy => store is FirebaseMemoryStore
      ? firestoreWritePolicy
      : const MemoryWritePolicy(mode: MemoryWriteMode.immediate);

  Future<void> open() async {
    stockMemory = await remember<int>(
      books.stockView.cell,
      id: 'stock',
      store: store,
      codec: JsonMemoryCodec<int>.identity(),
      project: (pulse) => pulse.payload as int? ?? 0,
      seed: _adoptStock,
      initial: 24,
      policy: _policy,
    );
    cashMemory = await remember<double>(
      books.cashView.cell,
      id: 'cash',
      store: store,
      codec: JsonMemoryCodec<double>.identity(),
      project: (pulse) => pulse.payload as double? ?? 0,
      seed: _adoptCash,
      initial: 0,
      policy: _policy,
    );
    ordersMemory = await remember<int>(
      books.orders.cell,
      id: 'orders',
      store: store,
      codec: JsonMemoryCodec<int>.identity(),
      project: (pulse) => pulse.payload as int? ?? 0,
      seed: (loaded) => books.adoptOrders(loaded ?? 0),
      initial: 0,
      policy: _policy,
    );
  }

  void _adoptStock(int? loaded) {
    final ok = books.adoptStock(loaded ?? 24);
    if (!ok) {
      throw StateError(
          'stored stock $loaded violates the non-negative governance rule');
    }
  }

  void _adoptCash(double? loaded) {
    final ok = books.adoptCash(loaded ?? 0);
    if (!ok) {
      throw StateError(
          'stored cash $loaded violates the non-negative governance rule');
    }
  }

  /// Forces every book's latest value to the store (a settled write),
  /// without releasing the cells. This is the kiosk's sync button.
  Future<void> saveAll() async {
    await stockMemory?.save();
    await cashMemory?.save();
    await ordersMemory?.save();
  }

  /// The sync button's conflict path. A `MemoryConflict` on the stock
  /// book means the other kiosk won the race: the boundary adopts the
  /// winner's payload through the governed gate and reports the winner's
  /// revision and generation — the provenance the demo is about. Cash
  /// and orders adopt the same way; anything else rethrows.
  Future<void> syncAll() async {
    try {
      await stockMemory?.save();
    } on MemoryConflict catch (conflict) {
      final stored = conflict.stored;
      if (stored == null) rethrow;
      final winner = stored.payload as int;
      final ok = books.adoptStock(winner);
      books.denials.emit(ok
          ? 'stock conflict at expected revision ${conflict.expected}: '
              'adopted winner revision ${stored.revision} '
              'generation ${stored.generation} payload $winner'
          : 'stock conflict: winner payload $winner was rejected by '
              'governance');
    }
    try {
      await cashMemory?.save();
    } on MemoryConflict catch (conflict) {
      final stored = conflict.stored;
      if (stored == null) rethrow;
      books.adoptCash(stored.payload as double);
      books.denials.emit(
          'cash conflict: adopted winner generation ${stored.generation}');
    }
    try {
      await ordersMemory?.save();
    } on MemoryConflict catch (conflict) {
      final stored = conflict.stored;
      if (stored == null) rethrow;
      books.adoptOrders(stored.payload as int);
      books.denials.emit(
          'orders conflict: adopted winner generation ${stored.generation}');
    }
  }

  /// Forces every book's latest value to the store (a settled write),
  /// then releases the cells. The store is closed only when this
  /// boundary owns it.
  Future<void> dispose() async {
    await stockMemory?.save();
    await cashMemory?.save();
    await ordersMemory?.save();
    await stockMemory?.unload();
    await cashMemory?.unload();
    await ordersMemory?.unload();
    if (ownsStore) {
      await store.close();
    }
  }
}
