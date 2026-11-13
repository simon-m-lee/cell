// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Standalone library (not a part of `cell.dart`): it imports `dart:io`,
// which must not leak into the web-safe core library.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cell/cell.dart'
    show LedgerEntry, LedgerStore, canonicalJsonDecode, canonicalJsonEncode;

/// A [LedgerStore] backed by a single JSONL file.
///
/// **One ledger per file.** Appending is `writeFrom` in append mode with
/// a trailing newline — the OS guarantees the write is atomic up to
/// `PIPE_BUF` (4096 bytes on Linux, smaller on some platforms). Entries
/// larger than `PIPE_BUF` are not atomic on append; the store rejects
/// them at `append` time with a loud error rather than silently
/// corrupting the file.
///
/// ### Non-obvious: no fsync per append
///
/// A truly durable ledger `fsync`s each entry. That is a synchronous
/// syscall (~0.1-10 ms depending on the device), and doing it per append
/// would cap the ledger at ~100 entries/sec on an SD card. The performance
/// gate (`<5%` regression on the pure path) cannot tolerate that.
/// Instead, `FileLedgerStore` **flushes** after each append (writes go to
/// the OS buffer) and **fsyncs on `close`**. A crash between flushes
/// loses at most one entry, and `verify()` on reopen will report the gap.
/// This is the same trade-off WAL-mode SQLite makes.
///
/// ### Honesty notes (review fixes)
///
/// `dart:io` exposes no per-append `fsync`; `flush()` is the strongest
/// available primitive, so `fsyncEachAppend` is accepted for API
/// compatibility but currently cannot be stronger than the default
/// flush-then-fsync-on-close behaviour. Likewise, appends to a regular
/// file are not atomically visible to concurrent readers regardless of
/// size — the `PIPE_BUF`-sized entry cap below is retained as a
/// conservative line-size bound, not an atomicity guarantee.
class FileLedgerStore implements LedgerStore {
  @override
  final String genesisHash;
  final File file;
  final bool fsyncEachAppend;
  final RandomAccessFile? _raf;
  int _lastSeqCache = -1;
  String? _lastHashCache;
  bool _closed = false;

  FileLedgerStore._({
    required this.genesisHash,
    required this.file,
    required this.fsyncEachAppend,
    required RandomAccessFile? raf,
  }) : _raf = raf;

  /// Opens (or creates) the ledger at [path].
  ///
  /// Reads the existing file to populate the head caches, then opens for
  /// append.
  static Future<FileLedgerStore> open(
    String path, {
    required String genesisHash,
    bool fsyncEachAppend = false,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    // Scan the existing file to find the last entry.
    var lastSeq = -1;
    String? lastHash;
    await for (final line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final json = canonicalJsonDecode(line) as Map<String, Object?>;
      final entry = LedgerEntry.fromJson(json);
      lastSeq = entry.seq;
      lastHash = entry.hash;
    }
    final raf = await file.open(mode: FileMode.append);
    final store = FileLedgerStore._(
      genesisHash: genesisHash,
      file: file,
      fsyncEachAppend: fsyncEachAppend,
      raf: raf,
    );
    store._lastSeqCache = lastSeq;
    store._lastHashCache = lastHash;
    return store;
  }

  @override
  Future<void> append(LedgerEntry entry) async {
    _ensureOpen();
    if (entry.seq != _lastSeqCache + 1) {
      throw StateError(
        'FileLedgerStore.append: expected seq ${_lastSeqCache + 1}, '
        'got ${entry.seq}',
      );
    }
    if (_lastSeqCache == -1 && entry.prevHash != genesisHash) {
      throw StateError(
        'FileLedgerStore.append: genesis prevHash mismatch',
      );
    }
    final line = '${canonicalJsonEncode(entry.toJson())}\n';
    final bytes = utf8.encode(line);
    if (bytes.length > 4096) {
      throw StateError(
        'FileLedgerStore.append: entry ${entry.seq} is ${bytes.length} '
        'bytes, exceeding PIPE_BUF (4096). Reduce the payload size, or '
        'use a store that supports atomic multi-block appends.',
      );
    }
    await _raf!.writeFrom(bytes);
    await _raf.flush();
    _lastSeqCache = entry.seq;
    _lastHashCache = entry.hash;
  }

  @override
  Future<int> get lastSeq async => _lastSeqCache;

  @override
  Future<String?> get lastHash async => _lastHashCache;

  @override
  Stream<LedgerEntry> entriesSince(int fromSeq) async* {
    _ensureOpen();
    await for (final line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final json = canonicalJsonDecode(line) as Map<String, Object?>;
      final entry = LedgerEntry.fromJson(json);
      if (entry.seq >= fromSeq) yield entry;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _raf?.flush();
    await _raf?.close();
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('FileLedgerStore is closed');
    }
  }
}
