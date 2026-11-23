// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The web stub: no REST transport on platforms without `dart:io`.
library;

import 'package:cell_skin/cell_skin.dart';

import 'rest_binding.dart';

/// Returns `null` — the web has no `dart:io` HTTP server.
Future<DemoRest?> bindDemoRest({required SkinMembrane membrane}) async => null;
