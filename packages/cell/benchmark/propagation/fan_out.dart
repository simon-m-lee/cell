// Fan-out scaling: one source delivering to N terminal observers.
//
// Run: dart run benchmark/propagation/fan_out.dart
import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness.dart';

class FanOutBenchmark extends BenchmarkBase {
  FanOutBenchmark(this.fanOut) : super('fan-out $fanOut');

  final int fanOut;
  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    emit = buildFanOut(fanOut).emit;
  }

  @override
  void run() {
    emit(count++);
  }
}

void main() {
  for (final n in [1, 10, 50, 100]) {
    FanOutBenchmark(n).report();
  }
}
