// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The demo's REST transport facade.
///
/// The real [RestAdapter] lives in `package:cell_skin/cell_skin_rest.dart`
/// and imports `dart:io`. The demo runs on the web too, so it binds the
/// adapter through a conditional import: `dart:io` platforms get the
/// live adapter; the web gets `null` (and the status strip says so).
library;

import 'package:cell_skin/cell_skin.dart';

import 'rest_stub.dart' if (dart.library.io) 'rest_io.dart' as impl;

/// The minimal surface the demo needs from the REST adapter.
abstract interface class DemoRest {
  /// The bound port.
  int get port;

  /// Stops the server.
  Future<void> close();
}

/// Binds the REST adapter when the platform supports it; `null` on the
/// web.
Future<DemoRest?> bindDemoRest({required SkinMembrane membrane}) =>
    impl.bindDemoRest(membrane: membrane);
