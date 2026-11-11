// Flow map vs raw StreamController.map (single-hop shape).
//
// Run: dart run benchmark/compare/vs_raw_stream_map.dart
import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';

class FlowMap extends BenchmarkBase {
  FlowMap() : super('flow vs raw: Flow map');
  late final FlowHandle h;

  @override
  void setup() {
    h = Flow.map<int, int>(Cell.ingress<int>().cell, project: (v) => v);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      h.emit(i);
    }
  }
}

class RawStreamMap extends BenchmarkBase {
  RawStreamMap() : super('flow vs raw: raw StreamController.map');
  late final StreamController<int> controller;
  late final Stream<int> mapped;

  @override
  void setup() {
    controller = StreamController<int>();
    mapped = controller.stream.map((v) => v);
    mapped.listen((_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      controller.add(i);
    }
  }
}

void main() {
  FlowMap().report();
  RawStreamMap().report();
  print('(see benchmark/README.md for the itemized cost ladder)');
}
