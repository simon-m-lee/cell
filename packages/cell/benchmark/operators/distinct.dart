// Cell.distinct: duplicate-heavy input (10 duplicates per unique value).
//
// Run: dart run benchmark/operators/distinct.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class CellDistinct extends BenchmarkBase {
  CellDistinct() : super('Cell.distinct (10 dup/unique)');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final filtered = Cell.distinct(source.cell);
    Cell.observe(source: filtered, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i ~/ 10);
    }
  }
}

class CellDistinctAllUnique extends BenchmarkBase {
  CellDistinctAllUnique() : super('Cell.distinct (all unique)');

  late final bool Function(int) emit;

  @override
  void setup() {
    final source = Cell.ingress<int>();
    final filtered = Cell.distinct(source.cell);
    Cell.observe(source: filtered, effect: (Pulse p) {});
    emit = source.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
  }
}

void main() {
  CellDistinct().report();
  CellDistinctAllUnique().report();
}
