// Sub-suite runner for benchmark/tissue (the research-driven suite).
// Parses `Name(RunTime): N us.` lines and writes JSON for the gate.
//
// Run (from packages/cell_tissue):
//   dart run benchmark/tissue/runner.dart --out benchmark/tissue/current.json
import 'dart:convert';
import 'dart:io';

/// Benchmarks that run on every PR. Keep this list cheap (< ~2 min).
const prSuite = [
  'benchmark/tissue/micro/mutation_cost.dart',
  'benchmark/tissue/micro/mutation_validation.dart',
  'benchmark/tissue/deputy/unmodifiable_view.dart',
  'benchmark/tissue/batch/collective_emit.dart',
  'benchmark/tissue/async/tissue_modifiable_async.dart',
];

/// The full research suite (used for baseline generation).
const fullSuite = [
  ...prSuite,
  'benchmark/tissue/micro/mutation_fanout.dart',
  'benchmark/tissue/deputy/sync_overhead.dart',
  'benchmark/tissue/deputy/chain_depth.dart',
  'benchmark/tissue/container/list_variants.dart',
  'benchmark/tissue/container/set_variants.dart',
  'benchmark/tissue/container/map_variants.dart',
  'benchmark/tissue/operators/bulk_mutations.dart',
  'benchmark/tissue/operators/complex_ops.dart',
  'benchmark/tissue/compare/vs_dart_list.dart',
  'benchmark/tissue/compare/vs_dart_set.dart',
  'benchmark/tissue/compare/vs_dart_map.dart',
  'benchmark/tissue/compare/vs_dart_unmodifiable_view.dart',
];

final linePattern = RegExp(r'^(.*)\(RunTime\):\s+([0-9.]+) us\.$');

Future<void> main(List<String> args) async {
  var out = 'current.json';
  var full = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--full') {
      full = true;
    }
  }

  final suite = full ? fullSuite : prSuite;
  final results = <String, double>{};
  for (final file in suite) {
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
