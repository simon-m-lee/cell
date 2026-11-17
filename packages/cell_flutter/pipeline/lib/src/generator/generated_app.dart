// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The generated app: a file tree as strings.
library;

import '../brd/ast.dart';

/// A generated app — the complete file tree, in memory.
class GeneratedApp {
  const GeneratedApp({
    required this.brdTitle,
    required this.files,
    this.schemaVersion = 'flutter-pipeline/v1',
  });

  final String brdTitle;
  final List<GeneratedFile> files;
  final String schemaVersion;

  GeneratedFile? file(String path) =>
      files.where((f) => f.path == path).firstOrNull;

  /// A stable byte representation for `verify` comparisons.
  String stableHash() {
    final sorted = [...files]..sort((a, b) => a.path.compareTo(b.path));
    return sorted.map((f) => '=== ${f.path} ===\n${f.content}').join('\n');
  }
}

/// One generated file.
class GeneratedFile {
  const GeneratedFile({required this.path, required this.content});

  final String path;
  final String content;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Sanitizes a title into a Dart package name.
String packageName(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

/// `home_screen` from `Home`.
String screenFileName(String screenName) =>
    '${screenName.toLowerCase()}_screen.dart';

/// `HomeScreen` from `Home`.
String screenClassName(String screenName) => '${screenName}Screen';

String cellFileName(String cellName) =>
    '${cellName.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')}.dart';

/// Which screen owns (declares) a non-app-level cell.
Map<String, List<BrdState>> cellsByScreen(
  Brd brd,
  List<String> Function(String screen) boundNamesByScreen,
) {
  final result = <String, List<BrdState>>{};
  for (final screen in brd.screens) {
    final bound = boundNamesByScreen(screen.name);
    result[screen.name] = [
      for (final state in brd.state)
        if (!state.appLevel && bound.contains(state.name)) state,
    ];
  }
  return result;
}
