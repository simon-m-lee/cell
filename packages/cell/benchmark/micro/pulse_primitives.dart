// Pins the per-pulse primitive costs that dominate every propagation
// benchmark. The `get<T>` exception-miss cost is included as a control:
// Phase 1 of the performance work replaced these misses with shape-tagged
// direct reads, and this file is the regression pin for that.
//
// Run: dart run benchmark/micro/pulse_primitives.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class PulseConstruct extends BenchmarkBase {
  PulseConstruct() : super('Pulse construction');

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      Pulse<int>(i);
    }
  }
}

class GovernedPulseConstruct extends BenchmarkBase {
  GovernedPulseConstruct() : super('governed Pulse construction');

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      Pulse<int>.governed(payload: i);
    }
  }
}

class WithStep extends BenchmarkBase {
  WithStep() : super('pulse.withStep');

  final pulse = Pulse<int>(1);

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      pulse.withStep('step');
    }
  }
}

class ExceptionMissControl extends BenchmarkBase {
  ExceptionMissControl() : super('[control] caught NoSuchMethodError miss');

  @override
  void run() {
    final p = Pulse<int>(1);
    for (var i = 0; i < 100000; i++) {
      try {
        (p as dynamic).absentField;
      } on NoSuchMethodError {
        // miss
      }
    }
  }
}

class EmptySynapsesCall extends BenchmarkBase {
  EmptySynapsesCall() : super('empty Synapses.call');

  final synapses = Synapses();

  @override
  void run() {
    for (var i = 0; i < 100000; i++) {
      synapses.call(Pulse<int>(i));
    }
  }
}

class SingleHopEmit extends BenchmarkBase {
  SingleHopEmit() : super('ingress.emit -> 1 observer');

  late final bool Function(int) emit;

  @override
  void setup() {
    final handle = Cell.ingress<int>();
    Cell.observe(source: handle.cell, effect: (Pulse p) {});
    emit = handle.emit;
  }

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      emit(i);
    }
  }
}

void main() {
  PulseConstruct().report();
  GovernedPulseConstruct().report();
  WithStep().report();
  ExceptionMissControl().report();
  EmptySynapsesCall().report();
  SingleHopEmit().report();
}
