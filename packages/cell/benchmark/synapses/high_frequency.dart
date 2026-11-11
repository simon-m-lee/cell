// High-frequency stress: 50k pulses through an ingress + observer graph.
// Measures sustained pulses/second.
//
// Run: dart run benchmark/synapses/high_frequency.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class HighFrequencyBenchmark extends BenchmarkBase {
  HighFrequencyBenchmark(this.pulses) : super('high frequency, $pulses pulses');

  final int pulses;
  late final bool Function(int) emit;
  var count = 0;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final a = Cell(bind: source.cell);
    final b = Cell(bind: a);
    Cell.observe(source: b, effect: (Pulse p) {});
    Cell.observe(source: source.cell, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < pulses; i++) {
      emit(count++);
    }
  }
}

void main() {
  HighFrequencyBenchmark(50000).report();
}
