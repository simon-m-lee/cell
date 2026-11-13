// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Replay determinism gate (the serialisation layer scope).
//
// Runs the replay test suite twice and fails when the two runs disagree on
// test outcomes. The machine-readable JSON reporter includes per-test
// timing, so the comparison normalises on (test name, result, message).
//
//   dart run tool/replay_determinism_check.dart
//
// The full `test/` suite is exercised by the same outcome
// comparison; this entry point is the documented gate.

import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final packageRoot = File.fromUri(Platform.script).parent.parent.path;

  final first = await _run(packageRoot);
  final second = await _run(packageRoot);

  stdout.writeln(
      'Replay suite outcomes — run 1: ${first.length}, run 2: ${second.length}');
  // NOTE: `List.==` is identity in Dart, so the lists are compared
  // element-wise (or via their joined serialisation).
  if (first.join('\n') == second.join('\n')) {
    stdout.writeln('Determinism check passed: both runs agree.');
    exit(0);
  }

  final onlyFirst = first.toSet().difference(second.toSet());
  final onlySecond = second.toSet().difference(first.toSet());
  stderr.writeln('Determinism check FAILED.');
  stderr.writeln('Only in run 1 (${onlyFirst.length}):');
  for (final line in onlyFirst) {
    stderr.writeln('  $line');
  }
  stderr.writeln('Only in run 2 (${onlySecond.length}):');
  for (final line in onlySecond) {
    stderr.writeln('  $line');
  }
  exit(1);
}

Future<List<String>> _run(String packageRoot) async {
  final result = await Process.run(
    'dart',
    ['test', 'test/replay', '--reporter=json'],
    workingDirectory: packageRoot,
  );
  if (result.exitCode != 0) {
    stderr.writeln('dart test exited ${result.exitCode}:\n${result.stdout}');
    exit(result.exitCode);
  }

  final outcomes = <String>[];
  final idToName = <int, String>{};
  for (final line in LineSplitter.split('${result.stdout}')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    Object? event;
    try {
      event = jsonDecode(trimmed);
    } catch (_) {
      continue; // Non-JSON noise on stdout is not part of the event stream.
    }
    if (event is! Map) continue;
    final test = event['test'];
    if (test is Map &&
        event['type'] == 'testStart' &&
        test['id'] is int &&
        test['name'] is String) {
      // Test ids depend on load order/concurrency; names are the stable
      // identity across runs.
      idToName[test['id'] as int] = test['name'] as String;
    } else if (event['type'] == 'testDone' && event['testID'] is int) {
      final name = idToName[event['testID'] as int];
      if (name != null) {
        outcomes.add('$name|${event['result']}|${event['message'] ?? ''}');
      }
    }
  }
  outcomes.sort();
  return outcomes;
}
