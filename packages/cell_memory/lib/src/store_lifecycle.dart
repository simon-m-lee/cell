// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

/// The admission and shutdown barrier shared by every store backend.
///
/// Not exported from the package barrel: backends import it directly (the
/// Firebase package with an `implementation_imports` ignore). A copy in
/// each backend would drift; this type is not a supported public API.
///
/// Semantics:
///
/// - A call that has entered [run] finishes, even if [close] closes
///   admission while it is queued on a per-id chain.
/// - A call that has not entered [run] when [close] closes admission
///   throws [StateError] with [closedMessage].
/// - [close] waits for the calls already inside. A second [close] throws.
/// - [op] is called on the same stack as [run] — the future is recorded
///   before [op] runs and before any `await` between the admission check
///   and the record, so [close] cannot slip between them.
///
/// ### When to use
/// Use [StoreLifecycle] when writing a new [MemoryStore] backend (or any
/// similar asynchronous resource) and you need the same "a call that has
/// entered finishes, a call that has not entered throws" guarantee the
/// shipped stores provide.
///
/// Do **not** use it in application code. A caller holds a [MemoryStore]
/// and calls its methods; the backend's own `close()` is the only
/// lifecycle call an application should make, and it delegates to this
/// barrier internally.
///
/// ### How it works
/// 1. **[run]** checks admission synchronously. If the barrier is already
///    closed, [run] throws [StateError] on the same stack — no future,
///    no queued work.
/// 2. **[run]** records the call as in-flight *before* calling [op], so a
///    concurrent [close] that closes admission has already seen this
///    call.
/// 3. **[run]** calls [op] synchronously and, when [op] settles, releases
///    the in-flight record. A synchronous throw from [op] becomes a
///    rejected future for the caller.
/// 4. **[close]** closes admission synchronously and returns `Future.wait`
///    over a snapshot of the in-flight calls. A second [close] throws
///    [StateError] — admission is already closed.
///
/// ### Non-obvious
/// - **[op] is called on [run]'s stack, not deferred.** If [op] throws
///   synchronously, [run] returns a rejected `Future.error` — the caller
///   sees a future rejection, not a synchronous throw. This is deliberate:
///   an in-flight operation, once admitted, behaves like every other
///   future-based operation.
/// - **[close] is not idempotent.** A second call throws [StateError]
///   with the same message as a late call. If you need idempotent
///   shutdown, wrap the call at the backend level; do not expect this
///   barrier to swallow the second close.
/// - **Admission closes before the wait.** A call that entered [run]
///   before admission closed will finish; a call that arrives after
///   admission closes throws. There is no window between "close was
///   requested" and "no new calls are admitted" — [run]'s check and
///   [close]'s close are both synchronous.
/// - **`inflight` returns a copy.** Mutating the returned list does not
///   affect the barrier; the internal in-flight list is never aliased
///   out.
/// - **Futures cannot be cancelled.** [close] waits for whatever was
///   admitted; a slow backend method blocks [close] for its duration.
///   Backends that must cap shutdown time have to impose their own
///   timeout above this barrier.
///
/// ### See also:
/// - [MemoryStore] — the contract this barrier serves.
/// - [FileMemoryStore], [InMemoryMemoryStore] — the shipped backends that
///   adopt this barrier.
///
/// ### AI Agent Guide
/// **Layer:** Memory — internal plumbing shared by every store backend.
/// Not exported from the barrel; not a supported public API.
/// **When to use:** implement a new [MemoryStore] backend and adopt the
/// same admission/close semantics as the shipped stores.
/// **When NOT to use:** application code — call the store's own `close()`
/// and let the backend handle the lifecycle.
/// **Live signature:** `final class StoreLifecycle` — pinned at
/// `cell_memory: 1.0.0`.
/// **Do NOT confuse with:** [MemoryStore.close] (the backend method that
/// wraps this barrier); this is the barrier itself.
/// **Guide:** see the memory HowTo for "writing a new MemoryStore
/// backend".
/// **Example:** `test/store_lifecycle_test.dart`.
/// **Cross-layer:** none — this is memory-internal. A Cell or Flow never
/// sees this type.
final class StoreLifecycle {
  /// Creates a lifecycle whose late-call and double-close error is
  /// [closedMessage].
  ///
  /// [closedMessage] is the text of the [StateError] thrown by a call
  /// that arrives after [close] (or by a second [close]). Choose a
  /// message that names the resource, e.g. `'FileMemoryStore is closed'`.
  StoreLifecycle(this.closedMessage);

  /// The [StateError] message for a late call and a second [close].
  final String closedMessage;

  bool _accepting = true;

  final List<Future<void>> _pending = [];

  /// Whether new calls are still admitted.
  ///
  /// `true` until [close] closes admission synchronously. There is no
  /// reopen: once this reads `false` it reads `false` forever.
  bool get accepting => _accepting;

