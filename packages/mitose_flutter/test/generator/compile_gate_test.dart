// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// Compile-and-test gate for the generated apps.
///
/// This test shells out to `flutter pub get` / `flutter analyze` /
/// `flutter test` for each reference app, so it is skipped by default.
/// Enable it explicitly:
///
/// ```bash
/// PIPELINE_COMPILE=1 dart test test/generator/compile_gate_test.dart
/// ```
///
/// CI (Phase F) runs it with the flag set.
library;

import 'dart:io';

import 'package:mitose_flutter/mitose_flutter.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['PIPELINE_COMPILE'] == '1';
  // Default to the monorepo layout: pipeline sits next to cell_flutter
  // and cell inside packages/.
  final cellFlutterPath = Platform.environment['CELL_FLUTTER_PATH'] ??
      Directory.current.parent.path.replaceAll('\\', '/');
  final cellPath = Platform.environment['CELL_PATH'] ??
      '${Directory.current.parent.parent.path.replaceAll('\\', '/')}/cell';

  group('generated apps compile and pass their tests', () {
    for (final stem in ['form_heavy', 'list_heavy', 'async_heavy']) {
      test(stem, () async {
        final app = generateApp(
            parseBrd(File('example/brds/$stem.bfd.md').readAsStringSync()));
        final tests = generateTests(
            parseBrd(File('example/brds/$stem.bfd.md').readAsStringSync()),
            generateWalkthrough(parseBrd(
                File('example/brds/$stem.bfd.md').readAsStringSync())));
        final combined = GeneratedApp(
          brdTitle: app.brdTitle,
          files: [...app.files, tests],
        );
        final dir = await Directory.systemTemp.createTemp('mitose_app_');
        addTearDown(() => dir.delete(recursive: true));
        await writeApp(combined, dir);
        await File('${dir.path}/pubspec_overrides.yaml').writeAsString('''
dependency_overrides:
  cell_flutter:
    path: $cellFlutterPath
  cell:
    path: $cellPath
''');

        if (!enabled) {
          markTestSkipped('set PIPELINE_COMPILE=1 to run the flutter gate');
          return;
        }

        for (final args in [
          ['pub', 'get'],
          ['analyze'],
          ['test'],
        ]) {
          final result = await Process.run(
            Platform.isWindows ? 'flutter.bat' : 'flutter',
            args,
            workingDirectory: dir.path,
            runInShell: true,
            environment: {
              ...Platform.environment,
              'FLUTTER_SUPPRESS_ANALYTICS': 'true',
            },
          );
          expect(
            result.exitCode,
            0,
            reason: 'flutter ${args.join(' ')} failed for $stem:\n'
                '${result.stdout}\n${result.stderr}',
          );
        }
      }, timeout: const Timeout(Duration(minutes: 8)));
    }
  });
}
