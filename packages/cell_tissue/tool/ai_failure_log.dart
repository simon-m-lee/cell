// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0
//
// Phase 6.1 of CONTRIBUTING-AI-DOC.md: structured log of real AI agent
// failures. Every entry is reviewed quarterly; each review produces a
// doc-comment, macro, or code change within one sprint.
//
//   dart run tool/ai_failure_log.dart add \
//     --operator Flow.x --symptom "..." --demo grid --fix "..." \
//     [--guide "HowTo-Mitose-Flow.md §3.4"]
//
//   dart run tool/ai_failure_log.dart list

import 'dart:convert';
import 'dart:io';

const String logFile = 'tool/ai_failure_log.jsonl';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln('usage: ai_failure_log.dart add|list [options]');
    exitCode = 64;
    return;
  }
  switch (args.first) {
    case 'add':
      exitCode = await _add(args.skip(1).toList());
    case 'list':
      exitCode = await _list();
    default:
      stderr.writeln('unknown command: ${args.first}');
      exitCode = 64;
  }
}

Future<int> _add(List<String> args) async {
  String? take(String name) {
    final idx = args.indexOf(name);
    if (idx == -1 || idx + 1 >= args.length) return null;
    return args[idx + 1];
  }

  final operator = take('--operator');
  final symptom = take('--symptom');
  final demo = take('--demo');
  final fix = take('--fix');
  final guide = take('--guide');

  if (operator == null || symptom == null) {
    stderr.writeln('--operator and --symptom are required');
    return 64;
  }

  final entry = {
    'date': DateTime.now().toIso8601String().substring(0, 10),
    'operator': operator,
    'symptom': symptom,
    'demo': demo ?? '',
    'fix': fix ?? '',
    'guide_link': guide ?? '',
  };
  final file = File(logFile);
  file.parent.createSync(recursive: true);
  final sink = file.openWrite(mode: FileMode.append);
  sink.writeln(jsonEncode(entry));
  await sink.close();
  stdout.writeln('appended: ${jsonEncode(entry)}');
  return 0;
}

Future<int> _list() async {
  final file = File(logFile);
  if (!file.existsSync()) {
    stdout.writeln('$logFile does not exist yet (no recorded AI failures).');
    return 0;
  }
  var count = 0;
  for (final line in await file.readAsLines()) {
    if (line.trim().isEmpty) continue;
    try {
      final entry = jsonDecode(line) as Map<String, dynamic>;
      count++;
      stdout.writeln('[${entry['date']}] ${entry['operator']}: '
          '${entry['symptom']} (demo: ${entry['demo']}) '
          '-> fix: ${entry['fix']}');
    } catch (_) {
      stdout.writeln('(unparseable line) $line');
    }
  }
  stdout.writeln('$count entries.');
  return 0;
}
