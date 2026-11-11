// How does a single mutation scale with observer count?
//
// Run: dart run benchmark/tissue/micro/mutation_fanout.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class MutationFanout extends BenchmarkBase {
  MutationFanout(this.observers) : super('fanout $observers observers');

  final int observers;
  final source = TissueList<int>();

  @override
  void setup() {
    for (var i = 0; i < observers; i++) {
      Cell.observe(source: source, effect: (_) {});
    }
  }

  @override
  void run() {
    source.add(1);
    source.remove(1);
  }
}

void main() {
  for (final n in [1, 10, 100, 1000]) {
    MutationFanout(n).report();
  }
}
