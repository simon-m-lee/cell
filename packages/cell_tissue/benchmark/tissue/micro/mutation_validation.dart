// Validation overhead: allowAll vs a custom per-element rule.
//
// Run: dart run benchmark/tissue/micro/mutation_validation.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class NoRuleAdd extends BenchmarkBase {
  NoRuleAdd() : super('add (allowAll)');

  final list = TissueList<int>();

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class PositiveRuleAdd extends BenchmarkBase {
  PositiveRuleAdd() : super('add (positive rule)');

  final list = TissueList<int>(
    testRule: TestTissue<int, TissueList<int>>(
      (v, {host, arguments, user}) => v >= 0,
    ),
  );

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class AsyncRuleAdd extends BenchmarkBase {
  AsyncRuleAdd() : super('add (async rule, serialized)');

  final list = TissueList<int>(
    testRule: TestTissue<int, TissueList<int>>(
      (v, {host, arguments, user}) async => v >= 0,
    ),
  );

  @override
  Future<void> run() async {
    await list.async.add(1);
    list.remove(1);
  }
}

void main() {
  NoRuleAdd().report();
  PositiveRuleAdd().report();
  AsyncRuleAdd().report();
}
