// Map chain: per-pulse cost of synchronous map stages.
//
// Run: dart run benchmark/micro/map_chain.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';

import '../harness.dart';

class MapChainD1 extends BenchmarkBase {
  MapChainD1() : super('flow: map chain depth=1');
  late final FlowBench bench = buildMapChain(1);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class MapChainD3 extends BenchmarkBase {
  MapChainD3() : super('flow: map chain depth=3');
  late final FlowBench bench = buildMapChain(3);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class MapChainD10 extends BenchmarkBase {
  MapChainD10() : super('flow: map chain depth=10');
  late final FlowBench bench = buildMapChain(10);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class MapIdentityControl extends BenchmarkBase {
  MapIdentityControl() : super('flow: [control] raw Cell.observe');
  late final Cell cell = Cell();

  @override
  void setup() {
    Cell.observe(source: cell, effect: (_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Flow.map<int, int>(cell, project: (v) => v).emit(i);
    }
  }
}

void main() {
  MapChainD1().report();
  MapChainD3().report();
  MapChainD10().report();
}
