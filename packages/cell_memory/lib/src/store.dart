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
///
/// ### When to use
/// Use [MemoryStore] when writing a new durable backend, or take a
/// `MemoryStore` parameter to stay backend-agnostic. The shipped backends —
/// [FileMemoryStore], [InMemoryMemoryStore], and any future Firestore
/// backend — honour the same contract unchanged, so application code that
/// depends on [MemoryCell] does not need to know which backend it holds.
///
/// Do **not** use [MemoryStore] as the primary user surface. Application
/// code depends on [MemoryCell], which consumes a store internally; the
/// store is the port the cell is built on, not the cell itself.
///
/// ### How it works
/// 1. **Read** — [read] returns the envelope stored under an id, or `null`
///    when absent. It throws [MemoryCorrupt] on unreadable bytes; it never
///    throws [MemoryConflict] (a read does not race with itself).
/// 2. **Write** — [write] installs an envelope only when the stored
///    revision equals [expectedRevision]. `0` means "must be absent".
///    Otherwise it throws [MemoryConflict] and leaves the stored record
///    unchanged. The envelope's revision must be `expectedRevision + 1`,
///    and its generation must match the stored row's.
/// 3. **Remove** — [remove] deletes the record. A concurrent writer sees
///    a [MemoryConflict] on its next [write] via the generation mismatch,
///    which is the intended detection.
/// 4. **Close** — [close] stops admission and waits for in-flight calls
///    already admitted. It is not idempotent; a second close throws
///    [StateError].
///
/// ### Non-obvious
/// - **The contract is the portability guarantee.** A backend that skips
///   [MemoryStoreCas] has broken the contract — a value written by that
///   backend can no longer be loaded by another. Every shipped backend
///   uses [MemoryStoreCas] unchanged.
/// - **Atomicity and CAS are separate concerns.** Atomic-per-id (no torn
///   reads) is a backend obligation. CAS on [MemoryEnvelope.revision] is
///   a caller obligation enforced by [MemoryStoreCas]. A backend that
///   implements atomicity but not CAS loses concurrent writes silently.
/// - **Per-id locking is in-process.** A backend that must survive two
///   processes writing the same id (one app instance plus one scheduler,
///   say) needs a cross-process lock — a file lock, a backend transaction
///   — in addition to this interface. The contract does not demand it.
///
/// See also:
/// - [MemoryStoreCas] — the shared compare-and-swap rules every backend
///   uses before writing.
/// - [MemoryEnvelope] — the document every backend persists.
/// - [MemoryStoreException] — the sealed base of every backend error.
/// - [FileMemoryStore] — the `dart:io` backend.
/// - [InMemoryMemoryStore] — the in-memory test double.
///
/// ### AI Agent Guide
/// **Layer:** Memory — the backend port. Not a Cell, not a Flow, not a
/// Tissue book. A store persists one [MemoryEnvelope] per id.
/// **When to use:** implement a new durable backend; or take a
/// `MemoryStore` parameter to stay backend-agnostic.
/// **When NOT to use:**
///   - as the primary user surface — callers should depend on
///     [MemoryCell], which uses a store internally;
///   - when the collection is a book with row history — that is
///     `cell_tissue`, not `cell_memory`;
///   - when the write needs to be visible on another process — the port is
///     in-process and does not carry a cross-process lock.
/// **Live signature:** `abstract interface class MemoryStore` — pinned at
/// `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryCell] (the Cell wrapper that consumes a
/// store) or the core `cell` package (reactive graph, no persistence).
/// **Guide:** see the memory HowTo for "writing a new MemoryStore backend".
/// **Example:** `example/memory_example.dart`.
/// **Cross-layer:** a store never decides policy — the write policy is on
/// [MemoryWritePolicy] and the value movement is on [MemoryCell]; a store
/// only commits or conflicts.
/// **Minimal compilable example**
/// ```dart
/// final MemoryStore store = InMemoryMemoryStore();
/// final env = MemoryEnvelope(
///   id: 'k',
///   revision: 1,
///   generation: MemoryEnvelope.mintGeneration(),
///   payload: 7,
/// );
/// await store.write(env, expectedRevision: 0);
/// print((await store.read('k'))?.payload); // 7
/// await store.close();
/// ```
abstract interface class MemoryStore {
  /// Reads the envelope stored under [id], or `null` when absent.
  ///
  /// **Throws:** [MemoryCorrupt] on unreadable bytes, an unknown schema, or
  /// any strict-validation failure. Never throws [MemoryConflict] — a
  /// missing id is `null`, not a conflict, because a read does not race
  /// with itself.
  ///
  /// **Consistency:** the returned [MemoryEnvelope] is the whole record
  /// (payload included), not a reference. Mutating the returned map cannot
  /// change what a subsequent [read] returns. This is the "no torn reads"
  /// half of the atomicity guarantee.
  Future<MemoryEnvelope?> read(String id);

