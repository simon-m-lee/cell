// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// A counter that survives process restarts through a JSON file.
//
//   dart run example/file_counter.dart
//
// Each run increments the counter by one and persists it to
// `memory/counter.json`. The first run starts at 0 (load miss); every
// later run starts from the stored integer and prints it.

import 'dart:io';

import 'package:cell/cell.dart';
import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';

Future<void> main() async {
  final store = FileMemoryStore.directory(Directory('memory'));

  // The domain starts at 0; remember's seed pushes the loaded value into
  // it before the observer is installed, so the domain is never clobbered
  // by a default.
  final counter = Cell.state<int>(initial: 0);
  final memory = await remember<int>(
    counter.cell,
    id: 'counter',
    store: store,
    codec: JsonMemoryCodec<int>.identity(),
    project: (pulse) => pulse.payload as int? ?? 0,
    seed: (loaded) => counter.update(loaded ?? 0),
    // Immediate, so the example is deterministic without a sleep.
    policy: const MemoryWritePolicy(mode: MemoryWriteMode.immediate),
  );

  final start = memory.value ?? 0;
  final next = start + 1;
  counter.update(next);
  // Wait until the scheduled write lands, then detach and keep the file.
  await memory.save();
  await memory.unload();
  await store.close();

  stdout.writeln('counter restored from $start, now $next');
}
