// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Coverage floor: line hits for `lib/src` only — `lib/doc/` is
// generated documentation and is out. Exit 1 under 90 percent.
//
// Run from the package root after `dart test --coverage coverage`.
library;

import 'dart:io';

const String floorPercent = '90';

Future<void> main() async {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    // The VM on this platform emits per-test .vm.json files instead of
    // lcov; convert them through the coverage package.
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--in=coverage',
      '--out=coverage/lcov.info',
      '--packages=.dart_tool/package_config.json',
      '--report-on=lib/src',
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('coverage/lcov.info missing and '
          'coverage:format_coverage failed:\n${result.stderr}');
      exitCode = 1;
      return;
    }
  }
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info missing — '
        'run `dart test --coverage coverage` first');
    exitCode = 1;
    return;
  }

  var hit = 0;
  var found = 0;
  var countedFiles = 0;
  String? currentFile;
  final lines = lcov.readAsLinesSync();
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).replaceAll('\\', '/');
    } else if (line.startsWith('LF:')) {
      final path = currentFile ?? '';
      final inScope = path.contains('/lib/src/') && !path.contains('/lib/doc/');
      if (!inScope) continue;
      found += int.parse(line.substring(3));
      countedFiles++;
    } else if (line.startsWith('LH:')) {
      final path = currentFile ?? '';
      final inScope = path.contains('/lib/src/') && !path.contains('/lib/doc/');
      if (!inScope) continue;
      hit += int.parse(line.substring(3));
    }
  }

  if (found == 0) {
    stderr.writeln('No lib/src lines in the coverage report');
    exitCode = 1;
    return;
  }

  final percent = hit * 100.0 / found;
  stdout.writeln('lib/src coverage: $hit/$found lines '
      '(${percent.toStringAsFixed(2)}%) across $countedFiles files');
  if (percent < 90.0) {
    stderr.writeln('Coverage is below the 90% floor');
    exitCode = 1;
  }
}
