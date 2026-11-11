// Governed vs ungoverned overhead for identical chain shapes.
// Pass criterion (proposal): governed overhead < 2x ungoverned.
//
// Run: dart run benchmark/propagation/governed_vs_ungoverned.dart
import 'package:benchmark_harness/benchmark_harness.dart';

import '../harness.dart';

class UngovernedChain extends BenchmarkBase {
  UngovernedChain() : super('chain depth 10, ungoverned');

  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    emit = buildChain(10).emit;
  }

  @override
  void run() {
    emit(count++);
  }
}

class GovernedChain extends BenchmarkBase {
  GovernedChain() : super('chain depth 10, governed');

  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    emit = buildChain(10, governed: true).emit;
  }

  @override
  void run() {
    emit(count++);
  }
}

void main() {
  UngovernedChain().report();
  GovernedChain().report();
}
