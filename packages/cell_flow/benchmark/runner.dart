// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell_flow): dart run benchmark/runner.dart --out current.json
import 'dart:convert';
import 'dart:io';

/// Benchmarks that run on every PR. Keep this list cheap (< ~5 min).
const prSuite = [
  'benchmark/micro/instruction_construction.dart',
  'benchmark/micro/pipeline_construction.dart',
  'benchmark/micro/map_chain.dart',
  'benchmark/micro/filter_chain.dart',
  'benchmark/micro/scan_reduce.dart',
  'benchmark/micro/distinct.dart',
  'benchmark/micro/take_skip.dart',
  'benchmark/micro/pairwise.dart',
  'benchmark/micro/pluck.dart',
  'benchmark/async/async_map.dart',
  'benchmark/async/async_expand.dart',
  'benchmark/async/async_fold.dart',
  'benchmark/async/from_future.dart',
  'benchmark/async/from_stream.dart',
  'benchmark/flatten/concat_map.dart',
  'benchmark/flatten/merge_map.dart',
  'benchmark/flatten/switch_map.dart',
  'benchmark/flatten/exhaust_map.dart',
  'benchmark/time/debounce.dart',
  'benchmark/time/throttle.dart',
  'benchmark/time/delay.dart',
  'benchmark/time/timeout.dart',
  'benchmark/combine/merge_with.dart',
  'benchmark/combine/combine_latest.dart',
  'benchmark/combine/zip_with.dart',
  'benchmark/combine/race.dart',
  'benchmark/combine/group_by.dart',
  'benchmark/collect/buffer_count.dart',
  'benchmark/collect/buffer_time.dart',
  'benchmark/collect/window_count.dart',
];

/// Nightly-only: comparisons (need rxdart) and 50k stress.
const nightlySuite = [
  'benchmark/compare/vs_rxdart_map_filter.dart',
  'benchmark/compare/vs_rxdart_asyncmap.dart',
  'benchmark/compare/vs_rxdart_switchmap.dart',
  'benchmark/compare/vs_raw_stream_map.dart',
  'benchmark/stress/high_frequency.dart',
];

final linePattern = RegExp(r'^(.*)\(RunTime\):\s+([0-9.]+) us\.$');

Future<void> main(List<String> args) async {
  var out = 'current.json';
  var nightly = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--nightly') {
      nightly = true;
    }
  }

  final suite = nightly ? [...prSuite, ...nightlySuite] : prSuite;
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
