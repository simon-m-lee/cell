// Benchmark runner: executes the PR-suite benchmark files, parses the
// `Name(RunTime): N us.` lines emitted by benchmark_harness, and writes
// the results as JSON for the regression gate.
//
// Run (from packages/cell): dart run benchmark/runner.dart --out current.json
//
// Flags:
//   --out <file>              JSON output (default current.json)
//   --runs <n>                measure each file n times, write the median
//                             (default 1; CI uses 3 to blunt shared-runner noise)
//   --retries <n>             re-run a file up to n extra times if it times out
//                             (default 0; CI uses 1 to survive one-off stalls)
//   --file-timeout <seconds>  per-file wall-clock budget (default 120)
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
  var runs = 1;
  var retries = 0;
  var fileTimeout = defaultFileTimeout;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--runs' && i + 1 < args.length) {
      runs = int.parse(args[i + 1]);
    } else if (args[i] == '--retries' && i + 1 < args.length) {
      retries = int.parse(args[i + 1]);
    } else if (args[i] == '--file-timeout' && i + 1 < args.length) {
      fileTimeout = Duration(seconds: int.parse(args[i + 1]));
    }
  }
  if (runs < 1 || retries < 0) {
    stderr.writeln('--runs must be >= 1 and --retries must be >= 0');
    exitCode = 2;
    return;
  }

  // Collect every measurement; the written JSON holds the per-benchmark
  // median so one noisy run on a shared CI runner cannot trip the gate.
  final samples = <String, List<double>>{};
  for (final file in prSuite) {
    for (var run = 1; run <= runs; run++) {
      var attempt = 1;
      String? capturedStdout;
      while (true) {
        stdout.writeln('== $file (run $run/$runs'
            '${attempt > 1 ? ', retry $attempt' : ''}) ==');
        final result = await runFile(file, timeout: fileTimeout);
        stdout.write(result.stdoutText);
        stderr.write(result.stderrText);
        if (result.exitCode == 0) {
          capturedStdout = result.stdoutText;
          break;
        }
        if (result.exitCode == 124 && attempt <= retries) {
          stderr.writeln('RETRYING: $file timed out (attempt $attempt)');
          attempt++;
          continue;
        }
        if (result.exitCode == 124) {
          stderr.writeln(
              'FAILED: $file (timed out after ${fileTimeout.inSeconds}s)');
        } else {
          stderr.writeln('FAILED: $file (exit ${result.exitCode})');
        }
        exitCode = result.exitCode;
        return;
      }
      for (final line in LineSplitter.split(capturedStdout)) {
        final match = linePattern.firstMatch(line.trim());
        if (match != null) {
          samples
              .putIfAbsent(match.group(1)!, () => [])
              .add(double.parse(match.group(2)!));
        }
      }
    }
  }

  final results = <String, double>{};
  for (final entry in samples.entries) {
    final values = entry.value..sort();
    final middle = values.length ~/ 2;
    results[entry.key] = values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }

  final outFile = File(out);
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(results),
  );
  stdout.writeln('Wrote ${results.length} benchmark results to $out '
      '(median of $runs run${runs == 1 ? '' : 's'} per file)');
}
