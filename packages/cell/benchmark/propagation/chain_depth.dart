// Chain-depth scaling: validates "zero-latency propagation" and exposes
// O(depth) vs O(depth^2) behavior (CycleChecker cost shows up here).
//
// Run: dart run benchmark/propagation/chain_depth.dart
import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness.dart';

class ChainBenchmark extends BenchmarkBase {
  ChainBenchmark(this.depth, {this.governed = false})
      : super('chain depth=$depth governed=$governed');

  final int depth;
  final bool governed;
  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    final chain = buildChain(depth, governed: governed);
    emit = chain.emit;
  }

  @override
  void run() {
    emit(count++);
  }

  @override
  void teardown() {}
}

void main() {
  for (final d in [1, 5, 10, 20, 50]) {
    ChainBenchmark(d).report();
    ChainBenchmark(d, governed: true).report();
  }
}
