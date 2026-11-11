// Validates the "mask eliminates the Nullable Field Tax" claim.
//
// Run: dart run benchmark/micro/nucleus_construction.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

/// `Nucleus.create` with only the mandatory context.
class NucleusDefault extends BenchmarkBase {
  NucleusDefault() : super('Nucleus default (1 field)');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Nucleus.create();
    }
  }
}

/// `Nucleus.create` with three populated fields.
class NucleusThreeFields extends BenchmarkBase {
  NucleusThreeFields() : super('Nucleus three fields');

  final context = Context.module('Payment');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Nucleus.create(context: context, forceLock: true);
    }
  }
}

/// Control: a plain class with three nullable fields.
class ControlPlainNucleus extends BenchmarkBase {
  ControlPlainNucleus() : super('[control] plain class, 3 nullables');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      _PlainNucleus();
    }
  }
}

class _PlainNucleus {
  Object? context;
  Object? receptor;
  Object? testRule;
}

void main() {
  NucleusDefault().report();
  NucleusThreeFields().report();
  ControlPlainNucleus().report();
}
