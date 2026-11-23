// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The `dart:io` implementation: binds the real REST adapter.
library;

import 'package:cell_skin/cell_skin.dart';
import 'package:cell_skin/cell_skin_rest.dart';

import 'rest_binding.dart';

final class _DemoRestAdapter implements DemoRest {
  final RestAdapter adapter;

  _DemoRestAdapter(this.adapter);

  @override
  int get port => adapter.port;

  @override
  Future<void> close() => adapter.close();
}

Future<DemoRest?> bindDemoRest({required SkinMembrane membrane}) async {
  final adapter = await RestAdapter.bind(
    membrane: membrane,
    auth: const AllowAllSkinAuth(), // The demo is a local, explicit opt-in.
  );
  return _DemoRestAdapter(adapter);
}