  /// Installs [envelope] only when the stored revision equals
  /// [expectedRevision]. `0` means "must be absent". Otherwise throws
  /// [MemoryConflict] and leaves the stored record unchanged.
  ///
  /// The envelope must carry `revision == expectedRevision + 1`; a
  /// mismatched number is [MemoryCorrupt], not a conflict. The generation
  /// carried on [envelope] must match the stored row's generation, or the
  /// write is a [MemoryConflict] (the delete-and-recreate ABA case).
  /// [MemoryStoreCas] implements all three checks; every backend uses it
  /// so the rules cannot drift.
  ///
  /// An envelope that exactly repeats the stored `(id, revision,
  /// generation, payload)` at `expectedRevision` or `expectedRevision + 1`
  /// is a **successful no-op** — the lost-response retry case. See
  /// [MemoryStoreCas.isIdempotentRetry].
  Future<void> write(MemoryEnvelope envelope, {required int expectedRevision});

  /// Deletes the durable record for [id]. Removing an absent id succeeds.
  ///
  /// **Not a CAS operation**: [remove] does not check a revision. A
  /// concurrent writer that read the record before the delete will see a
  /// [MemoryConflict] on its next [write] (generation mismatch), which is
  /// the intended detection — the delete is the "lose" and the concurrent
  /// writer is the loser. Use [MemoryCell.remove] to get the full drain,
  /// fence, and delete sequence; a raw [remove] is the backend primitive.
  Future<void> remove(String id);

  /// Ids this store currently holds. Order is unspecified.
  ///
  /// **Snapshot semantics:** implementations must return a settled view —
  /// a write that was already in flight when [list] was called is either
  /// fully included or fully absent. The shipped stores satisfy this by
  /// waiting for their in-flight operations before scanning.
  ///
  /// A malformed id in the store (e.g. a file whose name fails
  /// [MemoryIdGrammar]) is [MemoryCorrupt], not a silent omission: a store
  /// with unreadable records is a store a caller must be told about.
  Future<List<String>> list();

  /// Closes the store. The first call closes it; later calls throw
  /// [StateError].
  ///
  /// [close] waits for the calls already admitted; a call that started
  /// before [close] and is queued on a per-id chain still finishes. After
  /// [close] returns, every subsequent [read], [write], [remove], [list],
  /// or [close] throws [StateError] (message supplied by the backend at
  /// construction). The backend never reopens — a closed store is a
  /// terminal state.
  Future<void> close();
}

