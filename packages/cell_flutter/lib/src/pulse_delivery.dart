// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';

/// Reports whether Flutter is currently in a phase where `setState` must not
/// be called — build, or the microtasks and persistent callbacks Flutter
/// flushes between frames.
///
/// [isCellBuildPhase] is the **Frame Guard** for every widget binding in
/// `cell_flutter`. A pulse that arrives while Flutter is building or running
/// persistent callbacks cannot safely `setState` immediately: doing so throws
/// Flutter's *"setState() or markNeedsBuild() called during build"* framework
/// error. Every builder and listener in this package consults this getter
/// (directly or via [runAfterBuild]) before touching widget state.
///
/// ### When it is used
/// - **`CellBuilder` / `CellSelector`**: `CellNotifier` deliberately calls
///   its base setter synchronously, so a build-time pulse surfaces as a
///   framework error rather than a silent drop. This getter is *not* on
///   that path.
/// - **`CellValueBuilder` / `CellAsyncBuilder`**: pulses arriving in a build
///   phase are queued and flushed in a single post-frame callback.
/// - **`CellListener`**: pulses in a build phase are queued and delivered
///   in order after the frame, so `onPulse` can safely `Navigator.push` or
///   `showSnackBar`.
///
/// ### How it works
/// It reads [SchedulerBinding.schedulerPhase] and returns `true` when the
/// phase is either:
/// 1. [SchedulerPhase.persistentCallbacks] — the build/layout/paint pipeline.
/// 2. [SchedulerPhase.midFrameMicrotasks] — the microtasks Flutter drains
///    between persistent callbacks, still mid-frame.
///
/// Idle, transient-callback (gesture/pointer), and post-frame-callback phases
/// report `false` — a `setState` in any of those is safe.
///
/// ### Technical Details
/// - **Pure read**: reads Flutter's scheduler phase; no side effects.
/// - **Cheap**: a single enum comparison chain; safe to call per pulse.
///
/// See also:
/// - [runAfterBuild] — the scheduling counterpart that defers when needed.
/// - `SchedulerPhase` — the Flutter phases this getter inspects.
bool get isCellBuildPhase {
  final phase = SchedulerBinding.instance.schedulerPhase;
  return phase == SchedulerPhase.midFrameMicrotasks ||
      phase == SchedulerPhase.persistentCallbacks;
}

/// Runs [action] immediately, or defers it to the end of the current frame if
/// the scheduler is mid-build.
///
/// [runAfterBuild] is the **Safe-Mutation Trampoline** used by the stateful
/// widgets in `cell_flutter`. It answers one question per call: *can I touch
/// widget state right now, or must I wait?* If the current scheduler phase is
/// safe (see [isCellBuildPhase]), [action] runs inline — no frame of latency
/// is added. If Flutter is mid-build, [action] is scheduled through
/// [SchedulerBinding.addPostFrameCallback] and runs once the frame ends.
///
/// ### Why it is used
/// - **Widget-local deferral**: `CellSelector` uses it so `select` runs
///   outside the build phase and can safely `setState` when the slice changes.
///   `CellValueBuilder` and `CellAsyncBuilder` use the same pattern inline for
///   their pulse queues.
/// - **No added latency in the common case**: gestures, timers, and
///   microtasks are not in a build phase, so [action] fires synchronously and
///   the UI responds within the same event loop turn.
/// - **One deferral is enough**: a single post-frame callback closes over the
///   current [action]; callers that arrive during the same frame are expected
///   to coalesce themselves before calling (the builders keep a pending list
///   and flush only the latest or the whole queue, as appropriate).
///
/// ### How it works
/// 1. If [isCellBuildPhase] is `false`, [action] is invoked inline.
/// 2. Otherwise, [action] is registered with [SchedulerBinding] and will run
///    after the current frame's persistent callbacks complete.
///
/// ### Technical Details
/// - **No coalescing here**: each call schedules its own post-frame callback.
///   Coalescing (batching multiple pulses into one `setState`) is the caller's
///   responsibility — the widgets in this package do it with a `_flushScheduled`
///   flag and a pending list.
/// - **No lifecycle guard**: this helper does not know about widget disposal.
///   Callers must check `mounted` / `_disposed` inside [action] after any
///   deferral — every current caller does.
///
/// See also:
/// - [isCellBuildPhase] — the underlying phase check.
/// - `SchedulerBinding.addPostFrameCallback` — the Flutter primitive used for
///   deferral.
void runAfterBuild(void Function() action) {
  if (!isCellBuildPhase) {
    action();
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => action());
}

