// Validation overhead: allowAll vs a custom per-element rule vs the async
// facade round-trip with an async rule.
//
// Known limitation: the tissue mutation dispatch currently evaluates an
// async rule's Future with `== true` on the synchronous path, so an async
// rule rejects every mutation (see the suite README). This benchmark pins
// the async-facade round-trip cost so the number moves when that dispatch
// gains real FutureOr support. It deliberately extends
// AsyncBenchmarkBase: a sync BenchmarkBase with an async run() measures
// ~0 us, and benchmark_harness then multiplies the iteration count by
// 1000 per pass — that queued millions of pending timers and made the
// process appear to hang (CI run 11's exit-124).
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

class AsyncRuleAdd extends AsyncBenchmarkBase {
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

Future<void> main() async {
  NoRuleAdd().report();
  PositiveRuleAdd().report();
  await AsyncRuleAdd().report();
}
