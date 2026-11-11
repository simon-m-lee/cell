// Cell.asyncMap concurrency modes: concurrency 0/1/4/16, latestOnly,
// exhaust. Reports throughput (pulses/s) for pure-CPU mapper work.
//
// Run: dart run benchmark/operators/async_map.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class AsyncMapBenchmark extends AsyncBenchmarkBase {
  AsyncMapBenchmark({
    required this.concurrency,
    required this.latestOnly,
    required this.exhaust,
    required this.n,
  }) : super(
            'asyncMap c=$concurrency latest=$latestOnly exhaust=$exhaust n=$n');

  final int concurrency;
  final bool latestOnly;
  final bool exhaust;
  final int n;
  late final bool Function(int) emit;
  var emitted = 0;

  @override
  Future<void> setup() async {
    final source = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(
      source.cell,
      (v) async {
        // Pure CPU work — no timers, so the benchmark measures framework
        // overhead, not the event loop.
        var acc = v;
        for (var i = 0; i < 1000; i++) {
          acc = (acc * 31 + i) & 0xFFFF;
        }
        return acc;
      },
      concurrency: concurrency,
      latestOnly: latestOnly,
      exhaust: exhaust,
    );
    Cell.observe(
        source: mapped,
        effect: (Pulse p) {
          emitted++;
        });
    emit = source.emit;
    emitted = 0;
  }

  @override
  Future<void> run() async {
    final start = emitted;
    for (var i = 0; i < n; i++) {
      emit(i);
    }
    // `latestOnly` supersedes earlier in-flight work and `exhaust` drops
    // pulses while busy, so a synchronous burst can legitimately collapse
    // to a single delivery — waiting for all n deliveries there would only
    // burn the spin budget (deterministically). Wait for what the mode
    // promises instead, with a bounded fallback so a delivery regression
    // cannot stall the suite.
    final target = start + ((latestOnly || exhaust) ? 1 : n);
    var spins = 0;
    while (emitted < target && spins < 10000) {
      await Future<void>.delayed(Duration.zero);
      spins++;
    }
  }

  @override
  Future<void> teardown() async {
    emitted = 0;
  }
}

Future<void> main() async {
  for (final c in [0, 1, 4, 16]) {
    await AsyncMapBenchmark(
            concurrency: c, latestOnly: false, exhaust: false, n: 200)
        .report();
  }
  await AsyncMapBenchmark(
          concurrency: 0, latestOnly: true, exhaust: false, n: 200)
      .report();
  await AsyncMapBenchmark(
          concurrency: 0, latestOnly: false, exhaust: true, n: 200)
      .report();
}
