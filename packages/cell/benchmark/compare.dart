// Regression gate: compares a current benchmark JSON against the checked-in
// baseline and fails when any benchmark regressed by more than
// --max-regression (default 0.15 = 15%).
//
// Run: dart run benchmark/compare.dart --baseline baseline.json
//        --current current.json --max-regression 0.15
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var baselinePath = 'benchmark/baseline.json';
  var currentPath = 'current.json';
  var maxRegression = 0.15;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--baseline' && i + 1 < args.length) {
      baselinePath = args[i + 1];
    } else if (args[i] == '--current' && i + 1 < args.length) {
      currentPath = args[i + 1];
    } else if (args[i] == '--max-regression' && i + 1 < args.length) {
      maxRegression = double.parse(args[i + 1]);
    }
  }

  final baselineFile = File(baselinePath);
  final currentFile = File(currentPath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('Baseline not found: $baselinePath');
    exitCode = 2;
    return;
  }
  if (!currentFile.existsSync()) {
    stderr.writeln('Current results not found: $currentPath');
    exitCode = 2;
    return;
  }

  final baseline = jsonDecode(baselineFile.readAsStringSync()) as Map;
  final current = jsonDecode(currentFile.readAsStringSync()) as Map;

  final regressions = <String>[];
  final missing = <String>[];
  for (final entry in baseline.entries) {
    final name = entry.key as String;
    final before = (entry.value as num).toDouble();
    final after = current[name];
    if (after == null) {
      missing.add(name);
      continue;
    }
    final afterUs = (after as num).toDouble();
    final delta = (afterUs - before) / before;
    if (delta > maxRegression) {
      regressions.add('$name: ${before.toStringAsFixed(2)} -> '
          '${afterUs.toStringAsFixed(2)} us (${(delta * 100).toStringAsFixed(1)}% '
          'slower, limit ${(maxRegression * 100).toStringAsFixed(0)}%)');
    }
  }

  if (regressions.isNotEmpty) {
    stderr.writeln('Benchmark regressions detected:');
    for (final line in regressions) {
      stderr.writeln('  $line');
    }
    exitCode = 1;
    return;
  }

  if (missing.isNotEmpty) {
    stderr.writeln('Warning: baseline entries missing from current run: '
        '${missing.join(', ')}');
  }

  stdout.writeln('All benchmarks within the ${maxRegression * 100}% '
      'regression budget.');
}
