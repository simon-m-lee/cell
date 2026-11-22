// Validation overhead: allowAll vs a custom per-element rule vs the async
// facade round-trip with an async rule.
//
// The mutation dispatch gained real FutureOr support (issue #4): the async
// facade and the apply gateway await async rules, and the synchronous
// mutation surface throws UnsupportedError for them. This benchmark pins
// the async-facade round-trip cost. It deliberately extends
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
      // Guard non-int objects: the receptor re-validates emitted pulses
      // through the same rule.
      (v, {host, arguments, user}) async => v is! int || v >= 0,
    ),
  );

  @override
  Future<void> run() async {
    // Async rules must be awaited through the `.async` facade: the
    // synchronous surface throws UnsupportedError for them.
    await list.async.add(1);
    await list.async.remove(1);
  }
}

Future<void> main() async {
  NoRuleAdd().report();
  PositiveRuleAdd().report();
  await AsyncRuleAdd().report();
}
