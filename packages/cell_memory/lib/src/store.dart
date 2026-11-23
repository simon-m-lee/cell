// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'envelope.dart';

/// The durable backend contract for `cell_memory`.
///
/// Contract:
///
/// - [write] is atomic per id. Readers never observe a torn envelope.
/// - [write] is compare-and-swap on [expectedRevision]. Two writers that
///   both read revision 4 cannot both install revision 5; the loser gets
///   [MemoryConflict].
/// - [write] of an equal `(id, revision, payload)` when [expectedRevision]
///   already matches is a successful no-op.
/// - [read] returns `null` when the id is absent. It throws on corrupt data.
/// - [close] may be called once; later calls throw [StateError].
/// - Implementations are safe for concurrent calls on the same id; they
///   serialise per id. Different ids do not share a lock.
abstract interface class MemoryStore {
  /// Reads the envelope stored under [id], or `null` when absent.
  ///
  /// Throws [MemoryCorrupt] on corrupt data.
  Future<MemoryEnvelope?> read(String id);

  /// Installs [envelope] only when the stored revision equals
  /// [expectedRevision]. `0` means "must be absent". Otherwise throws
  /// [MemoryConflict] and leaves the stored record unchanged.
  Future<void> write(MemoryEnvelope envelope, {required int expectedRevision});

  /// Deletes the durable record for [id]. Removing an absent id succeeds.
  Future<void> remove(String id);

  /// Ids this store currently holds. Order is unspecified.
  Future<List<String>> list();

  /// Closes the store. The first call closes it; later calls throw
  /// [StateError].
  Future<void> close();
}

/// Base type of the store exception hierarchy.
///
/// Subtypes: [MemoryCorrupt], [MemoryIoException], and [MemoryConflict].
sealed class MemoryStoreException implements Exception {
  /// Creates a store exception.
  const MemoryStoreException(this.message);

  /// A human-readable description.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Stored data is unreadable: bad JSON, an unknown schema, a lone `.tmp`
/// file, a decode failure, or an envelope that fails strict validation.
final class MemoryCorrupt extends MemoryStoreException {
  /// Creates a corrupt-data error.
  const MemoryCorrupt(super.message);
}

/// A file or backend IO failure, wrapped with the path when known.
final class MemoryIoException extends MemoryStoreException {
  /// Creates an IO error with an optional [path] and [cause].
  MemoryIoException(String message, {this.path, this.cause})
      : super(path == null ? message : '$message (path: $path)');

  /// The path the IO touched, when known.
  final String? path;

  /// The underlying error, when known.
  final Object? cause;
}

/// [MemoryStore.write] saw a revision or generation other than the one
/// the writer expected.
///
/// The store leaves the stored record unchanged. Carries both revisions so
/// the caller can decide whether to retry or surface the conflict, and the
/// stored row itself when the backend has it in hand ([stored] is null only
/// for hand-written test doubles).
final class MemoryConflict extends MemoryStoreException {
  /// Creates a conflict for [expected] against [actual].
  MemoryConflict({
    required this.expected,
    required this.actual,
    this.stored,
  }) : super('expected revision $expected, store holds $actual');

  /// The revision the writer expected.
  final int expected;

  /// The revision the store actually holds (0 when absent).
  final int actual;

  /// The row the store holds, when the backend can hand it over. Null for
  /// stores that only report revisions.
  final MemoryEnvelope? stored;
}

/// Validates the store-side compare-and-swap bookkeeping shared by every
/// backend before any bytes move.
///
/// Backend implementations use this so the CAS contract cannot drift
/// between them. The call order in every store is:
///
/// 1. [isIdempotentRetry]: an envelope that repeats the record the store
///    already holds — either at the expected revision (a plain retry) or at
///    `expected + 1` (the lost-response case: the write already committed
///    and the caller retried) — is a successful no-op. `sameContent`
///    includes the generation, so a retry with a new generation is not a
///    no-op.
/// 2. [checkRevision]: otherwise the stored revision must equal
///    `expectedRevision`, or [MemoryConflict] is thrown and nothing is
///    written.
/// 3. [checkGeneration]: the stored row's generation must equal the
///    envelope's — a stale generation after a delete-and-recreate is a
///    conflict, closing the revision-number ABA hole.
/// 4. [checkNumbering]: the envelope must be numbered `expectedRevision + 1`.
abstract final class MemoryStoreCas {
  /// Whether writing [envelope] with [expectedRevision] repeats a record
  /// the store already holds, and is therefore a successful no-op.
  ///
  /// Two shapes count: the stored revision equals [expectedRevision] (a
  /// plain retry of an uncommitted write), or it equals
  /// `expectedRevision + 1` with the same content (the lost-response case:
  /// this writer's commit landed and the response was lost).
  static bool isIdempotentRetry(
    MemoryEnvelope? existing,
    MemoryEnvelope envelope,
    int expectedRevision,
  ) {
    if (existing == null || !existing.sameContent(envelope)) return false;
    return existing.revision == expectedRevision ||
        existing.revision == expectedRevision + 1;
  }

  /// Checks [envelope] numbering against [expectedRevision].
  static void checkNumbering(MemoryEnvelope envelope, int expectedRevision) {
    if (envelope.revision != expectedRevision + 1) {
      throw MemoryCorrupt(
        'envelope revision ${envelope.revision} is not '
        'expectedRevision + 1 ($expectedRevision + 1)',
      );
    }
  }

  /// Compares [storedRevision] against [expectedRevision], throwing
  /// [MemoryConflict] on a mismatch. [stored] rides on the conflict when
  /// the caller has the row in hand.
  static void checkRevision(
    int storedRevision,
    int expectedRevision, {
    MemoryEnvelope? stored,
  }) {
    if (storedRevision != expectedRevision) {
      throw MemoryConflict(
        expected: expectedRevision,
        actual: storedRevision,
        stored: stored,
      );
    }
  }

  /// Compares the stored row's generation against the envelope's.
  ///
  /// With [existing] null there is no generation to compare (the caller has
  /// already required `expectedRevision == 0`). A mismatch throws
  /// [MemoryConflict] carrying the stored row: a stale writer that still
  /// carries a previous life's generation must never install a revision
  /// into the recreated history.
  static void checkGeneration(
    MemoryEnvelope? existing,
    MemoryEnvelope envelope,
    int expectedRevision,
  ) {
    if (existing == null) return;
    if (existing.generation != envelope.generation) {
      throw MemoryConflict(
        expected: expectedRevision,
        actual: existing.revision,
        stored: existing,
      );
    }
  }
}
