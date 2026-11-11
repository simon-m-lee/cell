// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell_flow): dart run benchmark/runner.dart --out current.json
import 'dart:async';
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

/// Per-file wall-clock budget. A benchmark that hangs must not stall the
/// whole suite (or burn a full CI job) — kill it and fail fast.
const defaultFileTimeout = Duration(minutes: 2);

/// Runs one benchmark file as a child process and returns its captured
/// output. The script is launched directly (not via `dart run`) so the
/// spawned process *is* the benchmark VM and a kill on timeout cannot
/// leave an orphaned grandchild behind.
Future<({int exitCode, String stdoutText, String stderrText})> runFile(
  String file, {
  required Duration timeout,
}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    [file],
    workingDirectory: Directory.current.path,
  );
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  final done = Completer<({int exitCode, bool timedOut})>();
  late final Timer killTimer;
  process.exitCode.then((code) {
    killTimer.cancel();
    if (!done.isCompleted) {
      done.complete((exitCode: code, timedOut: false));
    }
  });
  killTimer = Timer(timeout, () {
    if (!done.isCompleted) {
      done.complete((exitCode: 124, timedOut: true));
    }
  });
  final result = await done.future;
  if (result.timedOut) {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
  }
  return (
    exitCode: result.exitCode,
    stdoutText: await stdoutFuture,
    stderrText: await stderrFuture,
  );
}

Future<void> main(List<String> args) async {
  var out = 'current.json';
  var nightly = false;
  var fileTimeout = defaultFileTimeout;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--nightly') {
      nightly = true;
    } else if (args[i] == '--file-timeout' && i + 1 < args.length) {
      fileTimeout = Duration(seconds: int.parse(args[i + 1]));
    }
  }

  final suite = nightly ? [...prSuite, ...nightlySuite] : prSuite;
  final results = <String, double>{};
  for (final file in suite) {
    stdout.writeln('== $file ==');
    final run = await runFile(file, timeout: fileTimeout);
    stdout.write(run.stdoutText);
    stderr.write(run.stderrText);
    if (run.exitCode != 0) {
      if (run.exitCode == 124) {
        stderr.writeln(
            'FAILED: $file (timed out after ${fileTimeout.inSeconds}s)');
      } else {
        stderr.writeln('FAILED: $file (exit ${run.exitCode})');
      }
      exitCode = run.exitCode;
      return;
    }
    for (final line in LineSplitter.split(run.stdoutText)) {
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
