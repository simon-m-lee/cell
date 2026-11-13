// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

import 'package:cell/replay/cli/cli.dart' show Cli;

Future<void> main(List<String> args) async {
  final exitCode = await Cli.run(args);
  exit(exitCode);
}
