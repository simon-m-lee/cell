// Pins the "flyweight receptors / no translation overhead" claim.
//
// Run: dart run benchmark/micro/instruction_construction.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_flow/cell_flow.dart';

class FlowInstructionConstruction extends BenchmarkBase {
  FlowInstructionConstruction() : super('flow: FlowInstruction construction');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p);
    }
  }
}

class ReceptorConstruction extends BenchmarkBase {
  ReceptorConstruction() : super('flow: Receptor construction');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Receptor.instruction(
          FlowInstruction<Cell, Pulse, Pulse>((p, {cell, user}) => p));
    }
  }
}

class RawClosureControl extends BenchmarkBase {
  RawClosureControl() : super('flow: [control] raw closure');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Pulse identity(Pulse p) => p;
      // ignore: unused_local_variable
      final closure = identity;
    }
  }
}

void main() {
  FlowInstructionConstruction().report();
  ReceptorConstruction().report();
  RawClosureControl().report();
}
