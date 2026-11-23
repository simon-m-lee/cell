// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Runs the microbenchmarks and compares them against
// `benchmark/baseline.json`.
//
// Usage (from packages/cell_flutter):
//
//   dart run tool/benchmark.dart            # run + compare against baseline
//   dart run tool/benchmark.dart --update   # run + write a new baseline
//
// Each benchmark test prints `BENCH name: p50=..us p99=..us
// rebuilds=n/m` lines; this tool parses them into the JSON shape the
// CI gate consumes. The gate fails when a baseline scenario's p50 or
// p99 regresses by more than 15%.

import 'dart:convert';
import 'dart:io';

const benchmarkDir = 'benchmark';
const baselinePath = '$benchmarkDir/baseline.json';
const maxRegression = 0.15;

/// Absolute slack for scenarios whose times are sub-millisecond: a 15%
/// relative gate on a 300us p99 leaves only ~45us of budget, which is
/// smaller than OS scheduling noise. A scenario regresses only when it
/// exceeds *both* the relative gate and this absolute floor.
const absoluteSlackUs = 300.0;

const files = [
  'cell_flutter_benchmark.dart',
  'value_listenable_benchmark.dart',
  'riverpod_benchmark.dart',
  'bloc_benchmark.dart',
];

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final measurements = <String, Map<String, Object?>>{};

  // Resolve the package root from the script location so the tool works
  // regardless of the caller's working directory.
  final packageRoot = File.fromUri(Platform.script).parent.parent.path;

  for (final file in files) {
    stdout.writeln('== $file ==');
    final result = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      ['test', '$benchmarkDir/$file', '--reporter', 'compact'],
      workingDirectory: packageRoot,
      runInShell: true,
    );
    final output = '${result.stdout}\n${result.stderr}';
    if (result.exitCode != 0) {
      stderr.writeln(output);
      exit(result.exitCode);
    }
    for (final line in output.split('\n')) {
      final marker = line.indexOf('BENCH ');
      if (marker < 0) continue;
      final parsed = _parse(line.substring(marker + 'BENCH '.length));
      measurements[parsed.$1] = parsed.$2;
    }
  }

  if (measurements.isEmpty) {
    stderr.writeln('No BENCH lines found; nothing measured.');
    exit(1);
  }

  final baselineFile = File('$packageRoot/$baselinePath');
  if (update) {
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(measurements)}\n',
    );
    stdout.writeln('Wrote $packageRoot/$baselinePath');
    return;
  }

  final baseline = baselineFile.existsSync()
      ? (jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};
  if (baseline.isEmpty) {
    stderr.writeln(
      'No baseline at $packageRoot/$baselinePath; run with --update first.',
    );
    exit(2);
  }

  var regressions = 0;
  stdout.writeln(
    '${'scenario'.padRight(34)} p50(us)  baseline  delta   p99(us)  baseline  delta',
  );
  for (final entry in baseline.entries) {
    final base = entry.value as Map<String, dynamic>;
    final current = measurements[entry.key];
    if (current == null) {
      stdout.writeln('${entry.key.padRight(34)} MISSING FROM RUN');
      regressions++;
      continue;
    }
    final p50 = current['p50'] as num;
    final p99 = current['p99'] as num;
    final baseP50 = base['p50'] as num;
    final baseP99 = base['p99'] as num;
    final p50Delta = baseP50 == 0 ? 0.0 : (p50 - baseP50) / baseP50;
    final p99Delta = baseP99 == 0 ? 0.0 : (p99 - baseP99) / baseP99;
    final p50Bad =
        (p50 - baseP50) > absoluteSlackUs && p50Delta > maxRegression;
    final p99Bad =
        (p99 - baseP99) > absoluteSlackUs && p99Delta > maxRegression;
    if (p50Bad || p99Bad) regressions++;
    stdout.writeln(
      '${entry.key.padRight(34)} ${p50.toString().padLeft(7)} ${baseP50.toString().padLeft(8)} '
      '${_pct(p50Delta).padLeft(7)} ${p99.toString().padLeft(7)} '
      '${baseP99.toString().padLeft(8)} ${_pct(p99Delta).padLeft(7)}'
      '${(p50Bad || p99Bad) ? '  <-- REGRESSION' : ''}',
    );
  }

  if (regressions > 0) {
    stderr.writeln(
      '$regressions scenario(s) regressed beyond '
      '${(maxRegression * 100).round()}%.',
    );
    exit(1);
  }
  stdout.writeln(
    'All ${baseline.length} baseline scenarios within '
    '${(maxRegression * 100).round()}%.',
  );
}

String _pct(num delta) {
  final sign = delta >= 0 ? '+' : '';
  return '$sign${(delta * 100).toStringAsFixed(1)}%';
}

(String, Map<String, Object?>) _parse(String line) {
  // 'name: p50=123us p99=456us rebuilds=78/100'
  final name = line.substring(0, line.indexOf(':')).trim();
  final p50 = int.parse(RegExp(r'p50=(\d+)').firstMatch(line)!.group(1)!);
  final p99 = int.parse(RegExp(r'p99=(\d+)').firstMatch(line)!.group(1)!);
  final rebuildsMatch = RegExp(r'rebuilds=(\d+)/(\d+)').firstMatch(line);
  return (
    name,
    <String, Object?>{
      'p50': p50,
      'p99': p99,
      'rebuilds': rebuildsMatch?.group(1),
      'updates': rebuildsMatch?.group(2),
    },
  );
}
