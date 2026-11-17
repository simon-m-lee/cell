// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';

/// An extension that records every pulse emitted by a [Cell], for assertion
/// in tests.
///
/// [CellRecordPulses] is the binding's **Pulse Journal Entry Point** — the
/// minimal way to capture the ordered sequence of pulses a cell produces
/// without constructing a widget or hand-rolling a `Cell.observe` call.
/// Where `CellBuilder` collapses history into a current value and
/// `CellListener` routes pulses into side effects, this extension preserves
/// the full sequence, so tests can assert on order, payloads, and error
/// types.
///
/// ### Why it is used
/// - **Pulse-level assertions**: some behaviors are only observable at the
///   pulse level — the *order* of emissions, the number of emissions, or
///   the distinction between a data pulse and an error pulse. A value-based
///   widget (`CellBuilder`) or a side-effect widget (`CellListener`) does
///   not expose that.
/// - **Any `Cell`, including derived ones**: `Cell.state` returns a
///   [ValueCell] with a synchronous `.value`; a `Cell.derive`,
///   `Cell.synthesis`, or `Cell.asyncMap` is a plain `Cell` without one.
///   [recordPulses] works uniformly on all of them, which makes it the
///   most reliable way to test derived-cell behavior.
/// - **Tissue collections**: `cell_tissue` collections are `Cell`
///   subtypes; the same recorder works on them, giving test code a single
///   uniform observation idiom across the reactive types.
///
/// ### How it works
/// 1. [recordPulses] constructs a [PulseRecorder], which opens exactly
///    one `Cell.observe` link on the source cell.
/// 2. The egress effect appends every received pulse — data, error, or
///    otherwise — to the recorder's in-order list.
/// 3. The recorder exposes two read views: [PulseRecorder.pulses] (the
///    raw pulse list) and [PulseRecorder.payloads] (the payload-only
///    list).
/// 4. [PulseRecorder.stop] releases the egress; [PulseRecorder.clear]
///    resets the recorded list without releasing it.
///
/// ### Error pulses (please read)
/// Every pulse is recorded regardless of type — the recorder does **not**
/// filter errors. Today in the core package, **`Cell.fromFuture` is the
/// only operator that emits `type == 'error'` pulses**; `Cell.fromStream`
/// and `Cell.asyncMap` do **not** emit error pulses at present. A recorder
/// over those sources will therefore not observe failures through
/// [PulseRecorder.pulses] or [PulseRecorder.payloads]. The per-source
/// behavior is asserted in `test/error_pulse_sources_test.dart`, which is
/// the authoritative statement every other doc in this package references.
///
/// When an error pulse *is* emitted, its `payload` is the underlying
/// error object (`Object`), not a `V`. Use [PulseRecorder.pulses] when
/// the test needs to distinguish `type == 'error'`; use
/// [PulseRecorder.payloads] when the test only cares about the payload
/// sequence and errors are not expected.
///
/// ### Cleanup (read this)
/// **Always release the recorder.** A [PulseRecorder] holds a strong
/// reference to the source cell until [PulseRecorder.stop] is called, so
/// a recorder left running pins its source for the lifetime of the
/// isolate. Two safe patterns:
/// - `addTearDown(recorder.stop)` for standalone use.
/// - Let [CellTestHarness] manage it — the harness calls `stop` on
///   `dispose`.
///
/// ### Technical Details
/// - **Generic over [Cell] subtype**: `T extends Cell` preserves the
///   source's static type for callers who want it
///   (`PulseRecorder<ValueCell<int>>`).
/// - **One egress per recorder**: each call to [recordPulses] opens a new
///   observation link. Two recorders on the same source are two egresses.
/// - **Ordered, unfiltered**: pulses are appended in emission order; the
///   list is not coalesced, sorted, or deduplicated.
///
/// ### Example
/// ```dart
/// testWidgets('emits on each update', (tester) async {
///   final counter = Cell.state<int>(initial: 0);
///   final recorder = counter.cell.recordPulses();
///   addTearDown(recorder.stop);
///
///   counter.update(1);
///   counter.update(2);
///   counter.update(3);
///
///   expect(recorder.payloads, [1, 2, 3]);
/// });
/// ```
///
/// ### See Also:
/// - [PulseRecorder] — the recorder this extension constructs.
/// - [CellTestHarness] — a higher-level test harness that manages recorder
///   lifetime automatically.
/// - `Cell.observe` — the underlying observation primitive.
/// - `CellAsyncBuilder` — for rendering error pulses in a widget context.
/// - `test/error_pulse_sources_test.dart` — the authoritative statement of
///   which sources emit error pulses.
extension CellRecordPulses<T extends Cell> on T {
  /// Records every pulse emitted by this cell.
  ///
  /// Returns a [PulseRecorder] whose [PulseRecorder.pulses] and
  /// [PulseRecorder.payloads] getters expose the recorded sequence. Call
  /// [PulseRecorder.stop] (or `addTearDown(recorder.stop)`) to release
  /// the egress; the recorder pins the source cell until stopped.
  ///
  /// ### Returns:
  /// A [PulseRecorder] over this cell, already subscribed and recording.
  ///
  /// ### See Also:
  /// - [PulseRecorder] — the returned type.
  /// - [CellRecordPulses] — the extension-level docs, including the
  ///   error-pulse behavior and cleanup contract.
  PulseRecorder<T> recordPulses() => PulseRecorder<T>._(this);
}

