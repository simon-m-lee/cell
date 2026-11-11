// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell_tissue): dart run benchmark/runner.dart --out current.json
import 'dart:convert';
import 'dart:io';

/// Benchmarks that run on every PR. Keep this list cheap (< ~2 min).
const prSuite = [
  'benchmark/micro/tissue_construction.dart',
  'benchmark/micro/tissue_mutation.dart',
  'benchmark/propagation/observer_delivery.dart',
];

final linePattern = RegExp(r'^(.*)\(RunTime\):\s+([0-9.]+) us\.$');

Future<void> main(List<String> args) async {
  var out = 'current.json';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    }
  }

  final results = <String, double>{};
  for (final file in prSuite) {
    stdout.writeln('== $file ==');
    final process = await Process.run(
      Platform.resolvedExecutable,
      ['run', file],
      workingDirectory: Directory.current.path,
    );
    stdout.write(process.stdout);
    stderr.write(process.stderr);
    if (process.exitCode != 0) {
      stderr.writeln('FAILED: $file (exit ${process.exitCode})');
      exitCode = process.exitCode;
      return;
    }
    for (final line in LineSplitter.split(process.stdout as String)) {
      final match = linePattern.firstMatch(line.trim());
      if (match != null) {
        results[match.group(1)!] = double.parse(match.group(2)!);
      }
    }
  }

  File(out).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(results)}\n',
  );
  stdout.writeln('Wrote ${results.length} benchmark results to $out');
}
