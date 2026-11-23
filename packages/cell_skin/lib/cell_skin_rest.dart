// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The REST binding entry point.
///
/// `RestAdapter` imports `dart:io`, so it is exported from this
/// library rather than from the main `cell_skin.dart` barrel — web and
/// Flutter-web consumers of the wire, the membrane, or the in-process
/// client must be able to compile without an `io` dependency.
///
/// ```dart
/// import 'package:cell_skin/cell_skin.dart';
/// import 'package:cell_skin/cell_skin_rest.dart';
///
/// final adapter = await RestAdapter.bind(
///   membrane: membrane,
///   auth: const AllowAllSkinAuth(), // anonymous access is opt-in
/// );
/// ```
/// {@category Features}
library;

export 'src/adapters/rest/rest_adapter.dart';
export 'src/security/skin_auth.dart';
export 'src/security/context_bridge.dart';
