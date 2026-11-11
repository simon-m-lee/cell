// ReceptorAsync throughput: serializedCompletion true vs false.
// Pass criterion (proposal): fire-and-forget throughput >= 5x serialized.
//
// Run: dart run benchmark/async/receptor_async.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class ReceptorAsyncBenchmark extends AsyncBenchmarkBase {
  ReceptorAsyncBenchmark({required this.serialized, required this.pulses})
      : super('receptor.async serialized=$serialized, $pulses pulses');

  final bool serialized;
  final int pulses;
  late final Future<void> Function(Pulse<int> pulse,
      {bool serializedCompletion}) ingest;
  var count = 0;

  @override
  Future<void> setup() async {
    final state = Cell.state<int>(initial: 0);
    ingest = state.ingest;
    count = 0;
  }

  @override
  Future<void> run() async {
    if (serialized) {
      for (var i = 0; i < pulses; i++) {
        await ingest(Pulse<int>(count++), serializedCompletion: true);
      }
    } else {
      for (var i = 0; i < pulses; i++) {
        await ingest(Pulse<int>(count++), serializedCompletion: false);
      }
    }
  }
}

Future<void> main() async {
  await ReceptorAsyncBenchmark(serialized: true, pulses: 2000).report();
  await ReceptorAsyncBenchmark(serialized: false, pulses: 2000).report();
}