/// Base type of the store exception hierarchy.
///
/// Subtypes: [MemoryCorrupt], [MemoryIoException], and [MemoryConflict].
///
/// ### AI Agent Guide
/// **Layer:** Memory — exception base. Not a supported public API for
/// pattern matching beyond the three concrete subtypes.
/// **When to use:** catch [MemoryStoreException] when the reaction is the
/// same for all store failures ("log and retry the whole operation"); catch
/// a concrete subtype when the reaction depends on the kind of failure.
/// **When NOT to use:** `catch (e)` on raw `Object` — the sealed hierarchy
/// exists so every store failure is one of exactly three shapes.
/// **Live signature:** `sealed class MemoryStoreException implements
/// Exception` — pinned at `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** `StateError` from a closed store (that is a
/// lifecycle error, not a store failure), or `ArgumentError` from
/// [MemoryIdGrammar.check] (invalid input, not corrupt data).
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
///
/// **Not a transient error.** A [MemoryCorrupt] means the durable record is
/// wrong and will remain wrong on retry — only a caller-initiated repair
/// (`remove` + re-create, or a migration) can clear it. A retry loop around
/// a [MemoryCorrupt] will spin forever.
///
/// ### AI Agent Guide
/// **Layer:** Memory — exception type.
/// **When to use:** catch it to surface a corrupt record to the user or a
/// migration tool; the caller decides whether to delete and re-create.
/// **When NOT to use:** as the reaction to a transient backend failure —
/// that is [MemoryIoException]; or to a lost CAS race — that is
/// [MemoryConflict].
/// **Live signature:** `const MemoryCorrupt(String message)` — pinned at
/// `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryIoException] (IO failed; bytes may
/// still be recoverable) or [MemoryConflict] (CAS loser; data is intact).
/// **Minimal compilable example**
/// ```dart
/// try {
///   throw const MemoryCorrupt('bad payload');
/// } on MemoryCorrupt catch (e) {
///   print(e.message); // bad payload
/// }
/// ```
final class MemoryCorrupt extends MemoryStoreException {
  /// Creates a corrupt-data error.
  const MemoryCorrupt(super.message);
}

