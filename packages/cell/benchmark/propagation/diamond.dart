// Converge-back (diamond) shapes: two branches rejoining at one sink.
//
// Run: dart run benchmark/propagation/diamond.dart
import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness.dart';

class DiamondBenchmark extends BenchmarkBase {
  DiamondBenchmark() : super('diamond (2 branches, shared sink)');

  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    emit = buildDiamond().emit;
  }

  @override
  void run() {
    emit(count++);
  }
}

void main() {
  DiamondBenchmark().report();
}
