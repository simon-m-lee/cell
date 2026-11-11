// Cell.switchMap: late-inner wins semantics with synchronous inner cells.
//
// Run: dart run benchmark/operators/switch_map.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class SwitchMapBenchmark extends BenchmarkBase {
  SwitchMapBenchmark() : super('Cell.switchMap (sync inner cells)');

  late final bool Function(int) emit;
  late final List<Cell> inners;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final out = Cell.switchMap<int, int>(source.cell, (v) {
      // Standalone inner cells: a mapper that binds every inner to the
      // source would keep adding links to the source's fan-out, making the
      // benchmark quadratic in the number of emissions.
      final inner = Cell.ingress<int>();
      inner.emit(v);
      return inner.cell;
    });
    Cell.observe(source: out, effect: (Pulse p) {});
    emit = source.emit;
    inners = const [];
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
  }
}

void main() {
  SwitchMapBenchmark().report();
}
