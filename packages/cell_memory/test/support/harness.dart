// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';

/// A fixed, well-formed generation shared by the test envelopes. One life:
/// [seed] writes revisions 1..n with this same generation, never one per
/// revision.
const String testGeneration = '0123456789abcdef0123456789abcdef';

/// Delivers [value] into [cell] through the framework's receptor path — the
/// same path `Cell.transaction` commit uses for non-ValueCell participants
/// (recorded in the README "Verified against" block).
Future<void> deliverValue<T>(MemoryCell<T> cell, T? value) async {
  final tx = Cell.transaction();
  await tx.begin([cell]);
  tx.update(cell, value);
  await tx.commit();
}

/// Seeds [store] with [revision] envelopes for [id], the last one carrying
/// [payload], by writing revisions 1..revision sequentially. The store's
/// compare-and-swap only accepts `expected + 1`.
Future<void> seed(
  MemoryStore store,
  String id, {
  required int revision,
  required Object? payload,
}) async {
  for (var r = 1; r <= revision; r++) {
    await store.write(
      MemoryEnvelope(
        id: id,
        revision: r,
        generation: testGeneration,
        payload: r == revision ? payload : 0,
      ),
      expectedRevision: r - 1,
    );
  }
}

/// A downstream listener that records every pulse it observes.
class PulseRecorder extends CellBase {
  /// Creates a recorder.
  PulseRecorder() : super(receptor: Receptor((cell, pulse, {user}) {
    (cell as PulseRecorder).pulses.add(pulse);
    return null;
  }));

  /// Pulses observed, in order.
  final pulses = <Pulse>[];

  /// Memory pulses observed, in order.
  List<MemoryPulse<T>> memory<T>() =>
      pulses.whereType<MemoryPulse<T>>().toList();
}

/// Links [recorder] downstream of [cell] through the cell's public
/// synapses object.
Future<void> linkRecorder(MemoryCell<Object?> cell, PulseRecorder recorder) async {
  final linked =
      await cell.synapses.link(cell, downstreamCell: recorder);
  assert(linked, 'link returned false');
}
