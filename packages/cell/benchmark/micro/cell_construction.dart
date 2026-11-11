// Validates the flyweight construction claim.
//
// Run: dart run benchmark/micro/cell_construction.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell/cell.dart';

class CellConstructDefault extends BenchmarkBase {
  CellConstructDefault() : super('Cell() default');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Cell();
    }
  }
}

class CellConstructGoverned extends BenchmarkBase {
  CellConstructGoverned() : super('Cell.governed(context)');

  final context = Context.module('Payment');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Cell.governed(context: context);
    }
  }
}

class CellConstructFromNucleus extends BenchmarkBase {
  CellConstructFromNucleus() : super('Cell.fromNucleus (full)');

  final nucleus = Nucleus.create(
    context: Context.module('Payment'),
    receptor: Receptor.passThrough,
    testRule: TestCell.allowAll,
    synapses: Synapses.enabled,
    forceLock: true,
  );

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      Cell.fromNucleus(nucleus);
    }
  }
}

class CellConstructDeputy extends AsyncBenchmarkBase {
  CellConstructDeputy() : super('deputy()');

  final principal = Cell();

  @override
  Future<void> run() async {
    for (var i = 0; i < 10000; i++) {
      await principal.deputy();
    }
  }
}

class ControlPlainClass extends BenchmarkBase {
  ControlPlainClass() : super('[control] plain class, 4 nullables');

  @override
  void run() {
    for (var i = 0; i < 10000; i++) {
      _PlainCell();
    }
  }
}

class _PlainCell {
  Object? context;
  Object? receptor;
  Object? testRule;
  Object? synapses;
}

Future<void> main() async {
  CellConstructDefault().report();
  CellConstructGoverned().report();
  CellConstructFromNucleus().report();
  await CellConstructDeputy().report();
  ControlPlainClass().report();
}
