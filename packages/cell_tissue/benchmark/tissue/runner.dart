// Sub-suite runner for benchmark/tissue (the research-driven suite).
// Parses `Name(RunTime): N us.` lines and writes JSON for the gate.
//
// Run (from packages/cell_tissue):
//   dart run benchmark/tissue/runner.dart --out benchmark/tissue/current.json
import 'dart:async';
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
  var full = false;
  var fileTimeout = defaultFileTimeout;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[i + 1];
    } else if (args[i] == '--full') {
      full = true;
    } else if (args[i] == '--file-timeout' && i + 1 < args.length) {
      fileTimeout = Duration(seconds: int.parse(args[i + 1]));
    }
  }

  final suite = full ? fullSuite : prSuite;
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
