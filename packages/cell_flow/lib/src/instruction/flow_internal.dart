// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Shared internal helpers for the operator instruction files. This library
// is intentionally NOT exported from the public `cell_flow` surface.

import 'dart:async';

/// Drains a nested inner sequence.
///
/// [inner] may be a `Stream`, `Future`, `Iterable` (excluding `String`), or
/// a plain scalar. Each produced value is passed to [onData]; when
/// [stillLive] returns `false` the drain aborts (an `await for` abort also
/// cancels the stream subscription).
///
/// Long iterables yield to the event loop every 256 items so a synchronous
/// burst cannot starve timers and I/O.
Future<void> drainInner(
  Object? inner,
  void Function(dynamic value) onData, {
  bool Function()? stillLive,
}) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await drainInner(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await Future<dynamic>.value(inner);
    await drainInner(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    var count = 0;
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await drainInner(event, onData, stillLive: stillLive);
      if (++count % 256 == 0) {
        // Cooperative yield: keep long synchronous iterables from blocking
        // the event loop.
        await Future<void>.delayed(Duration.zero);
      }
    }
    return;
  }

  onData(inner);
}

/// A sequential job queue: each job runs only after the previous one
/// completes, and a failing job does not break the chain.
class SequentialQueue {
  /// The tail of the async queue.
  Future<void> tail = Future<void>.value();

  /// Enqueues a job to run after the current tail completes.
  void enqueue(Future<void> Function() job) {
    tail = tail.then((_) => job()).catchError((_) {});
  }
}
