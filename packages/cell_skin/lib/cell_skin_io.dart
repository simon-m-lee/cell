// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The `dart:io` barrel of the skin.
///
/// `package:cell_skin/cell_skin.dart` stays importable from Flutter
/// web; the durable file store lives here instead:
///
/// ```dart
/// import 'package:cell_skin/cell_skin_io.dart';
///
/// final store = await FileIdempotencyStore.open(directory: './skin');
/// ```
/// {@category Features}
library;

export 'src/wire/file_idempotency_store.dart';
