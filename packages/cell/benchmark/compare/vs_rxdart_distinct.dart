// Cell.distinct vs RxDart.distinct on duplicate-heavy input.
//
// Run: dart run benchmark/compare/vs_rxdart_distinct.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';
import 'package:rxdart/rxdart.dart';

class CellDistinct extends BenchmarkBase {
  CellDistinct() : super('Cell.distinct');

  late final bool Function(int) emit;

  @override
  void setup() {
    final src = Cell.ingress<int>();
    final filtered = Cell.distinct(src.cell);
    Cell.observe(source: filtered, effect: (Pulse p) {});
    emit = src.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      emit(i ~/ 10); // 10 duplicates per unique
    }
  }
}

class RxDistinct extends BenchmarkBase {
  RxDistinct() : super('RxDart.distinct');

  final controller = StreamController<int>.broadcast();

  @override
  void setup() {
    controller.stream
        .transform(DistinctUniqueStreamTransformer())
        .listen((_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      controller.add(i ~/ 10);
    }
  }
}

void main() {
  CellDistinct().report();
  RxDistinct().report();
  // Cell.distinct emits governed pulses (provenance, cycle check, gate,
  // lineage, lifecycle accounting); RxDart.distinct emits bare values.
  // The feature-accounted per-emit ladder is in benchmark/README.md.
  print('(see benchmark/README.md for the itemized cost ladder)');
}