/// Returns the last pulse [cell] emitted, when the core package retained one
/// for late subscribers, or `null` when no pulse is synchronously visible.
///
/// [retainedPulseOf] is the **Late-Subscriber Probe** used by the widgets in
/// `cell_flutter` to seed their first frame before the next pulse arrives.
/// The problem it solves: a cell whose value was already emitted will not
/// emit again just because a widget subscribed a moment later. Without a
/// seed, the widget would sit on its `initial` / `nothing()` state until the
/// next external emission — possibly forever.
///
/// ### How it works
/// 1. It asks the core package for the retained pulse via
///    [Cell.latestPulse]. This covers every state-like operator —
///    `Cell.fromFuture`, `Cell.fromStream`, `Cell.asyncMap`, and
///    `Cell.derive` — because each retains the pulse it emits.
///    [Cell.ingress] cells are deliberately not covered: replaying an
///    already-handled event (e.g. a click) is not state.
/// 2. If no pulse is retained, and [cell] is a [ValueCell], its current
///    [ValueCell.value] is wrapped in a [Pulse] and returned. This is the
///    synchronous path for `Cell.state` results, `CellNotifier` sources,
///    and custom [ValueCell] subclasses that do not register with the core
///    retention map.
/// 3. Otherwise this returns `null` and the caller falls back to its
///    configured `initial` / `nothing()` — the cell has simply never
///    emitted a value this binding can see.
///
/// ### Which cells are served here
/// - `Cell.fromFuture` — retained on both the value and the `'error'` path.
/// - `Cell.fromStream` — retained per stream value (stream errors are never
///   emitted as pulses by the core package; see
///   `test/error_pulse_sources_test.dart`).
/// - `Cell.asyncMap` — retained per mapped result (mapper failures are never
///   emitted on the output cell).
/// - `Cell.derive` — retained per non-null projection.
/// - [ValueCell] — served through the `value` fallback.
///
/// ### Technical Details
/// - **Return type is `Pulse<Object?>`**: the payload type is erased; widgets
///   re-narrow via a runtime `is V` check when they apply the seed.
/// - **Non-mutating**: does not subscribe, does not touch the egress registry.
///
/// See also:
/// - [Cell.latestPulse] — the core-package accessor this probe delegates to.
/// - `test/seed_paths_test.dart` — the 12-test matrix locking in the seed
///   behavior for all four source types and all four consumers.
/// - [seedFromRetained] — applies this probe with the widget `initial`
///   fallback in one call.
/// - [CellValueBuilder] — seeds via this probe, falls back to `initial`.
/// - [CellAsyncBuilder] — seeds via `snapshotForCell`, which uses this probe.
/// - [CellAsValue] — seeds its mirror via this probe.
Pulse<Object?>? retainedPulseOf(Cell cell) {
  // Ask the core package for the retained pulse first. This covers every
  // state-like operator: fromFuture, fromStream, asyncMap, derive, and
  // (via the fallback below) ValueCell.
  final latest = Cell.latestPulse(cell);
  if (latest != null) return latest;
  // Defensive fallback: some cell implementations (custom subclasses of
  // ValueCell outside the standard factories) may not register with the
  // core retention map. Fall back to reading .value directly.
  if (cell is ValueCell<dynamic>) return Pulse<Object?>(cell.value);
  return null;
}

/// Seeds a widget's first visible value from [cell]'s retained pulse, falling
/// back to [initial].
///
/// **Seed priority**, highest first:
/// 1. The retained pulse from [retainedPulseOf], if it is a data pulse and
///    its payload is assignable to `V` (or is `null` when `null is V`).
/// 2. The caller's [initial].
///
/// An error pulse in the retained slot, a payload type mismatch, or a `null`
/// return from [retainedPulseOf] (the cell never emitted a value this binding
/// can see) falls through to [initial].
///
/// ### Technical Details
/// - **Stateless helper**: no mutation; safe to call from `initState` and
///   `didUpdateWidget`.
/// - **Type-erasure aware**: uses `is V` / `null is V` so a nullable `V` and
///   a non-nullable `V` are both handled correctly.
///
/// See also:
/// - [retainedPulseOf] — the retained-value probe used here.
V? seedFromRetained<V>(Cell cell, V? initial) {
  final latest = retainedPulseOf(cell);
  if (latest == null || latest.type == 'error') {
    return initial;
  }
  final payload = latest.payload;
  if (payload is V) {
    return payload;
  }
  // coverage:ignore-start
  // Executed by test/pulse_delivery_test.dart ('accepts a null retained
  // payload for a nullable V'), but the VM does not attribute this
  // type-variable test line in coverage reports.
  if (payload == null && null is V) {
    return null;
  }
  // coverage:ignore-end
  return initial;
}

/// Reports whether [value] is a collection whose default equality is
/// identity-based.
///
/// [isCollectionLike] is the shared check behind the debug-mode assertions
/// in `CellSelector` and `useCell`: a `List`, `Set`, or `Map` selection
/// compared with the default `==` rebuilds on every emission, because two
/// distinct collection instances are never `==`. Callers must supply
/// `listEquals` / `setEquals` / `mapEquals` instead.
///
/// `String` is **not** a collection here — Dart's `String` does not
/// implement `Iterable` or `Map`.
///
/// See also:
/// - `CellSelector` — asserts on this in `initState`.
/// - `useCell` — asserts on this for the initial and recomputed selection.
bool isCollectionLike(Object? value) => value is Map || value is Iterable;