  /// The in-flight operations at this instant, for `list()` snapshots.
  ///
  /// Returns a copy, never the internal in-flight list. Mutating the
  /// result does not affect the barrier; the snapshot is a point-in-time
  /// view of what [close] would wait for if it were called on the next
  /// stack turn.
  ///
  /// ### Non-obvious
  /// - The list is a snapshot, not a live view. A call that enters [run]
  ///   after [inflight] is read is not in the returned list — that is
  ///   the intended semantics, because a caller taking a snapshot wants
  ///   to know what was in-flight *at that instant*.
  List<Future<void>> get inflight => List<Future<void>>.of(_pending);

  /// Runs [op] under the admission barrier.
  ///
  /// If [op] returns normally, the barrier records [op]'s future and
  /// releases the in-flight entry when that future settles — whether it
  /// completes or errors. If [op] throws synchronously, the barrier
  /// still records and releases the entry, and returns a rejected
  /// [Future.error] to the caller.
  ///
  /// ### How it works
  /// 1. Checks admission. If closed, throws [StateError] with
  ///    [closedMessage] synchronously.
  /// 2. Registers the call as in-flight **before** calling [op]. This is
  ///    the barrier's load-bearing invariant: a concurrent [close] sees
  ///    this call as in-flight even if [op] itself has not started.
  /// 3. Calls [op] and, on a synchronous throw, releases the in-flight
  ///    record and returns `Future.error(error, stack)` so the caller
  ///    still receives a rejected future rather than a synchronous
  ///    throw.
  /// 4. On a normal return, wraps [op]'s future so the in-flight record
  ///    is released exactly once, on settle.
  ///
  /// ### Non-obvious
  /// - **The synchronous check is the whole point.** A caller that
  ///   entered [run] before [close] closed admission is guaranteed to
  ///   finish; a caller that did not throws immediately. There is no
  ///   "maybe accepted" state.
  /// - **`op` may itself be asynchronous.** [run] does not await it; it
  ///   only registers its future. The in-flight record is released when
  ///   that future settles.
  /// - **A synchronous throw still counts as an admitted operation.**
  ///   The in-flight record is released before [run] returns, so a
  ///   concurrent [close] does not wait for a call that already failed.
  ///
  /// ### Parameters:
  /// * [op]: The operation to admit. Called on the same stack as
  ///   [run], before any `await`. Its future is the value [run] returns
  ///   (subject to the barrier's `whenComplete` wrapper).
  ///
  /// ### Returns:
  /// A future that settles with [op]'s result once [op] settles. If [op]
  /// throws synchronously, a rejected future carrying the same error
  /// and stack.
  Future<T> run<T>(Future<T> Function() op) {
    if (!_accepting) throw StateError(closedMessage);
    final done = Completer<void>();
    _pending.add(done.future); // synchronous, before op()
    Future<T> future;
    try {
      future = op();
    } catch (error, stack) {
      _finish(done);
      return Future.error(error, stack);
    }
    return future.whenComplete(() => _finish(done));
  }

  /// Stops admission and waits for the admitted operations.
  ///
  /// Closes admission synchronously, then returns a future that completes
  /// when every in-flight call at the instant of the call has settled.
  /// Operations that were admitted before admission closed are included;
  /// operations that arrive after admission closes throw [StateError].
  ///
  /// ### How it works
  /// 1. Checks admission. If closed, throws [StateError] — a second
  ///    [close] is not idempotent.
  /// 2. Closes admission synchronously, before the wait.
  /// 3. Returns `Future.wait` over a snapshot of the in-flight calls.
  ///    The snapshot is taken inside the same stack turn as the close,
  ///    so no [run] can slip between "admission closed" and "in-flight
  ///    list snapshot".
  ///
  /// ### Non-obvious
  /// - **The close and the snapshot are one atomic step.** A call that
  ///   was admitted before the close is in the snapshot; a call that
  ///   arrives after the close throws. There is no window.
  /// - **A second [close] throws**, it does not silently succeed. That
  ///   is deliberate: two callers both closing the same store is a bug
  ///   in the caller, not a state to smooth over.
  /// - **`close` does not wait for future work.** Once the snapshot is
  ///   taken, no new calls can be admitted; the future completes when
  ///   everything in the snapshot settles. If a backend wants a
  ///   timeout, it must impose one above this call.
  ///
  /// ### Returns:
  /// A future that completes when all in-flight operations at the moment
  /// of the call have settled. It never completes with an error — the
  /// errors belong to the individual operations, not to [close].
  Future<void> close() {
    if (!_accepting) throw StateError(closedMessage);
    _accepting = false; // synchronous, before the wait
    return Future.wait(inflight);
  }

  void _finish(Completer<void> done) {
    if (!done.isCompleted) done.complete();
    _pending.remove(done.future);
  }
}