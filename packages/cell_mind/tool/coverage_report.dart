// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:io';

/// Parses a Dart `lcov.info` file and gates `lib/` line coverage.
///
/// The Dart VM coverage format reports line and function coverage;
/// branch percentages are not emitted by the toolchain, so the gate
/// applies the plan's threshold to lines and documents that fact.
///
/// Usage:
/// ```bash
/// dart run tool/coverage_report.dart coverage/lcov.info
/// ```
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/coverage_report.dart <lcov>');
    exitCode = 64;
    return;
  }
  final lines = File(args.first).readAsLinesSync();
  var hits = 0;
  var found = 0;
  String? current;
  var inLib = false;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      inLib = current.contains('lib/') ||
          current.replaceAll('\\', '/').contains('lib/');
      continue;
    }
    if (line == 'end_of_record') {
      current = null;
      inLib = false;
      continue;
    }
    if (!inLib) continue;
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      found++;
      if (parts.length > 1 && int.tryParse(parts[1]) != 0) hits++;
    }
  }
  final pct = found == 0 ? 100.0 : hits * 100 / found;
  stdout.writeln('lib/ line coverage: $hits/$found '
      '(${pct.toStringAsFixed(1)}%)');
  const threshold = 88.0;
  if (pct < threshold) {
    stderr.writeln('Coverage below the $threshold% gate.');
    exitCode = 1;
  }
}
