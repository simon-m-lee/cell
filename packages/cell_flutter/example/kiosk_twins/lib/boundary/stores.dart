// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell_memory/cell_memory.dart';
import 'package:cell_memory/cell_memory_io.dart';
import 'package:flutter/foundation.dart';

import 'firebase.dart';

/// The demo's store selector.
///
/// - Desktop default: `FileMemoryStore` under `kiosk_state/` in the
///   process working directory — the restart drill depends on that
///   stability.
/// - `--dart-define=STORE=firebase`: the network boundary —
///   `FirebaseMemoryStore` on the emulator, shared uid across kiosks.
/// - Web without Firebase: no `dart:io` file system, so the boundary
///   degrades to an in-memory store (the UI and domain still run;
///   persistence does not).
Future<MemoryStore> selectStore({Directory? stateDir}) async {
  const mode = String.fromEnvironment('STORE', defaultValue: 'file');
  if (mode == 'firebase') return selectFirebaseStore();
  if (kIsWeb) return InMemoryMemoryStore();
  switch (mode) {
    case 'file':
      return FileMemoryStore.directory(
          stateDir ?? Directory('kiosk_state'));
    default:
      throw ArgumentError.value(mode, 'STORE',
          'unknown store mode; expected "file" or "firebase"');
  }
}
