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
/// - A call that has entered [run] finishes, even if [close] flips the
///   flag while it is queued on a per-id chain.
/// - A call that has not entered [run] when [close] flips the flag throws
///   [StateError] with [closedMessage].
/// - [close] waits for the calls already inside. A second [close] throws.
/// - [op] is called on the same stack as [run] — the future is recorded
///   before [op] runs and before any `await` between the flag check and
///   the record, so [close] cannot slip between them.
final class StoreLifecycle {
  /// Creates a lifecycle whose late-call and double-close error is
  /// [closedMessage].
  StoreLifecycle(this.closedMessage);

  /// The [StateError] message for a late call and a second [close].
  final String closedMessage;

  bool _accepting = true;

  final List<Future<void>> _pending = [];

  /// Whether new calls are still admitted.
  bool get accepting => _accepting;

  /// The in-flight operations at this instant, for `list()` snapshots.
  List<Future<void>> get inflight => List<Future<void>>.of(_pending);

  /// Runs [op] under the admission barrier.
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