/// A file or backend IO failure, wrapped with the path when known.
///
/// **The underlying error is preserved on [cause].** A [MemoryIoException]
/// is the durable port's contract-shaped wrapper around an
/// implementation-specific error (e.g. a `FileSystemException` on the file
/// backend, a Firestore `FirebaseException` on the cloud backend). A caller
/// that wants to distinguish "disk full" from "permission denied" reads
/// [cause]; a caller that only wants "the write failed, retry" reads the
/// exception type.
///
/// ### AI Agent Guide
/// **Layer:** Memory — exception type.
/// **When to use:** catch it to retry or report a backend IO failure
/// (disk full, permission, network). Read [cause] for the specific error.
/// **When NOT to use:** for corrupt data — that is [MemoryCorrupt]; or for
/// a CAS loser — that is [MemoryConflict]. An IO error means the IO failed,
/// not that the data is wrong.
/// **Live signature:** `MemoryIoException(String message, {String? path,
/// Object? cause})` — pinned at `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryCorrupt] (data is wrong) or
/// [MemoryConflict] (concurrent writer won).
/// **Minimal compilable example**
/// ```dart
/// try {
///   throw MemoryIoException('disk full', path: '/data/x.json');
/// } on MemoryIoException catch (e) {
///   print(e.path);  // /data/x.json
///   print(e.cause); // null
/// }
/// ```
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
///
/// **Not a fault in the system** — a [MemoryConflict] is the CAS working
/// as designed: a concurrent writer, a stale writer, or a delete-and-
/// recreate got in the way and the framework detected it. The correct
/// reaction is usually "read the current revision and retry" — never "log
/// and give up".
///
/// ### AI Agent Guide
/// **Layer:** Memory — exception type.
/// **When to use:** catch it to retry with a fresh expected revision, or
/// to surface a lost update to the user. Read [actual] for the stored
/// revision and [stored] for the stored row (when the backend supplies it).
/// **When NOT to use:** as the reaction to an idempotent retry — those are
/// no-ops ([MemoryStoreCas.isIdempotentRetry]) and never raise a conflict.
/// **Live signature:** `MemoryConflict({required int expected, required
/// int actual, MemoryEnvelope? stored})` — pinned at `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryCorrupt] (data is wrong) or
/// [MemoryIoException] (IO failed). A conflict means the data is intact and
/// the writer is stale.
/// **Minimal compilable example**
/// ```dart
/// try {
///   throw MemoryConflict(expected: 4, actual: 5);
/// } on MemoryConflict catch (e) {
///   print('retry from ${e.actual}'); // retry from 5
/// }
/// ```
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
/// between them.
///
/// ### When to use
/// Use [MemoryStoreCas] when implementing a new [MemoryStore] backend: call
/// [isIdempotentRetry] first, then [checkRevision], [checkGeneration], and
/// [checkNumbering] in that order, before any bytes move.
///
/// Do **not** use [MemoryStoreCas] from application code. Application code
/// goes through [MemoryCell], which calls the store; the store calls these
/// checks.
///
/// ### How it works
/// The call order in every store is:
///
/// 1. [isIdempotentRetry]: an envelope that repeats the record the store
///    already holds — either at the expected revision (a plain retry) or at
///    `expected + 1` (the lost-response case: the write already committed
///    and the caller retried) — is a successful no-op. [MemoryEnvelope
///    .sameContent] includes the generation, so a retry with a new
///    generation is not a no-op.
/// 2. [checkRevision]: otherwise the stored revision must equal
///    `expectedRevision`, or [MemoryConflict] is thrown and nothing is
///    written.
/// 3. [checkGeneration]: the stored row's generation must equal the
///    envelope's — a stale generation after a delete-and-recreate is a
///    conflict, closing the revision-number ABA hole.
/// 4. [checkNumbering]: the envelope must be numbered `expectedRevision +
///    1`.
///
/// ### Non-obvious
/// - **The four calls are one decision.** A backend that runs them out of
///   order, or skips one, breaks the contract for every other backend.
///   [isIdempotentRetry] must run first (it short-circuits);
///   [checkNumbering] last (it is a bug in the *caller*, not a race).
/// - **`stored` rides on the conflict.** [checkRevision] and
///   [checkGeneration] pass the stored row to [MemoryConflict] when the
///   caller has it in hand, so the recovery path does not need a second
///   [MemoryStore.read].
/// - **Null `existing` means "absent".** [checkGeneration] treats a null
///   row as "nothing to compare" and returns; the caller has already
///   required `expectedRevision == 0` (asserted by [checkRevision]).
///
/// See also:
/// - [MemoryStore] — the contract these checks implement.
/// - [MemoryEnvelope.sameContent] — the equality used by
///   [isIdempotentRetry].
/// - [MemoryConflict] — the exception thrown by [checkRevision] and
///   [checkGeneration].
///
/// ### AI Agent Guide
/// **Layer:** Memory — the CAS rule engine. Not a Cell, not a Flow.
/// **When to use:** implement a new [MemoryStore] backend; call
/// [isIdempotentRetry] then the three checks in order before any bytes
/// move.
/// **When NOT to use:** from application code — a backend calls these;
/// a caller goes through [MemoryCell].
/// **Live signature:** `abstract final class MemoryStoreCas` — pinned at
/// `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** [MemoryCell.save] (encodes the current value
/// and calls a store; the store calls these checks).
/// **Minimal compilable example**
/// ```dart
/// final env = MemoryEnvelope(
///   id: 'x',
///   revision: 2,
///   generation: MemoryEnvelope.mintGeneration(),
///   payload: 42,
/// );
/// MemoryStoreCas.checkRevision(1, 1);              // ok
/// MemoryStoreCas.checkNumbering(env, 1);           // ok
/// MemoryStoreCas.checkGeneration(null, env, 1);    // ok
/// ```
abstract final class MemoryStoreCas {
  /// Whether writing [envelope] with [expectedRevision] repeats a record
  /// the store already holds, and is therefore a successful no-op.
  ///
  /// Two shapes count: the stored revision equals [expectedRevision] (a
  /// plain retry of an uncommitted write), or it equals
  /// `expectedRevision + 1` with the same content (the lost-response case:
  /// this writer's commit landed and the response was lost).
  ///
  /// **Call first.** A retry must not be treated as a conflict; a
  /// non-retry must not be short-circuited. [MemoryEnvelope.sameContent]
  /// includes the generation, so a retry that re-minted a generation is a
  /// conflict, not a no-op.
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
  ///
  /// **Call last.** A mismatch is [MemoryCorrupt], not [MemoryConflict] —
  /// it is a caller bug (the envelope was built with the wrong revision
  /// number), not a race. The stored record is not inspected; this check
  /// runs regardless of what the store holds.
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
  ///
  /// **Call second** (after [isIdempotentRetry] returns `false`). The
  /// conflict's [MemoryConflict.actual] carries the stored revision; the
  /// recovery path can retry from there without a second [MemoryStore
  /// .read].
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
  ///
  /// **Call third.** Together with [checkRevision] this closes the
  /// revision-number ABA hole: a stale writer sees the same revision as
  /// the fresh record and would otherwise be indistinguishable from a
  /// normal update.
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