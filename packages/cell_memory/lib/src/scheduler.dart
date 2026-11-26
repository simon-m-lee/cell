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
///
/// ### When to use
/// Use [MemoryScheduler] when writing a [MemoryStore] backend, or a test
/// double, that needs to drive the debounced write path of a [MemoryCell]
/// deterministically. Pass a [TimerScheduler] in production; pass a
/// [ManualScheduler] in tests.
///
/// Do **not** use [MemoryScheduler] as a general-purpose timer or clock.
/// It is a one-shot replace-or-fire scheduler scoped to the memory write
/// path, not a recurring timer.
///
/// ### How it works
/// 1. **[schedule]** starts a new schedule for the given delay. Any
///    pending schedule is discarded — this is replace, not append.
/// 2. **Fire** — when the delay elapses, the scheduled callback runs once
///    and the schedule becomes empty. There is no "reschedule" between
///    runs; the caller must call [schedule] again.
/// 3. **[cancel]** discards the pending schedule without running it. If
///    nothing is pending, [cancel] is a no-op.
///
/// ### Non-obvious
/// - **Schedule replaces, never appends.** A second [schedule] call before
///   the first fires discards the first. That is the debounce contract: a
///   new input resets the window.
/// - **The callback runs at most once per [schedule] call.** A scheduler
///   that fires twice for one [schedule] is broken; a test double that
///   does so would mask a real debounce bug.
/// - **No error channel.** If the scheduled callback throws, the throw is
///   reported to the zone it runs in. The scheduler itself does not catch
///   it; a caller that needs error isolation wraps the callback.
/// - **No clock surface.** The scheduler does not expose "now" or "when
///   the pending schedule fires". A test that needs to know reads
///   [ManualScheduler.lastDelay]; production code does not need to.
///
/// ### See also
/// - [TimerScheduler] — the production implementation backed by a real
///   [Timer].
/// - [ManualScheduler] — the deterministic test implementation.
/// - [MemoryWritePolicy] — the policy that decides when a memory cell
///   calls [schedule].
///
/// ### AI Agent Guide
/// **Layer:** Memory — write-timing seam. Not a Cell, not a Flow, not a
/// Tissue book.
/// **When to use:** a new [MemoryStore] backend, or a test that needs to
/// control the debounce window deterministically.
/// **When NOT to use:** general timing — use a real `Timer` or a
/// `Stream.periodic`. This interface exists only to make the debounced
/// memory write testable.
/// **Live signature:** `abstract interface class MemoryScheduler` —
/// pinned at `cell_memory: 0.1.0`.
/// **Do NOT confuse with:** `Timer` (Dart's timer) or `Stream.periodic`
/// (recurring). [MemoryScheduler] is a one-shot replace-or-fire scheduler
/// for the memory write path.
/// **Guide:** see the memory HowTo for "testing debounced writes".
/// **Example:** `test/scheduler_test.dart`.
/// **Cross-layer:** none — scheduler choice is a memory-internal seam.
/// **Minimal compilable example**
/// ```dart
/// final s = ManualScheduler();
/// var fired = 0;
/// s.schedule(const Duration(milliseconds: 300), () => fired++);
/// print(s.isPending);   // true
/// s.elapse();
/// print(fired);         // 1
/// print(s.isPending);   // false
/// ```
abstract interface class MemoryScheduler {
  /// Schedules [run] after [delay], replacing any pending schedule.
  ///
  /// If a schedule is already pending, it is discarded without firing. If
  /// no schedule is pending, [run] is scheduled fresh. Either way, [run]
  /// fires at most once, after [delay] has elapsed.
  ///
  /// ### Parameters:
  /// * [delay]: How long to wait before invoking [run].
  /// * [run]: The callback. Runs once, after [delay]. Its return value is
  ///   ignored.
  void schedule(Duration delay, void Function() run);

  /// Cancels the pending schedule, if any.
  ///
  /// After this call, [ManualScheduler.isPending] reads `false` and any
  /// pending callback will not fire. A no-op if nothing is pending. Does
  /// not affect a callback that is already running.
  void cancel();
}

/// A scheduler backed by a real [Timer].
///
/// The production implementation. Use this outside tests. A debounced
/// [MemoryCell] in a real app receives this scheduler by default; tests
/// pass [ManualScheduler] instead so they do not wait on real time.
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
///
/// ### When to use
/// Use [ManualScheduler] in tests that exercise the debounced
/// [MemoryWritePolicy]. Pass it to `MemoryCell.open` (or `remember`) in
/// place of the production [TimerScheduler]; no test should wait out a
/// real 300 ms debounce window.
///
/// ### How it works
/// 1. **[schedule]** records the callback and [lastDelay]. Nothing fires.
/// 2. **[elapse]** adds [dt] to [elapsed] and, if a callback is pending,
///    fires it once and clears it. A second [elapse] with no intervening
///    [schedule] is a no-op.
/// 3. **[cancel]** clears the pending callback without firing it.
///
/// ### Non-obvious
/// - **No real time passes.** [elapse] is instantaneous; it does not
///   sleep. [elapsed] and [lastDelay] are bookkeeping, not wall-clock
///   time.
/// - **Schedule replaces.** A second [schedule] before an [elapse]
///   discards the first callback, matching [MemoryScheduler]'s contract.
/// - **A fired callback is cleared.** After [elapse] runs the pending
///   callback, [isPending] reads `false`; a second [elapse] runs nothing
///   until a new [schedule] is called.
///
/// ### See also
/// - [TimerScheduler] — the production implementation.
/// - [MemoryScheduler] — the interface both implement.
/// - [MemoryWritePolicy] — the policy that decides when a memory cell
///   calls [schedule].
final class ManualScheduler implements MemoryScheduler {
  void Function()? _run;

  /// Whether a callback is currently pending.
  ///
  /// `true` between a [schedule] call and the next [elapse], [cancel], or
  /// second [schedule] call. `false` after a fired callback.
  bool get isPending => _run != null;

  /// The delay of the most recent [schedule].
  ///
  /// `null` until [schedule] is called. Lets a test assert the debounce
  /// window a policy configured, without reading the policy back.
  Duration? lastDelay;

  /// The total elapse time across [elapse] calls.
  ///
  /// Starts at [Duration.zero] and accumulates every [dt] passed to
  /// [elapse]. This is bookkeeping, not wall-clock time — nothing sleeps.
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
  ///
  /// Adds [dt] to [elapsed], then runs the pending callback exactly once
  /// and clears it. A no-op if nothing is pending. Does not fire the
  /// callback twice for a single [schedule] call.
  ///
  /// ### Parameters:
  /// * [dt]: How much fake time has passed. Defaults to [Duration.zero];
  ///   the callback fires regardless of [dt]'s value, but [elapsed]
  ///   accumulates it so tests can assert cumulative time.
  void elapse([Duration dt = Duration.zero]) {
    elapsed += dt;
    final run = _run;
    _run = null;
    if (run != null) run();
  }
}