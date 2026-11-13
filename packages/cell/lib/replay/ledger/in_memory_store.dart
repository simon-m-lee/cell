// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell.dart';

/// An in-memory [LedgerStore], suitable for tests and for ephemeral
/// graphs whose ledger does not need to survive the process.
///
/// `append` is synchronous in spirit (no I/O) but the API is `Future`
/// because the abstract store is async. The Future resolves immediately.
class InMemoryLedgerStore implements LedgerStore {
  @override
  final String genesisHash;
  final List<LedgerEntry> _entries = [];
  bool _closed = false;

  InMemoryLedgerStore({required this.genesisHash});

  @override
  Future<void> append(LedgerEntry entry) async {
    _ensureOpen();
    final expected = _entries.isEmpty ? 0 : _entries.last.seq + 1;
    if (entry.seq != expected) {
      throw StateError(
        'InMemoryLedgerStore.append: expected seq $expected, '
        'got ${entry.seq}',
      );
    }
    if (_entries.isEmpty && entry.prevHash != genesisHash) {
      throw StateError(
        'InMemoryLedgerStore.append: genesis prevHash mismatch '
        '(expected $genesisHash, got ${entry.prevHash})',
      );
    }
    _entries.add(entry);
  }

  @override
  Future<int> get lastSeq async => _entries.isEmpty ? -1 : _entries.last.seq;

  @override
  Future<String?> get lastHash async =>
      _entries.isEmpty ? null : _entries.last.hash;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    _ensureOpen();
    // `fromSeq` is used as a list index here. The store enforces strict
    // seq ordering from 0, so the list is dense and index == sequence —
    // equivalent to the file store's sequence-number interpretation for
    // every valid ledger.
    for (var i = fromSeq; i < _entries.length; i++) {
      yield _entries[i];
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('InMemoryLedgerStore is closed');
    }
  }
}
