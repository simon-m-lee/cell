// Regression gate: compares a current benchmark JSON against the checked-in
// baseline and fails when any benchmark regressed beyond its budget.
//
// Three-tier budget, because GitHub-hosted `ubuntu-latest` runners vary
// measurably between machines: benchmarks with a baseline >=
// --large-baseline (default 10000 us) are stable across runners and are
// gated at --max-regression (default 0.15 = 15%); mid-size benchmarks
// (>= --micro-baseline, default 200 us) swing tens of percent between
// runner machines, so they are gated at --max-regression-small
// (default 0.5 = 50%); benchmarks below 200 us sit in the micro tier and
// routinely swing >100% between machines, so they are gated at
// --max-regression-micro (default 2.0 = 200%). Benchmarks whose baseline
// is below --min-baseline (default 10 us) sit inside the measurement
// quantization noise and are reported but not gated.
//
// Run: dart run benchmark/compare.dart --baseline benchmark/baseline.json
//        --current current.json
//
// Optional --budgets <file> overrides the tier budget per benchmark (JSON
// map of benchmark name -> max regression, e.g. 0.5 = 50%). Use it for
// benchmarks whose measurement is dominated by a fixed wall-clock timer
// wait and therefore swings with scheduler noise rather than with
// framework performance.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var baselinePath = 'benchmark/baseline.json';
  var currentPath = 'current.json';
  var budgetsPath = '';
  var maxRegression = 0.15;
  var maxRegressionSmall = 0.5;
  var maxRegressionMicro = 2.0;
  var largeBaseline = 10000.0; // us
  var microBaseline = 200.0; // us
  var minBaseline = 10.0; // us

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--baseline' && i + 1 < args.length) {
      baselinePath = args[i + 1];
    } else if (args[i] == '--current' && i + 1 < args.length) {
      currentPath = args[i + 1];
    } else if (args[i] == '--budgets' && i + 1 < args.length) {
      budgetsPath = args[i + 1];
    } else if (args[i] == '--max-regression' && i + 1 < args.length) {
      maxRegression = double.parse(args[i + 1]);
    } else if (args[i] == '--max-regression-small' && i + 1 < args.length) {
      maxRegressionSmall = double.parse(args[i + 1]);
    } else if (args[i] == '--max-regression-micro' && i + 1 < args.length) {
      maxRegressionMicro = double.parse(args[i + 1]);
    } else if (args[i] == '--large-baseline' && i + 1 < args.length) {
      largeBaseline = double.parse(args[i + 1]);
    } else if (args[i] == '--micro-baseline' && i + 1 < args.length) {
      microBaseline = double.parse(args[i + 1]);
    } else if (args[i] == '--min-baseline' && i + 1 < args.length) {
      minBaseline = double.parse(args[i + 1]);
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

  final budgets = <String, double>{};
  if (budgetsPath.isNotEmpty) {
    final budgetsFile = File(budgetsPath);
    if (!budgetsFile.existsSync()) {
      stderr.writeln('Budgets file not found: $budgetsPath');
      exitCode = 2;
      return;
    }
    final decoded = jsonDecode(budgetsFile.readAsStringSync());
    if (decoded is! Map) {
      stderr.writeln('Budgets file must be a JSON object: $budgetsPath');
      exitCode = 2;
      return;
    }
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is num) {
        budgets[entry.key as String] = value.toDouble();
      } else {
        stderr.writeln('Skipping non-numeric budget entry: ${entry.key}');
      }
    }
  }

  final regressions = <String>[];
  final missing = <String>[];
  final notGated = <String>[];
  for (final entry in baseline.entries) {
    final name = entry.key as String;
    final before = (entry.value as num).toDouble();
    final after = current[name];
    if (after == null) {
      missing.add(name);
      continue;
    }
    if (before < minBaseline) {
      notGated.add(name);
      continue;
    }
    final afterUs = (after as num).toDouble();
    final delta = (afterUs - before) / before;
    final limit = budgets[name] ??
        (before >= largeBaseline
            ? maxRegression
            : before >= microBaseline
                ? maxRegressionSmall
                : maxRegressionMicro);
    if (delta > limit) {
      regressions.add('$name: ${before.toStringAsFixed(2)} -> '
          '${afterUs.toStringAsFixed(2)} us (${(delta * 100).toStringAsFixed(1)}% '
          'slower, limit ${(limit * 100).toStringAsFixed(0)}%)');
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

  if (notGated.isNotEmpty) {
    stdout.writeln('Not gated (baseline < ${minBaseline.toStringAsFixed(0)} us): '
        '${notGated.join(', ')}');
  }

  stdout.writeln('All gated benchmarks within budget '
      '(>= ${largeBaseline.toStringAsFixed(0)} us: ${maxRegression * 100}%, '
      '${microBaseline.toStringAsFixed(0)}-${largeBaseline.toStringAsFixed(0)} us: '
      '${maxRegressionSmall * 100}%, < ${microBaseline.toStringAsFixed(0)} us: '
      '${maxRegressionMicro * 100}%'
      '${budgets.isEmpty ? '' : ', custom budgets: ${budgets.length}'}).');
}
