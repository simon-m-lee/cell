// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';

import 'codec.dart';
import 'memory_cell.dart';
import 'policy.dart';
import 'scheduler.dart';
import 'store.dart';

/// Opens a memory cell for [domain], loads it, and attaches it.
///
/// Sugar for `MemoryCell.open` + [MemoryCell.attach]. [project] pulls the
/// value to store out of the domain pulse. For a `Cell.state<T>` the
/// projection is typically `(pulse) => pulse.payload as T? ?? initial`;
/// for other shapes the caller supplies the mapping. A failed projection
/// throws [MemoryCorrupt] inside the cell and does not write.
///
/// The returned cell retains the domain's accepted pulses through the
/// framework's public observer binding (see the README "Verified against"
/// block for why at cell 2.1.0 a `Cell.state` cannot be linked from
/// directly).
///
/// [seed] is the supported way to push a loaded value into the domain
/// cell: it is called with `memory.value` after [MemoryCell.open] returns
/// and **before** [MemoryCell.attach] installs the observer, so a domain
/// update inside it is not echoed back into the memory cell. Skipping
/// [seed] leaves the domain at its own initial value; the next domain
/// pulse then overwrites memory. If [seed] or [MemoryCell.attach] throws, the opened
/// cell is closed (releasing an owned store) before the error propagates,
/// so a failed remember leaks nothing.
Future<MemoryCell<T>> remember<T>(
  Cell domain, {
  required String id,
  required MemoryStore store,
  required MemoryCodec<T> codec,
  required T? Function(Pulse pulse) project,
  T? initial,
  Context context = Context.system,
  MemoryWritePolicy policy = const MemoryWritePolicy(),
  bool loadOnOpen = true,
  MemoryScheduler? scheduler,
  bool ownsStore = false,
  void Function(T? loaded)? seed,
}) async {
  final memory = await MemoryCell.open<T>(
    id: id,
    store: store,
    codec: codec,
    initial: initial,
    context: context,
    policy: policy,
    loadOnOpen: loadOnOpen,
    scheduler: scheduler,
    ownsStore: ownsStore,
  );
  try {
    if (seed != null) seed(memory.value);
    await memory.attach(domain, project: project);
  } catch (_) {
    await memory.close();
    rethrow;
  }
  return memory;
}
