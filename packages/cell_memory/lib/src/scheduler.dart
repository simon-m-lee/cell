// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

/// Schedules the debounced store write for a memory cell.
///
/// The production default is [TimerScheduler]. Tests pass [ManualScheduler]
/// and call [ManualScheduler.elapse]; no test waits out the debounce window
/// on a real timer.
abstract interface class MemoryScheduler {
  /// Schedules [run] after [delay], replacing any pending schedule.
  void schedule(Duration delay, void Function() run);

  /// Cancels the pending schedule, if any.
  void cancel();
}

/// A scheduler backed by a real [Timer].
final class TimerScheduler implements MemoryScheduler {
  Timer? _timer;

  @override
  void schedule(Duration delay, void Function() run) {
    _timer?.cancel();
    _timer = Timer(delay, run);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// A deterministic scheduler for tests.
///
/// [schedule] stores the pending callback; [elapse] fires it as if the
/// delay had passed. [lastDelay] records the most recent schedule's delay
/// and [elapsed] accumulates every elapse, so tests can assert both.
final class ManualScheduler implements MemoryScheduler {
  void Function()? _run;

  /// Whether a callback is currently pending.
  bool get isPending => _run != null;

  /// The delay of the most recent [schedule].
  Duration? lastDelay;

  /// The total elapse time across [elapse] calls.
  Duration elapsed = Duration.zero;

  @override
  void schedule(Duration delay, void Function() run) {
    lastDelay = delay;
    _run = run;
  }

  @override
  void cancel() {
    _run = null;
  }

  /// Fires the pending callback, if any, as if [dt] had elapsed.
  void elapse([Duration dt = Duration.zero]) {
    elapsed += dt;
    final run = _run;
    _run = null;
    if (run != null) run();
  }
}
