// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.

import 'package:cell/cell.dart';

/// Minimal, runnable quick start for `cell`.
///
/// Shows the core reactive cycle in a few lines:
/// 1. a state cell with an explicit update path,
/// 2. an observer reacting to every accepted change, and
/// 3. an async, lock-serialized write.
Future<void> main() async {
  // 1. State cell: the evolve function is the only update path.
  final counter = Cell.state<int>(
    initial: 0,
    evolve: (host, input) {
      final delta = input.payload as int? ?? 1;
      return Pulse((host.value ?? 0) + delta);
    },
  );

  // 2. Observe: side effects react to accepted pulses.
  final observer = Cell.observe<Pulse<int>>(
    source: counter.cell,
    effect: (pulse) => print('Counter: ${pulse.payload}'),
  );

  // 3. Write through the state handle (async, lock-serialized).
  await counter.updateAsync(5); // prints: Counter: 5
  observer.stop();
}
