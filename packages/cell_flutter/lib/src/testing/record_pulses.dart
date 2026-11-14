// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';

/// Records every pulse emitted by [cell].
///
/// The egress is bound to the recorder. Call `stop()` (or register
/// `addTearDown(recorder.stop)`) to release it.
///
/// ## Usage
///
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
/// ## Works on any `Cell`
///
/// `recordPulses` is available on any `Cell`, including derived cells
/// (`Cell.derive`, `Cell.synthesis`, `Cell.asyncMap`) and tissue
/// collections. This is the most reliable way to assert pulse sequences
/// from derived cells.
///
/// ## Error pulses
///
/// Every pulse is recorded regardless of type. Error pulses (only emitted
/// today by `Cell.fromFuture`) appear in [PulseRecorder.pulses] with
/// `type == 'error'` and a payload of `Object`, not `V`. Use
/// [PulseRecorder.payloads] to assert on the full sequence including
/// errors, or inspect [PulseRecorder.pulses] directly when you need the
/// type.
///
/// `fromStream` and `asyncMap` do **not** emit error pulses today; a
/// recorder over those sources will not see failures. See
/// `CellAsyncBuilder`'s dartdoc for the per-source behavior table.
extension CellRecordPulses<T extends Cell> on T {
  PulseRecorder<T> recordPulses() => PulseRecorder<T>._(this);
}

/// Records the pulses emitted by a [Cell].
///
/// Holds an [EgressHandle] internally. Call [stop] to release it; the
/// recorder can be reused (call [clear] to reset the recorded list
/// without releasing the egress).
///
/// ## Cleanup
///
/// Always release the recorder — either `addTearDown(recorder.stop)` for
/// standalone use, or let [CellTestHarness] manage it (the harness stops
/// recorders on `dispose`). A recorder left running holds a strong
/// reference to the source cell until the isolate ends.
class PulseRecorder<T extends Cell> {
  PulseRecorder._(this.cell) {
    _egress = Cell.observe<Pulse<Object?>>(
      source: cell,
      effect: _pulses.add,
      initiallyStarted: true,
    );
  }

  /// The source cell.
  final T cell;

  final List<Pulse<Object?>> _pulses = [];
  late final EgressHandle<Pulse<Object?>> _egress;
  bool _stopped = false;

  /// All pulses recorded so far, in order.
  List<Pulse<Object?>> get pulses => List.unmodifiable(_pulses);

  /// The payloads of all recorded pulses, in order.
  ///
  /// Error pulses appear here with their `Object` payload, not a `V`.
  List<Object?> get payloads => [for (final p in _pulses) p.payload];

  /// Clears the recorded list without stopping the recorder.
  void clear() => _pulses.clear();

  /// Stops recording and releases the egress.
  ///
  /// Idempotent. After [stop], [pulses] returns the last recorded list.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _egress.stop();
  }
}
