// Set variants: value vs identity.
//
// Run: dart run benchmark/tissue/container/set_variants.dart
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:cell_tissue/cell_tissue.dart';

class ValueSetAdd extends BenchmarkBase {
  ValueSetAdd() : super('value set add+remove');

  final set = TissueSet<int>(<int>[]);
  var i = 0;

  @override
  void run() {
    set.add(i);
    set.remove(i);
    i++;
  }
}

class IdentitySetAdd extends BenchmarkBase {
  IdentitySetAdd() : super('identity set add+remove');

  final set = TissueSet<int>(<int>[], identitySet: true);
  var i = 0;

  @override
  void run() {
    set.add(i);
    set.remove(i);
    i++;
  }
}

void main() {
  ValueSetAdd().report();
  IdentitySetAdd().report();
}