/// A recorder that captures every pulse emitted by a [Cell], in order.
///
/// [PulseRecorder] is the binding's **Pulse Journal**. It owns exactly one
/// `Cell.observe` link on a source cell and appends every received pulse
/// to an in-order list, so tests can assert on the sequence, payloads, and
/// error types of a cell's emissions without subscribing to the cell
/// themselves.
///
/// ### Why it is used
/// - **Sequence assertions**: the recorded list preserves order, so a test
///   can assert `expect(recorder.payloads, [1, 2, 3])` on a burst of
///   updates that a value-only view would collapse into the final value.
/// - **Error visibility**: [pulses] exposes the raw pulse list, allowing
///   tests to distinguish data from `type == 'error'` emissions — see the
///   extension docs for which core operators currently emit errors.
/// - **Harness-integrated**: [CellTestHarness] wraps one of these
///   internally and manages its lifecycle, so most tests use the harness
///   rather than the recorder directly.
///
/// ### How it works
/// 1. **Construction**: the private constructor (invoked via
///    [CellRecordPulses.recordPulses]) opens one `Cell.observe` link on
///    the source cell; the effect appends every pulse to an internal
///    list.
/// 2. **Reading**: [pulses] returns a snapshot copy of the list; [payloads]
///    derives a payload-only view on demand.
/// 3. **Reset**: [clear] empties the recorded list without releasing the
///    egress — useful for `setUp`-style isolation within a single test.
/// 4. **Release**: [stop] releases the egress. Idempotent.
///
/// ### Cleanup (read this)
/// **Always release the recorder.** It holds a strong reference to the
/// source cell until [stop] is called, so a recorder left running pins
/// its source for the lifetime of the isolate. Two correct patterns:
/// - `addTearDown(recorder.stop)` for standalone use.
/// - Let [CellTestHarness] manage it — the harness calls [stop] on
///   `dispose`.
///
/// ### Pulse semantics
/// - **Data pulses** are recorded with their payload.
/// - **Error pulses** are recorded with `type == 'error'` and the error
///   object as `payload`. Only `Cell.fromFuture` currently emits these in
///   the core package — see the extension docs for the full picture.
/// - **Ordering**: pulses are appended in emission order; the list is
///   neither filtered nor coalesced.
///
/// ### Technical Details
/// - **Snapshot-copy reads**: [pulses] returns `List.unmodifiable(_pulses)`,
///   which is a **copy** of the internal list, not a live view — subsequent
///   recordings do not appear in a previously obtained list, and each
///   access is O(n). Hold the result when iterating over a long recording.
/// - **Reusable**: [clear] resets the recording without dropping the
///   egress, so one recorder can span multiple assertion phases.
/// - **Idempotent [stop]**: repeated calls are no-ops; after the first
///   [stop], [pulses] continues to return the last recorded list.
/// - **Strong reference**: the source cell is pinned for the recorder's
///   lifetime (see *Cleanup*).
///
/// ### See Also:
/// - [CellRecordPulses.recordPulses] — the extension that creates one.
/// - [CellTestHarness] — the higher-level harness that owns recorders.
/// - `EgressHandle` — the primitive that [stop] releases.
/// - `Cell.observe` — the underlying observation primitive.
class PulseRecorder<T extends Cell> {
  PulseRecorder._(this.cell) {
    _egress = Cell.observe<Pulse<Object?>>(
      source: cell,
      effect: _pulses.add,
      initiallyStarted: true,
    );
  }

  /// The source cell.
  ///
  /// Held by strong reference until [stop] is called. Exposed so callers
  /// can inspect the source (e.g. for identity assertions) or stop the
  /// recorder via `recorder.cell` — though [stop] is the intended release
  /// path.
  final T cell;

  final List<Pulse<Object?>> _pulses = [];
  late final EgressHandle<Pulse<Object?>> _egress;
  bool _stopped = false;

  /// All pulses recorded so far, in order.
  ///
  /// The returned list is a **snapshot copy** — callers cannot mutate the
  /// recorder's internal state through this getter, and pulses recorded
  /// after the getter call do not appear in the returned list. Each access
  /// copies the recording (O(n)); hold the result when iterating. The list
  /// includes data pulses, error pulses, and any other pulse type the
  /// source emits.
  ///
  /// ### See Also:
  /// - [payloads] — the payload-only view.
  List<Pulse<Object?>> get pulses => List.unmodifiable(_pulses);

  /// The payloads of all recorded pulses, in order.
  ///
  /// Error pulses appear here with their underlying `Object` payload, not
  /// a `V`. Use this getter when the test only cares about the sequence of
  /// payload values; use [pulses] when the test needs to distinguish
  /// error pulses from data pulses by `type`.
  ///
  /// ### See Also:
  /// - [pulses] — the full pulse view, including `type`.
  List<Object?> get payloads => [for (final p in _pulses) p.payload];

  /// Clears the recorded list without stopping the recorder.
  ///
  /// The egress stays open and the source cell remains observed; subsequent
  /// pulses are appended to the now-empty list. Use this when a test
  /// wants to isolate assertions within a single recorder, or to reset
  /// state after an `initState`-like warm-up.
  ///
  /// ### See Also:
  /// - [stop] — releases the egress entirely.
  void clear() => _pulses.clear();

  /// Stops recording and releases the egress.
  ///
  /// Idempotent. After [stop], [pulses] returns the last recorded list —
  /// empty only if [clear] was the last mutating call before [stop]. The
  /// source cell is unaffected; only this recorder's observation link is
  /// released.
  ///
  /// ### See Also:
  /// - [clear] — reset the list without releasing the egress.
  /// - `EgressHandle.stop` — the primitive used to release the link.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _egress.stop();
  }
}
