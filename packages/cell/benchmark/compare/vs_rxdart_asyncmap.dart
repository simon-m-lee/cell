// Cell.asyncMap vs RxDart.asyncMap: 1000 values, pure-CPU mapper.
//
// Run: dart run benchmark/compare/vs_rxdart_asyncmap.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';
import 'package:rxdart/rxdart.dart';

int cpu(int v) {
  var acc = v;
  for (var i = 0; i < 1000; i++) {
    acc = (acc * 31 + i) & 0xFFFF;
  }
  return acc;
}

class CellAsyncMap extends AsyncBenchmarkBase {
  CellAsyncMap() : super('Cell.asyncMap');

  late final bool Function(int) emit;
  var received = 0;

  @override
  Future<void> setup() async {
    final source = Cell.ingress<int>();
    final mapped = Cell.asyncMap<int, int>(source.cell, (v) async => cpu(v));
    Cell.observe(
        source: mapped,
        effect: (Pulse p) {
          received++;
        });
    emit = source.emit;
    received = 0;
  }

  @override
  Future<void> run() async {
    for (var i = 0; i < 1000; i++) {
      emit(i);
    }
    var spins = 0;
    while (received < 1000 && spins < 1000000) {
      await Future<void>.delayed(Duration.zero);
      spins++;
    }
  }
}

class RxAsyncMap extends AsyncBenchmarkBase {
  RxAsyncMap() : super('RxDart.asyncMap');

  final controller = StreamController<int>.broadcast();
  var received = 0;

  @override
  Future<void> setup() async {
    controller.stream
        .transform(
          FlatMapStreamTransformer((v) => Stream<int>.value(cpu(v))),
        )
        .listen((_) => received++);
    received = 0;
  }

  @override
  Future<void> run() async {
    for (var i = 0; i < 1000; i++) {
      controller.add(i);
    }
    var spins = 0;
    while (received < 1000 && spins < 1000000) {
      await Future<void>.delayed(Duration.zero);
      spins++;
    }
  }
}

Future<void> main() async {
  await CellAsyncMap().report();
  await RxAsyncMap().report();
}
