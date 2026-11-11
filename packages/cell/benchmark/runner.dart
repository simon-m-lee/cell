// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell): dart run benchmark/runner.dart --out current.json
import 'dart:async';
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
  var fileTimeout = defaultFileTimeout;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--file-timeout' && i + 1 < args.length) {
      fileTimeout = Duration(seconds: int.parse(args[i + 1]));
    }
  }

  final results = <String, double>{};
  for (final file in prSuite) {
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

  final outFile = File(out);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(results),
  );
  stdout.writeln('Wrote ${results.length} benchmark results to $out');
}
