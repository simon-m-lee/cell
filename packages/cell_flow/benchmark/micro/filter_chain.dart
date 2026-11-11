// Filter chain: per-pulse cost of synchronous filter stages, including
// the rejection paths (which must not pay for downstream work).
//
// Run: dart run benchmark/micro/filter_chain.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';

import '../harness.dart';

class FilterChainD1 extends BenchmarkBase {
  FilterChainD1() : super('flow: filter chain depth=1');
  late final FlowBench bench = buildFilterChain(1);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class FilterChainD3 extends BenchmarkBase {
  FilterChainD3() : super('flow: filter chain depth=3');
  late final FlowBench bench = buildFilterChain(3);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class FilterChainD10 extends BenchmarkBase {
  FilterChainD10() : super('flow: filter chain depth=10');
  late final FlowBench bench = buildFilterChain(10);

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class FilterRejection extends BenchmarkBase {
  FilterRejection() : super('flow: filter reject rate=50%');
  late final FlowBench bench = buildWith(
    pipe: (source) => Flow.filter<int>(source, test: (v) => v.isEven).cell,
  );

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

class FilterRejection100 extends BenchmarkBase {
  FilterRejection100() : super('flow: filter reject rate=100%');
  late final FlowBench bench = buildWith(
    pipe: (source) => Flow.filter<int>(source, test: (_) => false).cell,
  );

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      bench.emit(i);
    }
  }
}

void main() {
  FilterChainD1().report();
  FilterChainD3().report();
  FilterChainD10().report();
  FilterRejection().report();
  FilterRejection100().report();
}
