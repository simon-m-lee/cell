// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The output tree writer.
library;

import 'dart:io';

import '../generator/generated_app.dart';

/// The canonical output tree (`flutter-pipeline/v1`).
final outputTreePatterns = <RegExp>[
  RegExp(r'^lib/main\.dart$'),
  RegExp(r'^lib/screens/[a-z_]+_screen\.dart$'),
  RegExp(r'^lib/cells/[a-zA-Z0-9_]+\.dart$'),
  RegExp(r'^test/app_test\.dart$'),
  RegExp(r'^pubspec\.yaml$'),
  RegExp(r'^analysis_options\.yaml$'),
  RegExp(r'^README\.md$'),
];

/// Writes [app] to [root], replacing the directory if needed.
///
/// Throws [ArgumentError] when a file is outside the canonical tree
/// (`WrongOutputTree` in the rubric's terms).
Future<void> writeApp(GeneratedApp app, Directory root) async {
  for (final file in app.files) {
    final valid =
        outputTreePatterns.any((pattern) => pattern.hasMatch(file.path));
    if (!valid) {
      throw ArgumentError(
        'file "${file.path}" is not part of the expected output tree '
        '`flutter-pipeline/v1`',
      );
    }
  }

  if (await root.exists()) {
    // Overwrite in place; remove stale files not part of the new tree
    // (avoids Windows directory-deletion locks).
    final wanted = app.files.map((f) => f.path).toSet();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative =
          entity.path.substring(root.path.length + 1).replaceAll('\\', '/');
      if (wanted.contains(relative)) continue;
      for (var attempt = 0;; attempt++) {
        try {
          await entity.delete();
          break;
        } catch (_) {
          if (attempt >= 5) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  } else {
    await root.create(recursive: true);
  }
  for (final file in app.files) {
    final target = File('${root.path}/${file.path}');
    await target.parent.create(recursive: true);
    await target.writeAsString('${file.content.trimRight()}\n');
  }
}

/// Loads a generated app from a directory (for `assess`).
///
/// Only files matching the canonical output tree are read; build
/// artifacts (`.dart_tool/`, `build/`) are ignored.
Future<GeneratedApp> loadAppFromDirectory(
  Directory root, {
  required String brdTitle,
}) async {
  final files = <GeneratedFile>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative =
        entity.path.substring(root.path.length + 1).replaceAll('\\', '/');
    if (!outputTreePatterns.any((pattern) => pattern.hasMatch(relative))) {
      continue;
    }
    try {
      files.add(GeneratedFile(
          path: relative, content: await entity.readAsString()));
    } on FileSystemException {
      // Binary artifact; not part of the tree.
    }
  }
  return GeneratedApp(brdTitle: brdTitle, files: files);
}
