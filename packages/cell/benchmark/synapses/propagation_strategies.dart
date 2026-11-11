// PropagationStrategy dispatch overhead: immediate / async / batched /
// buffered with one downstream observer.
//
// Run: dart run benchmark/synapses/propagation_strategies.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class StrategyBenchmark extends AsyncBenchmarkBase {
  StrategyBenchmark(this.strategy)
      : super('synapses strategy=${strategy.name}');

  final PropagationStrategy strategy;
  late final Synapses synapses;
  late final RecordingCell recorder;
  var count = 0;

  @override
  Future<void> setup() async {
    recorder = RecordingCell();
    synapses = Synapses(
      downstreams: [recorder],
      policy: PropagationPolicy(strategy: strategy),
    );
    count = 0;
  }

  @override
  Future<void> run() async {
    for (var i = 0; i < 1000; i++) {
      synapses.call(Pulse<int>(count++));
    }
    // Let scheduled delivery settle.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class RecordingCell extends CellBase {
  final List<Pulse> received = [];

  RecordingCell()
      : super(
          receptor: Receptor((cell, pulse, {user}) {
            final recorder = cell as RecordingCell;
            recorder.received.add(pulse);
            return null;
          }),
        );
}

Future<void> main() async {
  for (final s in [
    PropagationStrategy.immediate,
    PropagationStrategy.async,
    PropagationStrategy.batched,
    PropagationStrategy.buffered,
  ]) {
    await StrategyBenchmark(s).report();
  }
}
