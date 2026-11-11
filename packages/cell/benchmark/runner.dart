// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell): dart run benchmark/runner.dart --out current.json
import 'dart:convert';
import 'dart:io';

/// Benchmarks that run on every PR. Keep this list cheap (< ~2 min).
const prSuite = [
  'benchmark/micro/nucleus_construction.dart',
  'benchmark/micro/cell_construction.dart',
  'benchmark/micro/value_emit.dart',
  'benchmark/micro/pulse_primitives.dart',
  'benchmark/propagation/chain_depth.dart',
  'benchmark/propagation/fan_out.dart',
  'benchmark/propagation/diamond.dart',
  'benchmark/propagation/governed_vs_ungoverned.dart',
  'benchmark/operators/distinct.dart',
  'benchmark/operators/debounce_throttle.dart',
  'benchmark/operators/async_map.dart',
  'benchmark/operators/switch_map.dart',
  'benchmark/synapses/propagation_strategies.dart',
  'benchmark/transaction/value_transaction.dart',
  'benchmark/transaction/tx_apply.dart',
  'benchmark/async/receptor_async.dart',
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

  final outFile = File(out);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(results),
  );
  stdout.writeln('Wrote ${results.length} benchmark results to $out');
}
