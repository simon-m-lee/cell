// Pins the toHandle materialization cost: a Nucleus + Receptor + Cell per
// activation, and linear scaling in pipeline depth.
//
// Run: dart run benchmark/micro/pipeline_construction.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';

class PipelineConstructionD1 extends BenchmarkBase {
  PipelineConstructionD1() : super('flow: toHandle 1-stage');

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      Flow.map<int, int>(Cell.ingress<int>().cell, project: (v) => v);
    }
  }
}

class PipelineConstructionD3 extends BenchmarkBase {
  PipelineConstructionD3() : super('flow: toHandle 3-stage');

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      final gate = Cell.ingress<int>();
      FlowInstruction op =
          FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      op = op + FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      op = op + FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      op.toHandle(source: gate.cell);
    }
  }
}

class PipelineConstructionD10 extends BenchmarkBase {
  PipelineConstructionD10() : super('flow: toHandle 10-stage');

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      final gate = Cell.ingress<int>();
      FlowInstruction op =
          FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      for (var d = 1; d < 10; d++) {
        op = op + FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
      }
      op.toHandle(source: gate.cell);
    }
  }
}

class RawCellConstruction extends BenchmarkBase {
  RawCellConstruction() : super('flow: [control] Cell construction');

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      Cell();
    }
  }
}

class RawCellChain extends BenchmarkBase {
  RawCellChain() : super('flow: [control] Cell chain construction');

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      // A 3-cell observe chain as the bare-graph control.
      final a = Cell();
      final b = Cell();
      final c = Cell();
      Cell.observe(source: a, effect: (_) {});
      Cell.observe(source: b, effect: (_) {});
      if (identical(c, a)) throw StateError('unreachable');
    }
  }
}

void main() {
  PipelineConstructionD1().report();
  PipelineConstructionD3().report();
  PipelineConstructionD10().report();
  RawCellConstruction().report();
}
