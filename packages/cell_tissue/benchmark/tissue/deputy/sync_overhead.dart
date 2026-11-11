// Principal vs deputy mutation cost.
//
// Run: dart run benchmark/tissue/deputy/sync_overhead.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class PrincipalAdd extends BenchmarkBase {
  PrincipalAdd() : super('principal add+remove');

  final list = TissueList<int>();

  @override
  void run() {
    list.add(1);
    list.remove(1);
  }
}

class DeputyAdd extends BenchmarkBase {
  DeputyAdd(this.deputy) : super('read-only deputy mutation (rejected)');

  final TissueList<int> deputy;

  @override
  void run() {
    // The mutation is rejected by the deputy's rule — measure the
    // validation cost, not the commit.
    deputy.add(1);
  }
}

Future<void> main() async {
  PrincipalAdd().report();
  final source = TissueList<int>();
  final deputy = await source.deputy(testRule: TestTissue.readOnly);
  DeputyAdd(deputy).report();
}
